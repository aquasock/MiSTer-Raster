///////////////////////   VIDEO TIMING   /////////////////////////

// AUDIO_FORK_POINT[AV_SYNC]: advisory v0.5.0 handoff, not a permanent ABI.
// Future A/V synchronization should observe the presentation side, not H.262
// syntax state.  Useful starting signals are display_v_pos here plus
// mpeg2_new_swap_window_pulse / mpeg2_new_b_presentation_complete in
// Raster_top_prediction.svh and the actual framebuffer swap in
// Raster_top_framebuffer.svh.  Export a
// clean video-present/timebase event to a higher-level A/V controller; let that
// controller use timestamps/buffer occupancy/drop-repeat policy rather than
// directly stalling either codec's internal parser for normal synchronization.
wire [11:0] display_h_pos;
wire [11:0] display_v_pos;
wire        display_pixel_en;
wire        display_h_sync;
wire        display_v_sync;

wire [7:0]  fb_video_r;
wire [7:0]  fb_video_g;
wire [7:0]  fb_video_b;
wire        fb_video_de;
wire        fb_video_hs;
wire        fb_video_vs;

// ---------------------------------------------------------------------------
// Audio-clock-derived 90 kHz ticks drive video presentation and EOF timing.
// The clock itself remains active; profiler-only whole-second reporting is gone.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [1:0] stc_audio_reset_sync;
always @(posedge CLK_AUDIO or posedge reset_mpeg2_base) begin
	if (reset_mpeg2_base) stc_audio_reset_sync <= 2'b11;
	else                  stc_audio_reset_sync <= {stc_audio_reset_sync[0],1'b0};
end
wire stc_audio_reset = stc_audio_reset_sync[1];

wire        stc_tick_90k_audio;

mpeg2_h262_system_time_clock mpeg2_h262_system_time_clock
(
	.clk           (CLK_AUDIO),
	.reset         (stc_audio_reset),
	.run           (!(media_paused_audio || media_seeking_audio)),
	.load_valid    (1'b0),
	.load_value    (33'd0),
	.stc_90k       (),
	.tick_90k      (stc_tick_90k_audio),
	.stc_180k_half (),
	.pulse_1hz     ()
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] stc_tick_90k_sync;
wire mpeg2_new_stc_tick_90k=(stc_tick_90k_sync[2:1]==2'b01);
always @(posedge clk_mpeg2) begin
 if(reset_mpeg2) stc_tick_90k_sync<=0;
 else stc_tick_90k_sync<={stc_tick_90k_sync[1:0],stc_tick_90k_audio};
end
// Requested mode crosses coherently, then the raster applies it at frame end.
// Publish the applied mode (not the menu request) to presentation scheduling.
wire refresh_50_video_request, refresh_50_video_active, refresh_50_decoder;
video_config_cdc refresh_request_config(
 .src_clk(clk_sys),.dst_clk(clk_video),.src_data(status[6]),
 .dst_data(refresh_50_video_request));
video_config_cdc refresh_applied_config(
 .src_clk(clk_video),.dst_clk(clk_mpeg2),.src_data(refresh_50_video_active),
 .dst_data(refresh_50_decoder));

mpeg2_video_720x480p #(.ENABLE_REFRESH_SELECTION(1)) mpeg2_video_720x480p
(
	.clk      (clk_video),
	.reset    (reset_video),
	.refresh_50_request(refresh_50_video_request),
	.refresh_50_active(refresh_50_video_active),
	.h_pos    (display_h_pos),
	.v_pos    (display_v_pos),
	.pixel_en (display_pixel_en),
	.h_sync   (display_h_sync),
	.v_sync   (display_v_sync)
);

///////////////////////   NEW H.262 DECODER   ////////////////////

wire        mpeg2_new_phase1_supported;
wire        mpeg2_new_syntax_error;
wire        mpeg2_new_sequence_end_seen;
wire [13:0] mpeg2_new_horizontal_size;
wire [13:0] mpeg2_new_vertical_size;
wire [3:0]  mpeg2_new_frame_rate_code;
wire [2:0]  mpeg2_new_picture_coding_type;
wire [1:0]  mpeg2_new_intra_dc_precision;
wire        mpeg2_new_q_scale_type;
wire        mpeg2_new_intra_vlc_format;
wire        mpeg2_new_alternate_scan;
// Container timestamps accompany elementary-stream bytes in-band.
wire [32:0] mpeg2_new_inband_pts_90k;
wire        mpeg2_new_inband_valid;
// Entry 372: timestamps carried through frame ownership to the displayed frame.
wire [32:0] mpeg2_new_display_pts;
wire        mpeg2_new_display_pts_valid;
// Entry 389: timestamp-driven candidate presentation.  The scheduler exports
// only its already-stable next identity; timestamp ownership supplies the
// matching bank value and the local 90 kHz timeline decides when it is due.
wire        mpeg2_new_candidate_frame_valid;
wire        mpeg2_new_candidate_frame_scratch;
wire        mpeg2_new_candidate_scratch_bank;
wire [1:0]  mpeg2_new_candidate_frame_bank;
wire [32:0] mpeg2_new_candidate_pts;
wire        mpeg2_new_candidate_pts_valid;
wire        mpeg2_new_timestamp_candidate_active;
wire        mpeg2_new_timestamp_candidate_due;
wire [3:0]  mpeg2_new_forward_f_code_horizontal;
wire [3:0]  mpeg2_new_forward_f_code_vertical;
wire        mpeg2_new_intra_quant_matrix_default;

wire        mpeg2_new_first_picture_420_parsed;
wire        mpeg2_new_picture_420_complete;
wire [1:0]  mpeg2_new_active_frame_bank;
wire [1:0]  mpeg2_new_completed_frame_bank;
wire        mpeg2_new_reference_frame_valid;
wire [1:0]  mpeg2_new_reference_frame_bank;
wire [1:0]  mpeg2_new_previous_reference_frame_bank;
wire [7:0]  mpeg2_new_reference_promotion_count;
wire        mpeg2_new_p_macroblock_type_seen;
wire        mpeg2_new_p_forward_vector_valid;
wire signed [12:0] mpeg2_new_p_forward_vector_x;
wire signed [12:0] mpeg2_new_p_forward_vector_y;
wire        mpeg2_new_p_residual_required;
wire        mpeg2_new_p_residual_success;
wire        mpeg2_new_p_first_residual_sample_valid;
wire        mpeg2_new_p_residual_sample_valid;
wire [5:0]  mpeg2_new_p_residual_sample_index;
wire signed [15:0] mpeg2_new_p_residual_sample_value;
wire        mpeg2_new_b_motion_transport;
wire        mpeg2_new_slice_start;
wire        mpeg2_new_luma_macroblock_start;
wire        mpeg2_new_phase1_probe_error;
// kate - Commit 180 observability only.
wire        mpeg2_new_b_user_success;
wire [4:0]  mpeg2_new_slice_quantiser_scale_code;
wire [11:0] mpeg2_new_macroblock_address_increment;
wire        mpeg2_new_macroblock_quant;
wire [4:0]  mpeg2_new_macroblock_quantiser_scale_code;
wire [7:0]  mpeg2_new_slice_vertical_position;
wire [2:0]  mpeg2_new_slice_vertical_position_extension;
wire [2:0]  mpeg2_new_qfs_block_index;
wire        mpeg2_new_qfs_block_start;
wire        mpeg2_new_qfs_write_en;
wire [5:0]  mpeg2_new_qfs_write_index;
wire signed [12:0] mpeg2_new_qfs_write_value;
wire        mpeg2_new_qfs_block_end;

wire        mpeg2_new_inverse_quant_error;
wire        mpeg2_new_inverse_quant_unsupported_matrix;
wire        mpeg2_new_iq_coeff_block_start;
wire        mpeg2_new_iq_coeff_valid;
wire [5:0]  mpeg2_new_iq_coeff_index;
wire signed [11:0] mpeg2_new_iq_coeff_value;
wire        mpeg2_new_iq_coeff_block_end;

wire        mpeg2_new_idct_complete;
wire        mpeg2_new_idct_error;
wire        mpeg2_new_idct_sample_valid;
wire [5:0]  mpeg2_new_idct_sample_index;
wire signed [15:0] mpeg2_new_idct_sample_value;

wire        mpeg2_new_recon_pixel_valid;
wire [1:0]  mpeg2_new_recon_pixel_component;
wire [11:0] mpeg2_new_recon_pixel_x;
wire [11:0] mpeg2_new_recon_pixel_y;
wire [7:0]  mpeg2_new_recon_pixel_value;
wire        mpeg2_new_recon_block_start;
wire        mpeg2_new_recon_block_complete;
wire        mpeg2_new_recon_error;

wire        mpeg2_new_ddr_block_stored;
wire        mpeg2_new_ddr_store_error;

wire [7:0]  mpeg2_new_ddr_wr_burstcnt;
wire [28:0] mpeg2_new_ddr_wr_addr;
wire        mpeg2_new_ddr_wr_rd;
wire [63:0] mpeg2_new_ddr_wr_din;
wire [7:0]  mpeg2_new_ddr_wr_be;
wire        mpeg2_new_ddr_wr_we;
wire        mpeg2_new_ddr_writer_busy;

wire [7:0]  mpeg2_new_ddr_rd_burstcnt;
wire [28:0] mpeg2_new_ddr_rd_addr;
wire [28:0] mpeg2_new_ddr_rd_banked_addr;
wire        mpeg2_new_ddr_rd;
wire        mpeg2_new_ddr_reader_busy;
wire        mpeg2_new_ddr_reader_dout_ready;

wire [7:0]  mpeg2_new_pred_burstcnt;
wire [28:0] mpeg2_new_pred_addr;
wire        mpeg2_new_pred_rd;
wire        mpeg2_new_pred_busy;
wire        mpeg2_new_pred_dout_ready;

wire mpeg2_new_colour_description_valid;
wire [7:0] mpeg2_new_matrix_coefficients;
wire        mpeg2_new_pred_persisted_seen;
wire        mpeg2_new_pred_row_persisted;
wire        mpeg2_new_pred_error;

wire        mpeg2_new_p_store_select;
wire [7:0]  mpeg2_new_p_store_pixel_value;
wire [11:0] mpeg2_new_p_store_pixel_x;
wire [11:0] mpeg2_new_p_store_pixel_y;
wire        mpeg2_new_p_store_pixel_valid;
wire        mpeg2_new_p_store_block_start;
wire        mpeg2_new_p_store_block_complete;
reg         mpeg2_new_b_decode_scratch_bank;

wire        mpeg2_new_ddr_cache_error;

wire [4:0] mpeg2_new_effective_quantiser_scale_code =
	mpeg2_new_macroblock_quant ?
		mpeg2_new_macroblock_quantiser_scale_code :
		mpeg2_new_slice_quantiser_scale_code;

wire mpeg2_new_phase1n_frame_geometry_supported =
	(mpeg2_new_horizontal_size != 14'd0) &&
	(mpeg2_new_vertical_size   != 14'd0) &&
	(mpeg2_new_horizontal_size <= 14'd720) &&
	(mpeg2_new_vertical_size   <= 14'd480);

mpeg2_h262_frontend mpeg2_h262_frontend
(
	.clk                              (clk_mpeg2),
	.reset                            (reset_mpeg2),
	.stream_data                      (mpeg2_stream_data),
	.stream_valid                     (mpeg2_new_decode_stream_valid),
	.frontend_ready                   (),
	.phase1_supported                 (mpeg2_new_phase1_supported),
	.syntax_error                     (mpeg2_new_syntax_error),
	.syntax_error_source              (),
	.sequence_seen                    (),
	.sequence_extension_seen          (),
	.sequence_scalable_extension_seen (),
	.picture_seen                     (),
	.picture_coding_extension_seen    (),
	.slice_seen                       (),
	.sequence_end_seen                (mpeg2_new_sequence_end_seen),
	.horizontal_size                  (mpeg2_new_horizontal_size),
	.vertical_size                    (mpeg2_new_vertical_size),
	.aspect_ratio_information         (),
    .colour_description_valid(mpeg2_new_colour_description_valid),
    .matrix_coefficients(mpeg2_new_matrix_coefficients),
	.frame_rate_code                  (mpeg2_new_frame_rate_code),
	.profile_and_level_indication     (),
	.progressive_sequence             (),
	.chroma_format                    (),
	.temporal_reference               (),
	.picture_coding_type              (mpeg2_new_picture_coding_type),
	.intra_dc_precision               (mpeg2_new_intra_dc_precision),
	.picture_structure                (),
	.frame_pred_frame_dct             (),
	.concealment_motion_vectors       (),
	.q_scale_type                     (mpeg2_new_q_scale_type),
	.intra_vlc_format                 (mpeg2_new_intra_vlc_format),
	.alternate_scan                   (mpeg2_new_alternate_scan),
	.progressive_frame                (),
	.top_field_first                  (),
	.repeat_first_field               (),
	.forward_f_code_horizontal        (mpeg2_new_forward_f_code_horizontal),
	.forward_f_code_vertical          (mpeg2_new_forward_f_code_vertical),
	.backward_f_code_horizontal       (),
	.backward_f_code_vertical         (),
	.motion_f_code_seen               (),
	.intra_quant_matrix_default       (mpeg2_new_intra_quant_matrix_default)
);

wire [41:0] shared_residual_idct_requests;
wire [49:0] shared_residual_idct_responses;
mpeg2_h262_two_picture_probe #(.EXTERNAL_IDCT(1)) mpeg2_h262_two_picture_probe
(
 .external_idct_requests(shared_residual_idct_requests),
 .external_idct_responses(shared_residual_idct_responses),
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.stream_data                 (mpeg2_stream_data),
	.stream_valid                (mpeg2_new_decode_stream_valid),
	.stream_ready                (mpeg2_new_decoder_stream_ready),
	.phase1_supported            (mpeg2_new_phase1_supported),
	.vertical_size               (mpeg2_new_vertical_size),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.intra_vlc_format            (mpeg2_new_intra_vlc_format),
	.pipeline_block_done         (mpeg2_new_ddr_block_stored),
	.recon_block_complete        (mpeg2_new_recon_block_complete),
	.p_persistence_complete      (mpeg2_new_pred_persisted_seen),
	.p_row_persistence_complete  (mpeg2_new_pred_row_persisted),
	.slice_header_seen           (),
	.macroblock_address_seen     (),
	.first_i_macroblock_seen     (),
	.first_luma_dc_seen          (),
	.first_luma_block_complete   (),
	.first_picture_420_parsed    (mpeg2_new_first_picture_420_parsed),
	.second_picture_420_parsed   (),
	.picture_420_complete        (mpeg2_new_picture_420_complete),
	.active_frame_bank           (mpeg2_new_active_frame_bank),
	.completed_frame_bank        (mpeg2_new_completed_frame_bank),
	.picture_count               (),
	.reference_frame_valid       (mpeg2_new_reference_frame_valid),
	.reference_frame_bank        (mpeg2_new_reference_frame_bank),
	.previous_reference_frame_bank(mpeg2_new_previous_reference_frame_bank),
	.reference_promotion_count   (mpeg2_new_reference_promotion_count),
	.p_macroblock_type_seen      (mpeg2_new_p_macroblock_type_seen),
	.p_forward_vector_valid      (mpeg2_new_p_forward_vector_valid),
	.p_forward_vector_x          (mpeg2_new_p_forward_vector_x),
	.p_forward_vector_y          (mpeg2_new_p_forward_vector_y),
	.p_residual_required         (mpeg2_new_p_residual_required),
	.p_residual_success          (mpeg2_new_p_residual_success),
	.p_first_residual_sample_valid(mpeg2_new_p_first_residual_sample_valid),
	.p_first_residual_sample_value(),
	.p_residual_sample_valid     (mpeg2_new_p_residual_sample_valid),
	.p_residual_sample_index     (mpeg2_new_p_residual_sample_index),
	.p_residual_sample_value     (mpeg2_new_p_residual_sample_value),
	.b_motion_transport          (mpeg2_new_b_motion_transport),
	.probe_error                 (mpeg2_new_phase1_probe_error),
	.probe_error_source          (),
	.p_probe_error_source        (),
	.p_progress_detail           (),
	.publication_error_detail    (),
	.p_wide_probe_error_detail   (),
	.b_user_success              (mpeg2_new_b_user_success),
	.quantiser_scale_code        (mpeg2_new_slice_quantiser_scale_code),
	.macroblock_address_increment(mpeg2_new_macroblock_address_increment),
	.macroblock_quant            (mpeg2_new_macroblock_quant),
	.macroblock_quantiser_scale_code(mpeg2_new_macroblock_quantiser_scale_code),
	.slice_vertical_position     (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension(mpeg2_new_slice_vertical_position_extension),
	.first_luma_dc_size          (),
	.first_luma_dc_differential  (),
	.first_luma_dc_coefficient   (),
	.first_luma_ac_nonzero_count (),
	.first_luma_last_coeff_index (),
	.first_luma_last_ac_level    (),
	.slice_start                 (mpeg2_new_slice_start),
	.luma_macroblock_start       (mpeg2_new_luma_macroblock_start),
	.qfs_block_index             (mpeg2_new_qfs_block_index),
	.qfs_block_start             (mpeg2_new_qfs_block_start),
	.qfs_write_en                (mpeg2_new_qfs_write_en),
	.qfs_write_index             (mpeg2_new_qfs_write_index),
	.qfs_write_value             (mpeg2_new_qfs_write_value),
	.qfs_block_end               (mpeg2_new_qfs_block_end)
);

mpeg2_h262_inverse_quant mpeg2_h262_inverse_quant
(
	.clk                         (clk_mpeg2),
	.reset                       (reset_mpeg2),
	.block_start                 (mpeg2_new_qfs_block_start),
	.coeff_write_en              (mpeg2_new_qfs_write_en),
	.coeff_write_index           (mpeg2_new_qfs_write_index),
	.coeff_write_value           (mpeg2_new_qfs_write_value),
	.block_end                   (mpeg2_new_qfs_block_end),
	.intra_quant_matrix_default  (mpeg2_new_intra_quant_matrix_default),
	.intra_dc_precision          (mpeg2_new_intra_dc_precision),
	.quantiser_scale_code        (mpeg2_new_effective_quantiser_scale_code),
	.q_scale_type                (mpeg2_new_q_scale_type),
	.alternate_scan              (mpeg2_new_alternate_scan),
	.block_complete              (),
	.iq_error                    (mpeg2_new_inverse_quant_error),
	.unsupported_matrix          (mpeg2_new_inverse_quant_unsupported_matrix),
	.first_luma_f00              (),
	.first_luma_f77              (),
	.coeff_out_block_start       (mpeg2_new_iq_coeff_block_start),
	.coeff_out_valid             (mpeg2_new_iq_coeff_valid),
	.coeff_out_index             (mpeg2_new_iq_coeff_index),
	.coeff_out_value             (mpeg2_new_iq_coeff_value),
	.coeff_out_block_end         (mpeg2_new_iq_coeff_block_end)
);

wire [74:0] shared_idct_responses;
assign shared_residual_idct_responses=shared_idct_responses[74:25];
assign {mpeg2_new_idct_complete,mpeg2_new_idct_error,mpeg2_new_idct_sample_valid,
 mpeg2_new_idct_sample_index,mpeg2_new_idct_sample_value}=shared_idct_responses[24:0];
mpeg2_h262_shared_idct shared_idct(
 .clk(clk_mpeg2),.reset(reset_mpeg2),
 .requests({shared_residual_idct_requests,mpeg2_new_iq_coeff_block_start,
  mpeg2_new_iq_coeff_valid,mpeg2_new_iq_coeff_index,mpeg2_new_iq_coeff_value,
  mpeg2_new_iq_coeff_block_end}),.responses(shared_idct_responses)
);

mpeg2_h262_intra_recon mpeg2_h262_intra_recon
(
	.clk                                (clk_mpeg2),
	.reset                              (reset_mpeg2),
	.horizontal_size                    (mpeg2_new_horizontal_size),
	.vertical_size                      (mpeg2_new_vertical_size),
	.slice_vertical_position            (mpeg2_new_slice_vertical_position),
	.slice_vertical_position_extension  (mpeg2_new_slice_vertical_position_extension),
	.macroblock_address_increment       (mpeg2_new_macroblock_address_increment),
	.slice_start                        (mpeg2_new_slice_start),
	.macroblock_start                   (mpeg2_new_luma_macroblock_start),
	.block_index                        (mpeg2_new_qfs_block_index),
	.sample_valid                       (mpeg2_new_idct_sample_valid),
	.sample_index                       (mpeg2_new_idct_sample_index),
	.sample_value                       (mpeg2_new_idct_sample_value),
	.idct_block_complete                (mpeg2_new_idct_complete),
	.pixel_valid                        (mpeg2_new_recon_pixel_valid),
	.pixel_component                    (mpeg2_new_recon_pixel_component),
	.pixel_x                            (mpeg2_new_recon_pixel_x),
	.pixel_y                            (mpeg2_new_recon_pixel_y),
	.pixel_value                        (mpeg2_new_recon_pixel_value),
	.block_start                        (mpeg2_new_recon_block_start),
	.block_complete                     (mpeg2_new_recon_block_complete),
	.macroblock_420_complete            (),
	.recon_error                        (mpeg2_new_recon_error),
	.block_origin_x                     (),
	.block_origin_y                     ()
);

mpeg2_h262_ddram_store mpeg2_h262_ddram_store
(
	.clk             (clk_mpeg2),
	.reset           (reset_mpeg2),
	.frame_bank      (mpeg2_new_active_frame_bank),
	.pixel_value     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_value :
	                  mpeg2_new_recon_pixel_value),
	.pixel_component (mpeg2_new_p_store_select ?
	                  2'd0 :
	                  mpeg2_new_recon_pixel_component),
	.pixel_x         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_x :
	                  mpeg2_new_recon_pixel_x),
	.pixel_y         (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_y :
	                  mpeg2_new_recon_pixel_y),
	.pixel_valid     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_pixel_valid :
	                  mpeg2_new_recon_pixel_valid),
	.block_start     (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_start :
	                  mpeg2_new_recon_block_start),
	.block_complete  (mpeg2_new_p_store_select ?
	                  mpeg2_new_p_store_block_complete :
	                  mpeg2_new_recon_block_complete),
	.block_stored    (mpeg2_new_ddr_block_stored),
	.write_seen      (),
	.store_error     (mpeg2_new_ddr_store_error),
	.ddram_busy      (mpeg2_new_ddr_writer_busy),
	.ddram_burstcnt  (mpeg2_new_ddr_wr_burstcnt),
	.ddram_addr      (mpeg2_new_ddr_wr_addr),
	.ddram_rd        (mpeg2_new_ddr_wr_rd),
	.ddram_din       (mpeg2_new_ddr_wr_din),
	.ddram_be        (mpeg2_new_ddr_wr_be),
	.ddram_we        (mpeg2_new_ddr_wr_we)
);

