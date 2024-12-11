
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [3:0] data_in_sum_of_ones;
  assign data_in_sum_of_ones = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];

  always_comb begin
    if ((data_in_sum_of_ones > 3'd4) || (data_in_sum_of_ones == 3'd4 && data_in[0] == 0))begin
      // do option 2
      qm_out[0] = data_in[0];
      for (integer i=1; i<8; i=i+1)begin
        qm_out[i] = !(data_in[i] ^ qm_out[i-1]);
      end
      qm_out[8] = 0;
    end else begin
      // do option 1
      qm_out[0] = data_in[0];
      for (integer i=1; i<8; i=i+1)begin
        qm_out[i] = data_in[i] ^ qm_out[i-1];
      end
      qm_out[8] = 1;
    end
  end





endmodule //end tm_choice
