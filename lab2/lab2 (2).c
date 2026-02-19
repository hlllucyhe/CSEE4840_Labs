/*
 * CSEE 4840 Lab 2: Chat Client
 *
 * Sample implementation showing how to use the enhanced framebuffer functions
 *
 * Names: [Your names here]
 * UNIs: [Your UNIs here]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <libusb-1.0/libusb.h>
#include "fbputchar.h"
#include "usbkeyboard.h"

/* Server configuration */
#define IPADDR(a,b,c,d) (htonl(((a)<<24)|((b)<<16)|((c)<<8)|(d)))
#define SERVER_HOST IPADDR(128,59,19,114)  /* arthur.cs.columbia.edu */
#define SERVER_PORT htons(42000)

/* Screen layout configuration */
#define INPUT_ROWS 2      /* Bottom 2 rows for input */
#define SEPARATOR_ROW     /* Will be calculated based on screen size */

/* Input buffer */
#define MAX_INPUT_LEN 512
char input_buffer[MAX_INPUT_LEN];
int input_pos = 0;
int cursor_col = 0;

/* Screen dimensions */
int screen_rows = 0;
int screen_cols = 0;
int message_start_row = 0;
int message_end_row = 0;
int input_start_row = 0;
int current_message_row = 0;

/* Network socket */
int sockfd = -1;

/* Thread synchronization */
pthread_mutex_t screen_mutex = PTHREAD_MUTEX_INITIALIZER;

/* USB keyboard keycodes */
#define KEY_RETURN 0x28
#define KEY_BACKSPACE 0x2A
#define KEY_LEFT 0x50
#define KEY_RIGHT 0x4F
#define KEY_ESC 0x29

/* Modifier keys */
#define MOD_LSHIFT 0x02
#define MOD_RSHIFT 0x20

/* USB keycode to ASCII conversion table (without shift) */
const char keycode_to_ascii[] = {
  0,   0,   0,   0,   'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
  'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x',
  'y', 'z', '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '\n', 0,
  '\b', '\t', ' ', '-', '=', '[', ']', '\\', 0, ';', '\'', '`', ',', '.',
  '/', 0
};

/* USB keycode to ASCII conversion table (with shift) */
const char keycode_to_ascii_shift[] = {
  0,   0,   0,   0,   'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
  'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
  'Y', 'Z', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '\n', 0,
  '\b', '\t', ' ', '_', '+', '{', '}', '|', 0, ':', '"', '~', '<', '>',
  '?', 0
};

/*
 * Initialize the screen layout
 */
void init_screen(void)
{
  fbget_dimensions(&screen_rows, &screen_cols);
  
  /* Calculate screen regions */
  input_start_row = screen_rows - INPUT_ROWS;
  message_start_row = 0;
  message_end_row = input_start_row - 2;  /* Leave one row for separator */
  current_message_row = message_start_row;
  
  /* Clear screen */
  fbclear();
  
  /* Draw separator line */
  fbdraw_hline(input_start_row - 1, 255, 255, 255);
  
  /* Draw welcome message */
  pthread_mutex_lock(&screen_mutex);
  fbputs("CSEE 4840 Chat Client", message_start_row, 0);
  fbputs("Type messages and press Enter to send.", message_start_row + 1, 0);
  pthread_mutex_unlock(&screen_mutex);
  
  current_message_row = message_start_row + 3;
}

/*
 * Display a message in the message area (top of screen)
 */
void display_message(const char *msg)
{
  pthread_mutex_lock(&screen_mutex);
  
  /* Check if we need to scroll */
  if (current_message_row > message_end_row) {
    fbscroll_region(message_start_row, message_end_row);
    current_message_row = message_end_row;
  }
  
  /* Display message with wrapping */
  int lines = fbputs_wrap(msg, current_message_row, 0, screen_cols - 1, 255, 255, 255);
  current_message_row += lines;
  
  pthread_mutex_unlock(&screen_mutex);
}

/*
 * Update the input display area (bottom of screen)
 */
void update_input_display(void)
{
  pthread_mutex_lock(&screen_mutex);
  
  /* Clear input area */
  fbclear_region(input_start_row, 0, screen_rows - 1, screen_cols - 1);
  
  /* Display input buffer */
  int row = input_start_row;
  int col = 0;
  for (int i = 0; i < input_pos && i < MAX_INPUT_LEN; i++) {
    if (col >= screen_cols) {
      col = 0;
      row++;
      if (row >= screen_rows) break;
    }
    fbputchar(input_buffer[i], row, col, 255, 255, 0);  /* Yellow text */
    col++;
  }
  
  /* Draw cursor */
  int cursor_row = input_start_row + (cursor_col / screen_cols);
  int cursor_col_pos = cursor_col % screen_cols;
  fbdraw_cursor(cursor_row, cursor_col_pos, 0, 255, 255, 0);  /* Vertical bar, yellow */
  
  pthread_mutex_unlock(&screen_mutex);
}

/*
 * Send the current input buffer to the server
 */
