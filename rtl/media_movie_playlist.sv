// GPL-2.0-or-later. Phosphor-style USTAR/M3U selection above movie sessions.
// Scan bounded headers and the M3U only; never stream movie payloads to index.
module media_movie_playlist(
 input wire clk,reset,open,input wire [63:0] mounted_size,
 input wire metadata_clk,input wire [12:0] metadata_address,output wire [7:0] metadata_data,
 input wire completed,osd_open,input wire [10:0] key,
 input wire reader_idle,input wire [3:0] reader_error,
 input wire [8:0] stream_data,input wire stream_valid,
 output wire scan_busy,scan_cancel,stream_ready,
 output reg scan_start=0,output reg [63:0] scan_offset=0,scan_end=0,
 output reg selected=0,output reg [63:0] movie_base=0,movie_size=0,
 output reg [63:0] subtitle_base=0,subtitle_size=0,
 output reg playlist_active=0,output reg [7:0] track=0,count=0,
 output reg error=0
);
 localparam IDLE=0,DRAIN=1,START_HEADER=2,HEADER=3,HEADER_END=4,
            START_M3U=5,M3U=6,M3U_END=7,RESOLVE=8,RESOLVE_WAIT=9,
            PICK_WAIT=10,PICK=11,PLAY=12,FAILED=13;
 reg [3:0] state=IDLE;
 reg [63:0] archive_size=0,header_offset=0,next_header=0;
 reg first_header=1,m3u_seen=0;
 reg [31:0] prefix=0;reg [9:0] header_bytes=0;
 reg header_reset=1,m3u_begin=0;
 wire header_done,header_empty,header_error,header_ustar;
 wire [2:0] header_kind;wire [40:0] header_size;
 wire [31:0] header_hash,header_stem;wire [6:0] header_length;
 wire take=stream_valid&&stream_ready;
 wire metadata_ready,metadata_input_ready;
 media_movie_metadata metadata(.clk(clk),.reset(reset||open),.begin_file(m3u_begin),
  .byte_valid(take&&state==M3U),.byte_eof(stream_data[8]),.byte_data(stream_data[7:0]),
  .input_ready(metadata_input_ready),.ready(metadata_ready),
  .read_clk(metadata_clk),.read_address(metadata_address),.read_data(metadata_data));
 wire [63:0] payload=header_offset+64'd512;
 wire [63:0] payload_end=payload+{23'd0,header_size};
 wire [63:0] padded_end=payload+(({23'd0,header_size}+64'd511)&~64'd511);
 wire is_movie=header_kind==1,is_srt=header_kind==2;
 wire header_publish=state==HEADER_END&&!header_error&&!header_empty&&payload_end<=archive_size;
 reg [7:0] movie_count=0,srt_count=0;
 wire m3u_write,m3u_ready,m3u_error;wire [7:0] m3u_address,m3u_count;
 wire [31:0] m3u_hash,m3u_stem;wire [6:0] m3u_length;
 wire resolve_start=state==RESOLVE;
 wire movie_write,movie_done,movie_ready,movie_error,srt_write,srt_done,srt_ready,srt_error;
 wire [7:0] movie_address,srt_address;
 wire [40:0] resolved_movie_base,resolved_movie_size,resolved_srt_base,resolved_srt_size;
 (* ramstyle="M10K" *) reg [81:0] movies[0:255],subtitles[0:255];
 reg [81:0] movie_q=0,srt_q=0;
 reg movie_resolved=0,srt_resolved=0;
 reg key_toggle=0,n_down=0,p_down=0;
 wire next_key=key_toggle!=key[10]&&key[9]&&key[8:0]==9'h031&&!n_down&&!osd_open;
 wire prev_key=key_toggle!=key[10]&&key[9]&&key[8:0]==9'h04d&&!p_down&&!osd_open;
 assign scan_busy=state!=IDLE&&state!=PLAY;
 assign scan_cancel=open||state==DRAIN||state==FAILED;
 assign stream_ready=state==HEADER||(state==M3U&&metadata_input_ready);
 media_tar_header header(.clk(clk),.reset(reset||open||header_reset),
  .valid(take&&state==HEADER&&!stream_data[8]),.data(stream_data[7:0]),
  .done(header_done),.empty(header_empty),.error(header_error),.ustar(header_ustar),
  .kind(header_kind),.size(header_size),.name_hash(header_hash),.stem_hash(header_stem),.name_length(header_length));
 media_m3u_index m3u(.clk(clk),.reset(reset||open),.begin_file(m3u_begin),
  .byte_valid(take&&state==M3U),.byte_data(stream_data[7:0]),.byte_eof(stream_data[8]),
  .entry_write(m3u_write),.entry_address(m3u_address),.entry_hash(m3u_hash),.entry_stem_hash(m3u_stem),
  .entry_length(m3u_length),.entry_count(m3u_count),.ready(m3u_ready),.error(m3u_error));
 media_playlist_resolver movie_resolver(.clk(clk),.reset(reset||open),
  .audio_write(header_publish&&is_movie&&movie_count!=255),.audio_address(movie_count),
  .audio_hash(header_hash),.audio_length(header_length),.audio_kind(3'd1),
  .audio_offset(payload[40:0]),.audio_size(header_size),.audio_count(movie_count),
  .m3u_write(m3u_write),.m3u_address(m3u_address),.m3u_hash(m3u_hash),.m3u_length(m3u_length),.m3u_count(m3u_count),.start(resolve_start),
  .playlist_write(movie_write),.playlist_address(movie_address),.playlist_kind(),
  .playlist_offset(resolved_movie_base),.playlist_size(resolved_movie_size),.done(movie_done),.ready(movie_ready),.error(movie_error));
 media_playlist_resolver #(.OPTIONAL(1)) subtitle_resolver(.clk(clk),.reset(reset||open),
  .audio_write(header_publish&&is_srt&&srt_count!=255),.audio_address(srt_count),
  .audio_hash(header_stem),.audio_length(header_length-7'd4),.audio_kind(3'd2),
  .audio_offset(payload[40:0]),.audio_size(header_size),.audio_count(srt_count),
  .m3u_write(m3u_write),.m3u_address(m3u_address),.m3u_hash(m3u_stem),.m3u_length(m3u_length-7'd4),.m3u_count(m3u_count),.start(resolve_start),
  .playlist_write(srt_write),.playlist_address(srt_address),.playlist_kind(),
  .playlist_offset(resolved_srt_base),.playlist_size(resolved_srt_size),.done(srt_done),.ready(srt_ready),.error(srt_error));
 always @(posedge clk)begin
  if(movie_write)movies[movie_address]<={resolved_movie_base,resolved_movie_size};
  if(srt_write)subtitles[srt_address]<={resolved_srt_base,resolved_srt_size};
  movie_q<=movies[track];srt_q<=subtitles[track];
  key_toggle<=key[10];
  if(key_toggle!=key[10])begin
   if(key[8:0]==9'h031)n_down<=key[9];
   if(key[8:0]==9'h04d)p_down<=key[9];
  end
  selected<=0;scan_start<=0;m3u_begin<=0;
  if(reset||open)begin
   state<=open?DRAIN:IDLE;archive_size<=mounted_size;header_offset<=0;next_header<=0;
   movie_base<=0;movie_size<=0;subtitle_base<=0;subtitle_size<=0;
   playlist_active<=0;track<=0;count<=0;movie_count<=0;srt_count<=0;
   first_header<=1;m3u_seen<=0;header_reset<=1;prefix<=0;header_bytes<=0;error<=0;
   movie_resolved<=0;srt_resolved<=0;
   if(reset)begin n_down<=0;p_down<=0;end
  end else begin
   case(state)
    IDLE:;
    DRAIN:if(reader_idle)begin
     if(archive_size==0||archive_size>64'h1ffffffffff)begin error<=1;state<=FAILED;end
     else state<=START_HEADER;
    end
    START_HEADER:if(reader_idle)begin
     if(header_offset+64'd512>archive_size&&!first_header)begin error<=1;state<=FAILED;end
     else begin
      scan_offset<=header_offset;scan_end<=header_offset+64'd512>archive_size?archive_size:header_offset+64'd512;
      header_reset<=0;prefix<=0;header_bytes<=0;scan_start<=1;state<=HEADER;
     end
    end
    HEADER:if(take)begin
     if(!stream_data[8])begin
      if(header_bytes<4)prefix<={prefix[23:0],stream_data[7:0]};
      header_bytes<=header_bytes+1'b1;
     end else state<=HEADER_END;
    end
    HEADER_END:begin
     if(first_header&&(prefix==32'h000001ba||prefix==32'h000001b3))begin
      movie_base<=0;movie_size<=archive_size;selected<=1;state<=PLAY;
     end else if(!header_done||header_error)begin error<=1;state<=FAILED;end
     else if(header_empty)begin
      if(!m3u_seen||!m3u_ready||m3u_error||movie_count==0)begin error<=1;state<=FAILED;end
      else state<=RESOLVE;
     end else if(payload_end>archive_size||padded_end>archive_size||
                 ((is_movie||is_srt||header_kind==7)&&header_size==0)||
                 (is_movie&&movie_count==255)||(is_srt&&srt_count==255))begin error<=1;state<=FAILED;end
     else begin
      first_header<=0;next_header<=padded_end;
      if(is_movie)movie_count<=movie_count+1'b1;
      if(is_srt)srt_count<=srt_count+1'b1;
      if(header_kind==7)begin
       if(m3u_seen||header_size>41'd65536)begin error<=1;state<=FAILED;end
       else begin m3u_seen<=1;m3u_begin<=1;scan_offset<=payload;scan_end<=payload_end;state<=START_M3U;end
      end else begin header_offset<=padded_end;header_reset<=1;state<=DRAIN;end
     end
    end
    START_M3U:if(reader_idle)begin scan_start<=1;state<=M3U;end
    M3U:if(take&&stream_data[8])state<=M3U_END;
    M3U_END:if(m3u_ready&&metadata_ready)begin
     if(m3u_error||m3u_count==0)begin error<=1;state<=FAILED;end
     else begin header_offset<=next_header;header_reset<=1;state<=DRAIN;end
    end
    RESOLVE:state<=RESOLVE_WAIT;
    RESOLVE_WAIT:begin
     if(movie_done)movie_resolved<=movie_ready&&!movie_error;
     if(srt_done)srt_resolved<=srt_ready&&!srt_error;
     if((movie_done&&movie_error)||(srt_done&&srt_error))begin error<=1;state<=FAILED;end
     else if(movie_resolved&&srt_resolved)begin playlist_active<=1;count<=m3u_count;track<=0;state<=PICK_WAIT;end
    end
    PICK_WAIT:state<=PICK;
    PICK:begin
     movie_base<={23'd0,movie_q[81:41]};movie_size<={23'd0,movie_q[40:0]};
     subtitle_base<={23'd0,srt_q[81:41]};subtitle_size<={23'd0,srt_q[40:0]};
     selected<=1;state<=PLAY;
    end
    PLAY:if(playlist_active&&(completed||next_key||prev_key))begin
     if(prev_key)track<=track==0?count-1'b1:track-1'b1;
     else track<=track+1'b1==count?8'd0:track+1'b1;
     state<=PICK_WAIT;
    end else if(completed)begin movie_size<=0;subtitle_size<=0;end
    FAILED:;
    default:begin error<=1;state<=FAILED;end
   endcase
   if((state==HEADER||state==M3U)&&!scan_start&&reader_error!=0)begin error<=1;state<=FAILED;end
  end
 end
endmodule
