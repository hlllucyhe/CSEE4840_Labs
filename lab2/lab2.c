/*
 *
 * CSEE 4840
 *
 * Name/UNI: Lucy He/lh3365, Xiyuan Peng/xp2236, Pengpeng Wang/pw2660
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
#define INPUT_ROWS 2

static pthread_mutex_t fb_lock = PTHREAD_MUTEX_INITIALIZER;

static int chat_cursor = CHAT_TOP;
/* allow input to wrap across two input rows */
#define INPUT_MAX_LEN ((SCREEN_COLS - 2) + SCREEN_COLS) /* first row has "> " prompt */
static char input_buf[INPUT_MAX_LEN + 1];
static int input_len = 0;
static char last_sent[INPUT_MAX_LEN + 2];
/* In-memory chat buffer to support wrapping and scrolling */
#define MAX_CHAT_LINES (CHAT_BOTTOM - CHAT_TOP + 1)
static char chat_lines[MAX_CHAT_LINES][SCREEN_COLS + 1];
static int chat_line_count = 0;

static void clear_row(int row);
static void draw_divider(void);
static void chat_print_line(const char *s);
static void refresh_input_area(void);
static char hid_to_ascii(uint8_t, uint8_t);
static int should_accept_key(uint8_t, uint8_t);
static void send_input_line(void);
static int cursor_pos = 0; 

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
  cursor_pos = 0;

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

    // Arrow keys: update cursor position 
    if (kc == 0x50) { // left arrow
      if (cursor_pos > 0) cursor_pos--;
      refresh_input_area();
      continue;
    }
    if (kc == 0x4F) { //right arrow
      if (cursor_pos < input_len) cursor_pos++;
      refresh_input_area();
      continue;
    }

    // Convert HID keycode to ASCII
    char ch = hid_to_ascii(kc, mod);
    if (ch == 0) continue;

    if (ch == '\n') {               // Enter
      send_input_line();
    } 
    else if (ch == '\b') {        // Backspace
      if (cursor_pos > 0) {
        //delete at cursor position
        memmove(&input_buf[cursor_pos - 1],
                &input_buf[cursor_pos],
                (size_t)(input_len - cursor_pos + 1)); /* include '\0' */
        input_len--;
        cursor_pos--;
        //input_buf[input_len] = '\0';
        refresh_input_area();
      }
    }
    else if (ch >= 32 && ch <= 126) { // Printable
      if (input_len < INPUT_MAX_LEN) {
        // insert at cursor position
        memmove(&input_buf[cursor_pos + 1],
                &input_buf[cursor_pos],
                (size_t)(input_len - cursor_pos + 1)); /* include '\0' */
        input_buf[cursor_pos] = ch;
        input_len++;
        cursor_pos++;        
        //input_buf[input_len++] = ch;
        //input_buf[input_len] = '\0';
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
  if (cursor_pos < 0) cursor_pos = 0;
  if (cursor_pos > input_len) cursor_pos = input_len;

  /* Build wrapped lines from input `s` */
  char cur[SCREEN_COLS + 1];
  int idx = 0;

  for (const char *p = s; *p != '\0'; ++p) {
    char c = *p;
    if (c == '\r') continue;
    if (c == '\n') {
      /* flush current chunk */
      cur[idx] = '\0';
      if (chat_line_count < MAX_CHAT_LINES) {
        strncpy(chat_lines[chat_line_count], cur, SCREEN_COLS);
        chat_lines[chat_line_count][SCREEN_COLS] = '\0';
        chat_line_count++;
      } else {
        memmove(chat_lines, chat_lines + 1, (size_t)(MAX_CHAT_LINES - 1) * (SCREEN_COLS + 1));
        strncpy(chat_lines[MAX_CHAT_LINES - 1], cur, SCREEN_COLS);
        chat_lines[MAX_CHAT_LINES - 1][SCREEN_COLS] = '\0';
      }
      idx = 0;
      continue;
    }

    cur[idx++] = c;

    if (idx >= SCREEN_COLS) {
      cur[idx] = '\0';
      if (chat_line_count < MAX_CHAT_LINES) {
        strncpy(chat_lines[chat_line_count], cur, SCREEN_COLS);
        chat_lines[chat_line_count][SCREEN_COLS] = '\0';
        chat_line_count++;
      } else {
        memmove(chat_lines, chat_lines + 1, (size_t)(MAX_CHAT_LINES - 1) * (SCREEN_COLS + 1));
        strncpy(chat_lines[MAX_CHAT_LINES - 1], cur, SCREEN_COLS);
        chat_lines[MAX_CHAT_LINES - 1][SCREEN_COLS] = '\0';
      }
      idx = 0;
    }
  }

  /* flush remaining partial chunk */
  if (idx > 0) {
    cur[idx] = '\0';
    if (chat_line_count < MAX_CHAT_LINES) {
      strncpy(chat_lines[chat_line_count], cur, SCREEN_COLS);
      chat_lines[chat_line_count][SCREEN_COLS] = '\0';
      chat_line_count++;
    } else {
      memmove(chat_lines, chat_lines + 1, (size_t)(MAX_CHAT_LINES - 1) * (SCREEN_COLS + 1));
      strncpy(chat_lines[MAX_CHAT_LINES - 1], cur, SCREEN_COLS);
      chat_lines[MAX_CHAT_LINES - 1][SCREEN_COLS] = '\0';
    }
  }

  /* Redraw chat area from buffer */
  for (int i = 0; i < MAX_CHAT_LINES; ++i) {
    char out[SCREEN_COLS + 1];
    memset(out, ' ', SCREEN_COLS);
    out[SCREEN_COLS] = '\0';
    if (i < chat_line_count) {
      size_t l = strnlen(chat_lines[i], SCREEN_COLS);
      if (l > 0) memcpy(out, chat_lines[i], l);
    }
    fbputs(out, CHAT_TOP + i, 0);
  }

  /* update cursor position */
  chat_cursor = CHAT_TOP + chat_line_count;
  if (chat_cursor > CHAT_BOTTOM + 1) chat_cursor = CHAT_BOTTOM + 1;

  pthread_mutex_unlock(&fb_lock);
}

static void refresh_input_area(void) {
  pthread_mutex_lock(&fb_lock);
  clear_row(INPUT_ROW1);
  clear_row(INPUT_ROW2);

  /* First row: prompt + as much as fits on first row (SCREEN_COLS - 2) */
  char line1[SCREEN_COLS + 1];
  int first_len = (input_len > (SCREEN_COLS - 2)) ? (SCREEN_COLS - 2) : input_len;
  memset(line1, ' ', SCREEN_COLS);
  line1[SCREEN_COLS] = '\0';
  line1[0] = '>';
  line1[1] = ' ';
  if (first_len > 0) {
    memcpy(&line1[2], input_buf, (size_t)first_len);
  }
  fbputs(line1, INPUT_ROW1, 0);

  /* Second row: remaining input (up to SCREEN_COLS) */
  char line2[SCREEN_COLS + 1];
  memset(line2, ' ', SCREEN_COLS);
  line2[SCREEN_COLS] = '\0';
  int rem = input_len - first_len;
  if (rem > 0) {
    int copy_len = rem > SCREEN_COLS ? SCREEN_COLS : rem;
    memcpy(line2, &input_buf[first_len], (size_t)copy_len);
  }
  fbputs(line2, INPUT_ROW2, 0);

  // Draw cursor (simple visible marker) 
  {
    int first_cap = SCREEN_COLS - 2;          //chars available after "> " 
    int row, col;

    if (cursor_pos <= first_cap) {
      row = INPUT_ROW1;
      col = 2 + cursor_pos;
      if (col >= SCREEN_COLS) col = SCREEN_COLS - 1;
    } else {
      row = INPUT_ROW2;
      col = cursor_pos - first_cap;
      if (col >= SCREEN_COLS) col = SCREEN_COLS - 1;
    }

    fbputchar('|', row, col);
  }

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
    snprintf(me_line, sizeof(me_line), "me: %s", input_buf);
    chat_print_line(me_line);

    /* send input + newline in a single buffer and ensure all bytes are written */
    char sendBuf[INPUT_MAX_LEN + 2]; /* input + newline */
    int sendLen = 0;

    memcpy(sendBuf, input_buf, (size_t)input_len);
    sendLen = input_len;

    sendBuf[sendLen++] = '\n';

    /* save last sent line so we can ignore our own echo */
    memcpy(last_sent, sendBuf, (size_t)sendLen);
    last_sent[sendLen] = '\0';

    int sent = 0;
    while (sent < sendLen) {
        ssize_t w = write(sockfd, sendBuf + sent, (size_t)(sendLen - sent));
        if (w <= 0) break;
        sent += (int)w;
    }

    /* clear the input buffer after sending */
    memset(input_buf, 0, sizeof(input_buf));
    input_len = 0;
    cursor_pos = 0;
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
 
  /*while ((n = read(sockfd, &recvBuf, BUFFER_SIZE - 1)) > 0) {
    recvBuf[n] = '\0';
    printf("%s", recvBuf);
    chat_print_line(recvBuf);
  }
  */
  while ((n = read(sockfd, recvBuf, BUFFER_SIZE - 1)) > 0) {
      recvBuf[n] = '\0';

      if (strcmp(recvBuf, last_sent) == 0) {
          continue;  // ignore own broadcast
      }

      chat_print_line(recvBuf);
  }
  return NULL;
}

