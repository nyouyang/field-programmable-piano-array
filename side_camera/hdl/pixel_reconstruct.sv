`timescale 1ns / 1ps
`default_nettype none

module pixel_reconstruct
	#(
	 parameter HCOUNT_WIDTH = 11,
	 parameter VCOUNT_WIDTH = 10
	 )
	(
	 input wire 										 clk_in,
	 input wire 										 rst_in,
	 input wire 										 camera_pclk_in,
	 input wire 										 camera_hs_in,
	 input wire 										 camera_vs_in,
	 input wire [7:0] 							 camera_data_in,
	 output logic 									 pixel_valid_out,
	 output logic [HCOUNT_WIDTH-1:0] pixel_hcount_out,
	 output logic [VCOUNT_WIDTH-1:0] pixel_vcount_out,
	 output logic [15:0] 						 pixel_data_out
	 );

	 // your code here! and here's a handful of logics that you may find helpful to utilize.
	 
	 // previous value of PCLK
	 logic 													 pclk_prev;

	 // can be assigned combinationally:
	 //  true when pclk transitions from 0 to 1
	 logic 													 camera_sample_valid;
	 assign camera_sample_valid = (!pclk_prev && camera_pclk_in); 
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic 													 last_sampled_hs;
	 logic [7:0] 										 last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic 													 half_pixel_ready;

	 logic [HCOUNT_WIDTH:0] pixel_row_count;

	 always_ff@(posedge clk_in) begin
			if (rst_in) begin
				pixel_hcount_out <= 0;
				pixel_vcount_out <= 0;
				pixel_valid_out <= 0;
				half_pixel_ready <= 0;
				pixel_data_out <= 0;
				pixel_row_count <= 0;
			end else begin
				 if (camera_sample_valid) begin
					if (camera_hs_in && camera_vs_in) begin 
						if (!half_pixel_ready) begin 
							// getting first part of new pixel
							last_sampled_data <= camera_data_in;
							pixel_valid_out <= 0;
							half_pixel_ready <= 1;
						end else begin 
							// getting second part of new pixel
							pixel_data_out <= {last_sampled_data, camera_data_in};
							pixel_valid_out <= 1;
							half_pixel_ready <= 0;
							pixel_row_count <= pixel_row_count + 1;
							if (pixel_row_count == 0) begin 
								pixel_hcount_out <= 0;
							end else begin 
								pixel_hcount_out <= pixel_hcount_out + 1;
							end
						end
					end else begin 
						// data no longer valid
						half_pixel_ready <= 0;
					end

					if (!camera_vs_in) begin 
						// if low, frame completed and want in top left
						pixel_hcount_out <= 0;
						pixel_vcount_out <= 0;
						pixel_row_count <= 0;
						pixel_valid_out <= 0;
					end else if (last_sampled_hs && !camera_hs_in) begin
						// if hsync goes from high to low, move to next row
						pixel_hcount_out <= 0;
						pixel_vcount_out <= pixel_vcount_out + 1;
						pixel_row_count <= 0;
					end
					last_sampled_hs <= camera_hs_in;
				 end
				// single cycle valid_out on next clock cycle
				if (pixel_valid_out) begin 
					pixel_valid_out <= 0;
				end
			end
			pclk_prev <= camera_pclk_in;
	 end



endmodule

`default_nettype wire
