`default_nettype none

module sobel_masking (
  input wire clk_in,
  input wire rst_in,

  input wire data_valid_in,
  input wire [15:0] pixel_data_in,
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,

  output logic data_valid_out,
  output logic pixel_data_out,
  output logic [10:0] hcount_out,
  output logic [9:0] vcount_out
  );

  // 4 cycle latency

  logic [9:0] y1, cr1, cb1;

  rgb_to_ycrcb sobel_rgb_ycrcb (
      .clk_in(clk_in),
      .r_in({pixel_data_in[15:11],3'b0}),
      .g_in({pixel_data_in[10:5], 2'b0}),
      .b_in({pixel_data_in[4:0],3'b0}),
      .y_out(y1),
      .cr_out(cr1),
      .cb_out(cb1)
  );

  always_ff @(posedge clk_in) begin
    if (y1 > 10'b0_000_111_111) begin
        pixel_data_out <= 1;
    end else begin
        pixel_data_out <= 0;
    end
  end

  // pipeline everything else 

  logic [10:0] hcount_pipe [2:0];
  logic [9:0] vcount_pipe [2:0];
  logic data_valid_pipe [2:0];

  always_ff @(posedge clk_in) begin
    hcount_pipe[0] <= hcount_in;
    for (int i=1; i<3; i = i+1)begin
      hcount_pipe[i] <= hcount_pipe[i-1];
    end
    hcount_out <= hcount_pipe[2];

    vcount_pipe[0] <= vcount_in;
    for (int i=1; i<3; i = i+1)begin
      vcount_pipe[i] <= vcount_pipe[i-1];
    end
    vcount_out <= vcount_pipe[2];

    data_valid_pipe[0] <= data_valid_in;
    for (int i=1; i<3; i = i+1)begin
      data_valid_pipe[i] <= data_valid_pipe[i-1];
    end
    data_valid_out <= data_valid_pipe[2];
  end

endmodule

`default_nettype wire
