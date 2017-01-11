`timescale 1ns / 1ps
`default_nettype none

// Random number generator. It is a Fibonnacci LDR
// Source: https://en.wikipedia.org/wiki/Linear-feedback_shift_register
module FLDR16 (
    input wire clk,
    input wire request,
    output wire [7:0] random
    );

    reg inited = 1'b0;
    reg [15:0] counter = 16'b0;
    reg [16:0] seed = 16'b0;
    
    assign random = seed[7:0];
    
    always @( posedge clk ) begin

        if ( counter < 16'hFE ) begin
            counter <= counter + 16'b1;
        end
        else begin
            counter <= 16'b1;
        end

        if ( request == 1'b1 ) begin
            if ( inited == 1'b0 ) begin
                seed <= counter;
                inited <= 1'b1;
            end
            else begin 
                seed <= { seed[ 0 ] ^ seed[ 2 ] ^ seed[ 3 ] ^ seed[ 5 ], seed[ 15: 1 ] };
            end
        end
    end
    
endmodule

module veripac9 (
    input wire clk,
    input wire [7:0] addr,
    input wire rd,
    input wire wr,
    input wire [7:0] din,
    output reg [7:0] dout,
    input wire step,
    input wire reset
    );

    // Memory Map
    parameter VERIPAC_RAM_LENGTH = 8'hCA;
    localparam VERIPAC_CONTROL_REG = VERIPAC_RAM_LENGTH;
    localparam VERIPAC_KEYBOARD_REG = VERIPAC_CONTROL_REG + 8'd1;
    localparam VERIPAC_ACCUMULATOR = VERIPAC_CONTROL_REG + 8'd2;
    localparam VERIPAC_PROGRAM_COUNTER = VERIPAC_CONTROL_REG + 8'd3;
    localparam VERIPAC_INSTRUCTION_REG = VERIPAC_CONTROL_REG + 8'd4;
    localparam VERIPAC_DATA_COUNTER = VERIPAC_CONTROL_REG + 8'd5;

    localparam VERIPAC_SCREEN_START = 8'hD0;
    localparam VERIPAC_SCREEN_LENGTH = 8'd32;
    localparam VERIPAC_SCREEN_END = VERIPAC_SCREEN_START + VERIPAC_SCREEN_LENGTH;
    localparam VERIPAC_NUM_LINES = 8'd2;
    localparam VERIPAC_LINE_LENGTH = 8'd16;

    localparam VERIPAC_NUM_REGS = 8'd16;
    localparam VERIPAC_REGS_START = 8'hF0;
    
    localparam VERIPAC_STACK_SIZE = 8'd32;
    
    // Control Unit state
    localparam UCSTATE_FETCH1 = 2'b00;
    localparam UCSTATE_FETCH2 = 2'b01;
    localparam UCSTATE_EXEC = 2'b10;
    localparam UCSTATE_HALT = 2'b11;
    
    // Instruction set
    
    localparam I_CLR = 8'h01;
    localparam I_DEC = 8'h02;
    localparam I_INC = 8'h03;
    localparam I_RND = 8'h08;
    localparam I_MOV = 8'h09;
    localparam I_INA = 8'h04;
    localparam I_INPR = 4'h7;
    localparam I_OTA = 8'h0B;
    localparam I_OUTR = 4'hC;
    localparam I_SIG = 8'h05;
    localparam I_PAKR = 4'h8;
    localparam I_UNPR = 4'hB;
    localparam I_LDAR = 4'h9;
    localparam I_SUBR = 4'hD;
    localparam I_ADDR = 4'hE;
    localparam I_STOR = 4'hA;
    localparam I_LDVRNN = 4'h6;
    localparam I_NOP = 8'h00;
    localparam I_HALT = 8'hFF;
    localparam I_GTSNN = 8'h14;
    localparam I_RET = 8'h07;
    localparam I_BDCNN = 8'h11;
    localparam I_GTONN = 8'h12;
    localparam I_BRZNN = 8'h13;
    localparam I_BNERNN = 4'h2;
    localparam I_BEQRNN = 4'h3;
    localparam I_BGTRNN = 4'h4;
    localparam I_BLTRNN = 4'h5;
    
    // New instructions not present in original machine
    localparam I_LDVSPNN = 8'h10;
    localparam I_LDVANN = 8'h0A;
    localparam I_PSHA = 8'h0C;
    localparam I_POPA = 8'h0D;
    localparam I_PSHR = 8'h0E;
    localparam I_POPR = 8'h0F;
    localparam I_BNCNN = 8'h15;
    localparam I_BCNN = 8'h16;

    integer i;
 
    // The RAM
    reg [7: 0] ram[0: VERIPAC_RAM_LENGTH-1];
    initial begin
        for (i=0;i<VERIPAC_RAM_LENGTH;i=i+1)
            ram[i] = 8'b0;
    end
    
    // Screen Buffer
    reg [7: 0] screen[0: VERIPAC_SCREEN_LENGTH-1];
    initial begin
        for (i=0;i<VERIPAC_SCREEN_LENGTH;i=i+1)
            screen[i] = 8'h0C;
    end
    
    // The registers
    reg [7: 0] theRegisters[0: VERIPAC_NUM_REGS-1];
    initial begin
        for (i=0;i<VERIPAC_NUM_REGS;i=i+1)
            theRegisters[i] = 8'b0;
    end
    
    // The stack
    reg [7: 0] stack[ 0: VERIPAC_STACK_SIZE - 1];
    reg [7: 0] stackPointer = 0;
    
    // Special registers
    reg [7: 0] keyboardReg = 8'b0;
    reg [7: 0] accumulator = 8'b0;
    reg [7: 0] programCounter = 8'b0;
    reg [7: 0] instructionReg = 8'b0;
    reg [7: 0] dataCounter = 8'b0;
    reg [1: 0] ucState = UCSTATE_FETCH1;
    
    // Other signals
    reg carry = 1'b0;
    
    reg prevStep = 1'b0;
    
    // Used to fetch the contents of the register affected by the instruction:
    reg [7: 0] Ri = 8'b0;

    wire buzzer;
    assign buzzer = instructionReg == I_SIG && ucState == UCSTATE_EXEC;

    wire keyWanted;
    assign keyWanted = ( instructionReg == I_INA || instructionReg[7: 4] == I_INPR ) && ucState == UCSTATE_EXEC;
    
    // Random number generator
    reg rndRequest = 1'b0;
    wire [7: 0] rndNumber;
    FLDR16 theRND(
        .clk(clk),
        .request(rndRequest),
        .random(rndNumber)
    );
    

    function isTwoByteInstruction;
        input [7: 0] instructionFirstByte;
        
        isTwoByteInstruction = ( instructionFirstByte[7:4] >= 4'h1 &&
                                 instructionFirstByte[7:4] <= 4'h6 ) ||
                                 instructionFirstByte == I_LDVANN ||
                                 instructionFirstByte == I_PSHR ||
                                 instructionFirstByte == I_POPR;
    endfunction
    
    function isRegisterInstruction;
        input [7: 0] instructionFirstByte;
        
        isRegisterInstruction = instructionFirstByte[7:4] >= 4'h2 &&
                                instructionFirstByte[7:4] <= 4'hE;
    endfunction
    
    

    // Lectura del host
    always @* begin
        dout <= 8'hZZ;
        if (rd == 1'b1) begin
            if ( addr < VERIPAC_RAM_LENGTH ) begin
                dout <= ram[ addr ];
            end
            else if ( addr >= VERIPAC_SCREEN_START && addr < VERIPAC_SCREEN_END ) begin
                dout <= screen[ addr - VERIPAC_SCREEN_START ];
            end
            else if ( addr >= VERIPAC_REGS_START ) begin
                dout <= theRegisters[ addr - VERIPAC_REGS_START ];
            end
            else begin
                case ( addr )
                    VERIPAC_CONTROL_REG: begin
                        dout <= { 5'b0, buzzer, ucState };
                    end
                    
                    VERIPAC_KEYBOARD_REG : begin
                        dout <= { 7'b0, keyWanted };
                    end

                    VERIPAC_ACCUMULATOR: begin
                        dout <= accumulator;
                    end
                    
                    VERIPAC_PROGRAM_COUNTER: begin
                        dout <= programCounter;
                    end
                    
                    VERIPAC_INSTRUCTION_REG: begin
                        dout <= instructionReg;
                    end
                    
                    VERIPAC_DATA_COUNTER: begin
                        dout <= dataCounter;
                    end
                endcase
            end
        end
    end

    always @(posedge clk) begin

        // Escritura del host
        if (wr == 1'b1) begin
            if ( addr < VERIPAC_RAM_LENGTH ) begin
                ram[ addr ] <= din;
            end
            else if ( addr >= VERIPAC_SCREEN_START && addr < VERIPAC_SCREEN_END ) begin
                screen[ addr - VERIPAC_SCREEN_START ] <= din;
            end
            else if ( addr >= VERIPAC_REGS_START ) begin
                theRegisters[ addr - VERIPAC_REGS_START ] <= din;
            end
            else begin
                case ( addr )
                
                    VERIPAC_KEYBOARD_REG : begin
                        keyboardReg <= din;
                    end

                    VERIPAC_ACCUMULATOR: begin
                        accumulator <= din;
                    end
                    
                    VERIPAC_PROGRAM_COUNTER: begin
                        programCounter <= din;
                    end
                    
                    VERIPAC_INSTRUCTION_REG: begin
                        instructionReg <= din;
                    end
                    
                    VERIPAC_DATA_COUNTER: begin
                        dataCounter <= din;
                    end
                endcase
            end
        end
        else if ( rd == 0 ) begin
            if (reset == 1'b1) begin
                programCounter <= 8'b0;
                stackPointer <= 8'b0;
                ucState <= UCSTATE_FETCH1;
            end
            else if ( step == 1'b1 && prevStep == 1'b0 ) begin
                // Ejecucion de un paso de instruccion
                case ( ucState )
                    UCSTATE_FETCH1 : begin
                        if ( programCounter >= VERIPAC_RAM_LENGTH ) begin
                            ucState <= UCSTATE_HALT;
                        end
                        else begin
                            instructionReg <= ram[ programCounter ];
                            programCounter <= programCounter + 1;
                            ucState <= UCSTATE_FETCH2;
                        end
                    end
                    UCSTATE_FETCH2 : begin
                        if ( isTwoByteInstruction( instructionReg ) ) begin
                            if ( programCounter >= VERIPAC_RAM_LENGTH ) begin
                                ucState <= UCSTATE_HALT;
                            end
                            else begin
                                dataCounter <= ram[ programCounter ];
                                programCounter <= programCounter + 1;
                                ucState <= UCSTATE_EXEC;
                            end
                        end
                        else begin
                            if ( instructionReg == I_RND ) begin
                                rndRequest <= 1'b1;
                            end
                            dataCounter <= 8'b0;
                            ucState <= UCSTATE_EXEC;
                        end

                        if ( instructionReg == I_OTA || instructionReg[7: 4] == I_OUTR || instructionReg == I_SIG ) begin
                            Ri <= theRegisters[ 4'hB ];
                        end
                        else if ( instructionReg == I_MOV ) begin
                            Ri <= theRegisters[ 4'hC ];
                        end
                        else if ( isRegisterInstruction( instructionReg ) ) begin
                            Ri <= theRegisters[ instructionReg[3: 0] ];
                        end
                        else begin
                            Ri <= 8'b0;
                        end

                    end
                    UCSTATE_EXEC : begin

                        if ( isRegisterInstruction( instructionReg ) ) begin

                            // Instructions using a register Ri
                            case ( instructionReg[7: 4] )
                                I_INPR : begin
                                    // Get keyboard input in register
                                    theRegisters[ instructionReg[3: 0] ] <= keyboardReg;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_OUTR : begin
                                    // Output register to screen pointed by RB and inc RB
                                    screen[ Ri[4: 0] ] <= theRegisters[ instructionReg[3: 0] ];
                                    if ( Ri[4: 0] == 5'h0A ) begin
                                        theRegisters[ 4'hB ][4: 0] <= 5'b0;
                                    end
                                    else begin
                                        theRegisters[ 4'hB ][4: 0] <= Ri[4: 0] + 1;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_PAKR : begin
                                    // Pack nibbles
                                    accumulator[7: 4] <= Ri[3: 0];
                                    accumulator[3: 0] <= theRegisters[ instructionReg[3: 0] ][3: 0];
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_UNPR : begin
                                    // Unpack nibbles
                                    theRegisters[ instructionReg[3: 0] ] <= accumulator[7: 4];
                                    theRegisters[ instructionReg[3: 0] + 1 ] <= accumulator[3: 0];
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_LDAR : begin
                                    // Load accumulator with register
                                    accumulator <= Ri;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_SUBR : begin
                                    // Subtract accumulator from register
                                    { carry, accumulator } <= Ri - accumulator;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_ADDR : begin
                                    // Add register to accumulator
                                    { carry, accumulator } <= Ri + accumulator;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_STOR : begin
                                    // Store accumulator in register
                                    theRegisters[ instructionReg[3: 0] ] <= accumulator;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_LDVRNN : begin
                                    // Load register with number
                                    theRegisters[ instructionReg[3: 0] ] <= dataCounter;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BNERNN : begin
                                    // Branch if accumulator != Ri
                                    if ( accumulator != Ri ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BEQRNN : begin
                                    // Branch if accum == Ri
                                    if ( accumulator == Ri ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BGTRNN : begin
                                    // Branch if Ri < accum
                                    if ( Ri > accumulator ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BLTRNN : begin
                                    // Branch if Ri > accum
                                    if ( Ri < accumulator ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                            endcase

                        end
                        else begin
                            // Instructions that don't define a register
                            case ( instructionReg )
                                I_CLR : begin
                                    // Clear accumulator
                                    accumulator <= 8'b0;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_DEC : begin
                                    // Subtract 1 from accumulator
                                    { carry, accumulator } <= accumulator - 8'b1;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_INC : begin
                                    // Add 1 to accumulator
                                    { carry, accumulator } <= accumulator + 8'b1;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_RND : begin
                                    // Get a random number in accumulator
                                    accumulator <= rndNumber;
                                    rndRequest <= 1'b0;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_MOV : begin
                                    // Indirect reference memory with RC and copy result to accumulator
                                    if ( Ri < VERIPAC_RAM_LENGTH ) begin
                                        accumulator <= ram[ Ri ];
                                        theRegisters[ 4'hC ] <= theRegisters[ 4'hC ] + 1;
                                    end
                                    else begin
                                        accumulator <= 8'b0;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_INA : begin
                                    // Get keyboard input in accumulator
                                    accumulator <= keyboardReg;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_OTA : begin
                                    // Output accumulator to screen pointed by RB and inc RB
                                    screen[ Ri[4: 0] ] <= accumulator;
                                    theRegisters[ 4'hB ] <= theRegisters[ 4'hB ] + 1;
                                    if ( Ri[4: 0] == 5'h0A ) begin
                                        theRegisters[ 4'hB ][4: 0] <= 5'b0;
                                    end
                                    else begin
                                        theRegisters[ 4'hB ][4: 0] <= Ri[4: 0] + 1;
                                    end

                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_SIG : begin
                                    // Activate buzzer (see buzzer wire)
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_NOP : begin
                                    // Do nothing (NO-OP)
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_HALT : begin
                                    // Enter halt state
                                    ucState <= UCSTATE_HALT;
                                end
                                I_GTSNN : begin
                                    // Go to subroutine
                                    if ( stackPointer == VERIPAC_STACK_SIZE - 1 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        stack[ stackPointer ] <= programCounter;
                                        programCounter <= dataCounter;
                                        stackPointer <= stackPointer + 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                end
                                I_RET : begin
                                    // Return from subroutine
                                    if ( stackPointer == 0 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        programCounter <= stack[ stackPointer ];
                                        stackPointer <= stackPointer - 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                end
                                I_BDCNN : begin
                                    // Branch if accum != 0
                                    if ( accumulator != 8'b0 ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_GTONN : begin
                                    // Branch if accum == 0
                                    programCounter <= dataCounter;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BRZNN : begin
                                    // Unconditional branch
                                    if ( accumulator == 8'b0 ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_LDVSPNN : begin
                                    stackPointer <= dataCounter;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_LDVANN : begin
                                    accumulator <= dataCounter;
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_PSHA : begin
                                    if ( stackPointer == VERIPAC_STACK_SIZE - 1 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        stack[ stackPointer ] <= accumulator;
                                        stackPointer <= stackPointer + 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_POPA : begin
                                    if ( stackPointer == 0 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        accumulator <= stack[ stackPointer ];
                                        stackPointer <= stackPointer - 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_PSHR : begin
                                    if ( stackPointer == VERIPAC_STACK_SIZE - 1 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        stack[ stackPointer ] <= theRegisters[ dataCounter[3: 0] ];
                                        stackPointer <= stackPointer + 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_POPR : begin
                                    if ( stackPointer == 0 ) begin
                                        ucState <= UCSTATE_HALT;
                                    end
                                    else begin
                                        theRegisters[ dataCounter[3: 0] ] <= stack[ stackPointer ];
                                        stackPointer <= stackPointer - 1;
                                        ucState <= UCSTATE_FETCH1;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BNCNN : begin
                                    // Branch if carry == 0
                                    if ( carry == 1'b0 ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                                I_BCNN : begin
                                    // Branch if carry == 1
                                    if ( carry == 1'b1 ) begin
                                        programCounter <= dataCounter;
                                    end
                                    ucState <= UCSTATE_FETCH1;
                                end
                            endcase
                        end
                    end
                    //UCSTATE_HALT : begin
                    // Nada que hacer aqui
                    //end
                endcase
            end
            
            prevStep <= step;
        end
        
    end

endmodule
