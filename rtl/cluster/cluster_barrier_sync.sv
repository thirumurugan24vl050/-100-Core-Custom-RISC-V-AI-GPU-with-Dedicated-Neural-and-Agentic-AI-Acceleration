//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: cluster_barrier_sync.sv
// Description: Hardware Warp / Core Barrier Synchronization Controller.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module cluster_barrier_sync import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // 10 Core Barrier Request Ports
    input  logic                   core_barrier_req [9:0],
    input  logic [1:0]             core_barrier_warp[9:0],

    // Target Barrier Mask (Configured via CSR: 10 cores x 4 warps = 40 bits)
    input  logic [39:0]            barrier_participating_mask,

    // Barrier Release Broadcast
    output logic                   barrier_release_broadcast,
    output logic [39:0]            current_arrived_mask
);

    logic [39:0] arrived_mask;
    assign current_arrived_mask = arrived_mask;

    // Check if all participating warps have arrived
    wire all_arrived = ((arrived_mask & barrier_participating_mask) == barrier_participating_mask) && 
                       (barrier_participating_mask != 40'd0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arrived_mask              <= '0;
            barrier_release_broadcast <= 1'b0;
        end else begin
            // 1. Record Arriving Warps
            for (int c = 0; c < 10; c++) begin
                if (core_barrier_req[c]) begin
                    int warp_flat_idx;
                    warp_flat_idx = c * 4 + int'(core_barrier_warp[c]);
                    arrived_mask[warp_flat_idx] <= 1'b1;
                end
            end

            // 2. Release Barrier when all arrived
            if (all_arrived) begin
                barrier_release_broadcast <= 1'b1;
                arrived_mask              <= '0; // Clear arrival mask for next barrier
            end else begin
                barrier_release_broadcast <= 1'b0;
            end
        end
    end

endmodule
