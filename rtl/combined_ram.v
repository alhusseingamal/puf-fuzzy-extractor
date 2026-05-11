module combined_ram (
   input  clk,
   output reg [15:0] rdata,
   input  [12:0] raddr,
   input  we,
   input  [15:0] wdata,
   input  [15:0] wmask,
   input  [12:0] waddr
);
    localparam MAX_4K_BLOCKS = 32; // ice40hx8k

    wire [15:0] rdata_sel [0:MAX_4K_BLOCKS-1];
    reg [15:0] wdata_sel [0:MAX_4K_BLOCKS-1];
    
    reg [MAX_4K_BLOCKS-1:0] re_sel;
    reg [MAX_4K_BLOCKS-1:0] we_sel;
    
    /* this should become combinational only */
    integer i;
    always @ (*) begin
        /*re_sel <= 0;
         *we_sel <= 0;
         *re_sel[raddr[12:8]] <= 'b1;
         *we_sel[waddr[12:8]] <= 'b1;
         *wdata_sel[waddr[12:11]] <= wdata;
        */
        for (i=0;i<MAX_4K_BLOCKS;i=i+1)
        begin
            if (i == raddr[12:8]) begin
                re_sel[i] = 1;
            end else begin
                re_sel[i] = 0;
            end
            if (i == waddr[12:8]) begin
                we_sel[i] = we;
                wdata_sel[i] = wdata;
            end else begin
                we_sel[i] = 0;
                wdata_sel[i] = 0;
            end
            
        end
        rdata = rdata_sel[raddr[12:8]];
    end

    genvar gi;
    generate
        for (gi=0;gi<MAX_4K_BLOCKS;gi=gi+1)
        begin : gen_rams
            SB_RAM40_4K #(
              /*.INIT_0(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_1(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_2(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_3(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_4(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_5(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_6(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_7(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_8(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_9(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_A(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_B(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_C(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_D(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_E(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),
              .INIT_F(256'hxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx),*/
              .WRITE_MODE(32'sd0),
              .READ_MODE(32'sd0)
            ) ram40_4kinst_physical (
              .RDATA ( rdata_sel[gi] ),
              .RADDR ( {3'b000, raddr[7:0]} ),
              .WADDR ( {3'b000, waddr[7:0]} ),
              .MASK ( wmask ),
              .WDATA ( wdata ),
              .RCLKE ( 1'b1 ),
              .RCLK ( clk ),
              .RE ( re_sel[gi] ),
              .WCLKE ( 1'b1 ),
              .WCLK ( clk ),
              .WE ( we_sel[gi] )
           );
        end
    endgenerate

endmodule
