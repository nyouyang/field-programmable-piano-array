`default_nettype none
module evt_counter
  ( input wire          clk_in,
    input wire          rst_in,
    input wire          evt_in,
    output logic[26:0]  count_out,
    input wire [16:0]   max_count
  );
 
  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 17'b0;
    end else begin
      if (evt_in) begin
          if (count_out == max_count - 1)begin
              count_out <= 0;
          end else begin
              count_out <= count_out + 1;
          end
      end
    end
  end
endmodule
`default_nettype wire