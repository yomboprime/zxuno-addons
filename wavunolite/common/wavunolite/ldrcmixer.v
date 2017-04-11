`timescale 1ns / 1ps
`default_nettype none

module ldrcmixer(
    input wire clk,
    input wire [7: 0] audioA,
    input wire [7: 0] audioB,
    output reg [7: 0] audioOut
    );

parameter lookupTableSize = 256;

reg [7:0] ldrcLookupTable[0: lookupTableSize-1];

// Read the LUT from file. It contains the positive half of the mixing function.
initial begin
    $readmemh( "compressorLUT.list", ldrcLookupTable, 0, lookupTableSize );
end

reg [7: 0] audioAreg = 8'd128;
reg [7: 0] audioBreg = 8'd128;
reg [8: 0] sum = 9'd256;

always @( posedge clk ) begin

	audioAreg <= audioA;
	audioBreg <= audioB;

    sum <= audioAreg + audioBreg;

    // If input is positive
    if ( sum[8] == 1'b1 ) begin

        audioOut <= { 1'b1, ldrcLookupTable[ sum[7: 0] ][6: 0] };

    end
    else begin

        // else (input is negative), invert input and LUT value

        audioOut <= { 1'b0, 8'h7F - ldrcLookupTable[ 8'hFF - sum[7: 0] ][6: 0] };

    end
        

end
    
endmodule
