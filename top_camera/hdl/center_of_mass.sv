`default_nettype none
module center_of_mass (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] x_out,
                         output logic [9:0] y_out,
                         output logic valid_out);
	 
    localparam TABULATE_STATE = 0;
    localparam DIVIDE_STATE = 1;
    logic state;

    logic [31:0] sum_of_x_locations;
    logic [31:0] sum_of_y_locations;
    logic [31:0] num_pixels;

    logic x_start_signal;
    logic [31:0] x_quotient_out;
    logic [31:0] x_remainder_out;
    logic x_data_valid_out;
    logic x_error_out;
    logic x_busy_out;
    
    logic y_start_signal;
    logic [31:0] y_quotient_out;
    logic [31:0] y_remainder_out;
    logic y_data_valid_out;
    logic y_error_out;
    logic y_busy_out;

    logic x_done_dividing;
    logic y_done_dividing;

    logic valid_pixels_present;
    

    always_ff @(posedge clk_in) begin
        
        if (rst_in) begin
            state <= TABULATE_STATE;
            x_out <= 0;
            y_out <= 0;
            valid_out <= 0;
            sum_of_x_locations <= 0;
            sum_of_y_locations <= 0;
            num_pixels <= 0;
            valid_pixels_present <= 0;
            x_done_dividing <= 0;
            y_done_dividing <= 0;

        end else begin
            case(state)
                TABULATE_STATE: begin
                    valid_out <= 0;
                    // how to deal with case with 0 valid pixels??
                    if (tabulate_in) begin
                        if (valid_pixels_present) begin
                            state <= DIVIDE_STATE;
                        end else begin
                            num_pixels <= 0;
                            sum_of_x_locations <= 0;
                            sum_of_y_locations <= 0;
                            x_done_dividing <= 0;
                            y_done_dividing <= 0;
                            valid_pixels_present <= 0;
                        end
                    end else begin
                        if (valid_in) begin
                            sum_of_x_locations <= sum_of_x_locations + x_in;
                            sum_of_y_locations <= sum_of_y_locations + y_in;
                            valid_pixels_present <= 1;
                            num_pixels <= num_pixels + 1;
                        end                  
                    end
                end
                DIVIDE_STATE: begin

                    if (x_done_dividing && y_done_dividing) begin
                        x_out <= x_quotient_out[10:0];
                        y_out <= y_quotient_out[9:0];
                        valid_out <= 1;
                        state <= TABULATE_STATE;
                        num_pixels <= 0;
                        sum_of_x_locations <= 0;
                        sum_of_y_locations <= 0;
                        x_done_dividing <= 0;
                        y_done_dividing <= 0;
                        valid_pixels_present <= 0;

                    end else begin
                        if (!x_busy_out && !x_data_valid_out && !x_done_dividing) begin
                            x_start_signal <= 1;
                        end else begin
                            x_start_signal <= 0;
                        end
                        if (!x_busy_out && x_data_valid_out) begin
                            x_done_dividing <= 1;
                        end

                        if (!y_busy_out && !y_data_valid_out && !y_done_dividing) begin
                            y_start_signal <= 1;
                        end else begin
                            y_start_signal <= 0;
                        end
                        if (!y_busy_out && y_data_valid_out) begin
                            y_done_dividing <= 1;
                        end
                    end
                    
                end
            endcase
        end
    end

    divider x_divider ( .clk_in(clk_in),
                    .rst_in(rst_in),
                    .dividend_in(sum_of_x_locations),
                    .divisor_in(num_pixels),
                    .data_valid_in(x_start_signal),
                    .quotient_out(x_quotient_out),
                    .remainder_out(x_remainder_out),
                    .data_valid_out(x_data_valid_out),
                    .error_out(x_error_out),
                    .busy_out(x_busy_out)
                );

    divider y_divider ( .clk_in(clk_in),
                    .rst_in(rst_in),
                    .dividend_in(sum_of_y_locations),
                    .divisor_in(num_pixels),
                    .data_valid_in(y_start_signal),
                    .quotient_out(y_quotient_out),
                    .remainder_out(y_remainder_out),
                    .data_valid_out(y_data_valid_out),
                    .error_out(y_error_out),
                    .busy_out(y_busy_out)
                );


endmodule

`default_nettype wire
