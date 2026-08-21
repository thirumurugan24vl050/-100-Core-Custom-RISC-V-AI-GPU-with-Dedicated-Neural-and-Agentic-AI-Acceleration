//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: paged_kv_cache_mgr.sv
// Description: Paged KV-Cache Page Table Walker & Physical Memory Allocator.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module paged_kv_cache_mgr import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Command Request Interface (from Core / Coprocessor)
    input  logic                   kv_req_valid,
    input  logic [1:0]             kv_req_op, // 00: Lookup, 01: Alloc, 10: Free, 11: Share/IncRef
    input  logic [5:0]             kv_context_id, // 64 Active Context Threads
    input  logic [9:0]             kv_virtual_page, // Virtual page number
    output logic                   kv_resp_valid,
    output logic [KV_PAGE_ID_WIDTH-1:0] kv_resp_physical_page,
    output logic                   kv_resp_hit,
    output logic                   kv_resp_error, // Out of memory error

    // Memory Allocation Status
    output logic [10:0]            free_page_count,
    output logic [10:0]            allocated_page_count
);

    // 1024 Physical Pages Allocation Bitmap
    logic [KV_MAX_PAGES-1:0] page_allocation_bitmap;

    // Page Table: 64 Contexts x 64 Virtual Pages per context
    paged_kv_entry_t page_table [63:0][63:0];

    // Priority Encoder to Find First Free Physical Page
    logic [KV_PAGE_ID_WIDTH-1:0] first_free_page;
    logic                        free_page_found;

    always_comb begin
        first_free_page = '0;
        free_page_found = 1'b0;
        for (int p = 0; p < KV_MAX_PAGES; p++) begin
            if (!page_allocation_bitmap[p] && !free_page_found) begin
                first_free_page = 10'(p);
                free_page_found = 1'b1;
            end
        end
    end

    // Compute free and allocated count
    logic [10:0] free_count;
    always_comb begin
        free_count = '0;
        for (int p = 0; p < KV_MAX_PAGES; p++) begin
            if (!page_allocation_bitmap[p])
                free_count = free_count + 11'd1;
        end
    end
    assign free_page_count      = free_count;
    assign allocated_page_count = 11'd1024 - free_count;

    // Handle KV Operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            page_allocation_bitmap <= '0;
            kv_resp_valid          <= 1'b0;
            kv_resp_physical_page  <= '0;
            kv_resp_hit            <= 1'b0;
            kv_resp_error          <= 1'b0;

            for (int c = 0; c < 64; c++) begin
                for (int v = 0; v < 64; v++) begin
                    page_table[c][v].valid           <= 1'b0;
                    page_table[c][v].dirty           <= 1'b0;
                    page_table[c][v].physical_page   <= '0;
                    page_table[c][v].reference_count <= 2'd0;
                    page_table[c][v].token_count     <= 16'd0;
                end
            end
        end else begin
            kv_resp_valid <= kv_req_valid;
            kv_resp_error <= 1'b0;

            if (kv_req_valid) begin
                logic [5:0] v_page_idx;
                v_page_idx = kv_virtual_page[5:0];

                case (kv_req_op)
                    // 1. Page Table Lookup
                    2'b00: begin
                        if (page_table[kv_context_id][v_page_idx].valid) begin
                            kv_resp_physical_page <= page_table[kv_context_id][v_page_idx].physical_page;
                            kv_resp_hit           <= 1'b1;
                        end else begin
                            kv_resp_physical_page <= '0;
                            kv_resp_hit           <= 1'b0;
                        end
                    end

                    // 2. Allocate New Page
                    2'b01: begin
                        if (free_page_found) begin
                            page_allocation_bitmap[first_free_page] <= 1'b1;
                            page_table[kv_context_id][v_page_idx].valid           <= 1'b1;
                            page_table[kv_context_id][v_page_idx].physical_page   <= first_free_page;
                            page_table[kv_context_id][v_page_idx].reference_count <= 2'd1;
                            kv_resp_physical_page <= first_free_page;
                            kv_resp_hit           <= 1'b1;
                        end else begin
                            kv_resp_error <= 1'b1; // Out of memory
                            kv_resp_hit   <= 1'b0;
                        end
                    end

                    // 3. Free Page
                    2'b10: begin
                        if (page_table[kv_context_id][v_page_idx].valid) begin
                            logic [KV_PAGE_ID_WIDTH-1:0] p_page;
                            p_page = page_table[kv_context_id][v_page_idx].physical_page;
                            
                            if (page_table[kv_context_id][v_page_idx].reference_count <= 2'd1) begin
                                page_allocation_bitmap[p_page] <= 1'b0; // Free physical page
                                page_table[kv_context_id][v_page_idx].valid <= 1'b0;
                            end else begin
                                page_table[kv_context_id][v_page_idx].reference_count <= 
                                    page_table[kv_context_id][v_page_idx].reference_count - 2'd1;
                            end
                            kv_resp_hit <= 1'b1;
                        end
                    end

                    // 4. Share / Increment Reference (Zero-Copy Prefix Cache)
                    2'b11: begin
                        if (page_table[kv_context_id][v_page_idx].valid) begin
                            page_table[kv_context_id][v_page_idx].reference_count <= 
                                page_table[kv_context_id][v_page_idx].reference_count + 2'd1;
                            kv_resp_physical_page <= page_table[kv_context_id][v_page_idx].physical_page;
                            kv_resp_hit           <= 1'b1;
                        end
                    end
                endcase
            end
        end
    end

endmodule
