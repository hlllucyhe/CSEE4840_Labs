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
   logic [7:0]  offset;        // 0..255 within the 256-entry RAM
   logic [21:0] repeat_ctr;    // hold-to-repeat counter
   logic        k3_prev;       // for edge detect on KEY[3]
   logic [9:0]  base;          // latched switch value (so switches don't update display)

   // 1-cycle go pulse on KEY[3] press (KEYs are active-low)
   always_ff @(posedge clk) begin
      k3_prev <= ~KEY[3];
   end
   assign go = (~KEY[3]) & ~k3_prev;

   // Latch base when starting a run (so SW changes afterward don't affect display/run)
   always_ff @(posedge clk) begin
      if (go || ~KEY[2]) begin
          if (SW == 10'd0)
            base <= 10'd1;
          else
            base <= SW;
      end
   end

   // Offset control:
   // KEY[0] increment, KEY[1] decrement, KEY[2] sets display to switches (base=SW, offset=0)
   always_ff @(posedge clk) begin
      if (~KEY[2]) begin
         offset     <= 8'd0;     // display exactly the (latched) switch value
         repeat_ctr <= 22'd0;
      end else begin
         if ((~KEY[0]) || (~KEY[1])) begin
            repeat_ctr <= repeat_ctr + 22'd1;

            // change on wrap (lab suggests using a 22-bit counter and updating on wrap)
            if (&repeat_ctr) begin
               if ((~KEY[0]) && KEY[1]) begin
                  if (offset != 8'hFF) offset <= offset + 8'd1;
               end else if ((~KEY[1]) && KEY[0]) begin
                  if (offset != 8'd0) offset <= offset - 8'd1;
               end
            end
         end else begin
            repeat_ctr <= 22'd0;
         end
      end
   end

   // Drive range.start:
   // - while filling RAM: start is the latched base n
   // - after done: start is the read address (0..255)
   always_comb begin
      if (done) start = {24'd0, offset};     // read mode: address
      else      start = (base == 10'd0) ? 32'd0 : {22'd0, base};       // run mode: latched base n
   end

   logic [31:0] n_full;
   // displayed n = latched base + offset (show low 12 bits)
   assign n_full = {22'd0, base} + {24'd0, offset};
   assign n = (n_full[11:0] == 12'd0) ? 12'd1 : n_full[11:0];

   // 7-seg display:
   // Right 3 HEX (HEX2..HEX0): count (lower 12 bits)
   // Left  3 HEX (HEX5..HEX3): n (lower 12 bits)
   hex7seg h0(.a(count[3:0]),   .y(HEX0));
   hex7seg h1(.a(count[7:4]),   .y(HEX1));
   hex7seg h2(.a(count[11:8]),  .y(HEX2));
   hex7seg h3(.a(n[3:0]),       .y(HEX3));
   hex7seg h4(.a(n[7:4]),       .y(HEX4));
   hex7seg h5(.a(n[11:8]),      .y(HEX5));

   // LEDs mirror switches (fine to keep live)
   assign LEDR = SW;

endmodule
