`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    04:04:00 04/01/2012 
// Design Name: 
// Module Name:    sigma_delta_dac 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

`define MSBI 7 // Most significant Bit of DAC input

//This is a Delta-Sigma Digital to Analog Converter
module dac (DACout, DACin, Clk, Reset);
	output DACout; // This is the average output that feeds low pass filter
	input [`MSBI:0] DACin; // DAC input (excess 2**MSBI)
	input Clk;
	input Reset;

	reg DACout; // for optimum performance, ensure that this ff is in IOB
	reg [`MSBI+2:0] DeltaAdder; // Output of Delta adder
	reg [`MSBI+2:0] SigmaAdder; // Output of Sigma adder
	reg [`MSBI+2:0] SigmaLatch = 1'b1 << (`MSBI+1); // Latches output of Sigma adder
	reg [`MSBI+2:0] DeltaB; // B input of Delta adder

	always @(SigmaLatch) DeltaB = {SigmaLatch[`MSBI+2], SigmaLatch[`MSBI+2]} << (`MSBI+1);
	always @(DACin or DeltaB) DeltaAdder = DACin + DeltaB;
	always @(DeltaAdder or SigmaLatch) SigmaAdder = DeltaAdder + SigmaLatch;
	always @(posedge Clk)
	begin
		if(Reset)
		begin
			SigmaLatch <= #1 1'b1 << (`MSBI+1);
			DACout <= #1 1'b0;
		end
		else
		begin
			SigmaLatch <= #1 SigmaAdder;
			DACout <= #1 SigmaLatch[`MSBI+2];
		end
	end
endmodule

module mixer (
	input wire clkdac,
	input wire reset,
	input wire ear,
	input wire mic,
	input wire spk,
	input wire [7:0] ay1,
	input wire [7:0] ay2,
	output wire audio
	);

    parameter
        SRC_BEEPER = 2'd0,
        SRC_AY1    = 2'd1,
        SRC_AY2    = 2'd2;

	wire [7:0] beeper = ({ear,spk,mic}==3'b000)? 8'd17 :
						({ear,spk,mic}==3'b001)? 8'd36 :
					    ({ear,spk,mic}==3'b010)? 8'd184 :
					    ({ear,spk,mic}==3'b011)? 8'd192 :
					    ({ear,spk,mic}==3'b100)? 8'd22 :
		                ({ear,spk,mic}==3'b101)? 8'd48 :
					    ({ear,spk,mic}==3'b110)? 8'd244 : 8'd255;
	
    reg [7:0] mezcla;
    reg [1:0] sndsource = 2'd0;
	
	always @(posedge clkdac) begin
        case (sndsource)
            SRC_BEEPER: mezcla <= beeper;
            SRC_AY1   : mezcla <= ay1;
            SRC_AY2   : mezcla <= ay2;
        endcase
        sndsource <= (sndsource == 2'd2)? 2'd0 : sndsource + 2'd1;  // en lugar de sumar, multiplexamos en el tiempo las fuentes de sonido
    end

	dac audio_dac (
		.DACout(audio),
		.DACin(mezcla),
		.Clk(clkdac),
		.Reset(reset)
		);
endmodule
