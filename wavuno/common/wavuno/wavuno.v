`timescale 1ns / 1ps
`default_nettype none

module wavuno(
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
    
    // External SRAM interface
    output wire [20: 0] exp_sram_addr,
    inout wire [7: 0] exp_sram_data,
    output wire exp_sram_we_n,
    
    // Audio outputs
    output wire [7: 0] audio_out_left,
    output wire [7: 0] audio_out_right
    );

    // The external SRAM length, 2 MB max.
    parameter RAM_EXT_ADDR_LENGTH = 21;
    parameter RAM_EXT_LENGTH = 2 ** RAM_EXT_ADDR_LENGTH;

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

    parameter WAVUNO_REG_EXT_USER_POINTER0 = 12;
    parameter WAVUNO_REG_EXT_USER_POINTER1 = 13;
    parameter WAVUNO_REG_EXT_USER_POINTER2 = 14;
    
    parameter WAVUNO_REG_EXT_SAMPLE_WRITE = 15;
    parameter WAVUNO_REG_EXT_SAMPLE_READ = 16;
    
    parameter WAVUNO_REG_EXT_CONTROL_FORMAT = 17;
    parameter WAVUNO_REG_EXT_CONTROL_BEGIN_REPROD = 18;
    parameter WAVUNO_REG_EXT_CONTROL_END_REPROD = 19;
    
    parameter WAVUNO_REG_EXT_FREQ_DIVIDER0 = 20;
    parameter WAVUNO_REG_EXT_FREQ_DIVIDER1 = 21;
    
    parameter WAVUNO_REG_EXT_START_LOOP0 = 22;
    parameter WAVUNO_REG_EXT_START_LOOP1 = 23;
    parameter WAVUNO_REG_EXT_START_LOOP2 = 24;

    parameter WAVUNO_REG_EXT_END_LOOP0 = 25;
    parameter WAVUNO_REG_EXT_END_LOOP1 = 26;
    parameter WAVUNO_REG_EXT_END_LOOP2 = 27;

    //
    // Accessible registers
    //

    // Common registers
    
    // Wavuno register selection
    reg [7: 0] statusReg = 8'b0;

    // Register for reading the external or internal ram
    reg [7: 0] sampleReadRegister = 8'b0;


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


    // External ram registers
    
    // Z80 read/write pointer to external sram
    reg [RAM_EXT_ADDR_LENGTH-1: 0] userExtPointer = 0;

    // Format Control Register (external ram)
    reg [7: 0] controlRegisterExtFormat = 8'b0;
    
    // Begin Reproduction Control register (external ram)
    reg [7: 0] controlRegisterExtBeginReprod = 8'b0;
    
    // End Reproduction Control register (external ram)
    reg [7: 0] controlRegisterExtEndReprod = 8'b0;
    
    // Frequency divider (external ram)
    reg [15: 0] extFrequencyDivider = 16'd159;

    // Channel A

    // Loop Start Address (external ram)
    reg [RAM_EXT_ADDR_LENGTH-1: 0] extLoopStartA = 0;

    // Loop End Address (external ram)
    reg [RAM_EXT_ADDR_LENGTH-1: 0] extLoopEndA = 0;
    
    // Loop Start Preload Address register (external ram)
    reg [RAM_EXT_ADDR_LENGTH-1: 0] extLoopStartPreA = 0;
    
    // Loop End Preload Address register (external ram)
    reg [RAM_EXT_ADDR_LENGTH-1: 0] extLoopEndPreA = 0;


    //
    // Not accessible registers
    //

    // Register of output address to external SRAM
    reg [RAM_EXT_ADDR_LENGTH-1: 0] outputAddress = 0;

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
    
    // Audio output of internal ram channel
    reg [7: 0] audioOutInt = 8'd128;

    // External SRAM Registers

    // Sound sample frequency divider
    reg [7: 0] extSampleClk = 8'b0;

    // *** TODO rename to channelTurn
    reg [1: 0] playCount = 2'b0;

    // Current playing pointer to external sram, channel A
    reg [RAM_EXT_ADDR_LENGTH-1: 0] playExtPointerA = 0;
    
    // Current estereo sample turn, channel A
    reg estereoTurnA = 0;
    
    // Audio output of external ram channel A
    reg [7: 0] audioOutLeftA = 8'd128;
    reg [7: 0] audioOutRightA = 8'd128;

    
    // Returns 0 if input is 0 or bitToKeep if it is 1.
    function zeroOrKeep;
        input data_in;
        input bitToKeep;
        zeroOrKeep = data_in == 1'b0 ? 1'b0 : bitToKeep;
    endfunction

    //
    // External SRAM control signals
    //
    
    // Write enable (negated)
    wire extSampleWrite =
        zxuno_regrd == 1'b0 &&
        zxuno_regwr == 1'b1 &&
        zxuno_addr == ZXUNO_DATA_REG &&
        statusReg == WAVUNO_REG_EXT_SAMPLE_WRITE &&
        cpuCount > 3'b0;
        
    assign exp_sram_we_n = ! extSampleWrite;

    // Data to the sram or high impedance for reading
    assign exp_sram_data = (extSampleWrite == 1'b1)? din : 8'hZZ;

    // SRAM address comes from register outputAddress
    assign exp_sram_addr = outputAddress;

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
    
    ldrcmixer mixer_left(
        .clk(clk28),
        .audioA(audioOutInt),
        .audioB(audioOutLeftA),
        .audioOut(audio_out_left)
    );

    ldrcmixer mixer_right(
        .clk(clk28),
        .audioA(audioOutInt),
        .audioB(audioOutRightA),
        .audioOut(audio_out_right)
    );

    // Reading from the Z80 asynchronously
    always @* begin

        dout = 8'hZZ;
        oe_n = 1'b1;
        
        if ( zxuno_regrd == 1'b1 ) begin
            
            if ( zxuno_addr == ZXUNO_DATA_REG ) begin
            
                case ( statusReg )

                    WAVUNO_REG_INT_SAMPLE_READ: dout = sampleReadRegister;
                    
                    WAVUNO_REG_INT_CONTROL_FORMAT: dout = controlRegisterIntFormat;
                    
                    WAVUNO_REG_INT_CONTROL_BEGIN_REPROD: dout = controlRegisterIntBeginReprod;
                    
                    WAVUNO_REG_INT_CONTROL_END_REPROD: dout = controlRegisterIntEndReprod;
                    
                    WAVUNO_REG_INT_FREQ_DIVIDER0: dout = intFrequencyDivider[7: 0];
                    
                    WAVUNO_REG_INT_FREQ_DIVIDER1: dout = intFrequencyDivider[15: 8];

                    WAVUNO_REG_EXT_USER_POINTER0: dout = userExtPointer[7: 0];
                    
                    WAVUNO_REG_EXT_USER_POINTER1: dout = userExtPointer[15: 8];
                    
                    WAVUNO_REG_EXT_USER_POINTER2: dout = { 3'b0, userExtPointer[20: 16] };

                    WAVUNO_REG_EXT_SAMPLE_READ: dout = sampleReadRegister;
                    
                    WAVUNO_REG_EXT_CONTROL_FORMAT: dout = controlRegisterExtFormat;
                    
                    WAVUNO_REG_EXT_CONTROL_BEGIN_REPROD: dout = controlRegisterExtBeginReprod;
                    
                    WAVUNO_REG_EXT_CONTROL_END_REPROD: dout = controlRegisterExtEndReprod;
                    
                    WAVUNO_REG_EXT_FREQ_DIVIDER0: dout = extFrequencyDivider[7: 0];
                    
                    WAVUNO_REG_EXT_FREQ_DIVIDER1: dout = extFrequencyDivider[15: 8];

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

                                WAVUNO_REG_INT_SAMPLE_READ: begin
                                    sampleReadRegister <= theRAM[ userIntPointer ];
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


                                //
                                // External ram channels
                                //

                                WAVUNO_REG_EXT_USER_POINTER0: userExtPointer[7: 0] <= din;
                                
                                WAVUNO_REG_EXT_USER_POINTER1: userExtPointer[15: 8] <= din;
                                
                                WAVUNO_REG_EXT_USER_POINTER2: userExtPointer[20: 16] <= din[4: 0];

                                WAVUNO_REG_EXT_SAMPLE_WRITE: begin
                                    outputAddress <= userExtPointer;
                                    userExtPointer <= userExtPointer + 1;
                                end

                                WAVUNO_REG_EXT_SAMPLE_READ: begin
                                    outputAddress <= userExtPointer;
                                    sampleReadRegister <= exp_sram_data;
                                    userExtPointer <= userExtPointer + 1;
                                end

                                WAVUNO_REG_EXT_CONTROL_FORMAT: controlRegisterExtFormat <= din;

                                WAVUNO_REG_EXT_CONTROL_BEGIN_REPROD: begin
                                    controlRegisterExtBeginReprod <= din;
                                    if ( din[ 0 ] == 1'b1 ) begin
                                        extLoopStartA <= extLoopStartPreA;
                                        extLoopEndA <= extLoopEndPreA;
                                        playExtPointerA <= extLoopStartPreA;
                                        estereoTurnA <= 1'b0;
                                    end
                                end
                                
                                WAVUNO_REG_EXT_CONTROL_END_REPROD: controlRegisterExtEndReprod <= {
                                    7'b0,
                                    zeroOrKeep( din[ 0 ], controlRegisterExtEndReprod[ 0 ] )

                                };
                                
                                WAVUNO_REG_EXT_FREQ_DIVIDER0: extFrequencyDivider[7: 0] <= din;
                                
                                WAVUNO_REG_EXT_FREQ_DIVIDER1: extFrequencyDivider[15: 8] <= din;
                                
                                // Channel A
                                
                                WAVUNO_REG_EXT_START_LOOP0: extLoopStartPreA[7: 0] <= din;

                                WAVUNO_REG_EXT_START_LOOP1: extLoopStartPreA[15: 8] <= din;
                    
                                WAVUNO_REG_EXT_START_LOOP2: extLoopStartPreA[20: 16] <= din[4: 0];

                                WAVUNO_REG_EXT_END_LOOP0: extLoopEndPreA[7: 0] <= din;

                                WAVUNO_REG_EXT_END_LOOP1: extLoopEndPreA[15: 8] <= din;
                    
                                WAVUNO_REG_EXT_END_LOOP2: extLoopEndPreA[20: 16] <= din[4: 0];
                                
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

                // External ram channel A reproduction
            
                if ( controlRegisterExtBeginReprod[0] == 1'b1 ) begin
                
                    if ( extSampleClk == extFrequencyDivider ) begin
                
                        // Look for end of loop
                        if ( playExtPointerA == extLoopEndA ) begin

                            // Load new loop start and end, and update play pointer
                            extLoopStartA <= extLoopStartPreA;
                            extLoopEndA <= extLoopEndPreA;
                            playExtPointerA <= extLoopStartPreA;

                            // Raise flag of end of loop reached
                            controlRegisterExtEndReprod[ 0 ] <= 1'b1;

                            // If not looping...
                            if ( ! controlRegisterExtFormat[ 0 ] ) begin
                                // Set audio output to 0
                                audioOutLeftA <= 8'd128;
                                audioOutRightA <= 8'd128;
                                // Stop playing
                                controlRegisterExtBeginReprod[0] <= 0;
                            end
                            else begin
                                // Else read last sample
                                outputAddress <= playExtPointerA;
                                if ( controlRegisterExtFormat[ 1 ] == 1'b1 ) begin
                                    // If stereo
                                    if ( estereoTurnA == 1'b0 ) begin
                                        audioOutLeftA <= exp_sram_data;
                                    end
                                    else begin
                                        audioOutRightA <= exp_sram_data;
                                    end
                                    estereoTurnA <= ! estereoTurnA;
                                end
                                else begin
                                    // If mono
                                    audioOutLeftA <= exp_sram_data;
                                    audioOutRightA <= exp_sram_data;
                                end
                            end
                        end
                        else begin
                            // Read sample and increment play pointer
                            outputAddress <= playExtPointerA;
                            if ( controlRegisterExtFormat[ 1 ] == 1'b1 ) begin
                                // If stereo
                                if ( estereoTurnA == 1'b0 ) begin
                                    audioOutLeftA <= exp_sram_data;
                                end
                                else begin
                                    audioOutRightA <= exp_sram_data;
                                end
                                estereoTurnA <= ! estereoTurnA;
                            end
                            else begin
                                // If mono
                                audioOutLeftA <= exp_sram_data;
                                audioOutRightA <= exp_sram_data;
                            end
                            playExtPointerA <= playExtPointerA + 1;
                        end
                        
                        extSampleClk <= 8'b0;
                    end
                    else begin
                        extSampleClk <= extSampleClk + 1;
                    end

                end

            end
            
            playCount <= playCount + 1;

        end

    end
    
endmodule

/*

- carga del registro de frecuencia de sample (int y ext)
- estereo (y comenzar a hacer las librerias)
- 4 canales


- preguntar en el grupo a mcleod cómo especificar que un array esté en bram
*/