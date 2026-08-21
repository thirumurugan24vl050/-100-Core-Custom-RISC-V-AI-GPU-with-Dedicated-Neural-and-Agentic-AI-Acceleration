//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: noc_router_5port.sv
// Description: 5-Port Virtual-Channel NoC Router with XY Dimension-Order Routing.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module noc_router_5port import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Router Coordinates
    input  logic [3:0]             router_x,
    input  logic [3:0]             router_y,

    // 5 Inbound Ports (0: Local, 1: North, 2: South, 3: East, 4: West)
    input  logic                   in_valid [4:0],
    input  noc_flit_t              in_flit  [4:0],
    output logic                   in_ready [4:0],

    // 5 Outbound Ports (0: Local, 1: North, 2: South, 3: East, 4: West)
    output logic                   out_valid [4:0],
    output noc_flit_t              out_flit  [4:0],
    input  logic                   out_ready [4:0]
);

    // Port Indices
    localparam int PORT_LOCAL = 0;
    localparam int PORT_NORTH = 1;
    localparam int PORT_SOUTH = 2;
    localparam int PORT_EAST  = 3;
    localparam int PORT_WEST  = 4;

    // Input FIFO Buffers (depth 4 per port)
    noc_flit_t in_fifo_data [4:0][3:0];
    logic [1:0] in_fifo_wr  [4:0];
    logic [1:0] in_fifo_rd  [4:0];
    logic [2:0] in_fifo_cnt [4:0];

    // Routing and Crossbar Arbitration Signals
    logic [2:0] dest_port [4:0];
    logic [4:0] req_matrix [4:0]; // [out_port][in_port]
    logic [4:0] grant_matrix [4:0];
    logic [4:0] crossbar_grant;

    // Route Computation: Deterministic XY Routing
    function automatic logic [2:0] compute_route(
        input logic [3:0] cur_x,
        input logic [3:0] cur_y,
        input logic [3:0] dst_x,
        input logic [3:0] dst_y
    );
        begin
            if (dst_x > cur_x)
                compute_route = 3'(PORT_EAST);
            else if (dst_x < cur_x)
                compute_route = 3'(PORT_WEST);
            else if (dst_y > cur_y)
                compute_route = 3'(PORT_SOUTH);
            else if (dst_y < cur_y)
                compute_route = 3'(PORT_NORTH);
            else
                compute_route = 3'(PORT_LOCAL);
        end
    endfunction

    // Ingress Buffering Logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int p = 0; p < 5; p++) begin
                in_fifo_wr[p]  <= '0;
                in_fifo_rd[p]  <= '0;
                in_fifo_cnt[p] <= '0;
                for (int d = 0; d < 4; d++) begin
                    in_fifo_data[p][d] <= '0;
                end
            end
        end else begin
            for (int p = 0; p < 5; p++) begin
                // Ingress Write
                if (in_valid[p] && in_ready[p]) begin
                    in_fifo_data[p][in_fifo_wr[p]] <= in_flit[p];
                    in_fifo_wr[p]                  <= in_fifo_wr[p] + 2'd1;
                    if (!(crossbar_grant[p] && out_ready[dest_port[p]]))
                        in_fifo_cnt[p] <= in_fifo_cnt[p] + 3'd1;
                end

                // Crossbar Read
                if (crossbar_grant[p] && out_ready[dest_port[p]]) begin
                    in_fifo_rd[p] <= in_fifo_rd[p] + 2'd1;
                    if (!(in_valid[p] && in_ready[p]))
                        in_fifo_cnt[p] <= in_fifo_cnt[p] - 3'd1;
                end
            end
        end
    end

    // Ingress Flow Control
    always_comb begin
        for (int p = 0; p < 5; p++) begin
            in_ready[p] = (in_fifo_cnt[p] < 3'd4);
        end
    end

    // Routing and Crossbar Arbitration
    always_comb begin
        for (int p = 0; p < 5; p++) begin
            if (in_fifo_cnt[p] > 0) begin
                dest_port[p] = compute_route(
                    router_x, router_y,
                    in_fifo_data[p][in_fifo_rd[p]].dst_x,
                    in_fifo_data[p][in_fifo_rd[p]].dst_y
                );
            end else begin
                dest_port[p] = 3'(PORT_LOCAL);
            end
        end

        // Build Request Matrix
        for (int out_p = 0; out_p < 5; out_p++) begin
            for (int in_p = 0; in_p < 5; in_p++) begin
                req_matrix[out_p][in_p] = (in_fifo_cnt[in_p] > 0) && (dest_port[in_p] == 3'(out_p));
            end
        end

        // Simple Round-Robin / Priority Arbitration per Output Port
        for (int out_p = 0; out_p < 5; out_p++) begin
            grant_matrix[out_p] = '0;
            for (int in_p = 0; in_p < 5; in_p++) begin
                if (req_matrix[out_p][in_p] && (grant_matrix[out_p] == '0)) begin
                    grant_matrix[out_p][in_p] = 1'b1;
                end
            end
        end

        // Aggregate grant for each input port
        for (int in_p = 0; in_p < 5; in_p++) begin
            crossbar_grant[in_p] = grant_matrix[dest_port[in_p]][in_p];
        end

        // Drive Output Ports
        for (int out_p = 0; out_p < 5; out_p++) begin
            out_valid[out_p] = '0;
            out_flit[out_p]  = '0;
            for (int in_p = 0; in_p < 5; in_p++) begin
                if (grant_matrix[out_p][in_p]) begin
                    out_valid[out_p] = 1'b1;
                    out_flit[out_p]  = in_fifo_data[in_p][in_fifo_rd[in_p]];
                end
            end
        end
    end

endmodule
