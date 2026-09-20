// kate - Phase 1T-o: the controlled pattern-only P macroblock has no explicit
// forward vector. Once its complete first-Y0 transform is available, the
// prediction client reconstructs the full 8x8 luma block from real reference
// rows plus the 64 live residual samples, emits it through the ordinary DDR
// block writer, and verifies all eight destination row words by readback.
wire mpeg2_new_phase1t_implicit_reconstruct_required =
    mpeg2_new_p_residual_required &&
    mpeg2_new_p_residual_success &&
    mpeg2_new_p_first_residual_sample_valid &&
    !mpeg2_new_p_forward_vector_valid;

mpeg2_h262_reference_read_probe mpeg2_h262_reference_read_probe
(
    .clk                       (clk_mpeg2),
    .reset                     (reset_mpeg2),
    // kate - Phase 1T-y: connect live coded horizontal geometry at top level.
    .horizontal_size           (mpeg2_new_horizontal_size),
    // kate - Phase 1U-c: connect live coded vertical geometry at top level.
    .vertical_size             (mpeg2_new_vertical_size),
    .p_vector_proof_seen       (mpeg2_new_p_macroblock_type_seen),
    .p_forward_vector_valid    (mpeg2_new_p_forward_vector_valid),
    .p_forward_vector_x        (mpeg2_new_p_forward_vector_x),
    .p_forward_vector_y        (mpeg2_new_p_forward_vector_y),
    .forward_f_code_horizontal (mpeg2_new_forward_f_code_horizontal),
    .forward_f_code_vertical   (mpeg2_new_forward_f_code_vertical),
    .p_implicit_reconstruct_request(mpeg2_new_phase1t_implicit_reconstruct_required),
    .p_residual_sample_valid   (mpeg2_new_p_residual_sample_valid),
    .p_residual_sample_index   (mpeg2_new_p_residual_sample_index),
    .p_residual_sample_value   (mpeg2_new_p_residual_sample_value),
    .b_motion_transport        (mpeg2_new_b_motion_transport),
    .reference_frame_valid     (mpeg2_new_reference_frame_valid),
    .reference_frame_bank      (mpeg2_new_reference_frame_bank),
    .previous_reference_frame_bank(mpeg2_new_previous_reference_frame_bank),
    .destination_frame_bank    (mpeg2_new_active_frame_bank),
    .b_scratch_frame_bank      (mpeg2_new_b_decode_scratch_bank),
    .p_store_block_stored      (mpeg2_new_ddr_block_stored),
    .ddram_busy                (mpeg2_new_pred_busy),
    .ddram_dout                (DDRAM_DOUT),
    .ddram_dout_ready          (mpeg2_new_pred_dout_ready),
    .ddram_burstcnt            (mpeg2_new_pred_burstcnt),
    .ddram_addr                (mpeg2_new_pred_addr),
    .ddram_rd                  (mpeg2_new_pred_rd),
    .p_store_select            (mpeg2_new_p_store_select),
    .p_store_pixel_value       (mpeg2_new_p_store_pixel_value),
    .p_store_pixel_x           (mpeg2_new_p_store_pixel_x),
    .p_store_pixel_y           (mpeg2_new_p_store_pixel_y),
    .p_store_pixel_valid       (mpeg2_new_p_store_pixel_valid),
    .p_store_block_start       (mpeg2_new_p_store_block_start),
    .p_store_block_complete    (mpeg2_new_p_store_block_complete),
    .read_seen                 (),
    .sample_value              (),
    .sample_nonzero            (),
    .half_sample_seen          (),
    .reconstructed_seen        (),
    .reconstructed_value       (),
    .persisted_seen            (mpeg2_new_pred_persisted_seen),
    .row_persisted             (mpeg2_new_pred_row_persisted),
    .p_progress_stage          (),
    .probe_error               (mpeg2_new_pred_error),
    .probe_error_source        (),
    .probe_error_detail        ()
);

wire [1:0] mpeg2_new_display_frame_bank;
wire      mpeg2_new_display_scratch;
wire      mpeg2_new_display_scratch_bank;
wire [2:0] mpeg2_new_framebuffer_swap_reset_count;
reg       mpeg2_new_swap_window_video;
wire      mpeg2_new_b_presentation_complete;
// Promotion state participates in the functional EOF drain guard.
wire      mpeg2_new_b_promotion_active;
wire      mpeg2_new_b_presentation_error;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS" *)
reg [2:0] mpeg2_new_swap_window_sync;

always @(posedge clk_video) begin
    if (reset_video)
        mpeg2_new_swap_window_video <= 1'b0;
    else
        mpeg2_new_swap_window_video <= (display_v_pos >= 12'd480);
end

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2)
        mpeg2_new_swap_window_sync <= 3'b000;
    else
        mpeg2_new_swap_window_sync <=
            {mpeg2_new_swap_window_sync[1:0], mpeg2_new_swap_window_video};
