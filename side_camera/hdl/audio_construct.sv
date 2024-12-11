// `timescale 1ns / 1ps
// `default_nettype none

module audio_construct
	#(  
        parameter RESOLUTION = 256, // 2^8 
	    parameter SAMPLE_RATE = 128 // 2^7
	)
	(
        input wire 										 clk_in,
        input wire 										 rst_in,
        input wire [3:0]							     note_1_in,
        input wire [3:0]							     note_2_in,
        input wire [3:0]							     note_3_in,
        output logic							         spk_out
	);
    // sine wave lookup table
    logic [7:0] sine_lut [0:255] = '{
        127, 130, 133, 136, 139, 143, 146, 149,
        152, 155, 158, 161, 164, 167, 170, 173,
        176, 179, 182, 184, 187, 190, 193, 195,
        198, 200, 203, 205, 208, 210, 213, 215,
        217, 219, 221, 224, 226, 228, 229, 231,
        233, 235, 236, 238, 239, 241, 242, 244,
        245, 246, 247, 248, 249, 250, 251, 251,
        252, 253, 253, 254, 254, 254, 254, 254,
        255, 254, 254, 254, 254, 254, 253, 253,
        252, 251, 251, 250, 249, 248, 247, 246,
        245, 244, 242, 241, 239, 238, 236, 235,
        233, 231, 229, 228, 226, 224, 221, 219,
        217, 215, 213, 210, 208, 205, 203, 200,
        198, 195, 193, 190, 187, 184, 182, 179,
        176, 173, 170, 167, 164, 161, 158, 155,
        152, 149, 146, 143, 139, 136, 133, 130,
        127, 124, 121, 118, 115, 111, 108, 105,
        102, 99, 96, 93, 90, 87, 84, 81,
        78, 75, 72, 70, 67, 64, 61, 59,
        56, 54, 51, 49, 46, 44, 41, 39,
        37, 35, 33, 30, 28, 26, 25, 23,
        21, 19, 18, 16, 15, 13, 12, 10,
        9, 8, 7, 6, 5, 4, 3, 3,
        2, 1, 1, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 1, 1,
        2, 3, 3, 4, 5, 6, 7, 8,
        9, 10, 12, 13, 15, 16, 18, 19,
        21, 23, 25, 26, 28, 30, 33, 35,
        37, 39, 41, 44, 46, 49, 51, 54,
        56, 59, 61, 64, 67, 70, 72, 75,
        78, 81, 84, 87, 90, 93, 96, 99,
        102, 105, 108, 111, 115, 118, 121, 124
    };

    // frequency tuning word for octave starting at C4
    logic [31:0] ftw_values [0:11] = '{
        32'd15133,  // C4
        32'd16032,  // C#4
        32'd16986,  // D4
        32'd17996,  // D#4
        32'd19067,  // E4
        32'd20201,  // F4
        32'd21401,  // F#4
        32'd22675,  // G4
        32'd24022,  // G#4
        32'd25451,  // A4
        32'd26964,  // A#4
        32'd28567   // B4
    };

    logic [31:0] ftw_1;
    logic [31:0] ftw_2;
    logic [31:0] ftw_3;

    always_comb begin
        case (note_1_in)
            4'd1: ftw_1 = ftw_values[0];  // C4
            4'd2: ftw_1 = ftw_values[1];  // C#4
            4'd3: ftw_1 = ftw_values[2];  // D4
            4'd4: ftw_1 = ftw_values[3];  // D#4
            4'd5: ftw_1 = ftw_values[4];  // E4
            4'd6: ftw_1 = ftw_values[5];  // F4
            4'd7: ftw_1 = ftw_values[6];  // F#4
            4'd8: ftw_1 = ftw_values[7];  // G4
            4'd9: ftw_1 = ftw_values[8];  // G#4
            4'd10: ftw_1 = ftw_values[9];  // A4
            4'd11: ftw_1 = ftw_values[10]; // A#4
            4'd12: ftw_1 = ftw_values[11]; // B4
            default: ftw_1 = 32'd0;        // Default case
        endcase
    end

    always_comb begin
        case (note_2_in)
            4'd1: ftw_2 = ftw_values[0];  // C4
            4'd2: ftw_2 = ftw_values[1];  // C#4
            4'd3: ftw_2 = ftw_values[2];  // D4
            4'd4: ftw_2 = ftw_values[3];  // D#4
            4'd5: ftw_2 = ftw_values[4];  // E4
            4'd6: ftw_2 = ftw_values[5];  // F4
            4'd7: ftw_2 = ftw_values[6];  // F#4
            4'd8: ftw_2 = ftw_values[7];  // G4
            4'd9: ftw_2 = ftw_values[8];  // G#4
            4'd10: ftw_2 = ftw_values[9];  // A4
            4'd11: ftw_2 = ftw_values[10]; // A#4
            4'd12: ftw_2 = ftw_values[11]; // B4
            default: ftw_2 = 32'd0;        // Default case
        endcase
    end

    always_comb begin
        case (note_3_in)
            4'd1: ftw_3 = ftw_values[0];  // C4
            4'd2: ftw_3 = ftw_values[1];  // C#4
            4'd3: ftw_3 = ftw_values[2];  // D4
            4'd4: ftw_3 = ftw_values[3];  // D#4
            4'd5: ftw_3 = ftw_values[4];  // E4
            4'd6: ftw_3 = ftw_values[5];  // F4
            4'd7: ftw_3 = ftw_values[6];  // F#4
            4'd8: ftw_3 = ftw_values[7];  // G4
            4'd9: ftw_3 = ftw_values[8];  // G#4
            4'd10: ftw_3 = ftw_values[9];  // A4
            4'd11: ftw_3 = ftw_values[10]; // A#4
            4'd12: ftw_3 = ftw_values[11]; // B4
            default: ftw_3 = 32'd0;        // Default case
        endcase
    end


    logic [7:0] audio_sample_1;
    logic [7:0] audio_sample_2;
    logic [7:0] audio_sample_3;

    logic [31:0] phase_counter_1;
    logic [31:0] phase_counter_2;
    logic [31:0] phase_counter_3;

    always @(posedge clk_in) begin
        if (rst_in) begin
            phase_counter_1 <= 0;
            phase_counter_2 <= 0;
            phase_counter_3 <= 0;
        end else begin
            // wrap around at 32 bits, modulo 2^32
            phase_counter_1 <= phase_counter_1 + ftw_1; 
            phase_counter_2 <= phase_counter_2 + ftw_2;
            phase_counter_3 <= phase_counter_3 + ftw_3;
        end 
    end

    assign audio_sample_1 = sine_lut[phase_counter_1[31:24]];
    assign audio_sample_2 = sine_lut[phase_counter_2[31:24]];
    assign audio_sample_3 = sine_lut[phase_counter_3[31:24]];

    logic [7:0] line_out_audio;

    // scale before summing
    assign line_out_audio = (audio_sample_1 >> 2) + (audio_sample_2 >> 2) + (audio_sample_3 >> 2); 

    pwm pwm_audio
    (
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .dc_in(line_out_audio),
    .sig_out(spk_out)
    );

endmodule

// `default_nettype wire
