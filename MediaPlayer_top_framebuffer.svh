wire mpeg2_new_framebuffer_reset =
    reset_mpeg2 || media_seeking || (mpeg2_new_framebuffer_swap_reset_count != 3'd0);

localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK_WORDS     = 29'h00010000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS = 29'h00020000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS = 29'h00030000;
localparam [28:0] MPEG2_NEW_DDR_FRAME_BANK2_WORDS    = 29'h00040000;
wire [28:0] mpeg2_new_display_frame_offset =
    mpeg2_new_display_scratch ?
        (mpeg2_new_display_scratch_bank ? MPEG2_NEW_DDR_FRAME_SCRATCH1_WORDS :
                                           MPEG2_NEW_DDR_FRAME_SCRATCH0_WORDS) :
    (mpeg2_new_display_frame_bank == 2'd1) ? MPEG2_NEW_DDR_FRAME_BANK_WORDS :
    (mpeg2_new_display_frame_bank == 2'd2) ? MPEG2_NEW_DDR_FRAME_BANK2_WORDS :
                                             29'd0;
assign mpeg2_new_ddr_rd_banked_addr =
    mpeg2_new_ddr_rd_addr + mpeg2_new_display_frame_offset;


wire video_matrix_bt709;
media_color_control color_control(
 .sys_clk(clk_sys),.decoder_clk(clk_mpeg2),.video_clk(clk_video),
 .video_reset(reset_video),.mode(status[5:4]),
 .display_bt709(mpeg2_new_display_bt709),
 .frame_start((display_h_pos==0)&&(display_v_pos==0)),
 .matrix_bt709(video_matrix_bt709));

mpeg2_luma_framebuffer #(.ENABLE_COLOR_MATRIX(1)) mpeg2_luma_framebuffer
(
    .reset          (mpeg2_new_framebuffer_reset),
    .mem_clk        (clk_mpeg2),
    .picture_complete(mpeg2_new_first_picture_420_parsed),
    .horizontal_size(mpeg2_new_horizontal_size),
    .vertical_size  (mpeg2_new_vertical_size),
    .ddram_busy     (mpeg2_new_ddr_reader_busy),
    .ddram_dout     (DDRAM_DOUT),
    .ddram_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .ddram_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .ddram_addr     (mpeg2_new_ddr_rd_addr),
    .ddram_rd       (mpeg2_new_ddr_rd),
    .cache_ready    (),
    .read_seen      (),
    .cache_error    (mpeg2_new_ddr_cache_error),
    .rd_clk         (clk_video),
    .matrix_bt709(video_matrix_bt709),
    .h_pos          (display_h_pos),
    .v_pos          (display_v_pos),
    .pixel_en       (display_pixel_en),
    .h_sync         (display_h_sync),
    .v_sync         (display_v_sync),
    .video_r        (fb_video_r),
    .video_g        (fb_video_g),
    .video_b        (fb_video_b),
    .video_de       (fb_video_de),
    .video_hs       (fb_video_hs),
    .video_vs       (fb_video_vs)
);

mpeg2_h262_ddram_arbiter #(.ENABLE_QUIESCE(1),.ENABLE_DISPLAY_RELEASE(1)) mpeg2_h262_ddram_arbiter
(
    .clk             (clk_mpeg2),
    .reset           (reset_mpeg2),
    .quiesce(media_quiesce),.idle(media_movie_ddr_idle),
    .release_display_bank(media_seeking),
    .writer_burstcnt (mpeg2_new_ddr_wr_burstcnt),
    .writer_addr     (mpeg2_new_ddr_wr_addr),
    .writer_rd       (mpeg2_new_ddr_wr_rd),
    .writer_din      (mpeg2_new_ddr_wr_din),
    .writer_be       (mpeg2_new_ddr_wr_be),
    .writer_we       (mpeg2_new_ddr_wr_we),
    .writer_busy     (mpeg2_new_ddr_writer_busy),
    .reader_burstcnt (mpeg2_new_ddr_rd_burstcnt),
    .reader_addr     (mpeg2_new_ddr_rd_banked_addr),
    .reader_rd       (mpeg2_new_ddr_rd),
    .reader_busy     (mpeg2_new_ddr_reader_busy),
    .reader_dout_ready(mpeg2_new_ddr_reader_dout_ready),
    .prediction_burstcnt (mpeg2_new_pred_burstcnt),
    .prediction_addr     (mpeg2_new_pred_addr),
    .prediction_rd       (mpeg2_new_pred_rd),
    .prediction_busy     (mpeg2_new_pred_busy),
    .prediction_dout_ready(mpeg2_new_pred_dout_ready),
    .stream_addr(av_mem_addr),.stream_din(av_mem_data),
    .stream_rd(av_mem_read),.stream_we(av_mem_write),.stream_busy(av_mem_busy),
    .stream_dout_ready(av_mem_q_valid),
    // Preserve physical busy while quiescing so accepted DDR requests drain.
    .ddram_busy      (DDRAM_BUSY),
    .ddram_dout_ready(DDRAM_DOUT_READY),
    .ddram_burstcnt  (movie_mem_burst),
    .ddram_addr      (movie_mem_addr),
    .ddram_rd        (movie_mem_read),
    .ddram_din       (movie_mem_data),
    .ddram_be        (movie_mem_be),
    .ddram_we        (movie_mem_write)
);
