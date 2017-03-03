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

`define MSBI 8 // Most significant Bit of DAC input

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
	input wire [7:0] ay1_cha,
	input wire [7:0] ay1_chb,
	input wire [7:0] ay1_chc,
	input wire [7:0] ay2_cha,
	input wire [7:0] ay2_chb,
	input wire [7:0] ay2_chc,
   input wire [7:0] specdrum,
	output wire audio
	);

    parameter
        SRC_BEEPER  = 3'd0,
        SRC_AY1_CHA = 3'd1,
        SRC_AY1_CHB = 3'd2,
        SRC_AY1_CHC = 3'd3,
        SRC_AY2_CHA = 3'd4,
        SRC_AY2_CHB = 3'd5,
        SRC_AY2_CHC = 3'd6,
        SRC_SPECD   = 3'd7;

	wire [7:0] beeper = ({ear,spk,mic}==4'h0)? 8'd17 :
						({ear,spk,mic}==3'b001)? 8'd36 :
					    ({ear,spk,mic}==3'b010)? 8'd184 :
					    ({ear,spk,mic}==3'b011)? 8'd192 :
					    ({ear,spk,mic}==3'b100)? 8'd22 :
		                ({ear,spk,mic}==3'b101)? 8'd48 :
					    ({ear,spk,mic}==3'b110)? 8'd244 : 8'd255;
	
    reg [7:0] mezcla;
    reg [2:0] sndsource = 3'd0;
	
	always @(posedge clkdac) begin
        case (sndsource)
            SRC_BEEPER  : mezcla <= beeper;
            SRC_AY1_CHA : mezcla <= ay1_cha;
            SRC_AY1_CHB : mezcla <= ay1_chb;
            SRC_AY1_CHC : mezcla <= ay1_chc;
            SRC_AY2_CHA : mezcla <= ay2_cha;
            SRC_AY2_CHB : mezcla <= ay2_chb;
            SRC_AY2_CHC : mezcla <= ay2_chc;
            SRC_SPECD   : mezcla <= specdrum;
        endcase
        sndsource <= sndsource + 3'd1;  // en lugar de sumar, multiplexamos en el tiempo las fuentes de sonido
    end

	dac audio_dac (
		.DACout(audio),
		.DACin(mezcla),
		.Clk(clkdac),
		.Reset(reset)
		);
endmodule

/*
The sound mix is controlled by port #F7 (sets the mix for the
currently selected PSG). There are two channels for the beeper.
When one channel is active the beeper is at the same volume level as
a single PSG channel at full volume. When both are active and have
the same pan it is then double the volume of a single PSG channel.
This approximates the relative loudness of the beeper on 128K
machines.

D6-7:	channel A
D4-5:	channel B
D3-2:	channel C
D1-0:	channel D (beeper)

Panning is limited to switching a channel on or off for a given
speaker. The bits are decoded as follows:

00 = mute
10 = left
01 = right
11 = both

The default port value on reset is zero (all channels off).
*/
module panner_and_mixer (
   input wire clk,
   input wire mrst_n,
   input wire [7:0] a,
   input wire iorq_n,
   input wire rd_n,
   input wire wr_n,
   input wire [7:0] din,
   output reg [7:0] dout,
   output reg oe_n,
   //--- SOUND SOURCES ---
   input wire mic,
   input wire ear,
   input wire spk,
   input wire [7:0] ay1_cha,
   input wire [7:0] ay1_chb,
   input wire [7:0] ay1_chc,
   input wire [7:0] ay2_cha,
   input wire [7:0] ay2_chb,
   input wire [7:0] ay2_chc,
   input wire [7:0] specdrum,
   // --- OUTPUTs ---
   output wire [8:0] output_left,
   output wire [8:0] output_right
   );
   
   // Register accepts data from CPU
   reg [7:0] mixer = 8'b10011111; // ACB stereo mode, Specdrum and beeper on both channels
   always @(posedge clk) begin
      if (mrst_n == 1'b0)
         mixer <= 8'b10011111;
      else if (a == 8'hF7 && iorq_n == 1'b0 && wr_n == 1'b0)
         mixer <= din;
   end
   
   // CPU reads register
   always @* begin
      dout = mixer;
      if (a == 8'hF7 && iorq_n == 1'b0 && rd_n == 1'b0)
         oe_n = 1'b0;
      else
         oe_n = 1'b1;
   end
   
   // Mixer

   wire [7:0] beeper =  ({ear,spk,mic}==4'h0)? 8'd17:
                        ({ear,spk,mic}==3'b001)? 8'd36 :
                        ({ear,spk,mic}==3'b010)? 8'd184 :
                        ({ear,spk,mic}==3'b011)? 8'd192 :
                        ({ear,spk,mic}==3'b100)? 8'd22 :
                        ({ear,spk,mic}==3'b101)? 8'd48 :
                        ({ear,spk,mic}==3'b110)? 8'd244 : 
                                                 8'd255;

/*
   wire [7:0] beeper =  ({ear,spk,mic}==4'h0)? 8'd145:
                        ({ear,spk,mic}==3'b001)? 8'd164 :
                        ({ear,spk,mic}==3'b010)? 8'd56 :
                        ({ear,spk,mic}==3'b011)? 8'd64 :
                        ({ear,spk,mic}==3'b100)? 8'd150 :
                        ({ear,spk,mic}==3'b101)? 8'd176 :
                        ({ear,spk,mic}==3'b110)? 8'd116 : 
                                                 8'd127;
*/

   reg [11:0] mixleft = 12'h000;
   reg [11:0] mixright = 12'h000;
   reg [8:0] left, right;
   reg [3:0] state = 4'd0;
   always @(posedge clk) begin      
      case (state)
         4'd0: begin
                  left <= mixleft[8:0];
                  right <= mixright[8:0];
                  
                  if (mixer[7] == 1'b1)   // if channel A is going to the left
                     mixleft <= {4'h0, ay1_cha} + {4'h0, ay2_cha};
                  else
                     mixleft <= 12'h000;
               end
         4'd1: begin
                  if (mixer[6] == 1'b1)   // if channel A is going to the right...
                     mixright <= {4'h0, ay1_cha} + {4'h0, ay2_cha};
                  else
                     mixright <= 12'h000;
               end
         4'd2: begin
                  if (mixer[5] == 1'b1)   // if channel B is going to the left
                     mixleft <= mixleft + {4'h0, ay1_chb} + {4'h0, ay2_chb};
               end
         4'd3: begin
                  if (mixer[4] == 1'b1)   // if channel B is going to the right...
                     mixright <= mixright + {4'h0, ay1_chb} + {4'h0, ay2_chb};
               end
         4'd4: begin
                  if (mixer[3] == 1'b1)   // if channel C is going to the left
                     mixleft <= mixleft + {4'h0, ay1_chc} + {4'h0, ay2_chc};
               end
         4'd5: begin
                  if (mixer[2] == 1'b1)   // if channel C is going to the right...
                     mixright <= mixright + {4'h0, ay1_chc} + {4'h0, ay2_chc};
               end
         4'd6: begin
                  if (mixer[1] == 1'b1)   // if beeper+specdrum are going to the left
                     mixleft <= mixleft + {4'h0, beeper} + {4'h0, specdrum};
               end
         4'd7: begin
                  if (mixer[0] == 1'b1)   // if beeper+specdrum are going to the right...
                     mixright <= mixright + {4'h0, beeper} + {4'h0, specdrum};
               end
         4'd8: begin // mixleft = 256+(mixleft-128*8)/4 y lo mismo con right
                  mixleft <= mixleft + 12'hC00;
                  mixright <= mixright + 12'hC00;
               end
         4'd9: begin
                  mixleft  <= { {2{mixleft[11]}}, mixleft[11:2]};
                  mixright <= { {2{mixright[11]}}, mixright[11:2]};
               end
         4'd10: begin
                  mixleft <= mixleft + 12'd256;
                  mixright <= mixright + 12'd256;
                end
      endcase
      state <= (state == 4'd10)? 4'd0 : state + 4'd1;
   end

   assign output_right = right;
   assign output_left = left;
   

/*
   wire ay1AB_mix;
   ldrcmixer mixer_ay1AB(
      .clk(clk),
      .audioA(ay1_cha + 8'd128),
      .audioB(ay1_chb + 8'd128),
      .audioOut(ay1AB_mix)
   );
   
   wire ay1ABC_mix;
   ldrcmixer mixer_ay1ABC(
      .clk(clk),
      .audioA(ay1AB_mix),
      .audioB(ay1_chc + 8'd128),
      .audioOut(ay1ABC_mix)
   );

   wire ay2AB_mix;
   ldrcmixer mixer_ay2AB(
      .clk(clk),
      .audioA(ay2_cha + 8'd128),
      .audioB(ay2_chb + 8'd128),
      .audioOut(ay2AB_mix)
   );
   
   wire ay2ABC_mix;
   ldrcmixer mixer_ay2ABC(
      .clk(clk),
      .audioA(ay2AB_mix),
      .audioB(ay2_chc + 8'd128),
      .audioOut(ay2ABC_mix)
   );
   
   wire ay12_mix;
   ldrcmixer mixer_ay12(
      .clk(clk),
      .audioA(ay1ABC_mix),
      .audioB(ay2ABC_mix),
      .audioOut(ay12_mix)
   );
*/

/*
   wire final_mix;
   ldrcmixer mixer_final(
      .clk(clk),
      //.audioA(ay12_mix),
      .audioA(8'd128),
      //.audioB(beeper),
      .audioB(8'd128),
      .audioOut(final_mix)
   );

   assign output_left = final_mix;
   assign output_right = final_mix;

   //assign output_left = 8'd128;
   //assign output_right = 8'd128;
*/

endmodule
   