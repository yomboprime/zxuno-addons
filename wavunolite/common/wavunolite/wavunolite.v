`timescale 1ns / 1ps
`default_nettype none

module wavunolite(
    // Main clock, 28 MHz
    input wire clk28,

    // Turbo setting input
    input wire [1:0] turbo_enable,
    
    // Spectrum interface
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire [7:0] din,
    output reg [7:0] dout,
    output reg oe_n,

    // Audio outputs
    output wire [7: 0] audio_out_left,
    output wire [7: 0] audio_out_right
    );

    // The internal RAM, 2KB
    parameter RAM_INT_ADDR_LENGTH = 11;
    parameter RAM_INT_LENGTH = 1764;

    // Access ports values
    parameter ZXUNO_DATA_REG = 8'hFA;
    parameter ZXUNO_STATUS_REG = 8'hFB;

    // 
    // WavUno Registers
    //
    // WAVUNO_REG_XXX_0 is LSByte
    
    parameter WAVUNO_REG_INT_SAMPLE_RESET = 0;
    parameter WAVUNO_REG_INT_SAMPLE_WRITE = 1;
    parameter WAVUNO_REG_INT_SAMPLE_READ = 2;
    
    parameter WAVUNO_REG_INT_CONTROL_FORMAT = 3;
    parameter WAVUNO_REG_INT_CONTROL_BEGIN_REPROD = 4;
    parameter WAVUNO_REG_INT_CONTROL_END_REPROD = 5;
    
    parameter WAVUNO_REG_INT_FREQ_DIVIDER0 = 6;
    parameter WAVUNO_REG_INT_FREQ_DIVIDER1 = 7;
    
    parameter WAVUNO_REG_INT_START_LOOP0 = 8;
    parameter WAVUNO_REG_INT_START_LOOP1 = 9;

    parameter WAVUNO_REG_INT_END_LOOP0 = 10;
    parameter WAVUNO_REG_INT_END_LOOP1 = 11;

    //
    // Accessible registers
    //

    // Common registers
    
    // Wavuno register selection
    reg [7: 0] statusReg = 8'b0;

    // Internal ram registers

    // Z80 read/write pointer to internal ram
    reg [RAM_INT_ADDR_LENGTH-1: 0] userIntPointer = 0;

    // Format Control Register (internal ram)
    reg [7: 0] controlRegisterIntFormat = 8'b0;
    
    // Begin Reproduction Control register (internal ram)
    reg [7: 0] controlRegisterIntBeginReprod = 8'b0;
    
    // End Reproduction Control register (internal ram)
    reg [7: 0] controlRegisterIntEndReprod = 8'b0;
    
    // Frequency divider (internal ram)
    reg [15: 0] intFrequencyDivider = 16'd159;

    // Loop Start Address (internal ram)
    reg [RAM_INT_ADDR_LENGTH-1: 0] intLoopStart = 0;

    // Loop End Address (internal ram)
    reg [RAM_INT_ADDR_LENGTH-1: 0] intLoopEnd = 0;
    
    // Loop Start Preload Address register (internal ram)
    reg [RAM_INT_ADDR_LENGTH-1: 0] intLoopStartPre = 0;
    
    // Loop End Preload Address register (internal ram)
    reg [RAM_INT_ADDR_LENGTH-1: 0] intLoopEndPre = 0;

    //
    // Not accessible registers
    //

    // We need to divide the Z80 accesses to half (I don't know why). This flip flop is for that.
    reg toggleFlag = 1'b0;

    // Register that divides the 28 MHz clock in eight phases, 0 to 7
    reg [2: 0] clkDivider = 3'b0;

    // Position of next Z80 turn, counted in phases
    reg [2: 0] z80Pos = 3'b0;

    // Length of current Z80 turn, counted in phases
    reg [2: 0] cpuCount = 3'b0;
    
    // Tells if currently in the first phase of Z80 turn
    reg cpuActive = 1'b1;

    // Internal RAM Registers
    
    // Current playing pointer to internal RAM
    reg [RAM_INT_ADDR_LENGTH-1: 0] playIntPointer = 0;

    // Sound sample frequency divider
    reg [7: 0] intSampleClk = 8'b0;

    // TODO Internal estereo channel turn
    //reg estereoTurnA = 0;

    // Audio output of internal ram channel
    reg [7: 0] audioOutInt = 8'd128;

    // *** TODO rename to channelTurn
    reg [1: 0] playCount = 2'b0;

    // Returns 0 if input is 0 or bitToKeep if it is 1.
    function zeroOrKeep;
        input data_in;
        input bitToKeep;
        zeroOrKeep = data_in == 1'b0 ? 1'b0 : bitToKeep;
    endfunction

    //
    // The internal RAM
    //
    integer i;
    reg [7: 0] theRAM[ 0: RAM_INT_LENGTH-1 ];
    initial begin
        for (i=0;i<RAM_INT_LENGTH;i=i+1)
            theRAM[i] = 8'h00;
    end

    //
    // The mixers
    //
    
    assign audio_out_left = audioOutInt;
    assign audio_out_right = audioOutInt;

    // Reading from the Z80 asynchronously
    always @* begin

        dout = 8'hZZ;
        oe_n = 1'b1;
        
        if ( zxuno_regrd == 1'b1 ) begin
            
            if ( zxuno_addr == ZXUNO_DATA_REG ) begin
            
                case ( statusReg )
                    
                    WAVUNO_REG_INT_CONTROL_FORMAT: dout = controlRegisterIntFormat;
                    
                    WAVUNO_REG_INT_CONTROL_BEGIN_REPROD: dout = controlRegisterIntBeginReprod;
                    
                    WAVUNO_REG_INT_CONTROL_END_REPROD: dout = controlRegisterIntEndReprod;
                    
                    WAVUNO_REG_INT_FREQ_DIVIDER0: dout = intFrequencyDivider[7: 0];
                    
                    WAVUNO_REG_INT_FREQ_DIVIDER1: dout = intFrequencyDivider[15: 8];

                    default: dout = 8'b0;

                endcase

                oe_n = 1'b0;
            
            end
            else if ( zxuno_addr == ZXUNO_STATUS_REG ) begin
                // Read the status register
                dout = statusReg;
                oe_n = 1'b0;
            end                
                
        end

    end

    always @(posedge clk28) begin

        // if z80Pos is the next phase...
        if ( z80Pos == ( clkDivider + 3'b1 ) ) begin

            // Update z80Pos
            if ( turbo_enable > 2'b00 ) begin
                z80Pos <= z80Pos + ( 4'd8 >> turbo_enable );
            end
            
            // Update cpuCount, number of phases left off Z80 turn
            cpuCount <= ( 3'd4 >> turbo_enable );
            
            // Z80 access begins to be active now. This flag is only up for 1 phase, but
            // the sram wr signal is active for cpuCount phases
            cpuActive <= 1;

        end
        
        // Main clock divider in eight phases
        clkDivider <= clkDivider + 3'b1;

        if ( cpuCount > 3'b0 ) begin
        
            // It is the Z80 turn
            
            // Check if it is the first phase of the Z80 turn
            if ( cpuActive == 1'b1 ) begin

                // Z80 writing
                if ( zxuno_regrd == 1'b0 && zxuno_regwr == 1'b1 ) begin
                    if ( zxuno_addr == ZXUNO_DATA_REG ) begin
    
                        // Don't know why I must ignore 1 out of 2 writes
                        if ( toggleFlag == 1'b0 ) begin
                        
                            // Select register to write
                            case ( statusReg )
                            
                                //
                                // Internal ram channel
                                //

                                WAVUNO_REG_INT_SAMPLE_RESET: begin
                                    userIntPointer <= 0;
                                end

                                WAVUNO_REG_INT_SAMPLE_WRITE: begin
                                    theRAM[ userIntPointer ] <= din;
                                    userIntPointer <= userIntPointer + 1;
                                end

                                WAVUNO_REG_INT_CONTROL_FORMAT: controlRegisterIntFormat <= din;

                                WAVUNO_REG_INT_CONTROL_BEGIN_REPROD: begin
                                    controlRegisterIntBeginReprod <= din;
                                    if ( din[ 0 ] == 1'b1 ) begin
                                        intLoopStart <= intLoopStartPre;
                                        intLoopEnd <= intLoopEndPre;
                                        playIntPointer <= intLoopStartPre;
                                    end
                                end
                                
                                WAVUNO_REG_INT_CONTROL_END_REPROD: controlRegisterIntEndReprod <= {
                                    7'b0,
                                    zeroOrKeep( din[ 0 ], controlRegisterIntEndReprod[ 0 ] )
                                };
                                
                                WAVUNO_REG_INT_FREQ_DIVIDER0: intFrequencyDivider[7: 0] <= din;
                                
                                WAVUNO_REG_INT_FREQ_DIVIDER1: intFrequencyDivider[15: 8] <= din;

                                WAVUNO_REG_INT_START_LOOP0: intLoopStartPre[7: 0] <= din;

                                WAVUNO_REG_INT_START_LOOP1: intLoopStartPre[10: 8] <= din;

                                WAVUNO_REG_INT_END_LOOP0: intLoopEndPre[7: 0] <= din;

                                WAVUNO_REG_INT_END_LOOP1: intLoopEndPre[10: 8] <= din;

                            endcase

                        end
     
                        toggleFlag <= ! toggleFlag;
        
                    end
                    else if ( zxuno_addr == ZXUNO_STATUS_REG ) begin
                        statusReg <= din;
                    end

                end
            
                cpuActive <= 1'b0;
            
            end

            cpuCount <= cpuCount - 3'b1;

        end
        else begin
        
            // Reproduction turn

            if ( playCount == 2'b00 ) begin
            
                // Internal ram channel reproduction
            
                if ( controlRegisterIntBeginReprod[0] == 1'b1 ) begin
                
                    if ( intSampleClk == intFrequencyDivider ) begin
                
                        // Look for end of loop
                        if ( playIntPointer == intLoopEnd ) begin

                            // Load new loop start and end, and update play pointer
                            intLoopStart <= intLoopStartPre;
                            intLoopEnd <= intLoopEndPre;
                            playIntPointer <= intLoopStartPre;

                            // Raise flag of end of loop reached
                            controlRegisterIntEndReprod[ 0 ] <= 1'b1;

                            // If not looping...
                            if ( ! controlRegisterIntFormat[ 0 ] ) begin
                                // Set audio output to 0
                                audioOutInt <= 8'd128;
                                // Stop playing
                                controlRegisterIntBeginReprod[0] <= 0;
                            end
                            else begin
                                // Else read last sample
                                audioOutInt <= theRAM[ playIntPointer ];
                            end
                        end
                        else begin
                            // Read sample and increment play pointer
                            audioOutInt <= theRAM[ playIntPointer ];
                            playIntPointer <= playIntPointer + 1;
                        end
                        
                        intSampleClk <= 8'b0;
                    end
                    else begin
                        intSampleClk <= intSampleClk + 1;
                    end

                end

            end
            
            playCount <= playCount + 1;

        end

    end
    
endmodule
