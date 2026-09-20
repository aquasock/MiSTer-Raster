// GPL-2.0-or-later. One 4:3/16:9 toggle per physical A-key press. Releases are
// tracked while the OSD is open so menu typing and typematic repeats cannot
// leak into the player. The setting is not reset by new files or core resets.
module media_aspect_toggle(
 input wire clk,osd_open,
 input wire [10:0] key,
 output reg wide=0
);
 reg key_toggle=0;
 reg a_down=0;
 always @(posedge clk) begin
  key_toggle<=key[10];
  if(key_toggle!=key[10] && key[8:0]==9'h01c) begin
   a_down<=key[9];
   if(key[9]&&!a_down&&!osd_open) wide<=!wide;
  end
 end
endmodule
