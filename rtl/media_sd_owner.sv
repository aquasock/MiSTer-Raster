// Serialize logical movie/subtitle readers, including two readers of TAR slot 0.
// Slot mapping is latched with ownership until all trailing writes retire.
module media_sd_owner(
 input wire clk,reset,input wire [1:0] request,host_ack,input wire buff_wr,
 input wire subtitle_archive,input wire [31:0] reader_lba[2],input wire [5:0] reader_blocks[2],
 output wire [31:0] host_lba[2],output wire [5:0] host_blocks[2],
 output wire [1:0] host_request,reader_wr,ack
);
 reg busy=0,owner=0,slot=0,seen=0,last=1;
 reg [3:0] tail=0;
 wire winner=request==3?!last:request[1];
 assign host_request=busy&&!seen ? (slot?2'b10:2'b01)&{2{request[owner]}}:2'b00;
 assign reader_wr=busy&&buff_wr ? (owner?2'b10:2'b01):2'b00;
 assign ack=busy&&host_ack[slot] ? (owner?2'b10:2'b01):2'b00;
 assign host_lba[0]=busy&&!slot?reader_lba[owner]:32'd0;
 assign host_lba[1]=busy&&slot?reader_lba[owner]:32'd0;
 assign host_blocks[0]=busy&&!slot?reader_blocks[owner]:6'd0;
 assign host_blocks[1]=busy&&slot?reader_blocks[owner]:6'd0;
 always @(posedge clk)begin
  if(reset)begin busy<=0;owner<=0;slot<=0;seen<=0;last<=1;tail<=0;end
  else if(!busy)begin
   if(|request)begin owner<=winner;slot<=winner&&!subtitle_archive;busy<=1;seen<=0;tail<=0;end
  end else if(host_ack[slot])begin seen<=1;tail<=6;end
  else if(seen)begin
   if(tail!=0)tail<=tail-1'b1;
   else begin busy<=0;last<=owner;end
  end else if(!request[owner])busy<=0;
 end
endmodule
