wire media_external_new_file=(media_img_mounted[0] && !media_mount_d) ||
                            (media_user_reset && !media_user_reset_d);
wire media_new_file=media_external_new_file || playlist_selected || media_eof_close;
media_movie_playlist playlist(
 .clk(clk_sys),.reset(RESET),.open(media_external_new_file),
 .metadata_clk(PLAYER_META_CLOCK),.metadata_address(PLAYER_META_ADDRESS),.metadata_data(PLAYER_META_DATA),
 .mounted_size(media_img_mounted[0]?media_img_size:media_mount_size),
 .completed(media_video_eof_close),.osd_open(media_osd_sync[2]),.key(ps2_key),
 .reader_idle(media_reader_idle),.reader_error(media_error),.stream_data(media_stream_data),.stream_valid(media_stream_valid),
 .scan_busy(playlist_scan_busy),.scan_cancel(playlist_scan_cancel),.stream_ready(playlist_stream_ready),
 .scan_start(playlist_scan_start),.scan_offset(playlist_scan_offset),.scan_end(playlist_scan_end),
 .selected(playlist_selected),.movie_base(media_file_base),.movie_size(media_file_size),
 .subtitle_base(playlist_subtitle_base),.subtitle_size(playlist_subtitle_size),
 .playlist_active(playlist_active),.track(playlist_track),.count(playlist_count),.error(playlist_error));
wire media_paused_sys,media_seek_sys,media_seek_restart;
wire [34:0] media_target_sys,media_elapsed_sys,media_elapsed_q;
wire media_seek_done,media_seek_done_sys;
wire [36:0] media_control_mpeg;
wire media_paused=media_control_mpeg[36];
wire media_seeking=media_control_mpeg[35];
wire [34:0] media_target_q=media_control_mpeg[34:0];
wire media_search_restart,media_search_busy,media_probe_sys;
wire [40:0] media_start_offset,media_video_start;
wire [7:0] media_search_tag,media_search_echo;
wire [90:0] media_seek_config_mpeg;
wire [7:0] media_search_tag_mpeg=media_seek_config_mpeg[90:83];
wire media_probe_mpeg=media_seek_config_mpeg[82];
wire [40:0] media_start_offset_mpeg=media_seek_config_mpeg[81:41];
wire [40:0] media_video_start_mpeg=media_seek_config_mpeg[40:0];
wire media_movie_origin_valid;
wire [32:0] media_movie_origin;
wire media_point_found;
wire [32:0] media_point_pts;
wire [40:0] media_point_pack,media_point_sequence;
wire [159:0] media_probe_response_sys;
wire media_restart=media_new_file||media_search_restart;
video_config_cdc #(.WIDTH(91)) seek_file_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_search_tag,media_probe_sys,media_start_offset,media_video_start}),
 .dst_data(media_seek_config_mpeg));
video_config_cdc #(.WIDTH(8)) seek_file_echo_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(media_search_tag_mpeg),.dst_data(media_search_echo));
video_config_cdc #(.WIDTH(160)) seek_probe_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_search_tag_mpeg,av_is_ps,media_movie_origin_valid,media_movie_origin,
            media_point_found,av_raw_end,media_point_pts,media_point_pack,media_point_sequence}),
 .dst_data(media_probe_response_sys));
media_seek_search media_seek_search(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.request(media_seek_restart),
 .program_stream(media_probe_response_sys[151]),.origin_valid(media_probe_response_sys[150]),
 .origin(media_probe_response_sys[149:117]),.target_q(media_target_sys),.file_size(media_file_size),
 .reader_start(media_reader_start),.reader_position(media_byte_position),
 .response_tag(media_probe_response_sys[159:152]),.point_found(media_probe_response_sys[116]),
 .probe_end(media_probe_response_sys[115]),.point_pts(media_probe_response_sys[114:82]),
 .point_pack(media_probe_response_sys[81:41]),.point_sequence(media_probe_response_sys[40:0]),
 .busy(media_search_busy),.probing(media_probe_sys),.restart(media_search_restart),
 .tag(media_search_tag),.start_offset(media_start_offset),.video_start(media_video_start));
(* preserve, altera_attribute="-name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] media_osd_sync=0;
always @(posedge clk_sys) media_osd_sync<={media_osd_sync[1:0],OSD_STATUS};
media_keyboard_control #(.RESTART_BOTH_DIRECTIONS(1),.ENABLE_SEEK_GATE(1)) media_keyboard_control(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),.enabled(media_file_size!=0 && !playlist_scan_busy && !media_duration_busy),
 .seek_enabled(1'b1),.osd_open(media_osd_sync[2]),.key(ps2_key),.elapsed_q(media_elapsed_sys),
 .seek_done(media_seek_done_sys && !media_search_busy),.restart_complete(media_reader_start && !media_probe_sys),
 .duration_q(media_duration_q),
 .seek_origin_q(35'd0),
 .duration_valid(media_duration_known),
 .paused(media_paused_sys),.seek_active(media_seek_sys),
 .seek_target_q(media_target_sys),.restart(media_seek_restart));
video_config_cdc #(.WIDTH(37)) playback_control_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data({media_paused_sys,media_seek_sys,media_target_sys}),.dst_data(media_control_mpeg));
video_config_cdc #(.WIDTH(36)) playback_position_config(
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),
 .src_data({media_seek_done,media_elapsed_q}),.dst_data({media_seek_done_sys,media_elapsed_sys}));
