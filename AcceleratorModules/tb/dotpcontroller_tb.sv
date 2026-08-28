`timescale 1ns/1ps

module dotpcontroller_tb;
    logic               clk;
    logic               rst_n;
    logic               in_valid;
    logic               in_ready;
    logic signed [7:0]  a;
    logic signed [7:0]  b;
    logic        [15:0] vec_len;
    logic signed [31:0] acc;
    logic               acc_valid;
    logic               acc_ready;

    integer expected;
    integer random_a;
    integer random_b;
    integer i;

    DotProductController dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .a         (a),
        .b         (b),
        .vec_len   (vec_len),
        .acc       (acc),
        .acc_valid (acc_valid),
        .acc_ready (acc_ready)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic reset_dut;
        begin
            @(negedge clk);
            rst_n     = 1'b0;
            in_valid  = 1'b0;
            acc_ready = 1'b0;
            repeat (2) @(posedge clk);
            #1;
            if (acc !== 32'sd0 || acc_valid !== 1'b0)
                $fatal(1, "reset did not clear the controller");
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    task automatic send_pair(
        input logic signed [7:0] operand_a,
        input logic signed [7:0] operand_b,
        input logic        [15:0] length
    );
        begin
            @(negedge clk);
            a         = operand_a;
            b         = operand_b;
            vec_len   = length;
            in_valid  = 1'b1;

            while (!in_ready)
                @(negedge clk);

            @(posedge clk);
            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    task automatic check_result(
        input logic signed [31:0] expected_result,
        input string test_name
    );
        begin
            #1;
            if (!acc_valid || acc !== expected_result) begin
                $error("%s: expected valid result %0d, got valid=%0b acc=%0d",
                       test_name, expected_result, acc_valid, acc);
                $fatal(1);
            end
        end
    endtask

    task automatic consume_result;
        begin
            @(negedge clk);
            acc_ready = 1'b1;
            @(posedge clk);
            #1;
            if (acc_valid || !in_ready || acc !== 32'sd0)
                $fatal(1, "result handshake did not return controller to IDLE");
            @(negedge clk);
            acc_ready = 1'b0;
        end
    endtask

    initial begin
        rst_n     = 1'b1;
        in_valid  = 1'b0;
        acc_ready = 1'b0;
        a          = 8'sd0;
        b          = 8'sd0;
        vec_len    = 16'd0;

        reset_dut();

        // Three elements, including signed operands and bubbles between pairs.
        send_pair(8'sd2, 8'sd3, 16'd3);
        repeat (2) @(posedge clk);
        send_pair(-8'sd4, 8'sd5, 16'd3);
        send_pair(-8'sd3, -8'sd2, 16'd3);
        check_result(-32'sd8, "three-element signed dot product");

        if (in_ready)
            $fatal(1, "controller accepted input while a result was pending");

        // Hold backpressure for several cycles; valid and data must remain stable.
        repeat (3) begin
            @(posedge clk);
            check_result(-32'sd8, "output backpressure");
        end
        consume_result();

        // A vector of length one must include its first and only input pair.
        send_pair(8'sd127, -8'sd128, 16'd1);
        check_result(-32'sd16256, "single-element dot product");
        consume_result();

        // Randomized signed vector checked against a software accumulator.
        expected = 0;
        for (i = 0; i < 32; i = i + 1) begin
            random_a = $urandom_range(0, 255) - 128;
            random_b = $urandom_range(0, 255) - 128;
            expected = expected + random_a * random_b;
            send_pair(random_a, random_b, 16'd32);
        end
        check_result(expected, "randomized 32-element dot product");
        consume_result();

        // Reset while a vector is partially accumulated, then start cleanly.
        send_pair(8'sd10, 8'sd10, 16'd3);
        send_pair(8'sd10, 8'sd10, 16'd3);
        reset_dut();
        send_pair(-8'sd8, 8'sd4, 16'd1);
        check_result(-32'sd32, "reset during accumulation");

        $display("dotpcontroller_tb: PASS");
        $finish;
    end

endmodule
