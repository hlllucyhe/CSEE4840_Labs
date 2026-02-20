/*
 *
 * CSEE 4840 Lucy He/lh3365, Xiyuan Peng/xp2236, Pengpeng Wang/pw2660
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

/*layout*/
#define SCREEN_COLS 64
#define SCREEN_ROWS 24

#define DIVIDER_ROW 21
#define CHAT_TOP 1
#define CHAT_BOTTOM (DIVIDER_ROW - 1)
#define INPUT_ROW1 (DIVIDER_ROW + 1)
#define INPUT_ROW2 (DIVIDER_ROW + 2)

static pthread_mutex_t fb_lock = PTHREAD_MUTEX_INITIALIZER;

static int chat_cursor = CHAT_TOP;
static char input_buf[SCREEN_COLS + 1];
static int input_len = 0;

static void clear_row(int row);
static void draw_divider(void);
static void chat_print_line(const char *s);
static void refresh_input_area(void);
static char hid_to_ascii(uint8_t, uint8_t);
static int should_accept_key(uint8_t, uint8_t);
static void send_input_line(void);

/*
 * References:
 *
 * https://web.archive.org/web/20130307100215/http://beej.us/guide/bgnet/output/html/singlepage/bgnet.html
 *
 * http://www.thegeekstuff.com/2011/12/c-socket-programming/
 * 
 */

int sockfd; /* Socket file descriptor */

struct libusb_device_handle *keyboard;
uint8_t endpoint_address;

pthread_t network_thread;
void *network_thread_f(void *);

