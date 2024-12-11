
module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [3:0] one_count;
  logic [3:0] zero_count;
  logic option;

  //your code here, friend
  always_comb begin 
    one_count = 0;
    for (integer i = 0; i < 8; i = i+1) begin 
      one_count = one_count + data_in[i];
    end
    zero_count = 4'b1000 - one_count;

    option = (one_count > 4'b0100 || (one_count == 4'b0100 & !data_in[0]));

    if (!option) begin 
      // option 1
      qm_out[0] = data_in[0];
      for (integer i = 1; i < 8; i = i+1) begin 
        qm_out[i] = (data_in[i] ^ qm_out[i-1]);
      end
      qm_out[8] = 1;
    end else begin 
      // option 2
      qm_out[0] = data_in[0];
      for (integer i = 1; i < 8; i = i+1) begin 
        qm_out[i] = data_in[i] ~^ qm_out[i-1];
      end
      qm_out[8] = 0;
    end
  end


endmodule //end tm_choice
