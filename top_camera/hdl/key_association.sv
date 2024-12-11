`default_nettype none

module key_association (
  input wire clk_in,
  input wire rst_in,
  input wire [8:0] x_coords_keys_top [12:0],
  input wire [8:0] x_coords_keys_bottom [7:0],
  input wire [7:0] y_coords_keys_white [1:0],
  input wire [7:0] y_coords_keys_black [2:0],
  input wire [8:0] x_com,
  input wire [7:0] y_com,

  output logic [3:0] note
  );

  // 0: invalid
  // 1: C
  // 2: C sharp
  // 3: D
  // 4: D sharp
  // 5: E
  // 6: F
  // 7: F sharp
  // 8: G
  // 9: G sharp
  // 10: A
  // 11: A sharp
  // 12: B

  // key boundaries and output in 320/180 format
  // can i do this combinationally?

  logic [13:0] x_bins_top;
  logic [8:0] x_bins_bottom;

  always_comb begin
    x_bins_top[13] = (x_com < x_coords_keys_top[12]);
    for (int i=1; i<13; i=i+1) begin
        x_bins_top[i] = (x_coords_keys_top[i] <= x_com) && (x_com < x_coords_keys_top[i-1]);
    end
    x_bins_top[0] = (x_coords_keys_top[0] <= x_com);


    x_bins_bottom[8] = (x_com < x_coords_keys_top[12]);
    x_bins_bottom[7] = (x_coords_keys_top[12] <= x_com) && (x_com < x_coords_keys_bottom[6]);
    for (int i=2; i<7; i=i+1) begin
        x_bins_bottom[i] = (x_coords_keys_bottom[i] <= x_com) && (x_com < x_coords_keys_bottom[i-1]);
    end
    x_bins_bottom[1] = (x_coords_keys_bottom[1]<= x_com) && (x_com < x_coords_keys_top[0]);
    x_bins_bottom[0] = (x_coords_keys_top[0] <= x_com);  
  end
  
  always_ff @(posedge clk_in) begin
      if (y_com < y_coords_keys_white[1] || y_com > y_coords_keys_white[0]) begin
          // invalid
          note <= 4'b0000;
      end else if ((y_coords_keys_black[1] > y_com) && (y_com >= y_coords_keys_white[1])) begin
          case (x_bins_top)
            14'b00_0000_0000_0001: begin
                // invalid
                note <= 0;
            end
            14'b00_0000_0000_0010: begin
                // C
                note <= 1;
            end
            14'b00_0000_0000_0100: begin
                // C sharp
                note <= 2;
            end
            14'b00_0000_0000_1000: begin
                // D
                note <= 3;
            end
            14'b00_0000_0001_0000: begin
                // D sharp
                note <= 4;
            end
            14'b00_0000_0010_0000: begin
                // E
                note <= 5;
            end
            14'b00_0000_0100_0000: begin
                // F
                note <= 6;
            end
            14'b00_0000_1000_0000: begin
                // F sharp
                note <= 7;
            end
            14'b00_0001_0000_0000: begin
                // G
                note <= 8;
            end
            14'b00_0010_0000_0000: begin
                // G sharp
                note <= 9;
            end
            14'b00_0100_0000_0000: begin
                // A
                note <= 10;
            end
            14'b00_1000_0000_0000: begin
                // A sharp
                note <= 11;
            end
            14'b01_0000_0000_0000: begin
                // B
                note <= 12;
            end
            14'b10_0000_0000_0000: begin
                // invalid
                note <= 0;
            end
          endcase
      end else if ((y_coords_keys_white[0] >= y_com) && (y_com >= y_coords_keys_black[1])) begin
          case (x_bins_bottom)
            9'b0_0000_0001: begin
                // invalid
                note <= 0;
            end
            9'b0_0000_0010: begin
                // C
                note <= 1;
            end
            9'b0_0000_0100: begin
                // D
                note <= 3;
            end
            9'b0_0000_1000: begin
                // E
                note <= 5;
            end
            9'b0_0001_0000: begin
                // F
                note <= 6;
            end
            9'b0_0010_0000: begin
                // G
                note <= 8;
            end
            9'b0_0100_0000: begin
                // A
                note <= 10;
            end
            9'b0_1000_0000: begin
                // B
                note <= 12;
            end
            9'b1_0000_0000: begin
                // invalid
                note <= 0;
            end
          endcase
      end
  end

endmodule

`default_nettype wire
