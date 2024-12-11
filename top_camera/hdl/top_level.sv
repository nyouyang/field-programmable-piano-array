`timescale 1ns / 1ps
`default_nettype none

module top_level
  (
   input wire          clk_100mhz,
   output logic [15:0] led,
   // camera bus
   input wire [7:0]    camera_d, // 8 parallel data wires
   output logic        cam_xclk, // XC driving camera
   input wire          cam_hsync, // camera hsync wire
   input wire          cam_vsync, // camera vsync wire
   input wire          cam_pclk, // camera pixel clock
   inout wire          i2c_scl, // i2c inout clock
   inout wire          i2c_sda, // i2c inout data
   input wire [15:0]   sw,
   input wire [3:0]    btn,
   output logic [2:0]  rgb0,
   output logic [2:0]  rgb1,
   // seven segment
   output logic [3:0]  ss0_an,//anode control for upper four digits of seven-seg display
   output logic [3:0]  ss1_an,//anode control for lower four digits of seven-seg display
   output logic [6:0]  ss0_c, //cathode controls for the segments of upper four digits
   output logic [6:0]  ss1_c, //cathod controls for the segments of lower four digits
   // hdmi port
   output logic [2:0]  hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
   output logic [2:0]  hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
   output logic        hdmi_clk_p, hdmi_clk_n, //differential hdmi clock
   // spi transmit
   output logic        copi, dclk, cs // SPI controller output signals
   );

  // shut up those RGBs
  assign rgb0 = 0;
  assign rgb1 = 0;

  // Clock and Reset Signals
  logic          sys_rst_camera;
  logic          sys_rst_pixel;

  logic          clk_camera;
  logic          clk_pixel;
  logic          clk_5x;
  logic          clk_xc;

  logic          clk_100_passthrough;

  // clocking wizards to generate the clock speeds we need for our different domains
  // clk_camera: 200MHz, fast enough to comfortably sample the cameera's PCLK (50MHz)
  cw_hdmi_clk_wiz wizard_hdmi
    (.sysclk(clk_100_passthrough),
     .clk_pixel(clk_pixel),
     .clk_tmds(clk_5x),
     .reset(0));

  cw_fast_clk_wiz wizard_migcam
    (.clk_in1(clk_100mhz),
     .clk_camera(clk_camera),
     .clk_xc(clk_xc),
     .clk_100(clk_100_passthrough),
     .reset(0));

  // assign camera's xclk to pmod port: drive the operating clock of the camera!
  // this port also is specifically set to high drive by the XDC file.
  assign cam_xclk = sw[2] ? clk_xc : 1'b0;

  assign sys_rst_camera = btn[0]; //use for resetting camera side of logic
  assign sys_rst_pixel = btn[0]; //use for resetting hdmi/draw side of logic


  // video signal generator signals
  logic          hsync_hdmi;
  logic          vsync_hdmi;
  logic [10:0]  hcount_hdmi;
  logic [9:0]    vcount_hdmi;
  logic          active_draw_hdmi;
  logic          new_frame_hdmi;
  logic [5:0]    frame_count_hdmi;
  logic          nf_hdmi;

  // rgb output values
  logic [7:0]          red,green,blue;

  // ** Handling input from the camera **

  // synchronizers to prevent metastability
  logic [7:0]    camera_d_buf [1:0];
  logic          cam_hsync_buf [1:0];
  logic          cam_vsync_buf [1:0];
  logic          cam_pclk_buf [1:0];

  always_ff @(posedge clk_camera) begin
     camera_d_buf <= {camera_d, camera_d_buf[1]};
     cam_pclk_buf <= {cam_pclk, cam_pclk_buf[1]};
     cam_hsync_buf <= {cam_hsync, cam_hsync_buf[1]};
     cam_vsync_buf <= {cam_vsync, cam_vsync_buf[1]};
  end

  logic [10:0] camera_hcount;
  logic [9:0]  camera_vcount;
  logic [15:0] camera_pixel;
  logic        camera_valid;

  // your pixel_reconstruct module, from week 5 and 6
  // hook it up to buffered inputs.
  //same as it ever was.

  pixel_reconstruct pixel_reconstruct_inst
    (.clk_in(clk_camera),
     .rst_in(sys_rst_camera),
     .camera_pclk_in(cam_pclk_buf[0]),
     .camera_hs_in(cam_hsync_buf[0]),
     .camera_vs_in(cam_vsync_buf[0]),
     .camera_data_in(camera_d_buf[0]),
     .pixel_valid_out(camera_valid),
     .pixel_hcount_out(camera_hcount),
     .pixel_vcount_out(camera_vcount),
     .pixel_data_out(camera_pixel));

  //----------------BEGIN NEW STUFF FOR LAB 07------------------

  //clock domain cross (from clk_camera to clk_pixel)
  //switching from camera clock domain to pixel clock domain early
  //this lets us do convolution on the 74.25 MHz clock rather than the
  //200 MHz clock domain that the camera lives on.
  logic empty;
  logic cdc_valid;
  logic [15:0] cdc_pixel;
  logic [10:0] cdc_hcount;
  logic [9:0] cdc_vcount;

  //cdc fifo (AXI IP). Remember to include that IP folder.
  fifo cdc_fifo
    (.wr_clk(clk_camera),
     .full(),
     .din({camera_hcount, camera_vcount, camera_pixel}),
     .wr_en(camera_valid),

     .rd_clk(clk_pixel),
     .empty(empty),
     .dout({cdc_hcount, cdc_vcount, cdc_pixel}),
     .rd_en(1) //always read
    );
  assign cdc_valid = ~empty; //watch when empty. Ready immediately if something there

  //----
  //Filter 0: 1280x720 convolution of gaussian blur
  logic [10:0] f0_hcount;  //hcount from filter0 module
  logic [9:0] f0_vcount; //vcount from filter0 module
  logic [15:0] f0_pixel; //pixel data from filter0 module
  logic f0_valid; //valid signals for filter0 module
  //full resolution filter
  // filter #(.K_SELECT(1),.HRES(1280),.VRES(720))
  //   filtern(
  //   .clk_in(clk_pixel),
  //   .rst_in(sys_rst_pixel),
  //   .data_valid_in(cdc_valid),
  //   .pixel_data_in(cdc_pixel),
  //   .hcount_in(cdc_hcount),
  //   .vcount_in(cdc_vcount),
  //   .data_valid_out(f0_valid),
  //   .pixel_data_out(f0_pixel),
  //   .hcount_out(f0_hcount),
  //   .vcount_out(f0_vcount)
  // );
  // NEED TO PIPELINE THIS
  assign f0_hcount = cdc_hcount;
  assign f0_vcount = cdc_vcount;
  assign f0_pixel = cdc_pixel;
  assign f0_valid = cdc_valid;

  //----
  logic [10:0] lb_hcount;  //hcount to filter modules
  logic [9:0] lb_vcount; //vcount to filter modules
  logic [15:0] lb_pixel; //pixel data to filter modules
  logic lb_valid; //valid signals to filter modules

  //selection logic to either go through (btn[1]=1)
  //or bypass (btn[1]==0) the first filter
  //in the first part of lab as you develop line buffer, you'll want to bypass
  //since your filter won't be working, but it would be good to test the
  //downsampling line buffer below on its own
  always_ff @(posedge clk_pixel) begin
    if (btn[1])begin
      ds_hcount = cdc_hcount;
      ds_vcount = cdc_vcount;
      ds_pixel = cdc_pixel;
      ds_valid = cdc_valid;
    end else begin
      ds_hcount = f0_hcount;
      ds_vcount = f0_vcount;
      ds_pixel = f0_pixel;
      ds_valid = f0_valid;
    end
  end

  //----
  //A line buffer that, in conjunction with the control signal will down sample
  //the camera (or f0 filter) values from 1280x720 to 320x180
  //in reality we could get by without this, but it does make things a little easier
  //and we've also added it since it gives us a means of testing the line buffer
  //design outside of the filter.
  logic [2:0][15:0] lb_buffs; //grab output of down sample line buffer
  logic ds_control; //controlling when to write (every fourth pixel and line)
  logic [10:0] ds_hcount;  //hcount to downsample line buffer
  logic [9:0] ds_vcount; //vcount to downsample line buffer
  logic [15:0] ds_pixel; //pixel data to downsample line buffer
  logic ds_valid; //valid signals to downsample line buffer
  assign ds_control = ds_valid;
  line_buffer #(.HRES(320),
                .VRES(180))
    ds_lbuff (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .data_valid_in(ds_control),
    .pixel_data_in(ds_pixel),
    .hcount_in(ds_hcount[10:0]),
    .vcount_in(ds_vcount[9:0]),
    .data_valid_out(lb_valid),
    .line_buffer_out(lb_buffs),
    .hcount_out(lb_hcount),
    .vcount_out(lb_vcount)
  );

  assign lb_pixel = lb_buffs[1]; //pass on only the middle one.

  //----
  //Create three different filters that all exist in parallel
  //The outputs of all three filters are fed into the unpacked arrays below:
  logic [10:0] f_hcount [3:0];  //hcount from filter modules
  logic [9:0] f_vcount [3:0]; //vcount from filter modules
  logic [15:0] f_pixel [3:0]; //pixel data from filter modules
  logic f_valid [3:0]; //valid signals for filter modules

  //using generate/genvar, create three *Different* instances of the
  //filter module (you'll write that).  Each filter will implement a different
  //kernel
  generate
    genvar i;
    for (i=0; i<4; i=i+1)begin
      filter #(.K_SELECT(i),.HRES(320),.VRES(180))
        filterm(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_valid_in(lb_valid),
        .pixel_data_in(lb_pixel),
        .hcount_in(lb_hcount),
        .vcount_in(lb_vcount),
        .data_valid_out(f_valid[i]),
        .pixel_data_out(f_pixel[i]),
        .hcount_out(f_hcount[i]),
        .vcount_out(f_vcount[i])
      );
    end
  endgenerate

  logic [10:0] x_sobel_hcount;
  logic [9:0] x_sobel_vcount;
  logic x_sobel_pixel;
  logic x_sobel_valid;

  sobel_masking x_sobel_mask (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_in(f_hcount[2]),
    .vcount_in(f_vcount[2]),
    .pixel_data_in(f_pixel[2]),
    .data_valid_in(f_valid[2]),
    .hcount_out(x_sobel_hcount),
    .vcount_out(x_sobel_vcount),
    .pixel_data_out(x_sobel_pixel),
    .data_valid_out(x_sobel_valid)
  );

  logic [10:0] y_sobel_hcount;
  logic [9:0] y_sobel_vcount;
  logic y_sobel_pixel;
  logic y_sobel_valid;

  sobel_masking y_sobel_mask (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .hcount_in(f_hcount[3]),
    .vcount_in(f_vcount[3]),
    .pixel_data_in(f_pixel[3]),
    .data_valid_in(f_valid[3]),
    .hcount_out(y_sobel_hcount),
    .vcount_out(y_sobel_vcount),
    .pixel_data_out(y_sobel_pixel),
    .data_valid_out(y_sobel_valid)
  );

  logic [FB_SIZE-1:0] addra_sobel_x; //used to specify address to write to in frame buffer
  logic valid_camera_mem_sobel_x; //used to enable writing pixel data to frame buffer
  logic camera_mem_sobel_x; //used to pass pixel data into frame buffer
  logic first_frame_sobel_x;
  logic second_frame_sobel_x;

  //because the down sampling already happened upstream, there's no need to do here.
  always_ff @(posedge clk_pixel) begin
    if (sw[8]) begin
      // first frame when first_frame_sobel_x high and second_frame_sobel_x low
      if (x_sobel_hcount == 11'b0 && x_sobel_vcount == 10'b0 && first_frame_sobel_x == 0) begin
        first_frame_sobel_x <= 1;
      end else if (x_sobel_hcount == 319 && x_sobel_vcount == 179 && first_frame_sobel_x == 1) begin
        second_frame_sobel_x <= 1;
      end
    end else begin
      first_frame_sobel_x <= 0;
      second_frame_sobel_x <= 0;
    end

    if(x_sobel_valid && first_frame_sobel_x && !second_frame_sobel_x) begin
      addra_sobel_x <= x_sobel_hcount + x_sobel_vcount * 320;
      camera_mem_sobel_x <= x_sobel_pixel;
      valid_camera_mem_sobel_x <= 1;
    end else begin
      valid_camera_mem_sobel_x <= 0;
    end
  end

  // X-axis sobel filter frame buffer from IP
  blk_mem_gen_0 sobel_x_frame (
    .addra(addra_sobel_x), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(valid_camera_mem_sobel_x),
    .dina(camera_mem_sobel_x),
    .ena(1'b1),
    .douta(), //never read from this side
    .addrb(addrb_sobel_x),//transformed lookup pixel
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(1'b1),
    .doutb(sobel_x_captured_raw)
  );

  logic [FB_SIZE-1:0] addrb_sobel_x; //used to lookup address in memory for reading from buffer
  logic sobel_x_captured_raw; //data out of sobel x frame (1 bit)
  logic [7:0] debug_clusters;
  logic [7:0] crosshair_v_top;
  logic [7:0] crosshair_v_bottom;
  logic [8:0] x_coords_keys_top [12:0];
  logic [8:0] x_coords_keys_bottom [7:0];

  key_boundary_x x_sobel_compute (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel || ~second_frame_sobel_x),
    .pixel_from_fb(sobel_x_captured_raw),
    .addr_into_fb(addrb_sobel_x),
    .x_coords_out_top(x_coords_keys_top),
    .x_coords_out_bottom(x_coords_keys_bottom),
    .clusters(debug_clusters),
    .crosshair_v_top(crosshair_v_top),
    .crosshair_v_bottom(crosshair_v_bottom)
  );

  logic [FB_SIZE-1:0] addra_sobel_y; //used to specify address to write to in frame buffer
  logic valid_camera_mem_sobel_y; //used to enable writing pixel data to frame buffer
  logic camera_mem_sobel_y; //used to pass pixel data into frame buffer
  logic first_frame_sobel_y;
  logic second_frame_sobel_y;

  //because the down sampling already happened upstream, there's no need to do here.
  always_ff @(posedge clk_pixel) begin
    if (sw[8]) begin
      // first frame when first_frame_sobel_y high and second_frame_sobel_y low
      if (y_sobel_hcount == 11'b0 && y_sobel_vcount == 10'b0 && first_frame_sobel_y == 0) begin
        first_frame_sobel_y <= 1;
      end else if (y_sobel_hcount == 319 && y_sobel_vcount == 179 && first_frame_sobel_y == 1) begin
        second_frame_sobel_y <= 1;
      end
    end else begin
      first_frame_sobel_y <= 0;
      second_frame_sobel_y <= 0;
    end

    if(y_sobel_valid && first_frame_sobel_y && !second_frame_sobel_y) begin
      addra_sobel_y <= y_sobel_vcount + y_sobel_hcount * 180;
      camera_mem_sobel_y <= y_sobel_pixel;
      valid_camera_mem_sobel_y <= 1;
    end else begin
      valid_camera_mem_sobel_y <= 0;
    end
  end

  // Y-axis sobel filter frame buffer from IP
  blk_mem_gen_0 sobel_y_frame (
    .addra(addra_sobel_y), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(valid_camera_mem_sobel_y),
    .dina(camera_mem_sobel_y),
    .ena(1'b1),
    .douta(), //never read from this side
    .addrb(addrb_sobel_y),//transformed lookup pixel
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(1'b1),
    .doutb(sobel_y_captured_raw)
  );

  logic [FB_SIZE-1:0] addrb_sobel_y; //used to lookup address in memory for reading from buffer
  logic sobel_y_captured_raw; //data out of sobel x frame (1 bit)
  logic [7:0] debug_clusters_y;
  logic [8:0] crosshair_h_white;
  logic [8:0] crosshair_h_black;
  logic [7:0] y_coords_keys_white [1:0];
  logic [7:0] y_coords_keys_black [2:0];

  key_boundary_y y_sobel_compute (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel || ~second_frame_sobel_y),
    .pixel_from_fb(sobel_y_captured_raw),
    .addr_into_fb(addrb_sobel_y),
    .y_coords_out_white(y_coords_keys_white),
    .y_coords_out_black(y_coords_keys_black),
    .clusters(debug_clusters_y),
    .crosshair_h_white(crosshair_h_white),
    .crosshair_h_black(crosshair_h_black)
  );

  logic [10:0] thumb_x;
  logic [9:0] thumb_y;
  logic [10:0] middle_x;
  logic [9:0] middle_y;
  logic [10:0] pinky_x;
  logic [9:0] pinky_y;

  logic [10:0] centroid_A_x;
  logic [9:0] centroid_A_y;
  logic [10:0] centroid_B_x;
  logic [9:0] centroid_B_y;
  logic [10:0] centroid_C_x;
  logic [9:0] centroid_C_y;  

  // TODO: pipeline hcount_hdmi, vcount_hdmi, nf_hdmi by 7
  logic [10:0] hcount_hdmi_pipe [6:0];
  logic [9:0] vcount_hdmi_pipe [6:0];
  logic nf_hdmi_pipe [6:0];

  always_ff @(posedge clk_pixel) begin
    hcount_hdmi_pipe[0] <= hcount_hdmi;
    for (int i=1; i<7; i = i+1)begin
      hcount_hdmi_pipe[i] <= hcount_hdmi_pipe[i-1];
    end

    vcount_hdmi_pipe[0] <= vcount_hdmi;
    for (int i=1; i<7; i = i+1)begin
      vcount_hdmi_pipe[i] <= vcount_hdmi_pipe[i-1];
    end

    nf_hdmi_pipe[0] <= nf_hdmi;
    for (int i=1; i<7; i = i+1)begin
      nf_hdmi_pipe[i] <= nf_hdmi_pipe[i-1];
    end
  end

  // k means
  k_means k_means_inst (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_in(hcount_hdmi_pipe[6]),  //TODO: needs to use pipelined signal! (PS3)
    .y_in(vcount_hdmi_pipe[6]), //TODO: needs to use pipelined signal! (PS3)
    .centroid_a_x(thumb_x),
    .centroid_a_y(thumb_y),
    .centroid_b_x(middle_x),
    .centroid_b_y(middle_y),
    .centroid_c_x(pinky_x),
    .centroid_c_y(pinky_y),
    .valid_in(mask), //aka threshold
    .tabulate_in((nf_hdmi_pipe[6])),
    .a_x_out(centroid_A_x),
    .a_y_out(centroid_A_y),
    .b_x_out(centroid_B_x),
    .b_y_out(centroid_B_y),
    .c_x_out(centroid_C_x),
    .c_y_out(centroid_C_y),
    .valid_out(new_com)
  );

  always_ff @( posedge clk_pixel ) begin
    if (sys_rst_pixel) begin
      thumb_x <= 320; // 1280/4
      thumb_y <= 360; // 720/2
      middle_x <= 640;
      middle_y <= 360;
      pinky_x <= 960;
      pinky_y <= 360;
    end if (new_com) begin
      thumb_x <= centroid_A_x;
      thumb_y <= centroid_A_y;
      middle_x <= centroid_B_x;
      middle_y <= centroid_B_y;
      pinky_x <= centroid_C_x;
      pinky_y <= centroid_C_y;
    end
  end                      

  // key association

  logic [3:0] thumb_note;
  logic [3:0] middle_note;
  logic [3:0] pinky_note;

  key_association associate_keys_thumb (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_coords_keys_top(x_coords_keys_top),
    .x_coords_keys_bottom(x_coords_keys_bottom),
    .y_coords_keys_white(y_coords_keys_white),
    .y_coords_keys_black(y_coords_keys_black),
    .x_com((1279-thumb_x)>>2),
    .y_com(thumb_y>>2),
    .note(thumb_note)
  );

  key_association associate_keys_middle (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_coords_keys_top(x_coords_keys_top),
    .x_coords_keys_bottom(x_coords_keys_bottom),
    .y_coords_keys_white(y_coords_keys_white),
    .y_coords_keys_black(y_coords_keys_black),
    .x_com(middle_x>>2),
    .y_com(middle_y>>2),
    .note(middle_note)
  );

  key_association associate_keys_pinky (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_coords_keys_top(x_coords_keys_top),
    .x_coords_keys_bottom(x_coords_keys_bottom),
    .y_coords_keys_white(y_coords_keys_white),
    .y_coords_keys_black(y_coords_keys_black),
    .x_com(pinky_x>>2),
    .y_com(pinky_y>>2),
    .note(pinky_note)
  );

  // K-MEANS AND KEY ASSOCIATION HERE

  // SPECIFIED NOTES
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

 // SPI communication from top FPGA to side FPGA
   localparam CYCLES_PER_TRIGGER = 1000000; // 1 MHz

   logic [31:0]        trigger_count;
   logic               spi_trigger;

   counter note_trigger
     (.clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .period_in(CYCLES_PER_TRIGGER),
      .count_out(trigger_count));

   // use the trigger_count output to make spi_trigger a single-cycle high with 8kHz frequency
   assign spi_trigger = (trigger_count == CYCLES_PER_TRIGGER - 1); 

   // SPI Controller
   spi_transmit my_spi_transmit
   ( .clk_in(clk_pixel),
     .rst_in(sys_rst_pixel),
     .data_in({thumb_note, middle_note, pinky_note}),
     .trigger_in(spi_trigger),
     .chip_data_out(copi),
     .chip_clk_out(dclk),
     .chip_sel_out(cs)
    );

  //------
  //Choose which filter to use
  //based on values of sw[2:0] select which filter output gets handed on to the
  //next module. We must make sure to route hcount, vcount, pixels and valid signal
  // for each module.  Could have done this with a for loop as well!  Think
  // about it!
  logic [10:0] fmux_hcount; //hcount from filter mux
  logic [9:0]  fmux_vcount; //vcount from filter mux
  logic [15:0] fmux_pixel; //pixel data from filter mux
  logic fmux_valid; //data valid from filter mux

  //00 Identity Kernel
  //10 Sobel y axis masked
  //01 Sobel x axis masked
  //11 line buffer
  always_ff @(posedge clk_pixel)begin
    case (sw[1:0])
      2'b00: begin
        fmux_hcount <= f_hcount[0];
        fmux_vcount <= f_vcount[0];
        fmux_pixel <= f_pixel[0];
        fmux_valid <= f_valid[0];
      end
      2'b10: begin
        fmux_hcount <= y_sobel_hcount;
        fmux_vcount <= y_sobel_vcount;
        fmux_pixel <= y_sobel_pixel? 16'b1111_1111_1111_1111: 0;
        fmux_valid <= y_sobel_valid;
      end
      2'b01: begin
        fmux_hcount <= x_sobel_hcount;
        fmux_vcount <= x_sobel_vcount;
        fmux_pixel <= x_sobel_pixel? 16'b1111_1111_1111_1111: 0;
        fmux_valid <= x_sobel_valid;
      end
      default: begin
        fmux_hcount <= lb_hcount;
        fmux_vcount <= lb_vcount;
        fmux_pixel <= lb_pixel;
        fmux_valid <= lb_valid;
      end
    endcase
  end


  localparam FB_DEPTH = 320*180;
  localparam FB_SIZE = $clog2(FB_DEPTH);
  logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer
  logic valid_camera_mem; //used to enable writing pixel data to frame buffer
  logic [15:0] camera_mem; //used to pass pixel data into frame buffer

  //because the down sampling already happened upstream, there's no need to do here.
  always_ff @(posedge clk_pixel) begin
    if(fmux_valid) begin
      addra <= fmux_hcount + fmux_vcount * 320;
      camera_mem <= fmux_pixel;
      valid_camera_mem <= 1;
    end else begin
      valid_camera_mem <= 0;
    end
  end

  //frame buffer from IP
  blk_mem_gen_0 frame_buffer (
    .addra(addra), //pixels are stored using this math
    .clka(clk_pixel),
    .wea(valid_camera_mem),
    .dina(camera_mem),
    .ena(1'b1),
    .douta(), //never read from this side
    .addrb(addrb),//transformed lookup pixel
    .dinb(16'b0),
    .clkb(clk_pixel),
    .web(1'b0),
    .enb(1'b1),
    .doutb(frame_buff_raw)
  );
  logic [15:0] frame_buff_raw; //data out of frame buffer (565)
  logic [FB_SIZE-1:0] addrb; //used to lookup address in memory for reading from buffer
  logic good_addrb; //used to indicate within valid frame for scaling
  //brought in from lab 5...just do 4X upscale
  always_ff @(posedge clk_pixel)begin
    addrb <= (319-(hcount_hdmi >> 2)) + 320*(vcount_hdmi >> 2);
    good_addrb <= (hcount_hdmi<1280)&&(vcount_hdmi<720);
  end

  // TODO: pipeline good_addrb by 2 cycles
  logic good_addrb_pipe [1:0];

  always_ff @(posedge clk_pixel) begin
    good_addrb_pipe[0] <= good_addrb;
    good_addrb_pipe[1] <= good_addrb_pipe[0];
  end

  //--------------------------END NEW STUFF-------------------

  //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
  //remapped frame_buffer outputs with 8 bits for r, g, b
  logic [7:0] fb_red, fb_green, fb_blue;
  always_ff @(posedge clk_pixel)begin
    fb_red <= (good_addrb_pipe[1])?{frame_buff_raw[15:11],3'b0}:8'b0;
    fb_green <= (good_addrb_pipe[1])?{frame_buff_raw[10:5], 2'b0}:8'b0;
    fb_blue <= (good_addrb_pipe[1])?{frame_buff_raw[4:0],3'b0}:8'b0;
  end
  // Pixel Processing pre-HDMI output

  // RGB to YCrCb

  //output of rgb to ycrcb conversion (10 bits due to module):
  logic [9:0] y_full, cr_full, cb_full; //ycrcb conversion of full pixel
  //bottom 8 of y, cr, cb conversions:
  logic [7:0] y, cr, cb; //ycrcb conversion of full pixel
  //Convert RGB of full pixel to YCrCb
  //See lecture 07 for YCrCb discussion.
  //Module has a 3 cycle latency
  rgb_to_ycrcb rgbtoycrcb_m(
    .clk_in(clk_pixel),
    .r_in(fb_red),
    .g_in(fb_green),
    .b_in(fb_blue),
    .y_out(y_full),
    .cr_out(cr_full),
    .cb_out(cb_full)
  );

  //threshold module (apply masking threshold):
  logic [7:0] lower_threshold;
  logic [7:0] upper_threshold;
  logic mask; //Whether or not thresholded pixel is 1 or 0

  //Center of Mass variables (tally all mask=1 pixels for a frame and calculate their center of mass)
  logic [10:0] x_com, x_com_calc; //long term x_com and output from module, resp
  logic [9:0] y_com, y_com_calc; //long term y_com and output from module, resp
  logic new_com; //used to know when to update x_com and y_com ...

  //take lower 8 of full outputs.
  // treat cr and cb as signed numbers, invert the MSB to get an unsigned equivalent ( [-128,128) maps to [0,256) )
  assign y = y_full[7:0];
  assign cr = {!cr_full[7],cr_full[6:0]};
  assign cb = {!cb_full[7],cb_full[6:0]};

  //threshold values used to determine what value  passes:
  assign lower_threshold = 8'b1010_0000; //A0
  assign upper_threshold = 8'b1111_0000; //F0

  //Thresholder: Takes in the full selected channedl and
  //based on upper and lower bounds provides a binary mask bit
  // * 1 if selected channel is within the bounds (inclusive)
  // * 0 if selected channel is not within the bounds
  threshold mt(
     .clk_in(clk_pixel),
     .rst_in(sys_rst_pixel),
     .pixel_in(cr),
     .lower_bound_in(lower_threshold),
     .upper_bound_in(upper_threshold),
     .mask_out(mask) //single bit if pixel within mask.
  );

  logic [6:0] ss_c;
  final_proj_ssc mssc(.clk_in(clk_pixel),
                 .rst_in(sys_rst_pixel),
                 .thumb_note(thumb_note),
                 .middle_note(middle_note),
                 .pinky_note(pinky_note),
                 .cat_out(ss_c),
                 .an_out({ss0_an, ss1_an})
  );

  // logic [6:0] ss_c;
  // //modified version of seven segment display for showing
  // // thresholds and selected channel
  // // special customized version
  // lab05_ssc mssc(.clk_in(clk_pixel),
  //                .rst_in(sys_rst_pixel),
  //                .lt_in({thumb_note, middle_note}),
  //                .ut_in({pinky_note, 4'b0}),
  //                .channel_sel_in(3'b101),
  //                .cat_out(ss_c),
  //                .an_out({ss0_an, ss1_an})
  // );
  assign ss0_c = ss_c; //control upper four digit's cathodes!
  assign ss1_c = ss_c; //same as above but for lower four digits!

  //image_sprite output:
  logic [7:0] img_red, img_green, img_blue;
  assign img_red =0;
  assign img_green =0;
  assign img_blue =0;
  //image sprite removed to keep builds focused.


  //crosshair output:
  logic [7:0] ch_red, ch_green, ch_blue;
  // make one bit logic signals for each of these cases
  logic x_sobel_top_13_lines, x_sobel_bottom_8_lines, y_sobel_white_2_lines, y_sobel_black_3_lines;
//vcount_hdmi==crosshair_v_top<<2 ||
  assign x_sobel_top_13_lines =  hcount_hdmi==1279-(x_coords_keys_top[0]<<2) || hcount_hdmi==1279-(x_coords_keys_top[1]<<2) || hcount_hdmi==1279-(x_coords_keys_top[2]<<2) || hcount_hdmi==1279-(x_coords_keys_top[3]<<2) || hcount_hdmi==1279-(x_coords_keys_top[4]<<2) || hcount_hdmi==1279-(x_coords_keys_top[5]<<2) || hcount_hdmi==1279-(x_coords_keys_top[6]<<2) || hcount_hdmi==1279-(x_coords_keys_top[7]<<2) || hcount_hdmi==1279-(x_coords_keys_top[8]<<2) || hcount_hdmi==1279-(x_coords_keys_top[9]<<2) || hcount_hdmi==1279-(x_coords_keys_top[10]<<2) || hcount_hdmi==1279-(x_coords_keys_top[11]<<2) || hcount_hdmi==1279-(x_coords_keys_top[12]<<2);
//vcount_hdmi==crosshair_v_bottom<<2 ||
  assign x_sobel_bottom_8_lines =  hcount_hdmi==1279-(x_coords_keys_bottom[0]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[1]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[2]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[3]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[4]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[5]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[6]<<2) || hcount_hdmi==1279-(x_coords_keys_bottom[7]<<2);
// hcount_hdmi==1279-(crosshair_h_white<<2) ||
  assign y_sobel_white_2_lines = vcount_hdmi==(y_coords_keys_white[0]<<2) || vcount_hdmi==(y_coords_keys_white[1]<<2);
// hcount_hdmi==1279-(crosshair_h_black<<2) ||
  assign y_sobel_black_3_lines = vcount_hdmi==(y_coords_keys_black[0]<<2) || vcount_hdmi==(y_coords_keys_black[1]<<2) || vcount_hdmi==(y_coords_keys_black[2]<<2);

  //Create Crosshair patter on center of mass:
  //0 cycle latency
  //TODO: Should be using output of (PS3)

  always_comb begin
    case (sw[15:14])
      2'b00: begin
        ch_red = 8'h00;
        ch_green = 8'h00;
        ch_blue = 8'h00;
      end
      2'b01: begin
        ch_red   = (x_sobel_top_13_lines)?8'hFF:8'h00;
        ch_green   = (x_sobel_top_13_lines)?8'hFF:8'h00;
        ch_blue   = (x_sobel_top_13_lines)?8'hFF:8'h00;
      end
      2'b10: begin
        ch_red   = (x_sobel_bottom_8_lines)?8'hFF:8'h00;
        ch_green   = (x_sobel_bottom_8_lines)?8'hFF:8'h00;
        ch_blue   = (x_sobel_bottom_8_lines)?8'hFF:8'h00;  
      end
      2'b11: begin
        ch_red = (hcount_hdmi == thumb_x || hcount_hdmi == middle_x || hcount_hdmi == pinky_x || vcount_hdmi == thumb_y || vcount_hdmi == middle_y || vcount_hdmi == pinky_y)?8'hFF:8'h00;
        ch_green = (hcount_hdmi == thumb_x || hcount_hdmi == middle_x || hcount_hdmi == pinky_x || vcount_hdmi == thumb_y || vcount_hdmi == middle_y || vcount_hdmi == pinky_y)?8'hFF:8'h00;
        ch_blue = (hcount_hdmi == thumb_x || hcount_hdmi == middle_x || hcount_hdmi == pinky_x || vcount_hdmi == thumb_y || vcount_hdmi == middle_y || vcount_hdmi == pinky_y)?8'hFF:8'h00;
      end
    endcase
  end

  // y sobel white 2
  // always_comb begin
  //   ch_red   = (x_sobel_top_13_lines || x_sobel_bottom_8_lines || y_sobel_white_2_lines || y_sobel_black_3_lines)?8'hFF:8'h00;
  //   ch_green   = (x_sobel_top_13_lines || x_sobel_bottom_8_lines || y_sobel_white_2_lines || y_sobel_black_3_lines)?8'hFF:8'h00;
  //   ch_blue   = (x_sobel_top_13_lines || x_sobel_bottom_8_lines || y_sobel_white_2_lines || y_sobel_black_3_lines)?8'hFF:8'h00;
  // end

  // HDMI video signal generator
   video_sig_gen vsg
     (
      .pixel_clk_in(clk_pixel),
      .rst_in(sys_rst_pixel),
      .hcount_out(hcount_hdmi),
      .vcount_out(vcount_hdmi),
      .vs_out(vsync_hdmi),
      .hs_out(hsync_hdmi),
      .nf_out(nf_hdmi),
      .ad_out(active_draw_hdmi),
      .fc_out(frame_count_hdmi)
      );


  // Video Mux: select from the different display modes based on switch values
  //used with switches for display selections
  logic [1:0] display_choice;
  logic [1:0] target_choice;

  assign display_choice = sw[6:5]; //was [5:4]; not anymore
  assign target_choice =  {1'b0,sw[7]}; //was [7:6]; not anymore

  //choose what to display from the camera:
  // * 'b00:  normal camera out
  // * 'b01:  selected channel image in grayscale
  // * 'b10:  masked pixel (all on if 1, all off if 0)
  // * 'b11:  chroma channel with mask overtop as magenta
  //
  //then choose what to use with center of mass:
  // * 'b0: nothing
  // * 'b1: crosshair

  // TODO: pipeline fb_red, fb_green, fb_blue by 4
  logic [7:0] fb_red_pipe [3:0];
  logic [7:0] fb_green_pipe [3:0];
  logic [7:0] fb_blue_pipe [3:0];

  always_ff @(posedge clk_pixel) begin
    fb_red_pipe[0] <= fb_red;
    for (int i=1; i<4; i = i+1)begin
      fb_red_pipe[i] <= fb_red_pipe[i-1];
    end

    fb_green_pipe[0] <= fb_green;
    for (int i=1; i<4; i = i+1)begin
      fb_green_pipe[i] <= fb_green_pipe[i-1];
    end

    fb_blue_pipe[0] <= fb_blue;
    for (int i=1; i<4; i = i+1)begin
      fb_blue_pipe[i] <= fb_blue_pipe[i-1];
    end
  end

  // TODO: pipeline y, cr by 1
  logic [7:0] y_pipe;
  logic [7:0] cr_pipe;
  always_ff @(posedge clk_pixel) begin
    y_pipe <= y;
    cr_pipe <= cr;
  end

  // TODO: pipeline ch_red, ch_green, ch_blue by 7
  logic [7:0] ch_red_pipe [6:0];
  logic [7:0] ch_green_pipe [6:0];
  logic [7:0] ch_blue_pipe [6:0];

  always_ff @(posedge clk_pixel) begin
    ch_red_pipe[0] <= ch_red;
    for (int i=1; i<7; i = i+1)begin
      ch_red_pipe[i] <= ch_red_pipe[i-1];
    end

    ch_green_pipe[0] <= ch_green;
    for (int i=1; i<7; i = i+1)begin
      ch_green_pipe[i] <= ch_green_pipe[i-1];
    end

    ch_blue_pipe[0] <= ch_blue;
    for (int i=1; i<7; i = i+1)begin
      ch_blue_pipe[i] <= ch_blue_pipe[i-1];
    end
  end

  video_mux mvm(
    .bg_in(display_choice), //choose background
    .target_in(target_choice), //choose target
    .camera_pixel_in({fb_red_pipe[3], fb_green_pipe[3], fb_blue_pipe[3]}), //TODO: needs (PS2)
    .camera_y_in(y_pipe), //luminance TODO: needs (PS6)
    .channel_in(cr_pipe), //current channel being drawn TODO: needs (PS5)
    .thresholded_pixel_in(mask), //one bit mask signal TODO: needs (PS4)
    .crosshair_in({ch_red_pipe[6], ch_green_pipe[6], ch_blue_pipe[6]}), //TODO: needs (PS8)
    .com_sprite_pixel_in({img_red, img_green, img_blue}), //TODO: needs (PS9) maybe?
    .pixel_out({red,green,blue}) //output to tmds
  );

   // HDMI Output: just like before!

   logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
   logic       tmds_signal [2:0]; //output of each TMDS serializer!

   //three tmds_encoders (blue, green, red)
   //note green should have no control signal like red
   //the blue channel DOES carry the two sync signals:
   //  * control_in[0] = horizontal sync signal
   //  * control_in[1] = vertical sync signal

   tmds_encoder tmds_red(
       .clk_in(clk_pixel),
       .rst_in(sys_rst_pixel),
       .data_in(red),
       .control_in(2'b0),
       .ve_in(active_draw_hdmi),
       .tmds_out(tmds_10b[2]));

   tmds_encoder tmds_green(
         .clk_in(clk_pixel),
         .rst_in(sys_rst_pixel),
         .data_in(green),
         .control_in(2'b0),
         .ve_in(active_draw_hdmi),
         .tmds_out(tmds_10b[1]));

   tmds_encoder tmds_blue(
        .clk_in(clk_pixel),
        .rst_in(sys_rst_pixel),
        .data_in(blue),
        .control_in({vsync_hdmi,hsync_hdmi}),
        .ve_in(active_draw_hdmi),
        .tmds_out(tmds_10b[0]));


   //three tmds_serializers (blue, green, red):
   //MISSING: two more serializers for the green and blue tmds signals.
   tmds_serializer red_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[2]),
         .tmds_out(tmds_signal[2]));
   tmds_serializer green_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[1]),
         .tmds_out(tmds_signal[1]));
   tmds_serializer blue_ser(
         .clk_pixel_in(clk_pixel),
         .clk_5x_in(clk_5x),
         .rst_in(sys_rst_pixel),
         .tmds_in(tmds_10b[0]),
         .tmds_out(tmds_signal[0]));

   //output buffers generating differential signals:
   //three for the r,g,b signals and one that is at the pixel clock rate
   //the HDMI receivers use recover logic coupled with the control signals asserted
   //during blanking and sync periods to synchronize their faster bit clocks off
   //of the slower pixel clock (so they can recover a clock of about 742.5 MHz from
   //the slower 74.25 MHz clock)
   OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
   OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
   OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
   OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));


   // Nothing To Touch Down Here:
   // register writes to the camera

   // The OV5640 has an I2C bus connected to the board, which is used
   // for setting all the hardware settings (gain, white balance,
   // compression, image quality, etc) needed to start the camera up.
   // We've taken care of setting these all these values for you:
   // "rom.mem" holds a sequence of bytes to be sent over I2C to get
   // the camera up and running, and we've written a design that sends
   // them just after a reset completes.

   // If the camera is not giving data, press your reset button.

   logic  busy, bus_active;
   logic  cr_init_valid, cr_init_ready;

   logic  recent_reset;
   always_ff @(posedge clk_camera) begin
      if (sys_rst_camera) begin
         recent_reset <= 1'b1;
         cr_init_valid <= 1'b0;
      end
      else if (recent_reset) begin
         cr_init_valid <= 1'b1;
         recent_reset <= 1'b0;
      end else if (cr_init_valid && cr_init_ready) begin
         cr_init_valid <= 1'b0;
      end
   end

   logic [23:0] bram_dout;
   logic [7:0]  bram_addr;

   // ROM holding pre-built camera settings to send
   xilinx_single_port_ram_read_first
     #(
       .RAM_WIDTH(24),
       .RAM_DEPTH(256),
       .RAM_PERFORMANCE("HIGH_PERFORMANCE"),
       .INIT_FILE("rom.mem")
       ) registers
       (
        .addra(bram_addr),     // Address bus, width determined from RAM_DEPTH
        .dina(24'b0),          // RAM input data, width determined from RAM_WIDTH
        .clka(clk_camera),     // Clock
        .wea(1'b0),            // Write enable
        .ena(1'b1),            // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst_camera), // Output reset (does not affect memory contents)
        .regcea(1'b1),         // Output register enable
        .douta(bram_dout)      // RAM output data, width determined from RAM_WIDTH
        );

   logic [23:0] registers_dout;
   logic [7:0]  registers_addr;
   assign registers_dout = bram_dout;
   assign bram_addr = registers_addr;

   logic       con_scl_i, con_scl_o, con_scl_t;
   logic       con_sda_i, con_sda_o, con_sda_t;

   // NOTE these also have pullup specified in the xdc file!
   // access our inouts properly as tri-state pins
   IOBUF IOBUF_scl (.I(con_scl_o), .IO(i2c_scl), .O(con_scl_i), .T(con_scl_t) );
   IOBUF IOBUF_sda (.I(con_sda_o), .IO(i2c_sda), .O(con_sda_i), .T(con_sda_t) );

   // provided module to send data BRAM -> I2C
   camera_registers crw
     (.clk_in(clk_camera),
      .rst_in(sys_rst_camera),
      .init_valid(cr_init_valid),
      .init_ready(cr_init_ready),
      .scl_i(con_scl_i),
      .scl_o(con_scl_o),
      .scl_t(con_scl_t),
      .sda_i(con_sda_i),
      .sda_o(con_sda_o),
      .sda_t(con_sda_t),
      .bram_dout(registers_dout),
      .bram_addr(registers_addr));

   // a handful of debug signals for writing to registers
   assign led[0] = crw.bus_active;
   assign led[1] = cr_init_valid;
   assign led[2] = cr_init_ready;
   assign led[15:3] = 0;

endmodule // top_level


`default_nettype wire