always @(posedge clk_sys) begin
    media_mount_d<=media_img_mounted[0];media_user_reset_d<=media_user_reset;
    if(RESET) media_mount_size<=0;
    else if(media_img_mounted[0]) media_mount_size<=media_img_size;
end
// Duration preflight owns the same reader until every accepted response drains.
wire media_duration_busy,media_duration_start,media_duration_cancel,media_duration_ready;
wire media_duration_valid;
wire [34:0] media_duration_q;
wire [63:0] media_duration_size,media_duration_offset;
media_duration_probe media_duration_probe(
 .clk(clk_sys),.reset(RESET||playlist_scan_busy),.new_file(media_new_file),.file_size(media_file_size),
 .reader_idle(media_reader_idle),.reader_error(media_error),
 .stream_data(media_stream_data),.stream_valid(media_stream_valid),.stream_ready(media_duration_ready),
 .busy(media_duration_busy),.reader_start(media_duration_start),.reader_cancel(media_duration_cancel),
 .read_size(media_duration_size),.read_offset(media_duration_offset),
 .duration_valid(media_duration_valid),.duration_q(media_duration_q),.origin());
wire playlist_ui_visible;
media_album_ui_toggle playlist_ui_keys(
 .clk(clk_sys),.reset(RESET),.new_file(media_external_new_file),
 .enabled(playlist_active&&!playlist_scan_busy),.osd_open(media_osd_sync[2]),
 .key(ps2_key),.visible(playlist_ui_visible));
