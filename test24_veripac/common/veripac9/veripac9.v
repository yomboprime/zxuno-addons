`timescale 1ns / 1ps
`default_nettype none

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
    
    localparam UCSTATE_FETCH1 = 2'b00;
    localparam UCSTATE_FETCH2 = 2'b01;
    localparam UCSTATE_EXEC = 2'b10;
    localparam UCSTATE_HALT = 2'b11;
 
    integer i;
 
    // The RAM
    reg [7: 0] ram[0: 255];
    initial begin
        for (i=0;i<255;i=i+1)
            ram[i] = 8'b0;
    end
    
    // Screen Buffer
    reg [7: 0] screen[0: VERIPAC_SCREEN_LENGTH-1];
    initial begin
        for (i=0;i<VERIPAC_SCREEN_LENGTH;i=i+1)
            screen[i] = 8'b0;
    end
    
    // The registers
    reg [7: 0] theRegisters[0: VERIPAC_NUM_REGS-1];
    initial begin
        for (i=0;i<VERIPAC_NUM_REGS;i=i+1)
            theRegisters[i] = 8'b0;
    end
    
    // Special registers
    reg [7: 0] keyboardReg = 8'b0;
    reg [7: 0] accumulator = 8'b0;
    reg [7: 0] programCounter = 8'b0;
    reg [7: 0] instructionReg = 8'b0;
    reg [7: 0] dataCounter = 8'b0;
    reg [1: 0] ucState = UCSTATE_FETCH1;
    
    // Other signals
    reg prevStep = 1'b0;
    
    reg keyPressed = 1'b0;
    reg keyWanted = 1'b0;

    reg buzzer = 1'b0;

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
                        keyPressed <= 1'b1;
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
                programCounter <= 0;
                ucState <= UCSTATE_FETCH1;
            end
            else if ( step == 1'b1 && prevStep == 1'b0 ) begin
                programCounter <= programCounter + 1;
                ucState <= ucState + 1;
            end
        end
        
        prevStep <= step;
    end

endmodule
