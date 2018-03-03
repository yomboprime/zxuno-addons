/*
    Coprocesador v1.0 - 2 Enero 2017

    mcleod_Ideafix & yomboprime

*/


module mult_and_add_spectrum (
  input wire clk28,      // reloj de 28 MHz (el reloj maestro)
  input wire clkreg,     // el reloj de acceso a registros de E/S
  input wire [7:0] zxuno_regaddr,  // el registro de ZXUNO direccionado actualmente
  input wire zxuno_regaddr_changed, // a 1 durante un CLK para indicar que se acaba de cambiar el registro de direccion ZXUNO
  input wire zxuno_regrd,          // operacion de lectura en un registro ZXUNO
  input wire zxuno_regwr,          // operacion de escritura en un registro ZXUNO
  input wire [7:0] din,  // bus de entrada de datos desde el Z80
  output reg [7:0] dout, // bus de salida de datos hacia el Z80
  output reg oe_n        // a 0 cuando se ha seleccionado este periférico para lectura
  );

  parameter REGISTRO_PERIFERICO = 8'hC0; // elige un registro dentro de la zona de uso privado $C0 a $DF

  reg signed [15:0] a,b,c;
  wire signed [15:0] d;

  mult_and_add coprocesador (
    .clk(clk28),
    .a(a),
    .b(b),
    .c(c),
    .d(d)
  );

  reg accediendo_al_puerto = 1'b0;
  reg byte_devuelto = 1'b0; // indica qué cacho de D se devuelve
  always @(posedge clkreg) begin
    if (zxuno_regaddr_changed == 1'b1 && zxuno_regaddr == REGISTRO_PERIFERICO) begin
      byte_devuelto <= 1'b0;  // si acabamos de acceder a este registro, reseteamos el ff que determina qué cacho se devuelve
    end
    else if (zxuno_regaddr == REGISTRO_PERIFERICO && (zxuno_regwr == 1'b1 || zxuno_regrd==1'b1) && accediendo_al_puerto == 1'b0) begin
      accediendo_al_puerto <= 1'b1;  // flip flop para evitar hacer esta operación muchas veces mientras dura el ciclo de escritura E/S
      if (zxuno_regwr == 1'b1) begin
        a[7:0] <= a[15:8];           // se empujan todos los datos: din -> hi(C) -> low(C) -> hi(B) -> low(B) -> hi(A) -> low(A)
        a[15:8] <= b[7:0];           // así, la secuencia de escritura es: low(A),hi(A),low(B),hi(B),low(C),hi(C)
        b[7:0] <= b[15:8];
        b[15:8] <= c[7:0];
        c[7:0] <= c[15:8];
        c[15:8] <= din;
        byte_devuelto <= 1'b0; // tras una escritura, la siguiente lectura devolverá la parte baja de D
      end
      else begin
        case (byte_devuelto)
          1'b0: dout <= d[7:0];
          1'b1: dout <= d[15:8];
        endcase
        byte_devuelto <= ! byte_devuelto; // tras devolver un cacho de D, se bascula para en la siguiente lectura, devolver el otro cacho
      end
    end
    else begin
      accediendo_al_puerto <= 1'b0;
    end
  end

  always @* begin
    if (zxuno_regaddr == REGISTRO_PERIFERICO && zxuno_regrd == 1'b1)
      oe_n = 1'b0;
    else
      oe_n = 1'b1;
  end
endmodule

// d = a * b + c
// (9.7) fixed point 2's complement
module mult_and_add (
  input wire clk,
  input wire signed [15:0] a,
  input wire signed [15:0] b,
  input wire signed [15:0] c,
  output reg signed [15:0] d
  );
  
  wire signed [31:0] product;
  assign product = a * b;

  always @(posedge clk) begin
    d <= { product }[22:7] + c;
  end
endmodule
