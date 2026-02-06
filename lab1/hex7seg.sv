module hex7seg(input logic  [3:0] a,
	       output logic [6:0] y);

   always_comb begin
        case (a)
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
            4'hA: y = 7'b0001000; // A
            4'hB: y = 7'b0000011; // b
            4'hC: y = 7'b1000110; // C
            4'hD: y = 7'b0100001; // d
            4'hE: y = 7'b0000110; // E
            4'hF: y = 7'b0001110; // F
            default: y = 7'b1111111; // blank
        endcase
    end
   
endmodule
