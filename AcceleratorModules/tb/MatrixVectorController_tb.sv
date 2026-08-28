`timescale 1ns/1ps

module MatrixVectorController_tb;
    localparam int COLS = 4;
    localparam int ROWS = 3;
    localparam int COL_ADDR_WIDTH = (COLS <= 1) ? 1 : $clog2(COLS);
    localparam int ROW_ADDR_WIDTH = (ROWS <= 1) ? 1 : $clog2(ROWS);
    localparam int WEIGHT_COUNT = ROWS * COLS;
    localparam int WEIGHT_ADDR_WIDTH =
        (WEIGHT_COUNT <= 1) ? 1 : $clog2(WEIGHT_COUNT);
    localparam int TIMEOUT_CYCLES = 200;

    logic clk;
    logic rst_n;
    logic start;
    logic busy;
    logic done;

    logic        [COL_ADDR_WIDTH-1:0] activation_addr;
    logic signed [7:0]                activation_data;
    logic        [WEIGHT_ADDR_WIDTH-1:0] weight_addr;
    logic signed [7:0]                   weight_data;

    logic        [ROW_ADDR_WIDTH-1:0] output_addr;
    logic signed [31:0]               output_data;
    logic                             output_write;

    // These arrays model the memories surrounding the controller.
    logic signed [7:0]  activation_mem [0:COLS-1];
    logic signed [7:0]  weight_mem     [0:WEIGHT_COUNT-1];
    logic signed [31:0] output_mem     [0:ROWS-1];

    integer expected [0:ROWS-1];
    integer write_count;
    logic signed [7:0] random_activation;
    logic signed [7:0] random_weight;
    integer row_index;
    integer col_index;
    integer test_index;

    MatrixVectorController #(
        .WEIGHT_COLUMN_WIDTH (COLS),
        .WEIGHT_ROW_WIDTH    (ROWS)
    ) dut (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .busy            (busy),
        .done            (done),
        .activation_addr (activation_addr),
        .activation_data (activation_data),
        .weight_addr     (weight_addr),
        .weight_data     (weight_data),
        .output_addr     (output_addr),
        .output_data     (output_data),
        .output_write    (output_write)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // One-cycle synchronous-read memories. The addresses are sampled at a
    // rising edge, and the corresponding data appears just after that edge.
    // The output memory is always able to accept a write.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            activation_data <= 8'sd0;
            weight_data     <= 8'sd0;
            write_count     <= 0;
        end else begin
            activation_data <= activation_mem[activation_addr];
            weight_data     <= weight_mem[weight_addr];

            if (output_write) begin
                output_mem[output_addr] <= output_data;
                write_count             <= write_count + 1;
            end
        end
    end

    task automatic clear_outputs;
        integer clear_row;
        begin
            for (clear_row = 0; clear_row < ROWS; clear_row = clear_row + 1)
                output_mem[clear_row] = 32'sh7fff_ffff;
        end
    endtask

    task automatic calculate_expected;
        integer calc_row;
        integer calc_col;
        begin
            for (calc_row = 0; calc_row < ROWS; calc_row = calc_row + 1) begin
                expected[calc_row] = 0;
                for (calc_col = 0; calc_col < COLS; calc_col = calc_col + 1)
                    expected[calc_row] = expected[calc_row] +
                        $signed(weight_mem[calc_row * COLS + calc_col]) *
                        $signed(activation_mem[calc_col]);
            end
        end
    endtask

    task automatic run_and_check(input string test_name);
        integer writes_before;
        integer elapsed_cycles;
        integer check_row;
        begin
            clear_outputs();
            calculate_expected();
            writes_before = write_count;

            // A one-cycle start pulse begins the job.
            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            #1;
            if (!busy)
                $fatal(1, "%s: busy did not assert after start", test_name);
            @(negedge clk);
            start = 1'b0;

            elapsed_cycles = 0;
            while (!done && elapsed_cycles < TIMEOUT_CYCLES) begin
                @(posedge clk);
                #1;
                elapsed_cycles = elapsed_cycles + 1;
            end

            if (!done)
                $fatal(1, "%s: timed out after %0d cycles", test_name,
                       TIMEOUT_CYCLES);

            // The final output-memory write occurs on the edge that enters
            // FINISH. The #1 delays above allow nonblocking writes to settle.
            if (write_count != writes_before + ROWS)
                $fatal(1, "%s: expected %0d output writes, observed %0d",
                       test_name, ROWS, write_count - writes_before);

            for (check_row = 0; check_row < ROWS; check_row = check_row + 1) begin
                if (output_mem[check_row] !== expected[check_row]) begin
                    $error("%s row %0d: expected %0d, got %0d", test_name,
                           check_row, expected[check_row],
                           output_mem[check_row]);
                    $fatal(1);
                end
            end

            $display("%s: PASS (%0d cycles after start acceptance)",
                     test_name, elapsed_cycles);

            // FINISH produces a one-cycle done pulse, followed by IDLE.
            @(posedge clk);
            #1;
            if (done || busy)
                $fatal(1, "%s: controller did not return to idle", test_name);
        end
    endtask

    initial begin
        rst_n = 1'b0;
        start = 1'b0;

        for (row_index = 0; row_index < ROWS; row_index = row_index + 1)
            output_mem[row_index] = 32'sd0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Hand-calculated example:
        // x = [2, -1, 3, 4]
        // W = [[1, 2, 3, 4], [-1, 0, 1, 2], [5, -2, 3, -4]]
        // Expected y = [25, 9, 5].
        activation_mem[0] =  8'sd2;
        activation_mem[1] = -8'sd1;
        activation_mem[2] =  8'sd3;
        activation_mem[3] =  8'sd4;

        weight_mem[0]  =  8'sd1;
        weight_mem[1]  =  8'sd2;
        weight_mem[2]  =  8'sd3;
        weight_mem[3]  =  8'sd4;
        weight_mem[4]  = -8'sd1;
        weight_mem[5]  =  8'sd0;
        weight_mem[6]  =  8'sd1;
        weight_mem[7]  =  8'sd2;
        weight_mem[8]  =  8'sd5;
        weight_mem[9]  = -8'sd2;
        weight_mem[10] =  8'sd3;
        weight_mem[11] = -8'sd4;

        run_and_check("hand-calculated 3x4 matrix-vector");

        // Reuse the same hardware for several signed randomized jobs.
        for (test_index = 0; test_index < 20; test_index = test_index + 1) begin
            for (col_index = 0; col_index < COLS; col_index = col_index + 1) begin
                random_activation = 8'($urandom_range(0, 255) - 128);
                activation_mem[col_index] = 8'(random_activation);
            end

            for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
                for (col_index = 0; col_index < COLS; col_index = col_index + 1) begin
                    random_weight = 8'($urandom_range(0, 255) - 128);
                    weight_mem[row_index * COLS + col_index] = 8'(random_weight);
                end
            end

            run_and_check($sformatf("random job %0d", test_index));
        end

        $display("MatrixVectorController_tb: ALL TESTS PASS");
        $finish;
    end


    initial begin
        if ($test$plusargs("waves")) begin
            $dumpfile("MatrixVectorController_tb.vcd");
            $dumpvars(0, MatrixVectorController_tb);
        end
    end

endmodule
