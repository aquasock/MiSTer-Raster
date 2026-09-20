// GPL-2.0-or-later. USTAR header reader for Raster playlists.
// Filename normalization/FNV hashing follows Phosphor media_tar_index.
// Only ordinary short-name ustar members are accepted; unsupported extensions
// fail explicitly rather than silently changing path or size interpretation.
module media_tar_header(
 input wire clk,reset,valid,input wire [7:0] data,
 output reg done=0,empty=0,error=0,ustar=0,
 output wire [2:0] kind,output reg [40:0] size=0,
 output reg [31:0] name_hash=32'h811c9dc5,
 output reg [31:0] stem_hash=32'h811c9dc5,
 output reg [6:0] name_length=0
);
 reg [8:0] pos=0;
 reg zero=1,magic=1,regular=1,invalid=0,name_end=0;
 reg [17:0] sum=0,expected=0;
 reg [31:0] suffix=0,h1=32'h811c9dc5,h2=32'h811c9dc5,h3=32'h811c9dc5,h4=32'h811c9dc5;
 wire [7:0] slash=data==8'h5c ? 8'h2f:data;
 wire [7:0] lower=(slash>=65&&slash<=90)?slash+8'd32:slash;
 wire [31:0] mixed=name_hash^{24'd0,lower};
 wire [17:0] sum_next=sum+((pos>=148&&pos<156)?18'd32:{10'd0,data});
 assign kind=regular?(suffix==32'h2e6d7067 ? 3'd1:suffix==32'h2e737274 ? 3'd2:suffix==32'h2e6d3375 ? 3'd7:3'd0):3'd0;
 always @(posedge clk)begin
  if(reset)begin
   pos<=0;done<=0;empty<=0;error<=0;ustar<=0;zero<=1;magic<=1;regular<=1;invalid<=0;name_end<=0;
   size<=0;sum<=0;expected<=0;name_hash<=32'h811c9dc5;stem_hash<=32'h811c9dc5;name_length<=0;
   suffix<=0;h1<=32'h811c9dc5;h2<=32'h811c9dc5;h3<=32'h811c9dc5;h4<=32'h811c9dc5;
  end else if(valid&&!done)begin
   pos<=pos+1'b1;sum<=sum_next;if(data!=0)zero<=0;
   if(pos<100)begin
    if(data==0)name_end<=1;
    else if(!name_end)begin
     suffix<={suffix[23:0],lower};name_length<=name_length+1'b1;
     h4<=h3;h3<=h2;h2<=h1;h1<=name_hash;stem_hash<=h3;
     name_hash<=(mixed<<24)+(mixed<<8)+(mixed<<7)+(mixed<<4)+(mixed<<1)+mixed;
    end
   end
   if(pos>=124&&pos<=135)begin
    if(data>=48&&data<=55)begin size<=(size<<3)+{38'd0,data[2:0]};if(|size[40:38])invalid<=1;end
    else if(data!=0&&data!=32)invalid<=1;
   end
   if(pos>=148&&pos<=155)begin
    if(data>=48&&data<=55)begin expected<=(expected<<3)+{15'd0,data[2:0]};if(|expected[17:15])invalid<=1;end
    else if(data!=0&&data!=32)invalid<=1;
   end
   if(pos==156)begin regular<=data==0||data==48;if(data!=0&&data!=48&&data!=53)invalid<=1;end
   case(pos)
    257:if(data!="u")magic<=0;258:if(data!="s")magic<=0;259:if(data!="t")magic<=0;
    260:if(data!="a")magic<=0;261:if(data!="r")magic<=0;
    262:if(data!=0)invalid<=1;263,264:if(data!="0")invalid<=1;
    default:;
   endcase
   if(pos>=345&&pos<500&&data!=0)invalid<=1;
   if(pos==511)begin done<=1;empty<=zero&&data==0;ustar<=magic;
    error<=!(zero&&data==0)&&(invalid||!magic||sum_next!=expected||name_length==0);
   end
  end
 end
endmodule
