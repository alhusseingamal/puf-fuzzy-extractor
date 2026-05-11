module puf_module ( input  clk, input  rst,
    input  uart_rx_ready, input  [7:0] uart_data_from_rx,   // Until now, those are needed only to signal the start of communication from PC side
    input  uart_tx_ready, output reg [7:0] uart_data_to_tx, output reg uart_tx_enable
);

parameter PUF_BITS = 131072; // max. possible for ice40hx8k
localparam PUF_BYTES = 16384; // =PUF_BITS/8

//enum {INIT, WAIT_FOR_REQUEST, WAITCYCLE_FOR_MEMORY, PUF_READ, UART_SEND, UART_WAIT_FINISH, LOOP_CONDITION} state;

wire [15:0] rdata;   // read data
reg [12:0] raddr;    // read address
reg [12:0] waddr;    // write address
reg [15:0] wmask;    // write mask
reg we;              // write enable
reg [15:0] wdata;    // write data

localparam 
    INIT = 0, WAIT_FOR_REQUEST = 1, 
    WAITCYCLE_FOR_MEMORY = 2, PUF_READ = 3, 
    UART_SEND = 4, UART_WAIT_FINISH = 5, 
    LOOP_CONDITION = 6;

reg [2:0] state;    // State register

// Other registers:
reg [13:0] i_r; // byte read index / address
// reg [12:0] i_w_r; // byte write index / address             // I think this should be [13:0] as well
reg [7:0] puf_byte_reg;

combined_ram ram_inst (.clk (clk),
    .rdata(rdata), .raddr(raddr),
    .we(we), .wdata(wdata),
    .wmask(wmask), .waddr(waddr)
);

// sequential logic block for state machine
always @ (posedge clk, posedge rst) begin
    if (rst) begin
    // TODO-BASIC: Initialize/reset the state and other registers
        state <= INIT;
        i_r <= 0;
        puf_byte_reg <= 0;
    end else begin
    case (state)
        INIT: begin
                    // for init'ing the UART chip on the board we send one dummy byte (see in comb_proc below)
                    state <= WAIT_FOR_REQUEST;
                end
        WAIT_FOR_REQUEST:
                begin
                    // TODO-SRAM: reset the puf byte index register
                    puf_byte_reg <= 0;
                    
                    // TODO-UART: wait for the UART to send 's', then transition to the next state
                    if (uart_rx_ready == 1'b1 && ((uart_data_from_rx == 'h53 || uart_data_from_rx == 'h73))) begin
                        state <= WAITCYCLE_FOR_MEMORY;
                    end else begin
                        state <= WAIT_FOR_REQUEST;
                    end                    
                end
        WAITCYCLE_FOR_MEMORY:
                begin
                    state <= PUF_READ;
                end
        PUF_READ:
                begin
                    // TODO-SRAM: change the following to select the correct byte of
                    // the rdata vector, using the LSB of i_r:
                    if (i_r[0] == 1'b0) begin
                        puf_byte_reg <= rdata[7:0];
                    end else begin
                        puf_byte_reg <= rdata[15:8];
                    end
                    
                    // TODO-UART:
                    // wait for uart to become ready before sending
                    if (uart_tx_ready == 1'b1) begin
                        state <= UART_SEND;
                    end else begin
                        state <= PUF_READ;
                    end
                end
        UART_SEND :
                begin
                    // most logic happens in combinational part, but we need one thing here..
                    state <= UART_WAIT_FINISH;
                end
        UART_WAIT_FINISH :
                begin
                    // wait for uart transmission to finish and become ready again
                    if (uart_tx_ready == 1'b1) begin
                        state <= LOOP_CONDITION;
                    end else begin
                        state <= UART_WAIT_FINISH;
                    end
                end
        LOOP_CONDITION :
                begin
                    // TODO-SRAM: do the following:
                    // check if we have transmitted the complete SRAM,
                    // and depending on that go back to the start or
                    // increment the read index and continue transmitting
                    if (i_r == PUF_BYTES-1) begin
                        i_r <= 0;
                        state <= WAIT_FOR_REQUEST;
                    end else begin
                        i_r <= i_r + 1;
                        state <= WAITCYCLE_FOR_MEMORY;
                    end
                end
        default :
                begin
                    state <= INIT;
                end
    endcase
    end
end

// combinational outputs depending on states/registers
// more explanation: see above the sequential process
always @ (*) begin
    // defaults:
    // do not enable uart transmission per default:
    uart_tx_enable = 1'b0;
    // the puf_byte_reg register is a buffer that should always contain the last
    // value to send, since the UART module directly accesses it while sending
    // (until the UART module signals uart_tx_ready = '1' again)
    // TODO-UART: hardwire the puf_byte_reg to the uart tx
    uart_data_to_tx = puf_byte_reg;
    
    // TODO-SRAM: set all memory signal defaults/hardwired values
    //  so, also make sure that you are not constantly writing to memory:
    // wmask <= 0; // meaning: write mask that allows to not write single bits, can be kept 0 when writing always 16bit values
    // ... put other memory signal defaults here
    wmask = 16'b0;
    we = 1'b0;
    wdata = 16'b0;
    waddr = 13'b0;
    raddr = i_r[13:1];
    
    case (state)
        INIT :  begin
                    // dummy-send to clear usb-serial inputs
                    // this will leave a random byte on the PC side after each
                    // reset, which is already handled in the get_puf_from_device.py script
                    uart_tx_enable = 1'b1;
                end
        WAIT_FOR_REQUEST :
                begin
                    // keep defaults
                    // you can write something to memory for testing purpose:
                    //wdata <= i_w_r;
                    //we <= 1;
                end
        WAITCYCLE_FOR_MEMORY :
                begin
                    // keep defaults
                end
        PUF_READ :
                begin
                    // keep defaults
                end
        // TODO-UART: add whatever neccessary to the following two states,
        //  here and/or in the sequential always block above
        //  (not everything needs to be necessarily filled out! think about what you need..)
        UART_SEND :
                begin
                    uart_tx_enable = 1'b1;
                end
        UART_WAIT_FINISH :
                begin
                end
        LOOP_CONDITION :
                begin
                    // keep defaults
                end
        default : begin
                    // keep defaults
                    // INFO: This could be another spot where you can put your defaults,
                    //  instead of after always..begin.
                    //  However, it would also mean that in EVERY other condition here you need
                    //  to assign a value to what you put here, because we make combinational
                    //  logic. Otherwise synthesis would need to be able to save the last
                    //  assigned value, requiring some sort of loopback. Since this block is
                    //  not clock-sensitive, it would result in 'latches', that can lead to 
                    //  many problems if not handled properly (i.e. you usually don't want to
                    //  have latches in your design!).
                end
    endcase
end

endmodule
