//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: noc_interface_adapter.sv
// Description: Network Interface Adapter Bridging Compute Nodes to NoC Fabric.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module noc_interface_adapter import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Node Coordinates
    input  logic [3:0]             node_x,
    input  logic [3:0]             node_y,

    // Local Node Memory Request Interface (Core -> NoC)
    input  logic                   local_mem_req_valid,
    input  logic                   local_mem_req_write,
    input  logic [3:0]             local_dst_x,
    input  logic [3:0]             local_dst_y,
    input  logic [31:0]            local_mem_addr,
    input  logic [31:0]            local_mem_wdata,
    output logic                   local_mem_req_ready,

    // Local Node Memory Response Interface (NoC -> Core)
    output logic                   local_mem_resp_valid,
    output logic [31:0]            local_mem_resp_rdata,

    // NoC Router Local Port Interface
    output logic                   noc_tx_valid,
    output noc_flit_t              noc_tx_flit,
    input  logic                   noc_tx_ready,

    input  logic                   noc_rx_valid,
    input  noc_flit_t              noc_rx_flit,
    output logic                   noc_rx_ready
);

    // TX Packetization
    assign local_mem_req_ready = noc_tx_ready;
    assign noc_tx_valid        = local_mem_req_valid;

    always_comb begin
        noc_tx_flit.flit_type = FLIT_SINGLE;
        noc_tx_flit.vc_id     = local_mem_req_write ? VC_REQ : VC_REQ;
        noc_tx_flit.src_x     = node_x;
        noc_tx_flit.src_y     = node_y;
        noc_tx_flit.dst_x     = local_dst_x;
        noc_tx_flit.dst_y     = local_dst_y;
        noc_tx_flit.msg_type  = local_mem_req_write ? 8'h02 : 8'h01; // 01: Read, 02: Write
        noc_tx_flit.payload   = {local_mem_addr, local_mem_wdata, 64'd0};
    end

    // RX Depacketization
    assign noc_rx_ready         = 1'b1;
    assign local_mem_resp_valid = noc_rx_valid && (noc_rx_flit.msg_type == 8'h03); // Read Resp
    assign local_mem_resp_rdata = noc_rx_flit.payload[95:64];

endmodule
