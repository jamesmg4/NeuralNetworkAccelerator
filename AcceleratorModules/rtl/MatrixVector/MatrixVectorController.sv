`timescale 1ns/1ps

// Computes one matrix-vector multiplication:
//
//     output[row] = sum(weight[row][col] * activation[col])
//
// The weight matrix is stored in row-major order and has dimensions:
//
//     WEIGHT_ROW_WIDTH rows x WEIGHT_COLUMN_WIDTH columns
//
// The activation vector contains WEIGHT_COLUMN_WIDTH elements and the output vector
// contains WEIGHT_ROW_WIDTH elements.
//
// This first version should use one DotProductController. It calculates one
// output row at a time rather than calculating several rows in parallel.
module MatrixVectorController #(
    parameter int WEIGHT_COLUMN_WIDTH  = 4,
    parameter int WEIGHT_ROW_WIDTH = 3,

    // These widths are derived here, rather than inside the module body,
    // because they are needed while elaborating the port declarations.
    // The conditional guarantees a legal one-bit port when a size equals one.
    localparam int COL_WIDTH =
        (WEIGHT_COLUMN_WIDTH <= 1) ? 1 : $clog2(WEIGHT_COLUMN_WIDTH),
    localparam int ROW_WIDTH =
        (WEIGHT_ROW_WIDTH <= 1) ? 1 : $clog2(WEIGHT_ROW_WIDTH),
    localparam int WEIGHT_COUNT = WEIGHT_COLUMN_WIDTH * WEIGHT_ROW_WIDTH,
    localparam int WEIGHT_ADDR_WIDTH =
        (WEIGHT_COUNT <= 1) ? 1 : $clog2(WEIGHT_COUNT)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         start,
    output logic                         busy,
    output logic                         done,

    output logic        [COL_WIDTH-1:0]  activation_addr,
    input  logic signed [7:0]            activation_data,

    output logic [WEIGHT_ADDR_WIDTH-1:0] weight_addr,
    input  logic signed [7:0]            weight_data,

    output logic        [ROW_WIDTH-1:0]  output_addr,
    output logic signed [31:0]           output_data,
    output logic                         output_write
);

        typedef enum logic [2:0] {
        IDLE,
        FETCH,
        SEND,
        WAIT_RESULT,
        FINISH
    } state_t;


    state_t current_state;
    state_t next_state;


    logic [ROW_WIDTH-1:0] row;
    logic [COL_WIDTH-1:0] col;

    localparam logic [COL_WIDTH-1:0] MAX_COL = COL_WIDTH'(WEIGHT_COLUMN_WIDTH - 1);
    localparam logic [ROW_WIDTH-1:0] MAX_ROW = ROW_WIDTH'(WEIGHT_ROW_WIDTH - 1);



    //checking if WEIGHT_COLUMN_WIDTH fits in 16 bits
    initial begin
        if (WEIGHT_COLUMN_WIDTH < 1) begin
            $fatal(1, "WEIGHT_COLUMN_WIDTH must be at least 1");
        end

        if (WEIGHT_COLUMN_WIDTH > 16'hFFFF) begin
            $fatal(1,"WEIGHT_COLUMN_WIDTH=%0d exceeds the 16-bit vec_len limit", WEIGHT_COLUMN_WIDTH);
        end

        if (WEIGHT_ROW_WIDTH < 1) begin
            $fatal(1, "WEIGHT_ROW_WIDTH must be at least 1");
        end
    end 

    // Signals driven by this matrix-vector controller
    logic dotp_in_valid;
    logic dotp_acc_ready;

    // Signals driven by the instantiated dot-product controller
    logic dotp_in_ready;
    logic dotp_acc_valid;
    logic signed [31:0] dotp_acc;

    // Successful handshake events
    logic dotp_input_accepted;
    logic dotp_result_accepted;    
    

    DotProductController dotp (
        .clk(clk),
        .rst_n(rst_n),

        .in_valid(dotp_in_valid),
        .in_ready(dotp_in_ready),
        .a(activation_data),
        .b(weight_data),
        .vec_len(WEIGHT_COLUMN_WIDTH[15:0]),

        .acc(dotp_acc),
        .acc_valid(dotp_acc_valid),
        .acc_ready(dotp_acc_ready)
    );

    assign dotp_input_accepted = dotp_in_valid && dotp_in_ready;

    assign dotp_result_accepted = dotp_acc_valid && dotp_acc_ready;

    logic start_accepted;

    assign start_accepted =
        start && (current_state == IDLE);


    //sequentail logic

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
            row <= '0;
            col <= '0;
        end else begin
            current_state <= next_state;
            if(start_accepted) begin
                row <= '0;
                col <= '0;
            end else begin
                if (dotp_input_accepted) begin
                    if (col == MAX_COL) begin
                        col <= '0;
                    end else begin
                        col <= col + 1;
                    end
                end
                if (dotp_result_accepted) begin
                    if (row == MAX_ROW) begin
                        row <= '0;
                    end else begin
                        row <= row + 1;
                    end
                end
            end 
        end
    end

    always_comb begin
        next_state = current_state;
        busy = 1'b0;
        done = 1'b0;
        dotp_in_valid = 1'b0;
        dotp_acc_ready = 1'b0;
        output_write = 1'b0;
        activation_addr = col;
        weight_addr = WEIGHT_ADDR_WIDTH'(row * WEIGHT_COLUMN_WIDTH + col);
        output_addr = row;
        output_data = dotp_acc;
        
        case (current_state)
            IDLE: begin
                if (start_accepted) begin
                    next_state = FETCH;
                end
            end
            FETCH: begin
                    busy = 1'b1;
                    next_state = SEND;
            end
            SEND: begin
                busy = 1'b1;
                dotp_in_valid = 1'b1;
                if (dotp_input_accepted) begin
                    if (col == MAX_COL) begin
                        next_state = WAIT_RESULT;
                    end else begin
                        next_state = FETCH;
                    end
                end
            end
            WAIT_RESULT: begin
                busy = 1'b1;
                dotp_acc_ready = 1'b1;
                if (dotp_result_accepted) begin
                    output_write = 1'b1;
                    if (row == MAX_ROW) begin
                        next_state = FINISH;
                    end else begin
                        next_state = FETCH;
                    end
                end
            end
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

       
endmodule
