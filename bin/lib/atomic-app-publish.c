// Publish a fully qualified sibling directory without an absent/partial interval.
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/stdio.h>

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    if (renameatx_np(AT_FDCWD, argv[1], AT_FDCWD, argv[2], RENAME_EXCL) == 0) return 0;
    if (errno == EEXIST && renameatx_np(AT_FDCWD, argv[1], AT_FDCWD, argv[2], RENAME_SWAP) == 0) return 0;
    perror("atomic app publication");
    return 1;
}
