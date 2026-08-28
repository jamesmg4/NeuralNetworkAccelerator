`timescale 1ns/1ps

module INT8_MAC_tb;
    logic               clk;
    logic               rst_n;
    logic               clear;
    logic               enable;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic signed [31:0] acc;

    INT8_MAC dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .clear  (clear),
        .enable (enable),
        .a      (a),
        .b      (b),
        .acc    (acc)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_acc(
        input logic signed [31:0] expected,
        input string test_name
    );
        #1;
        if (acc !== expected) begin
            $error("%s: expected acc=%0d, got acc=%0d", test_name,
                   expected, acc);
            $fatal(1);
        end
    endtask

    task automatic accumulate(
        input logic signed [7:0] operand_a,
        input logic signed [7:0] operand_b,
        input logic signed [31:0] expected,
        input string test_name
    );
        @(negedge clk);
        a      = operand_a;
        b      = operand_b;
        enable = 1'b1;
        clear  = 1'b0;
        @(posedge clk);
        check_acc(expected, test_name);
    endtask

    initial begin
        rst_n  = 1'b0;
        clear  = 1'b0;
        enable = 1'b0;
        a      = 8'sd0;
        b      = 8'sd0;

        repeat (2) @(posedge clk);
        check_acc(32'sd0, "reset");
        @(negedge clk);
        rst_n = 1'b1;

        accumulate(8'sd3, 8'sd4, 32'sd12, "positive product");
        accumulate(-8'sd5, 8'sd7, -32'sd23, "negative product");

        @(negedge clk);
        enable = 1'b0;
        a      = 8'sd100;
        b      = 8'sd100;
        @(posedge clk);
        check_acc(-32'sd23, "disabled MAC holds its value");

        // Clear has priority if clear and enable are asserted together.
        @(negedge clk);
        clear  = 1'b1;
        enable = 1'b1;
        @(posedge clk);
        check_acc(32'sd0, "clear priority");

        accumulate(-8'sd128, -8'sd128, 32'sd16384,
                   "largest positive INT8 product");
        accumulate(8'sd127, -8'sd128, 32'sd128,
                   "signed accumulation at INT8 limits");

        // Verify that the active-low reset clears the accumulator immediately.
        @(negedge clk);
        enable = 1'b0;
        rst_n  = 1'b0;
        check_acc(32'sd0, "asynchronous reset");

        $display("INT8_MAC_tb: PASS");
        $finish;
    end

endmodule