// The A key alone selects display shape; sequence metadata never overrides it.
wire aspect_wide,ar;
media_aspect_toggle aspect_key(.clk(clk_sys),.osd_open(media_osd_sync[2]),.key(ps2_key),.wide(aspect_wide));
video_config_cdc #(.WIDTH(1)) aspect_config (
 .src_clk(clk_sys), .dst_clk(clk_video),
 .src_data(aspect_wide), .dst_data(ar)
);
assign VIDEO_ARX = ar ? 13'd16 : 13'd4;
assign VIDEO_ARY = ar ? 13'd9 : 13'd3;
assign PLAYER_META_STATE={playlist_active&&playlist_ui_visible&&!playlist_scan_busy,playlist_count,playlist_track+8'd1};
assign PLAYER_UI_CLOCK=clk_sys;
media_ui_state player_ui_state(
 .clk(clk_sys),.reset(RESET),.new_file(media_new_file),
 .loaded(media_file_size!=0 && !playlist_scan_busy && !media_duration_busy && !media_fifo_reset),
 .duration_known(media_duration_known),
 .paused(media_paused_sys),.seeking(media_seek_sys),
 .elapsed_q(media_elapsed_sys),.target_q(media_target_sys),
 .duration_q(media_duration_q),.duration_valid(media_duration_valid),.scene_state(PLAYER_UI_STATE));
media_session_control #(.ENABLE_START_READY(1)) media_session_control (
 .clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),.reset(RESET),.restart(media_restart),
 .reader_idle(media_reader_idle),.ddr_idle(media_ddr_idle),
 .start_ready(media_search_echo==media_search_tag && !media_duration_busy && !playlist_scan_busy),
 .reader_cancel(media_reader_cancel),.fifo_reset(media_fifo_reset),
 .reader_start(media_reader_start),.quiesce(media_quiesce),
 .decoder_reset(media_decoder_reset),.generation(media_generation)
);
media_file_reader media_file_reader (
 .clk(clk_sys),.reset(RESET),.start(playlist_scan_busy ? playlist_scan_start : (media_duration_busy ? media_duration_start : (media_reader_start && media_file_size!=0))),
 .cancel(playlist_scan_busy ? playlist_scan_cancel : (media_duration_busy ? media_duration_cancel : (media_reader_cancel || media_fatal_sys))),.suspend(1'b0),
 .file_base(playlist_scan_busy ? 64'd0 : media_file_base),
 .file_size(playlist_scan_busy ? playlist_scan_end : (media_duration_busy ? media_duration_size : media_file_size)),
 .start_offset(playlist_scan_busy ? playlist_scan_offset : (media_duration_busy ? media_duration_offset : {23'd0,media_start_offset})),
 .sd_lba(media_sd_lba[0]),.sd_blk_cnt(media_sd_blocks[0]),.sd_rd(media_sd_rd[0]),
 .sd_ack(media_sd_ack[0]),.sd_buff_wr(media_reader_wr[0]),
 .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
 .stream_data(media_stream_data),.stream_valid(media_stream_valid),
 .stream_ready(playlist_scan_busy ? playlist_stream_ready : (media_duration_busy ? media_duration_ready : (!mpeg2_stream_full && !media_fifo_reset))),.idle(media_reader_idle),
 .byte_position(media_byte_position),.requests(),
 .completions(),.max_wait(),.error(media_error)
);
always @(posedge clk_sys) begin
 if(media_fifo_reset) media_prefill<=0;
 else begin
  if(media_fifo_used>=4096 || (media_stream_valid && media_stream_data[8])) media_prefill<=1;
 end
end
video_config_cdc #(.WIDTH(1)) media_prefill_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_prefill),.dst_data(media_prefill_mpeg));
video_config_cdc #(.WIDTH(1)) media_fatal_config (
 .src_clk(clk_mpeg2),.dst_clk(clk_sys),.src_data(mpeg2_new_transport_fatal_error),.dst_data(media_fatal_sys));
// Reader failure participates in seek termination; preserve that functional
// event without carrying the former 256-bit statistics snapshot.
video_config_cdc #(.WIDTH(1)) reader_error_config (
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),
 .src_data(|media_error),.dst_data(media_reader_error_mpeg));
wire        mpeg2_stream_full;
wire        mpeg2_stream_empty;
wire [7:0]  mpeg2_fifo_data;
wire [7:0]  mpeg2_stream_data;
wire        mpeg2_new_system_input_ready;
wire        mpeg2_new_system_input_valid;
wire        mpeg2_stream_rd;
wire        mpeg2_stream_wr;
wire        mpeg2_new_decode_stream_valid;
wire        mpeg2_new_stream_ready;
wire        mpeg2_new_decoder_stream_ready;
wire        mpeg2_new_b_presentation_hold;
wire        mpeg2_new_p_destination_ownership_hold;

media_sd_owner mounted_file_owner(.clk(clk_sys),.reset(RESET),.request(media_sd_rd),.ack(media_sd_ack),
 .subtitle_archive(subtitle_archive),.reader_lba(media_sd_lba),.reader_blocks(media_sd_blocks),
 .host_lba(media_host_lba),.host_blocks(media_host_blocks),.host_ack(media_host_ack),
 .buff_wr(media_sd_wr),.host_request(media_host_rd),.reader_wr(media_reader_wr));
wire[36:0] subtitle_elapsed_q;
wire subtitle_before_start,subtitle_retime;
wire [6:0] subtitle_offset_code,subtitle_speed_code;
media_subtitle_select subtitle_select(.clk(clk_sys),.reset(RESET),
 .offset_select(status[57:7]),.speed_select(status[108:58]),
 .offset_code(subtitle_offset_code),.speed_code(subtitle_speed_code));
media_subtitle_time subtitle_time(.clk(clk_sys),.reset(RESET||media_new_file),
 .elapsed_q(media_elapsed_sys),.offset_code(subtitle_offset_code),.speed_code(subtitle_speed_code),
 .subtitle_q(subtitle_elapsed_q),.before_start(subtitle_before_start),.restart(subtitle_retime));
media_subtitles subtitles(.clk(clk_sys),.reset(RESET),.new_movie(media_new_file),
 .mount(media_img_mounted[1]),.mount_size(media_img_size),
 .auto_load(playlist_selected&&playlist_active),.auto_base(playlist_subtitle_base),.auto_size(playlist_subtitle_size),.archive_source(subtitle_archive),
 .loaded(PLAYER_UI_STATE[74]),.seeking(media_seek_sys||subtitle_retime),.enabled(!status[120]&&!subtitle_before_start),
 .suspend(playlist_scan_busy || media_duration_busy || media_seek_sys || (media_fifo_occupancy<16'd8192 && !media_reader_idle)),
 .elapsed_q(subtitle_elapsed_q),.epoch(PLAYER_UI_STATE[90:75]),
 .sd_lba(media_sd_lba[1]),.sd_blocks(media_sd_blocks[1]),.sd_rd(media_sd_rd[1]),
 .sd_ack(media_sd_ack[1]),.sd_wr(media_reader_wr[1]),.sd_addr(media_sd_addr),.sd_data(media_sd_data),
 .command(PLAYER_SUBTITLE_COMMAND),.command_ack(PLAYER_SUBTITLE_ACK),.warning());

hps_io #(.CONF_STR(CONF_STR), .CONF_STR_BRAM(1), .WIDE(1), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask(16'd0),
	.ps2_key(ps2_key),

    .img_mounted(media_img_mounted),.img_size(media_img_size),
    .sd_lba(media_host_lba),.sd_blk_cnt(media_host_blocks),
    .sd_rd(media_host_rd),.sd_wr(2'b0),.sd_ack(media_host_ack),
    .sd_buff_addr(media_sd_addr),.sd_buff_dout(media_sd_data),
    .sd_buff_din(media_sd_unused),.sd_buff_wr(media_sd_wr),
    .ioctl_wait(1'b0)

);