end

wire mpeg2_new_swap_window_pulse =
    mpeg2_new_swap_window_sync[1] && !mpeg2_new_swap_window_sync[2];

wire mpeg2_new_frame_waiting =
    mpeg2_new_picture_420_complete &&
    mpeg2_new_first_picture_420_parsed &&
    (mpeg2_new_display_scratch ||
     (mpeg2_new_completed_frame_bank != mpeg2_new_display_frame_bank));

// kate - Commit 162 fixes the proven consecutive-P publication/presentation
// race without weakening Commit-142 DDR ownership protection.  After a P is
// published, accepted stream bytes are allowed to reach and classify the next
// picture header.  Only when that next picture is another P and its selected
// destination bank is still the displayed reference bank is input then parked.
// The hold releases as soon as presentation moves away from that bank.  A
// following B or I disarms the P-only gate and retains the existing B reorder
// and presentation path unchanged.
reg [31:0] mpeg2_new_p_ownership_picture_window;
reg        mpeg2_new_p_ownership_header_capture;
reg        mpeg2_new_p_ownership_header_second_byte;
reg        mpeg2_new_p_ownership_arm;
reg        mpeg2_new_p_destination_ownership_hold_reg;

wire [31:0] mpeg2_new_p_ownership_picture_window_next =
    {mpeg2_new_p_ownership_picture_window[23:0], mpeg2_stream_data};
