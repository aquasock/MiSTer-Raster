assign CLK_VIDEO = clk_video;
assign CE_PIXEL  = 1'b1;
assign VGA_DE = fb_video_de;
assign VGA_HS = fb_video_hs;
assign VGA_VS = fb_video_vs;
assign VGA_R = fb_video_r;
assign VGA_G = fb_video_g;
assign VGA_B = fb_video_b;

// Gate one: framebuffer pixels reach the platform directly. Player UI and
// subtitles remain in their independent HDMI overlay.

// Normal platform LED values; legacy diagnostic success/blink logic is retired.
assign LED_USER = 1'b0;
assign LED_POWER = 2'b00;
assign LED_DISK = 2'b00;

endmodule
