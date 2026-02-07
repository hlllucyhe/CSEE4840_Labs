// CSEE 4840 Lab 1: Run and Display Collatz Conjecture Iteration Counts
//
// Spring 2023
//
// By: <your name here>
// Uni: <your uni here>

module lab1( input logic        CLOCK_50,  // 50 MHz Clock input
	     
	     input logic [3:0] 	KEY, // Pushbuttons; KEY[0] is rightmost

	     input logic [9:0] 	SW, // Switches; SW[0] is rightmost

	     // 7-segment LED displays; HEX0 is rightmost
	     output logic [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,

	     output logic [9:0] LEDR // LEDs above the switches; LED[0] on right
	     );

   logic 			clk, go, done;   
   logic [31:0] 		start;
   logic [15:0] 		count;

   logic [11:0] 		n;
   
   assign clk = CLOCK_50;
 
   range #(256, 8) // RAM_WORDS = 256, RAM_ADDR_BITS = 8)
         r ( .* ); // Connect everything with matching names

   // Replace this comment and the code below it with your own code;
   // ------------------------------------------------------------
   // BUTTON HANDLING (Debounced)
   // ------------------------------------------------------------

   // Buttons are active-low on DE boards → invert first
   logic btn0_raw, btn1_raw, btn2_raw, btn3_raw;
   assign btn0_raw = ~KEY[0];  // increment
   assign btn1_raw = ~KEY[1];  // decrement
   assign btn2_raw = ~KEY[2];  // reset offset
   assign btn3_raw = ~KEY[3];  // go

   // Debounced outputs
   logic k0, k1, k2, k3;

   debounce d0(.clk(clk), .btn_in(btn0_raw), .btn_out(k0));
   debounce d1(.clk(clk), .btn_in(btn1_raw), .btn_out(k1));
   debounce d2(.clk(clk), .btn_in(btn2_raw), .btn_out(k2));
   debounce d3(.clk(clk), .btn_in(btn3_raw), .btn_out(k3));

   // ------------------------------------------------------------
   // Generate single-cycle go pulse from KEY[3]
   // ------------------------------------------------------------
   logic k3_d;
   always_ff @(posedge clk) begin
      k3_d <= k3;
   end
   assign go = k3 & ~k3_d;

   // ------------------------------------------------------------
   // Offset control (select which of 256 values to display)
   // ------------------------------------------------------------
   logic [7:0]  offset;
   logic [21:0] repeat_ctr;  // hold-to-repeat timing (~5-10Hz)

   always_ff @(posedge clk) begin
      if (k2) begin
         offset     <= 8'd0;
         repeat_ctr <= 22'd0;
      end else begin

         // Reset offset when new computation starts
         if (go)
            offset <= 8'd0;

         if (k0 || k1) begin
            repeat_ctr <= repeat_ctr + 22'd1;

            // Change offset only when counter wraps
            if (&repeat_ctr) begin
               if (k0 && !k1) begin
                  if (offset != 8'hFF)
                     offset <= offset + 8'd1;
               end
               else if (k1 && !k0) begin
                  if (offset != 8'd0)
                     offset <= offset - 8'd1;
               end
            end
         end
         else begin
            repeat_ctr <= 22'd0;
         end
      end
   end

   // ------------------------------------------------------------
   // Drive range.start
   // - While running (done=0): start = base n from switches
   // - After done=1: start = read address (offset)
   // ------------------------------------------------------------
   always_comb begin
      if (done)
         start = {24'd0, offset};      // read mode
      else
         start = {22'd0, SW[9:0]};     // run mode
   end

   // ------------------------------------------------------------
   // Compute displayed n = base + offset
   // ------------------------------------------------------------
   logic [31:0] n_full;
   assign n_full = {22'd0, SW[9:0]} + {24'd0, offset};
   assign n      = n_full[11:0];

   // ------------------------------------------------------------
   // Display wiring using provided hex7seg module
   // Right 3 HEX (HEX2..HEX0): iteration count
   // Left  3 HEX (HEX5..HEX3): n
   // ------------------------------------------------------------

   hex7seg h0(.a(count[3:0]),  .y(HEX0));
   hex7seg h1(.a(count[7:4]),  .y(HEX1));
   hex7seg h2(.a(count[11:8]), .y(HEX2));

   hex7seg h3(.a(n[3:0]),      .y(HEX3));
   hex7seg h4(.a(n[7:4]),      .y(HEX4));
   hex7seg h5(.a(n[11:8]),     .y(HEX5));

   // LEDs mirror switches
   assign LEDR = SW;


endmodule


module debounce #(parameter N = 19)
(
    input  logic clk,
    input  logic btn_in,
    output logic btn_out
);

    logic [N-1:0] counter;
    logic sync0, sync1;

    // Synchronizer
    always_ff @(posedge clk) begin
        sync0 <= btn_in;
        sync1 <= sync0;
    end

    always_ff @(posedge clk) begin
        if (sync1 == btn_out)
            counter <= '0;
        else begin
            counter <= counter + 1;
            if (&counter)
                btn_out <= sync1;
        end
    end

endmodule