`default_nettype none
module k_means (
                         input wire clk_in,
                         input wire rst_in,
                         input wire [10:0] x_in,
                         input wire [9:0]  y_in,
                        input wire [10:0] centroid_a_x,
                        input wire [9:0] centroid_a_y,
                        input wire [10:0] centroid_b_x,
                        input wire [9:0] centroid_b_y,
                        input wire [10:0] centroid_c_x,
                        input wire [9:0] centroid_c_y,
                         input wire valid_in,
                         input wire tabulate_in,
                         output logic [10:0] a_x_out,
                         output logic [9:0] a_y_out,
                            output logic [10:0] b_x_out,
                            output logic [9:0] b_y_out,
                            output logic [10:0] c_x_out,
                            output logic [9:0] c_y_out,
                         output logic valid_out);
	
    
    logic [31:0] a_x_sum;
    logic [31:0] a_y_sum;
    logic [31:0] a_total_count;
    logic [31:0] b_x_sum;
    logic [31:0] b_y_sum;
    logic [31:0] b_total_count;
    logic [31:0] c_x_sum;
    logic [31:0] c_y_sum;
    logic [31:0] c_total_count;

    function [31:0] manhattan_distance(
    input [31:0] x1,
    input [31:0] y1,
    input [31:0] x2,
    input [31:0] y2
    );
        logic [31:0] dx;
        logic [31:0] dy;

        // Compute absolute differences
        if (x1 > x2) 
            dx = x1 - x2;
        else 
            dx = x2 - x1;

        if (y1 > y2) 
            dy = y1 - y2;
        else 
            dy = y2 - y1;

        // Return Manhattan distance
        manhattan_distance = dx + dy;
    endfunction

    logic a_x_valid_out;
    logic a_y_valid_out;
    logic a_x_error_out;
    logic a_y_error_out;
    logic a_x_busy_out;
    logic a_y_busy_out;

    logic a_x_ready;
    logic a_y_ready;

    logic b_x_valid_out;
    logic b_y_valid_out;
    logic b_x_error_out;
    logic b_y_error_out;
    logic b_x_busy_out;
    logic b_y_busy_out;

    logic b_x_ready;
    logic b_y_ready;

    logic c_x_valid_out;
    logic c_y_valid_out;
    logic c_x_error_out;
    logic c_y_error_out;
    logic c_x_busy_out;
    logic c_y_busy_out;

    logic c_x_ready;
    logic c_y_ready;

    logic [31:0] distance_to_a;
    logic [31:0] distance_to_b;
    logic [31:0] distance_to_c;

    assign valid_out = a_x_ready && a_y_ready && b_x_ready && b_y_ready && c_x_ready && c_y_ready;

    always_ff @(posedge clk_in) begin
        if (rst_in || valid_out) begin
            a_x_sum = 0;
            a_y_sum = 0;
            a_total_count = 0;
            b_x_sum = 0;
            b_y_sum = 0;
            b_total_count = 0;
            c_x_sum = 0;
            c_y_sum = 0;
            c_total_count = 0;

            a_x_ready = 0;
            a_y_ready = 0;
            b_x_ready = 0;
            b_y_ready = 0;
            c_x_ready = 0;
            c_y_ready = 0;
        end else if (valid_in) begin
            distance_to_a = manhattan_distance(x_in, y_in, centroid_a_x, centroid_a_y);
            distance_to_b = manhattan_distance(x_in, y_in, centroid_b_x, centroid_b_y);
            distance_to_c = manhattan_distance(x_in, y_in, centroid_c_x, centroid_c_y);
            if (distance_to_a <= distance_to_b && distance_to_a <= distance_to_c) begin
                a_x_sum = a_x_sum + x_in;
                a_y_sum = a_y_sum + y_in;
                a_total_count = a_total_count + 1;
            end else if (distance_to_b <= distance_to_a && distance_to_b <= distance_to_c) begin
                b_x_sum = b_x_sum + x_in;
                b_y_sum = b_y_sum + y_in;
                b_total_count = b_total_count + 1;
            end else begin
                c_x_sum = c_x_sum + x_in;
                c_y_sum = c_y_sum + y_in;
                c_total_count = c_total_count + 1;
            end
        end
        if (!rst_in && !valid_out) begin
            a_x_ready <= a_x_ready || a_x_valid_out;
            a_y_ready <= a_y_ready || a_y_valid_out;
            b_x_ready <= b_x_ready || b_x_valid_out;
            b_y_ready <= b_y_ready || b_y_valid_out;
            c_x_ready <= c_x_ready || c_x_valid_out;
            c_y_ready <= c_y_ready || c_y_valid_out;
        end
    end

    divider a_x_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(a_x_sum),  
    .divisor_in(a_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(a_x_out),
    .remainder_out(),
    .data_valid_out(a_x_valid_out),
    .error_out(a_x_error_out),
    .busy_out(a_x_busy_out)
    );

    divider a_y_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(a_y_sum),  
    .divisor_in(a_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(a_y_out),
    .remainder_out(),
    .data_valid_out(a_y_valid_out),
    .error_out(a_y_error_out),
    .busy_out(a_y_busy_out)
    );

    divider b_x_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(b_x_sum),  
    .divisor_in(b_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(b_x_out),
    .remainder_out(),
    .data_valid_out(b_x_valid_out),
    .error_out(b_x_error_out),
    .busy_out(b_x_busy_out)
    );

    divider b_y_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(b_y_sum),  
    .divisor_in(b_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(b_y_out),
    .remainder_out(),
    .data_valid_out(b_y_valid_out),
    .error_out(b_y_error_out),
    .busy_out(b_y_busy_out)
    );

    divider c_x_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(c_x_sum),  
    .divisor_in(c_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(c_x_out),
    .remainder_out(),
    .data_valid_out(c_x_valid_out),
    .error_out(c_x_error_out),
    .busy_out(c_x_busy_out)
    );

    divider c_y_div(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .dividend_in(c_y_sum),  
    .divisor_in(c_total_count), 
    .data_valid_in(tabulate_in), 
    .quotient_out(c_y_out),
    .remainder_out(),
    .data_valid_out(c_y_valid_out),
    .error_out(c_y_error_out),
    .busy_out(c_y_busy_out)
    );

endmodule

`default_nettype wire


