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

   /* Replace this comment and the code below with your solution,
      which should generate running, done, cgo, n, num, we, and din */

   
   // State machine to control the Collatz iteration process
   always_ff @(posedge clk) begin
      if (go && !running) begin
         // Start new iteration sequence
         running <= 1;
         num <= 0;
         din <= 1;
         cgo <= 1;
         n <= start;
         done <= 0;
         we <= 0;
      end else if (running && n != 12'd0) begin
         if (cgo) begin
            // First cycle after starting Collatz - deassert cgo
            cgo <= 0;
         end else if (we) begin
            // Just wrote to RAM - prepare for next number
            we <= 0;
            if (num == RAM_ADDR_BITS'(RAM_WORDS - 1)) begin
               // Finished all iterations
               running <= 0;
               done <= 1;
            end else begin
               // Start next number
               num <= num + 1;
               n <= n + 1;
               din <= 1;
               cgo <= 1;
            end
         end else if (cdone) begin
            // Collatz iteration complete - write count to RAM
            we <= 1;
         end else begin
            // Counting iterations while Collatz is running
            din <= din + 1;
         end
      end else if (done) begin
         // One-cycle pulse for done
         done <= 0;
      end
   end
   
   /* Replace this comment and the code above with your solution */

   logic 			 we;                    // Write din to addr
   logic [15:0] 		 din;                   // Data to write
   logic [15:0] 		 mem[RAM_WORDS - 1:0];  // The RAM itself
   logic [RAM_ADDR_BITS - 1:0] 	 addr;                  // Address to read/write

   assign addr = we ? num : start[RAM_ADDR_BITS-1:0];
   
   always_ff @(posedge clk) begin
      if (we) mem[addr] <= din;
      count <= mem[addr];      
   end

endmodule
	     