wire mpeg2_new_p_ownership_picture_start_now =
    (mpeg2_new_p_ownership_picture_window_next == 32'h00000100);
wire mpeg2_new_picture_header_classified_now =
    mpeg2_new_decode_stream_valid &&
    mpeg2_new_p_ownership_header_capture &&
    mpeg2_new_p_ownership_header_second_byte;
wire [2:0] mpeg2_new_picture_header_type_now = mpeg2_stream_data[5:3];
wire mpeg2_new_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b011);
wire mpeg2_new_non_b_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now != 3'b011);
wire mpeg2_new_i_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b001);
wire mpeg2_new_p_picture_start_now =
    mpeg2_new_picture_header_classified_now &&
    (mpeg2_new_picture_header_type_now == 3'b010);
wire mpeg2_new_sequence_end_now =
    mpeg2_new_decode_stream_valid &&
    (mpeg2_new_p_ownership_picture_window_next == 32'h000001b7);
wire mpeg2_new_p_destination_display_owned =
    !mpeg2_new_display_scratch &&
    (mpeg2_new_active_frame_bank == mpeg2_new_display_frame_bank);
wire mpeg2_new_p_publication_now =
    mpeg2_new_picture_420_complete &&
    (mpeg2_new_picture_coding_type == 3'b010);

assign mpeg2_new_p_destination_ownership_hold =
    mpeg2_new_p_destination_ownership_hold_reg;

wire mpeg2_new_b_reference_overlap_header;

always @(posedge clk_mpeg2) begin
    if (reset_mpeg2) begin
        mpeg2_new_p_ownership_picture_window      <= 32'd0;
        mpeg2_new_p_ownership_header_capture      <= 1'b0;
        mpeg2_new_p_ownership_header_second_byte  <= 1'b0;
        mpeg2_new_p_ownership_arm                 <= 1'b0;
        mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;
    end
    else begin
        if (mpeg2_new_p_destination_ownership_hold_reg &&
            !mpeg2_new_p_destination_display_owned)
            mpeg2_new_p_destination_ownership_hold_reg <= 1'b0;

        if (mpeg2_new_p_publication_now)
            mpeg2_new_p_ownership_arm <= 1'b1;

        if (mpeg2_new_decode_stream_valid) begin
            mpeg2_new_p_ownership_picture_window <=
                mpeg2_new_p_ownership_picture_window_next;

            if (mpeg2_new_p_ownership_picture_start_now) begin
                mpeg2_new_p_ownership_header_capture     <= 1'b1;
                mpeg2_new_p_ownership_header_second_byte <= 1'b0;
            end
            else if (mpeg2_new_p_ownership_header_capture) begin
                if (!mpeg2_new_p_ownership_header_second_byte) begin
                    mpeg2_new_p_ownership_header_second_byte <= 1'b1;
                end
                else begin
                    mpeg2_new_p_ownership_header_capture     <= 1'b0;
                    mpeg2_new_p_ownership_header_second_byte <= 1'b0;

                    if (mpeg2_new_p_ownership_arm ||
                        mpeg2_new_b_reference_overlap_header) begin
                        mpeg2_new_p_ownership_arm <= 1'b0;
                        if ((mpeg2_stream_data[5:3] == 3'b010) &&
                            mpeg2_new_p_destination_display_owned)
                            mpeg2_new_p_destination_ownership_hold_reg <= 1'b1;
                    end
                end
            end
        end
    end
end

// Entry 206: every accepted picture header produces an explicit event, so two
// adjacent B headers cannot collapse into one coding-type level.  The scheduler
// alternates two scratch frames and owns the complete B...B->future-reference
// presentation transaction, including fail-open error retirement.
wire mpeg2_new_pending_frame_valid,mpeg2_new_reorder_active;
mpeg2_h262_picture_timestamp mpeg2_h262_picture_timestamp
(
    .clk                     (clk_mpeg2),
    .reset                   (reset_mpeg2),
    .metadata_valid          (av_is_ps ? av_picture_pts_valid : mpeg2_new_inband_valid),
    .metadata_pts            (av_is_ps ? av_picture_pts : mpeg2_new_inband_pts_90k),
    .picture_start           (mpeg2_new_picture_header_classified_now),
    .picture_is_b            (mpeg2_new_b_picture_start_now),
    .decode_scratch_bank     (mpeg2_new_b_decode_scratch_bank),
    .b_picture_complete      (mpeg2_new_b_user_success),
    .active_frame_bank       (mpeg2_new_active_frame_bank),
    .display_frame_bank      (mpeg2_new_display_frame_bank),
    .display_scratch         (mpeg2_new_display_scratch),
    .display_scratch_bank    (mpeg2_new_display_scratch_bank),
    .candidate_frame_valid   (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank  (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank    (mpeg2_new_candidate_frame_bank),
    .display_pts             (mpeg2_new_display_pts),
    .display_pts_valid       (mpeg2_new_display_pts_valid),
    .candidate_pts           (mpeg2_new_candidate_pts),
    .candidate_pts_valid     (mpeg2_new_candidate_pts_valid),
    .associated_count        ()
);

wire media_scheduler_window,media_fast_seek,media_rebase;
wire [32:0] media_seek_elapsed;
wire media_seek_drained=mpeg2_new_sequence_end_seen &&
 !mpeg2_new_frame_waiting && !mpeg2_new_candidate_frame_valid &&
 !mpeg2_new_pending_frame_valid &&
 !mpeg2_new_reorder_active &&
 !mpeg2_new_b_presentation_hold && !mpeg2_new_p_destination_ownership_hold;
// These are decoder/presentation completion signals, not video raster reads:
// scanout keeps reading the final displayed frame until the safe reset path.
wire media_eof_video_drained=media_seek_drained && mpeg2_new_b_presentation_complete &&
 !mpeg2_new_b_promotion_active && mpeg2_new_framebuffer_swap_reset_count==0 &&
 mpeg2_stream_empty && !mpeg2_new_decode_stream_valid &&
 !mpeg2_new_pred_rd && !mpeg2_new_ddr_wr_we;
media_eof_control eof_control(
 .clk_sys(clk_sys),.clk_mpeg2(clk_mpeg2),.reset_sys(RESET),.reset_decoder(reset_mpeg2),
 .new_file(media_new_file),.loaded(media_file_size!=0 && !playlist_scan_busy),
 .sys_paused(media_paused_sys),.sys_seeking(media_seek_sys),
 .preflight(media_duration_busy),.generation(media_generation),
 .input_eof(media_eof_seen && mpeg2_ingress_end),.video_drained(media_eof_video_drained),
 .audio_finished(!av_is_ps || mp2_finished_sync[2]),.paused(media_paused),.seeking(media_seeking),
 .fatal(mpeg2_new_transport_fatal_error),.tick_90k(mpeg2_new_stc_tick_90k),
 .frame_rate_code(mpeg2_new_frame_rate_code),.close_file(media_video_eof_close));

media_playback_control #(.ENABLE_MOVIE_ORIGIN(1)) media_playback_control(
 .clk(clk_mpeg2),.reset(reset_mpeg2),.paused(media_paused),.seek_active(media_seeking),
 .movie_origin_valid(media_movie_origin_valid),.movie_origin(media_movie_origin),
 .seek_target_q(media_target_q),.frame_rate_code(mpeg2_new_frame_rate_code),
 .swap_reset_count(mpeg2_new_framebuffer_swap_reset_count),
 .first_picture_complete(mpeg2_new_picture_420_complete),
 .swap_window(mpeg2_new_swap_window_pulse),.drained(media_seek_drained),
 .fatal(mpeg2_new_transport_fatal_error || media_reader_error_mpeg),
 .display_pts_valid(mpeg2_new_display_pts_valid),.display_pts(mpeg2_new_display_pts),
 .elapsed_q(media_elapsed_q),.seek_done(media_seek_done),
 .scheduler_window(media_scheduler_window),.fast_seek(media_fast_seek),
 .rebase(media_rebase),.seek_elapsed_90k(media_seek_elapsed));

mpeg2_h262_pts_presentation_timeline #(.ENABLE_PLAYBACK_CONTROL(1)) mpeg2_h262_pts_presentation_timeline
(
    .clk              (clk_mpeg2),
    .reset            (reset_mpeg2),
    .tick_90k         (mpeg2_new_stc_tick_90k),
    .hold_time(media_seeking),.rebase(media_rebase),
    .rebase_pts(media_seek_pts),
    .metadata_valid   (mpeg2_new_inband_valid),
    .metadata_pts     (av_is_ps ? av_origin : mpeg2_new_inband_pts_90k),
    .candidate_valid  (mpeg2_new_candidate_pts_valid),
    .candidate_pts    (mpeg2_new_candidate_pts),
    .anchored         (),
    .stc_90k          (),
    .candidate_active (mpeg2_new_timestamp_candidate_active),
    .candidate_due    (mpeg2_new_timestamp_candidate_due)
);

mpeg2_h262_b_presentation_scheduler #(.ENABLE_REFRESH_SELECTION(1)) mpeg2_h262_b_presentation_scheduler
(
    .clk                         (clk_mpeg2),
    .reset                       (reset_mpeg2),
    .swap_window_pulse           (media_scheduler_window),
    .refresh_50                  (refresh_50_decoder),
    .frame_rate_code             (mpeg2_new_frame_rate_code),
    .timestamp_candidate_active  (media_seeking || mpeg2_new_timestamp_candidate_active),
    .timestamp_candidate_due     (media_seeking || mpeg2_new_timestamp_candidate_due),
    .frame_waiting               (mpeg2_new_frame_waiting),
    .completed_frame_bank        (mpeg2_new_completed_frame_bank),
    .reference_frame_bank        (mpeg2_new_reference_frame_bank),
    .reference_promotion_count   (mpeg2_new_reference_promotion_count),
    .b_picture_start             (mpeg2_new_b_picture_start_now),
    .non_b_picture_start         (mpeg2_new_non_b_picture_start_now),
    .i_picture_start             (mpeg2_new_i_picture_start_now),
    .p_picture_start             (mpeg2_new_p_picture_start_now),
    .sequence_end                (mpeg2_new_sequence_end_now),
    .b_user_success              (mpeg2_new_b_user_success),
    .b_decode_error              (mpeg2_new_phase1_probe_error),
    .display_frame_bank          (mpeg2_new_display_frame_bank),
    .display_scratch             (mpeg2_new_display_scratch),
    .display_scratch_bank        (mpeg2_new_display_scratch_bank),
    .decode_scratch_bank         (mpeg2_new_b_decode_scratch_bank),
    .candidate_frame_valid       (mpeg2_new_candidate_frame_valid),
    .candidate_frame_scratch     (mpeg2_new_candidate_frame_scratch),
    .candidate_scratch_bank      (mpeg2_new_candidate_scratch_bank),
    .candidate_frame_bank        (mpeg2_new_candidate_frame_bank),
    .framebuffer_swap_reset_count(mpeg2_new_framebuffer_swap_reset_count),
    .reference_overlap_header    (mpeg2_new_b_reference_overlap_header),
    .presentation_hold           (mpeg2_new_b_presentation_hold),
    .scratch_available           (),
    .promotion_active            (mpeg2_new_b_promotion_active),
    .presentation_complete       (mpeg2_new_b_presentation_complete),
    .presentation_error          (mpeg2_new_b_presentation_error),
    .debug_state                 (),
    .pending_frame_valid         (mpeg2_new_pending_frame_valid),
    .reorder_active              (mpeg2_new_reorder_active)
);

wire mpeg2_new_display_bt709;
mpeg2_h262_picture_color picture_color(
 .clk(clk_mpeg2),.reset(reset_mpeg2),
 .colour_description_valid(mpeg2_new_colour_description_valid),
 .matrix_coefficients(mpeg2_new_matrix_coefficients),
 .picture_start(mpeg2_new_picture_header_classified_now),
 .picture_is_b(mpeg2_new_b_picture_start_now),
 .decode_scratch_bank(mpeg2_new_b_decode_scratch_bank),
 .b_picture_complete(mpeg2_new_b_user_success),
 .active_frame_bank(mpeg2_new_active_frame_bank),
 .display_frame_bank(mpeg2_new_display_frame_bank),
 .display_scratch(mpeg2_new_display_scratch),
 .display_scratch_bank(mpeg2_new_display_scratch_bank),
 .display_bt709(mpeg2_new_display_bt709));
