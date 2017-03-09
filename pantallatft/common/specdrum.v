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
   output reg [7:0] specdrum_left,
   output reg [7:0] specdrum_right
   );

   reg [7:0] regsdrum = 8'h00;
   // pseudo estereo usando un delay de 256 muestras
   // (alrededor de 10 ms de retraso)
   reg [7:0] delay[0:255];
   reg [7:0] dmuestra;
   reg [7:0] idxwrite = 8'd0;
   reg [9:0] cnt = 10'd0; // 1 muestra por cada 1024 ciclos de reloj clk (28 MHz / 1024)
   
   initial begin
      specdrum_left = 8'h00;
      specdrum_right = 8'h00;
   end
   
   always @(posedge clk) begin
      if (rst_n == 1'b0)
         regsdrum <= 8'h00;
      else if (iorq_n == 1'b0 && a == 8'hDF && wr_n == 1'b0)
         regsdrum <= d;
   end
   
   always @(posedge clk) begin
      cnt <= cnt + 10'd1;
      case (cnt)
        10'd0: delay[idxwrite] <= regsdrum;
        10'd1: idxwrite <= idxwrite + 8'd1;
        10'd2: dmuestra <= delay[idxwrite];
        10'd3: begin
                specdrum_left <= regsdrum;
                specdrum_right <= dmuestra;
              end
      endcase
   end
        
endmodule
