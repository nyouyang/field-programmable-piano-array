module spi_receive
     #(parameter DATA_WIDTH = 12,
       parameter DATA_CLK_PERIOD = 20 // how long in clock cycles data should be transmitted
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal, when 1 put 0s on all controllable outputs except chip_sel_out 

       input wire   chip_sel_in, //start a transaction, when high transmit data in data_in w/ MSB and going down
       input logic chip_data_in, //(COPI) each bit will exist here for DATA__CLK_PERIOD
       input logic chip_clk_in, //(DCLK), no flipflops, tells downstream when to sample values of data_out -- when low to high, should sample value has in data_out
       output logic [DATA_WIDTH-1:0] data_out, //data received!
       output logic data_valid_out //high when output data is present.
      );
    //your code here
    logic prev_cs;
    logic prev_dclk;
    logic transmitting;
    logic [DATA_WIDTH-1:0] data_out_internal; // data received from the peripheral, will show as data_out later
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // when 1, put 0s on all controllable outputs
            data_out <= 0;
            data_valid_out <= 0;
            prev_dclk <= 0;
            data_out_internal <= 0;
            transmitting <= 0;
        end else if (((!chip_sel_in && prev_cs))) begin 
            // when CS is pulled low, transaction is beginning
            transmitting <= 1;
            data_out_internal <= 0;
            data_out <= 0;
            data_valid_out <= 0;
        end else if (chip_sel_in && !prev_cs) begin 
            // done transmitting
            transmitting <= 0;
            data_out <= data_out_internal;
            data_valid_out <= 1;
        end else if (transmitting && chip_clk_in && !prev_dclk) begin 
            // sample on duty cycle rising edge
            data_out_internal <= {data_out_internal[DATA_WIDTH-2:0],chip_data_in};
        end else begin 
            data_valid_out <= 0;
        end

        prev_cs <= chip_sel_in;
        prev_dclk <= chip_clk_in;

    end

endmodule