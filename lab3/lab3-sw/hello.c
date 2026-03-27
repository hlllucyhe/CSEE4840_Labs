/*
 * Userspace program for the VGA bouncing ball
 *
 * Sends ball coordinates to the vga_ball device driver
 * via ioctl, making the ball bounce around the screen.
 */

#include <stdio.h>
#include "vga_ball.h"
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>

/* Screen dimensions */
#define SCREEN_WIDTH  640
#define SCREEN_HEIGHT 480
#define BALL_RADIUS   20


int vga_ball_fd;

int main()
{
    vga_ball_arg_t arg;
    static const char filename[] = "/dev/vga_ball";

    /* Ball position */
    int x = 320, y = 240;

    /* Ball velocity (pixels per step) */
    int vx = 3, vy = 2;
    
    /* open device */
    printf("VGA ball Userspace program started\n");

    if ( (vga_ball_fd = open(filename, O_RDWR)) == -1) {
      fprintf(stderr, "could not open %s\n", filename);
      return -1;
    }

    /* Bounce forever */
    while (1) {

        /* Send new position to hardware via driver */
        arg.position.x = (unsigned short) x;
        arg.position.y = (unsigned short) y;

        if (ioctl(vga_ball_fd, VGA_BALL_WRITE_POSITION, &arg) < 0) {
            perror("ioctl VGA_BALL_WRITE_POSITION failed");
            close(vga_ball_fd);
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

    close(vga_ball_fd);
    return 0;
}
