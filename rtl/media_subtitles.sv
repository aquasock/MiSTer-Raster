// Linked TAR member or manual SRT slot controller. Re-reads from zero after seeks instead of storing
// a whole-file index. All host responses drain before a new reader session.
module media_subtitles(
 input wire clk,reset,new_movie,mount,input wire [63:0] mount_size,
 input wire auto_load,input wire [63:0] auto_base,auto_size,output reg archive_source=0,
 input wire loaded,seeking,enabled,suspend,input wire [36:0] elapsed_q,input wire [15:0] epoch,
 output wire [31:0] sd_lba,output wire [5:0] sd_blocks,output wire sd_rd,
 input wire sd_ack,sd_wr,input wire [12:0] sd_addr,input wire [15:0] sd_data,
 output reg [34:0] command=0,input wire command_ack,
 output wire warning
);
reg associated=0,mount_d=0,seek_d=0,restart_pending=0;
reg [63:0] size=0,base=0;
reg reader_start=0;
wire reader_idle,byte_valid,byte_ready;
wire [8:0] byte_data;
wire [3:0] reader_error;
wire remount=mount && !mount_d;
wire invalidate=reset || new_movie || auto_load || remount || (seeking&&!seek_d);
wire cancel=reset || new_movie || auto_load || remount || seeking || restart_pending || !associated;
wire parse_reset=cancel;
wire cue_valid,parse_eof;
reg cue_ready=0;
wire [36:0] cue_start,cue_end;
wire [6:0] length0,length1;
reg [6:0] char_index=0;
wire [7:0] char_data;
wire active=associated && loaded && !seeking && enabled && cue_valid &&
 elapsed_q>=cue_start && elapsed_q<cue_end && reader_error==0;
always @(posedge clk)begin
 mount_d<=mount;seek_d<=seeking;reader_start<=0;
 if(reset)begin associated<=0;size<=0;base<=0;archive_source<=0;restart_pending<=0;end
 else if(auto_load)begin associated<=auto_size!=0;size<=auto_size;base<=auto_base;archive_source<=1;restart_pending<=auto_size!=0;end
 else if(new_movie)begin associated<=0;size<=0;base<=0;archive_source<=0;restart_pending<=0;end
 else if(remount)begin associated<=mount_size!=0;size<=mount_size;base<=0;archive_source<=0;restart_pending<=mount_size!=0;end
 else if(seeking && associated)restart_pending<=1;
 else if(restart_pending && reader_idle && !seeking)begin restart_pending<=0;reader_start<=1;end
end
media_file_reader reader(
 .clk(clk),.reset(reset),.start(reader_start),.cancel(cancel),.suspend(suspend),
 .file_size(size),.file_base(base),.start_offset(64'd0),.sd_lba(sd_lba),.sd_blk_cnt(sd_blocks),.sd_rd(sd_rd),
 .sd_ack(sd_ack),.sd_buff_wr(sd_wr),.sd_buff_addr(sd_addr),.sd_buff_dout(sd_data),
 .stream_data(byte_data),.stream_valid(byte_valid),.stream_ready(byte_ready),.idle(reader_idle),.error(reader_error),.byte_position(),.requests(),.completions(),.max_wait());
media_srt_parser parser(.clk(clk),.reset(parse_reset),.data(byte_data),.valid(byte_valid),.ready(byte_ready),
 .cue_valid(cue_valid),.cue_ready(cue_ready),.start_q(cue_start),.end_q(cue_end),
 .length0(length0),.length1(length1),.text_addr(char_index),.text_q(char_data),.eof(parse_eof),.warning(warning));
localparam IDLE=0,FETCH=1,WRITE=2,WAIT_TEXT=3,COMMIT=4,WAIT_COMMIT=5,WAIT_CLEAR=6;
reg [2:0] state=IDLE;
reg dirty=1,sent=0,visible=0;
reg [15:0] published_epoch=0;
wire acked=command_ack==command[34];
always @(posedge clk)begin
 cue_ready<=0;
 if(invalidate)dirty<=1;
 // Never abandon an in-flight command: the coalescing mailbox is explicitly
 // acknowledged by the consumer after applying each command.
 if(acked && dirty)begin
  command<={~command[34],epoch,2'd1,16'd0};
  state<=WAIT_CLEAR;sent<=0;visible<=0;published_epoch<=epoch;
  if(!invalidate)dirty<=0;
 end else if(!dirty && !invalidate)case(state)
 IDLE:begin
  if(cue_valid && !sent && elapsed_q<cue_end && associated && reader_error==0)begin char_index<=0;state<=FETCH;end
  else if(visible!=active || published_epoch!=epoch)state<=COMMIT;
  else if(cue_valid && elapsed_q>=cue_end)begin cue_ready<=1;sent<=0;end
  else if(!cue_valid)sent<=0;
 end
 FETCH:state<=WRITE;
 WRITE:if(acked)begin
  command<={~command[34],epoch,2'd0,1'b0,char_index,
   ((char_index[6]?{1'b0,char_index[5:0]}<length1:{1'b0,char_index[5:0]}<length0)?char_data:8'd0)};
  state<=WAIT_TEXT;
 end
 WAIT_TEXT:if(acked)begin
  if(char_index==127)state<=COMMIT;else begin char_index<=char_index+1'b1;state<=FETCH;end
 end
 COMMIT:if(acked)begin
  command<={~command[34],epoch,2'd1,1'b0,length1,active,length0};
  visible<=active;published_epoch<=epoch;sent<=cue_valid;state<=WAIT_COMMIT;
 end
 WAIT_COMMIT:if(acked)state<=IDLE;
 WAIT_CLEAR:if(acked)state<=IDLE;
 default:state<=IDLE;
 endcase
end
endmodule
