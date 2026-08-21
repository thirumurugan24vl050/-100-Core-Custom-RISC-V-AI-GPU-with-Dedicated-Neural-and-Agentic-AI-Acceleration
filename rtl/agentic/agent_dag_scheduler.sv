//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: agent_dag_scheduler.sv
// Description: Hardware Agent Task DAG Scheduler with 64-Node Dependency Matrix.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module agent_dag_scheduler import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Task Insertion Interface (from Host / Master Core)
    input  logic                   insert_task_valid,
    input  logic [DAG_NODE_ID_WIDTH-1:0] insert_node_id,
    input  logic [2:0]             insert_priority,
    input  logic [MAX_DAG_NODES-1:0] insert_dep_mask,
    input  logic [7:0]             insert_cluster_target,
    input  logic [31:0]            insert_pc_start,
    input  logic [31:0]            insert_context_ptr,
    output logic                   insert_task_ready,

    // Task Completion Event (from Clusters / Cores)
    input  logic                   task_complete_valid,
    input  logic [DAG_NODE_ID_WIDTH-1:0] task_complete_id,

    // Task Dispatch Port (to Idle Cores / Clusters)
    output logic                   dispatch_valid,
    output logic [DAG_NODE_ID_WIDTH-1:0] dispatch_node_id,
    output logic [7:0]             dispatch_cluster_target,
    output logic [31:0]            dispatch_pc_start,
    output logic [31:0]            dispatch_context_ptr,
    input  logic                   dispatch_ready,

    // Status & Telemetry
    output logic [6:0]             active_task_count,
    output logic [MAX_DAG_NODES-1:0] completed_task_mask
);

    // 64-Node DAG Table
    agent_dag_node_t dag_nodes [MAX_DAG_NODES-1:0];

    // Global Completion Bitmask
    logic [MAX_DAG_NODES-1:0] completed_mask;
    assign completed_task_mask = completed_mask;

    // Ready task evaluation mask
    logic [MAX_DAG_NODES-1:0] node_ready_mask;
    logic [6:0]               active_count;
    assign active_task_count = active_count;
    assign insert_task_ready = (active_count < MAX_DAG_NODES);

    // Dependency Resolution (Combinational bitwise evaluation)
    always_comb begin
        for (int i = 0; i < MAX_DAG_NODES; i++) begin
            // A node is ready if valid, not running, not completed, and all prerequisite tasks in dep_mask are complete
            if (dag_nodes[i].valid && !dag_nodes[i].running && !dag_nodes[i].completed &&
                ((dag_nodes[i].dependency_mask & ~completed_mask) == '0)) begin
                node_ready_mask[i] = 1'b1;
            end else begin
                node_ready_mask[i] = 1'b0;
            end
        end
    end

    // Priority-Based Task Selection Arbiter
    logic [DAG_NODE_ID_WIDTH-1:0] highest_prio_node;
    logic                         found_candidate;

    always_comb begin
        highest_prio_node = '0;
        found_candidate   = 1'b0;

        // Iterate through priority levels (7 down to 0)
        for (int p = 7; p >= 0; p--) begin
            if (!found_candidate) begin
                for (int n = 0; n < MAX_DAG_NODES; n++) begin
                    if (!found_candidate && node_ready_mask[n] && (dag_nodes[n].task_prio == 3'(p))) begin
                        highest_prio_node = 6'(n);
                        found_candidate   = 1'b1;
                    end
                end
            end
        end
    end

    // Dispatch Interface Drive
    assign dispatch_valid          = found_candidate;
    assign dispatch_node_id        = highest_prio_node;
    assign dispatch_cluster_target = dag_nodes[highest_prio_node].cluster_target;
    assign dispatch_pc_start       = dag_nodes[highest_prio_node].instruction_ptr;
    assign dispatch_context_ptr    = dag_nodes[highest_prio_node].context_ptr;

    // State Updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            completed_mask <= '0;
            active_count   <= '0;
            for (int i = 0; i < MAX_DAG_NODES; i++) begin
                dag_nodes[i].valid           <= 1'b0;
                dag_nodes[i].ready           <= 1'b0;
                dag_nodes[i].running         <= 1'b0;
                dag_nodes[i].completed       <= 1'b0;
                dag_nodes[i].node_id         <= 6'(i);
                dag_nodes[i].task_prio       <= '0;
                dag_nodes[i].dependency_mask <= '0;
                dag_nodes[i].cluster_target  <= '0;
                dag_nodes[i].instruction_ptr <= '0;
                dag_nodes[i].context_ptr     <= '0;
            end
        end else begin
            // 1. Task Insertion
            if (insert_task_valid && insert_task_ready) begin
                dag_nodes[insert_node_id].valid           <= 1'b1;
                dag_nodes[insert_node_id].running         <= 1'b0;
                dag_nodes[insert_node_id].completed       <= 1'b0;
                dag_nodes[insert_node_id].task_prio       <= insert_priority;
                dag_nodes[insert_node_id].dependency_mask <= insert_dep_mask;
                dag_nodes[insert_node_id].cluster_target  <= insert_cluster_target;
                dag_nodes[insert_node_id].instruction_ptr <= insert_pc_start;
                dag_nodes[insert_node_id].context_ptr     <= insert_context_ptr;
                active_count <= active_count + 7'd1;
            end

            // 2. Task Dispatch Mark
            if (dispatch_valid && dispatch_ready) begin
                dag_nodes[dispatch_node_id].running <= 1'b1;
            end

            // 3. Task Completion Event
            if (task_complete_valid) begin
                dag_nodes[task_complete_id].completed <= 1'b1;
                dag_nodes[task_complete_id].running   <= 1'b0;
                completed_mask[task_complete_id]      <= 1'b1;
                if (active_count > 0)
                    active_count <= active_count - 7'd1;
            end
        end
    end

endmodule