int main()
{
  int err, col;

  struct sockaddr_in serv_addr;

  struct usb_keyboard_packet packet;
  int transferred;
  char keystate[12];

  if ((err = fbopen()) != 0) {
    fprintf(stderr, "Error: Could not open framebuffer: %d\n", err);
    exit(1);
  }

  /* Clear screen at startup */
  fbclear();
  
  /*draw divider*/
  draw_divider();
  chat_cursor = CHAT_TOP;
  input_len = 0;
  input_buf[0] = '\0';
  refresh_input_area();

  /* Draw rows of asterisks across the top and bottom of the screen */
  /*for (col = 0 ; col < 64 ; col++) {
    fbputchar('*', 0, col);
    fbputchar('*', 23, col);
  }

  fbputs("Hello CSEE 4840 World!", 4, 10);*/

  /* Open the keyboard */
  if ( (keyboard = openkeyboard(&endpoint_address)) == NULL ) {
    fprintf(stderr, "Did not find a keyboard\n");
    exit(1);
  }
    
  /* Create a TCP communications socket */
  if ( (sockfd = socket(AF_INET, SOCK_STREAM, 0)) < 0 ) {
    fprintf(stderr, "Error: Could not create socket\n");
    exit(1);
  }

  /* Get the server address */
  memset(&serv_addr, 0, sizeof(serv_addr));
  serv_addr.sin_family = AF_INET;
  serv_addr.sin_port = htons(SERVER_PORT);
  if ( inet_pton(AF_INET, SERVER_HOST, &serv_addr.sin_addr) <= 0) {
    fprintf(stderr, "Error: Could not convert host IP \"%s\"\n", SERVER_HOST);
    exit(1);
  }

  /* Connect the socket to the server */
  if ( connect(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) {
    fprintf(stderr, "Error: connect() failed.  Is the server running?\n");
    exit(1);
  }

  /* Start the network thread */
  pthread_create(&network_thread, NULL, network_thread_f, NULL);

  /* Look for and handle keypresses */
  for (;;) {
    libusb_interrupt_transfer(keyboard, endpoint_address,
			      (unsigned char *) &packet, sizeof(packet),
			      &transferred, 0);
  
    if (transferred != sizeof(packet)) continue;

    uint8_t kc  = packet.keycode[0];
    uint8_t mod = packet.modifiers;

    // ESC quits
    if (kc == 0x29) break;

    // Ignore repeats while holding a key (optional but recommended)
    if (!should_accept_key(kc, mod)) continue;

    // Convert HID keycode to ASCII
    char ch = hid_to_ascii(kc, mod);
    if (ch == 0) continue;

    if (ch == '\n') {               // Enter
      send_input_line();
    } 
    else if (ch == '\b') {        // Backspace
      if (input_len > 0) {
      input_len--;
      input_buf[input_len] = '\0';
      refresh_input_area();
      }
    }
    else if (ch >= 32 && ch <= 126) { // Printable
      if (input_len < SCREEN_COLS - 3) {
        input_buf[input_len++] = ch;
        input_buf[input_len] = '\0';
        refresh_input_area();
      }
    }
  }

  /* Terminate the network thread */
  pthread_cancel(network_thread);

  /* Wait for the network thread to finish */
  pthread_join(network_thread, NULL);

  return 0;
}

static void clear_row(int row) {
  char blank[SCREEN_COLS + 1];
  memset(blank, ' ', SCREEN_COLS);
  blank[SCREEN_COLS] = '\0';
  fbputs(blank, row, 0);
}

static void draw_divider(void) {
  char line[SCREEN_COLS + 1];
  memset(line, '-', SCREEN_COLS);
  line[SCREEN_COLS] = '\0';
  fbputs(line, DIVIDER_ROW, 0);
}

static void chat_print_line(const char *s) {
  pthread_mutex_lock(&fb_lock);

  if (chat_cursor > CHAT_BOTTOM) {
    for (int r = CHAT_TOP; r <= CHAT_BOTTOM; r++)
      clear_row(r);
    chat_cursor = CHAT_TOP;
  }

  clear_row(chat_cursor);

  char tmp[SCREEN_COLS + 1];
  snprintf(tmp, sizeof(tmp), "%.*s", SCREEN_COLS, s);
  fbputs(tmp, chat_cursor, 0);

  chat_cursor++;

  pthread_mutex_unlock(&fb_lock);
}

static void refresh_input_area(void) {
  pthread_mutex_lock(&fb_lock);

  clear_row(INPUT_ROW1);
  clear_row(INPUT_ROW2);

  char line[SCREEN_COLS + 1];
  snprintf(line, sizeof(line), "> %s", input_buf);
  fbputs(line, INPUT_ROW1, 0);

  pthread_mutex_unlock(&fb_lock);
}

static int is_shift_pressed(uint8_t modifiers) {
  /* Left Shift = 0x02, Right Shift = 0x20 */
  return ((modifiers & 0x02) || (modifiers & 0x20));
}

static char hid_to_ascii(uint8_t keycode, uint8_t modifiers) {
  int shift = is_shift_pressed(modifiers);

  /* Special keys */
  if (keycode == 0x28) return '\n'; /* Enter */
  if (keycode == 0x2A) return '\b'; /* Backspace */
  if (keycode == 0x2C) return ' ';  /* Space */

  /* Letters: HID 0x04..0x1D => a..z */
  if (keycode >= 0x04 && keycode <= 0x1D) {
    char base = (char)('a' + (keycode - 0x04));
    return shift ? (char)(base - 'a' + 'A') : base;
  }

  /* Numbers row: HID 0x1E..0x27 => 1..0 */
  if (keycode >= 0x1E && keycode <= 0x27) {
    static const char unshift[] = { '1','2','3','4','5','6','7','8','9','0' };
    static const char shifted[] = { '!','@','#','$','%','^','&','*','(',')' };
    int idx = (int)(keycode - 0x1E);
    return shift ? shifted[idx] : unshift[idx];
  }

  /* Punctuation (US keyboard typical) */
  switch (keycode) {
    case 0x2D: return shift ? '_' : '-';  /* - _ */
    case 0x2E: return shift ? '+' : '=';  /* = + */
    case 0x2F: return shift ? '{' : '[';  /* [ { */
    case 0x30: return shift ? '}' : ']';  /* ] } */
    case 0x31: return shift ? '|' : '\\'; /* \ | */
    case 0x33: return shift ? ':' : ';';  /* ; : */
    case 0x34: return shift ? '"' : '\''; /* ' " */
    case 0x35: return shift ? '~' : '`';  /* ` ~ */
    case 0x36: return shift ? '<' : ',';  /* , < */
    case 0x37: return shift ? '>' : '.';  /* . > */
    case 0x38: return shift ? '?' : '/';  /* / ? */
    default: return 0; /* unmapped / ignored */
  }
}

/* Simple de-repeat filter: ignore identical consecutive key packets */
static uint8_t last_kc = 0;
static uint8_t last_mod = 0;

static int should_accept_key(uint8_t kc, uint8_t mod) {
  if (kc == 0) { /* release */
    last_kc = 0;
    last_mod = 0;
    return 0;
  }
  if (kc == last_kc && mod == last_mod) return 0;
  last_kc = kc;
  last_mod = mod;
  return 1;
}

/* Send current input buffer to server and also record in chat area */
static void send_input_line(void) {
  if (input_len <= 0) return;

  char me_line[SCREEN_COLS + 32];
  snprintf(me_line, sizeof(me_line), "me: %s\n", input_buf);
  chat_print_line(me_line);

  write(sockfd, input_buf, (size_t)input_len);

  input_len = 0;
  input_buf[0] = '\0';
  refresh_input_area();
}



void *network_thread_f(void *ignored)
{
  char recvBuf[BUFFER_SIZE];
  int n;
  //Receive data
  /*char lineBuf[512]; 
  int lineLen = 0;

  while ((n = read(sockfd, &recvBuf, BUFFER_SIZE - 1)) > 0) {
      recvBuf[n] = '\0';

      for (int i = 0; i < n; i++) {
          char c = recvBuf[i];
          if (c == '\r') continue;   // ignore CR
          if (c == '\n') {
              lineBuf[lineLen] = '\0';
              if (lineLen > 0) {
                  chat_print_line(lineBuf);
              }
              lineLen = 0;
          } else {
              if (lineLen < sizeof(lineBuf) - 1) {
                  lineBuf[lineLen++] = c;
              }
          }
      }
  }*/
 
  while ( (n = read(sockfd, &recvBuf, BUFFER_SIZE - 1)) > 0 ) {
    recvBuf[n] = '\0';
    printf("%s", recvBuf);
    chat_print_line(recvBuf);
  }

  return NULL;
}

