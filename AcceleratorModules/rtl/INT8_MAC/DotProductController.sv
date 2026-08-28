`timescale 1ns/1ps

module DotProductController (
    input  logic               clk,
    input  logic               rst_n,

    input  logic               in_valid, // says that a, b and vec_len have valid data
    output logic               in_ready, // means the dot product controller is waiting for either the first pair or the next pair of the current dot product.
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    input  logic        [15:0] vec_len,

    output logic signed [31:0] acc,
    output logic               acc_valid, // controller has finished a dot product (1 is yes, 0 no)
    input  logic               acc_ready // driven by matrix controller to say that it is ready for the accumulation
);

    typedef enum logic [1:0] {
        IDLE = 2'd0,
        MAC  = 2'd1,
        DONE = 2'd2
    } state_t;

    state_t current_state;
    state_t next_state;

    logic        [15:0] count;
    logic        [15:0] len_reg;
    logic signed [31:0] mac_acc;
    logic                mac_clear;
    logic                mac_enable;
    logic                input_fire;
    logic                output_fire;
    logic        [16:0] next_element_count;

    assign in_ready           = (current_state == IDLE) || (current_state == MAC);
    assign acc_valid          = (current_state == DONE);
    assign acc                = mac_acc;

    assign input_fire         = in_valid && in_ready; // mac_enable
    assign output_fire        = acc_valid && acc_ready; // mac_clear 
    assign mac_enable         = input_fire;
    assign mac_clear          = output_fire;
    assign next_element_count = {1'b0, count} + 17'd1;

    INT8_MAC mac (
        .clk    (clk),
        .rst_n  (rst_n),
        .clear  (mac_clear),
        .enable (mac_enable),
        .a      (a),
        .b      (b),
        .acc    (mac_acc)
    );


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count         <= 16'd0;
            len_reg       <= 16'd0;
       end else begin
            current_state <= next_state;

            if (current_state == IDLE && input_fire) begin
                len_reg <= vec_len;
                count   <= 16'd1;
            end else if (current_state == MAC && input_fire) begin
                count <= count + 16'd1;
            end else if (output_fire) begin
                count   <= 16'd0;
                len_reg <= 16'd0;
            end
        end
    end

    always_comb begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (input_fire) begin
                    // A zero-length vector cannot contain an input pair. Treat an
                    // invalid length of zero as a one-element vector so the block
                    // cannot lock up waiting for data that should not exist.
                    if (vec_len <= 16'd1)
                        next_state = DONE;
                    else
                        next_state = MAC;

                 end
            end

            MAC: begin
                if (input_fire &&
                    (next_element_count >= {1'b0, len_reg}))
                    next_state = DONE;
            end
            DONE: begin
                if (output_fire)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule
