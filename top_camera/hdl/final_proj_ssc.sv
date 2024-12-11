`timescale 1ns / 1ps
`default_nettype none

module final_proj_ssc #(parameter COUNT_TO = 100000)
                                (   input wire         clk_in,
                                    input wire         rst_in,
                                    input wire [3:0]  thumb_note,
                                    input wire [3:0]  middle_note,
                                    input wire [3:0]  pinky_note,
                                    output logic[6:0]   cat_out,
                                    output logic[7:0]   an_out
                                 );

  logic[7:0]      segment_state;
  logic[31:0]     segment_counter;
  logic [6:0]     led_out;
  logic [6:0] thumb_symbol_cat [1:0];
  logic [6:0] middle_symbol_cat [1:0];
  logic [6:0] pinky_symbol_cat [1:0];
  always_comb begin
    case(thumb_note)
      4'b0000: thumb_symbol_cat[0] = 7'b0111111; //0 (invalid, 00)
      4'b0001: thumb_symbol_cat[0] = 7'b0000000; //null (C )
      4'b0010: thumb_symbol_cat[0] = 7'b1101101; //S (CS)
      4'b0011: thumb_symbol_cat[0] = 7'b0000000; //null (D )
      4'b0100: thumb_symbol_cat[0] = 7'b1101101; //S (DS)
      4'b0101: thumb_symbol_cat[0] = 7'b0000000; //null (E )
      4'b0110: thumb_symbol_cat[0] = 7'b0000000; //null (F )
      4'b0111: thumb_symbol_cat[0] = 7'b1101101; //S (FS)
      4'b1000: thumb_symbol_cat[0] = 7'b0000000; //null (G )
      4'b1001: thumb_symbol_cat[0] = 7'b1101101; //S (GS)
      4'b1010: thumb_symbol_cat[0] = 7'b0000000; //null (A )
      4'b1011: thumb_symbol_cat[0] = 7'b1101101; //S (AS)
      4'b1100: thumb_symbol_cat[0] = 7'b0000000; //null (B )
    endcase
  end

  always_comb begin
    case(thumb_note)
      4'b0000: thumb_symbol_cat[1] = 7'b0111111; //0 (invalid, 00)
      4'b0001: thumb_symbol_cat[1] = 7'b0111001; //C (C )
      4'b0010: thumb_symbol_cat[1] = 7'b0111001; //C (CS)
      4'b0011: thumb_symbol_cat[1] = 7'b1011110; //D (D )
      4'b0100: thumb_symbol_cat[1] = 7'b1011110; //D (DS)
      4'b0101: thumb_symbol_cat[1] = 7'b1111001; //E (E )
      4'b0110: thumb_symbol_cat[1] = 7'b1110001; //F (F )
      4'b0111: thumb_symbol_cat[1] = 7'b1110001; //F (FS)
      4'b1000: thumb_symbol_cat[1] = 7'b0111101; //G (G )
      4'b1001: thumb_symbol_cat[1] = 7'b0111101; //G (GS)
      4'b1010: thumb_symbol_cat[1] = 7'b1110111; //A (A )
      4'b1011: thumb_symbol_cat[1] = 7'b1110111; //A (AS)
      4'b1100: thumb_symbol_cat[1] = 7'b1111100; //B (B )
    endcase
  end

  always_comb begin
    case(middle_note)
      4'b0000: middle_symbol_cat[0] = 7'b0111111; //0 (invalid, 00)
      4'b0001: middle_symbol_cat[0] = 7'b0000000; //null (C )
      4'b0010: middle_symbol_cat[0] = 7'b1101101; //S (CS)
      4'b0011: middle_symbol_cat[0] = 7'b0000000; //null (D )
      4'b0100: middle_symbol_cat[0] = 7'b1101101; //S (DS)
      4'b0101: middle_symbol_cat[0] = 7'b0000000; //null (E )
      4'b0110: middle_symbol_cat[0] = 7'b0000000; //null (F )
      4'b0111: middle_symbol_cat[0] = 7'b1101101; //S (FS)
      4'b1000: middle_symbol_cat[0] = 7'b0000000; //null (G )
      4'b1001: middle_symbol_cat[0] = 7'b1101101; //S (GS)
      4'b1010: middle_symbol_cat[0] = 7'b0000000; //null (A )
      4'b1011: middle_symbol_cat[0] = 7'b1101101; //S (AS)
      4'b1100: middle_symbol_cat[0] = 7'b0000000; //null (B )
    endcase
  end

  always_comb begin
    case(middle_note)
      4'b0000: middle_symbol_cat[1] = 7'b0111111; //0 (invalid, 00)
      4'b0001: middle_symbol_cat[1] = 7'b0111001; //C (C )
      4'b0010: middle_symbol_cat[1] = 7'b0111001; //C (CS)
      4'b0011: middle_symbol_cat[1] = 7'b1011110; //D (D )
      4'b0100: middle_symbol_cat[1] = 7'b1011110; //D (DS)
      4'b0101: middle_symbol_cat[1] = 7'b1111001; //E (E )
      4'b0110: middle_symbol_cat[1] = 7'b1110001; //F (F )
      4'b0111: middle_symbol_cat[1] = 7'b1110001; //F (FS)
      4'b1000: middle_symbol_cat[1] = 7'b0111101; //G (G )
      4'b1001: middle_symbol_cat[1] = 7'b0111101; //G (GS)
      4'b1010: middle_symbol_cat[1] = 7'b1110111; //A (A )
      4'b1011: middle_symbol_cat[1] = 7'b1110111; //A (AS)
      4'b1100: middle_symbol_cat[1] = 7'b1111100; //B (B )
    endcase
  end

  always_comb begin
    case(pinky_note)
      4'b0000: pinky_symbol_cat[0] = 7'b0111111; //0 (invalid, 00)
      4'b0001: pinky_symbol_cat[0] = 7'b0000000; //null (C )
      4'b0010: pinky_symbol_cat[0] = 7'b1101101; //S (CS)
      4'b0011: pinky_symbol_cat[0] = 7'b0000000; //null (D )
      4'b0100: pinky_symbol_cat[0] = 7'b1101101; //S (DS)
      4'b0101: pinky_symbol_cat[0] = 7'b0000000; //null (E )
      4'b0110: pinky_symbol_cat[0] = 7'b0000000; //null (F )
      4'b0111: pinky_symbol_cat[0] = 7'b1101101; //S (FS)
      4'b1000: pinky_symbol_cat[0] = 7'b0000000; //null (G )
      4'b1001: pinky_symbol_cat[0] = 7'b1101101; //S (GS)
      4'b1010: pinky_symbol_cat[0] = 7'b0000000; //null (A )
      4'b1011: pinky_symbol_cat[0] = 7'b1101101; //S (AS)
      4'b1100: pinky_symbol_cat[0] = 7'b0000000; //null (B )
    endcase
  end

  always_comb begin
    case(pinky_note)
      4'b0000: pinky_symbol_cat[1] = 7'b0111111; //0 (invalid, 00)
      4'b0001: pinky_symbol_cat[1] = 7'b0111001; //C (C )
      4'b0010: pinky_symbol_cat[1] = 7'b0111001; //C (CS)
      4'b0011: pinky_symbol_cat[1] = 7'b1011110; //D (D )
      4'b0100: pinky_symbol_cat[1] = 7'b1011110; //D (DS)
      4'b0101: pinky_symbol_cat[1] = 7'b1111001; //E (E )
      4'b0110: pinky_symbol_cat[1] = 7'b1110001; //F (F )
      4'b0111: pinky_symbol_cat[1] = 7'b1110001; //F (FS)
      4'b1000: pinky_symbol_cat[1] = 7'b0111101; //G (G )
      4'b1001: pinky_symbol_cat[1] = 7'b0111101; //G (GS)
      4'b1010: pinky_symbol_cat[1] = 7'b1110111; //A (A )
      4'b1011: pinky_symbol_cat[1] = 7'b1110111; //A (AS)
      4'b1100: pinky_symbol_cat[1] = 7'b1111100; //B (B )
    endcase
  end

  assign cat_out = ~led_out;
  assign an_out = ~segment_state;

  always_comb begin
    case(segment_state)
      8'b0000_0001:   led_out = pinky_symbol_cat[0];
      8'b0000_0010:   led_out = pinky_symbol_cat[1];
      8'b0000_0100:   led_out = 7'b0000000;
      8'b0000_1000:   led_out = middle_symbol_cat[0];
      8'b0001_0000:   led_out = middle_symbol_cat[1];
      8'b0010_0000:   led_out = 7'b0000000;
      8'b0100_0000:   led_out = thumb_symbol_cat[0];
      8'b1000_0000:   led_out = thumb_symbol_cat[1];
      default:        led_out = 7'b0000000;
    endcase
  end

  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      segment_state <= 8'b0000_0001;
      segment_counter <= 32'b0;
    end else begin
      if (segment_counter == COUNT_TO)begin
          segment_counter <= 32'd0;
          segment_state <= {segment_state[6:0],segment_state[7]};
      end else begin
          segment_counter <= segment_counter +1;
      end
    end
  end
endmodule //seven_segment_controller


`default_nettype wire

