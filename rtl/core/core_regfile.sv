//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_regfile.sv
// Description: Multi-Warp Scalar (32x32) and Vector (32x256) Register File.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_regfile import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Scalar Read Ports
    input  logic [1:0]             r_warp_id,
    input  logic [4:0]             r_scalar_addr1,
    input  logic [4:0]             r_scalar_addr2,
    output logic [XLEN-1:0]        r_scalar_data1,
    output logic [XLEN-1:0]        r_scalar_data2,

    // Scalar Write Port
    input  logic [1:0]             w_scalar_warp_id,
    input  logic                   w_scalar_en,
    input  logic [4:0]             w_scalar_addr,
    input  logic [XLEN-1:0]        w_scalar_data,

    // Vector Read Ports
    input  logic [4:0]             r_vec_addr1,
    input  logic [4:0]             r_vec_addr2,
    output logic [VLEN-1:0]        r_vec_data1,
    output logic [VLEN-1:0]        r_vec_data2,

    // Vector Write Port
    input  logic [1:0]             w_vec_warp_id,
    input  logic                   w_vec_en,
    input  logic [4:0]             w_vec_addr,
    input  logic [VLEN-1:0]        w_vec_data
);

    // Scalar Register Banks: 4 Warps x 32 Registers x 32 bits
    logic [XLEN-1:0] scalar_regs [NUM_WARPS-1:0][NUM_SCALAR_REGS-1:0];

    // Vector Register Banks: 4 Warps x 32 Registers x 256 bits
    logic [VLEN-1:0] vector_regs [NUM_WARPS-1:0][NUM_VECTOR_REGS-1:0];

    // Scalar Asynchronous Read with x0 hardwired to 0
    always_comb begin
        if (r_scalar_addr1 == 5'd0)
            r_scalar_data1 = '0;
        else if (w_scalar_en && (w_scalar_warp_id == r_warp_id) && (w_scalar_addr == r_scalar_addr1))
            r_scalar_data1 = w_scalar_data; // Internal bypass forwarding
        else
            r_scalar_data1 = scalar_regs[r_warp_id][r_scalar_addr1];

        if (r_scalar_addr2 == 5'd0)
            r_scalar_data2 = '0;
        else if (w_scalar_en && (w_scalar_warp_id == r_warp_id) && (w_scalar_addr == r_scalar_addr2))
            r_scalar_data2 = w_scalar_data; // Internal bypass forwarding
        else
            r_scalar_data2 = scalar_regs[r_warp_id][r_scalar_addr2];
    end

    // Vector Asynchronous Read
    always_comb begin
        if (w_vec_en && (w_vec_warp_id == r_warp_id) && (w_vec_addr == r_vec_addr1))
            r_vec_data1 = w_vec_data; // Vector bypass forwarding
        else
            r_vec_data1 = vector_regs[r_warp_id][r_vec_addr1];

        if (w_vec_en && (w_vec_warp_id == r_warp_id) && (w_vec_addr == r_vec_addr2))
            r_vec_data2 = w_vec_data; // Vector bypass forwarding
        else
            r_vec_data2 = vector_regs[r_warp_id][r_vec_addr2];
    end

    // Synchronous Write Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int w = 0; w < NUM_WARPS; w++) begin
                for (int r = 0; r < NUM_SCALAR_REGS; r++) begin
                    scalar_regs[w][r] <= '0;
                end
                for (int v = 0; v < NUM_VECTOR_REGS; v++) begin
                    vector_regs[w][v] <= '0;
                end
            end
        end else begin
            // Scalar write (ignore write to x0)
            if (w_scalar_en && (w_scalar_addr != 5'd0)) begin
                scalar_regs[w_scalar_warp_id][w_scalar_addr] <= w_scalar_data;
            end
            // Vector write
            if (w_vec_en) begin
                vector_regs[w_vec_warp_id][w_vec_addr] <= w_vec_data;
            end
        end
    end

endmodule
