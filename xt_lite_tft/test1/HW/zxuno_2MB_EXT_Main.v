`timescale 1ns / 1ps

module zxuno_Next186lite_2MB_EXT
	(
		input  CLK_50MHZ,
		output [2:0]VGA_R,
		output [2:0]VGA_G,
		output [2:0]VGA_B,
		output VGA_HSYNC,
		output VGA_VSYNC,
		output SRAM_WE_n,
		output [20:0]SRAM_A,
		inout [7:0]SRAM_D,
		output SRAM_EXT_WE_n,
		output [20:0]SRAM_EXT_A,
		inout [7:0]SRAM_EXT_D,
		output LED,
		output AUDIO_L,
		output AUDIO_R,
		inout PS2CLKA,
		inout PS2CLKB,
		inout PS2DATA,
		inout PS2DATB,
		output SD_nCS,
		output SD_DI,
		output SD_CK,
		input SD_DO,
		input P_A,
		input P_U,
		input P_D,
		input P_L,
		input P_R,
		input P_tr
	);

	wire [5:0]V_R;
	wire [5:0]V_G;
	wire [5:0]V_B;
	assign VGA_R = V_R[5:3];
	assign VGA_G = V_G[5:3];
	assign VGA_B = V_B[5:3];
	assign SRAM_A = 21'h000000;
	assign SRAM_WE_n = 1'b1;
	assign SRAM_D = 8'hzz;

	system_2MB sys_inst
	(
		.CLK_50MHZ(CLK_50MHZ),
		.VGA_R(V_R),
		.VGA_G(V_G),
		.VGA_B(V_B),
		.VGA_HSYNC(VGA_HSYNC),
		.VGA_VSYNC(VGA_VSYNC),
		.SRAM_ADDR(SRAM_EXT_A),
		.SRAM_DATA(SRAM_EXT_D),
		.SRAM_WE_n(SRAM_EXT_WE_n),
		.LED(LED),
		.SD_n_CS(SD_nCS),
		.SD_DI(SD_DI),
		.SD_CK(SD_CK),
		.SD_DO(SD_DO),
		.AUD_L(AUDIO_L),
		.AUD_R(AUDIO_R),
	 	.PS2_CLK1(PS2CLKA),
		.PS2_CLK2(PS2CLKB),
		.PS2_DATA1(PS2DATA),
		.PS2_DATA2(PS2DATB)
	);

endmodule
