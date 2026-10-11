#include <unistd.h>
#include <sys/ioctl.h>
#include <termios.h>

int login_tty(int fd) {
    (void)setsid();
    (void)ioctl(fd, TIOCSCTTY, (char *)NULL);
    (void)dup2(fd, 0);
    (void)dup2(fd, 1);
    (void)dup2(fd, 2);
    if (fd > 2) {
        (void)close(fd);
    }
    return 0;
}
