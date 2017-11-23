/*

	Code derived from https://github.com/thekroko/ili9341_fpga

	2017 Adapted by Yomboprime from SPI interface to 16 bit parallel


Note: To rotate the image 180º in the screen, in the file initSequence.list:

Change this:

00
36
01
60
00
2A


to this:

00
36
01
A0
00
2A

*/


`default_nettype none

module TFTScreen(
	input wire clk,
	input wire [2:0] r,
	input wire [2:0] g,
	input wire [2:0] b,
	input wire [8:0] hc,
	input wire [8:0] vc,
	output wire screenRD,
	output reg screenWR,
	output reg screenRS,
	output reg screenRESET,
	output reg [15:0] screenData
);

assign screenRD = 1'b1;
initial screenWR = 1'b1;
initial screenRS = 1'b1;
initial screenRESET = 1'b1;

// Clock cycles per ms
parameter TICKS_MS = 14000;

// Init Sequence Data (based upon https://github.com/notro/fbtft/blob/master/fb_ili9341.c)
localparam INIT_SEQ_LEN = 174;
reg[7:0] initSeqCounter = 8'b0;
reg[7:0] INIT_SEQ [0:INIT_SEQ_LEN-1];
initial begin
  $readmemh( "initSequence.list", INIT_SEQ, 0, INIT_SEQ_LEN - 1 );
end


// Main state machine with delay
parameter START = 3'd0;
parameter HOLD_RESET = 3'd1;
parameter SEND_INIT_SEQ = 3'd2;
parameter WAIT_FOR_POWERUP = 3'd3;
parameter TURN_ON_DISPLAY = 3'd4;
parameter START_WRITING = 3'd5;
parameter LOOP = 3'd6;

reg[23:0] remainingDelayTicks = 24'b0;
reg [2:0] state = START;

// State machine for one memory write operation
//parameter WRITE_IDLE = 2'd0;
//parameter WRITE_START = 2'd1;
parameter WRITE_MAKE = 2'd2;
parameter WRITE_FINISH = 2'd3;

reg [1:0] writeState = WRITE_FINISH;


always @ (posedge clk) begin

/*
	if ( writeState == WRITE_START ) begin
		screenWR <= 1'b0;
		writeState <= WRITE_MAKE;
	end
	else
*/
	if ( writeState == WRITE_MAKE ) begin
		screenWR <= 1'b1;
		writeState <= WRITE_FINISH;
	end
/*
	else if ( writeState == WRITE_FINISH ) begin
		writeState <= WRITE_IDLE;
	end
*/
	else if (remainingDelayTicks > 0) begin
		remainingDelayTicks <= remainingDelayTicks - 1'b1;
	end
	else begin
		case (state)
			START: begin
				screenRESET <= 1'b0;
				remainingDelayTicks <= 200 * TICKS_MS;
				state <= HOLD_RESET;
			end

			HOLD_RESET: begin
				screenRESET <= 1'b1;
				remainingDelayTicks <= 120 * TICKS_MS;
				state <= SEND_INIT_SEQ;
			end

			SEND_INIT_SEQ: begin
				if (initSeqCounter < INIT_SEQ_LEN) begin
					screenRS <= INIT_SEQ[initSeqCounter][0];
					screenData <= { 8'h00, INIT_SEQ[initSeqCounter + 1'b1] };
					writeState <= WRITE_MAKE;
					screenWR <= 1'b0;
					initSeqCounter <= initSeqCounter + 2'd2;
				end else begin
					state <= WAIT_FOR_POWERUP;
					remainingDelayTicks <= 10 * TICKS_MS;
				end
			end

			WAIT_FOR_POWERUP: begin
				screenRS <= 1'b0;
				screenData <= 16'h0011; // take out of sleep mode
				writeState <= WRITE_MAKE;
                screenWR <= 1'b0;
				remainingDelayTicks <= 120 * TICKS_MS;
				state <= TURN_ON_DISPLAY;
			end

			TURN_ON_DISPLAY: begin
				screenRS <= 1'b0;
				screenData <= 16'h0029; // Turn on display
				writeState <= WRITE_MAKE;
                screenWR <= 1'b0;
				state <= START_WRITING;
			end

			START_WRITING: begin
				screenRS <= 1'b0;
				screenData <= 16'h002C; // Start pixel writing
				writeState <= WRITE_MAKE;
                screenWR <= 1'b0;
				state <= LOOP;
			end

			// frame buffer loop
			default: begin

				if ( vc == 8'd215 && hc == 9'd300 ) begin // y = 192 + 24, x == 320 - 20
					// 'Write to screen' command
					screenRS <= 1'b0;
					screenData <= 16'h002C; // Start pixel writing
					writeState <= WRITE_MAKE;
                    screenWR <= 1'b0;
				end
				else begin
					if ( ( vc < 240 && hc < 320 ) || ( vc == 240 && hc < 321 ) ) begin
						screenRS <= 1'b1;
						screenData <= { b, 2'b00, g, 3'b000, r, 2'b00 };
						writeState <= WRITE_MAKE;
                        screenWR <= 1'b0;
					end
				end

			end
		endcase
	end

end

endmodule
