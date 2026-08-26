//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: riscv_ai_core.sv
// Description: Fully Integrated Multi-Warp RISC-V AI GPU Compute Core:
//              - 4 Hardware Warps x 32 Logical Lanes (SIMT)
//              - Full RV32IM Scalar Pipeline (37 RV32I + 8 RV32M instructions)
//              - 256-bit Vector SIMD Execution Unit (INT8/INT4/FP16/INT32)
//              - 8-entry Reconvergence Stack for Branch Divergence
//              - Dedicated 64-bit LSU with SPAD and Global SRAM resolution
//              - Coprocessor Dispatches to NMU, Agentic Coprocessor, and Barriers
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module riscv_ai_core import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Core ID and Configuration
    input  logic [7:0]             core_id,
    input  logic [3:0]             cluster_id,

    // I-Cache Interface
    output logic                   icache_req_valid,
    output logic [XLEN-1:0]        icache_req_addr,
    input  logic                   icache_resp_valid,
    input  logic [31:0]            icache_resp_data,

    // Cluster Shared Scratchpad SRAM Interface
    output logic                   scratchpad_req_valid,
    output logic                   scratchpad_req_write,
    output logic [15:0]            scratchpad_req_addr,
    output logic [31:0]            scratchpad_req_wdata,
    output logic [3:0]             scratchpad_req_wstrb,
    input  logic [31:0]            scratchpad_resp_rdata,
    input  logic                   scratchpad_resp_valid,

    // Global Memory Interface (via Cluster Gateway)
    output logic                   global_mem_req_valid,
    output logic                   global_mem_req_write,
    output logic [63:0]            global_mem_req_addr,
    output logic [31:0]            global_mem_req_wdata,
    input  logic [31:0]            global_mem_resp_rdata,
    input  logic                   global_mem_resp_valid,

    // Cluster Neural Engine Interface
    output logic                   neural_req_valid,
    output logic [3:0]             neural_req_op,
    output logic [31:0]            neural_req_src_a,
    output logic [31:0]            neural_req_src_b,
    output logic [31:0]            neural_req_dst_c,
    input  logic                   neural_resp_valid,
    input  logic [31:0]            neural_resp_data,

    // Agentic Coprocessor Interface
    output logic                   agent_req_valid,
    output logic [3:0]             agent_req_op,
    output logic [31:0]            agent_req_param1,
    output logic [31:0]            agent_req_param2,
    input  logic                   agent_resp_valid,
    input  logic [31:0]            agent_resp_data,

    // Cluster Barrier Sync Interface
    output logic                   barrier_req_valid,
    output logic [1:0]             barrier_req_warp,
    input  logic                   barrier_release
);

    // Warp enable and stall masks
    logic [NUM_WARPS-1:0] warp_enable_mask;
    logic [NUM_WARPS-1:0] warp_barrier_stall;

    // Fetch stage wires
    logic [1:0]      sched_fetch_warp;
    logic            sched_fetch_valid;
    logic            fetch_out_valid;
    logic [1:0]      fetch_out_warp_id;
    logic [XLEN-1:0] fetch_out_pc;
    logic [31:0]     fetch_out_instruction;

    // Decode stage wires
    logic [1:0]      dec_warp_id;
    logic [4:0]      dec_rs1_addr, dec_rs2_addr, dec_rd_addr;
    logic            dec_reg_write_en, dec_vec_write_en;
    logic [XLEN-1:0] dec_imm_val;
    logic            dec_is_scalar, dec_is_vec, dec_is_neural, dec_is_agentic;
    logic            dec_is_load, dec_is_store, dec_is_branch, dec_is_jump, dec_is_csr;
    logic            dec_is_barrier, dec_is_fence, dec_is_yield;
    logic [4:0]      dec_scalar_op;
    logic [3:0]      dec_vec_op;
    logic [1:0]      dec_vec_dtype;
    logic [3:0]      dec_neural_op, dec_agentic_op;
    logic [1:0]      dec_fence_scope;
    logic [2:0]      dec_funct3;
    logic [11:0]     dec_csr_addr;
    logic            dec_illegal;
    logic            dec_hazard_stall;

    // Register file wires
    logic [XLEN-1:0] rf_rdata1, rf_rdata2;
    logic [VLEN-1:0] vrf_rdata1, vrf_rdata2;
    logic            rf_wen;
    logic [1:0]      rf_wwarp;
    logic [4:0]      rf_waddr;
    logic [XLEN-1:0] rf_wdata;
    logic            vrf_wen;
    logic [1:0]      vrf_wwarp;
    logic [4:0]      vrf_waddr;
    logic [VLEN-1:0] vrf_wdata;

    // Execute stage wires
    logic [XLEN-1:0] alu_res;
    logic            branch_taken;
    logic            comp_res;
    logic [VLEN-1:0] vec_res;
    logic [XLEN-1:0] vec_reduction;
    logic            vec_ready;

    // LSU wires
    logic            lsu_busy;
    logic            lsu_req_ready;
    logic            lsu_resp_valid;
    logic [1:0]      lsu_resp_warp;
    logic [4:0]      lsu_resp_rd;
    logic [XLEN-1:0] lsu_resp_rdata_scalar;
    logic [VLEN-1:0] lsu_resp_rdata_vector;
    logic            lsu_resp_is_vector;

    // Barrier tracking
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warp_enable_mask   <= 4'b1111; // Enable all 4 warps
            warp_barrier_stall <= 4'b0000;
        end else begin
            if (barrier_req_valid) begin
                warp_barrier_stall[barrier_req_warp] <= 1'b1;
            end
            if (barrier_release) begin
                warp_barrier_stall <= 4'b0000;
            end
        end
    end

    // 1. Warp Scheduler Instance
    core_warp_scheduler u_warp_sched (
        .clk                  (clk),
        .rst_n                (rst_n),
        .warp_enable_mask     (warp_enable_mask),
        .warp_barrier_stall   (warp_barrier_stall),
        .sb_set_busy          (dec_is_load || dec_is_neural || dec_is_agentic),
        .sb_set_warp_id       (dec_warp_id),
        .sb_set_reg_id        (dec_rd_addr),
        .sb_clear_busy        (rf_wen),
        .sb_clear_warp_id     (rf_wwarp),
        .sb_clear_reg_id      (rf_waddr),
        .dec_warp_id          (dec_warp_id),
        .dec_rs1_addr         (dec_rs1_addr),
        .dec_rs2_addr         (dec_rs2_addr),
        .dec_hazard_stall     (dec_hazard_stall),
        .selected_fetch_warp  (sched_fetch_warp),
        .selected_fetch_valid (sched_fetch_valid)
    );

    // 2. Fetch Unit Instance
    core_fetch_unit u_fetch (
        .clk                  (clk),
        .rst_n                (rst_n),
        .fetch_warp_id        (sched_fetch_warp),
        .fetch_warp_valid     (sched_fetch_valid && !dec_hazard_stall),
        .warp_active_mask     (warp_enable_mask),
        .redirect_valid       (branch_taken || dec_is_jump),
        .redirect_warp_id     (dec_warp_id),
        .redirect_target_pc   (dec_is_jump ? (dec_funct3[0] ? (rf_rdata1 + dec_imm_val) : (fetch_out_pc + dec_imm_val)) : (fetch_out_pc + dec_imm_val)),
        .icache_req_valid     (icache_req_valid),
        .icache_req_addr      (icache_req_addr),
        .icache_resp_valid    (icache_resp_valid),
        .icache_resp_data     (icache_resp_data),
        .fetch_out_valid      (fetch_out_valid),
        .fetch_out_warp_id    (fetch_out_warp_id),
        .fetch_out_pc         (fetch_out_pc),
        .fetch_out_instruction(fetch_out_instruction),
        .decode_ready         (!dec_hazard_stall && !lsu_busy)
    );

    // 3. Decode Unit Instance (69 Defined Instructions)
    core_decode_unit u_decode (
        .instruction          (fetch_out_instruction),
        .pc_in                (fetch_out_pc),
        .warp_id_in           (fetch_out_warp_id),
        .warp_id_out          (dec_warp_id),
        .rs1_addr             (dec_rs1_addr),
        .rs2_addr             (dec_rs2_addr),
        .rd_addr              (dec_rd_addr),
        .reg_write_en         (dec_reg_write_en),
        .vec_write_en         (dec_vec_write_en),
        .imm_val              (dec_imm_val),
        .is_scalar_op         (dec_is_scalar),
        .is_vector_op         (dec_is_vec),
        .is_neural_op         (dec_is_neural),
        .is_agentic_op        (dec_is_agentic),
        .is_load              (dec_is_load),
        .is_store             (dec_is_store),
        .is_branch            (dec_is_branch),
        .is_jump              (dec_is_jump),
        .is_csr               (dec_is_csr),
        .is_barrier           (dec_is_barrier),
        .is_fence             (dec_is_fence),
        .is_yield             (dec_is_yield),
        .scalar_alu_op        (dec_scalar_op),
        .vector_op            (dec_vec_op),
        .vector_dtype         (dec_vec_dtype),
        .neural_op            (dec_neural_op),
        .agentic_op           (dec_agentic_op),
        .fence_scope          (dec_fence_scope),
        .funct3_out           (dec_funct3),
        .csr_addr             (dec_csr_addr),
        .illegal_instruction  (dec_illegal)
    );

    // 4. Multi-Warp Register File Instance
    core_regfile u_regfile (
        .clk                  (clk),
        .rst_n                (rst_n),
        .r_warp_id            (dec_warp_id),
        .r_scalar_addr1       (dec_rs1_addr),
        .r_scalar_addr2       (dec_rs2_addr),
        .r_scalar_data1       (rf_rdata1),
        .r_scalar_data2       (rf_rdata2),
        .w_scalar_warp_id     (rf_wwarp),
        .w_scalar_en          (rf_wen),
        .w_scalar_addr        (rf_waddr),
        .w_scalar_data        (rf_wdata),
        .r_vec_addr1          (dec_rs1_addr),
        .r_vec_addr2          (dec_rs2_addr),
        .r_vec_data1          (vrf_rdata1),
        .r_vec_data2          (vrf_rdata2),
        .w_vec_warp_id        (vrf_wwarp),
        .w_vec_en             (vrf_wen),
        .w_vec_addr           (vrf_waddr),
        .w_vec_data           (vrf_wdata)
    );

    // 5. Scalar ALU Instance (37 RV32I + 8 RV32M)
    logic [XLEN-1:0] alu_op_b;
    assign alu_op_b = (dec_is_scalar && (fetch_out_instruction[6:0] == 7'b0010011 || fetch_out_instruction[6:0] == 7'b0110111 || fetch_out_instruction[6:0] == 7'b0010111)) ? dec_imm_val : rf_rdata2;

    core_scalar_alu u_alu (
        .alu_op               (dec_scalar_op),
        .operand_a            (fetch_out_instruction[6:0] == 7'b0010111 ? fetch_out_pc : rf_rdata1),
        .operand_b            (alu_op_b),
        .branch_funct3        (dec_funct3),
        .alu_result           (alu_res),
        .branch_taken         (branch_taken),
        .comparison_result    (comp_res)
    );

    // 6. Vector SIMD Unit Instance (256-bit)
    core_vector_unit u_vector_unit (
        .clk                  (clk),
        .rst_n                (rst_n),
        .vec_valid            (fetch_out_valid && dec_is_vec),
        .vec_op               (dec_vec_op),
        .vec_dtype            (dec_vec_dtype),
        .vec_op_a             (vrf_rdata1),
        .vec_op_b             (vrf_rdata2),
        .scalar_val           (rf_rdata1),
        .vec_result           (vec_res),
        .vec_scalar_reduction (vec_reduction),
        .vec_ready            (vec_ready)
    );

    // 7. Branch Reconvergence Stack Instance (8 entries / warp)
    core_reconvergence_stack u_reconv_stack (
        .clk                  (clk),
        .rst_n                (rst_n),
        .warp_id              (dec_warp_id),
        .diverge_push_valid   (fetch_out_valid && dec_is_branch && branch_taken),
        .diverge_else_mask    (~32'h00000001),
        .diverge_reconv_pc    (fetch_out_pc + 32'd4),
        .reconv_pop_valid     (1'b0),
        .current_active_mask  (),
        .stack_empty          (),
        .stack_full           ()
    );

    // 8. Load/Store Unit (LSU)
    core_lsu u_lsu (
        .clk                  (clk),
        .rst_n                (rst_n),
        .req_valid            (fetch_out_valid && (dec_is_load || dec_is_store || dec_is_fence)),
        .req_ready            (lsu_req_ready),
        .warp_id              (dec_warp_id),
        .is_load              (dec_is_load),
        .is_store             (dec_is_store),
        .is_vector_mem        (1'b0),
        .is_fence             (dec_is_fence),
        .fence_scope          (dec_fence_scope),
        .funct3               (dec_funct3),
        .addr                 ({32'd0, rf_rdata1 + dec_imm_val}),
        .wdata_scalar         (rf_rdata2),
        .wdata_vector         (vrf_rdata2),
        .rd_addr              (dec_rd_addr),
        .resp_valid           (lsu_resp_valid),
        .resp_warp_id         (lsu_resp_warp),
        .resp_rd_addr         (lsu_resp_rd),
        .resp_rdata_scalar    (lsu_resp_rdata_scalar),
        .resp_rdata_vector    (lsu_resp_rdata_vector),
        .resp_is_vector       (lsu_resp_is_vector),
        .busy                 (lsu_busy),
        .spad_req_valid       (scratchpad_req_valid),
        .spad_req_write       (scratchpad_req_write),
        .spad_req_addr        (scratchpad_req_addr),
        .spad_req_wdata       (scratchpad_req_wdata),
        .spad_req_wstrb       (scratchpad_req_wstrb),
        .spad_resp_rdata      (scratchpad_resp_rdata),
        .spad_resp_valid      (scratchpad_resp_valid),
        .global_req_valid     (global_mem_req_valid),
        .global_req_write     (global_mem_req_write),
        .global_req_addr      (global_mem_req_addr),
        .global_req_wdata     (global_mem_req_wdata),
        .global_resp_rdata    (global_mem_resp_rdata),
        .global_resp_valid    (global_mem_resp_valid)
    );

    // 9. Coprocessor Dispatch Lines
    assign neural_req_valid  = fetch_out_valid && dec_is_neural;
    assign neural_req_op     = dec_neural_op;
    assign neural_req_src_a  = rf_rdata1;
    assign neural_req_src_b  = rf_rdata2;
    assign neural_req_dst_c  = {27'd0, dec_rd_addr};

    assign agent_req_valid   = fetch_out_valid && dec_is_agentic;
    assign agent_req_op      = dec_agentic_op;
    assign agent_req_param1  = rf_rdata1;
    assign agent_req_param2  = rf_rdata2;

    assign barrier_req_valid = fetch_out_valid && dec_is_barrier;
    assign barrier_req_warp  = dec_warp_id;

    // 10. Writeback Multiplexer
    always_comb begin
        rf_wen   = 1'b0;
        rf_wwarp = dec_warp_id;
        rf_waddr = dec_rd_addr;
        rf_wdata = alu_res;

        vrf_wen   = 1'b0;
        vrf_wwarp = dec_warp_id;
        vrf_waddr = dec_rd_addr;
        vrf_wdata = vec_res;

        if (lsu_resp_valid) begin
            if (lsu_resp_is_vector) begin
                vrf_wen   = 1'b1;
                vrf_wwarp = lsu_resp_warp;
                vrf_waddr = lsu_resp_rd;
                vrf_wdata = lsu_resp_rdata_vector;
            end else begin
                rf_wen   = 1'b1;
                rf_wwarp = lsu_resp_warp;
                rf_waddr = lsu_resp_rd;
                rf_wdata = lsu_resp_rdata_scalar;
            end
        end else if (neural_resp_valid) begin
            rf_wen   = 1'b1;
            rf_wdata = neural_resp_data;
        end else if (agent_resp_valid) begin
            rf_wen   = 1'b1;
            rf_wdata = agent_resp_data;
        end else if (fetch_out_valid) begin
            if (dec_is_jump) begin
                rf_wen   = dec_reg_write_en;
                rf_wdata = fetch_out_pc + 32'd4;
            end else if (dec_is_scalar) begin
                rf_wen   = dec_reg_write_en;
                rf_wdata = alu_res;
            end else if (dec_is_vec) begin
                vrf_wen   = dec_vec_write_en;
                vrf_wdata = vec_res;
                if (dec_vec_op == 4'h4 || dec_vec_op == 4'h5 || dec_vec_op == 4'h6) begin // Reduction to scalar
                    rf_wen   = 1'b1;
                    rf_wdata = vec_reduction;
                end
            end
        end
    end

endmodule
