/*
 * tests/test-fh.c — minimal name_to_handle_at / open_by_handle_at tester
 *
 * Compile with:
 *   gcc -Wall -O2 -o test-fh test-fh.c
 *
 * Usage:
 *   ./test-fh /path/to/file
 *   returns 0 on success, non-zero on error.
 */

#define _GNU_SOURCE
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>
/*
 * glibc already provides:
 *   struct file_handle {
 *     __u32 handle_bytes;
 *     __u32 handle_type;
 *     unsigned char f_handle[0];
 *   };
 */

#ifndef AT_FDCWD
# define AT_FDCWD -100
#endif

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <path>\n", argv[0]);
        return EXIT_FAILURE;
    }
        /* Allocate struct file_handle plus 1024 bytes for the handle data */
    size_t max_bytes = 1024;
    size_t alloc_size = sizeof(struct file_handle) + max_bytes;
    struct file_handle *fh = malloc(alloc_size);
    if (!fh) {
        perror("malloc");
        return EXIT_FAILURE;
    }
    fh->handle_bytes = max_bytes;

    int mount_id = 0;
    /* name_to_handle_at */
    if (syscall(SYS_name_to_handle_at, AT_FDCWD, argv[1], fh, &mount_id, 0) != >
        perror("name_to_handle_at");
        free(fh);
        return EXIT_FAILURE;
    }
        /* open_by_handle_at */
    int fd = syscall(SYS_open_by_handle_at, mount_id, fh, O_RDONLY);
    if (fd < 0) {
        perror("open_by_handle_at");
        free(fh);
        return EXIT_FAILURE;
    }

    close(fd);
    free(fh);
    return EXIT_SUCCESS;
}
