// Map a centered fixed 4:3 area to Phosphor's 640x480 transport scene.
// Phase accumulators implement nearest-neighbor scaling without pixel-rate
// multipliers, division or RAM. Geometry division runs only during blanking.
module media_progress_coordinates(
 input wire clk,frame,de,line_end,
 input wire [11:0] width,height,x,y,
 output reg [11:0] px=0,py=0,output wire inside_area
);
 reg [11:0] extent=480,left=0,top=0,right=640,bottom=480;
 reg [11:0] next_extent=480,next_top=0,saved_width=640;
 reg [13:0] division=0;
 reg [1:0] remainder=0;
 wire [2:0] reduced=trial-3'd3;
 reg [4:0] count=0;
 reg [1:0] state=0;
 wire [13:0] triple_width={2'b0,width}+({2'b0,width}<<1);
 wire [2:0] trial={remainder,division[13]};
 reg [12:0] phase_x=480,phase_y=480;
 wire [12:0] step=13'd480-{1'b0,extent};
 wire [12:0] double_extent={extent,1'b0};
 assign inside_area=extent>=240 && x>=left && x<right && y>=top && y<bottom;
 always @(posedge clk)begin
  if(frame)begin
   saved_width<=width;
   next_extent<=triple_width>={height,2'b0}?height:triple_width[13:2];
   next_top<=triple_width>={height,2'b0}?12'd0:(height-triple_width[13:2])>>1;
   state<=1;
  end else case(state)
   1:begin division<={next_extent,2'b0};remainder<=0;count<=14;state<=2;end
   2:begin
    division<={division[12:0],trial>=3};remainder<=trial>=3?reduced[1:0]:trial[1:0];
    count<=count-1'b1;if(count==1)state<=3;
   end
   3:begin
    extent<=next_extent;left<=(saved_width-division[11:0])>>1;
    right<=((saved_width-division[11:0])>>1)+division[11:0];
    top<=next_top;bottom<=next_top+next_extent;state<=0;
   end
   default:;
  endcase
  if(!de)begin px<=0;phase_x<=480;end
  else if(x>=left && x<right)begin
   if(phase_x>=double_extent)begin px<=px+12'd2;phase_x<=phase_x+step-{1'b0,extent};end
   else if(phase_x>={1'b0,extent})begin px<=px+1'b1;phase_x<=phase_x+step;end
   else phase_x<=phase_x+13'd480;
  end
  if(frame)begin py<=0;phase_y<=480;end
  else if(line_end && y>=top && y<bottom)begin
   if(phase_y>=double_extent)begin py<=py+12'd2;phase_y<=phase_y+step-{1'b0,extent};end
   else if(phase_y>={1'b0,extent})begin py<=py+1'b1;phase_y<=phase_y+step;end
   else phase_y<=phase_y+13'd480;
  end
 end
endmodule