// `default_nettype none
// module k_means (
//                          input wire clk_in,
//                          input wire rst_in,
//                          input wire [10:0] x_in,
//                          input wire [9:0]  y_in,
//                          input wire valid_in,
//                          input wire tabulate_in,
//                          output logic [10:0] x_out,
//                          output logic [9:0] y_out,
//                          output logic valid_out);
	
//     // step 1: decide on 3 random centroid
//     // step 2: find distances from each centroid to each point, assign each point to a centroid
//     // step 3: find new center of masses of three new groups
//     // repeat steps 1-3 x times

//     logic [10:0] centroid_A_x;
//     logic [9:0] centroid_A_y;
//     logic [10:0] centroid_B_x;
//     logic [9:0] centroid_B_y;
//     logic [10:0] centroid_C_x;
//     logic [9:0] centroid_C_y;

//     logic [31:0] A_sum_of_x_locations;
//     logic [31:0] A_sum_of_y_locations;
//     logic [31:0] A_num_pixels;

//     logic [31:0] B_sum_of_x_locations;
//     logic [31:0] B_sum_of_y_locations;
//     logic [31:0] B_num_pixels;

//     logic [31:0] C_sum_of_x_locations;
//     logic [31:0] C_sum_of_y_locations;
//     logic [31:0] C_num_pixels;

    

//     always_ff @(posedge clk_in) begin

//         if (rst_in) begin
            
//         end else begin
            
//             if (valid_in) begin

//             end

//         end

//     end


//     localparam TABULATE_STATE = 0;
//     localparam DIVIDE_STATE = 1;
//     logic state;

//     logic [31:0] sum_of_x_locations;
//     logic [31:0] sum_of_y_locations;
//     logic [31:0] num_pixels;

