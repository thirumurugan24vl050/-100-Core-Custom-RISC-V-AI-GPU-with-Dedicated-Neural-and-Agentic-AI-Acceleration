//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_warp_scheduler.sv
// Description: Zero-Overhead 4-Warp Latency Hiding Scheduler with Scoreboard.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_warp_scheduler import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Warp Enable & Status Controls
    input  logic [NUM_WARPS-1:0]   warp_enable_mask,
    input  logic [NUM_WARPS-1:0]   warp_barrier_stall,

    // Scoreboard Hazard Reporting
    input  logic                   sb_set_busy,
    input  logic [1:0]             sb_set_warp_id,
    input  logic [4:0]             sb_set_reg_id,
    input  logic                   sb_clear_busy,
    input  logic [1:0]             sb_clear_warp_id,
    input  logic [4:0]             sb_clear_reg_id,

    // Instruction Dependency Checking (Decode Stage)
    input  logic [1:0]             dec_warp_id,
    input  logic [4:0]             dec_rs1_addr,
    input  logic [4:0]             dec_rs2_addr,
    output logic                   dec_hazard_stall,

    // Fetch / Issue Arbiter Outputs
    output logic [1:0]             selected_fetch_warp,
    output logic                   selected_fetch_valid
);

    // Register Busy Scoreboard: 4 Warps x 32 Registers
    logic [31:0] scoreboard [NUM_WARPS-1:0];

    // Warp Ready Mask
    logic [NUM_WARPS-1:0] warp_ready_mask;
    logic [1:0]           last_scheduled_warp;

    // Hazard detection for current decoded instruction
    always_comb begin
        if (dec_rs1_addr != 5'd0 && scoreboard[dec_warp_id][dec_rs1_addr])
            dec_hazard_stall = 1'b1;
        else if (dec_rs2_addr != 5'd0 && scoreboard[dec_warp_id][dec_rs2_addr])
            dec_hazard_stall = 1'b1;
        else
            dec_hazard_stall = 1'b0;
    end

    // Compute Ready Mask for each warp
    always_comb begin
        for (int w = 0; w < NUM_WARPS; w++) begin
            warp_ready_mask[w] = warp_enable_mask[w] && !warp_barrier_stall[w];
        end
    end

    // Round-Robin Warp Scheduler
    always_comb begin
        selected_fetch_valid = 1'b0;
        selected_fetch_warp  = 2'd0;

        for (int i = 1; i <= NUM_WARPS; i++) begin
            logic [1:0] candidate_warp;
            candidate_warp = 2'((int'(last_scheduled_warp) + i) % NUM_WARPS);
            if (warp_ready_mask[candidate_warp] && !selected_fetch_valid) begin
                selected_fetch_warp  = candidate_warp;
                selected_fetch_valid = 1'b1;
            end
        end
    end

    // State updates for Scoreboard and Scheduler
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int w = 0; w < NUM_WARPS; w++) begin
                scoreboard[w] <= '0;
            end
            last_scheduled_warp <= 2'd0;
        end else begin
            // Update last scheduled warp
            if (selected_fetch_valid) begin
                last_scheduled_warp <= selected_fetch_warp;
            end

            // Clear scoreboard bit on writeback / complete
            if (sb_clear_busy && (sb_clear_reg_id != 5'd0)) begin
                scoreboard[sb_clear_warp_id][sb_clear_reg_id] <= 1'b0;
            end

            // Set scoreboard bit on issue for multi-cycle / load instructions
            if (sb_set_busy && (sb_set_reg_id != 5'd0)) begin
                scoreboard[sb_set_warp_id][sb_set_reg_id] <= 1'b1;
            end
        end
    end

endmodule
