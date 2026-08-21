//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: systolic_pe.sv
// Description: Processing Element for Weight-Stationary 2D Tensor Systolic Array.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module systolic_pe import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Control Modes
    input  logic                   load_weight_en,
    input  logic                   compute_en,
    input  logic                   accum_clr,

    // Horizontal Activation Stream (West -> East)
    input  logic signed [7:0]      act_in,
    output logic signed [7:0]      act_out,

    // Vertical Partial Sum Stream (North -> South)
    input  logic signed [31:0]     psum_in,
    output logic signed [31:0]     psum_out,

    // Weight Load Port
    input  logic signed [7:0]      weight_in
);

    // Weight Stationary Register
    logic signed [7:0]  weight_reg;
    logic signed [15:0] mult_product;
    logic signed [31:0] accum_reg;

    // Multiplication
    assign mult_product = act_in * weight_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_reg  <= '0;
            accum_reg   <= '0;
            act_out     <= '0;
            psum_out    <= '0;
        end else begin
            // 1. Weight Pre-load
            if (load_weight_en) begin
                weight_reg <= weight_in;
            end

            // 2. Activation Forwarding
            if (compute_en) begin
                act_out <= act_in;
            end

            // 3. Multiply-Accumulate Datapath
            if (accum_clr) begin
                accum_reg <= '0;
                psum_out  <= '0;
            end else if (compute_en) begin
                accum_reg <= psum_in + 32'(mult_product);
                psum_out  <= psum_in + 32'(mult_product);
            end
        end
    end

endmodule