void send_message(void)
{
  if (input_pos == 0) return;
  
  /* Add newline and send */
  input_buffer[input_pos] = '\n';
  write(sockfd, input_buffer, input_pos + 1);
  
  /* Display sent message */
  input_buffer[input_pos] = '\0';
  char display_buf[MAX_INPUT_LEN + 10];
  snprintf(display_buf, sizeof(display_buf), "You: %s", input_buffer);
  display_message(display_buf);
  
  /* Clear input */
  input_pos = 0;
  cursor_col = 0;
  memset(input_buffer, 0, sizeof(input_buffer));
  
  update_input_display();
}

/*
 * Network thread - receives messages from server
 */
void *network_thread(void *arg)
{
  char buffer[1024];
  int n;
  
  while (1) {
    n = read(sockfd, buffer, sizeof(buffer) - 1);
    if (n <= 0) break;
    
    buffer[n] = '\0';
    
    /* Remove trailing newline if present */
    if (n > 0 && buffer[n-1] == '\n') {
      buffer[n-1] = '\0';
    }
    
    /* Display received message */
    display_message(buffer);
  }
  
  return NULL;
}

/*
 * Convert USB keycode to ASCII character
 */
char keycode_to_char(unsigned char keycode, unsigned char modifier)
{
  int shifted = (modifier & (MOD_LSHIFT | MOD_RSHIFT)) != 0;
  
  if (keycode < sizeof(keycode_to_ascii)) {
    if (shifted) {
      return keycode_to_ascii_shift[keycode];
    } else {
      return keycode_to_ascii[keycode];
    }
  }
  
  return 0;
}

/*
 * Handle keyboard input
 */
void handle_keyboard(void)
{
  struct libusb_device_handle *keyboard;
  unsigned char buffer[8];
  int transferred;
  unsigned char last_keycode = 0;
  
  /* Open keyboard */
  keyboard = openkeyboard();
  if (keyboard == NULL) {
    fprintf(stderr, "Did not find a keyboard\n");
    exit(1);
  }
  
  while (1) {
    /* Read from keyboard */
    int r = libusb_interrupt_transfer(keyboard, 
                                      LIBUSB_ENDPOINT_IN | 1,
                                      buffer, 
                                      sizeof(buffer),
                                      &transferred,
                                      0);
    
    if (r != 0 || transferred != 8) continue;
    
    unsigned char modifier = buffer[0];
    unsigned char keycode = buffer[2];
    
    /* Detect key press (transition from no key to key) */
    if (keycode != 0 && last_keycode == 0) {
      /* Special keys */
      if (keycode == KEY_ESC) {
        /* Exit program */
        return;
      } else if (keycode == KEY_RETURN) {
        /* Send message */
        send_message();
      } else if (keycode == KEY_BACKSPACE) {
        /* Delete character */
        if (input_pos > 0) {
          input_pos--;
          cursor_col--;
          input_buffer[input_pos] = '\0';
          update_input_display();
        }
      } else if (keycode == KEY_LEFT) {
        /* Move cursor left */
        if (cursor_col > 0) {
          cursor_col--;
          update_input_display();
        }
      } else if (keycode == KEY_RIGHT) {
        /* Move cursor right */
        if (cursor_col < input_pos) {
          cursor_col++;
          update_input_display();
        }
      } else {
        /* Regular character */
        char c = keycode_to_char(keycode, modifier);
        if (c != 0 && input_pos < MAX_INPUT_LEN - 1) {
          /* Insert character at cursor position */
          if (cursor_col < input_pos) {
            /* Insert in middle - shift characters right */
            memmove(&input_buffer[cursor_col + 1], 
                    &input_buffer[cursor_col],
                    input_pos - cursor_col);
          }
          input_buffer[cursor_col] = c;
          input_pos++;
          cursor_col++;
          update_input_display();
        }
      }
    }
    
    last_keycode = keycode;
  }
}

/*
 * Main function
 */
int main(int argc, char **argv)
{
  struct sockaddr_in serv_addr = { AF_INET, SERVER_PORT, { SERVER_HOST } };
  pthread_t net_thread;
  
  /* Initialize framebuffer */
  if (fbopen() != 0) {
    fprintf(stderr, "Error: Failed to open framebuffer\n");
    exit(1);
  }
  
  /* Initialize screen */
  init_screen();
  
  /* Connect to server */
  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if (sockfd < 0) {
    fprintf(stderr, "Error: Failed to create socket\n");
    exit(1);
  }
  
  if (connect(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) {
    fprintf(stderr, "Error: Failed to connect to server\n");
    fprintf(stderr, "Is the server running at the configured address?\n");
    exit(1);
  }
  
  display_message("Connected to chat server!");
  
  /* Start network thread */
  pthread_create(&net_thread, NULL, network_thread, NULL);
  
  /* Handle keyboard input (blocks) */
  handle_keyboard();
  
  /* Cleanup */
  pthread_join(net_thread, NULL);
  close(sockfd);
  
  /* Clear screen on exit */
  fbclear();
  
  return 0;
}
