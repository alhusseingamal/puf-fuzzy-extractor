module top_level (
   input  CLK,
   input  RST,
   output [7:0] LED,
   input  UART_RX,
   output UART_TX
);
   parameter PUF_BITS_DEF = 131072;

   wire [7:0] data_to_tx;
   wire [7:0] data_from_rx;
   wire tx_enable, rx_ready;
   wire data_valid;
   wire uart_rx_s, uart_tx_s;

   reg [7:0] led_state;
   reg err;
   
   reg [22:0] counter = 0;

   uart uart_inst (
      .clk ( CLK ),
      .rst ( RST ),
      .txdatain ( data_to_tx ),
      .txrdyin ( tx_enable ),          // Top level -> UART, inform the UART TX to start sending a byte
      .rxpin ( uart_rx_s ),
      .rxdataout ( data_from_rx ),
      .rxrdyout ( rx_ready ),
      .txrdyout ( data_valid ),        // UART -> Top level, inform the Top level that sending a byte is done
      .txpin ( uart_tx_s ),
      .errout ( err )
   );
   defparam uart_inst.CLKS_PER_BIT = 104;
   
   puf_module puf_module_inst (
        .clk ( CLK ),
        .rst ( RST ),
        // receiving signals
        .uart_rx_ready ( rx_ready ),
        .uart_data_from_rx ( data_from_rx ),
        // sending signals
        .uart_tx_ready ( data_valid ),
        .uart_data_to_tx ( data_to_tx ),
        .uart_tx_enable ( tx_enable )
   );
   defparam puf_module_inst.PUF_BITS = PUF_BITS_DEF;

   assign UART_TX = uart_tx_s;
   assign uart_rx_s = UART_RX;
   assign LED = led_state;

   always @(posedge CLK, posedge RST) begin
     if (RST) begin
        begin
            counter <= 0;
            led_state <= 0;
        end
     end else begin
        if (counter < 6000000) begin
            counter <= counter + 1;
        end else begin
            led_state[0] <= led_state[0] ^ 1;
            counter <= 0;
        end
     end
   end

endmodule
