/*

        TFT Screen code derived from https://github.com/thekroko/ili9341_fpga

        2017 Adapted by Yomboprime from SPI interface to 16 bit parallel

*/

module TFTScreen(
    input clk,
    input [4:0] r,
    input [5:0] g,
    input [4:0] b,
    input [9:0] hc,
    input [9:0] vc,
    output screenRD,
    output reg screenWR,
    output reg screenRS,
    output reg screenRESET,
    output reg [15:0] screenData
);


// **********
// Parameters
// **********

// Uncomment the correct line to change screen rotation (0/180)
parameter initSeqName = "initSequence.list";
//parameter initSeqName = "initSequence180.list";

// Clock cycles per ms ( = clk frequency / 1000)
parameter TICKS_MS = 25000;

// Screen X offset
//parameter END_X = 10'd799;

// Screen Y offset
//parameter END_Y = 10'd420;

// Screen X offset
parameter END_X = 10'd20;

// Screen Y offset
parameter END_Y = 10'd420;

// *****************
// End of Parameters
// *****************


assign screenRD = 1'b1;
initial screenWR = 1'b1;
initial screenRS = 1'b1;
initial screenRESET = 1'b1;

// Init Sequence Data (based upon https://github.com/notro/fbtft/blob/master/fb_ili9341.c)
localparam INIT_SEQ_LEN = 174;
reg[7:0] initSeqCounter = 8'b0;
reg[7:0] INIT_SEQ [0:INIT_SEQ_LEN-1];
initial begin
    $readmemh( initSeqName, INIT_SEQ, 0, INIT_SEQ_LEN - 1 );
end


// Main state machine with delay
parameter START = 3'd0;
parameter HOLD_RESET = 3'd1;
parameter SEND_INIT_SEQ = 3'd2;
parameter WAIT_FOR_POWERUP = 3'd3;
parameter TURN_ON_DISPLAY = 3'd4;
parameter START_WRITING = 3'd5;
parameter WRITE_FRAME_BLACK = 3'd6;
parameter LOOP = 3'd7;

reg[23:0] remainingDelayTicks = 24'b0;
reg [2:0] state = START;

reg[16:0] fillBlackFrameCounter = 16'b0;

// State machine for one memory write operation
parameter WRITE_MAKE = 2'd0;
parameter WRITE_FINISH = 2'd1;

reg [1:0] writeState = WRITE_FINISH;


always @ (posedge clk) begin
    if ( writeState == WRITE_MAKE ) begin
        screenWR <= 1'b1;
        writeState <= WRITE_FINISH;
    end
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
                fillBlackFrameCounter <= 0;
                state <= WRITE_FRAME_BLACK;
            end

            WRITE_FRAME_BLACK: begin
                if ( fillBlackFrameCounter < 320 * 240 ) begin
                    fillBlackFrameCounter <= fillBlackFrameCounter + 1'b1;
                    screenRS <= 1'b1;
                    screenData <= 16'b0;
                    writeState <= WRITE_MAKE;
                    screenWR <= 1'b0;
                end
                else begin
                    state <= LOOP;
                end
            end

            // frame buffer loop
            default: begin

                if ( hc == END_X && vc == END_Y ) begin
                    // 'Write to screen' command
                    screenRS <= 1'b0;
                    screenData <= 16'h002C; // Start pixel writing
                    writeState <= WRITE_MAKE;
                    screenWR <= 1'b0;
                end
                else begin
                    // Write if coordinates are in [640, 400] in even lines, or in [640, 440] in odd or even lines
                    // (half resolution i.e. 320x200, and fill to 240 lines)
                    // Write also if we are in the last pixel ( hc == 640 && vc == 440 ) because we have lost previously
                    // one cycle when executing the 'write pixels' command.
                    if ( ( hc < 640 && vc < 440 && ( ( vc[0] == 1'b0 ) || ( vc >= 400 ) ) ) ||
                         ( hc == 640 && vc == 440 ) begin
                        screenRS <= 1'b1;
                        screenData <= { b, g, r };
                        writeState <= WRITE_MAKE;
                        screenWR <= 1'b0;
                    end
                end

            end
        endcase
    end

end

endmodule

