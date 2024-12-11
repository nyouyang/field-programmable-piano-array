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
	 // your code here
     logic [20:0] total_pixels;
     logic [31:0] x_sum;
     logic [31:0] y_sum;
     logic busy_out_x;
     logic busy_out_y;
     localparam RESTING = 2'b00;
     localparam SUMMING = 2'b01;
     localparam DIVIDING = 2'b10;
     logic [1:0] state;

     always_ff @(posedge clk_in) begin 
        if (rst_in) begin 
            total_pixels <= 0;
            x_sum <= 0;
            y_sum <= 0;
            state <= RESTING;
            valid_out <= 0;
        end else begin 
            case (state)
                RESTING: begin 
                    if (valid_in) begin 
                        total_pixels <= 1;
                        x_sum <= x_in;
                        y_sum <= y_in;
                    end else begin 
                        x_sum <= 0;
                        y_sum <= 0;
                        total_pixels <= 0;
                    end
                    state <= SUMMING;
                    valid_out <= 0;
                end
                SUMMING: begin 
                    if (valid_in) begin 
                        x_sum <= x_sum + x_in;
                        y_sum <= y_sum + y_in;
                        total_pixels <= total_pixels + 1;
                    end 
                    if (tabulate_in) begin 
                        if (total_pixels == 0) begin 
                            state <= RESTING;
                        end else begin 
                            state <= DIVIDING; 
                        end
                    end
                end 
                DIVIDING: begin 
                    if (!busy_out_x && !busy_out_y) begin 
                        valid_out <= 1;
                        state <= RESTING;
                    end 
                end
            endcase
        end
     end 
    divider x_com(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(x_sum),
        .divisor_in(total_pixels),
        .data_valid_in(tabulate_in),
        .quotient_out(x_out),
        .remainder_out(),
        .data_valid_out(),
        .error_out(),
        .busy_out(busy_out_x)
    );

    divider y_com(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dividend_in(y_sum),
        .divisor_in(total_pixels),
        .data_valid_in(tabulate_in),
        .quotient_out(y_out),
        .remainder_out(),
        .data_valid_out(),
        .error_out(),
        .busy_out(busy_out_y)
    );
endmodule

`default_nettype wire
