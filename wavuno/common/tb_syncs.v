`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:00:10 09/15/2016
// Design Name:   pal_sync_generator
// Module Name:   D:/Users/rodriguj/Documents/zxspectrum/zxuno/repositorio/cores/spectrum_v2_spartan6/test23/v4/tb_syncs.v
// Project Name:  zxuno_v4
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: pal_sync_generator
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_syncs;

	// Inputs
	reg clk;

	// Outputs
	wire raster_int_in_progress;
	wire [8:0] hcnt;
	wire [8:0] vcnt;
	wire [2:0] ro;
	wire [2:0] go;
	wire [2:0] bo;
	wire hsync;
	wire vsync;
	wire csync;
	wire int_n;

	// Instantiate the Unit Under Test (UUT)
	pal_sync_generator uut (
		.clk(clk), 
		.mode(2'b00), 
		.rasterint_enable(1'b0), 
		.vretraceint_disable(1'b0), 
		.raster_line(9'd0), 
		.raster_int_in_progress(), 
		.ri(3'b111), 
		.gi(3'b111), 
		.bi(3'b111), 
		.hcnt(hcnt), 
		.vcnt(vcnt), 
		.ro(ro), 
		.go(go), 
		.bo(bo), 
		.hsync(hsync), 
		.vsync(vsync), 
		.csync(csync), 
		.int_n(int_n)
	);

	initial begin
		// Initialize Inputs
		clk = 0;

		// Add stimulus here

	end
   
   always begin
      clk = #(1000/14) ~clk;
   end
      
endmodule

