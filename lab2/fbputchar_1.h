#ifndef _FBPUTCHAR_H
#  define _FBPUTCHAR_H

#define FBOPEN_DEV -1          /* Couldn't open the device */
#define FBOPEN_FSCREENINFO -2  /* Couldn't read the fixed info */
#define FBOPEN_VSCREENINFO -3  /* Couldn't read the variable info */
#define FBOPEN_MMAP -4         /* Couldn't mmap the framebuffer memory */
#define FBOPEN_BPP -5          /* Unexpected bits-per-pixel */

extern int fbopen(void);
extern void fbputchar(char, int, int);
extern void fbputs(const char*, int, int);
extern void fbclear(void);           /* Clear the entire screen */
extern void fbhhline(int row);        /* Draw a horizontal line */
extern void fbmovecursor(int row, int col); /* Move cursor position */
extern void fbdrawcursor(int row, int col, int visible); /* Draw/erase cursor */

#endif