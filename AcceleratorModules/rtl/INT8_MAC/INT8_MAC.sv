`timescale 1ns/1ps

module INT8_MAC (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic        enable,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    output logic signed [31:0] acc
);

    logic signed [15:0] product;

    assign product = a * b;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 32'sd0;
        end else if (clear) begin
            acc <= 32'sd0;
        end else if (enable) begin
            acc <= acc + {{16{product[15]}}, product};
        end
    end

endmodule
