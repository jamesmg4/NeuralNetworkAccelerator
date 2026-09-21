`timescale 1ns/1ps

module INT8_MACPipeline (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        clear,
    input  logic        enable,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    output logic signed [31:0] acc
);

    logic signed [15:0] product;
    logic product_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= 32'sd0;
            product <= 16'sd0;
            product_valid <= 1'b0;
        end else if (clear) begin
            acc <= 32'sd0;
            product <= 16'sd0;
            product_valid <= 1'b0;
        end else begin
            if(product_valid) begin
                acc <= acc + product;
            end
            if(enable) begin
                product <= a * b;
            end
            product_valid <= enable;
        end
    end

endmodule
