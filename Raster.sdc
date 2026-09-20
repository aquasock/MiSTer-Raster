derive_pll_clocks
derive_clock_uncertainty

# core specific constraints

# hps_io.video_calc publishes slowly changing video measurements to the HPS
# through a clk_sys-selected status register.  The vid_* measurements are
# produced in clk_vid/clk_100 domains and are intentionally sampled as
# telemetry rather than synchronous control data.  Cut only those established
# measurement-register -> status-register crossings; keep both clock domains
# and every other crossing fully timed.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|video_calc:video_calc|vid_*}] \
    -to   [get_keepers {*|hps_io:hps_io|video_calc:video_calc|dout[*]}]

# kate - Phase 1P CDC/reset timing closure.
#
# The 27 MHz video and 60 MHz MPEG clocks are both PLL-derived, but the
# framebuffer deliberately transfers a few control/descriptor values through
# explicit synchronizer stages.  Do not mark the entire clock domains
# asynchronous: that would hide accidental future crossings.  Cut only the
# proven first-stage CDC paths; stage 2 and all ordinary same-clock logic remain
# timed normally.

# 60 MHz memory/decoder -> 27 MHz presentation descriptor handshake.
# picture_width_mem / picture_height_mem are captured before cache_ready is
# asserted and remain stable for the displayed picture.  cache_ready itself is
# synchronized separately.  These exceptions therefore cover only the first
# sampling registers in the 27 MHz domain.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_height_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_mem[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|picture_width_r1[*]}]
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|cache_ready_r1}]

# 27 MHz presentation -> 60 MHz memory/decoder line-consumed handshake.
# kate - Phase 1S removed the old asynchronous 11-bit line-number bus.  Only the
# event toggle now crosses domains; the 60 MHz side derives source-line identity
# from a local sequential counter.  Cut only the first toggle synchronizer stage.
set_false_path \
    -from [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_rd*}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|line_done_toggle_m1}]

# kate - Phase 1S publication scheduling adds one single-bit video-domain
# blanking-window level.  It is registered in the 27 MHz domain, then sampled by
# an explicit three-stage synchronizer in the 60 MHz decoder/DDRAM domain.  Cut
# only the asynchronous source -> first synchronizer stage; later stages and the
# scheduler remain fully timed.
set_false_path \
    -from [get_keepers {*|mpeg2_new_swap_window_video}] \
    -to   [get_keepers {*|mpeg2_new_swap_window_sync[0]}]

# Asynchronous reset request sources.
# status[0] and cfg[1] are the HPS reset controls that reach reset_request;
# RESET is the external reset input.  These are intentional asynchronous
# assertion paths into the reset synchronizer registers, not synchronous data
# transfers.  Scope the exceptions to those reset chains only so no other HPS
# control path is hidden.  The synchronous stage-to-stage release paths remain
# fully timed.
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[0]}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|status[0]}] \
    -to   [get_keepers {*|reset_video_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|cfg[1]}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_keepers {*|hps_io:hps_io|cfg[1]}] \
    -to   [get_keepers {*|reset_video_sync[*]}]
set_false_path \
    -from [get_ports {RESET}] \
    -to   [get_keepers {*|reset_mpeg2_sync[*]}]
set_false_path \
    -from [get_ports {RESET}] \
    -to   [get_keepers {*|reset_video_sync[*]}]

