// CSEE 4840 Lab 1: Run and Display Collatz Conjecture Iteration Counts
//
// Spring 2023
//
// By: Lucy He, Pengpeng Wang, Xiyuan Peng
// Uni: lh3365, pw2660, xp2236

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
   // The code below is merely to suppress Verilator lint warnings
   assign LEDR = SW;
   
   // blink right-most three displays when done
   localparam int BLINK_HALF_CYCLES = 12_500_000; // 0.25 s @ 50 MHz
   logic [31:0] blink_cnt;
   logic [2:0]  blink_toggles_left;
   logic blink_active, blink_show, blink_req;

   always_ff @(posedge clk) begin
      if (!done) begin
        blink_show <= 1'b1;
        blink_active <= 1'b0;
        blink_cnt <= 32'd0;
        blink_toggles_left <= 3'd0; 
      end else begin
        // start blink sequence
        if (blink_req) begin
            blink_active       <= 1'b1;
            blink_show         <= 1'b1;
            blink_cnt          <= 32'd0;
            blink_toggles_left <= 3'd6; // blink 3 times
        end
        
        // run blink toggles
        if (blink_active) begin
            if (blink_cnt == BLINK_HALF_CYCLES-1) begin
                blink_cnt <= 32'd0;
                if (blink_toggles_left != 0) begin
                    blink_show <= ~blink_show;
                    blink_toggles_left <= blink_toggles_left - 1'b1;
                end else begin
                    blink_active <= 1'b0;
                    blink_show   <= 1'b1;
                end
            end else begin
                blink_cnt <= blink_cnt + 1'b1;
            end
        end
      end
   end
   
   // update base number based on switches
   logic [11:0] n_base;
   logic [11:0] offset;
   logic [9:0] start_sw_latched; // latch start switches at KEY[3] press
   assign n_base = {2'b00, start_sw_latched}; // zero-extend to 12 bits
   assign n = n_base + offset;

   always_comb begin
      if (!done)
         start = {22'd0, start_sw_latched};     // start value
      else
         start = {24'd0, offset[7:0]};      // read address
   end

   // displays
   logic [11:0] k;
   logic [6:0] hex0_n, hex1_n, hex2_n;
   assign k = (!done || (n == 12'd0)) ? 12'd0 : count[11:0];
   hex7seg h0(.a(k[3:0]),  .y(hex0_n));
   hex7seg h1(.a(k[7:4]),  .y(hex1_n));
   hex7seg h2(.a(k[11:8]), .y(hex2_n));
   hex7seg h3(.a(n[3:0]),   .y(HEX3));
   hex7seg h4(.a(n[7:4]),   .y(HEX4));
   hex7seg h5(.a(n[11:8]),  .y(HEX5));

   assign HEX0 = (blink_show) ? hex0_n : 7'h7F;
   assign HEX1 = (blink_show) ? hex1_n : 7'h7F;
   assign HEX2 = (blink_show) ? hex2_n : 7'h7F;
   
   // debounce pushbutton keys
   logic [3:0] key_db;
   debounce #(.DEBOUNCE_US(100)) db0(.clk(clk), .A(KEY[0]), .A_db(key_db[0]));
   debounce #(.DEBOUNCE_US(100)) db1(.clk(clk), .A(KEY[1]), .A_db(key_db[1]));
   debounce #(.DEBOUNCE_US(100)) db2(.clk(clk), .A(KEY[2]), .A_db(key_db[2]));
   debounce #(.DEBOUNCE_US(100)) db3(.clk(clk), .A(KEY[3]), .A_db(key_db[3]));

   // edge detect keys and done
   logic [3:0] key_prev;
   logic done_prev;
   always_ff @(posedge clk) begin
      key_prev <= key_db;
      done_prev <= done;
   end
   logic [3:0] key_rise;
   logic done_rise;
   assign key_rise = (key_db & ~key_prev);
   assign done_rise = done & ~done_prev;

   // increment and decrement offset with KEY[0] and KEY[1]
   localparam int HOLD_DELAY_CYCLES = 15_000_000;  // 0.30 s @ 50 MHz
   localparam int REPEAT_CYCLES     = 10_000_000;  // 0.20 s @ 50 MHz => 5 Hz

   logic [31:0] inc_hold_cnt, dec_hold_cnt;
   logic [31:0] inc_rep_cnt,  dec_rep_cnt;
   logic        inc_repeat_en, dec_repeat_en;

   logic inc_pulse, dec_pulse;
   always_ff @(posedge clk) begin
      inc_pulse <= 1'b0;
      dec_pulse <= 1'b0;

      if (done && !blink_active && !(key_db[0] & key_db[1])) begin
        // short press pulses
        if (key_rise[0]) inc_pulse <= 1'b1;
        if (key_rise[1]) dec_pulse <= 1'b1;

        // KEY[0] hold/repeat
        if (!key_db[0]) begin
            inc_hold_cnt  <= 32'd0;
            inc_rep_cnt   <= 32'd0;
            inc_repeat_en <= 1'b0;
        end else if (!inc_repeat_en) begin  // waiting for hold delay to expire
            if (inc_hold_cnt >= HOLD_DELAY_CYCLES-1) begin
                inc_repeat_en <= 1'b1;
                inc_rep_cnt   <= 32'd0;
            end else begin
                inc_hold_cnt <= inc_hold_cnt + 1'b1;
            end
        end else begin  // repeat during hold
            if (inc_rep_cnt >= REPEAT_CYCLES-1) begin
                inc_rep_cnt <= 32'd0;
                inc_pulse   <= 1'b1;   // repeat pulse
            end else begin
                inc_rep_cnt <= inc_rep_cnt + 1'b1;
            end
        end

        // KEY[1] hold/repeat
        if (!key_db[1]) begin
            dec_hold_cnt  <= 32'd0;
            dec_rep_cnt   <= 32'd0;
            dec_repeat_en <= 1'b0;
        end else if (!dec_repeat_en) begin // waiting for hold delay to expire
            if (dec_hold_cnt >= HOLD_DELAY_CYCLES-1) begin
                dec_repeat_en <= 1'b1;
                dec_rep_cnt   <= 32'd0;
            end else begin
                dec_hold_cnt <= dec_hold_cnt + 1'b1;
            end
        end else begin  // repeat during hold
            if (dec_rep_cnt >= REPEAT_CYCLES-1) begin
                dec_rep_cnt <= 32'd0;
                dec_pulse   <= 1'b1;   // repeat pulse
            end else begin
                dec_rep_cnt <= dec_rep_cnt + 1'b1;
            end
        end
      end else begin
         // not in scroll mode: keep repeat machinery reset
         inc_hold_cnt  <= 32'd0;
         dec_hold_cnt  <= 32'd0;
         inc_rep_cnt   <= 32'd0;
         dec_rep_cnt   <= 32'd0;
         inc_repeat_en <= 1'b0;
         dec_repeat_en <= 1'b0;
      end
   end
   
   // KEY[3] for starting range iteration sequence
   logic go_reg;
   assign go = go_reg;
   logic run_in_progress;

   always_ff @(posedge clk) begin
      // defaults
      go_reg    <= 1'b0;
      blink_req <= 1'b0;

      // while idle (not running and not done yet), track switches
      if (!run_in_progress && !done) begin
         start_sw_latched <= SW[9:0];
      end

      // start run on KEY[3] press (ignore if already running)
      if (key_rise[3] && !run_in_progress) begin
         start_sw_latched <= SW[9:0];
         run_in_progress  <= 1'b1;
         go_reg           <= 1'b1;     // 1-cycle pulse
      end

      // when done rises: mark not running and request blink
      if (done_rise) begin
         run_in_progress <= 1'b0;
         blink_req       <= 1'b1;
      end
   end
   
   // KEY[2] resets offset to 0
   always_ff @(posedge clk) begin
      if (!done) begin
         offset <= 12'd0;
      end else if (done_rise) begin
         offset <= 12'd0;
      end else if (done && !blink_active && key_rise[2]) begin
         offset <= 12'd0;
      end else if (key_rise[3] && !run_in_progress) begin
         offset <= 12'd0;
      end else if (done && !blink_active) begin
         if (inc_pulse && (offset != 12'd255))
            offset <= offset + 12'd1;
         else if (dec_pulse && (offset != 12'd0))
            offset <= offset - 12'd1;
      end
   end
   
  
endmodule

//debounce module for keys
module debounce #(
    parameter int CLK_HZ = 50_000_000,
    parameter int DEBOUNCE_US = 100
)(
    input  logic clk,
    input  logic A,        // raw, active-low
    output logic A_db      // debounced, active-high
);

    // 2-flop synchronizer
    logic ff0, ff1;
    always_ff @(posedge clk) begin
        ff0 <= A;
        ff1 <= ff0;
    end

    // active-high "pressed" sample
    logic sample;
    assign sample = ~ff1;

    localparam int DEBOUNCE_CYCLES = (CLK_HZ/1000000) * DEBOUNCE_US;
    localparam int CNT_W = (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    logic [CNT_W-1:0] cnt;

    initial begin
        A_db = 1'b0;
        cnt  = '0;
    end

    always_ff @(posedge clk) begin
        if (sample == A_db) begin
            cnt <= '0; // no change
        end else begin
            if (cnt == DEBOUNCE_CYCLES-1) begin
                cnt  <= '0;
                A_db <= sample;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule

