//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: axi_dma_controller.sv
// Description: High-Throughput Multi-Channel DMA Engine with AXI Master Interface.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module axi_dma_controller import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Host / Core DMA Programming Interface
    input  logic                   dma_start,
    input  logic [31:0]            dma_src_addr,
    input  logic [31:0]            dma_dst_addr,
    input  logic [15:0]            dma_byte_len,
    output logic                   dma_busy,
    output logic                   dma_done_irq,

    // On-Chip Memory Master Port
    output logic                   m_mem_req_valid,
    output logic                   m_mem_req_write,
    output logic [31:0]            m_mem_req_addr,
    output logic [127:0]           m_mem_req_wdata,
    input  logic                   m_mem_req_ready,

    input  logic                   m_mem_resp_valid,
    input  logic [127:0]           m_mem_resp_rdata
);

    typedef enum logic [1:0] {
        DMA_IDLE  = 2'b00,
        DMA_READ  = 2'b01,
        DMA_WRITE = 2'b10,
        DMA_DONE  = 2'b11
    } dma_state_e;

    dma_state_e state, next_state;
    logic [31:0]  cur_src, cur_dst;
    logic [15:0]  bytes_remaining;
    logic [127:0] dma_buffer;

    assign dma_busy     = (state != DMA_IDLE);
    assign dma_done_irq = (state == DMA_DONE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= DMA_IDLE;
            cur_src         <= '0;
            cur_dst         <= '0;
            bytes_remaining <= '0;
            dma_buffer      <= '0;
        end else begin
            state <= next_state;

            case (state)
                DMA_IDLE: begin
                    if (dma_start) begin
                        cur_src         <= dma_src_addr;
                        cur_dst         <= dma_dst_addr;
                        bytes_remaining <= dma_byte_len;
                    end
                end

                DMA_READ: begin
                    if (m_mem_resp_valid) begin
                        dma_buffer <= m_mem_resp_rdata;
                        cur_src    <= cur_src + 32'd16;
                    end
                end

                DMA_WRITE: begin
                    if (m_mem_req_valid && m_mem_req_ready) begin
                        cur_dst <= cur_dst + 32'd16;
                        if (bytes_remaining >= 16)
                            bytes_remaining <= bytes_remaining - 16'd16;
                        else
                            bytes_remaining <= '0;
                    end
                end

                DMA_DONE: begin
                    // 1 cycle pulse
                end
            endcase
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            DMA_IDLE: begin
                if (dma_start) next_state = DMA_READ;
            end
            DMA_READ: begin
                if (m_mem_resp_valid) next_state = DMA_WRITE;
            end
            DMA_WRITE: begin
                if (m_mem_req_valid && m_mem_req_ready) begin
                    if (bytes_remaining <= 16)
                        next_state = DMA_DONE;
                    else
                        next_state = DMA_READ;
                end
            end
            DMA_DONE: begin
                next_state = DMA_IDLE;
            end
            default: next_state = DMA_IDLE;
        endcase
    end

    // Master memory request assignments
    assign m_mem_req_valid = (state == DMA_READ) || (state == DMA_WRITE);
    assign m_mem_req_write = (state == DMA_WRITE);
    assign m_mem_req_addr  = (state == DMA_WRITE) ? cur_dst : cur_src;
    assign m_mem_req_wdata = dma_buffer;

endmodule
