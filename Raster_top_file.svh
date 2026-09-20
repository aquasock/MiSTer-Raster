// Mounted-file sector reads leave stock Main's menu polling responsive.
wire [1:0] media_img_mounted;
wire [63:0] media_img_size;
wire [31:0] media_sd_lba[2];
wire [5:0] media_sd_blocks[2];
wire [1:0] media_sd_rd,media_sd_ack,media_host_rd,media_reader_wr;
wire [12:0] media_sd_addr;
wire [15:0] media_sd_data;
wire [15:0] media_sd_unused[2];
assign media_sd_unused[0]=16'd0;
assign media_sd_unused[1]=16'd0;
wire media_sd_wr;
wire [8:0] media_stream_data,media_fifo_data;
wire [14:0] media_fifo_used;
wire [15:0] media_fifo_occupancy=mpeg2_stream_full ? 16'd32768 : {1'b0,media_fifo_used};
wire media_stream_valid,media_reader_idle;
wire media_prefill_mpeg,media_fatal_sys,media_reader_error_mpeg;
reg media_prefill=0;
wire media_reader_cancel,media_fifo_reset,media_reader_start;
wire media_decoder_reset,media_quiesce,media_ddr_idle;
wire [63:0] media_byte_position;
wire [31:0] media_generation;
wire [3:0] media_error;
reg media_mount_d=0,media_user_reset_d=0;
wire [63:0] media_file_size,media_file_base;
reg [63:0] media_mount_size=0;
wire playlist_scan_busy,playlist_scan_cancel,playlist_scan_start,playlist_stream_ready,playlist_selected;
wire playlist_active,playlist_error;
wire [7:0] playlist_track,playlist_count;
wire [63:0] playlist_scan_offset,playlist_scan_end,playlist_subtitle_base,playlist_subtitle_size;
wire subtitle_archive;
wire [31:0] media_host_lba[2];
wire [5:0] media_host_blocks[2];
wire [1:0] media_host_ack;
wire media_user_reset=status[0] | buttons[1];
wire media_eof_close,media_video_eof_close;
// Movie session and DDR ownership are independent of the file selector.
// A future TAR controller can supply member boundaries through the reader
// without changing decoder drain/restart or presentation timing.
wire media_movie_ddr_idle;
wire media_duration_known;
wire [28:0] movie_mem_addr;
wire [63:0] movie_mem_data;
wire [7:0] movie_mem_be,movie_mem_burst;
wire movie_mem_read,movie_mem_write;
assign media_ddr_idle=media_movie_ddr_idle;
assign media_eof_close=media_video_eof_close&&!playlist_active;
