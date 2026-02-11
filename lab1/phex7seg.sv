module hex7seg(input logic  [3:0] a,
	       output logic [6:0] y);

   // 7-segment display decoder for hexadecimal digits
   // Segments are active-low (0 = on, 1 = off)
   // Bit assignment: y[6]=g, y[5]=f, y[4]=e, y[3]=d, y[2]=c, y[1]=b, y[0]=a
   
   always_comb begin
      case(a)
	4'h0: y = 7'b1000000; // 0
	4'h1: y = 7'b1111001; // 1
	4'h2: y = 7'b0100100; // 2
	4'h3: y = 7'b0110000; // 3
	4'h4: y = 7'b0011001; // 4
	4'h5: y = 7'b0010010; // 5
	4'h6: y = 7'b0000010; // 6
	4'h7: y = 7'b1111000; // 7
	4'h8: y = 7'b0000000; // 8
	4'h9: y = 7'b0010000; // 9
	4'ha: y = 7'b0001000; // A
	4'hb: y = 7'b0000011; // b
	4'hc: y = 7'b1000110; // C
	4'hd: y = 7'b0100001; // d
	4'he: y = 7'b0000110; // E
	4'hf: y = 7'b0001110; // F
	default: y = 7'b1111111; // blank
      endcase
   end
   
endmodule
