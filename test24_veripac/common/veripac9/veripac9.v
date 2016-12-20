`timescale 1ns / 1ps
`default_nettype none

module veripac9 (
    input wire clk,
    input wire [7:0] addr,
    input wire rd,
    input wire wr,
    input wire [7:0] din,
    output reg [7:0] dout//,
    //input wire step
    );
    
    reg [7: 0] ram[0: 255];
    integer i;
    initial begin
        for (i=0;i<255;i=i+1)
            ram[i] = i;
    end

    //(zxuno_addr == UARTDATA && zxuno_regrd == 1'b1);

    always @* begin
        dout = 8'hZZ;
        if (rd == 1'b1) begin
            dout = ram[ addr ];
        end
    end

    always @(posedge clk) begin
        if (wr == 1'b1) begin
            ram[ addr ] = din;
        end
    end

endmodule
