module collatz( input logic         clk,   // Clock
		input logic 	    go,    // Load value from n; start iterating
		input logic  [31:0] n,     // Start value; only read when go = 1
		output logic [31:0] dout,  // Iteration value: true after go = 1
		output logic 	    done); // True when dout reaches 1

   wire [31:0] dout_next;
   assign dout_next = (dout[0] == 1'b0) ? (dout >> 1) : (3 * dout + 1);

   always_ff @(posedge clk) begin
      if (go) begin
         dout <= n;
         done <= (n==1);
      end else if (!done) begin
         dout <= dout_next;
         done <= (dout_next == 1);
      end
   end

endmodule
