//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: global_buffer.sv
// Description: 4MB Distributed Global Buffer:
//              - 16 Independent Interleaved SRAM Banks (256KB per Bank)
//              - Partitioned into 2MB Paged KV Storage, 1MB Weights, 1MB DMA
//              - Synchronous Dual-Port (1R/1W) Access Architecture
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module global_buffer import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Read Port
    input  logic                   ren,
    input  logic [31:0]            raddr,          // 32-bit byte address in 4MB space
    output logic [127:0]           rdata,          // 128-bit read data beat
    output logic                   rvalid,

    // Write Port
    input  logic                   wen,
    input  logic [31:0]            waddr,
    input  logic [127:0]           wdata,
    input  logic [15:0]            wstrb,          // 16-byte write strobe
    output logic                   wready
);

    localparam int NUM_BANKS      = 16;
    localparam int BANK_WORDS     = 16384; // 16K x 128-bit words = 256KB per bank
    localparam int BANK_ADDR_BITS = 14;

    // Bank Selection: bits [7:4] select one of the 16 banks (interleaved per 16-byte word)
    logic [3:0] rbank_sel, wbank_sel;
    logic [BANK_ADDR_BITS-1:0] rword_addr, wword_addr;

    assign rbank_sel  = raddr[7:4];
    assign rword_addr = raddr[BANK_ADDR_BITS+7:8];

    assign wbank_sel  = waddr[7:4];
    assign wword_addr = waddr[BANK_ADDR_BITS+7:8];

    assign wready = 1'b1;

    // 16 Independent Synchronous SRAM Bank Arrays
    logic [127:0] bank_mem [NUM_BANKS-1:0][BANK_WORDS-1:0];
    logic [127:0] bank_rdata [NUM_BANKS-1:0];
    logic [3:0]   rbank_sel_pipe;

    // Write Logic
    always_ff @(posedge clk) begin
        if (wen) begin
            for (int b = 0; b < 16; b++) begin
                if (wstrb[b]) begin
                    bank_mem[wbank_sel][wword_addr][b*8 +: 8] <= wdata[b*8 +: 8];
                end
            end
        end
    end

    // Synchronous Read Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid         <= 1'b0;
            rbank_sel_pipe <= '0;
            rdata          <= '0;
        end else begin
            rvalid         <= ren;
            rbank_sel_pipe <= rbank_sel;
            if (ren) begin
                rdata <= bank_mem[rbank_sel][rword_addr];
            end
        end
    end

endmodule
