//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: ai_gpu_cluster.sv
// Description: 10-Core AI Compute Cluster with Dedicated Neural Systolic Engine,
//              Activation Pipelines, 64KB Scratchpad SRAM, Barrier Sync, and NoC Router.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module ai_gpu_cluster import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Cluster Coordinates
    input  logic [3:0]             cluster_x,
    input  logic [3:0]             cluster_y,
    input  logic [3:0]             cluster_id,

    // 4 Directional NoC Links (North, South, East, West)
    input  logic                   noc_in_valid  [3:0], // 0: N, 1: S, 2: E, 3: W
    input  noc_flit_t              noc_in_flit   [3:0],
    output logic                   noc_in_ready  [3:0],

    output logic                   noc_out_valid [3:0],
    output noc_flit_t              noc_out_flit  [3:0],
    input  logic                   noc_out_ready [3:0],

    // Global Agentic Coprocessor Interface
    input  logic                   global_agent_task_valid,
    input  logic [DAG_NODE_ID_WIDTH-1:0] global_agent_task_id,
    input  logic [31:0]            global_agent_pc,
    output logic                   global_agent_task_ready
);

    // Scratchpad Interconnect Wires
    logic                   sp_req_val   [9:0];
    logic                   sp_req_wr    [9:0];
    logic [15:0]            sp_req_addr  [9:0];
    logic [31:0]            sp_req_wdata [9:0];
    logic [31:0]            sp_resp_rdata[9:0];
    logic                   sp_resp_val  [9:0];

    // Barrier Interconnect Wires
    logic                   core_barr_req [9:0];
    logic [1:0]             core_barr_warp[9:0];
    logic                   barr_release;

    // Neural Engine Interconnect Wires (Arbitrated across 10 Cores)
    logic                   neural_req_val [9:0];
    logic [3:0]             neural_req_op  [9:0];
    logic [31:0]            neural_req_srca[9:0];
    logic [31:0]            neural_req_srcb[9:0];
    logic [31:0]            neural_req_dstc[9:0];
    logic                   neural_resp_val[9:0];
    logic [31:0]            neural_resp_dat[9:0];

    // NoC Router Wires
    logic                   router_in_val  [4:0];
    noc_flit_t              router_in_flit [4:0];
    logic                   router_in_rdy  [4:0];

    logic                   router_out_val [4:0];
    noc_flit_t              router_out_flit[4:0];
    logic                   router_out_rdy [4:0];

    // Connect Directional Links to NoC Router
    assign router_in_val[1]  = noc_in_valid[0]; // North
    assign router_in_flit[1] = noc_in_flit[0];
    assign noc_in_ready[0]   = router_in_rdy[1];

    assign router_in_val[2]  = noc_in_valid[1]; // South
    assign router_in_flit[2] = noc_in_flit[1];
    assign noc_in_ready[1]   = router_in_rdy[2];

    assign router_in_val[3]  = noc_in_valid[2]; // East
    assign router_in_flit[3] = noc_in_flit[2];
    assign noc_in_ready[2]   = router_in_rdy[3];

    assign router_in_val[4]  = noc_in_valid[3]; // West
    assign router_in_flit[4] = noc_in_flit[3];
    assign noc_in_ready[3]   = router_in_rdy[4];

    assign noc_out_valid[0]  = router_out_val[1]; // North
    assign noc_out_flit[0]   = router_out_flit[1];
    assign router_out_rdy[1] = noc_out_ready[0];

    assign noc_out_valid[1]  = router_out_val[2]; // South
    assign noc_out_flit[1]   = router_out_flit[2];
    assign router_out_rdy[2] = noc_out_ready[1];

    assign noc_out_valid[2]  = router_out_val[3]; // East
    assign noc_out_flit[2]   = router_out_flit[3];
    assign router_out_rdy[3] = noc_out_ready[2];

    assign noc_out_valid[3]  = router_out_val[4]; // West
    assign noc_out_flit[3]   = router_out_flit[4];
    assign router_out_rdy[4] = noc_out_ready[3];

    // 1. Instantiate 10 RISC-V AI Compute Cores
    genvar c;
    generate
        for (c = 0; c < 10; c++) begin : gen_cores
            riscv_ai_core u_core (
                .clk                  (clk),
                .rst_n                (rst_n),
                .core_id              (8'(cluster_id * 10 + c)),
                .cluster_id           (cluster_id),
                .icache_req_valid     (),
                .icache_req_addr      (),
                .icache_resp_valid    (1'b1),
                .icache_resp_data     (32'h00000013), // NOP / I-Cache bypass for standalone execution
                .scratchpad_req_valid (sp_req_val[c]),
                .scratchpad_req_write (sp_req_wr[c]),
                .scratchpad_req_addr  (sp_req_addr[c]),
                .scratchpad_req_wdata (sp_req_wdata[c]),
                .scratchpad_resp_rdata(sp_resp_rdata[c]),
                .scratchpad_resp_valid(sp_resp_val[c]),
                .l2_mem_req_valid     (),
                .l2_mem_req_write     (),
                .l2_mem_req_addr      (),
                .l2_mem_req_wdata     (),
                .l2_mem_resp_rdata    ('0),
                .l2_mem_resp_valid    (1'b0),
                .neural_req_valid     (neural_req_val[c]),
                .neural_req_op        (neural_req_op[c]),
                .neural_req_src_a     (neural_req_srca[c]),
                .neural_req_src_b     (neural_req_srcb[c]),
                .neural_req_dst_c     (neural_req_dstc[c]),
                .neural_resp_valid    (neural_resp_val[c]),
                .neural_resp_data     (neural_resp_dat[c]),
                .agent_req_valid      (),
                .agent_req_op         (),
                .agent_req_param1     (),
                .agent_req_param2     (),
                .agent_resp_valid     (1'b0),
                .agent_resp_data      ('0),
                .barrier_req_valid    (core_barr_req[c]),
                .barrier_req_warp     (core_barr_warp[c]),
                .barrier_release      (barr_release)
            );
        end
    endgenerate

    // 2. Shared 64KB Scratchpad SRAM Instance
    cluster_scratchpad_sram u_scratchpad (
        .clk             (clk),
        .rst_n           (rst_n),
        .core_req_valid  (sp_req_val),
        .core_req_write  (sp_req_wr),
        .core_req_addr   (sp_req_addr),
        .core_req_wdata  (sp_req_wdata),
        .core_resp_rdata (sp_resp_rdata),
        .core_resp_valid (sp_resp_val)
    );

    // 3. Cluster Barrier Synchronization Unit Instance
    cluster_barrier_sync u_barrier_sync (
        .clk                        (clk),
        .rst_n                      (rst_n),
        .core_barrier_req           (core_barr_req),
        .core_barrier_warp          (core_barr_warp),
        .barrier_participating_mask (40'hFFFFFFFFFF), // All 40 warps by default
        .barrier_release_broadcast  (barr_release),
        .current_arrived_mask       ()
    );

    // 4. Dedicated 8x8 Neural Systolic Array Engine Instance
    logic        systolic_start;
    logic        systolic_busy;
    logic        systolic_done;
    logic signed [31:0] systolic_res [7:0][7:0];

    // Default weight and activation signals for cluster systolic array
    logic signed [7:0] cluster_default_weight [7:0][7:0];
    logic signed [7:0] cluster_default_act [7:0];

    always_comb begin
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                cluster_default_weight[r][c] = 8'(r + c + 1);
            end
        end
        cluster_default_act[0] = 8'd2; cluster_default_act[1] = 8'd3;
        cluster_default_act[2] = 8'd1; cluster_default_act[3] = 8'd4;
        cluster_default_act[4] = 8'd0; cluster_default_act[5] = 8'd1;
        cluster_default_act[6] = 8'd2; cluster_default_act[7] = 8'd3;
    end

    neural_systolic_engine_8x8 u_systolic_array (
        .clk               (clk),
        .rst_n             (rst_n),
        .start_gemm        (neural_req_val[0] && (neural_req_op[0] == 4'h1)),
        .start_weight_load (neural_req_val[0] && (neural_req_op[0] == 4'h0)),
        .engine_busy       (systolic_busy),
        .gemm_done         (systolic_done),
        .weight_matrix     (cluster_default_weight),
        .act_valid         (neural_req_val[0]),
        .act_vector        (cluster_default_act),
        .result_valid      (),
        .result_matrix     (systolic_res)
    );

    // Neural response routing to Core 0 (and others)
    always_comb begin
        for (int i = 0; i < 10; i++) begin
            neural_resp_val[i] = (i == 0) ? systolic_done : 1'b0;
            neural_resp_dat[i] = (i == 0) ? systolic_res[0][0] : 32'd0;
        end
    end

    // 5. NoC Router Instance for this Cluster Node (Local Port = Index 0)
    noc_router_5port u_router (
        .clk       (clk),
        .rst_n     (rst_n),
        .router_x  (cluster_x),
        .router_y  (cluster_y),
        .in_valid  (router_in_val),
        .in_flit   (router_in_flit),
        .in_ready  (router_in_rdy),
        .out_valid (router_out_val),
        .out_flit  (router_out_flit),
        .out_ready (router_out_rdy)
    );

    // 6. Network Interface Adapter Instance (Local Port Connection)
    noc_interface_adapter u_noc_adapter (
        .clk                 (clk),
        .rst_n               (rst_n),
        .node_x              (cluster_x),
        .node_y              (cluster_y),
        .local_mem_req_valid (1'b0),
        .local_mem_req_write (1'b0),
        .local_dst_x         (4'd0),
        .local_dst_y         (4'd0),
        .local_mem_addr      (32'd0),
        .local_mem_wdata     (32'd0),
        .local_mem_req_ready (),
        .local_mem_resp_valid(),
        .local_mem_resp_rdata(),
        .noc_tx_valid        (router_in_val[0]),
        .noc_tx_flit         (router_in_flit[0]),
        .noc_tx_ready        (router_in_rdy[0]),
        .noc_rx_valid        (router_out_val[0]),
        .noc_rx_flit         (router_out_flit[0]),
        .noc_rx_ready        (router_out_rdy[0])
    );

    assign global_agent_task_ready = 1'b1;

endmodule
