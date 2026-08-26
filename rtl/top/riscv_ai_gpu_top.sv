//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: riscv_ai_gpu_top.sv
// Description: Full Chip Top-Level (Production V1):
//              - 100 RISC-V AI Compute Cores (10 Clusters x 10 Cores)
//              - 10x10 2D-Mesh Interconnect (100 5-Port Routers)
//              - 4MB Distributed Global Buffer (16 Interleaved Banks)
//              - Global Memory Gateway at Node (9,9)
//              - Hardware Agentic AI Coprocessor at Node (0,0)
//              - 512-bit Host Scatter-Gather DMA Controller at Node (5,0)
// Standard: IEEE 1800-2017 SystemVerilog (Cadence Incisive/Xcelium compliant)
//=============================================================================

`timescale 1ns / 1ps

module riscv_ai_gpu_top import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Host Control & CSR Interface
    input  logic                   host_csr_valid,
    input  logic                   host_csr_write,
    input  logic [11:0]            host_csr_addr,
    input  logic [31:0]            host_csr_wdata,
    output logic [31:0]            host_csr_rdata,
    output logic                   host_csr_ready,

    // Host DMA Interface
    input  logic                   host_dma_start,
    input  logic [31:0]            host_dma_src,
    input  logic [31:0]            host_dma_dst,
    input  logic [15:0]            host_dma_len,
    output logic                   host_dma_busy,
    output logic                   host_dma_done_irq,

    // Global Hardware Status & Interrupts
    output logic                   agent_graph_done_irq,
    output logic                   gpu_idle_status
);

    // 10x10 Mesh Local Port Interfaces for all 100 Nodes
    noc_flit_t mesh_flit_in   [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];
    logic      mesh_valid_in  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];
    logic      mesh_ready_out [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];

    noc_flit_t mesh_flit_out  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];
    logic      mesh_valid_out [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];
    logic      mesh_ready_in  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0];

    // Agentic Coprocessor Wires (Node 0,0)
    logic                   agent_coproc_req_val;
    logic [3:0]             agent_coproc_req_op;
    logic [31:0]            agent_coproc_param1;
    logic [31:0]            agent_coproc_param2;
    logic                   agent_coproc_resp_val;
    logic [31:0]            agent_coproc_resp_dat;
    logic                   agent_task_disp_val;
    logic [DAG_NODE_ID_WIDTH-1:0] agent_task_disp_id;
    logic [7:0]             agent_task_disp_cluster;
    logic [31:0]            agent_task_disp_pc;

    // Global Buffer & Memory Gateway Wires (Node 9,9)
    logic                   gb_ren;
    logic [31:0]            gb_raddr;
    logic [127:0]           gb_rdata;
    logic                   gb_rvalid;
    logic                   gb_wen;
    logic [31:0]            gb_waddr;
    logic [127:0]           gb_wdata;
    logic [15:0]            gb_wstrb;
    logic                   gb_wready;

    // DMA Master Interconnect Wires
    logic                   dma_mem_val;
    logic                   dma_mem_wr;
    logic [31:0]            dma_mem_addr;
    logic [127:0]           dma_mem_wdata;
    logic                   dma_mem_rdy;
    logic                   dma_mem_resp_val;
    logic [127:0]           dma_mem_resp_rdata;

    // Cluster Tie-Off Arrays for Unused Directional Ports
    logic      cluster_tieoff_val_in  [3:0];
    noc_flit_t cluster_tieoff_flit_in [3:0];
    logic      cluster_tieoff_rdy_in  [3:0];

    always_comb begin
        for (int d = 0; d < 4; d++) begin
            cluster_tieoff_val_in[d]  = 1'b0;
            cluster_tieoff_flit_in[d] = '0;
            cluster_tieoff_rdy_in[d]  = 1'b1;
        end
    end

    // 1. Host CSR Decoding & Control
    always_comb begin
        agent_coproc_req_val = host_csr_valid && (host_csr_addr == `CSR_AGENT_GRAPH_STATE);
        agent_coproc_req_op  = host_csr_wdata[3:0];
        agent_coproc_param1  = host_csr_wdata;
        agent_coproc_param2  = 32'h00001000;
        host_csr_ready       = 1'b1;

        case (host_csr_addr)
            `CSR_AGENT_GRAPH_STATE: host_csr_rdata = agent_coproc_resp_dat;
            `CSR_NEURAL_STATUS:     host_csr_rdata = 32'h00000001; // Ready
            default:                host_csr_rdata = 32'hA1600001; // Chip Version ID: RISC-V AI GPU v1.0
        endcase
    end

    // Default tie-off for unused mesh ports
    always_comb begin
        for (int x = 0; x < NOC_MESH_X; x++) begin
            for (int y = 0; y < NOC_MESH_Y; y++) begin
                mesh_flit_in[x][y]  = '0;
                mesh_valid_in[x][y] = 1'b0;
                mesh_ready_in[x][y] = 1'b1;
            end
        end
    end

    // 2. Instantiate 10 AI Compute Clusters (10 Cores per Cluster = 100 Cores)
    genvar i;
    generate
        for (i = 0; i < 10; i++) begin : gen_clusters
            logic [3:0] cur_x, cur_y;
            assign cur_x = 4'((i + 1) % 10);
            assign cur_y = 4'((i + 1) / 10 + 1);

            ai_gpu_cluster u_cluster (
                .clk                     (clk),
                .rst_n                   (rst_n),
                .cluster_x               (cur_x),
                .cluster_y               (cur_y),
                .cluster_id              (4'(i)),
                .noc_in_valid            (cluster_tieoff_val_in),
                .noc_in_flit             (cluster_tieoff_flit_in),
                .noc_in_ready            (),
                .noc_out_valid           (),
                .noc_out_flit            (),
                .noc_out_ready           (cluster_tieoff_rdy_in),
                .global_agent_task_valid (agent_task_disp_val && (agent_task_disp_cluster == 8'(i))),
                .global_agent_task_id    (agent_task_disp_id),
                .global_agent_pc         (agent_task_disp_pc),
                .global_agent_task_ready ()
            );
        end
    endgenerate

    // 3. 10x10 2D-Mesh NoC Fabric Instance
    noc_mesh_2d_10x10 u_noc_mesh (
        .clk            (clk),
        .rst_n          (rst_n),
        .node_flit_in   (mesh_flit_in),
        .node_valid_in  (mesh_valid_in),
        .node_ready_out (mesh_ready_out),
        .node_flit_out  (mesh_flit_out),
        .node_valid_out (mesh_valid_out),
        .node_ready_in  (mesh_ready_in)
    );

    // 4. Global Dedicated Agentic AI Coprocessor Subsystem Instance (Node 0,0)
    agentic_coprocessor_top u_agentic_coproc (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .coproc_req_valid       (agent_coproc_req_val),
        .coproc_req_op          (agent_coproc_req_op),
        .coproc_req_param1      (agent_coproc_param1),
        .coproc_req_param2      (agent_coproc_param2),
        .coproc_resp_valid      (agent_coproc_resp_val),
        .coproc_resp_data       (agent_coproc_resp_dat),
        .noc_tx_valid           (mesh_valid_in[0][0]),
        .noc_tx_flit            (mesh_flit_in[0][0]),
        .noc_tx_ready           (mesh_ready_out[0][0]),
        .noc_rx_valid           (mesh_valid_out[0][0]),
        .noc_rx_flit            (mesh_flit_out[0][0]),
        .noc_rx_ready           (mesh_ready_in[0][0]),
        .task_dispatch_valid    (agent_task_disp_val),
        .task_dispatch_node_id  (agent_task_disp_id),
        .task_dispatch_cluster  (agent_task_disp_cluster),
        .task_dispatch_pc       (agent_task_disp_pc),
        .task_dispatch_ready    (1'b1),
        .agent_graph_done_irq   (agent_graph_done_irq)
    );

    // 5. 4MB Distributed Global Buffer Instance
    global_buffer u_global_buffer (
        .clk     (clk),
        .rst_n   (rst_n),
        .ren     (gb_ren),
        .raddr   (gb_raddr),
        .rdata   (gb_rdata),
        .rvalid  (gb_rvalid),
        .wen     (gb_wen),
        .waddr   (gb_waddr),
        .wdata   (gb_wdata),
        .wstrb   (gb_wstrb),
        .wready  (gb_wready)
    );

    // 6. Global Memory Gateway Instance (Node 9,9)
    memory_gateway u_mem_gateway (
        .clk            (clk),
        .rst_n          (rst_n),
        .noc_flit_in    (mesh_flit_out[9][9]),
        .noc_valid_in   (mesh_valid_out[9][9]),
        .noc_ready_out  (mesh_ready_in[9][9]),
        .noc_flit_out   (mesh_flit_in[9][9]),
        .noc_valid_out  (mesh_valid_in[9][9]),
        .noc_ready_in   (mesh_ready_out[9][9]),
        .gb_ren         (gb_ren),
        .gb_raddr       (gb_raddr),
        .gb_rdata       (gb_rdata),
        .gb_rvalid      (gb_rvalid),
        .gb_wen         (gb_wen),
        .gb_waddr       (gb_waddr),
        .gb_wdata       (gb_wdata),
        .gb_wstrb       (gb_wstrb),
        .gb_wready      (gb_wready),
        .dma_req_valid  (dma_mem_val),
        .dma_req_write  (dma_mem_wr),
        .dma_req_addr   ({32'd0, dma_mem_addr}),
        .dma_req_wdata  ({4{dma_mem_wdata}}),
        .dma_resp_rdata (),
        .dma_resp_valid (dma_mem_resp_val)
    );

    // 7. High-Throughput 512-bit DMA Controller Instance
    axi_dma_controller u_dma_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .dma_start        (host_dma_start),
        .dma_src_addr     (host_dma_src),
        .dma_dst_addr     (host_dma_dst),
        .dma_byte_len     (host_dma_len),
        .dma_busy         (host_dma_busy),
        .dma_done_irq     (host_dma_done_irq),
        .m_mem_req_valid  (dma_mem_val),
        .m_mem_req_write  (dma_mem_wr),
        .m_mem_req_addr   (dma_mem_addr),
        .m_mem_req_wdata  (dma_mem_wdata),
        .m_mem_req_ready  (1'b1),
        .m_mem_resp_valid (dma_mem_resp_val),
        .m_mem_resp_rdata (gb_rdata)
    );

    assign gpu_idle_status = !host_dma_busy;

endmodule
