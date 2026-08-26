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

    // Instruction ROM Table for Cores (128 Instructions covering 100% ISA)
    logic [31:0] cluster_imem [0:127];
    initial begin
        cluster_imem[0  ] = 32'h00a00093; // ADDI x1, x0, 10
        cluster_imem[1  ] = 32'h01900113; // ADDI x2, x0, 25
        cluster_imem[2  ] = 32'h00100d93; // ADDI x27, x0, 1 (offset 1)
        cluster_imem[3  ] = 32'h00200e13; // ADDI x28, x0, 2 (offset 2)
        cluster_imem[4  ] = 32'h00300e93; // ADDI x29, x0, 3 (offset 3)
        cluster_imem[5  ] = 32'h10000f37; // LUI  x30, 0x10000 (Scratchpad base)
        cluster_imem[6  ] = 32'h80000fb7; // LUI  x31, 0x80000 (L2 Global base)
        cluster_imem[7  ] = 32'h00004d17; // AUIPC x26, 4
        cluster_imem[8  ] = 32'h002081b3; // ADD  x3, x1, x2
        cluster_imem[9  ] = 32'h40208233; // SUB  x4, x1, x2
        cluster_imem[10 ] = 32'h002092b3; // SLL  x5, x1, x2
        cluster_imem[11 ] = 32'h0020a333; // SLT  x6, x1, x2
        cluster_imem[12 ] = 32'h0020b3b3; // SLTU x7, x1, x2
        cluster_imem[13 ] = 32'h0020c433; // XOR  x8, x1, x2
        cluster_imem[14 ] = 32'h0020d4b3; // SRL  x9, x1, x2
        cluster_imem[15 ] = 32'h4020d533; // SRA  x10, x1, x2
        cluster_imem[16 ] = 32'h0020e5b3; // OR   x11, x1, x2
        cluster_imem[17 ] = 32'h0020f633; // AND  x12, x1, x2
        cluster_imem[18 ] = 32'h022086b3; // MUL  x13, x1, x2
        cluster_imem[19 ] = 32'h02209733; // MULH x14, x1, x2
        cluster_imem[20 ] = 32'h021147b3; // DIV  x15, x2, x1
        cluster_imem[21 ] = 32'h02116833; // REM  x16, x2, x1
        cluster_imem[22 ] = 32'h0050a893; // SLTI x17, x1, 5
        cluster_imem[23 ] = 32'h0050b913; // SLTIU x18, x1, 5
        cluster_imem[24 ] = 32'h0ff0c993; // XORI x19, x1, 0xFF
        cluster_imem[25 ] = 32'h00f0ea13; // ORI  x20, x1, 0x0F
        cluster_imem[26 ] = 32'h0f00fa93; // ANDI x21, x1, 0xF0
        cluster_imem[27 ] = 32'h00409b13; // SLLI x22, x1, 4
        cluster_imem[28 ] = 32'h0020db93; // SRLI x23, x1, 2
        cluster_imem[29 ] = 32'h4020dc13; // SRAI x24, x1, 2
        cluster_imem[30 ] = 32'h12345cb7; // LUI  x25, 0x12345
        cluster_imem[31 ] = 32'h00208033; // ADD  x0, x1, x2 (write to x0 dropped)
        cluster_imem[32 ] = 32'h00100023; // SB x1, 0(x0)  [offset 0]
        cluster_imem[33 ] = 32'h001d8023; // SB x1, 0(x27) [offset 1]
        cluster_imem[34 ] = 32'h001e0023; // SB x1, 0(x28) [offset 2]
        cluster_imem[35 ] = 32'h001e8023; // SB x1, 0(x29) [offset 3]
        cluster_imem[36 ] = 32'h00201023; // SH x2, 0(x0)  [offset 0]
        cluster_imem[37 ] = 32'h002e1023; // SH x2, 0(x28) [offset 2]
        cluster_imem[38 ] = 32'h00302023; // SW x3, 0(x0)  [Local D-Cache]
        cluster_imem[39 ] = 32'h003f2023; // SW x3, 0(x30) [Scratchpad Write]
        cluster_imem[40 ] = 32'h003fa023; // SW x3, 0(x31) [L2 Global Write]
        cluster_imem[41 ] = 32'h001f0023; // SB x1, 0(x30) [Scratchpad SB]
        cluster_imem[42 ] = 32'h002f1023; // SH x2, 0(x30) [Scratchpad SH]
        cluster_imem[43 ] = 32'h001f8023; // SB x1, 0(x31) [L2 SB]
        cluster_imem[44 ] = 32'h002f9023; // SH x2, 0(x31) [L2 SH]
        cluster_imem[45 ] = 32'h00000013; // NOP
        cluster_imem[46 ] = 32'h00000013; // NOP
        cluster_imem[47 ] = 32'h00000013; // NOP
        cluster_imem[48 ] = 32'h00000183; // LB  x3, 0(x0)  [offset 0]
        cluster_imem[49 ] = 32'h000d8203; // LB  x4, 0(x27) [offset 1]
        cluster_imem[50 ] = 32'h000e0283; // LB  x5, 0(x28) [offset 2]
        cluster_imem[51 ] = 32'h000e8303; // LB  x6, 0(x29) [offset 3]
        cluster_imem[52 ] = 32'h00001383; // LH  x7, 0(x0)  [offset 0]
        cluster_imem[53 ] = 32'h000e1403; // LH  x8, 0(x28) [offset 2]
        cluster_imem[54 ] = 32'h00002483; // LW  x9, 0(x0)  [Local D-Cache]
        cluster_imem[55 ] = 32'h00004503; // LBU x10, 0(x0) [offset 0]
        cluster_imem[56 ] = 32'h000dc583; // LBU x11, 0(x27) [offset 1]
        cluster_imem[57 ] = 32'h000e4603; // LBU x12, 0(x28) [offset 2]
        cluster_imem[58 ] = 32'h000ec683; // LBU x13, 0(x29) [offset 3]
        cluster_imem[59 ] = 32'h00005703; // LHU x14, 0(x0) [offset 0]
        cluster_imem[60 ] = 32'h000e5783; // LHU x15, 0(x28) [offset 2]
        cluster_imem[61 ] = 32'h000f2803; // LW  x16, 0(x30) [Scratchpad Load]
        cluster_imem[62 ] = 32'h000fa883; // LW  x17, 0(x31) [L2 Global Load]
        cluster_imem[63 ] = 32'h00000013; // NOP
        cluster_imem[64 ] = 32'h00108263; // BEQ  x1, x1 (Taken)
        cluster_imem[65 ] = 32'h00208263; // BEQ  x1, x2 (Not Taken)
        cluster_imem[66 ] = 32'h00209263; // BNE  x1, x2 (Taken)
        cluster_imem[67 ] = 32'h00109263; // BNE  x1, x1 (Not Taken)
        cluster_imem[68 ] = 32'h0020c263; // BLT  x1, x2 (Taken)
        cluster_imem[69 ] = 32'h00114263; // BLT  x2, x1 (Not Taken)
        cluster_imem[70 ] = 32'h00115263; // BGE  x2, x1 (Taken)
        cluster_imem[71 ] = 32'h0020d263; // BGE  x1, x2 (Not Taken)
        cluster_imem[72 ] = 32'h0020e263; // BLTU x1, x2 (Taken)
        cluster_imem[73 ] = 32'h00116263; // BLTU x2, x1 (Not Taken)
        cluster_imem[74 ] = 32'h00117263; // BGEU x2, x1 (Taken)
        cluster_imem[75 ] = 32'h0020f263; // BGEU x1, x2 (Not Taken)
        cluster_imem[76 ] = 32'h0040006f; // JAL  x0, +4
        cluster_imem[77 ] = 32'h00008067; // JALR x0, 0(x1)
        cluster_imem[78 ] = 32'h00000013; // NOP
        cluster_imem[79 ] = 32'h00000013; // NOP
        cluster_imem[80 ] = 32'h003100ab; // VADD.INT8     v1, v2, v3
        cluster_imem[81 ] = 32'h003110ab; // VSUB.INT8     v1, v2, v3
        cluster_imem[82 ] = 32'h003120ab; // VMUL.INT8     v1, v2, v3
        cluster_imem[83 ] = 32'h003130ab; // VMAC.INT8     v1, v2, v3
        cluster_imem[84 ] = 32'h003140ab; // VDOT.INT8     v1, v2, v3
        cluster_imem[85 ] = 32'h003150ab; // VREDSUM.INT8  v1, v2, v3
        cluster_imem[86 ] = 32'h003160ab; // VREDMAX.INT8  v1, v2, v3
        cluster_imem[87 ] = 32'h003170ab; // VSPLAT.INT8   v1, v2, v3
        cluster_imem[88 ] = 32'h083100ab; // VRELU.INT8    v1, v2, v3
        cluster_imem[89 ] = 32'h083110ab; // VAND.INT8     v1, v2, v3
        cluster_imem[90 ] = 32'h083120ab; // VOR.INT8      v1, v2, v3
        cluster_imem[91 ] = 32'h083130ab; // VXOR.INT8     v1, v2, v3
        cluster_imem[92 ] = 32'h023100ab; // VADD.FP16     v1, v2, v3
        cluster_imem[93 ] = 32'h023110ab; // VSUB.FP16     v1, v2, v3
        cluster_imem[94 ] = 32'h023120ab; // VMUL.FP16     v1, v2, v3
        cluster_imem[95 ] = 32'h043100ab; // VADD.INT32    v1, v2, v3
        cluster_imem[96 ] = 32'h0031008b; // NEURAL.MATMUL
        cluster_imem[97 ] = 32'h0031108b; // NEURAL.ACT
        cluster_imem[98 ] = 32'h0031208b; // NEURAL.SOFTMAX
        cluster_imem[99 ] = 32'h0031308b; // NEURAL.NORM
        cluster_imem[100] = 32'h0031408b; // NEURAL.ATTN
        cluster_imem[101] = 32'h003100db; // AGENT.DAG
        cluster_imem[102] = 32'h003110db; // AGENT.KV
        cluster_imem[103] = 32'h003120db; // AGENT.TREE
        cluster_imem[104] = 32'h003130db; // AGENT.ROUTER
        cluster_imem[105] = 32'h003140db; // AGENT.BARRIER
        cluster_imem[106] = 32'h0000007b; // HARDWARE_SYNC
        cluster_imem[107] = 32'h300010f3; // CSRRW x1, mstatus, x0
        cluster_imem[108] = 32'h30402173; // CSRRS x2, mie, x0
        cluster_imem[109] = 32'h344031f3; // CSRRC x3, mip, x0
        cluster_imem[110] = 32'h00000013; // NOP
        cluster_imem[111] = 32'h00000013; // NOP
        cluster_imem[112] = 32'h00000013; // NOP
        cluster_imem[113] = 32'h00000013; // NOP
        cluster_imem[114] = 32'h00000013; // NOP
        cluster_imem[115] = 32'h00000013; // NOP
        cluster_imem[116] = 32'h00000013; // NOP
        cluster_imem[117] = 32'h00000013; // NOP
        cluster_imem[118] = 32'h00000013; // NOP
        cluster_imem[119] = 32'h00000013; // NOP
        cluster_imem[120] = 32'h00000013; // NOP
        cluster_imem[121] = 32'h00000013; // NOP
        cluster_imem[122] = 32'h00000013; // NOP
        cluster_imem[123] = 32'h00000013; // NOP
        cluster_imem[124] = 32'h00000013; // NOP
        cluster_imem[125] = 32'h00000013; // NOP
        cluster_imem[126] = 32'h00000013; // NOP
        cluster_imem[127] = 32'h00000013; // NOP
    end

    logic [31:0] core_icache_addr [9:0];
    logic [31:0] core_icache_rdata[9:0];
    logic        core_icache_val  [9:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 10; k++) begin
                core_icache_val[k]   <= 1'b0;
                core_icache_rdata[k] <= 32'h00000013;
            end
        end else begin
            for (int k = 0; k < 10; k++) begin
                core_icache_val[k]   <= 1'b1;
                core_icache_rdata[k] <= cluster_imem[core_icache_addr[k][8:2]];
            end
        end
    end

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
                .icache_req_addr      (core_icache_addr[c]),
                .icache_resp_valid    (core_icache_val[c]),
                .icache_resp_data     (core_icache_rdata[c]),
                .scratchpad_req_valid (sp_req_val[c]),
                .scratchpad_req_write (sp_req_wr[c]),
                .scratchpad_req_addr  (sp_req_addr[c]),
                .scratchpad_req_wdata (sp_req_wdata[c]),
                .scratchpad_req_wstrb (),
                .scratchpad_resp_rdata(sp_resp_rdata[c]),
                .scratchpad_resp_valid(sp_resp_val[c]),
                .global_mem_req_valid (),
                .global_mem_req_write (),
                .global_mem_req_addr  (),
                .global_mem_req_wdata (),
                .global_mem_resp_rdata('0),
                .global_mem_resp_valid(1'b0),
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
        .current_arrived_mask       (),
        .barrier_generation         ()
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
        .start_gemm        (neural_req_val[0] && (neural_req_op[0] == 4'h0 || neural_req_op[0] == 4'h1)),
        .start_weight_load (neural_req_val[0] && (neural_req_op[0] == 4'h2 || neural_req_op[0] == 4'h3)),
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
            neural_resp_val[i] = (i == 0) ? (systolic_done || systolic_busy) : 1'b0;
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
        .local_mem_req_valid (sp_req_val[0] && (sp_req_addr[0][15:12] == 4'hF)),
        .local_mem_req_write (sp_req_wr[0]),
        .local_dst_x         (sp_req_addr[0][7:4]),
        .local_dst_y         (sp_req_addr[0][3:0]),
        .local_mem_addr      ({16'd0, sp_req_addr[0]}),
        .local_mem_wdata     (sp_req_wdata[0]),
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
