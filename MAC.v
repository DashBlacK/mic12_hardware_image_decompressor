/*
Copyright by Shahbaaz Shakil and Mushfiqur Rahman
COMP ENG 3DQ5 - Dr. Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

// This module serves as a Multiply-Accumulate (MAC) unit
module MAC (
    input logic Clock_50,                   // 50 MHz clock
    input logic Resetn,

    input logic clear,
    input logic [31:0] operand1,
    input logic [31:0] operand2,
    output logic [63:0] macOutput
);

logic [63:0] multOut;
logic [63:0] accumulate;

assign multOut = operand1 *operand2;
assign macOutput = accumulate;

always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if (Resetn == 1'b0) begin
		accumulate <= 64'd0;
	end else begin
        if (clear == 1'b1) begin
            accumulate <= 64'd0;
        end else begin
            accumulate <= accumulate + multOut;
        end
    end
end

/* always_ff @ (posedge Clock_50 or negedge Resetn) begin
	if ((Resetn == 1'b0) | (clear == 1'b1)) begin
		accumulate <= 64'd0;
	end else begin
        accumulate <= accumulate + multOut;
    end
end */

endmodule
