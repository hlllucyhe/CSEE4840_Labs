// CSEE 4840 Lab 1: Run and Display Collatz Conjecture Iteration Counts
//
// Spring 2025
//
// Complete implementation with debouncing and proper button handling

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

   logic [11:0] 		n;  // Value of n being displayed (lower 12 bits)
   logic [7:0]                  offset; // Offset from switch value (0-255)
   
   assign clk = CLOCK_50;
 
   range #(256, 8) // RAM_WORDS = 256, RAM_ADDR_BITS = 8)
         r ( .* ); // Connect everything with matching names

   // Debouncing and button edge detection
   logic [3:0] 			key_sync1, key_sync2, key_stable;
   logic [3:0] 			key_pressed;  // Rising edge (button press)
   
   // Synchronize button inputs (active low)
   always_ff @(posedge clk) begin
      key_sync1 <= KEY;
      key_sync2 <= key_sync1;
   end
   
   // Debounce counter - wait for stable signal
   logic [15:0] 		debounce_counter[3:0];
   logic [3:0] 			key_debounced;
   
   genvar 			i;
   generate
      for (i = 0; i < 4; i++) begin : debounce_gen
	 always_ff @(posedge clk) begin
	    if (key_sync2[i] == key_debounced[i]) begin
	       debounce_counter[i] <= 16'd0;
	    end else begin
	       debounce_counter[i] <= debounce_counter[i] + 16'd1;
	       if (debounce_counter[i] == 16'd65535) begin
		  key_debounced[i] <= key_sync2[i];
	       end
	    end
	 end
      end
   endgenerate
   
   // Edge detection - detect button presses (high to low transition since active low)
   logic [3:0] 			key_prev;
   always_ff @(posedge clk) begin
      key_prev <= key_debounced;
      key_pressed <= ~key_debounced & key_prev; // Detect falling edge (press)
   end
   
   // Auto-repeat logic for increment/decrement buttons
   // Counter runs at ~5 Hz when button held
   logic [21:0] 		repeat_counter;
   logic 			repeat_trigger;
   
   always_ff @(posedge clk) begin
      if (~key_debounced[0] || ~key_debounced[1]) begin
	 // Button held - increment counter
	 repeat_counter <= repeat_counter + 22'd1;
	 // Trigger at counter rollover (~10M cycles = ~0.2s at 50MHz)
	 repeat_trigger <= (repeat_counter == 22'd0);
      end else begin
	 repeat_counter <= 22'd0;
	 repeat_trigger <= 1'b0;
      end
   end
   
   // Button action signals
   logic 			increment, decrement, reset_offset, start_range;
   
   assign increment = key_pressed[0] || (repeat_trigger && ~key_debounced[0]);
   assign decrement = key_pressed[1] || (repeat_trigger && ~key_debounced[1]);
   assign reset_offset = key_pressed[2];
   assign start_range = key_pressed[3];
   
   // Range control and offset management
   logic 			range_running;
   logic [9:0] 			base_value;  // Value from switches
   
   always_ff @(posedge clk) begin
      // Capture switch value
      base_value <= SW;
      
      // Start range computation
      if (start_range) begin
	 go <= 1'b1;
	 start <= {22'd0, SW};  // Start from switch value
	 range_running <= 1'b1;
	 offset <= 8'd0;  // Reset offset when starting new range
      end else begin
	 go <= 1'b0;
      end
      
      // Update range_running status
      if (done) begin
	 range_running <= 1'b0;
      end
      
      // Handle offset changes (only when range is complete)
      if (!range_running && done) begin
	 if (reset_offset) begin
	    offset <= 8'd0;
	 end else if (increment && offset < 8'd255) begin
	    offset <= offset + 8'd1;
	 end else if (decrement && offset > 8'd0) begin
	    offset <= offset - 8'd1;
	 end
      end
   end
   
   // Calculate displayed n and read address
   always_comb begin
      n = {2'b00, base_value} + {4'b0, offset};
      start = {24'd0, offset};  // Use offset as read address when not starting
   end
   
   // Display on 7-segment displays
   // HEX5-HEX3 show n value (3 hex digits)
   // HEX2-HEX0 show iteration count (3 hex digits)
   
   hex7seg h0(.a(count[3:0]),   .y(HEX0));
   hex7seg h1(.a(count[7:4]),   .y(HEX1));
   hex7seg h2(.a(count[11:8]),  .y(HEX2));
   hex7seg h3(.a(n[3:0]),       .y(HEX3));
   hex7seg h4(.a(n[7:4]),       .y(HEX4));
   hex7seg h5(.a(n[11:8]),      .y(HEX5));
   
   // LED indicators
   assign LEDR[9] = range_running;  // Show when range computation is active
   assign LEDR[8] = done;           // Show when range is complete
   assign LEDR[7:0] = offset;       // Show current offset
   
endmodule