# The framebuffer reset reaches a second async-assert/sync-deassert chain in
# the independent 27 MHz read domain.  Cut only the asynchronous transfer from
# the already-synchronized MPEG reset output into that chain.
set_false_path \
    -from [get_keepers {*|reset_mpeg2_sync[2]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# kate - Phase 1R controlled frame-bank publication uses a four-cycle reset
# request generated entirely in the 60 MHz memory/decoder domain to restart the
# framebuffer memory-side prefill state after bank 1 has been completed.  That
# request also intentionally asserts the framebuffer's existing 27 MHz
# rd_reset_sync chain asynchronously; release is still synchronized by the
# chain itself.  Treat only this new assertion boundary like the original
# reset_mpeg2_sync boundary above.  Do not cut the stage-to-stage release paths
# or any other 60 MHz -> 27 MHz logic.
set_false_path \
    -from [get_keepers {*|mpeg2_h262_b_presentation_scheduler:*|framebuffer_swap_reset_count[*]}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Entry 238: a new download resets the framebuffer memory side synchronously
# in clk_mpeg2, but the same level intentionally asserts the existing rd_clk
# reset-release synchronizer asynchronously.  Cut only that controller-to-reset
# chain boundary; release inside rd_reset_sync and all ordinary crossings stay
# fully timed.
set_false_path \
    -from [get_keepers {*|media_session_control:*|decoder_reset}] \
    -to   [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Intel documents these first-stage DCFIFO ACLR exceptions when both
# write_aclr_synch and read_aclr_synch are enabled.  The generated instance
# names include version-dependent suffixes, so match only the documented
# wraclr/rdaclr synchronizer stage-0 structure rather than the whole FIFO.
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:wraclr|dffe*a[0]}]
set_false_path -to [get_keepers {*|dcfifo:*|dcfifo_*:auto_generated|dffpipe_*:rdaclr|dffe*a[0]}]

# Configuration mailbox: data remains fixed from request through acknowledgement.
# Cut only the held bundle and first control synchronizer stages.
# RTL disables shift-RAM inference and preserves all three control registers;
# phase1p_timing.tcl requires every stage of every configuration mailbox.
set_false_path -from [get_keepers {*video_config_cdc:*|held_data[*]}] -to [get_keepers {*video_config_cdc:*|dst_data[*]}]
set_false_path -to [get_keepers {*video_config_cdc:*|req_sync[0]}]
set_false_path -to [get_keepers {*video_config_cdc:*|ack_sync[0]}]

# Asynchronous VS levels enter system-clock edge detectors through three stages.
set_false_path -to [get_keepers {*hdmi_vs_sys_sync[0]}]
set_false_path -to [get_keepers {*core_vs_sys_sync[0]}]

# Session restart levels use preserved three-stage synchronizers.
set_false_path -to [get_keepers {*|media_session_control:*|req_sync[0]}]
set_false_path -to [get_keepers {*|media_session_control:*|ack_sync[0]}]

# OSD status is observed only through a preserved system-clock synchronizer.
set_false_path -to [get_keepers {*media_osd_sync[0]}]
# Seek blanks/reinitializes scanout while reconstruction advances offscreen.
set_false_path -from [get_keepers {*video_config_cdc:playback_control_config|dst_data[35]}] -to [get_keepers {*|mpeg2_luma_framebuffer:mpeg2_luma_framebuffer|rd_reset_sync[*]}]

# Shared UI formatting advances only on scene_phase==0, every fourth HDMI
# clock. Only register-to-register paths sharing that exact enable get four
# cycles. Snapshot inputs, provider writes, publication, pixel processing and
# all output-to-compositor paths retain ordinary single-cycle timing.
set player_scene_ce_regs [get_registers {*media_ui_scene:scene|media_ui_divider:divider|*}]
foreach player_scene_name {snapshot w h scale revision state resume_state field ch hours minutes seconds time_digits subtitle_rect0 subtitle_rect1 tx ty tw th track_x0 track_x1 fill_x0 fill_x1 track_y0 track_y1 fill_y0 fill_y1 subtitle_bottom bar_height time_y fraction product multiplicand multiplier multiply_count multiply_resume product_low remaining_delta time_rounded remaining clamped_position time_operand glyph_span text_span numerator denominator div_start text_we text_addr text_data object_we object_addr object_data commit commit_epoch commit_groups commit_scale} {
    set player_scene_ce_regs [add_to_collection $player_scene_ce_regs [get_registers -nowarn "*media_ui_scene:scene|${player_scene_name}*"]]
}
set_multicycle_path -setup -end 4 -from $player_scene_ce_regs -to $player_scene_ce_regs
set_multicycle_path -hold -end 3 -from $player_scene_ce_regs -to $player_scene_ce_regs
