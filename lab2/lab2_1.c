/*
 *
 * CSEE 4840 Lab 2 for 2019
 *
 * Name/UNI: Please Changeto Yourname (pcy2301)
 */
#include "fbputchar.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include "usbkeyboard.h"
#include <pthread.h>

 /* Update SERVER_HOST to be the IP address of
  * the chat server you are connecting to
  */
  /* arthur.cs.columbia.edu */
#define SERVER_HOST "128.59.19.114"
#define SERVER_PORT 42000

#define BUFFER_SIZE 128
#define SCREEN_ROWS 24
#define SCREEN_COLS 64
#define INPUT_ROWS 2
#define INPUT_START_ROW 22
#define RECEIVE_START_ROW 0
#define RECEIVE_END_ROW 20
#define SEPARATOR_ROW 21

/*
 * References:
 *
 * https://web.archive.org/web/20130307100215/http://beej.us/guide/bgnet/output/html/singlepage/bgnet.html
 *
 * http://www.thegeekstuff.com/2011/12/c-socket-programming/
 *
 */

int sockfd; /* Socket file descriptor */

struct libusb_device_handle* keyboard;
uint8_t endpoint_address;

pthread_t network_thread;
void* network_thread_f(void*);

/* Global variables for text editing */
char input_buffer[SCREEN_COLS + 1] = { 0 };  /* +1 for null terminator */
int input_pos = 0;  /* Current cursor position in input buffer */
int receive_row = 0;  /* Current row for received messages */
int receive_col = 0;  /* Current column for received messages */

/* Function to clear the input area */
void clear_input_area()
{
    int row, col;
    for (row = INPUT_START_ROW; row < INPUT_START_ROW + INPUT_ROWS; row++) {
        for (col = 0; col < SCREEN_COLS; col++) {
            fbputchar(' ', row, col);
        }
    }
    memset(input_buffer, 0, sizeof(input_buffer));
    input_pos = 0;
    fbmovecursor(INPUT_START_ROW, 0);
}

/* Function to display the input buffer */
void display_input()
{
    int row = INPUT_START_ROW;
    int col = 0;
    int i;

    /* Clear current input area first */
    clear_input_area();

    /* Display the input buffer */
    for (i = 0; i < input_pos && i < SCREEN_COLS; i++) {
        fbputchar(input_buffer[i], row, col++);
        if (col >= SCREEN_COLS) {
            col = 0;
            row++;
            if (row >= INPUT_START_ROW + INPUT_ROWS) break;
        }
    }

    /* Update cursor position */
    fbmovecursor(row, col);
}

/* Function to add a character to the input buffer */
void add_to_input(char c)
{
    if (input_pos < SCREEN_COLS * INPUT_ROWS - 1) {
        /* Insert character at cursor position */
        int i;
        for (i = input_pos; i < input_pos; i++) {
            /* Shift characters to the right */
            if (i + 1 < SCREEN_COLS * INPUT_ROWS) {
                input_buffer[i + 1] = input_buffer[i];
            }
        }
        input_buffer[input_pos] = c;
        input_pos++;
        display_input();
    }
}

/* Function to delete character before cursor */
void backspace_input()
{
    if (input_pos > 0) {
        input_pos--;
        input_buffer[input_pos] = 0;
        display_input();
    }
}

/* Function to move cursor left */
void move_cursor_left()
{
    if (input_pos > 0) {
        input_pos--;
        display_input();
    }
}

/* Function to move cursor right */
void move_cursor_right()
{
    if (input_pos < strlen(input_buffer)) {
        input_pos++;
        display_input();
    }
}

/* Function to send the current input buffer */
void send_message()
{
    if (strlen(input_buffer) > 0) {
        /* Add newline and send */
        char sendBuf[BUFFER_SIZE];
        snprintf(sendBuf, sizeof(sendBuf), "%s\n", input_buffer);
        write(sockfd, sendBuf, strlen(sendBuf));

        /* Display sent message in receive area */
        int i;
        for (i = 0; i < strlen(input_buffer); i++) {
            if (receive_col >= SCREEN_COLS) {
                receive_col = 0;
                receive_row++;
                if (receive_row > RECEIVE_END_ROW) {
                    /* Simple scroll: clear and reset to top */
                    int row;
                    for (row = RECEIVE_START_ROW; row <= RECEIVE_END_ROW; row++) {
                        for (int col = 0; col < SCREEN_COLS; col++) {
                            fbputchar(' ', row, col);
                        }
                    }
                    receive_row = RECEIVE_START_ROW;
                }
            }
            fbputchar(input_buffer[i], receive_row, receive_col++);
        }

        /* Add newline in receive area */
        receive_col = 0;
        receive_row++;
        if (receive_row > RECEIVE_END_ROW) {
            receive_row = RECEIVE_START_ROW;
        }

        /* Clear input area */
        clear_input_area();
    }
}

