//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: l2_cache_bank.sv
// Description: 256KB Banked L2 Cache with 4-Way Set Associativity & Tag Array.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module l2_cache_bank import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Interconnect Request Interface
    input  logic                   l2_req_valid,
    input  logic                   l2_req_write,
    input  logic [31:0]            l2_req_addr,
    input  logic [127:0]           l2_req_wdata, // 128-bit line access
    output logic                   l2_req_ready,

    // Interconnect Response Interface
    output logic                   l2_resp_valid,
    output logic [127:0]           l2_resp_rdata,
    output logic                   l2_resp_hit
);

    // 256KB Bank = 16384 lines of 128 bits (16 bytes)
    // 4-Way Set Associative: 4096 Sets x 4 Ways
    // Address Breakdown:
    // [3:0]   : Byte Offset in 128-bit line (4 bits)
    // [15:4]  : Set Index (12 bits = 4096 sets)
    // [31:16] : Tag (16 bits)

    logic [11:0] set_idx;
    logic [15:0] tag_in;

    assign set_idx = l2_req_addr[15:4];
    assign tag_in  = l2_req_addr[31:16];

    // Data Storage Array: 4 Ways x 4096 Sets x 128 bits (represented in memory words)
    logic [127:0] cache_data [3:0][4095:0];
    logic [15:0]  cache_tag  [3:0][4095:0];
    logic         cache_valid[3:0][4095:0];
    logic         cache_dirty[3:0][4095:0];

    // Tag Comparison Logic
    logic [3:0]   way_hit_mask;
    logic         is_hit;
    logic [1:0]   hit_way_idx;

    always_comb begin
        way_hit_mask = 4'b0000;
        is_hit       = 1'b0;
        hit_way_idx  = 2'd0;

        for (int w = 0; w < 4; w++) begin
            if (cache_valid[w][set_idx] && (cache_tag[w][set_idx] == tag_in)) begin
                way_hit_mask[w] = 1'b1;
                is_hit          = 1'b1;
                hit_way_idx     = 2'(w);
            end
        end
    end

    assign l2_req_ready = 1'b1;

    // Cache Operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            l2_resp_valid <= 1'b0;
            l2_resp_rdata <= '0;
            l2_resp_hit   <= 1'b0;

            for (int w = 0; w < 4; w++) begin
                for (int s = 0; s < 4096; s++) begin
                    cache_valid[w][s] <= 1'b0;
                    cache_dirty[w][s] <= 1'b0;
                    cache_tag[w][s]   <= '0;
                    cache_data[w][s]  <= '0;
                end
            end
        end else begin
            l2_resp_valid <= l2_req_valid;
            l2_resp_hit   <= is_hit;

            if (l2_req_valid) begin
                if (is_hit) begin
                    if (l2_req_write) begin
                        cache_data[hit_way_idx][set_idx]  <= l2_req_wdata;
                        cache_dirty[hit_way_idx][set_idx] <= 1'b1;
                    end else begin
                        l2_resp_rdata <= cache_data[hit_way_idx][set_idx];
                    end
                end else begin
                    // Cache Miss: Allocate in Way 0 for simplicity/direct line fill
                    if (l2_req_write) begin
                        cache_valid[0][set_idx] <= 1'b1;
                        cache_dirty[0][set_idx] <= 1'b1;
                        cache_tag[0][set_idx]   <= tag_in;
                        cache_data[0][set_idx]  <= l2_req_wdata;
                    end else begin
                        cache_valid[0][set_idx] <= 1'b1;
                        cache_dirty[0][set_idx] <= 1'b0;
                        cache_tag[0][set_idx]   <= tag_in;
                        cache_data[0][set_idx]  <= 128'hDEADBEEF_CAFEF00D_12345678_87654321; // Simulated DRAM fill
                        l2_resp_rdata           <= 128'hDEADBEEF_CAFEF00D_12345678_87654321;
                    end
                end
            end
        end
    end

endmodule
