`timescale 1ns / 1ps
`default_nettype none


module convolution (
    input wire clk_in,
    input wire rst_in,
    input wire [KERNEL_SIZE-1:0][15:0] data_in,
    input wire [10:0] hcount_in,
    input wire [9:0] vcount_in,
    input wire data_valid_in,
    output logic data_valid_out,
    output logic [10:0] hcount_out,
    output logic [9:0] vcount_out,
    output logic [15:0] line_out
    );

    parameter K_SELECT = 0;
    localparam KERNEL_SIZE = 3;


    // Your code here!

    /* Note that the coeffs output of the kernels module
     * is packed in all dimensions, so coeffs should be
     * defined as `logic signed [2:0][2:0][7:0] coeffs`
     *
     * This is because iVerilog seems to be weird about passing
     * signals between modules that are unpacked in more
     * than one dimension - even though this is perfectly
     * fine Verilog.
     */

    // pixel cache is unsigned
    logic [15:0] nine_pixel_cache [2:0][2:0];
    logic signed [2:0][2:0][7:0] coeffs;
    logic signed [7:0] shift;
    logic signed [15:0] red_pixel_cache [2:0][2:0];
    logic signed [15:0] green_pixel_cache [2:0][2:0];
    logic signed [15:0] blue_pixel_cache [2:0][2:0];
    logic signed [15:0] red_pixel_preprocessed;
    logic signed [15:0] green_pixel_preprocessed;
    logic signed [15:0] blue_pixel_preprocessed;

    logic data_valid_out_pipe [2:0];
    logic [10:0] hcount_out_pipe [2:0];
    logic [9:0] vcount_out_pipe [2:0];

    // instantiate kernel and get coeffs
    kernels #(
        .K_SELECT(K_SELECT)) conv_kernel (
        .rst_in(rst_in),
        .coeffs(coeffs),
        .shift(shift));


    always_ff @(posedge clk_in) begin

        if (rst_in) begin
            data_valid_out <= data_valid_in;
            hcount_out <= hcount_in;
            vcount_out <= vcount_in;
            line_out <= data_in[1];

        end else begin
            if (data_valid_in) begin

                // shift middle column left
                nine_pixel_cache[0][0] <= nine_pixel_cache[0][1];
                nine_pixel_cache[1][0] <= nine_pixel_cache[1][1];
                nine_pixel_cache[2][0] <= nine_pixel_cache[2][1];

                // shift right column left
                nine_pixel_cache[0][1] <= nine_pixel_cache[0][2];
                nine_pixel_cache[1][1] <= nine_pixel_cache[1][2];
                nine_pixel_cache[2][1] <= nine_pixel_cache[2][2];

                // shift line buffer into right column
                nine_pixel_cache[0][2] <= data_in[0];
                nine_pixel_cache[1][2] <= data_in[1];
                nine_pixel_cache[2][2] <= data_in[2];

            end

            // red channel
            red_pixel_cache[0][0] <= $signed({1'b0, nine_pixel_cache[0][0][15:11]}) * $signed(coeffs[0][0]);
            red_pixel_cache[0][1] <= $signed({1'b0, nine_pixel_cache[0][1][15:11]}) * $signed(coeffs[0][1]);
            red_pixel_cache[0][2] <= $signed({1'b0, nine_pixel_cache[0][2][15:11]}) * $signed(coeffs[0][2]);
            red_pixel_cache[1][0] <= $signed({1'b0, nine_pixel_cache[1][0][15:11]}) * $signed(coeffs[1][0]);
            red_pixel_cache[1][1] <= $signed({1'b0, nine_pixel_cache[1][1][15:11]}) * $signed(coeffs[1][1]);
            red_pixel_cache[1][2] <= $signed({1'b0, nine_pixel_cache[1][2][15:11]}) * $signed(coeffs[1][2]);
            red_pixel_cache[2][0] <= $signed({1'b0, nine_pixel_cache[2][0][15:11]}) * $signed(coeffs[2][0]);
            red_pixel_cache[2][1] <= $signed({1'b0, nine_pixel_cache[2][1][15:11]}) * $signed(coeffs[2][1]);
            red_pixel_cache[2][2] <= $signed({1'b0, nine_pixel_cache[2][2][15:11]}) * $signed(coeffs[2][2]);

            red_pixel_preprocessed <= ($signed(red_pixel_cache[0][0]) + $signed(red_pixel_cache[0][1]) + $signed(red_pixel_cache[0][2]) + $signed(red_pixel_cache[1][0]) + $signed(red_pixel_cache[1][1]) + $signed(red_pixel_cache[1][2]) + $signed(red_pixel_cache[2][0]) + $signed(red_pixel_cache[2][1]) + $signed(red_pixel_cache[2][2])) >>> shift;

            if (red_pixel_preprocessed < 16'sb0) begin
                line_out[15:11] <= 5'b0;
            end else if (red_pixel_preprocessed > 16'sd31) begin
                line_out[15:11] <= 5'd31;
            end else begin
                line_out[15:11] <= red_pixel_preprocessed[4:0];
            end

            // green channel
            green_pixel_cache[0][0] <= $signed({1'b0, nine_pixel_cache[0][0][10:5]}) * $signed(coeffs[0][0]);
            green_pixel_cache[0][1] <= $signed({1'b0, nine_pixel_cache[0][1][10:5]}) * $signed(coeffs[0][1]);
            green_pixel_cache[0][2] <= $signed({1'b0, nine_pixel_cache[0][2][10:5]}) * $signed(coeffs[0][2]);
            green_pixel_cache[1][0] <= $signed({1'b0, nine_pixel_cache[1][0][10:5]}) * $signed(coeffs[1][0]);
            green_pixel_cache[1][1] <= $signed({1'b0, nine_pixel_cache[1][1][10:5]}) * $signed(coeffs[1][1]);
            green_pixel_cache[1][2] <= $signed({1'b0, nine_pixel_cache[1][2][10:5]}) * $signed(coeffs[1][2]);
            green_pixel_cache[2][0] <= $signed({1'b0, nine_pixel_cache[2][0][10:5]}) * $signed(coeffs[2][0]);
            green_pixel_cache[2][1] <= $signed({1'b0, nine_pixel_cache[2][1][10:5]}) * $signed(coeffs[2][1]);
            green_pixel_cache[2][2] <= $signed({1'b0, nine_pixel_cache[2][2][10:5]}) * $signed(coeffs[2][2]);

            green_pixel_preprocessed <= ($signed(green_pixel_cache[0][0]) + $signed(green_pixel_cache[0][1]) + $signed(green_pixel_cache[0][2]) + $signed(green_pixel_cache[1][0]) + $signed(green_pixel_cache[1][1]) + $signed(green_pixel_cache[1][2]) + $signed(green_pixel_cache[2][0]) + $signed(green_pixel_cache[2][1]) + $signed(green_pixel_cache[2][2])) >>> shift;

            if (green_pixel_preprocessed < 16'sb0) begin
                line_out[10:5] <= 6'b0;
            end else if (green_pixel_preprocessed > 16'sd63) begin
                line_out[10:5] <= 6'd63;
            end else begin
                line_out[10:5] <= green_pixel_preprocessed[5:0];
            end

            // blue channel
            blue_pixel_cache[0][0] <= $signed({1'b0, nine_pixel_cache[0][0][4:0]}) * $signed(coeffs[0][0]);
            blue_pixel_cache[0][1] <= $signed({1'b0, nine_pixel_cache[0][1][4:0]}) * $signed(coeffs[0][1]);
            blue_pixel_cache[0][2] <= $signed({1'b0, nine_pixel_cache[0][2][4:0]}) * $signed(coeffs[0][2]);
            blue_pixel_cache[1][0] <= $signed({1'b0, nine_pixel_cache[1][0][4:0]}) * $signed(coeffs[1][0]);
            blue_pixel_cache[1][1] <= $signed({1'b0, nine_pixel_cache[1][1][4:0]}) * $signed(coeffs[1][1]);
            blue_pixel_cache[1][2] <= $signed({1'b0, nine_pixel_cache[1][2][4:0]}) * $signed(coeffs[1][2]);
            blue_pixel_cache[2][0] <= $signed({1'b0, nine_pixel_cache[2][0][4:0]}) * $signed(coeffs[2][0]);
            blue_pixel_cache[2][1] <= $signed({1'b0, nine_pixel_cache[2][1][4:0]}) * $signed(coeffs[2][1]);
            blue_pixel_cache[2][2] <= $signed({1'b0, nine_pixel_cache[2][2][4:0]}) * $signed(coeffs[2][2]);

            blue_pixel_preprocessed <= ($signed(blue_pixel_cache[0][0]) + $signed(blue_pixel_cache[0][1]) + $signed(blue_pixel_cache[0][2]) + $signed(blue_pixel_cache[1][0]) + $signed(blue_pixel_cache[1][1]) + $signed(blue_pixel_cache[1][2]) + $signed(blue_pixel_cache[2][0]) + $signed(blue_pixel_cache[2][1]) + $signed(blue_pixel_cache[2][2])) >>> shift;

            if (blue_pixel_preprocessed < 16'sb0) begin
                line_out[4:0] <= 5'b0;
            end else if (blue_pixel_preprocessed > 16'sd31) begin
                line_out[4:0] <= 5'd31;
            end else begin
                line_out[4:0] <= blue_pixel_preprocessed[4:0];
            end

            // pipeline outputs
            data_valid_out_pipe[0] <= data_valid_in;
            data_valid_out_pipe[1] <= data_valid_out_pipe[0];
            data_valid_out_pipe[2] <= data_valid_out_pipe[1];
            data_valid_out <= data_valid_out_pipe[2];

            hcount_out_pipe[0] <= hcount_in;
            hcount_out_pipe[1] <= hcount_out_pipe[0];
            hcount_out_pipe[2] <= hcount_out_pipe[1];
            hcount_out <= hcount_out_pipe[2];

            vcount_out_pipe[0] <= vcount_in;
            vcount_out_pipe[1] <= vcount_out_pipe[0];
            vcount_out_pipe[2] <= vcount_out_pipe[1];
            vcount_out <= vcount_out_pipe[2];

        end
    end



    // always_ff @(posedge clk_in) begin
    //   // Make sure to have your output be set with registered logic!
    //   // Otherwise you'll have timing violations.
    // end

endmodule

`default_nettype wire