int main()
{
    int err;

    struct sockaddr_in serv_addr;

    struct usb_keyboard_packet packet;
    int transferred;
    char keystate[12];

    if ((err = fbopen()) != 0) {
        fprintf(stderr, "Error: Could not open framebuffer: %d\n", err);
        exit(1);
    }

    /* Clear the entire screen */
    fbclear();

    /* Draw separator line */
    fbhhline(SEPARATOR_ROW);

    /* Clear input area */
    clear_input_area();

    /* Initialize receive area */
    receive_row = RECEIVE_START_ROW;
    receive_col = 0;

    /* Open the keyboard */
    if ((keyboard = openkeyboard(&endpoint_address)) == NULL) {
        fprintf(stderr, "Did not find a keyboard\n");
        exit(1);
    }

    /* Create a TCP communications socket */
    if ((sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        fprintf(stderr, "Error: Could not create socket\n");
        exit(1);
    }

    /* Get the server address */
    memset(&serv_addr, 0, sizeof(serv_addr));
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(SERVER_PORT);
    if (inet_pton(AF_INET, SERVER_HOST, &serv_addr.sin_addr) <= 0) {
        fprintf(stderr, "Error: Could not convert host IP \"%s\"\n", SERVER_HOST);
        exit(1);
    }

    /* Connect the socket to the server */
    if (connect(sockfd, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        fprintf(stderr, "Error: connect() failed.  Is the server running?\n");
        exit(1);
    }

    /* Start the network thread */
    pthread_create(&network_thread, NULL, network_thread_f, NULL);

    /* Look for and handle keypresses */
    for (;;) {
        libusb_interrupt_transfer(keyboard, endpoint_address,
            (unsigned char*)&packet, sizeof(packet),
            &transferred, 0);
        if (transferred == sizeof(packet)) {
            sprintf(keystate, "%02x %02x %02x", packet.modifiers, packet.keycode[0],
                packet.keycode[1]);
            printf("%s\n", keystate);

            if (packet.keycode[0] == 0x29) { /* ESC pressed? */
                break;
            }

            /* Handle key presses - we'll add proper USB to ASCII conversion later */
            /* For now, just handle some basic keys for testing */
            if (packet.keycode[0] != 0) {  /* Key pressed, not released */
                switch (packet.keycode[0]) {
                case 0x28: /* Enter */
                    send_message();
                    break;
                case 0x2a: /* Backspace */
                    backspace_input();
                    break;
                case 0x50: /* Left arrow */
                    move_cursor_left();
                    break;
                case 0x4f: /* Right arrow */
                    move_cursor_right();
                    break;
                default:
                    /* Simple ASCII mapping for testing - letters only */
                    if (packet.keycode[0] >= 0x04 && packet.keycode[0] <= 0x1d) {
                        /* Map to lowercase a-z */
                        char c = 'a' + (packet.keycode[0] - 0x04);
                        if (packet.modifiers & (USB_LSHIFT | USB_RSHIFT)) {
                            /* Convert to uppercase */
                            c = c - 'a' + 'A';
                        }
                        add_to_input(c);
                    }
                    break;
                }
            }
        }
    }

    /* Terminate the network thread */
    pthread_cancel(network_thread);

    /* Wait for the network thread to finish */
    pthread_join(network_thread, NULL);

    return 0;
}

void* network_thread_f(void* ignored)
{
    char recvBuf[BUFFER_SIZE];
    int n;
    /* Receive data */
    while ((n = read(sockfd, &recvBuf, BUFFER_SIZE - 1)) > 0) {
        recvBuf[n] = '\0';
        printf("%s", recvBuf);

        /* Display received message in receive area with word wrapping */
        int i;
        for (i = 0; i < n; i++) {
            if (recvBuf[i] == '\n' || recvBuf[i] == '\r') {
                receive_col = 0;
                receive_row++;
                if (receive_row > RECEIVE_END_ROW) {
                    receive_row = RECEIVE_START_ROW;
                }
            }
            else {
                if (receive_col >= SCREEN_COLS) {
                    receive_col = 0;
                    receive_row++;
                    if (receive_row > RECEIVE_END_ROW) {
                        receive_row = RECEIVE_START_ROW;
                    }
                }
                fbputchar(recvBuf[i], receive_row, receive_col++);
            }
        }
    }

    return NULL;
}