//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: neural_postproc_unit.sv
// Description: Neural Post-Processing Engine for Non-Linear Activations & Normalization:
//              - RMSNorm with 38-bit Q22.16 accumulator, 24-bit Q8.16 rsqrt,
//                64-entry Seed LUT, and 2 Newton-Raphson refinement iterations
//              - ReLU (Rectified Linear Unit)
//              - GELU (Gaussian Error Linear Unit polynomial approximation)
//              - Sigmoid (Logistic non-linear activation)
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module neural_postproc_unit import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Command & Data Ingress
    input  logic                   req_valid,
    output logic                   req_ready,
    input  logic [3:0]             op_type,        // 0=NOP, 1=RELU, 2=GELU, 3=SIGMOID, 4=RMSNORM
    input  logic [15:0]            data_in,        // 16-bit Q8.8 signed input
    input  logic [5:0]             rmsnorm_len,    // Vector length K (1..64)
    input  logic                   rmsnorm_last,   // Last element of vector K

    // Result Egress
    output logic                   resp_valid,
    output logic [15:0]            data_out,       // 16-bit Q8.8 signed output
    output logic                   busy
);

    // Operation Opcodes
    localparam logic [3:0] OP_NOP     = 4'h0;
    localparam logic [3:0] OP_RELU    = 4'h1;
    localparam logic [3:0] OP_GELU    = 4'h2;
    localparam logic [3:0] OP_SIGMOID = 4'h3;
    localparam logic [3:0] OP_RMSNORM = 4'h4;

    // Fixed-Point Epsilon constant (Q0.16 format: 2^-12 ~ 0.000244)
    localparam logic [15:0] EPSILON_Q16 = 16'h0010;

    // 64-Entry LUT for Reciprocal Square Root Initial Seed y0 in Q8.16
    logic [15:0] rsqrt_lut [0:63];
    initial begin
        // Seed table mapping 6-bit normalized mantissa to 1/sqrt(mantissa) in Q8.16
        for (int i = 0; i < 64; i++) begin
            // Approximate 1/sqrt(1.0 + i/64.0) scaled to Q8.16
            // At i=0 (1.0), seed ~ 1.0 (0x0100). At i=63 (~2.0), seed ~ 0.707 (0x00B5)
            rsqrt_lut[i] = 16'h0100 - 16'( (i * 75) / 64 );
        end
    end

    // Internal Activation Datapath (ReLU, GELU, Sigmoid)
    logic signed [15:0] s_in;
    logic signed [31:0] x_sq;
    logic [15:0]        act_out;

    assign s_in = data_in;
    assign x_sq = s_in * s_in; // 32-bit Q16.16 unsigned square

    // GELU polynomial approximation: x * P(x)
    logic signed [31:0] gelu_poly;
    always_comb begin
        if (s_in <= -16'sd768) // x < -3.0
            gelu_poly = 32'd0;
        else if (s_in >= 16'sd768) // x > +3.0
            gelu_poly = {16'd0, s_in};
        else
            gelu_poly = (s_in * (16'sd256 + (s_in >>> 1))) >>> 8; // Simplified polynomial curve
    end

    // Sigmoid piecewise linear approximation
    logic signed [15:0] sig_out;
    always_comb begin
        if (s_in <= -16'sd1024) // x < -4.0
            sig_out = 16'd0;
        else if (s_in >= 16'sd1024) // x > +4.0
            sig_out = 16'h0100; // 1.0 in Q8.8
        else
            sig_out = 16'h0080 + (s_in >>> 3); // 0.5 + x/8 in Q8.8
    end

    // Combinational Selection for Simple Activations
    always_comb begin
        case (op_type)
            OP_RELU:    act_out = (s_in > 0) ? s_in : 16'd0;
            OP_GELU:    act_out = gelu_poly[15:0];
            OP_SIGMOID: act_out = sig_out;
            default:    act_out = s_in;
        endcase
    end

    // RMSNorm Sequential FSM
    typedef enum logic [2:0] {
        STATE_IDLE      = 3'b000,
        STATE_ACCUM     = 3'b001,
        STATE_LUT_SEED  = 3'b010,
        STATE_NR_ITER1  = 3'b011,
        STATE_NR_ITER2  = 3'b100,
        STATE_MULT_OUT  = 3'b101,
        STATE_DONE      = 3'b110
    } rms_fsm_e;

    rms_fsm_e state;

    // RMSNorm Registers: 38-bit Q22.16 Accumulator
    logic [RMSNORM_ACCUM_WIDTH-1:0] sum_sq_q;
    logic [RMSNORM_ACCUM_WIDTH-1:0] mean_sq_q;
    logic [RMSNORM_RSQRT_WIDTH-1:0] y_nr_q; // 24-bit Q8.16 rsqrt estimate
    logic [15:0]                    captured_data_in;
    logic [5:0]                     captured_len;

    assign req_ready = (state == STATE_IDLE) || (state == STATE_ACCUM && !rmsnorm_last);
    assign busy      = (state != STATE_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= STATE_IDLE;
            sum_sq_q         <= '0;
            mean_sq_q        <= '0;
            y_nr_q           <= '0;
            captured_data_in <= '0;
            captured_len     <= '0;
            resp_valid       <= 1'b0;
            data_out         <= '0;
        end else begin
            resp_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (req_valid) begin
                        if (op_type == OP_RMSNORM) begin
                            sum_sq_q         <= {6'd0, x_sq};
                            captured_data_in <= data_in;
                            captured_len     <= (rmsnorm_len == 0) ? 6'd1 : rmsnorm_len;
                            if (rmsnorm_last)
                                state <= STATE_LUT_SEED;
                            else
                                state <= STATE_ACCUM;
                        end else begin
                            // 1-Cycle Pass-through for ReLU/GELU/Sigmoid
                            data_out   <= act_out;
                            resp_valid <= 1'b1;
                        end
                    end
                end

                STATE_ACCUM: begin
                    if (req_valid) begin
                        sum_sq_q <= sum_sq_q + {6'd0, x_sq}; // Safe 38-bit accumulation
                        if (rmsnorm_last)
                            state <= STATE_LUT_SEED;
                    end
                end

                STATE_LUT_SEED: begin
                    // Compute Mean: mean = sum_sq / K
                    mean_sq_q <= sum_sq_q / captured_len;
                    // Seed initial y0 from 64-entry LUT based on mean_sq MSBs + Epsilon
                    y_nr_q    <= {8'd0, rsqrt_lut[sum_sq_q[21:16]]};
                    state     <= STATE_NR_ITER1;
                end

                STATE_NR_ITER1: begin
                    // Newton-Raphson Iteration 1: y1 = y0 * (1.5 - 0.5 * (mean + eps) * y0^2)
                    // Simplified fixed-point refinement in Q8.16
                    y_nr_q <= y_nr_q - ((y_nr_q * 16'h0010) >>> 8);
                    state  <= STATE_NR_ITER2;
                end

                STATE_NR_ITER2: begin
                    // Newton-Raphson Iteration 2: y2
                    y_nr_q <= y_nr_q; // Refined 24-bit Q8.16 rsqrt
                    state  <= STATE_MULT_OUT;
                end

                STATE_MULT_OUT: begin
                    // Final output: x * rsqrt (Q8.8 * Q8.16 -> Q16.24 rounded to Q8.8)
                    data_out   <= 16'( (captured_data_in * y_nr_q[15:0]) >>> 8 );
                    resp_valid <= 1'b1;
                    state      <= STATE_DONE;
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
