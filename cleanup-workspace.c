#define _GNU_SOURCE

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/openat2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

static int fail(const char *operation, const char *name)
{
    fprintf(stderr, "cleanup-workspace-helper: %s %s: %s\n",
            operation, name, strerror(errno));
    return -1;
}

static int simple_component(const char *component)
{
    return component[0] != '\0' && strcmp(component, ".") != 0 &&
           strcmp(component, "..") != 0 && strchr(component, '/') == NULL;
}

static int open_directory(int directory_fd, const char *name,
                          unsigned long long resolve)
{
    struct open_how how = {
        .flags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC,
        .resolve = resolve,
    };
    return (int)syscall(SYS_openat2, directory_fd, name, &how, sizeof(how));
}

static int remove_contents(int directory_fd)
{
    int scan_fd = dup(directory_fd);
    if (scan_fd < 0)
        return fail("duplicate directory", ".");

    DIR *directory = fdopendir(scan_fd);
    if (directory == NULL) {
        int saved_errno = errno;
        close(scan_fd);
        errno = saved_errno;
        return fail("open directory stream", ".");
    }

    errno = 0;
    struct dirent *entry;
    while ((entry = readdir(directory)) != NULL) {
        const char *name = entry->d_name;
        if (strcmp(name, ".") == 0 || strcmp(name, "..") == 0)
            continue;

        struct stat information;
        if (fstatat(directory_fd, name, &information, AT_SYMLINK_NOFOLLOW) < 0) {
            int saved_errno = errno;
            closedir(directory);
            errno = saved_errno;
            return fail("inspect entry", name);
        }

        if (S_ISDIR(information.st_mode)) {
            int child_fd = open_directory(directory_fd, name,
                                          RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS |
                                              RESOLVE_NO_XDEV);
            if (child_fd < 0) {
                int saved_errno = errno;
                closedir(directory);
                errno = saved_errno;
                return fail("open child directory", name);
            }
            int result = remove_contents(child_fd);
            close(child_fd);
            if (result < 0) {
                closedir(directory);
                return -1;
            }
            if (unlinkat(directory_fd, name, AT_REMOVEDIR) < 0) {
                int saved_errno = errno;
                closedir(directory);
                errno = saved_errno;
                return fail("remove child directory", name);
            }
        } else if (S_ISREG(information.st_mode) || S_ISLNK(information.st_mode)) {
            if (unlinkat(directory_fd, name, 0) < 0) {
                int saved_errno = errno;
                closedir(directory);
                errno = saved_errno;
                return fail("remove entry", name);
            }
        } else {
            errno = EINVAL;
            closedir(directory);
            return fail("refuse unexpected entry type", name);
        }
        errno = 0;
    }

    if (errno != 0) {
        int saved_errno = errno;
        closedir(directory);
        errno = saved_errno;
        return fail("read directory", ".");
    }
    if (closedir(directory) < 0)
        return fail("close directory", ".");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc != 3 || !simple_component(argv[1]) || !simple_component(argv[2])) {
        fprintf(stderr, "usage: cleanup-workspace-helper REPOSITORY WORKSPACE\n");
        return EXIT_FAILURE;
    }

    const char *root = "/home/runner/actions-runner/_work";
    /* The fixed absolute anchor cannot use RESOLVE_BENEATH, and _work may
     * itself be the deliberately mounted persistent volume.  Mount crossings
     * below this anchor are rejected on every descendant open. */
    int root_fd = open_directory(AT_FDCWD, root,
                                 RESOLVE_NO_SYMLINKS);
    if (root_fd < 0)
        return fail("open fixed work root", root);

    struct stat root_information;
    if (fstat(root_fd, &root_information) < 0 || !S_ISDIR(root_information.st_mode)) {
        if (errno == 0)
            errno = ENOTDIR;
        int result = fail("validate fixed work root", root);
        close(root_fd);
        return result == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    int repository_fd = open_directory(root_fd, argv[1],
                                       RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS |
                                           RESOLVE_NO_XDEV);
    if (repository_fd < 0) {
        int result = fail("open repository", argv[1]);
        close(root_fd);
        return result == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    struct stat workspace_information;
    if (fstatat(repository_fd, argv[2], &workspace_information,
                AT_SYMLINK_NOFOLLOW) < 0 || !S_ISDIR(workspace_information.st_mode)) {
        if (errno == 0)
            errno = ENOTDIR;
        int result = fail("validate workspace", argv[2]);
        close(repository_fd);
        close(root_fd);
        return result == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    int workspace_fd = open_directory(repository_fd, argv[2],
                                       RESOLVE_BENEATH | RESOLVE_NO_SYMLINKS |
                                           RESOLVE_NO_XDEV);
    if (workspace_fd < 0) {
        int result = fail("open workspace", argv[2]);
        close(repository_fd);
        close(root_fd);
        return result == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
    }

    int result = remove_contents(workspace_fd);
    if (result == 0 && unlinkat(repository_fd, argv[2], AT_REMOVEDIR) < 0)
        result = fail("remove workspace", argv[2]);
    close(workspace_fd);
    close(repository_fd);
    close(root_fd);
    return result == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
