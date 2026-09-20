///////////////////////   CLOCKS   ///////////////////////////////

// AUDIO_FORK_POINT[CLOCK_RESET]: advisory v0.5.0 handoff, not a permanent ABI.
// Add audio as a sibling clock/reset consumer.  Reusing clk_mpeg2 is acceptable
// only if its throughput and timing remain suitable; otherwise add an explicit
// audio clock domain and synchronize reset release/CDC using the same discipline
// below.  Audio FIFO readiness must not be ANDed into mpeg2_new_stream_ready:
// routine A/V synchronization belongs above the two independent decoder pipes.
wire clk_sys;
wire clk_video;
wire clk_mpeg2;
wire clk_mpeg2_mem;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_video),
	.outclk_2(clk_mpeg2),
	.outclk_3(clk_mpeg2_mem)
);

// kate - Phase 1P CDC/reset closure.
//
// RESET, status[0], and buttons[1] originate outside the MPEG/video clock
// domains.  Treat their OR as an asynchronous reset request, then synchronize
// reset RELEASE independently into each destination domain.  Assertion is
// asynchronous into these small synchronizer chains, so even a short request
// is stretched until the destination clock has observed it.
//
// This is an implementation/timing-safety change, not an H.262 requirement.
// User reset restarts a session through the DDR-drain handshake.
wire reset_request = RESET;

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_mpeg2_sync;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] reset_video_sync;

always @(posedge clk_mpeg2 or posedge reset_request) begin
	if (reset_request)
		reset_mpeg2_sync <= 3'b111;
	else
		reset_mpeg2_sync <= {reset_mpeg2_sync[1:0], 1'b0};
end

always @(posedge clk_video or posedge reset_request) begin
	if (reset_request)
		reset_video_sync <= 3'b111;
	else
		reset_video_sync <= {reset_video_sync[1:0], 1'b0};
end

wire reset_mpeg2_base = reset_mpeg2_sync[2];
wire reset_video = reset_video_sync[2];

wire reset_mpeg2 = reset_mpeg2_base || media_decoder_reset;

// The first scheduled frame starts playback. EOF closure follows the same
// reset/drain path as a fresh load and restores startup message behavior.
wire media_new_file_mpeg;
video_config_cdc #(.WIDTH(1)) playback_hide_reset_config(
 .src_clk(clk_sys),.dst_clk(clk_mpeg2),.src_data(media_new_file_hold),.dst_data(media_new_file_mpeg));
reg media_new_file_hold=0;
always @(posedge clk_sys) begin
 if(RESET||media_new_file) media_new_file_hold<=1;
 else if(media_reader_start) media_new_file_hold<=0;
end
reg playback_started = 0;
always @(posedge clk_mpeg2) begin
    if (reset_mpeg2_base || media_new_file_mpeg) playback_started <= 0;
    else if (mpeg2_new_framebuffer_swap_reset_count != 0) playback_started <= 1;
end
video_config_cdc #(.WIDTH(1)) playback_osd_config (
 .src_clk(clk_mpeg2), .dst_clk(clk_sys),
 .src_data(playback_started), .dst_data(OSD_HIDE_MESSAGE)
);


// kate - Phase 1Ob: the streaming H.262 bitreader continues to own input
// backpressure while picture_data() advances across every slice of the first
// supported I-picture.  Slice boundaries remain inside the bitreader so no
// alignment or payload bytes are discarded.
// Before the first slice is selected, bytes flow continuously for start-code/header
// parsing.  During slice parsing the bitreader stalls this FIFO whenever its
// current payload byte has not been fully consumed, including IQ/IDCT waits.
assign mpeg2_stream_wr = !playlist_scan_busy && !media_duration_busy && media_stream_valid && !mpeg2_stream_full && !media_fifo_reset;
assign mpeg2_fifo_data=media_fifo_data[7:0];
wire media_eof_at_head=!mpeg2_stream_empty && media_fifo_data[8];
wire media_data_read;
reg media_eof_seen=0;
always @(posedge clk_mpeg2) begin
    if(reset_mpeg2) media_eof_seen<=0;
    else if(media_prefill_mpeg && media_eof_at_head) media_eof_seen<=1;
end
assign mpeg2_stream_rd=!reset_mpeg2 && media_prefill_mpeg && (media_eof_at_head || media_data_read);

// Phase 1V: the decoder owns syntax/persistence backpressure, while the top
// level additionally pauses between a persisted B and completion of its proven
// scratch->future-reference presentation transaction. This prevents a later
// P/B pair from overtaking the two-vblank display-order operation.
// kate - Commit 162 adds a second, P-only ownership pause after the following
// picture header has been consumed and classified.  It never blocks the header
// needed to distinguish a consecutive P from a following B.
assign mpeg2_new_stream_ready =
	!media_decoder_reset &&
	mpeg2_new_decoder_stream_ready &&
	!mpeg2_new_b_presentation_hold &&
	!mpeg2_new_p_destination_ownership_hold;

// EOF is an ordered FIFO token, never a gap between host sector requests.
wire mpeg2_new_system_input_end = media_eof_seen && !reset_mpeg2;

wire [7:0] mpeg2_ingress_data;
wire mpeg2_ingress_valid, mpeg2_ingress_ready, mpeg2_ingress_end;
wire mpeg2_demux_error;

wire mpeg2_new_transport_fatal_error =
    mpeg2_demux_error || mp2_error ||
	mpeg2_new_syntax_error ||
	mpeg2_new_phase1_probe_error ||
	mpeg2_new_pred_error ||
	mpeg2_new_inverse_quant_error ||
	mpeg2_new_inverse_quant_unsupported_matrix ||
	mpeg2_new_idct_error ||
	mpeg2_new_recon_error ||
	mpeg2_new_ddr_store_error ||
	mpeg2_new_ddr_cache_error ||
	mpeg2_new_b_presentation_error;

mpeg2_h262_stream_transport_gate mpeg2_h262_stream_transport_gate
(
	.clk              (clk_mpeg2),
	.reset            (reset_mpeg2),
	.fifo_empty       (mpeg2_stream_empty || media_eof_at_head || reset_mpeg2 || !media_prefill_mpeg),
	.decoder_ready    (mpeg2_new_system_input_ready),
	.fatal_error      (mpeg2_new_transport_fatal_error),
	.fifo_read        (media_data_read),
	.decoder_valid    (mpeg2_new_system_input_valid)
);
