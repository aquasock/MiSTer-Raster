// Read-only preflight owner of the existing mounted-file reader. Cancellation
// waits for reader_idle: timeouts never recycle an outstanding Main response.
module media_duration_probe #(
 parameter [63:0] HEAD_BYTES=65536, TAIL_BYTES=4194304,
 parameter integer TIMEOUT_CYCLES=500000000
)(
 input wire clk,reset,new_file,
 input wire [63:0] file_size,
 input wire reader_idle,
 input wire [3:0] reader_error,
 input wire [8:0] stream_data,
 input wire stream_valid,
 output wire stream_ready,
 output wire busy,
 output reg reader_start=0,
 output wire reader_cancel,
 output reg [63:0] read_size=0,read_offset=0,
 output reg duration_valid=0,
 output reg [34:0] duration_q=0,
 output reg [32:0] origin=0
);
localparam IDLE=0,DRAIN=1,START_HEAD=2,HEAD=3,START_TAIL=4,TAIL=5,FINISH=6,ABORT=7;
reg [2:0] state=IDLE;
reg [31:0] timer=0;
reg head_valid=0;
reg [7:0] head_video_id=0;
reg [63:0] size=0;
wire reading=state==HEAD || state==TAIL;
assign busy=state!=IDLE || new_file;
assign reader_cancel=new_file || state==DRAIN || state==ABORT;
reg parser_reset=1;
wire parser_ready,window_valid,window_origin,window_healthy;
wire [7:0] window_video_id;
wire [32:0] first_pts;
wire [34:0] end_q;
assign stream_ready=reading && parser_ready;
media_duration_window window(
 .clk(clk),.reset(parser_reset),.in_data(stream_data[7:0]),
 .in_valid(reading && stream_valid && !stream_data[8]),.in_ready(parser_ready),
 .origin_valid((state==TAIL || state==FINISH) && head_valid),.origin(origin),
 .first_pts(first_pts),.valid(window_valid),.end_q(end_q),.have_origin(window_origin),.healthy(window_healthy),.video_stream_id(window_video_id));
always @(posedge clk) begin
 reader_start<=0;parser_reset<=0;
 if(reset) begin state<=IDLE;duration_valid<=0;head_valid<=0;parser_reset<=1;timer<=0;end
 else if(new_file) begin
  state<=DRAIN;duration_valid<=0;head_valid<=0;parser_reset<=1;timer<=0;
 end else begin
  if(busy && timer<TIMEOUT_CYCLES) timer<=timer+1'b1;
  case(state)
   IDLE: timer<=0;
   DRAIN: if(reader_idle) begin size<=file_size;state<=START_HEAD;end
   START_HEAD: begin
    if(size==0 || size>64'h20000000000) state<=ABORT;
    else begin
     read_offset<=0;read_size<=size<HEAD_BYTES?size:HEAD_BYTES;
     parser_reset<=1;reader_start<=1;state<=HEAD;
    end
   end
   HEAD: if(stream_valid && stream_ready && stream_data[8]) begin
    // The head need only establish the first video timestamp. Endpoint
    // qualification belongs to the tail and may require much more data.
    head_valid<=window_origin && window_healthy;origin<=first_pts;head_video_id<=window_video_id;state<=START_TAIL;
   end
   START_TAIL: if(reader_idle) begin
    if(!head_valid) state<=ABORT;
    else begin
     read_offset<=size>TAIL_BYTES?size-TAIL_BYTES:0;read_size<=size;
     parser_reset<=1;reader_start<=1;state<=TAIL;
    end
   end
   TAIL: if(stream_valid && stream_ready && stream_data[8]) state<=FINISH;
   FINISH: if(reader_idle) begin
    duration_valid<=window_valid && head_valid && window_video_id==head_video_id;duration_q<=end_q;state<=IDLE;
   end
   ABORT: if(reader_idle) begin state<=IDLE;parser_reset<=1;end
  endcase
  if((reading && !reader_start && reader_error!=0) || (busy && state!=ABORT && timer>=TIMEOUT_CYCLES)) begin
   state<=ABORT;duration_valid<=0;
  end
 end
end
endmodule
