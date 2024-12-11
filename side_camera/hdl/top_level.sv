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
   // spi receive
   input wire cipo, 
   input wire dclk, 
   input wire cs, // SPI controller-in peripheral-out
   // audio
   output logic        spkl, spkr // left and right channels of line out port
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
  assign cam_xclk = sw[0] ? clk_xc : 1'b0;

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

  // your pixel_reconstruct module, from the exercise!
  // hook it up to buffered inputs.
  pixel_reconstruct pixel
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


  //two-port BRAM used to hold image from camera.
  //The camera is producing video at 720p and 30fps, but we can't store all of that
  //we're going to down-sample by a factor of 4 in both dimensions
  //so we have 320 by 180.  this is kinda a bummer, but we'll fix it
  //in future weeks by using off-chip DRAM.
  //even with the down-sample, because our camera is producing data at 30fps
  //and  our display is running at 720p at 60 fps, there's no hope to have the
  //production and consumption of information be synchronized in this system.
  //even if we could line it up once, the clocks of both systems will drift over time
  //so to avoid this sync issue, we use a conflict-resolution device...the frame buffer
  //instead we use a frame buffer as a go-between. The camera sends pixels in at
  //its own rate, and we pull them out for display at the 720p rate/requirement
  //this avoids the whole sync issue. It will however result in artifacts when you
  //introduce fast motion in front of the camera. These lines/tears in the image
  //are the result of unsynced frame-rewriting happening while displaying. It won't
  //matter for slow movement
  localparam FB_DEPTH = 320*180;
  localparam FB_SIZE = $clog2(FB_DEPTH);
  logic [FB_SIZE-1:0] addra; //used to specify address to write to in frame buffer

  logic valid_camera_mem; //used to enable writing pixel data to frame buffer
  logic [15:0] camera_mem; //used to pass pixel data into frame buffer
  logic [2:0] four_counter;


  always_ff @(posedge clk_camera)begin
    //create logic to handle wriiting of camera.
    //we want to down sample the data from the camera by a factor of four in both
    //the x and y dimensions!
    if (camera_valid) begin
      if ((camera_hcount[1] == 0 && camera_hcount[0] == 0) && 
         (camera_vcount[1] == 0 && camera_vcount[0] == 0)) begin
            addra <= (addra == FB_DEPTH-1 || (camera_hcount == 0 && camera_vcount == 0))? 0:(addra + 1);
            camera_mem <= camera_pixel;
            valid_camera_mem <= 1;
        end
    end else begin 
        valid_camera_mem <= 0; 
        camera_mem <= 0;
      end
  end

  //frame buffer from IP
  // stores one frame of the camera 
  blk_mem_gen_0 frame_buffer (
    .addra(addra), //pixels are stored using this math
    .clka(clk_camera),
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
  logic good_addrb_1; //used to indicate within valid frame for scaling, 1 clock cycle delay
  logic good_addrb_2; //used to indicate within valid frame for scaling, 2 clock cycle delay

  // downsample and rescale upward
  always_ff @(posedge clk_pixel)begin
    //use structure below to do scaling
    addrb <= (319-(hcount_hdmi>>2)) + 320*(vcount_hdmi>>2);
    good_addrb <= (hcount_hdmi<1280)&&(vcount_hdmi<720);
    // delay by 2 clock cycles for frame buffer
    good_addrb_1 <= good_addrb;
    good_addrb_2 <= good_addrb_1;
  end

  //split fame_buff into 3 8 bit color channels (5:6:5 adjusted accordingly)
  //remapped frame_buffer outputs with 8 bits for r, g, b
  logic [7:0] fb_red, fb_green, fb_blue;

  logic [7:0] fb_red_pip [2:0];
  logic [7:0] fb_green_pip [2:0];
  logic [7:0] fb_blue_pip [2:0];
  logic [7:0] fb_red_out, fb_green_out, fb_blue_out;

  always_ff @(posedge clk_pixel)begin
    fb_red <= good_addrb_2?{frame_buff_raw[15:11],3'b0}:8'b0;
    fb_green <= good_addrb_2?{frame_buff_raw[10:5], 2'b0}:8'b0;
    fb_blue <= good_addrb_2?{frame_buff_raw[4:0],3'b0}:8'b0;

    // delay by 3 clock cycles for PS1 and PS2
    fb_red_pip[0] <= fb_red;
    fb_green_pip[0] <= fb_green;
    fb_blue_pip[0] <= fb_blue;
    for (int i = 1; i < 3; i = i+1) begin 
      fb_red_pip[i] <= fb_red_pip[i-1];
      fb_green_pip[i] <= fb_green_pip[i-1];
      fb_blue_pip[i] <= fb_blue_pip[i-1];
    end
  end

  assign fb_red_out = fb_red_pip[2];
  assign fb_green_out = fb_green_pip[2];
  assign fb_blue_out = fb_blue_pip[2];


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

  //channel select module (select which of six color channels to mask):
  logic [2:0] channel_sel;
  logic [7:0] selected_channel; //selected channels
  //selected_channel could contain any of the six color channels depend on selection

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

  assign channel_sel = sw[3:1];
  // * 3'b000: green
  // * 3'b001: red
  // * 3'b010: blue
  // * 3'b011: not valid
  // * 3'b100: y (luminance)
  // * 3'b101: Cr (Chroma Red)
  // * 3'b110: Cb (Chroma Blue)
  // * 3'b111: not valid
  //Channel Select: Takes in the full RGB and YCrCb information and
  // chooses one of them to output as an 8 bit value
  channel_select mcs(
     .sel_in(channel_sel),
     .r_in(fb_red_out),    //needs to use pipelined signal (PS1)
     .g_in(fb_green_out),  //needs to use pipelined signal (PS1)
     .b_in(fb_blue_out),   //needs to use pipelined signal (PS1)
     .y_in(y),
     .cr_in(cr),
     .cb_in(cb),
     .channel_out(selected_channel)
  );

  // delay y (chromance) and selected_channel by 5 cycles, PS5 and PS6
  logic [7:0] y_out;
  logic [7:0] selected_channel_out;

  always_ff @(posedge clk_pixel) begin 
    y_out <= y;
    selected_channel_out <= selected_channel;
  end

  //threshold values used to determine what value  passes:
  assign lower_threshold = {sw[11:8],4'b0};
  assign upper_threshold = {sw[15:12],4'b0};

  //Thresholder: Takes in the full selected channedl and
  //based on upper and lower bounds provides a binary mask bit
  // * 1 if selected channel is within the bounds (inclusive)
  // * 0 if selected channel is not within the bounds
  threshold mt(
     .clk_in(clk_pixel),
     .rst_in(sys_rst_pixel),
     .pixel_in(selected_channel),
     .lower_bound_in(lower_threshold),
     .upper_bound_in(upper_threshold),
     .mask_out(mask) //single bit if pixel within mask.
  );

  logic [6:0] ss_c;
  //modified version of seven segment display for showing
  // thresholds and selected channel
  // special customized version
  lab05_ssc mssc(.clk_in(clk_pixel),
                 .rst_in(sys_rst_pixel),
                 .lt_in(lower_threshold),
                 .ut_in(upper_threshold),
                 .channel_sel_in(channel_sel),
                 .cat_out(ss_c),
                 .an_out({ss0_an, ss1_an})
  );
  assign ss0_c = ss_c; //control upper four digit's cathodes!
  assign ss1_c = ss_c; //same as above but for lower four digits!

  //Center of Mass Calculation: (you need to do)
  //using x_com_calc and y_com_calc values
  //Center of Mass:
  center_of_mass com_m(
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .x_in(hcount_hdmi_out),  //needs to use pipelined signal! (PS3)
    .y_in(vcount_hdmi_out), //needs to use pipelined signal! (PS3)
    .valid_in(mask), //aka threshold
    .tabulate_in((nf_hdmi)),
    .x_out(x_com_calc),
    .y_out(y_com_calc),
    .valid_out(new_com)
  );
  //grab logic for above
  //update center of mass x_com, y_com based on new_com signal
  always_ff @(posedge clk_pixel)begin
    if (sys_rst_pixel)begin
      x_com <= 0;
      y_com <= 0;
    end if(new_com)begin
      x_com <= x_com_calc;
      y_com <= y_com_calc;
    end
  end

  logic [9:0] y_com_out;

  always_ff @(posedge clk_pixel) begin 
    y_com_out <= y_com;
  end

  // CHECK IF PLAYING THEN ASSIGN TO AUDIO
  logic playing;
  assign playing = (y_com_out >= 385)? 1'b1: 1'b0;

  // SPI communication with top FPGA to know what notes are coming in

   // SPI interface controls
   logic [11:0] spi_read_data;
   logic        spi_read_data_valid;

    // synchronizers to prevent metastbility
    logic [11:0]   cipo_buf [1:0];
    logic          dclk_buf [1:0];
    logic          cs_buf [1:0];

  always_ff @(posedge clk_pixel) begin
     cipo_buf <= {cipo, cipo_buf[1]};
     dclk_buf <= {dclk, dclk_buf[1]};
     cs_buf <= {cs, cs_buf[1]};
  end


   spi_receive my_spi_receive
   ( .clk_in(clk_pixel),
     .rst_in(sys_rst_pixel),
     .chip_sel_in(cs_buf[0]),
     .chip_data_in(cipo_buf[0]), //(serial din preferably)
     .chip_clk_in(dclk_buf[0]),
     .data_out(spi_read_data),
     .data_valid_out(spi_read_data_valid) //high when output data is present.
    );

  // use chord notes 

   logic [11:0]                chord_note;
   // store your audio sample from the SPI controller, only when the data is valid!
   always_ff @(posedge clk_pixel) begin
    if (spi_read_data_valid) begin 
        chord_note <= spi_read_data;
    end
   end 

  logic spk_out;
  
  audio_construct audio
   (
    .clk_in(clk_pixel),
    .rst_in(sys_rst_pixel),
    .note_1_in(chord_note[3:0]),
    .note_2_in(chord_note[7:4]),
    .note_3_in(chord_note[11:8]),
    .spk_out(spk_out)
   );

   assign spkl = playing? spk_out: 0;
   assign spkr = playing? spk_out: 0;

  
  //blue line output for alignmnet purposes:
  logic [7:0] line_red, line_green, line_blue;

  //Create blue line at specific y position:
  //0 cycle latency
  always_comb begin
    line_red   = ((vcount_hdmi_out==385))?8'hFF:8'h00;
    line_green = ((vcount_hdmi_out==385))?8'hFF:8'h00;
    line_blue  = ((vcount_hdmi_out==385))?8'hFF:8'h00;
  end

  //crosshair output:
  logic [7:0] ch_red, ch_green, ch_blue;

  //Create Crosshair patter on center of mass:
  //0 cycle latency
  //Should be using output of (PS3)
  always_comb begin
    ch_red   = ((vcount_hdmi_out==y_com) || (hcount_hdmi_out==x_com))?8'hFF:8'h00;
    ch_green = ((vcount_hdmi_out==y_com) || (hcount_hdmi_out==x_com))?8'hFF:8'h00;
    ch_blue  = ((vcount_hdmi_out==y_com) || (hcount_hdmi_out==x_com))?8'hFF:8'h00;
  end
  
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
    
  // delay 7 cycles 
  logic [10:0] hcount_hdmi_pip [6:0];
  logic [9:0] vcount_hdmi_pip [6:0];
  logic [10:0] hcount_hdmi_out;
  logic [9:0] vcount_hdmi_out;

  always_ff @(posedge clk_pixel) begin
    hcount_hdmi_pip[0] <= hcount_hdmi;
    vcount_hdmi_pip[0] <= vcount_hdmi;
    for (int i = 1; i < 7; i = i + 1) begin 
      hcount_hdmi_pip[i] <= hcount_hdmi_pip[i-1];
      vcount_hdmi_pip[i] <= vcount_hdmi_pip[i-1];
    end
  end
  assign hcount_hdmi_out = hcount_hdmi_pip[6];
  assign vcount_hdmi_out = vcount_hdmi_pip[6];


  // Video Mux: select from the different display modes based on switch values
  //used with switches for display selections
  logic [1:0] display_choice;
  logic [1:0] target_choice;

  assign display_choice = sw[5:4];
  assign target_choice =  sw[7:6];

  //choose what to display from the camera:
  // * 'b00:  normal camera out
  // * 'b01:  selected channel image in grayscale
  // * 'b10:  masked pixel (all on if 1, all off if 0)
  // * 'b11:  chroma channel with mask overtop as magenta
  //
  //then choose what to use with center of mass:
  // * 'b00: nothing
  // * 'b01: crosshair
  // * 'b10: blue line for alignment
  // * 'b11: crosshair and blue line for alignment

  video_mux mvm(
    .bg_in(display_choice), //choose background
    .target_in(target_choice), //choose target
    .camera_pixel_in({fb_red_out, fb_green_out, fb_blue_out}), // needs (PS2)
    .camera_y_in(y_out), //luminance, needs (PS6)
    .channel_in(selected_channel_out), //current channel being drawn, needs (PS5)
    .thresholded_pixel_in(mask), //one bit mask signal, needs (PS4)
    .crosshair_in({ch_red, ch_green, ch_blue}), //needs (PS8)
    .line_pixel_in({line_red, line_green, line_blue}), //needs (PS9) maybe?
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
   // light for debugging if playing tracking working
   assign led[15] = playing;
   // light for debugging SPI receive
   assign led[14] = chord_note[11];
   assign led[13] = chord_note[10];
   assign led[12] = chord_note[9];
   assign led[11] = chord_note[8];
   assign led[10] = chord_note[7];
   assign led[9] = chord_note[6];
   assign led[8] = chord_note[5];
   assign led[7] = chord_note[4];
   assign led[6] = chord_note[3];
   assign led[5] = chord_note[2];
   assign led[4] = chord_note[1];
   assign led[3] = chord_note[0];

endmodule // top_level


`default_nettype wire

