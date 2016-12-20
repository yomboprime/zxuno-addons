`timescale 1ns / 1ps
`default_nettype none

module veripac9_zxuno (
    input wire clk,
    input wire [7:0] zxuno_addr,
    input wire zxuno_regrd,
    input wire zxuno_regwr,
    input wire [7:0] din,
    output reg [7:0] dout,
    output reg oe_n
    );

    parameter ZXUNO_DATA_REG = 8'hFA;
    parameter ZXUNO_STATUS_REG = 8'hFB;
    
    reg veripac_wr = 0;
    reg veripac_rd = 0;
    reg step = 0;
    reg [7: 0] veripac_addr = 8'b0;
    reg [7: 0] veripac_din;
    wire [7: 0] veripac_dout;
    
    veripac9 theVeripac9 (
        .clk(clk),
        .addr(veripac_addr),
        .rd(veripac_rd),
        .wr(veripac_wr),
        .din(veripac_din),
        .dout(veripac_dout)//,
        //.step
    );

    //(zxuno_addr == UARTDATA && zxuno_regrd == 1'b1);

    always @* begin
        oe_n = 1'b1;
        veripac_rd = 1'b0;
        dout = 8'hZZ;
        if (zxuno_addr == ZXUNO_DATA_REG && zxuno_regrd == 1'b1) begin
            dout = veripac_dout;
            veripac_rd = 1'b1;
            oe_n = 1'b0;
        end
        else if (zxuno_addr == ZXUNO_STATUS_REG && zxuno_regrd == 1'b1) begin
            dout = veripac_addr;
            oe_n = 1'b0;
        end
    end

    always @(posedge clk) begin
        if (zxuno_addr == ZXUNO_DATA_REG && zxuno_regwr == 1'b1 ) begin
            veripac_wr <= 1'b1;
            veripac_din <= din;
        end
        else begin
            veripac_wr <= 1'b0;
        end
        if (zxuno_addr == ZXUNO_STATUS_REG && zxuno_regwr == 1'b1 ) begin
            veripac_addr <= din;
        end
    end

endmodule
