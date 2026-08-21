//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: agent_token_router.sv
// Description: Multi-Agent Token & Context Router Interfacing to NoC.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module agent_token_router import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Token Ingestion from Host / Agent Dispatcher
    input  logic                   token_in_valid,
    input  logic [15:0]            token_id,
    input  logic [5:0]             agent_id,
    input  logic [3:0]             target_cluster,
    input  logic [3:0]             target_core,
    input  logic [63:0]            token_embedding,
    output logic                   token_in_ready,

    // Outbound NoC Flit Interface
    output logic                   noc_tx_valid,
    output noc_flit_t              noc_tx_flit,
    input  logic                   noc_tx_ready,

    // Inbound NoC Flit Interface (Responses / Token Completion)
    input  logic                   noc_rx_valid,
    input  noc_flit_t              noc_rx_flit,
    output logic                   noc_rx_ready,

    // Inbound Completion Event to Coprocessor
    output logic                   token_complete_valid,
    output logic [15:0]            token_complete_id,
    output logic [5:0]             token_complete_agent
);

    // Internal FIFO Queue for Token Buffering (16 deep)
    logic [15:0] q_token_id   [15:0];
    logic [5:0]  q_agent_id   [15:0];
    logic [3:0]  q_cluster    [15:0];
    logic [3:0]  q_core       [15:0];
    logic [63:0] q_embedding  [15:0];

    logic [3:0] wr_ptr, rd_ptr;
    logic [4:0] count;

    assign token_in_ready = (count < 5'd16);

    // Queue Enqueue & Dequeue Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= '0;
            rd_ptr <= '0;
            count  <= '0;
            for (int i = 0; i < 16; i++) begin
                q_token_id[i]  <= '0;
                q_agent_id[i]  <= '0;
                q_cluster[i]   <= '0;
                q_core[i]      <= '0;
                q_embedding[i] <= '0;
            end
        end else begin
            // Enqueue
            if (token_in_valid && token_in_ready) begin
                q_token_id[wr_ptr]  <= token_id;
                q_agent_id[wr_ptr]  <= agent_id;
                q_cluster[wr_ptr]   <= target_cluster;
                q_core[wr_ptr]      <= target_core;
                q_embedding[wr_ptr] <= token_embedding;
                wr_ptr <= wr_ptr + 4'd1;
                count  <= count + 5'd1;
            end

            // Dequeue when NoC accepts flit
            if (noc_tx_valid && noc_tx_ready) begin
                rd_ptr <= rd_ptr + 4'd1;
                count  <= count - 5'd1;
            end
        end
    end

    // Assemble Outbound NoC Flit
    assign noc_tx_valid = (count > 0);
    always_comb begin
        noc_tx_flit.flit_type = FLIT_SINGLE;
        noc_tx_flit.vc_id     = VC_AGENT;
        noc_tx_flit.src_x     = 4'd0; // Originating from Global Agent Unit at (0,0)
        noc_tx_flit.src_y     = 4'd0;
        noc_tx_flit.dst_x     = q_cluster[rd_ptr];
        noc_tx_flit.dst_y     = q_core[rd_ptr];
        noc_tx_flit.msg_type  = 8'hA1; // Agent Token Dispatch Msg
        noc_tx_flit.payload   = {q_token_id[rd_ptr], q_agent_id[rd_ptr], 42'd0, q_embedding[rd_ptr]};
    end

    // Process Inbound Flits
    assign noc_rx_ready          = 1'b1;
    assign token_complete_valid  = noc_rx_valid && (noc_rx_flit.msg_type == 8'hA2);
    assign token_complete_id     = noc_rx_flit.payload[127:112];
    assign token_complete_agent  = noc_rx_flit.payload[111:106];

endmodule
