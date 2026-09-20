// FPGA MP2 and progressive MPG integration; all compressed-stream logic runs
// at clk_mpeg2. Audio crosses only through CDC FIFOs into CLK_AUDIO.
wire [42:0] av_video_q;
wire av_video_q_valid,av_video_q_ready,av_video_fifo_ready;
wire [28:0] av_mem_addr;
wire [63:0] av_mem_data;
wire av_mem_read,av_mem_write,av_mem_busy,av_mem_q_valid;
wire [20:0] av_video_ram_level;
wire [10:0] av_audio_ram_level;
wire [11:0] mp2_pcm_wr_used;
reg av_eof_queued;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) av_eof_queued<=0;
    else if(av_ingress_end&&!av_eof_queued&&av_video_fifo_ready) av_eof_queued<=1;
end
assign av_video_ready=av_is_ps?av_video_fifo_ready:mpeg2_ingress_ready;
wire [7:0] av_expanded_data;
wire av_expanded_valid,av_expanded_end;
assign mpeg2_ingress_data=av_is_ps?av_expanded_data:av_video_byte;
assign mpeg2_ingress_valid=av_is_ps?av_expanded_valid:av_video_valid;
assign mpeg2_ingress_end=av_is_ps?av_expanded_end:av_ingress_end;
mpeg2_av_ddr_fifo av_video_fifo (
    .clk(clk_mpeg2),.reset(reset_mpeg2),
    .input_data({av_ingress_end,av_video_pts_valid,av_video_pts,av_video_byte}),
    .input_valid(av_is_ps&&(av_video_valid||(av_ingress_end&&!av_eof_queued))),.input_ready(av_video_fifo_ready),
    .output_data(av_video_q),.output_valid(av_video_q_valid),.output_ready(av_video_q_ready),
    .mem_addr(av_mem_addr),.mem_data(av_mem_data),.mem_read(av_mem_read),.mem_write(av_mem_write),
    .mem_busy(av_mem_busy),.mem_q(DDRAM_DOUT),.mem_q_valid(av_mem_q_valid),.ram_level(av_video_ram_level)
);
mpeg2_pes_metadata_expand av_video_expand (
    .clk(clk_mpeg2),.reset(reset_mpeg2),.input_data(av_video_q),.input_valid(av_video_q_valid),
    .input_ready(av_video_q_ready),.output_data(av_expanded_data),.output_valid(av_expanded_valid),
    .output_ready(mpeg2_ingress_ready),.output_end(av_expanded_end)
);
wire [41:0] av_audio_q;
wire av_audio_q_valid,av_audio_q_ready,av_audio_empty;
av_stream_fifo av_audio_fifo (
    .clk(clk_mpeg2),.reset(reset_mpeg2),.input_data({av_audio_pts_valid,av_audio_pts,av_audio_byte}),
    .input_valid(av_audio_valid),.input_ready(av_audio_ready),.output_data(av_audio_q),
    .output_valid(av_audio_q_valid),.output_ready(av_audio_q_ready),.empty(av_audio_empty),.ram_level(av_audio_ram_level)
);
wire mp2_pcm_valid,mp2_pcm_ready,mp2_error,mp2_idle;
wire signed [15:0] mp2_pcm_l,mp2_pcm_r;
wire [32:0] mp2_pcm_pts;
wire mp2_pcm_pts_valid;
mp2_decoder #(.ENABLE_SEEK_SKIP(1),.ENABLE_START_SYNC(1)) mp2_decoder (
    .clk(clk_mpeg2),.reset(reset_mpeg2),.input_data(av_audio_q[7:0]),.input_valid(av_audio_q_valid),
    .input_ready(av_audio_q_ready),.input_end(av_ingress_end&&av_audio_empty),
    .input_pts(av_audio_q[40:8]),.input_pts_valid(av_audio_q[41]),
    .pcm_valid(mp2_pcm_valid),.pcm_ready(mp2_pcm_ready),.pcm_left(mp2_pcm_l),.pcm_right(mp2_pcm_r),
    .pcm_pts(mp2_pcm_pts),.pcm_pts_valid(mp2_pcm_pts_valid),.error(mp2_error),
    .frames_decoded(),.idle(mp2_idle),
    .resync_start(media_start_offset_mpeg!=0),
    .seek(media_seeking),.seek_target(media_seek_pts)
);
wire mp2_fifo_full,mp2_fifo_empty,mp2_fifo_rd;
wire [66:0] mp2_fifo_data;
reg mp2_eof_queued;
wire mp2_eof=av_ingress_end&&av_audio_empty&&mp2_idle&&!mp2_eof_queued;
assign mp2_pcm_ready=!mp2_fifo_full;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) mp2_eof_queued<=0;
    else if(mp2_eof&&!mp2_fifo_full) mp2_eof_queued<=1;
