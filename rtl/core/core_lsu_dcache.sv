//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_lsu_dcache.sv
// Description: Multi-Warp Load/Store Unit with Integrated L1 D-Cache & Scratchpad Bridge.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_lsu_dcache import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Core Pipeline Memory Interface
    input  logic                   mem_req_valid,
    input  logic [1:0]             mem_req_warp_id,
    input  logic                   mem_req_write,
    input  logic [2:0]             mem_req_funct3, // LB, LH, LW, LBU, LHU, SB, SH, SW
    input  logic [XLEN-1:0]        mem_req_addr,
    input  logic [XLEN-1:0]        mem_req_wdata,
    output logic                   mem_resp_valid,
    output logic [1:0]             mem_resp_warp_id,
    output logic [XLEN-1:0]        mem_resp_rdata,
    output logic                   lsu_busy,

    // Cluster Scratchpad SRAM Interface
    output logic                   scratchpad_req_valid,
    output logic                   scratchpad_req_write,
    output logic [15:0]            scratchpad_req_addr,
    output logic [31:0]            scratchpad_req_wdata,
    input  logic [31:0]            scratchpad_resp_rdata,
    input  logic                   scratchpad_resp_valid,

    // Top-Level / L2 Memory Interface
    output logic                   l2_mem_req_valid,
    output logic                   l2_mem_req_write,
    output logic [XLEN-1:0]        l2_mem_req_addr,
    output logic [XLEN-1:0]        l2_mem_req_wdata,
    input  logic [XLEN-1:0]        l2_mem_resp_rdata,
    input  logic                   l2_mem_resp_valid
);

    // Address region decoding
    logic is_scratchpad_addr;
    logic is_l2_global_addr;

    assign is_scratchpad_addr = (mem_req_addr[31:28] == 4'h1);
    assign is_l2_global_addr  = (mem_req_addr[31:28] >= 4'h8);

    // Simple L1 cache storage (1024 words x 32 bits = 4KB)
    logic [31:0] dcache_mem [1023:0];
    logic [9:0]  dcache_index;
    assign dcache_index = mem_req_addr[11:2];

    // Pipeline tracking registers
    logic [1:0]      inflight_warp;
    logic [2:0]      inflight_funct3;
    logic [1:0]      inflight_byte_offset;
    logic            inflight_read_valid;
    logic            inflight_is_scratchpad;
    logic            inflight_is_l2;

    // Read byte extraction & sign extension helper
    function automatic logic [31:0] format_load_data(
        input logic [31:0] raw_word,
        input logic [2:0]  f3,
        input logic [1:0]  offset
    );
        logic [7:0]  byte_val;
        logic [15:0] half_val;
        begin
            case (offset)
                2'b00: byte_val = raw_word[7:0];
                2'b01: byte_val = raw_word[15:8];
                2'b10: byte_val = raw_word[23:16];
                2'b11: byte_val = raw_word[31:24];
            endcase

            half_val = offset[1] ? raw_word[31:16] : raw_word[15:0];

            case (f3)
                3'b000: format_load_data = {{24{byte_val[7]}}, byte_val};       // LB
                3'b001: format_load_data = {{16{half_val[15]}}, half_val};      // LH
                3'b010: format_load_data = raw_word;                             // LW
                3'b100: format_load_data = {24'd0, byte_val};                    // LBU
                3'b101: format_load_data = {16'd0, half_val};                    // LHU
                default: format_load_data = raw_word;
            endcase
        end
    endfunction

    // Write mask generation helper
    function automatic logic [31:0] format_store_data(
        input logic [31:0] orig_word,
        input logic [31:0] write_val,
        input logic [2:0]  f3,
        input logic [1:0]  offset
    );
        begin
            case (f3)
                3'b000: begin // SB
                    format_store_data = orig_word;
                    format_store_data[offset*8 +: 8] = write_val[7:0];
                end
                3'b001: begin // SH
                    format_store_data = orig_word;
                    format_store_data[offset[1]*16 +: 16] = write_val[15:0];
                end
                default: begin // SW
                    format_store_data = write_val;
                end
            endcase
        end
    endfunction

    // Scratchpad interface drive
    assign scratchpad_req_valid = mem_req_valid && is_scratchpad_addr;
    assign scratchpad_req_write = mem_req_write;
    assign scratchpad_req_addr  = mem_req_addr[15:0];
    assign scratchpad_req_wdata = mem_req_wdata;

    // L2 Global interface drive
    assign l2_mem_req_valid = mem_req_valid && is_l2_global_addr;
    assign l2_mem_req_write = mem_req_write;
    assign l2_mem_req_addr  = mem_req_addr;
    assign l2_mem_req_wdata = mem_req_wdata;

    assign lsu_busy = mem_req_valid && (is_scratchpad_addr || is_l2_global_addr);

    // Sequential D-Cache operations & tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 1024; i++) begin
                dcache_mem[i] <= '0;
            end
            inflight_warp          <= '0;
            inflight_funct3        <= '0;
            inflight_byte_offset   <= '0;
            inflight_read_valid    <= 1'b0;
            inflight_is_scratchpad <= 1'b0;
            inflight_is_l2         <= 1'b0;
        end else begin
            // 1. Process Core Writes
            if (mem_req_valid && mem_req_write && !is_scratchpad_addr && !is_l2_global_addr) begin
                dcache_mem[dcache_index] <= format_store_data(
                    dcache_mem[dcache_index],
                    mem_req_wdata,
                    mem_req_funct3,
                    mem_req_addr[1:0]
                );
            end

            // 2. Track read requests
            if (mem_req_valid && !mem_req_write) begin
                inflight_warp          <= mem_req_warp_id;
                inflight_funct3        <= mem_req_funct3;
                inflight_byte_offset   <= mem_req_addr[1:0];
                inflight_read_valid    <= 1'b1;
                inflight_is_scratchpad <= is_scratchpad_addr;
                inflight_is_l2         <= is_l2_global_addr;
            end else begin
                inflight_read_valid    <= 1'b0;
            end
        end
    end

    // Response Multiplexing
    always_comb begin
        mem_resp_valid   = 1'b0;
        mem_resp_warp_id = inflight_warp;
        mem_resp_rdata   = '0;

        if (inflight_read_valid) begin
            if (inflight_is_scratchpad) begin
                mem_resp_valid = scratchpad_resp_valid;
                mem_resp_rdata = format_load_data(scratchpad_resp_rdata, inflight_funct3, inflight_byte_offset);
            end else if (inflight_is_l2) begin
                mem_resp_valid = l2_mem_resp_valid;
                mem_resp_rdata = format_load_data(l2_mem_resp_rdata, inflight_funct3, inflight_byte_offset);
            end else begin // Local D-Cache Hit (1-cycle synchronous latency)
                mem_resp_valid = 1'b1;
                mem_resp_rdata = format_load_data(dcache_mem[dcache_index], inflight_funct3, inflight_byte_offset);
            end
        end
    end

endmodule
