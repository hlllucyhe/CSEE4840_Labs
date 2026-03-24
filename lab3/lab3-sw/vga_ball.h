#ifndef _VGA_BALL_H
#define _VGA_BALL_H

#include <linux/ioctl.h>

/* Ball position struct */
typedef struct {
    unsigned short x;  /* X coordinate (0-639) */
    unsigned short y;  /* Y coordinate (0-479) */
} vga_ball_position_t;

/* Argument passed to ioctl */
typedef struct {
    vga_ball_position_t position;
} vga_ball_arg_t;

#define VGA_BALL_MAGIC 'q'

/* ioctl commands */
#define VGA_BALL_WRITE_POSITION _IOW(VGA_BALL_MAGIC, 1, vga_ball_arg_t)
#define VGA_BALL_READ_POSITION  _IOR(VGA_BALL_MAGIC, 2, vga_ball_arg_t)

#endif
