module spi_transmit
     #(parameter DATA_WIDTH = 12,
       parameter DATA_CLK_PERIOD = 20 // how long in clock cycles data should be transmitted
      )
      (input wire   clk_in, //system clock (100 MHz)
       input wire   rst_in, //reset in signal, when 1 put 0s on all controllable outputs except chip_sel_out 
       input wire   [DATA_WIDTH-1:0] data_in, //data to send, copi and should be stored internally 
       input wire   trigger_in, //start a transaction, when high transmit data in data_in w/ MSB and going down
 
       output logic chip_data_out, //(COPI) each bit will exist here for DATA__CLK_PERIOD
       output logic chip_clk_out, //(DCLK), no flipflops, tells downstream when to sample values of data_out -- when low to high, should sample value has in data_out and new data should be replaced when high to low -- duty cycle must be 50%, must be 50% of even value of DATA_CLK_PERIOD 
       output logic chip_sel_out // (CS), normally high but is low before start of transmission of data and back to high when data transmitted 
      );

    
    logic prev_trigger;
    logic prev_cs;
    logic prev_dclk;
    parameter DATA_NUMBER = $clog2(DATA_WIDTH);
    logic [DATA_NUMBER-1:0] transaction_number;
    logic [DATA_WIDTH-1:0] data_in_internal;
    logic [DATA_WIDTH-1:0] values_sent_out; // values from controller sent to peripheral 
    parameter DUTY_CYCLE = (DATA_CLK_PERIOD[0] == 1)? (DATA_CLK_PERIOD - 1) >> 1: (DATA_CLK_PERIOD >> 1);
    parameter COUNTER_SIZE = $clog2(DUTY_CYCLE);
    logic [COUNTER_SIZE:0] dclk_counter;
    logic dclk_cycle;
    
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            // when 1, put 0s on all controllable outputs
            chip_sel_out <= 1;
            chip_clk_out <= 0; 
            transaction_number <= 0;
            dclk_cycle <= 0;
            prev_dclk <= 0;
            data_in_internal <= 0;
        end else if (((trigger_in && !prev_trigger) || (!chip_sel_out && prev_cs)) && dclk_cycle != 1) begin 
            // trigger OR when CS is 0, transaction is beginning, and duty cycle has not started yet
            chip_sel_out <= 0;
            data_in_internal <= data_in;
            transaction_number <= 0;
            chip_data_out <= data_in[DATA_WIDTH-1];
            values_sent_out <= data_in[DATA_WIDTH-1];
            // begin dclk with low and 50% duty cycle
            dclk_cycle <= 1; // cycle beginning with low
            dclk_counter <= 1;
        end 

        //duty cycle 
        if (dclk_cycle == 1) begin 
            if (dclk_counter == DUTY_CYCLE-1) begin
                if (chip_clk_out == 1) begin // high to low
                    if ((transaction_number) == DATA_WIDTH-1) begin // last transaction finished 
                        // chip_data_out <= data_in_internal[DATA_WIDTH-transaction_number-1];
                        chip_data_out <= 0;
                        // values_sent_out <= {values_sent_out[DATA_WIDTH-2:0],data_in_internal[DATA_WIDTH-transaction_number-1]};
                        dclk_cycle <= 0;
                        dclk_counter <= 0;
                        chip_sel_out <= 1;
                        transaction_number <= 0;
                    end else begin 
                        // next transaction
                        transaction_number <= transaction_number + 1;
                        chip_data_out <= data_in_internal[DATA_WIDTH-transaction_number-2];
                        values_sent_out <= {values_sent_out[DATA_WIDTH-2:0],data_in_internal[DATA_WIDTH-transaction_number-2]};
                    end 
                    chip_clk_out <= 0;// set to low
                end else begin // low to high
                    chip_clk_out <= 1; // set to high
                    end
                dclk_counter <= 0; // at end of duty cylce, reset the counter
            end else begin 
                dclk_counter <= dclk_counter + 1; // cycle running, continue increasing
            end
        end else begin // dclk not running, make counter = 0
            dclk_counter <= 0;
        end
        
        prev_trigger <= trigger_in;
        prev_cs <= chip_sel_out;
        prev_dclk <= chip_clk_out;

    end

endmodule