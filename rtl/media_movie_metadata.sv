// GPL-2.0-or-later. Bounded display metadata for plain/extended movie M3Us.
// Record 0 is the playlist title; records 1..255 follow actual path entries.
// Each record has 31 printable title bytes and a length byte. Video reads use
// a separate synchronous RAM port; metadata never reads movie payloads.
module media_movie_metadata(
 input wire clk,reset,begin_file,byte_valid,byte_eof,input wire [7:0] byte_data,
 output wire input_ready,output reg ready=0,
 input wire read_clk,input wire [12:0] read_address,output reg [7:0] read_data=0
);
 localparam COLLECT=0,CLEAR=1,CLASSIFY=2,TITLE=3,PLAYLIST=4,MOVIE=5,LENGTH=6,FINISH=7;
 reg [2:0] state=COLLECT;
 (* ramstyle="M10K" *) reg [7:0] bytes[0:8191];
 reg [7:0] line[0:99],title[0:30];
 reg [6:0] line_length=0,source=0,basename=0;
 reg [5:0] title_length=0,index=0;
 reg [7:0] count=0,record=0;
 reg [12:0] clear_address=0;
 reg eof_pending=0,pending_title=0;
 wire [7:0] character=source<line_length?line[source]:8'd0;
 wire [7:0] printable=character>=32&&character<127?character:8'h3f;
 wire [7:0] upper1=line[1]&8'hdf,upper2=line[2]&8'hdf,
  upper3=line[3]&8'hdf,upper4=line[4]&8'hdf,upper5=line[5]&8'hdf,
  upper6=line[6]&8'hdf,upper7=line[7]&8'hdf,upper8=line[8]&8'hdf;
 assign input_ready=state==COLLECT&&!ready;
 always @(posedge read_clk)read_data<=bytes[read_address];
 always @(posedge clk)begin
  if(state==CLEAR)bytes[clear_address]<=0;
  else if(state==PLAYLIST||state==MOVIE)
   bytes[{record,index[4:0]}]<=index<31 ?
    ((state==MOVIE&&pending_title)?(index<title_length?title[index]:8'd0):
     (source<line_length?printable:8'd0)):8'd0;
  else if(state==LENGTH)bytes[{record,5'd31}]<=index;
  if(reset)begin state<=COLLECT;ready<=0;line_length<=0;count<=0;pending_title<=0;eof_pending<=0;end
  else if(begin_file)begin state<=CLEAR;clear_address<=0;ready<=0;line_length<=0;count<=0;pending_title<=0;eof_pending<=0;end
  else case(state)
   CLEAR:if(clear_address==8191)state<=COLLECT;else clear_address<=clear_address+1'b1;
   COLLECT:if(byte_valid)begin
    if(byte_eof||byte_data==10||byte_data==13)begin eof_pending<=byte_eof;state<=CLASSIFY;source<=0;index<=0;end
    else begin
     if(line_length<100)begin line[line_length]<=byte_data;line_length<=line_length+1'b1;end
    end
   end
   CLASSIFY:begin
    if(line_length==0)state<=FINISH;
    else if(line[0]=="#")begin
     if(line_length>=8&&upper1=="E"&&upper2=="X"&&upper3=="T"&&upper4=="I"&&upper5=="N"&&upper6=="F"&&line[7]==":")begin
      // Seek the comma before capturing the optional EXTINF title.
      if(source<8)source<=8;
      else if(source>=line_length)state<=FINISH;
      else if(character==",")begin source<=source+1'b1;title_length<=0;pending_title<=1;state<=TITLE;end
      else source<=source+1'b1;
     end else if(line_length>=10&&upper1=="P"&&upper2=="L"&&upper3=="A"&&upper4=="Y"&&upper5=="L"&&upper6=="I"&&upper7=="S"&&upper8=="T"&&line[9]==":")begin
      source<=10;record<=0;state<=PLAYLIST;
     end else state<=FINISH;
    end else if(count==255)state<=FINISH;
    else begin
     // Use basename as fallback; index by paths, not EXTINF comments.
     if(source==0)basename<=0;
     if(source<line_length)begin
      if(character=="/"||character==8'h5c)basename<=source+1'b1;
      source<=source+1'b1;
     end else begin source<=basename;record<=count+1'b1;count<=count+1'b1;state<=MOVIE;end
    end
   end
   TITLE:if(source>=line_length||title_length==31)state<=FINISH;
    else begin title[title_length]<=printable;title_length<=title_length+1'b1;source<=source+1'b1;end
   PLAYLIST,MOVIE:begin
    if(index==30||(state==MOVIE&&pending_title?index+1>=title_length:source+1>=line_length))begin
     if(state==MOVIE&&pending_title)index<=title_length;
     else if(source>=line_length)index<=index;
     else index<=index+1'b1;
     state<=LENGTH;
    end else begin index<=index+1'b1;source<=source+1'b1;end
   end
   LENGTH:begin if(record!=0)pending_title<=0;state<=FINISH;end
   FINISH:begin line_length<=0;state<=COLLECT;if(eof_pending)ready<=1;end
   default:state<=COLLECT;
  endcase
 end
endmodule
