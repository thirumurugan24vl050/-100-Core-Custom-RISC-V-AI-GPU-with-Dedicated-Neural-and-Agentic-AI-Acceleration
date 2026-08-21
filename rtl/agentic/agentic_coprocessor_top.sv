//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: agentic_coprocessor_top.sv
// Description: Top-Level Agentic AI Coprocessor Subsystem.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module agentic_coprocessor_top import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Core / Host CSR & Instruction Request Port
    input  logic                   coproc_req_valid,
    input  logic [3:0]             coproc_req_op,
    input  logic [31:0]            coproc_req_param1,
    input  logic [31:0]            coproc_req_param2,
    output logic                   coproc_resp_valid,
    output logic [31:0]            coproc_resp_data,

    // Outbound NoC Network Interface
    output logic                   noc_tx_valid,
    output noc_flit_t              noc_tx_flit,
    input  logic                   noc_tx_ready,

    // Inbound NoC Network Interface
    input  logic                   noc_rx_valid,
    input  noc_flit_t              noc_rx_flit,
    output logic                   noc_rx_ready,

    // Task Dispatch Port to Clusters
    output logic                   task_dispatch_valid,
    output logic [DAG_NODE_ID_WIDTH-1:0] task_dispatch_node_id,
    output logic [7:0]             task_dispatch_cluster,
    output logic [31:0]            task_dispatch_pc,
    input  logic                   task_dispatch_ready,

    // Hardware Event Interrupt to Host
    output logic                   agent_graph_done_irq
);

    // Internal Wires
    logic [6:0]             active_dag_tasks;
    logic [MAX_DAG_NODES-1:0] completed_dag_mask;
    logic                   task_complete_sig;
    logic [DAG_NODE_ID_WIDTH-1:0] task_complete_id;

    // KV Cache wires
    logic                   kv_req_val;
    logic [1:0]             kv_req_op;
    logic [5:0]             kv_ctx;
    logic [9:0]             kv_vpage;
    logic                   kv_resp_val;
    logic [KV_PAGE_ID_WIDTH-1:0] kv_resp_ppage;
    logic                   kv_hit;
    logic                   kv_err;

    // Tree Search wires
    logic                   tree_req_val;
    logic                   tree_resp_val;
    logic [2:0]             tree_best_idx;
    logic [15:0]            tree_best_score;
    logic [7:0]             tree_prune_mask;

    // Token Router wires
    logic                   token_in_val;
    logic                   token_in_rdy;
    logic                   token_comp_val;
    logic [15:0]            token_comp_id;
    logic [5:0]             token_comp_agent;

    // Map Coprocessor Request Opcode to Sub-modules
    always_comb begin
        kv_req_val   = 1'b0;
        kv_req_op    = 2'b00;
        kv_ctx       = coproc_req_param1[5:0];
        kv_vpage     = coproc_req_param2[9:0];
        tree_req_val = 1'b0;
        token_in_val = 1'b0;

        if (coproc_req_valid) begin
            case (coproc_req_op)
                AGENT_OP_KV_ALLOC: begin
                    kv_req_val = 1'b1;
                    kv_req_op  = 2'b01;
                end
                AGENT_OP_KV_FREE: begin
                    kv_req_val = 1'b1;
                    kv_req_op  = 2'b10;
                end
                AGENT_OP_KV_LOOKUP: begin
                    kv_req_val = 1'b1;
                    kv_req_op  = 2'b00;
                end
                AGENT_OP_TREE_EVAL: begin
                    tree_req_val = 1'b1;
                end
                AGENT_OP_TOKEN_ROUTE: begin
                    token_in_val = 1'b1;
                end
                default: ;
            endcase
        end
    end

    // 1. DAG Task Scheduler Instance
    agent_dag_scheduler u_dag_sched (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .insert_task_valid      (coproc_req_valid && (coproc_req_op == AGENT_OP_DAG_INSERT)),
        .insert_node_id         (coproc_req_param1[5:0]),
        .insert_priority        (coproc_req_param1[8:6]),
        .insert_dep_mask        ({32'd0, coproc_req_param2}),
        .insert_cluster_target  (coproc_req_param1[23:16]),
        .insert_pc_start        (32'h00001000), // Default test agent task entry
        .insert_context_ptr     (coproc_req_param2),
        .insert_task_ready      (),
        .task_complete_valid    (task_complete_sig || token_comp_val),
        .task_complete_id       (task_complete_id),
        .dispatch_valid         (task_dispatch_valid),
        .dispatch_node_id       (task_dispatch_node_id),
        .dispatch_cluster_target(task_dispatch_cluster),
        .dispatch_pc_start      (task_dispatch_pc),
        .dispatch_context_ptr   (),
        .dispatch_ready         (task_dispatch_ready),
        .active_task_count      (active_dag_tasks),
        .completed_task_mask    (completed_dag_mask)
    );

    // 2. Paged KV-Cache Manager Instance
    paged_kv_cache_mgr u_kv_mgr (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .kv_req_valid           (kv_req_val),
        .kv_req_op              (kv_req_op),
        .kv_context_id          (kv_ctx),
        .kv_virtual_page        (kv_vpage),
        .kv_resp_valid          (kv_resp_val),
        .kv_resp_physical_page  (kv_resp_ppage),
        .kv_resp_hit            (kv_hit),
        .kv_resp_error          (kv_err),
        .free_page_count        (),
        .allocated_page_count   ()
    );

    // 3. Speculative Tree Search Engine Instance
    agent_tree_search_engine u_tree_search (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .eval_req_valid         (tree_req_val),
        .temperature_threshold  (coproc_req_param2[15:0]),
        .branch_q_values        ('{16'd200, 16'd180, 16'd220, 16'd150, 16'd90, 16'd110, 16'd300, 16'd250}),
        .branch_visit_counts    ('{16'd10, 16'd8, 16'd12, 16'd5, 16'd2, 16'd4, 16'd20, 16'd15}),
        .total_visit_count      (16'd76),
        .eval_resp_valid        (tree_resp_val),
        .best_branch_idx        (tree_best_idx),
        .best_branch_score      (tree_best_score),
        .valid_branch_mask      (tree_prune_mask)
    );

    // 4. Multi-Agent Token Router Instance
    agent_token_router u_token_router (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .token_in_valid         (token_in_val),
        .token_id               (coproc_req_param1[15:0]),
        .agent_id               (coproc_req_param1[21:16]),
        .target_cluster         (coproc_req_param2[7:4]),
        .target_core            (coproc_req_param2[3:0]),
        .token_embedding        ({32'd0, coproc_req_param2}),
        .token_in_ready         (token_in_rdy),
        .noc_tx_valid           (noc_tx_valid),
        .noc_tx_flit            (noc_tx_flit),
        .noc_tx_ready           (noc_tx_ready),
        .noc_rx_valid           (noc_rx_valid),
        .noc_rx_flit            (noc_rx_flit),
        .noc_rx_ready           (noc_rx_ready),
        .token_complete_valid   (token_comp_val),
        .token_complete_id      (token_comp_id),
        .token_complete_agent   (token_comp_agent)
    );

    assign task_complete_sig = coproc_req_valid && (coproc_req_op == AGENT_OP_DAG_FIRE);
    assign task_complete_id  = coproc_req_param1[DAG_NODE_ID_WIDTH-1:0];

    // Response Data Multiplexing
    always_comb begin
        coproc_resp_valid = 1'b0;
        coproc_resp_data  = '0;

        if (kv_resp_val) begin
            coproc_resp_valid = 1'b1;
            coproc_resp_data  = {20'd0, kv_hit, kv_err, kv_resp_ppage};
        end else if (tree_resp_val) begin
            coproc_resp_valid = 1'b1;
            coproc_resp_data  = {8'd0, tree_prune_mask, 5'd0, tree_best_idx, tree_best_score};
        end else if (coproc_req_valid) begin
            coproc_resp_valid = 1'b1;
            coproc_resp_data  = {25'd0, active_dag_tasks};
        end
    end

    assign agent_graph_done_irq = (active_dag_tasks == 0) && (completed_dag_mask != 0);

endmodule
