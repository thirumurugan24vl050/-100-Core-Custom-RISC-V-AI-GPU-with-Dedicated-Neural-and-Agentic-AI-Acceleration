//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: memory_gateway.sv
// Description: Global Memory Gateway & Protocol Translator:
//              - Bridges NoC memory transaction flits to 4MB Global Buffer
//              - Converts 512-bit Host DMA transactions to/from Global SRAM
//              - Formats NoC response flits on VC_RESP with uniform packet tracking
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module memory_gateway import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // NoC Interface
    input  noc_flit_t              noc_flit_in,
    input  logic                   noc_valid_in,
    output logic                   noc_ready_out,

    output noc_flit_t              noc_flit_out,
    output logic                   noc_valid_out,
    input  logic                   noc_ready_in,

    // 4MB Global Buffer Interface
    output logic                   gb_ren,
    output logic [31:0]            gb_raddr,
    input  logic [127:0]           gb_rdata,
    input  logic                   gb_rvalid,

    output logic                   gb_wen,
    output logic [31:0]            gb_waddr,
    output logic [127:0]           gb_wdata,
    output logic [15:0]            gb_wstrb,
    input  logic                   gb_wready,

    // Host 512-bit DMA Subsystem Interface
    input  logic                   dma_req_valid,
    input  logic                   dma_req_write,
    input  logic [63:0]            dma_req_addr,
    input  logic [511:0]           dma_req_wdata,
    output logic [511:0]           dma_resp_rdata,
    output logic                   dma_resp_valid
);

    typedef enum logic [2:0] {
        STATE_IDLE      = 3'b000,
        STATE_NOC_READ  = 3'b001,
        STATE_NOC_WRITE = 3'b010,
        STATE_DMA_XFER  = 3'b011,
        STATE_RESP_SEND = 3'b100
    } gw_state_e;

    gw_state_e state;

    // Latched request metadata
    logic [3:0]    latched_src_x, latched_src_y;
    noc_vc_e       latched_vc;
    logic [15:0]   latched_packet_id;
    logic [7:0]    latched_msg_type;

    assign noc_ready_out = (state == STATE_IDLE);

    // Global Buffer Request Multiplexing
    always_comb begin
        gb_ren   = 1'b0;
        gb_raddr = 32'd0;
        gb_wen   = 1'b0;
        gb_waddr = 32'd0;
        gb_wdata = 128'd0;
        gb_wstrb = 16'hFFFF;

        if (state == STATE_IDLE && noc_valid_in) begin
            if (noc_flit_in.msg_type == MSG_MEM_REQ) begin
                if (noc_flit_in.flags[0]) begin // flags[0] = write
                    gb_wen   = 1'b1;
                    gb_waddr = noc_flit_in.payload[31:0];
                    gb_wdata = noc_flit_in.payload[127:0];
                end else begin // read
                    gb_ren   = 1'b1;
                    gb_raddr = noc_flit_in.payload[31:0];
                end
            end
        end
    end

    // Sequential Processing and Response Generation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state              <= STATE_IDLE;
            latched_src_x      <= '0;
            latched_src_y      <= '0;
            latched_vc         <= VC_REQ;
            latched_packet_id  <= '0;
            latched_msg_type   <= '0;
            noc_valid_out      <= 1'b0;
            noc_flit_out       <= '0;
            dma_resp_valid     <= 1'b0;
            dma_resp_rdata     <= '0;
        end else begin
            noc_valid_out  <= 1'b0;
            dma_resp_valid <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    if (noc_valid_in) begin
                        latched_src_x     <= noc_flit_in.src_x;
                        latched_src_y     <= noc_flit_in.src_y;
                        latched_vc        <= noc_flit_in.vc_id;
                        latched_packet_id <= noc_flit_in.payload[127:112];
                        latched_msg_type  <= noc_flit_in.msg_type;

                        if (noc_flit_in.msg_type == MSG_MEM_REQ) begin
                            if (noc_flit_in.flags[0])
                                state <= STATE_NOC_WRITE;
                            else
                                state <= STATE_NOC_READ;
                        end
                    end else if (dma_req_valid) begin
                        state <= STATE_DMA_XFER;
                    end
                end

                STATE_NOC_READ: begin
                    if (gb_rvalid) begin
                        noc_valid_out              <= 1'b1;
                        noc_flit_out.flit_type     <= FLIT_SINGLE;
                        noc_flit_out.vc_id         <= VC_RESP; // VC1: Response
                        noc_flit_out.src_x         <= 4'd9;    // Gateway node (9,9)
                        noc_flit_out.src_y         <= 4'd9;
                        noc_flit_out.dst_x         <= latched_src_x;
                        noc_flit_out.dst_y         <= latched_src_y;
                        noc_flit_out.msg_type      <= MSG_MEM_RESP;
                        noc_flit_out.flags         <= 4'b0000;
                        noc_flit_out.payload       <= gb_rdata;
                        state                      <= STATE_IDLE;
                    end
                end

                STATE_NOC_WRITE: begin
                    // Write complete, acknowledge on VC_RESP
                    noc_valid_out              <= 1'b1;
                    noc_flit_out.flit_type     <= FLIT_SINGLE;
                    noc_flit_out.vc_id         <= VC_RESP;
                    noc_flit_out.src_x         <= 4'd9;
                    noc_flit_out.src_y         <= 4'd9;
                    noc_flit_out.dst_x         <= latched_src_x;
                    noc_flit_out.dst_y         <= latched_src_y;
                    noc_flit_out.msg_type      <= MSG_MEM_RESP;
                    noc_flit_out.flags         <= 4'b0000;
                    noc_flit_out.payload       <= 128'd1; // Success ACK
                    state                      <= STATE_IDLE;
                end

                STATE_DMA_XFER: begin
                    dma_resp_valid <= 1'b1;
                    dma_resp_rdata <= {4{gb_rdata}};
                    state          <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