//     logic x_start_signal;
//     logic [31:0] x_quotient_out;
//     logic [31:0] x_remainder_out;
//     logic x_data_valid_out;
//     logic x_error_out;
//     logic x_busy_out;
    
//     logic y_start_signal;
//     logic [31:0] y_quotient_out;
//     logic [31:0] y_remainder_out;
//     logic y_data_valid_out;
//     logic y_error_out;
//     logic y_busy_out;

//     logic x_done_dividing;
//     logic y_done_dividing;

//     logic valid_pixels_present;


//     always_ff @(posedge clk_in) begin
        
//         if (rst_in) begin
//             state <= TABULATE_STATE;
//             x_out <= 0;
//             y_out <= 0;
//             valid_out <= 0;
//             sum_of_x_locations <= 0;
//             sum_of_y_locations <= 0;
//             num_pixels <= 0;
//             valid_pixels_present <= 0;
//             x_done_dividing <= 0;
//             y_done_dividing <= 0;

//         end else begin
//             case(state)
//                 TABULATE_STATE: begin
//                     valid_out <= 0;
//                     // how to deal with case with 0 valid pixels??
//                     if (tabulate_in) begin
//                         if (valid_pixels_present) begin
//                             state <= DIVIDE_STATE;
//                         end else begin
//                             num_pixels <= 0;
//                             sum_of_x_locations <= 0;
//                             sum_of_y_locations <= 0;
//                             x_done_dividing <= 0;
//                             y_done_dividing <= 0;
//                             valid_pixels_present <= 0;
//                         end
//                     end else begin
//                         if (valid_in) begin
//                             sum_of_x_locations <= sum_of_x_locations + x_in;
//                             sum_of_y_locations <= sum_of_y_locations + y_in;
//                             valid_pixels_present <= 1;
//                             num_pixels <= num_pixels + 1;
//                         end                  
//                     end
//                 end
//                 DIVIDE_STATE: begin

//                     if (x_done_dividing && y_done_dividing) begin
//                         x_out <= x_quotient_out[10:0];
//                         y_out <= y_quotient_out[9:0];
//                         valid_out <= 1;
//                         state <= TABULATE_STATE;
//                         num_pixels <= 0;
//                         sum_of_x_locations <= 0;
//                         sum_of_y_locations <= 0;
//                         x_done_dividing <= 0;
//                         y_done_dividing <= 0;
//                         valid_pixels_present <= 0;

//                     end else begin
//                         if (!x_busy_out && !x_data_valid_out && !x_done_dividing) begin
//                             x_start_signal <= 1;
//                         end else begin
//                             x_start_signal <= 0;
//                         end
//                         if (!x_busy_out && x_data_valid_out) begin
//                             x_done_dividing <= 1;
//                         end

//                         if (!y_busy_out && !y_data_valid_out && !y_done_dividing) begin
//                             y_start_signal <= 1;
//                         end else begin
//                             y_start_signal <= 0;
//                         end
//                         if (!y_busy_out && y_data_valid_out) begin
//                             y_done_dividing <= 1;
//                         end
//                     end
                    
//                 end
//             endcase
//         end
//     end

//     divider x_divider ( .clk_in(clk_in),
//                     .rst_in(rst_in),
//                     .dividend_in(sum_of_x_locations),
//                     .divisor_in(num_pixels),
//                     .data_valid_in(x_start_signal),
//                     .quotient_out(x_quotient_out),
//                     .remainder_out(x_remainder_out),
//                     .data_valid_out(x_data_valid_out),
//                     .error_out(x_error_out),
//                     .busy_out(x_busy_out)
//                 );

//     divider y_divider ( .clk_in(clk_in),
//                     .rst_in(rst_in),
//                     .dividend_in(sum_of_y_locations),
//                     .divisor_in(num_pixels),
//                     .data_valid_in(y_start_signal),
//                     .quotient_out(y_quotient_out),
//                     .remainder_out(y_remainder_out),
//                     .data_valid_out(y_data_valid_out),
//                     .error_out(y_error_out),
//                     .busy_out(y_busy_out)
//                 );


// endmodule

// `default_nettype wire
