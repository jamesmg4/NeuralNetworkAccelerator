`timescale 1ns/1ps

module MatrixVectorController_tb #(
    parameter int COLS = 4,
    parameter int ROWS = 3,
    parameter int RANDOM_JOBS = 10
);
    localparam int COL_ADDR_WIDTH = (COLS <= 1) ? 1 : $clog2(COLS);
    localparam int ROW_ADDR_WIDTH = (ROWS <= 1) ? 1 : $clog2(ROWS);
    localparam int WEIGHT_COUNT = ROWS * COLS;
    localparam int WEIGHT_ADDR_WIDTH =
        (WEIGHT_COUNT <= 1) ? 1 : $clog2(WEIGHT_COUNT);
    localparam int EXPECTED_LATENCY = ROWS * (2 * COLS + 1);
    localparam int TIMEOUT_CYCLES = EXPECTED_LATENCY + 20;

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

    // Per-job performance counters. Measurement begins when start is accepted
    // and ends when done asserts. These exist only in the testbench and do not
    // add hardware to the synthesized accelerator.
    logic   measurement_active;
    integer total_latency_cycles;
    integer busy_cycles;
    integer accepted_operand_pairs;
    integer measured_output_writes;

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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            measurement_active     <= 1'b0;
            total_latency_cycles   <= 0;
            busy_cycles            <= 0;
            accepted_operand_pairs <= 0;
            measured_output_writes <= 0;
        end else if (dut.start_accepted) begin
            measurement_active     <= 1'b1;
            total_latency_cycles   <= 0;
            busy_cycles            <= 0;
            accepted_operand_pairs <= 0;
            measured_output_writes <= 0;
        end else if (measurement_active) begin
            // done is combinational from FINISH. The edge that enters FINISH
            // has already counted the final busy/output-write cycle; the next
            // edge observes done and stops measurement without adding a cycle.
            if (done) begin
                measurement_active <= 1'b0;
            end else begin
                total_latency_cycles <= total_latency_cycles + 1;

                if (busy)
                    busy_cycles <= busy_cycles + 1;

                if (dut.dotp_input_accepted)
                    accepted_operand_pairs <= accepted_operand_pairs + 1;

                if (output_write)
                    measured_output_writes <= measured_output_writes + 1;
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
        real mac_utilization;
        real products_per_cycle;
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

            if (accepted_operand_pairs != WEIGHT_COUNT)
                $fatal(1, "%s: expected %0d accepted operand pairs, observed %0d",
                       test_name, WEIGHT_COUNT, accepted_operand_pairs);

            if (measured_output_writes != ROWS)
                $fatal(1, "%s: measurement expected %0d output writes, observed %0d",
                       test_name, ROWS, measured_output_writes);

            if (total_latency_cycles != elapsed_cycles)
                $fatal(1, "%s: latency counters disagree: counter=%0d task=%0d",
                       test_name, total_latency_cycles, elapsed_cycles);

            if (total_latency_cycles != EXPECTED_LATENCY)
                $fatal(1, "%s: expected latency=%0d cycles, observed=%0d cycles",
                       test_name, EXPECTED_LATENCY, total_latency_cycles);

            for (check_row = 0; check_row < ROWS; check_row = check_row + 1) begin
                if (output_mem[check_row] !== expected[check_row]) begin
                    $error("%s row %0d: expected %0d, got %0d", test_name,
                           check_row, expected[check_row],
                           output_mem[check_row]);
                    $fatal(1);
                end
            end

            mac_utilization = 100.0 * $itor(accepted_operand_pairs) /
                              $itor(busy_cycles);
            products_per_cycle = $itor(accepted_operand_pairs) /
                                 $itor(total_latency_cycles);

            $display("%s: PASS", test_name);
            $display("  latency=%0d cycles, busy=%0d cycles, accepted pairs=%0d, output writes=%0d",
                     total_latency_cycles, busy_cycles,
                     accepted_operand_pairs, measured_output_writes);
            $display("  MAC utilization=%0.2f%%, products/cycle=%0.4f",
                     mac_utilization, products_per_cycle);

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

        // Dimension-independent deterministic data. Values remain within INT8
        // for every configuration in the baseline parameter sweep.
        for (col_index = 0; col_index < COLS; col_index = col_index + 1)
            activation_mem[col_index] = 8'(col_index - 2);

        for (row_index = 0; row_index < ROWS; row_index = row_index + 1) begin
            for (col_index = 0; col_index < COLS; col_index = col_index + 1)
                weight_mem[row_index * COLS + col_index] =
                    8'((row_index + 1) * (col_index + 1) - 4);
        end

        run_and_check($sformatf("deterministic %0dx%0d matrix-vector",
                                ROWS, COLS));

        // Reuse the same hardware for several signed randomized jobs.
        for (test_index = 0; test_index < RANDOM_JOBS;
             test_index = test_index + 1) begin
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
