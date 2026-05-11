module uart ( clk, rst, txdatain, txrdyin, rxpin, rxdataout, rxrdyout, txrdyout, txpin, errout );

//parameter CLKS_PER_BIT = 2500; // 2500=38400 @ 96MHz
parameter CLKS_PER_BIT = 104; // 104=115200 @ 12MHz

input clk;
input rst;
input [7:0] txdatain;
input rxpin;
input txrdyin;
output [7:0] rxdataout;
output txpin;
output rxrdyout;
output txrdyout;
output errout;

reg [15:0] rxctr = 0;
reg [15:0] txctr = 0;
reg [2:0] rxbitctr = 3'b0;
reg [2:0] txbitctr = 3'b0;
reg [7:0] rxdataout = 8'h0;
reg txpin = 1'b0;
reg rxrdyout = 1'b0;
reg errout = 1'b0;
reg txrdyout = 1'b0;
reg [1:0] rxstate = 2'b0;
reg [1:0] txstate = 2'b0;

always @( posedge clk or posedge rst) begin
	if ( rst ) begin
		rxctr <= 0;
		rxstate <= 2'b00;
		rxbitctr <= 3'b0;
		errout <= 1'b0;
		rxrdyout <= 1'b0;
	end else begin
		case ( rxstate )
			2'b00:
				begin
					rxctr <= 0;
					rxbitctr <= 3'b0;
					rxrdyout <= 1'b0; // moved here to not receive wrong chars
					if (rxpin == 1'b0) begin
						rxdataout <= 8'h00;
						rxstate <= 2'b01;
						//rxrdyout <= 1'b0;
					end else begin
						rxstate <= 2'b0;
					end
				end
			2'b01:
				begin
					if ( rxctr == (CLKS_PER_BIT-1)/2 ) begin
						rxctr <= 0;
						if (rxpin == 1'b0) begin
							rxstate <= 2'b10;		
						end else begin
							rxstate <= 2'b0;
						end
					end else begin
						rxctr <= rxctr + 1'b1;
						rxstate <= 2'b01;
					end
				end
			2'b10:
				begin
					if ( rxctr == CLKS_PER_BIT-1 ) begin
						rxctr <= 0;
						rxdataout[rxbitctr] <= rxpin;
						if (rxbitctr == 3'b111) begin
							rxbitctr <= 3'b0;
							rxstate <= 2'b11;
						end else begin
							rxbitctr <= rxbitctr + 1'b1;
							rxstate <= 2'b10;
						end
					end else begin
						rxctr <= rxctr + 1'b1;
						rxstate <= 3'b010;
					end
				end
			2'b11:
				begin
					if ( rxctr == CLKS_PER_BIT-1 ) begin
						rxctr <= 0;
						if (rxpin == 1'b1) begin
							rxrdyout <= 1'b1;
						end else begin
							errout <= 1'b1;
						end
						rxstate <= 2'b00;
					end else begin
						rxctr <= rxctr + 1'b1;
						rxstate <= 2'b11;
					end
				end
		endcase
	end
end

always @( posedge clk or posedge rst) begin
	if (rst) begin
		txstate <= 2'b00;
		txrdyout <= 1'b1;
		txpin <= 1'b1;
		txctr <= 0;
		txbitctr <= 3'b0;
	end else begin
		case ( txstate )
			2'b00:
				begin
					txctr <= 0;
					txbitctr <= 3'b0;
					txrdyout <= 1'b1;
					if (txrdyin == 1'b1) begin
						txrdyout <= 1'b0;
						txstate <= 2'b01;
					end else begin
						txstate <= 2'b00;
					end
				end
			2'b01:
				begin
					txpin <= 1'b0;
					if (txctr == (CLKS_PER_BIT-1)) begin
						txctr <= 0;
						txstate <= 2'b10;
					end else begin
						txctr <= txctr + 1'b1;
					end
				end
			2'b10:
				begin
					txpin <= txdatain[txbitctr];
					if (txctr == (CLKS_PER_BIT-1)) begin
						txctr <= 0;
						if (txbitctr == 3'b111) begin
							txbitctr <= 3'b0;
							txstate <= 2'b11;
						end else begin
							txbitctr <= txbitctr + 1'b1;
							txstate <= 2'b10;
						end
					end else begin
						txctr <= txctr + 1'b1;
					end
				end
			2'b11:
				begin
					txpin <= 1'b1;
					if (txctr == (CLKS_PER_BIT-1)) begin
						txctr <= 0;
						txstate <= 2'b00;
						txrdyout <= 1'b1;
					end else begin
						txctr <= txctr + 1'b1;
					end
				end
		endcase
	end
end


endmodule 
