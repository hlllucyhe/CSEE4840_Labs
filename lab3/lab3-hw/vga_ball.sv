/*
 * Avalon memory-mapped peripheral that generates VGA
 *
 * Stephen A. Edwards
 * Columbia University
 *
 * Register map (16-bit writedata):
 *
 * Word Offset   15 ... 0     Meaning
 *        0      X coordinate  Ball X position (0-639)
 *        1      Y coordinate  Ball Y position (0-479)
 */

module vga_ball(input logic        clk,
                input logic        reset,
                input logic [15:0] writedata,
                input logic        write,
                input logic        chipselect,
                input logic [2:0]  address,

                output logic [7:0] VGA_R, VGA_G, VGA_B,
                output logic       VGA_CLK, VGA_HS, VGA_VS,
                                   VGA_BLANK_n,
                output logic       VGA_SYNC_n);

   logic [10:0]  hcount;
   logic [9:0]   vcount;

   // Ball position registers
   logic [15:0]  ball_x, ball_y;

   // Ball radius (in pixels)
   parameter BALL_RADIUS = 10'd20;

   // Ball color: white
   parameter [7:0] BALL_R = 8'hff, BALL_G = 8'hff, BALL_B = 8'hff;

   // Background color: dark blue
   parameter [7:0] BG_R = 8'h80, BG_G = 8'h00, BG_B = 8'h80;

   vga_counters counters(.clk50(clk), .*);

   // Write ball position from software via Avalon bus
   always_ff @(posedge clk) begin
      if (reset) begin
         ball_x <= 16'd320;  // Start at center X
         ball_y <= 16'd240;  // Start at center Y
      end else if (chipselect && write) begin
         case (address)
           3'h0 : ball_x <= writedata;
           3'h1 : ball_y <= writedata;
         endcase
      end
   end

   // Compute whether current pixel is inside the ball (circle)
   // Use squared distance to avoid sqrt:
   // (hpixel - ball_x)^2 + (vpixel - ball_y)^2 <= BALL_RADIUS^2
   logic [10:0] hpixel;
   assign hpixel = hcount[10:1]; // actual pixel column (0-639)

   logic signed [11:0] dx, dy;
   assign dx = $signed({1'b0, hpixel}) - $signed({1'b0, ball_x[9:0]});
   assign dy = $signed({1'b0, vcount}) - $signed({1'b0, ball_y[9:0]});

   logic in_ball;
   assign in_ball = (dx*dx + dy*dy) <= (BALL_RADIUS * BALL_RADIUS);

   // VGA output
   always_comb begin
      {VGA_R, VGA_G, VGA_B} = {8'h0, 8'h0, 8'h0};
      if (VGA_BLANK_n) begin
         if (in_ball)
            {VGA_R, VGA_G, VGA_B} = {BALL_R, BALL_G, BALL_B};
         else
            {VGA_R, VGA_G, VGA_B} = {BG_R, BG_G, BG_B};
      end
   end

endmodule


module vga_counters(
 input logic         clk50, reset,
 output logic [10:0] hcount,  // hcount[10:1] is pixel column
 output logic [9:0]  vcount,  // vcount[9:0] is pixel row
 output logic        VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_n, VGA_SYNC_n);

/*
 * 640 X 480 VGA timing for a 50 MHz clock: one pixel every other cycle
 * 
 * HCOUNT 1599 0             1279       1599 0
 *             _______________              ________
 * ___________|    Video      |____________|  Video
 * 
 * 
 * |SYNC| BP |<-- HACTIVE -->|FP|SYNC| BP |<-- HACTIVE
 *       _______________________      _____________
 * |____|       VGA_HS          |____|
 */
   // Parameters for hcount
   parameter HACTIVE      = 11'd 1280,
             HFRONT_PORCH = 11'd 32,
             HSYNC        = 11'd 192,
             HBACK_PORCH  = 11'd 96,   
             HTOTAL       = HACTIVE + HFRONT_PORCH + HSYNC +
                            HBACK_PORCH; // 1600
   
   // Parameters for vcount
   parameter VACTIVE      = 10'd 480,
             VFRONT_PORCH = 10'd 10,
             VSYNC        = 10'd 2,
             VBACK_PORCH  = 10'd 33,
             VTOTAL       = VACTIVE + VFRONT_PORCH + VSYNC +
                            VBACK_PORCH; // 525

   logic endOfLine;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          hcount <= 0;
     else if (endOfLine) hcount <= 0;
     else                hcount <= hcount + 11'd 1;

   assign endOfLine = hcount == HTOTAL - 1;
       
   logic endOfField;
   
   always_ff @(posedge clk50 or posedge reset)
     if (reset)          vcount <= 0;
     else if (endOfLine)
       if (endOfField)   vcount <= 0;
       else              vcount <= vcount + 10'd 1;

   assign endOfField = vcount == VTOTAL - 1;

   // Horizontal sync: from 0x520 to 0x5DF (0x57F)
   // 101 0010 0000 to 101 1101 1111
   assign VGA_HS = !( (hcount[10:8] == 3'b101) &
                      !(hcount[7:5] == 3'b111));
   assign VGA_VS = !( vcount[9:1] == (VACTIVE + VFRONT_PORCH) / 2);

   assign VGA_SYNC_n = 1'b0; // For putting sync on the green signal; unused
   
   // Horizontal active: 0 to 1279     Vertical active: 0 to 479
   assign VGA_BLANK_n = !( hcount[10] & (hcount[9] | hcount[8]) ) &
                        !( vcount[9] | (vcount[8:5] == 4'b1111) );

   /* VGA_CLK is 25 MHz
    *             __    __    __
    * clk50    __|  |__|  |__|
    *        
    *             _____       __
    * hcount[0]__|     |_____|
    */
   assign VGA_CLK = hcount[0]; // 25 MHz clock: rising edge sensitive
   
endmodule
