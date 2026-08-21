//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: l2_directory_ctrl.sv
// Description: Multi-Bank L2 Cache Directory and Request Interleaver.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module l2_directory_ctrl import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Inbound Request from NoC (512-bit / 128-bit payload)
    input  logic                   mem_req_valid,
    input  logic                   mem_req_write,
    input  logic [31:0]            mem_req_addr,
    input  logic [127:0]           mem_req_wdata,
    output logic                   mem_req_ready,

    output logic                   mem_resp_valid,
    output logic [127:0]           mem_resp_rdata,

    // 16 L2 Cache Bank Interfaces
    output logic [15:0]            bank_req_valid,
    output logic [15:0]            bank_req_write,
    output logic [31:0]            bank_req_addr  [15:0],
    output logic [127:0]           bank_req_wdata [15:0],

    input  logic [15:0]            bank_resp_valid,
    input  logic [127:0]           bank_resp_rdata[15:0],
    input  logic [15:0]            bank_resp_hit
);

    // Bank Selection: Address bits [7:4] select 1 of 16 banks
    logic [3:0] selected_bank;
    assign selected_bank = mem_req_addr[7:4];
    assign mem_req_ready = 1'b1;

    always_comb begin
        for (int b = 0; b < 16; b++) begin
            bank_req_valid[b] = mem_req_valid && (selected_bank == 4'(b));
            bank_req_write[b] = mem_req_write;
            bank_req_addr[b]  = mem_req_addr;
            bank_req_wdata[b] = mem_req_wdata;
        end
    end

    // Multiplex Responses from 16 Banks
    always_comb begin
        mem_resp_valid = |bank_resp_valid;
        mem_resp_rdata = '0;
        for (int b = 0; b < 16; b++) begin
            if (bank_resp_valid[b]) begin
                mem_resp_rdata = bank_resp_rdata[b];
            end
        end
    end

endmodule
