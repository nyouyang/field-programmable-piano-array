`default_nettype none

module key_boundary_x (
  input wire clk_in,
  input wire rst_in,
  input wire pixel_from_fb,

  output logic [FB_SIZE-1:0] addr_into_fb,
  output logic [8:0] x_coords_out_top [12:0],
  output logic [8:0] x_coords_out_bottom [7:0],
  output logic [7:0] clusters,
  output logic [7:0] crosshair_v_top,
  output logic [7:0] crosshair_v_bottom
  );

  localparam FB_DEPTH = 320*180;
  localparam FB_SIZE = $clog2(FB_DEPTH);
  // TODO: add states, one for done w 13, one for one w 8, one for done w both
  // TODO: add a valid signal?

  logic previous_sobel_x_captured_raw;
  logic [8:0] sobel_x_frame_hcount; 
  logic [7:0] sobel_x_frame_vcount;
  logic [7:0] num_clusters;
  // expand size of x_coords? rn allocating at most 13 clusters
  logic [8:0] x_coords [12:0];
  logic led_one_on;

  // TODO: pipeline hcount, vcount 3 cycles
  logic [8:0] sobel_x_frame_hcount_pipe [2:0];
  logic [7:0] sobel_x_frame_vcount_pipe [2:0];


  always_ff @(posedge clk_in)begin

      if (rst_in) begin
          sobel_x_frame_hcount <= 0;
          sobel_x_frame_vcount <= 0;
          num_clusters <= 0;
          led_one_on <= 0;
          clusters <= 2;

      end else begin
        // change: if at end of frame, go to idle state
        if (sobel_x_frame_hcount == 319 && sobel_x_frame_vcount == 179) begin
            sobel_x_frame_hcount <= 319;
        end else begin
            if (sobel_x_frame_hcount == 319) begin
                sobel_x_frame_hcount <= 0;
                sobel_x_frame_vcount <= sobel_x_frame_vcount + 1;
            end else begin
                sobel_x_frame_hcount <= sobel_x_frame_hcount + 1;
            end
        end

        addr_into_fb <= sobel_x_frame_hcount + sobel_x_frame_vcount*320;
        previous_sobel_x_captured_raw <= pixel_from_fb;

        sobel_x_frame_hcount_pipe[0] <= sobel_x_frame_hcount;
        for (int i=1; i<3; i = i+1)begin
            sobel_x_frame_hcount_pipe[i] <= sobel_x_frame_hcount_pipe[i-1];
        end

        sobel_x_frame_vcount_pipe[0] <= sobel_x_frame_vcount;
        for (int i=1; i<3; i = i+1)begin
            sobel_x_frame_vcount_pipe[i] <= sobel_x_frame_vcount_pipe[i-1];
        end

        if (sobel_x_frame_hcount_pipe[2] != 319) begin
            // rising edge, beginning of cluster
            if (previous_sobel_x_captured_raw == 0 && pixel_from_fb == 1) begin
                num_clusters <= num_clusters + 1;
                x_coords[0] <= sobel_x_frame_hcount_pipe[2];
                // shift xcoords to the right
                for (int i=0; i<12; i=i+1) begin
                    x_coords[i+1] <= x_coords[i];
                end
            end
        end else begin
        if (num_clusters == 13 && led_one_on == 0) begin
            // DO SOMETHING HERE, then go to done w 13 state
            clusters <= num_clusters;
            led_one_on <= 1;
            crosshair_v_top <= sobel_x_frame_vcount_pipe[2];
            for (int i=0; i<13; i=i+1) begin
                x_coords_out_top[i] <= x_coords[i];
            end
        end else if (num_clusters == 8) begin
            // DO SOMETHING ELSE HERE, then go to done w 8 state
            crosshair_v_bottom <= sobel_x_frame_vcount_pipe[2];
            for (int i=0; i<8; i=i+1) begin
                x_coords_out_bottom[i] <= x_coords[i];
            end
        end
        num_clusters <= 0;
        // TODO: reset x_coords to all 0
        end
      end

  end


endmodule

`default_nettype wire
