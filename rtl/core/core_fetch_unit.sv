//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_fetch_unit.sv
// Description: Multi-Warp Instruction Fetch Engine with Branch Redirection.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_fetch_unit import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Warp Selection from Warp Scheduler
    input  logic [1:0]             fetch_warp_id,
    input  logic                   fetch_warp_valid,
    input  logic [NUM_WARPS-1:0]   warp_active_mask,

    // Branch / Jump Redirection from Execute Stage
    input  logic                   redirect_valid,
    input  logic [1:0]             redirect_warp_id,
    input  logic [XLEN-1:0]        redirect_target_pc,

    // Instruction Memory / I-Cache Interface
    output logic                   icache_req_valid,
    output logic [XLEN-1:0]        icache_req_addr,
    input  logic                   icache_resp_valid,
    input  logic [31:0]            icache_resp_data,

    // Fetch Output to Decode Stage
    output logic                   fetch_out_valid,
    output logic [1:0]             fetch_out_warp_id,
    output logic [XLEN-1:0]        fetch_out_pc,
    output logic [31:0]            fetch_out_instruction,
    input  logic                   decode_ready
);

    // Warp Program Counters
    logic [XLEN-1:0] warp_pc [NUM_WARPS-1:0];

    // Pipeline registers
    logic [1:0]      inflight_warp_id;
    logic [XLEN-1:0] inflight_pc;
    logic            inflight_valid;

    // Output assignment to I-Cache
    assign icache_req_valid = fetch_warp_valid && decode_ready;
    assign icache_req_addr  = warp_pc[fetch_warp_id];

    // PC Sequential update and Branch Redirection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int w = 0; w < NUM_WARPS; w++) begin
                warp_pc[w] <= 32'h00000000; // Reset vector
            end
            inflight_warp_id <= '0;
            inflight_pc      <= '0;
            inflight_valid   <= 1'b0;
        end else begin
            // 1. Handle Branch / Jump Redirect (Highest Priority)
            if (redirect_valid) begin
                warp_pc[redirect_warp_id] <= redirect_target_pc;
            end 
            // 2. Advance sequential PC on valid fetch request
            else if (icache_req_valid) begin
                warp_pc[fetch_warp_id] <= warp_pc[fetch_warp_id] + 32'd4;
            end

            // Track in-flight request
            if (decode_ready) begin
                inflight_warp_id <= fetch_warp_id;
                inflight_pc      <= warp_pc[fetch_warp_id];
                inflight_valid   <= icache_req_valid;
            end
        end
    end

    // Fetch to Decode stage handshake
    assign fetch_out_valid       = icache_resp_valid && inflight_valid;
    assign fetch_out_warp_id     = inflight_warp_id;
    assign fetch_out_pc          = inflight_pc;
    assign fetch_out_instruction = icache_resp_data;

endmodule
