/*
 * Userspace program for the VGA bouncing ball
 *
 * Sends ball coordinates to the vga_ball device driver
 * via ioctl, making the ball bounce around the screen.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include "vga_ball.h"

/* Screen dimensions */
#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480
#define BALL_RADIUS   20

/* Device file */
#define DEVICE "/dev/vga_ball"

int main()
{
    int fd;
    vga_ball_arg_t arg;

    /* Ball position */
    int x = 320, y = 240;

    /* Ball velocity (pixels per step) */
    int vx = 3, vy = 2;

    /* Open the device */
    fd = open(DEVICE, O_RDWR);
    if (fd < 0) {
        perror("Could not open " DEVICE);
        return -1;
    }

    printf("VGA Ball userspace program started\n");

    /* Bounce forever */
    while (1) {

        /* Send new position to hardware via driver */
        arg.position.x = (unsigned short) x;
        arg.position.y = (unsigned short) y;

        if (ioctl(fd, VGA_BALL_WRITE_POSITION, &arg) < 0) {
            perror("ioctl VGA_BALL_WRITE_POSITION failed");
            close(fd);
            return -1;
        }

        /* Update position */
        x += vx;
        y += vy;

        /* Bounce off left/right walls */
        if (x - BALL_RADIUS <= 0) {
            x = BALL_RADIUS;
            vx = abs(vx);
        }
        if (x + BALL_RADIUS >= SCREEN_WIDTH) {
            x = SCREEN_WIDTH - BALL_RADIUS;
            vx = -abs(vx);
        }

        /* Bounce off top/bottom walls */
        if (y - BALL_RADIUS <= 0) {
            y = BALL_RADIUS;
            vy = abs(vy);
        }
        if (y + BALL_RADIUS >= SCREEN_HEIGHT) {
            y = SCREEN_HEIGHT - BALL_RADIUS;
            vy = -abs(vy);
        }

        /* Small delay to control speed (~60 fps) */
        usleep(16000);
    }

    close(fd);
    return 0;
}
