`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  logic [4:0] tally;
  logic [4:0] num_ones;
  logic [4:0] num_zeros;

  // can you assume these complete first before any sequential logic on rising edge??
  assign num_ones = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
  assign num_zeros = 4'd8 - q_m[0] - q_m[1] - q_m[2] - q_m[3] - q_m[4] - q_m[5] - q_m[6] - q_m[7];

  always_ff @(posedge clk_in) begin

    if (rst_in) begin
      tally <= 0;
      tmds_out <= 10'b0;

    end else begin

      if (ve_in) begin
        
        if (tally == 0 || num_ones == num_zeros) begin
        
          // update output
          tmds_out[9] <= !q_m[8];
          tmds_out[8] <= q_m[8];
          tmds_out[7:0] <= (q_m[8])?q_m[7:0]:~q_m[7:0];

          // update tally
          if (q_m[8] == 0) begin
            tally <= tally + num_zeros - num_ones;
          end else begin
            tally <= tally + num_ones - num_zeros;
          end

        end else begin
          
          if ((tally[4] == 0 && num_ones > num_zeros) || (tally[4] == 1 && num_zeros > num_ones)) begin
        
            // invert
            tmds_out[9] <= 1;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= ~q_m[7:0];
            // why is this + 2*q_m[8]??
            tally <= tally + 2'd2*q_m[8] + num_zeros - num_ones;

          end else begin
            
            // don't invert
            tmds_out[9] <= 0;
            tmds_out[8] <= q_m[8];
            tmds_out[7:0] <= q_m[7:0];
            // why is this - 2*!q_m[8]??
            // why is ~q_m[8] equal to -2 here but !q_m[8] equal to 0 when q_m[8] is 1??
            tally <= tally - 2'd2*(!q_m[8]) + num_ones - num_zeros;

          end
        end
      end else begin
        tally <= 0;
        case(control_in)
          2'b00: tmds_out <= 10'b1101010100;
          2'b01: tmds_out <= 10'b0010101011;
          2'b10: tmds_out <= 10'b0101010100;
          2'b11: tmds_out <= 10'b1010101011;
        endcase
      end
    end
  end

endmodule //end tmds_encoder
`default_nettype wire
