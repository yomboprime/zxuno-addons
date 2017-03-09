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
  input wire [7:0] specdrum_left,
  input wire [7:0] specdrum_right,
  // --- OUTPUTs ---
  output wire output_left,
  output wire output_right
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
   
  // Mixer for EAR, MIC and SPK
  reg [7:0] beeper;
  always @* begin
    beeper = 8'd0;
    case ({ear,spk,mic})
      3'b000: beeper = 8'd0;
      3'b001: beeper = 8'd36;
      3'b010: beeper = 8'd184;
      3'b011: beeper = 8'd192;
      3'b100: beeper = 8'd64;
      3'b101: beeper = 8'd100;
      3'b110: beeper = 8'd248;
      3'b111: beeper = 8'd255;
    endcase
  end
  
  reg [8:0] mixleft = 9'h000;
  reg [8:0] mixright = 9'h000;
  reg [1:0] state_left = 2'd0;
  reg [1:0] state_right = 2'd0;
  
  // Envia muestras al canal izquierdo de aquellas fuentes de audio
  // que estén habilitadas para usar dicho canal.
  // Lo hace de tal formas que el en caso de que haya pocas fuentes de audio
  // cada una será muestreada más rapidamente que si hubiera muchas. De ahí
  // que la máquina de estados sea pelín más compleja.

  // Se replica esta máquina de estados para el canal derecho.
  always @(posedge clk) begin
    case (state_left)
      2'd0:
      begin
        if (mixer[7]) begin
          mixleft <= ay1_cha + ay2_cha;
          state_left <= 2'd1;
        end
        else if (!mixer[7] && mixer[5]) begin
          mixleft <= ay1_chb + ay2_chb;
          state_left <= 2'd2;
        end
        else if (!mixer[7] && !mixer[5] && mixer[3]) begin
          mixleft <= ay1_chc + ay2_chc;
          state_left <= 2'd3;
        end
        else if (!mixer[7] && !mixer[5] && !mixer[3] && mixer[1]) begin
          mixleft <= beeper + specdrum_left;
          state_left <= 2'd0;
        end
      end
      
      2'd1:
      begin
        if (mixer[5]) begin
          mixleft <= ay1_chb + ay2_chb;
          state_left <= 2'd2;
        end
        else if (!mixer[5] && mixer[3]) begin
          mixleft <= ay1_chc + ay2_chc;
          state_left <= 2'd3;
        end
        else if (!mixer[5] && !mixer[3] && mixer[1]) begin
          mixleft <= beeper + specdrum_left;
          state_left <= 2'd0;
        end
      end
      
      2'd2:
      begin
        if (mixer[3]) begin
          mixleft <= ay1_chc + ay2_chc;
          state_left <= 2'd3;
        end
        else if (!mixer[3] && mixer[1]) begin
          mixleft <= beeper + specdrum_left;
          state_left <= 2'd0;
        end
      end
       
      2'd3:
      begin
        if (mixer[1]) begin
          mixleft <= beeper + specdrum_left;
          state_left <= 2'd0;
        end
      end

    endcase
  end
  
  // Lo mismo, pero para el canal derecho
  always @(posedge clk) begin
    case (state_right)
      2'd0:
      begin
        if (mixer[6]) begin
          mixright <= ay1_cha + ay2_cha;
          state_right <= 2'd1;
        end
        else if (!mixer[6] && mixer[4]) begin
          mixright <= ay1_chb + ay2_chb;
          state_right <= 2'd2;
        end
        else if (!mixer[6] && !mixer[4] && mixer[2]) begin
          mixright <= ay1_chc + ay2_chc;
          state_right <= 2'd3;
        end
        else if (!mixer[6] && !mixer[4] && !mixer[2] && mixer[0]) begin
          mixright <= beeper + specdrum_right;
          state_right <= 2'd0;
        end
      end
      
      2'd1:
      begin
        if (mixer[4]) begin
          mixright <= ay1_chb + ay2_chb;
          state_right <= 2'd2;
        end
        else if (!mixer[4] && mixer[2]) begin
          mixright <= ay1_chc + ay2_chc;
          state_right <= 2'd3;
        end
        else if (!mixer[4] && !mixer[2] && mixer[0]) begin
          mixright <= beeper + specdrum_right;
          state_right <= 2'd0;
        end
      end
      
      2'd2:
      begin
        if (mixer[2]) begin
          mixright <= ay1_chc + ay2_chc;
          state_right <= 2'd3;
        end
        else if (!mixer[2] && mixer[0]) begin
          mixright <= beeper + specdrum_right;
          state_right <= 2'd0;
        end
      end
       
      2'd3:
      begin
        if (mixer[0]) begin
          mixright <= beeper + specdrum_right;
          state_right <= 2'd0;
        end
      end

    endcase
  end
       
   // DACs
	dac audio_dac_left (
		.DACout(output_left),
		.DACin(mixleft),
		.Clk(clk),
		.Reset(!mrst_n)
		);
   
	dac audio_dac_right (
		.DACout(output_right),
		.DACin(mixright),
		.Clk(clk),
		.Reset(!mrst_n)
		);
endmodule
   