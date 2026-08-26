//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_reconvergence_stack.sv
// Description: Multi-Warp SIMT Branch Reconvergence Stack:
//              - 4 Hardware Warps x 8-entry Stack Depth
//              - Manages dynamic lane active mask [31:0] & reconvergence PC [31:0]
//              - PUSH on branch divergence, POP on reconvergence point
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_reconvergence_stack import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Warp Selection
    input  logic [1:0]             warp_id,

    // Divergence Push Interface
    input  logic                   diverge_push_valid,
    input  logic [31:0]            diverge_else_mask,
    input  logic [XLEN-1:0]        diverge_reconv_pc,

    // Reconvergence Pop Interface
    input  logic                   reconv_pop_valid,

    // Stack Status & Active Mask Output
    output logic [31:0]            current_active_mask [NUM_WARPS-1:0],
    output logic                   stack_empty [NUM_WARPS-1:0],
    output logic                   stack_full [NUM_WARPS-1:0]
);

    localparam int STACK_DEPTH = 8;
    localparam int PTR_WIDTH   = 3; // 0..7

    typedef struct packed {
        logic [31:0]     mask;
        logic [XLEN-1:0] reconv_pc;
    } stack_entry_t;

    // 4 Warps x 8 Stack Entries
    stack_entry_t stack_mem [NUM_WARPS-1:0][STACK_DEPTH-1:0];
    logic [PTR_WIDTH:0] stack_ptr [NUM_WARPS-1:0]; // 4-bit pointer for depth 8 (0..8)
    logic [31:0]        active_mask_reg [NUM_WARPS-1:0];

    // Status outputs
    always_comb begin
        for (int w = 0; w < NUM_WARPS; w++) begin
            stack_empty[w]         = (stack_ptr[w] == 0);
            stack_full[w]          = (stack_ptr[w] == STACK_DEPTH);
            current_active_mask[w] = active_mask_reg[w];
        end
    end

    // Stack Push / Pop Sequential Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int w = 0; w < NUM_WARPS; w++) begin
                stack_ptr[w]       <= '0;
                active_mask_reg[w] <= 32'hFFFFFFFF; // All 32 lanes active at reset
                for (int d = 0; d < STACK_DEPTH; d++) begin
                    stack_mem[w][d] <= '0;
                end
            end
        end else begin
            // 1. Branch Divergence PUSH: Save reconvergence entry and update active mask
            if (diverge_push_valid && !stack_full[warp_id]) begin
                stack_mem[warp_id][stack_ptr[warp_id][2:0]].mask      <= diverge_else_mask;
                stack_mem[warp_id][stack_ptr[warp_id][2:0]].reconv_pc <= diverge_reconv_pc;
                stack_ptr[warp_id]                                    <= stack_ptr[warp_id] + 1'b1;
            end
            // 2. Reconvergence POP: Restore previous execution mask
            else if (reconv_pop_valid && !stack_empty[warp_id]) begin
                stack_ptr[warp_id]       <= stack_ptr[warp_id] - 1'b1;
                active_mask_reg[warp_id] <= stack_mem[warp_id][stack_ptr[warp_id][2:0] - 1'b1].mask;
            end
        end
    end

endmodule
