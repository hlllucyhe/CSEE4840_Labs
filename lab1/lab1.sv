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
   logic [3:0] k0, k1;
    always_ff @(posedge clk) begin
        k0 <= KEY; k1 <= k0;
    end
    logic k3p, k2p;
    always_ff @(posedge clk) begin
        k3p <= k1[3];
        k2p <= k1[2];
    end
    wire run_pulse   = (k3p && !k1[3]); // falling edge
    wire reset_pulse = (k2p && !k1[2]); // falling edge

    // offset select within [SW .. SW+255]
    logic [7:0]  offset;
    logic [21:0] rep;
    wire         tick = (rep == 22'd0);

    // track if RAM matches current SW base
    logic [9:0]  sw_prev;
    logic        filled, running;

    always_ff @(posedge clk) begin
        sw_prev <= SW;
        rep     <= rep + 22'd1;

        if (SW != sw_prev) begin
            filled  <= 1'b0;
            running <= 1'b0;
            offset  <= 8'd0;
        end else begin
            if (run_pulse && !running) begin
                running <= 1'b1;
                filled  <= 1'b0;
            end
            if (done) begin
                running <= 1'b0;
                filled  <= 1'b1;
            end

            if (reset_pulse) offset <= 8'd0;
            else if (tick) begin
                if (!k1[0] && k1[1])      offset <= offset + 8'd1; // KEY[0] inc
                else if (!k1[1] && k1[0]) offset <= offset - 8'd1; // KEY[1] dec
            end
        end
    end

    assign go = run_pulse && !running;

    // range start: SW when filling, offset when reading
    always_comb begin
        if (running) start = {22'd0, SW};
        else         start = {24'd0, offset};
    end

    // displayed n and count
    always_comb n = {2'b00, SW} + {4'b0000, offset};
    logic [15:0] cshow;
    always_comb cshow = filled ? count : 16'd0;

    // display
    hex7seg h5(.a(n[11:8]),     .y(HEX5));
    hex7seg h4(.a(n[7:4]),      .y(HEX4));
    hex7seg h3(.a(n[3:0]),      .y(HEX3));
    hex7seg h2(.a(cshow[11:8]), .y(HEX2));
    hex7seg h1(.a(cshow[7:4]),  .y(HEX1));
    hex7seg h0(.a(cshow[3:0]),  .y(HEX0));

    assign LEDR = SW;

endmodule