end
mp2_pcm_fifo mp2_pcm_fifo (
    .reset(reset_mpeg2),.wr_clk(clk_mpeg2),.rd_clk(CLK_AUDIO),
    .wr_data({mp2_eof,mp2_pcm_pts_valid,mp2_pcm_pts,mp2_pcm_l,mp2_pcm_r}),
    .wr_en((mp2_pcm_valid||mp2_eof)&&!mp2_fifo_full),.wr_full(mp2_fifo_full),.wr_used(mp2_pcm_wr_used),
    .rd_data(mp2_fifo_data),.rd_en(mp2_fifo_rd),.rd_empty(mp2_fifo_empty)
);
// Origin is common to the video scheduler and PCM sink. A 100 ms preroll
// permits independent codec startup without consuming movie audio early.
wire av_seek_origin=media_seeking && media_movie_origin_valid && !media_probe_mpeg;
wire [32:0] av_origin=(av_seek_origin ? media_movie_origin : mpeg2_new_inband_pts_90k)-33'd9000;
reg av_origin_sent;
wire av_origin_full,av_origin_empty;
wire [32:0] av_origin_q;
wire av_origin_wr=av_is_ps&&(mpeg2_new_inband_valid||av_seek_origin)&&!av_origin_sent&&!av_origin_full;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) av_origin_sent<=0;
    else if(av_origin_wr) av_origin_sent<=1;
end
dcfifo #(.lpm_numwords(4),.lpm_showahead("ON"),.lpm_type("dcfifo"),.lpm_width(33),
    .lpm_widthu(2),.overflow_checking("ON"),.underflow_checking("ON"),.use_eab("ON"),
    .rdsync_delaypipe(4),.wrsync_delaypipe(4),.write_aclr_synch("ON"),.read_aclr_synch("ON")
) av_origin_fifo (.aclr(reset_mpeg2),.data(av_origin),.wrclk(clk_mpeg2),
    .wrreq(av_origin_wr),.wrfull(av_origin_full),.q(av_origin_q),.rdclk(CLK_AUDIO),
    .rdreq(!av_origin_empty&&!reset_mp2_out),.rdempty(av_origin_empty));
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mp2_reset_sync;
always @(posedge CLK_AUDIO or posedge reset_mpeg2) begin
    if(reset_mpeg2) mp2_reset_sync<=3'b111;
    else mp2_reset_sync<={mp2_reset_sync[1:0],1'b0};
end
wire reset_mp2_out=mp2_reset_sync[2];
wire signed [15:0] mp2_output_l,mp2_output_r;
wire mp2_finished;
// A single held bundle transfers pause, seek state and the destination PTS.
reg [32:0] media_first_pts;
reg media_first_pts_valid;
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) begin media_first_pts<=0;media_first_pts_valid<=0;end
 else if(mpeg2_new_inband_valid&&!media_first_pts_valid) begin
  media_first_pts<=mpeg2_new_inband_pts_90k;media_first_pts_valid<=1;
 end
end
wire [32:0] media_seek_pts=(media_movie_origin_valid ? media_movie_origin : media_first_pts)+media_seek_elapsed;
wire media_paused_audio,media_seeking_audio;
wire [32:0] media_seek_pts_audio;
video_config_cdc #(.WIDTH(35)) playback_audio_config(
 .src_clk(clk_mpeg2),.dst_clk(CLK_AUDIO),
 .src_data({media_paused,media_seeking,media_seek_pts}),
 .dst_data({media_paused_audio,media_seeking_audio,media_seek_pts_audio}));
mp2_pcm_output #(.ENABLE_PLAYBACK_CONTROL(1)) mp2_pcm_output (
    .clk(CLK_AUDIO),.reset(reset_mp2_out),
    .pause(media_paused_audio),.seek(media_seeking_audio),.seek_target(media_seek_pts_audio),
    .origin_valid(!av_origin_empty),.origin_pts(av_origin_q),
    .fifo_data(mp2_fifo_data),.fifo_empty(mp2_fifo_empty),.fifo_rd(mp2_fifo_rd),
    .audio_l(mp2_output_l),.audio_r(mp2_output_r),.underrun(),
    .timestamp_error(),.finished(mp2_finished),.samples_played()
);
assign audio_pcm_output_l=mp2_output_l;
assign audio_pcm_output_r=mp2_output_r;
wire av_picture_pts_valid;
wire [32:0] av_picture_pts;
mpeg2_pes_picture_pts av_picture_pts_bind (
    .clk(clk_mpeg2),.reset(reset_mpeg2),.stream_data(mpeg2_stream_data),
    .stream_valid(mpeg2_new_decode_stream_valid),.metadata_valid(mpeg2_new_inband_valid),
    .metadata_pts(mpeg2_new_inband_pts_90k),.pts_valid(av_picture_pts_valid),.pts(av_picture_pts)
);
// PCM completion is functional: EOF must wait for the final audio sample.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mp2_finished_sync;
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) mp2_finished_sync<=0;
 else mp2_finished_sync<={mp2_finished_sync[1:0],mp2_finished};
end
