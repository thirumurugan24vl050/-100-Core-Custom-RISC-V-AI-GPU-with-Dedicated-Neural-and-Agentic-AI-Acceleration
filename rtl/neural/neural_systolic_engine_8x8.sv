//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: neural_systolic_engine_8x8.sv
// Description: 8x8 2D Systolic Tensor GEMM Accelerator with Skew/Deskew Logic.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module neural_systolic_engine_8x8 import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Command Handshake
    input  logic                   start_gemm,
    input  logic                   start_weight_load,
    output logic                   engine_busy,
    output logic                   gemm_done,

    // Weight Matrix Input (8x8 INT8 = 64 bytes)
    input  logic signed [7:0]      weight_matrix [7:0][7:0],

    // Activation Stream Input (8 lanes x INT8)
    input  logic                   act_valid,
    input  logic signed [7:0]      act_vector [7:0],

    // Output Matrix C Result (8 lanes x 32-bit accumulators)
    output logic                   result_valid,
    output logic signed [31:0]     result_matrix [7:0][7:0]
);

    // PE Interconnection Wires
    logic signed [7:0]  pe_act_wire   [7:0][8:0]; // [row][col]
    logic signed [31:0] pe_psum_wire  [8:0][7:0]; // [row][col]

    // Skewing registers for activations (Row i delayed by i cycles)
    logic signed [7:0] act_skew [7:0][7:0];

    // FSM States
    typedef enum logic [2:0] {
        IDLE        = 3'b000,
        LOAD_WEIGHT = 3'b001,
        COMPUTE     = 3'b010,
        DRAIN       = 3'b011,
        DONE        = 3'b100
    } state_e;

    state_e state, next_state;
    logic [5:0] cycle_counter;

    // Load weight enable per column
    logic pe_load_weight_en;
    logic pe_compute_en;
    logic pe_accum_clr;

    assign engine_busy = (state != IDLE);
    assign gemm_done   = (state == DONE);

    // FSM State Transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= IDLE;
            cycle_counter <= '0;
        end else begin
            state <= next_state;
            if (state != next_state) begin
                cycle_counter <= '0;
            end else if (state != IDLE && state != DONE) begin
                cycle_counter <= cycle_counter + 6'd1;
            end
        end
    end

    // Next State Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_weight_load) next_state = LOAD_WEIGHT;
                else if (start_gemm)   next_state = COMPUTE;
            end
            LOAD_WEIGHT: begin
                if (cycle_counter >= 6'd8) next_state = IDLE;
            end
            COMPUTE: begin
                // 8 cycles input + 8 cycles array traversal + 8 cycles drain = 24 cycles
                if (cycle_counter >= 6'd24) next_state = DRAIN;
            end
            DRAIN: begin
                if (cycle_counter >= 6'd8) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Control signals
    assign pe_load_weight_en = (state == LOAD_WEIGHT);
    assign pe_compute_en     = (state == COMPUTE || state == DRAIN);
    assign pe_accum_clr      = (state == IDLE && start_gemm);
    assign result_valid      = (state == DRAIN || state == DONE);

    // Activation Skewing Delay Pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < 8; r++) begin
                for (int d = 0; d < 8; d++) begin
                    act_skew[r][d] <= '0;
                end
            end
        end else if (act_valid || pe_compute_en) begin
            for (int r = 0; r < 8; r++) begin
                act_skew[r][0] <= act_vector[r];
                for (int d = 1; d <= r; d++) begin
                    act_skew[r][d] <= act_skew[r][d-1];
                end
            end
        end
    end

    // Connect skewed activations to PE inputs
    always_comb begin
        for (int r = 0; r < 8; r++) begin
            pe_act_wire[r][0] = (r == 0) ? act_vector[0] : act_skew[r][r];
        end
        for (int c = 0; c < 8; c++) begin
            pe_psum_wire[0][c] = 32'sd0; // Top boundary partial sums are 0
        end
    end

    // Instantiate 8x8 Grid of Processing Elements
    genvar r_idx, c_idx;
    generate
        for (r_idx = 0; r_idx < 8; r_idx++) begin : gen_row
            for (c_idx = 0; c_idx < 8; c_idx++) begin : gen_col
                systolic_pe u_pe (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .load_weight_en (pe_load_weight_en),
                    .compute_en     (pe_compute_en),
                    .accum_clr      (pe_accum_clr),
                    .act_in         (pe_act_wire[r_idx][c_idx]),
                    .act_out        (pe_act_wire[r_idx][c_idx+1]),
                    .psum_in        (pe_psum_wire[r_idx][c_idx]),
                    .psum_out       (pe_psum_wire[r_idx+1][c_idx]),
                    .weight_in      (weight_matrix[r_idx][c_idx])
                );
            end
        end
    endgenerate

    // Capture Output Matrix C Results from bottom row PEs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int r = 0; r < 8; r++) begin
                for (int c = 0; c < 8; c++) begin
                    result_matrix[r][c] <= '0;
                end
            end
        end else if (state == DRAIN || state == DONE) begin
            for (int c = 0; c < 8; c++) begin
                result_matrix[cycle_counter[2:0]][c] <= pe_psum_wire[8][c];
            end
        end
    end

endmodule
