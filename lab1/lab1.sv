module debounce_keys #(
    parameter int N_KEYS = 4,
    parameter int CLK_HZ = 50_000_000,
    parameter int DEBOUNCE_MS = 10
)(
    input  logic                  clk,
    input  logic [N_KEYS-1:0]      key_in,
    output logic [N_KEYS-1:0]      key_db
);

    localparam int DEBOUNCE_CYCLES = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam int CNT_W = (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    logic [N_KEYS-1:0] key_ff0, key_ff1;
    always_ff @(posedge clk) begin
        key_ff0 <= key_in;
        key_ff1 <= key_ff0;
    end

    logic [CNT_W-1:0] cnt [N_KEYS-1:0];

    integer i;
    initial begin
        key_db = {N_KEYS{1'b1}};
        for (i = 0; i < N_KEYS; i++) cnt[i] = '0;
    end

    always_ff @(posedge clk) begin
        for (i = 0; i < N_KEYS; i++) begin
            if (key_ff1[i] == key_db[i]) begin
                cnt[i] <= '0;
            end else begin
                if (cnt[i] == DEBOUNCE_CYCLES-1) begin
                    key_db[i] <= key_ff1[i];
                    cnt[i]    <= '0;
                end else begin
                    cnt[i] <= cnt[i] + 1'b1;
                end
            end
        end
    end

endmodule


module lab1(
    input  logic        CLOCK_50,
    input  logic [3:0]   KEY,
    input  logic [9:0]   SW,
    output logic [6:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5,
    output logic [9:0]   LEDR
);

    logic [9:0] base_n;
    assign base_n = SW[9:0];

    logic [3:0] key_db;
    debounce_keys #(
        .N_KEYS(4),
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(2)
    ) u_db (
        .clk   (CLOCK_50),
        .key_in(KEY),
        .key_db(key_db)
    );

    logic [3:0] key_prev;
    always_ff @(posedge CLOCK_50) begin
        key_prev <= key_db;
    end

    logic [3:0] key_pressed;
    assign key_pressed = ~key_db;

    logic [3:0] key_fall;
    assign key_fall[0] = (key_prev[0] == 1'b1) && (key_db[0] == 1'b0);
    assign key_fall[1] = (key_prev[1] == 1'b1) && (key_db[1] == 1'b0);
    assign key_fall[2] = (key_prev[2] == 1'b1) && (key_db[2] == 1'b0);
    assign key_fall[3] = (key_prev[3] == 1'b1) && (key_db[3] == 1'b0);

    logic [7:0] offset;

    // Auto-repeat parameters
    localparam int CLK_HZ = 50_000_000;
    localparam int INITIAL_DELAY_MS = 250; // hold for 250ms before repeating
    localparam int REPEAT_HZ = 5;          // repeat speed after delay

    localparam int INITIAL_DELAY_CYCLES = (CLK_HZ/1000) * INITIAL_DELAY_MS;
    localparam int REPEAT_CYCLES        = (CLK_HZ / REPEAT_HZ);

    localparam int ID_W = (INITIAL_DELAY_CYCLES <= 1) ? 1 : $clog2(INITIAL_DELAY_CYCLES);
    localparam int RP_W = (REPEAT_CYCLES        <= 1) ? 1 : $clog2(REPEAT_CYCLES);

    logic [ID_W-1:0] inc_delay_cnt, dec_delay_cnt;
    logic [RP_W-1:0] inc_rep_cnt,   dec_rep_cnt;
    logic inc_repeating, dec_repeating;

    logic inc_pulse, dec_pulse, rst_pulse;
    assign rst_pulse = key_fall[2];

    always_ff @(posedge CLOCK_50) begin
        inc_pulse <= 1'b0;
        dec_pulse <= 1'b0;

        // KEY0 auto-repeat (increment)
        if (key_fall[0]) begin
            inc_pulse      <= 1'b1;     // single step on press
            inc_repeating  <= 1'b0;
            inc_delay_cnt  <= '0;
            inc_rep_cnt    <= '0;
        end else if (!key_pressed[0]) begin
            inc_repeating  <= 1'b0;     // released
            inc_delay_cnt  <= '0;
            inc_rep_cnt    <= '0;
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
                    inc_pulse   <= 1'b1; // repeat step
                end else begin
                    inc_rep_cnt <= inc_rep_cnt + 1'b1;
                end
            end
        end

        // KEY1 auto-repeat (decrement)
        if (key_fall[1]) begin
            dec_pulse      <= 1'b1;     // single step on press
            dec_repeating  <= 1'b0;
            dec_delay_cnt  <= '0;
            dec_rep_cnt    <= '0;
        end else if (!key_pressed[1]) begin
            dec_repeating  <= 1'b0;     // released
            dec_delay_cnt  <= '0;
            dec_rep_cnt    <= '0;
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
                    dec_pulse   <= 1'b1; // repeat step
                end else begin
                    dec_rep_cnt <= dec_rep_cnt + 1'b1;
                end
            end
        end
    end

    // Saturating offset update (no wrap-around)
    always_ff @(posedge CLOCK_50) begin
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

    logic [11:0] n_display;
    assign n_display = {2'b00, base_n} + {4'b0000, offset};

    logic go_pulse;
    assign go_pulse = key_fall[3];

    logic range_done_pulse;
    logic [15:0] range_count;

    logic range_ready;
    always_ff @(posedge CLOCK_50) begin
        if (go_pulse) range_ready <= 1'b0;
        else if (range_done_pulse) range_ready <= 1'b1;
    end

    logic [31:0] range_start;
    always_comb begin
        if (go_pulse) begin
            range_start = {22'd0, base_n};
        end else if (range_ready) begin
            range_start = {24'd0, offset};
        end else begin
            range_start = 32'd0;
        end
    end

    range #(.RAM_WORDS(256), .RAM_ADDR_BITS(8)) u_range (
        .clk   (CLOCK_50),
        .go    (go_pulse),
        .start (range_start),
        .done  (range_done_pulse),
        .count (range_count)
    );

    logic [11:0] k_display;
    always_ff @(posedge CLOCK_50) begin
        if (!range_ready) begin
            k_display <= 12'd0;
        end
        else if (n_display == 12'd0) begin
            k_display <= 12'd0;   // force 000 when n = 0
        end
        else begin
            k_display <= range_count[11:0];
        end
    end


    hex7seg h0(.a(k_display[3:0]),   .y(HEX0));
    hex7seg h1(.a(k_display[7:4]),   .y(HEX1));
    hex7seg h2(.a(k_display[11:8]),  .y(HEX2));

    hex7seg h3(.a(n_display[3:0]),   .y(HEX3));
    hex7seg h4(.a(n_display[7:4]),   .y(HEX4));
    hex7seg h5(.a(n_display[11:8]),  .y(HEX5));

    always_comb begin
        LEDR      = 10'd0;
        LEDR[9]   = range_ready;
        LEDR[8]   = range_done_pulse;
        LEDR[7:0] = offset;
    end

endmodule
