module range
   #(parameter
     RAM_WORDS = 16,            // Number of counts to store in RAM
     RAM_ADDR_BITS = 4)         // Number of RAM address bits
   (input logic         clk,    // Clock
    input logic 	go,     // Read start and start testing
    input logic [31:0] 	start,  // Number to start from or count to read
    output logic 	done,   // True once memory is filled
    output logic [15:0] count); // Iteration count once finished

   logic 		cgo;    // "go" for the Collatz iterator
   logic                cdone;  // "done" from the Collatz iterator
   logic [31:0] 	n;      // number to start the Collatz iterator

// verilator lint_off PINCONNECTEMPTY
   
   // Instantiate the Collatz iterator
   collatz c1(.clk(clk),
	      .go(cgo),
	      .n(n),
	      .done(cdone),
	      .dout());

   logic [RAM_ADDR_BITS - 1:0] 	 num;         // The RAM address to write
   logic 			 running = 0; // True during the iterations

   logic 			 we;                    // Write din to addr
   logic [15:0] 		 din;                   // Data to write (iteration count)
   logic [15:0] 		 mem[RAM_WORDS - 1:0];  // The RAM itself
   logic [RAM_ADDR_BITS - 1:0] 	 addr;                  // Address to read/write

   assign addr = we ? num : start[RAM_ADDR_BITS-1:0];

   // State machine logic
   always_ff @(posedge clk) begin
      if (go && !running) begin
	 // Start new range test
	 running <= 1'b1;
	 n <= start;
	 num <= '0;
	 din <= 16'd0;  // Start count at 0
	 cgo <= 1'b1;
	 done <= 1'b0;
	 we <= 1'b0;
      end else if (running) begin
	 // Running mode
	 if (cgo) begin
	    // Just started Collatz iteration
	    cgo <= 1'b0;
	    din <= din + 16'd1;  // Count this iteration
	 end else if (!cdone) begin
	    // Collatz still running, increment count each cycle
	    din <= din + 16'd1;
	 end else if (!we) begin
	    // Collatz done, write to memory
	    we <= 1'b1;
	 end else begin
	    // Memory write complete
	    we <= 1'b0;
	    if (num == RAM_WORDS - 1) begin
	       // Finished all numbers
	       running <= 1'b0;
	       done <= 1'b1;
	    end else begin
	       // Move to next number
	       num <= num + 1;
	       n <= n + 1;
	       din <= 16'd0;  // Reset count for next number
	       cgo <= 1'b1;   // Start next Collatz iteration
	    end
	 end
      end else begin
	 // Idle state
	 cgo <= 1'b0;
	 we <= 1'b0;
      end
   end
   
   // Memory read/write
   always_ff @(posedge clk) begin
      if (we) mem[addr] <= din;
      count <= mem[addr];      
   end

endmodule
