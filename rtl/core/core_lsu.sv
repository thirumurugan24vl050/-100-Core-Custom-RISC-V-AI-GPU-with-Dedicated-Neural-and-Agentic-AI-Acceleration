//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: core_lsu.sv
// Description: Multi-Warp Load/Store Unit (LSU):
//              - 64-bit Physical Address Resolution (SPAD vs Global SRAM)
//              - 32-bit Scalar Interface & 8-Beat 256-bit Vector SIMD Decomposition
//              - AI_FENCE memory ordering synchronization
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module core_lsu import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Core Instruction Execution Interface
    input  logic                   req_valid,
    output logic                   req_ready,
    input  logic [1:0]             warp_id,
    input  logic                   is_load,
    input  logic                   is_store,
    input  logic                   is_vector_mem,
    input  logic                   is_fence,
    input  logic [1:0]             fence_scope,
    input  logic [2:0]             funct3,
    input  logic [63:0]            addr,
    input  logic [31:0]            wdata_scalar,
    input  logic [VLEN-1:0]        wdata_vector,
    input  logic [4:0]             rd_addr,

    // Core Writeback Egress
    output logic                   resp_valid,
    output logic [1:0]             resp_warp_id,
    output logic [4:0]             resp_rd_addr,
    output logic [XLEN-1:0]        resp_rdata_scalar,
    output logic [VLEN-1:0]        resp_rdata_vector,
    output logic                   resp_is_vector,
    output logic                   busy,

    // Cluster Shared Scratchpad SRAM Interface (32-bit wide)
    output logic                   spad_req_valid,
    output logic                   spad_req_write,
    output logic [15:0]            spad_req_addr,
    output logic [31:0]            spad_req_wdata,
    output logic [3:0]             spad_req_wstrb,
    input  logic [31:0]            spad_resp_rdata,
    input  logic                   spad_resp_valid,

    // Global Memory Interface (via Cluster Gateway)
    output logic                   global_req_valid,
    output logic                   global_req_write,
    output logic [63:0]            global_req_addr,
    output logic [31:0]            global_req_wdata,
    input  logic [31:0]            global_resp_rdata,
    input  logic                   global_resp_valid
);

    // LSU FSM for Scalar, 8-Beat Vector Decomposition, and Fence Retirement
    typedef enum logic [2:0] {
        STATE_IDLE       = 3'b000,
        STATE_SCALAR_REQ = 3'b001,
        STATE_SCALAR_WAIT= 3'b010,
        STATE_VEC_BEATS  = 3'b011,
        STATE_VEC_WAIT   = 3'b100,
        STATE_FENCE_DRAIN= 3'b101
    } lsu_state_e;

    lsu_state_e state;

    // Address Classification: Addresses < 64KB (0x0000_0000..0x0000_FFFF) target Cluster SPAD
    logic is_spad_addr;
    assign is_spad_addr = (addr < 64'h0000_0000_0001_0000);

    // Vector beat counter (8 beats of 32-bit = 256 bits)
    logic [2:0]  vec_beat_cnt;
    logic [1:0]  latched_warp_id;
    logic [4:0]  latched_rd_addr;
    logic [2:0]  latched_funct3;
    logic [63:0] latched_base_addr;
    logic        latched_is_load;
    logic        latched_is_store;
    logic        latched_is_vector;
    logic [VLEN-1:0] latched_wdata_vec;
    logic [VLEN-1:0] assembled_rdata_vec;

    assign busy      = (state != STATE_IDLE);
    assign req_ready = (state == STATE_IDLE);

    // Scratchpad & Global Request Multiplexing
    always_comb begin
        spad_req_valid   = 1'b0;
        spad_req_write   = 1'b0;
        spad_req_addr    = 16'd0;
        spad_req_wdata   = 32'd0;
        spad_req_wstrb   = 4'b1111;

        global_req_valid = 1'b0;
        global_req_write = 1'b0;
        global_req_addr  = 64'd0;
        global_req_wdata = 32'd0;

        if (state == STATE_SCALAR_REQ) begin
            if (latched_base_addr < 64'h0001_0000) begin
                spad_req_valid = 1'b1;
                spad_req_write = latched_is_store;
                spad_req_addr  = latched_base_addr[15:0];
                spad_req_wdata = wdata_scalar;
                // Byte strobe generation based on funct3 (SB=000, SH=001, SW=010)
                case (latched_funct3[1:0])
                    2'b00: spad_req_wstrb = 4'b0001 << latched_base_addr[1:0];
                    2'b01: spad_req_wstrb = 4'b0011 << {latched_base_addr[1], 1'b0};
                    default: spad_req_wstrb = 4'b1111;
                endcase
            end else begin
                global_req_valid = 1'b1;
                global_req_write = latched_is_store;
                global_req_addr  = latched_base_addr;
                global_req_wdata = wdata_scalar;
            end
        end else if (state == STATE_VEC_BEATS) begin
            logic [63:0] beat_addr;
            beat_addr = latched_base_addr + {59'd0, vec_beat_cnt, 2'b00};
            if (beat_addr < 64'h0001_0000) begin
                spad_req_valid = 1'b1;
                spad_req_write = latched_is_store;
                spad_req_addr  = beat_addr[15:0];
                spad_req_wdata = latched_wdata_vec[vec_beat_cnt*32 +: 32];
                spad_req_wstrb = 4'b1111;
            end else begin
                global_req_valid = 1'b1;
                global_req_write = latched_is_store;
                global_req_addr  = beat_addr;
                global_req_wdata = latched_wdata_vec[vec_beat_cnt*32 +: 32];
            end
        end
    end

    // Sequential State Machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= STATE_IDLE;
            vec_beat_cnt        <= '0;
            latched_warp_id     <= '0;
            latched_rd_addr     <= '0;
            latched_funct3      <= '0;
            latched_base_addr   <= '0;
            latched_is_load     <= 1'b0;
            latched_is_store    <= 1'b0;
            latched_is_vector   <= 1'b0;
            latched_wdata_vec   <= '0;
            assembled_rdata_vec <= '0;
            resp_valid          <= 1'b0;
            resp_warp_id        <= '0;
            resp_rd_addr        <= '0;
            resp_rdata_scalar   <= '0;
            resp_rdata_vector   <= '0;
            resp_is_vector      <= 1'b0;
        end else begin
            resp_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (req_valid) begin
                        latched_warp_id   <= warp_id;
                        latched_rd_addr   <= rd_addr;
                        latched_funct3    <= funct3;
                        latched_base_addr <= addr;
                        latched_is_load   <= is_load;
                        latched_is_store  <= is_store;
                        latched_is_vector <= is_vector_mem;
                        latched_wdata_vec <= wdata_vector;

                        if (is_fence) begin
                            state <= STATE_FENCE_DRAIN;
                        end else if (is_vector_mem) begin
                            vec_beat_cnt <= 3'd0;
                            state        <= STATE_VEC_BEATS;
                        end else if (is_load || is_store) begin
                            state        <= STATE_SCALAR_REQ;
                        end
                    end
                end

                STATE_SCALAR_REQ: begin
                    state <= STATE_SCALAR_WAIT;
                end

                STATE_SCALAR_WAIT: begin
                    if (spad_resp_valid || global_resp_valid) begin
                        logic [31:0] raw_data;
                        raw_data = (latched_base_addr < 64'h0001_0000) ? spad_resp_rdata : global_resp_rdata;

                        if (latched_is_load) begin
                            resp_valid   <= 1'b1;
                            resp_warp_id <= latched_warp_id;
                            resp_rd_addr <= latched_rd_addr;
                            resp_is_vector <= 1'b0;
                            // Format scalar load data (LB, LH, LW, LBU, LHU)
                            case (latched_funct3)
                                3'b000: resp_rdata_scalar <= {{24{raw_data[7]}}, raw_data[7:0]};   // LB
                                3'b001: resp_rdata_scalar <= {{16{raw_data[15]}}, raw_data[15:0]}; // LH
                                3'b010: resp_rdata_scalar <= raw_data;                              // LW
                                3'b100: resp_rdata_scalar <= {24'd0, raw_data[7:0]};               // LBU
                                3'b101: resp_rdata_scalar <= {16'd0, raw_data[15:0]};              // LHU
                                default: resp_rdata_scalar <= raw_data;
                            endcase
                        end
                        state <= STATE_IDLE;
                    end
                end

                STATE_VEC_BEATS: begin
                    state <= STATE_VEC_WAIT;
                end

                STATE_VEC_WAIT: begin
                    if (spad_resp_valid || global_resp_valid) begin
                        logic [31:0] raw_data;
                        raw_data = (latched_base_addr < 64'h0001_0000) ? spad_resp_rdata : global_resp_rdata;
                        assembled_rdata_vec[vec_beat_cnt*32 +: 32] <= raw_data;

                        if (vec_beat_cnt == 3'd7) begin
                            if (latched_is_load) begin
                                resp_valid         <= 1'b1;
                                resp_warp_id       <= latched_warp_id;
                                resp_rd_addr       <= latched_rd_addr;
                                resp_is_vector     <= 1'b1;
                                resp_rdata_vector  <= {raw_data, assembled_rdata_vec[223:0]};
                            end
                            state <= STATE_IDLE;
                        end else begin
                            vec_beat_cnt <= vec_beat_cnt + 1'b1;
                            state        <= STATE_VEC_BEATS;
                        end
                    end
                end

                STATE_FENCE_DRAIN: begin
                    // Drain and complete fence synchronization
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
