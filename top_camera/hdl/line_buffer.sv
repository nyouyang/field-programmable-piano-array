`default_nettype none

module line_buffer (
            input wire clk_in, //system clock
            input wire rst_in, //system reset

            input wire [10:0] hcount_in, //current hcount being read
            input wire [9:0] vcount_in, //current vcount being read
            input wire [15:0] pixel_data_in, //incoming pixel
            input wire data_valid_in, //incoming  valid data signal

            output logic [KERNEL_SIZE-1:0][15:0] line_buffer_out, //output pixels of data
            output logic [10:0] hcount_out, //current hcount being read
            output logic [9:0] vcount_out, //current vcount being read
            output logic data_valid_out //valid data out signal
  );
  parameter HRES = 1280;
  parameter VRES = 720;

  localparam KERNEL_SIZE = 3;

  // to help you get started, here's a bram instantiation.
  // you'll want to create one BRAM for each row in the kernel, plus one more to
  // buffer incoming data from the wire:

  generate
    genvar i;
    for (i=0; i<4; i=i+1) begin
      xilinx_true_dual_port_read_first_1_clock_ram #(
        .RAM_WIDTH(16),
        .RAM_DEPTH(HRES),
        .RAM_PERFORMANCE("HIGH_PERFORMANCE")) line_buffer_ram (
        .clka(clk_in),     // Clock
        //writing port:
        .addra(hcount_in),   // Port A address bus,
        .dina(pixel_data_in),     // Port A RAM input data
        .wea(data_valid_in && (vcount_in[1:0] == i)),       // Port A write enable
        //reading port:
        .addrb(hcount_in),   // Port B address bus,
        .doutb(intermediate_result[i]),    // Port B RAM output data,
        .douta(),   // Port A RAM output data, width determined from RAM_WIDTH
        .dinb(0),     // Port B RAM input data, width determined from RAM_WIDTH
        .web(1'b0),       // Port B write enable
        .ena(1'b1),       // Port A RAM Enable
        .enb(1'b1),       // Port B RAM Enable,
        .rsta(1'b0),     // Port A output reset
        .rstb(1'b0),     // Port B output reset
        .regcea(1'b1), // Port A output register enable
        .regceb(1'b1) // Port B output register enable
      );
    end
  endgenerate

  logic [15:0] intermediate_result [3:0];

  always_comb begin
    case (vcount_in[1:0])
      2'b00: begin
        line_buffer_out = {intermediate_result[3], intermediate_result[2], intermediate_result[1]};
      end
      2'b01: begin
        line_buffer_out = {intermediate_result[0], intermediate_result[3], intermediate_result[2]};
      end
      2'b10: begin
        line_buffer_out = {intermediate_result[1], intermediate_result[0], intermediate_result[3]};
      end
      2'b11: begin
        line_buffer_out = {intermediate_result[2], intermediate_result[1], intermediate_result[0]};
      end
    endcase
  end
  

  logic data_valid_out_pipe;
  logic [10:0] hcount_out_pipe;
  logic [9:0] vcount_out_pipe;
  always_ff @(posedge clk_in) begin

    // pipeline data_valid_out
    data_valid_out_pipe <= data_valid_in;
    data_valid_out <= data_valid_out_pipe;

    // pipeline hcount_out
    hcount_out_pipe <= hcount_in;
    hcount_out <= hcount_out_pipe;

    // pipeline vcount_out
    vcount_out_pipe <= vcount_in;
    if (vcount_out_pipe >= 2) begin
      vcount_out <= vcount_out_pipe - 2;
    end else if (vcount_out_pipe == 1) begin
      vcount_out <= VRES-1;
    end else begin
      vcount_out <= VRES-2;
    end

  end


endmodule


`default_nettype wire

