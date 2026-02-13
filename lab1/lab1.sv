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
    // read base n from switches
    logic [9:0] base_n;
    assign base_n = SW[9:0];
    assign LEDR   = base_n;

    // debounce keys
    logic [3:0] key_db;

    debounce #(.DEBOUNCE_US(1)) db0(.clk(clk), .key_in(KEY[0]), .key_db(key_db[0]));
    debounce #(.DEBOUNCE_US(1)) db1(.clk(clk), .key_in(KEY[1]), .key_db(key_db[1]));
    debounce #(.DEBOUNCE_US(1)) db2(.clk(clk), .key_in(KEY[2]), .key_db(key_db[2]));
    debounce #(.DEBOUNCE_US(1)) db3(.clk(clk), .key_in(KEY[3]), .key_db(key_db[3]));

    // Edge detect (falling edge on active-low debounced key == press event)
    logic [3:0] key_prev;
    always_ff @(posedge clk) begin
        key_prev <= key_db;
    end

    logic [3:0] key_pressed; // 1 when pressed
    assign key_pressed = ~key_db;

    logic [3:0] key_fall; // 1-cycle pulse on press
    assign key_fall[0] = (key_prev[0] == 1'b1) && (key_db[0] == 1'b0);
    assign key_fall[1] = (key_prev[1] == 1'b1) && (key_db[1] == 1'b0);
    assign key_fall[2] = (key_prev[2] == 1'b1) && (key_db[2] == 1'b0);
    assign key_fall[3] = (key_prev[3] == 1'b1) && (key_db[3] == 1'b0);

    // control offset with KEY[0] and KEY[1]
    logic [7:0] offset;

    localparam int CLK_HZ            = 50_000_000;
    localparam int INITIAL_DELAY_MS  = 500;
    localparam int REPEAT_HZ         = 5;

    localparam int INITIAL_DELAY_CYCLES = (CLK_HZ/1000) * INITIAL_DELAY_MS;
    localparam int REPEAT_CYCLES        = (CLK_HZ / REPEAT_HZ);

    localparam int ID_W = (INITIAL_DELAY_CYCLES <= 1) ? 1 : $clog2(INITIAL_DELAY_CYCLES);
    localparam int RP_W = (REPEAT_CYCLES        <= 1) ? 1 : $clog2(REPEAT_CYCLES);

    logic [ID_W-1:0] inc_delay_cnt, dec_delay_cnt;
    logic [RP_W-1:0] inc_rep_cnt,   dec_rep_cnt;
    logic            inc_repeating, dec_repeating;

    logic inc_pulse, dec_pulse, rst_pulse;
    assign rst_pulse = key_fall[2] | key_fall[3]; // KEY2 or KEY3 press

    // Generate inc/dec pulses: short press + long-press repeat
    always_ff @(posedge clk) begin
        inc_pulse <= 1'b0;
        dec_pulse <= 1'b0;

        // INC (KEY[0])
        if (key_fall[0]) begin
            inc_pulse     <= 1'b1;
            inc_repeating <= 1'b0;
            inc_delay_cnt <= '0;
            inc_rep_cnt   <= '0;
        end else if (!key_pressed[0]) begin
            inc_repeating <= 1'b0;
            inc_delay_cnt <= '0;
            inc_rep_cnt   <= '0;
        end else begin
            if (!inc_repeating) begin
                if (inc_delay_cnt == INITIAL_DELAY_CYCLES-1) begin
                    inc_repeating <= 1'b1;
                    inc_delay_cnt <= '0;
                    inc_rep_cnt   <= '0;
                end else begin
                    inc_delay_cnt <= inc_delay_cnt + 1'b1;
                end
            end else begin
                if (inc_rep_cnt == REPEAT_CYCLES-1) begin
                    inc_rep_cnt <= '0;
                    inc_pulse   <= 1'b1;
                end else begin
                    inc_rep_cnt <= inc_rep_cnt + 1'b1;
                end
            end
        end

        // DEC (KEY[1])
        if (key_fall[1]) begin
            dec_pulse     <= 1'b1;
            dec_repeating <= 1'b0;
            dec_delay_cnt <= '0;
            dec_rep_cnt   <= '0;
        end else if (!key_pressed[1]) begin
            dec_repeating <= 1'b0;
            dec_delay_cnt <= '0;
            dec_rep_cnt   <= '0;
        end else begin
            if (!dec_repeating) begin
                if (dec_delay_cnt == INITIAL_DELAY_CYCLES-1) begin
                    dec_repeating <= 1'b1;
                    dec_delay_cnt <= '0;
                    dec_rep_cnt   <= '0;
                end else begin
                    dec_delay_cnt <= dec_delay_cnt + 1'b1;
                end
            end else begin
                if (dec_rep_cnt == REPEAT_CYCLES-1) begin
                    dec_rep_cnt <= '0;
                    dec_pulse   <= 1'b1;
                end else begin
                    dec_rep_cnt <= dec_rep_cnt + 1'b1;
                end
            end
        end
    end

    // Apply offset updates
    always_ff @(posedge clk) begin
        if (rst_pulse) begin
            offset <= 8'd0;
        end else begin
            if (inc_pulse) begin
                if (offset != 8'hFF) offset <= offset + 8'd1;
            end
            if (dec_pulse) begin
                if (offset != 8'd0)  offset <= offset - 8'd1;
            end
        end
    end

    // n display
    assign n = {2'b00, base_n} + {4'b0000, offset};

    // control range with KEY[3]
    assign go = key_fall[3];

    logic range_ready;
    always_ff @(posedge clk) begin
        if (go)       range_ready <= 1'b0;
        else if (done) range_ready <= 1'b1;
    end

    always_comb begin
        if (go) begin
            start = {22'd0, base_n};
        end else if (range_ready) begin
            start = {24'd0, offset};
        end else begin
            start = 32'd0;
        end
    end

    // display count and handle 0 case
    logic [11:0] k_display;
    always_ff @(posedge clk) begin
        if (!range_ready) begin
            k_display <= 12'd0;
        end else if (n == 12'd0) begin
            k_display <= 12'd0;
        end else begin
            k_display <= count[11:0];
        end
    end

    //blink after done range
    localparam int BLINK_TOGGLE_HZ      = 4;
    localparam int BLINK_DURATION_MS    = 1000;
    localparam int BLINK_TOGGLE_CYCLES  = (CLK_HZ / BLINK_TOGGLE_HZ);
    localparam int BLINK_DURATION_CYCLES= (CLK_HZ / 1000) * BLINK_DURATION_MS;

    localparam int BT_W = (BLINK_TOGGLE_CYCLES   <= 1) ? 1 : $clog2(BLINK_TOGGLE_CYCLES);
    localparam int BD_W = (BLINK_DURATION_CYCLES <= 1) ? 1 : $clog2(BLINK_DURATION_CYCLES);

    logic        blink_active;
    logic        blink_phase; // 1=show, 0=hide
    logic [BT_W-1:0] blink_tcnt;
    logic [BD_W-1:0] blink_dcnt;

    always_ff @(posedge clk) begin
        if (go) begin
            blink_active <= 1'b0;
            blink_phase  <= 1'b1;
            blink_tcnt   <= '0;
            blink_dcnt   <= '0;
        end else if (done) begin
            blink_active <= 1'b1;
            blink_phase  <= 1'b1;
            blink_tcnt   <= '0;
            blink_dcnt   <= '0;
        end else if (blink_active) begin
            if (blink_dcnt == BLINK_DURATION_CYCLES-1) begin
                blink_active <= 1'b0;
                blink_phase  <= 1'b1;
                blink_tcnt   <= '0;
                blink_dcnt   <= '0;
            end else begin
                blink_dcnt <= blink_dcnt + 1'b1;

                if (blink_tcnt == BLINK_TOGGLE_CYCLES-1) begin
                    blink_tcnt  <= '0;
                    blink_phase <= ~blink_phase;
                end else begin
                    blink_tcnt <= blink_tcnt + 1'b1;
                end
            end
        end
    end

    // displays
    logic [6:0] hex0_k, hex1_k, hex2_k;
    hex7seg h0(.a(k_display[3:0]),  .y(hex0_k));
    hex7seg h1(.a(k_display[7:4]),  .y(hex1_k));
    hex7seg h2(.a(k_display[11:8]), .y(hex2_k));

    always_comb begin
        if (blink_active && !blink_phase) begin
            HEX0 = 7'b1111111;
            HEX1 = 7'b1111111;
            HEX2 = 7'b1111111;
        end else begin
            HEX0 = hex0_k;
            HEX1 = hex1_k;
            HEX2 = hex2_k;
        end
    end

    hex7seg h3(.a(n[3:0]),  .y(HEX3));
    hex7seg h4(.a(n[7:4]),  .y(HEX4));
    hex7seg h5(.a(n[11:8]), .y(HEX5));

endmodule

module debounce #(
    parameter int CLK_HZ      = 50_000_000,
    parameter int DEBOUNCE_US = 1
)(
    input  logic clk,
    input  logic key_in,  // raw active-low from board
    output logic key_db   // debounced active-low
);

    // 2-flop synchronizer
    logic ff0, ff1;
    always_ff @(posedge clk) begin
        ff0 <= key_in;
        ff1 <= ff0;
    end

    localparam int DEBOUNCE_CYCLES = (CLK_HZ/1_000_000) * DEBOUNCE_US;
    localparam int CNT_W = (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    logic [CNT_W-1:0] cnt;

    // Start unpressed to match typical board behavior in simulation
    initial begin
        key_db = 1'b1;
        cnt    = '0;
    end

    always_ff @(posedge clk) begin
        if (ff1 == key_db) begin
            cnt <= '0;
        end else begin
            if (cnt == DEBOUNCE_CYCLES-1) begin
                key_db <= ff1;
                cnt    <= '0;
            end else begin
                cnt <= cnt + 1'b1;
            end
        end
    end

endmodule
