// GPL-2.0-or-later. Phosphor playlist layout, colors and scrolling adapted for
// Raster's HDMI clock. A blanking-time formatter caches seven text rows; the
// six-stage pixel pipeline never performs title addressing or decimal math.
module media_movie_playlist_ui(
 input wire clk,enabled,input wire [7:0] track_count,current_track,
 output reg [12:0] metadata_address=0,input wire [7:0] metadata_data,
 input wire [23:0] rgb,input wire hs,vs,de,layout_de,
 output reg [23:0] rgb_out=0,output reg hs_out=0,vs_out=0,de_out=0
);
 reg [11:0] raster_x=0,y=0,width=0,height=0,left=0,top=0;
 reg zoom=0,de_d=0,vs_d=0;
 wire frame_tick=vs&&!vs_d;
 always @(posedge clk)begin
  de_d<=layout_de;vs_d<=vs;
  if(layout_de)raster_x<=raster_x+1'b1;else raster_x<=0;
  if(de_d&&!layout_de)begin width<=raster_x;y<=y+1'b1;end
  if(frame_tick)begin
   height<=y;y<=0;zoom<=height>=960&&width>=800;
   left<=width>=(height>=960&&width>=800?740:370)?(width-(height>=960&&width>=800?740:370))>>1:0;
   top<=height>=(height>=960&&width>=800?656:328)?(height-(height>=960&&width>=800?656:328))>>1:0;
  end
 end
 reg [7:0] display_start=1,playing=0,total=0,tracked_track=0;
 reg [2:0] selected_slot=0;
 reg [5:0] row_present=0;
 integer row_index;
 reg [4:0] title_length=0,album_length=0;
 reg [8:0] heading_left=89,heading_right=281;
 wire [4:0] heading_length=album_length==0?5'd16:album_length>27?5'd27:album_length;
 reg [15:0] album_scroll=0,row_scroll=0;
 wire [4:0] row_limit=title_length>27?title_length-27:0;
 wire [4:0] album_limit=album_length>27?album_length-27:0;
 function [15:0] advance_scroll;
  input [15:0] current;input [4:0] limit;
  reg [4:0] offset;reg direction;reg [3:0] pace;reg [5:0] pause;
  begin
   offset=current[4:0];direction=current[5];pace=current[9:6];pause=current[15:10];
   if(limit==0)begin offset=0;direction=0;pace=0;pause=45;end
   else if(offset>limit)begin offset=0;direction=0;pace=0;pause=45;end
   else if(pause!=0)pause=pause-1'b1;
   else if(pace==9)begin
    pace=0;
    if(!direction)begin
     if(offset>=limit)begin direction=1;pause=45;end
     else if(offset+1'b1>=limit)begin offset=limit;direction=1;pause=45;end
     else offset=offset+1'b1;
    end else if(offset<=1)begin offset=0;direction=0;pause=45;end
    else offset=offset-1'b1;
   end else pace=pace+1'b1;
   advance_scroll={pause,pace,direction,offset};
  end
 endfunction
 (* ramstyle="M10K" *) reg [7:0] text[0:255];
 reg cache_write=0;reg[7:0] cache_address=0,cache_data=0;
 always @(posedge clk)if(cache_write)text[cache_address]<=cache_data;
 localparam IDLE=0,ALBUM_WAIT=1,ALBUM_READ=2,TITLE_WAIT=3,TITLE_READ=4,
  ROW=5,ROW_INFO=6,COLUMN=7,INDEX=8,REQUEST=9,WAIT_DATA=10,READ_DATA=11,WRITE=12;
 reg [3:0] state=IDLE;
 reg [2:0] row=0;
 reg [4:0] column=0;
 reg [7:0] record=0;
 reg [5:0] source_index=0;
 reg row_valid=0,row_selected=0;
 reg [7:0] glyph=0;
 wire [127:0] default_heading="CURRENT PLAYLIST";
 always @(posedge clk)begin
  cache_write<=0;
  if(frame_tick)begin
   total<=track_count;playing<=current_track;
   if(current_track<=3||track_count<=6)display_start<=1;
   else if(current_track>track_count-3)display_start<=track_count-5;
   else display_start<=current_track-2;
   metadata_address<=13'd31;state<=ALBUM_WAIT;
   if(!enabled||tracked_track!=current_track)begin
    album_scroll<={6'd45,10'd0};row_scroll<={6'd45,10'd0};tracked_track<=current_track;
   end else begin album_scroll<=advance_scroll(album_scroll,album_limit);row_scroll<=advance_scroll(row_scroll,row_limit);end
  end else case(state)
   IDLE:;
   ALBUM_WAIT:begin
    selected_slot<=playing-display_start;
    for(row_index=0;row_index<6;row_index=row_index+1)
     row_present[row_index]<={1'b0,total}>={1'b0,display_start}+row_index;
    state<=ALBUM_READ;
   end
   ALBUM_READ:begin album_length<=metadata_data[4:0];metadata_address<={playing,5'd31};state<=TITLE_WAIT;end
   TITLE_WAIT:state<=TITLE_READ;
   TITLE_READ:begin
    title_length<=metadata_data[4:0];row<=0;state<=ROW;
    // Center the visible glyph cells, excluding the final two-pixel gap.
    heading_left<=9'd186-({4'd0,heading_length}<<2)-({4'd0,heading_length}<<1);
    heading_right<=9'd186+({4'd0,heading_length}<<2)+({4'd0,heading_length}<<1);
   end
   ROW:begin
    record<=row==0?8'd0:display_start+row-1'b1;
    column<=0;state<=ROW_INFO;
   end
   ROW_INFO:begin
    row_valid<=row==0||record<=total;row_selected<=row!=0&&record==playing;state<=COLUMN;
   end
   COLUMN:begin
    glyph<=8'h20;
    if(!row_valid)state<=WRITE;
    else if(row==0&&album_length==0)begin
     if(column<16)glyph<=default_heading[(15-column)*8+:8];state<=WRITE;
    end else if(row==0)begin source_index<={1'b0,column}+{1'b0,album_scroll[4:0]};state<=INDEX;end
    else begin source_index<={1'b0,column};state<=INDEX;end
   end
   INDEX:begin
    if(row!=0&&row_selected)source_index<=source_index+row_scroll[4:0];
    state<=REQUEST;
   end
   REQUEST:if(source_index>=31||(row==0&&source_index>=album_length)||(row_selected&&source_index>=title_length))begin glyph<=8'h20;state<=WRITE;end
    else begin metadata_address<={record,source_index[4:0]};state<=WAIT_DATA;end
   WAIT_DATA:state<=READ_DATA;
   READ_DATA:begin glyph<=metadata_data;state<=WRITE;end
   WRITE:begin
    cache_write<=1;cache_address<={row,column};cache_data<=glyph;
    if(column==26)begin if(row==6)state<=IDLE;else begin row<=row+1'b1;state<=ROW;end end
    else begin column<=column+1'b1;state<=COLUMN;end
   end
   default:state<=IDLE;
  endcase
 end
 // Constant coordinate ROM replaces a long combinational divide-by-12 chain.
 (* ramstyle="M10K" *) reg [7:0] coordinates[0:511];
 (* ramstyle="M10K" *) reg [4:0] font[0:2047];
 integer n;
 initial begin
  for(n=0;n<512;n=n+1)coordinates[n]=(((n/12)&31)<<3)|((n%12)/2);
  $readmemb("rtl/media_overlay_font.mem",font);
 end
 reg [11:0] rx0=0,ry0=0;
 reg [26:0] video[0:4];
 reg [4:0] enable_pipe=0;
 reg [2:0] background1=0;
 reg [23:0] color2=0,color3=0,color4=0;
 reg [8:0] dx1=0;
 reg [2:0] row1=0,row2=0,gy1=0,gy2=0,gy3=0,gx3=0,gx4=0;
 reg valid1=0,valid2=0,valid3=0,valid4=0,bright1=0,bright2=0,bright3=0,bright4=0;
 reg [7:0] coordinate2=0,character3=0;
 reg [4:0] font4=0;
 reg [2:0] text_row;
 reg [11:0] text_y;
 reg text_band,selected_band,separator;
 always_comb begin
  text_row=0;text_y=16;text_band=0;
  if(ry0>=16&&ry0<32)text_band=1;
  else if(ry0>=64&&ry0<80)begin text_band=1;text_row=1;text_y=64;end
  else if(ry0>=106&&ry0<122)begin text_band=1;text_row=2;text_y=106;end
  else if(ry0>=148&&ry0<164)begin text_band=1;text_row=3;text_y=148;end
  else if(ry0>=190&&ry0<206)begin text_band=1;text_row=4;text_y=190;end
  else if(ry0>=232&&ry0<248)begin text_band=1;text_row=5;text_y=232;end
  else if(ry0>=274&&ry0<290)begin text_band=1;text_row=6;text_y=274;end
  selected_band=0;
  case(selected_slot)
   0:selected_band=ry0>=52&&ry0<86;1:selected_band=ry0>=94&&ry0<128;
   2:selected_band=ry0>=136&&ry0<170;3:selected_band=ry0>=178&&ry0<212;
   4:selected_band=ry0>=220&&ry0<254;5:selected_band=ry0>=262&&ry0<296;
   default:selected_band=0;
  endcase
  separator=(ry0==84&&row_present[0])||(ry0==126&&row_present[1])||
   (ry0==168&&row_present[2])||(ry0==210&&row_present[3])||
   (ry0==252&&row_present[4])||(ry0==294&&row_present[5]);
 end
 integer i;
 initial for(i=0;i<5;i=i+1)video[i]=0;
 wire panel0=rx0<370&&ry0<328;
 always @(posedge clk)begin
  // Stage 0: normalize coordinates; geometry is registered during blanking.
  rx0<=(raster_x-left)>>zoom;ry0<=(y-top)>>zoom;
  video[0]<={hs,vs,de,rgb};enable_pipe<={enable_pipe[3:0],enabled};
  for(i=1;i<5;i=i+1)video[i]<=video[i-1];
  // Stage 1: rectangles, row and glyph row.
  background1<=0;
  if(enable_pipe[0]&&panel0)begin
   background1<=1;
   if(selected_band&&rx0>=8&&rx0<362)background1<=2;
   if(rx0<2||rx0>=368||ry0<2||ry0>=326)background1<=3;
   if(separator&&rx0>=14&&rx0<356)background1<=4;
  end
  dx1<=rx0-(text_row==0?{3'd0,heading_left}:12'd18);row1<=text_row;gy1<=(ry0-text_y)>>1;
  valid1<=enable_pipe[0]&&panel0&&text_band&&rx0>=(text_row==0?{3'd0,heading_left}:12'd18)&&rx0<(text_row==0?{3'd0,heading_right}:12'd342);
  bright1<=text_row==0||text_row=={1'b0,selected_slot}+1'b1;
  // Stage 2: coordinate lookup.
  coordinate2<=coordinates[dx1];row2<=row1;gy2<=gy1;
  case(background1)
   1:color2<={2'b0,video[1][23:18],2'b0,video[1][15:10],2'b0,video[1][7:2]}+24'h080c12;
   2:color2<={2'b0,video[1][23:18],2'b0,video[1][15:10],2'b0,video[1][7:2]}+24'h182028;
   3:color2<=24'h607786;4:color2<=24'h263640;
   default:color2<=video[1][23:0];
  endcase
  valid2<=valid1;bright2<=bright1;
  // Stage 3: cached text lookup.
  character3<=text[{row2,coordinate2[7:3]}];gx3<=coordinate2[2:0];gy3<=gy2;
  color3<=color2;valid3<=valid2;bright3<=bright2;
  // Stage 4: font lookup.
  font4<=font[{character3,gy3}];gx4<=gx3;
  color4<=color3;valid4<=valid3;bright4<=bright3;
  // Stage 5: composite with video and sync delayed by the same six clocks.
  {hs_out,vs_out,de_out}<=video[4][26:24];rgb_out<=color4;
  if(valid4&&gx4<5&&font4[4-gx4])rgb_out<=bright4?24'heef2f4:24'h70808a;
 end
endmodule
