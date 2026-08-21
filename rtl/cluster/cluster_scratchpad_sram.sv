//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: cluster_scratchpad_sram.sv
// Description: 64KB 8-Bank Shared Scratchpad SRAM with Multi-Core Crossbar Arbiter.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module cluster_scratchpad_sram import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // 10 Core Request Ports
    input  logic                   core_req_valid [9:0],
    input  logic                   core_req_write [9:0],
    input  logic [15:0]            core_req_addr  [9:0],
    input  logic [31:0]            core_req_wdata [9:0],
    output logic [31:0]            core_resp_rdata[9:0],
    output logic                   core_resp_valid[9:0]
);

    // 8 Memory Banks: 8 Banks x 2048 words x 32 bits = 64KB
    logic [31:0] sram_bank [7:0][2047:0];

    // Bank indexing: Address bits [4:2] select bank, bits [15:5] select word in bank
    logic [2:0]  req_bank_idx [9:0];
    logic [10:0] req_word_idx [9:0];

    always_comb begin
        for (int c = 0; c < 10; c++) begin
            req_bank_idx[c] = core_req_addr[c][4:2];
            req_word_idx[c] = core_req_addr[c][15:5];
        end
    end

    // Bank Arbitration: 8 Banks x 10 Requesters
    logic [9:0] bank_req_mask [7:0];
    logic [9:0] bank_grant    [7:0];

    always_comb begin
        for (int b = 0; b < 8; b++) begin
            for (int c = 0; c < 10; c++) begin
                bank_req_mask[b][c] = core_req_valid[c] && (req_bank_idx[c] == 3'(b));
            end
        end

        // Priority grant per bank
        for (int b = 0; b < 8; b++) begin
            bank_grant[b] = '0;
            for (int c = 0; c < 10; c++) begin
                if (bank_req_mask[b][c] && (bank_grant[b] == '0)) begin
                    bank_grant[b][c] = 1'b1;
                end
            end
        end
    end

    // Synchronous Read/Write Execution
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int b = 0; b < 8; b++) begin
                for (int w = 0; w < 2048; w++) begin
                    sram_bank[b][w] <= '0;
                end
            end
            for (int c = 0; c < 10; c++) begin
                core_resp_valid[c] <= 1'b0;
                core_resp_rdata[c] <= '0;
            end
        end else begin
            for (int c = 0; c < 10; c++) begin
                core_resp_valid[c] <= 1'b0;
            end

            for (int b = 0; b < 8; b++) begin
                for (int c = 0; c < 10; c++) begin
                    if (bank_grant[b][c]) begin
                        if (core_req_write[c]) begin
                            sram_bank[b][req_word_idx[c]] <= core_req_wdata[c];
                        end else begin
                            core_resp_rdata[c] <= sram_bank[b][req_word_idx[c]];
                            core_resp_valid[c] <= 1'b1;
                        end
                    end
                end
            end
        end
    end

endmodule
