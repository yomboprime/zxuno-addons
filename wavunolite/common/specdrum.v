`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    23:58:32 02/03/2017 
// Design Name: 
// Module Name:    specdrum. Perhaps the simplest device ever written for the ZX-UNO
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
module specdrum (
   input wire clk,
   input wire rst_n,
   input wire [7:0] a,
   input wire iorq_n,
   input wire wr_n,
   input wire [7:0] d,
   output reg [7:0] specdrum_out
   );
   
   initial specdrum_out = 8'h00;
   always @(posedge clk) begin
      if (rst_n == 1'b0)
         specdrum_out <= 8'h00;
      else if (iorq_n == 1'b0 && a == 8'hDF && wr_n == 1'b0)
         specdrum_out <= d;
   end
endmodule
