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
	 assign camera_sample_valid = (pclk_prev == 0) && (camera_pclk_in == 1);
	 logic first_zero;
	 
	 // previous value of camera data, from last valid sample!
	 // should NOT update on every cycle of clk_in, only
	 // when samples are valid.
	 logic 													 last_sampled_hs;
	 logic [7:0] 										 last_sampled_data;

	 // flag indicating whether the last byte has been transmitted or not.
	 logic 													 half_pixel_ready;

	 always_ff@(posedge clk_in) begin
			if (rst_in) begin
				pixel_valid_out <= 0;
				pixel_hcount_out <= 0;
				pixel_vcount_out <= 0;
				pixel_data_out <= 0;

				// pclk_prev <= 0;
				last_sampled_hs <= 0;
				last_sampled_data <= 0;
				half_pixel_ready <= 0;
				first_zero <= 0;

			end else begin

				 if(camera_sample_valid) begin

					// active drawing
					 if (camera_hs_in && camera_vs_in) begin

						 last_sampled_data <= camera_data_in;
						 last_sampled_hs <= 1;

						 if (!half_pixel_ready) begin
							 half_pixel_ready <= 1;
						 end else begin
							 pixel_data_out <= {last_sampled_data, camera_data_in};
							 pixel_valid_out <= 1;
							 if (first_zero) begin
								 pixel_hcount_out <= pixel_hcount_out + 1;
							 end else begin
								 first_zero <= 1;
							 end
							 half_pixel_ready <= 0;
						 end

					// horizontal sync
					 end else if (!camera_hs_in && camera_vs_in) begin
						 half_pixel_ready <= 0;
						 first_zero <= 0;
						 // row completed
						 if (last_sampled_hs) begin
							 pixel_hcount_out <= 0;
							 pixel_vcount_out <= pixel_vcount_out + 1;
						 end
						 last_sampled_hs <= 0;

					// vertical sync
					 end else begin
						 half_pixel_ready <= 0;
						 first_zero <= 0;
						 // frame completed
						 pixel_hcount_out <= 0;
						 pixel_vcount_out <= 0;
					 end

				 end else begin
					 pixel_valid_out <= 0;
				 end

				//  pclk_prev <= camera_pclk_in;
			end
			pclk_prev <= camera_pclk_in;
	 end

endmodule

`default_nettype wire