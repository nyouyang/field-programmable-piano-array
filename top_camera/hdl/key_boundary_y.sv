`default_nettype none

module key_boundary_y (
  input wire clk_in,
  input wire rst_in,
  input wire pixel_from_fb,

  output logic [FB_SIZE-1:0] addr_into_fb,
  output logic [7:0] y_coords_out_white [1:0],
  output logic [7:0] y_coords_out_black [2:0],
  output logic [7:0] clusters,
  output logic [8:0] crosshair_h_white,
  output logic [8:0] crosshair_h_black
  );

  localparam FB_DEPTH = 320*180;
  localparam FB_SIZE = $clog2(FB_DEPTH);
  // TODO: add states, one for done w 13, one for one w 8, one for done w both
  // TODO: add a valid signal?

  logic previous_sobel_y_captured_raw;
  logic [8:0] sobel_y_frame_hcount; 
  logic [7:0] sobel_y_frame_vcount;
  logic [7:0] num_clusters;
  // expand size of y_coords? rn allocating at most 3 clusters
  logic [7:0] y_coords [2:0];
  logic led_one_on;

  // TODO: pipeline hcount, vcount 3 cycles
  logic [8:0] sobel_y_frame_hcount_pipe [2:0];
  logic [7:0] sobel_y_frame_vcount_pipe [2:0];

  always_ff @(posedge clk_in)begin

      if (rst_in) begin
          sobel_y_frame_hcount <= 0;
          sobel_y_frame_vcount <= 0;
          num_clusters <= 0;
          led_one_on <= 0;
          clusters <= 2; // for debugging

      end else begin
        // change: if at end of frame, go to idle state
        if (sobel_y_frame_hcount == 319 && sobel_y_frame_vcount == 179) begin
            sobel_y_frame_hcount <= 319;
        end else begin
            if (sobel_y_frame_vcount == 179) begin
                sobel_y_frame_vcount <= 0;
                sobel_y_frame_hcount <= sobel_y_frame_hcount + 1;
            end else begin
                sobel_y_frame_vcount <= sobel_y_frame_vcount + 1;
            end
        end

        addr_into_fb <= sobel_y_frame_vcount + sobel_y_frame_hcount*180;
        previous_sobel_y_captured_raw <= pixel_from_fb;

        sobel_y_frame_hcount_pipe[0] <= sobel_y_frame_hcount;
        for (int i=1; i<3; i = i+1)begin
        sobel_y_frame_hcount_pipe[i] <= sobel_y_frame_hcount_pipe[i-1];
        end

        sobel_y_frame_vcount_pipe[0] <= sobel_y_frame_vcount;
        for (int i=1; i<3; i = i+1)begin
        sobel_y_frame_vcount_pipe[i] <= sobel_y_frame_vcount_pipe[i-1];
        end

        if (sobel_y_frame_vcount_pipe[2] != 179) begin
            if (sobel_y_frame_vcount_pipe[2] > 5 && sobel_y_frame_vcount_pipe[2] < 175) begin
                // rising edge, beginning of cluster
                if (previous_sobel_y_captured_raw == 0 && pixel_from_fb == 1) begin
                    num_clusters <= num_clusters + 1;
                    y_coords[0] <= sobel_y_frame_vcount_pipe[2];
                    // shift ycoords to the right
                    for (int i=0; i<2; i=i+1) begin
                        y_coords[i+1] <= y_coords[i];
                    end
                end   
            end
        end else begin
        if (num_clusters == 2 && led_one_on == 0) begin
            // DO SOMETHING HERE, then go to done w 2 state
            clusters <= num_clusters;
            led_one_on <= 1;
            crosshair_h_white <= sobel_y_frame_hcount_pipe[2];
            for (int i=0; i<2; i=i+1) begin
                y_coords_out_white[i] <= y_coords[i];
            end
        end else if (num_clusters == 3) begin
            // DO SOMETHING ELSE HERE, then go to done w 3 state
            crosshair_h_black <= sobel_y_frame_hcount_pipe[2];
            for (int i=0; i<3; i=i+1) begin
                y_coords_out_black[i] <= y_coords[i];
            end
        end
        num_clusters <= 0;
        // TODO: reset y_coords to all 0
        end
      end

  end


endmodule

`default_nettype wire
