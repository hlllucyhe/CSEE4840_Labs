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
   logic [7:0]  offset;       // 0..255 within the 256-entry RAM
   logic [21:0] repeat_ctr;   // hold-to-repeat counter
   logic        k3_prev;      // for edge detect on KEY[3]

   // 1-cycle go pulse on KEY[3] press
   always_ff @(posedge clk) begin
      k3_prev <= ~KEY[3];
   end
   assign go = (~KEY[3]) & ~k3_prev;

   always_ff @(posedge clk) begin
      if (~KEY[2]) begin
         offset     <= 8'd0;
         repeat_ctr <= 22'd0;
      end else begin
         if (go) offset <= 8'd0;   // reset offset when starting a new run

         if ((~KEY[0]) || (~KEY[1])) begin
            repeat_ctr <= repeat_ctr + 22'd1;

            // change on wrap (~5-12 Hz depending on board; lab suggests 22-bit example)
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

   always_comb begin
      if (done) start = {24'd0, offset};     // read mode: address
      else      start = {22'd0, SW[9:0]};    // run mode: base n
   end
   
   logic [11:0] n_sum; 
   assign n_sum = {2'd0, SW[9:0]} + {4'd0, offset};
   assign n = n_sum[11:0];

   hex7seg h0(.a(count[3:0]),   .y(HEX0));
   hex7seg h1(.a(count[7:4]),   .y(HEX1));
   hex7seg h2(.a(count[11:8]),  .y(HEX2));
   hex7seg h3(.a(n[3:0]),       .y(HEX3));
   hex7seg h4(.a(n[7:4]),       .y(HEX4));
   hex7seg h5(.a(n[11:8]),      .y(HEX5));

   assign LEDR = SW;

endmodule
