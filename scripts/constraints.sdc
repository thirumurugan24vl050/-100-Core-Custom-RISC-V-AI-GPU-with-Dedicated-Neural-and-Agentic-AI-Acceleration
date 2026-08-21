#=============================================================================
# SDC Timing Constraints: 100-Core Custom RISC-V AI GPU
# Target Frequency: 1.0 GHz (Period: 1.0 ns)
# Standard: Synopsys Design Constraints (SDC 2.1)
#=============================================================================

# 1. Main System Clock Definition
create_clock -name clk -period 1.000 [get_ports clk]
set_clock_uncertainty -setup 0.050 [get_clocks clk]
set_clock_uncertainty -hold  0.020 [get_clocks clk]
set_clock_transition 0.050 [get_clocks clk]

# 2. Reset and Control Signal Timing
set_false_path -from [get_ports rst_n]

# 3. Host CSR Interface Constraints (Operating across synchronous boundary)
set_input_delay  -clock clk -max 0.250 [get_ports {host_csr_valid host_csr_write host_csr_addr[*] host_csr_wdata[*]}]
set_input_delay  -clock clk -min 0.050 [get_ports {host_csr_valid host_csr_write host_csr_addr[*] host_csr_wdata[*]}]
set_output_delay -clock clk -max 0.250 [get_ports {host_csr_ready host_csr_rdata[*]}]
set_output_delay -clock clk -min 0.050 [get_ports {host_csr_ready host_csr_rdata[*]}]

# 4. Host DMA Interface Constraints (512-bit streaming bus)
set_input_delay  -clock clk -max 0.300 [get_ports {host_dma_req_val host_dma_req_wr host_dma_req_addr[*] host_dma_req_wdata[*] host_dma_req_len[*]}]
set_input_delay  -clock clk -min 0.050 [get_ports {host_dma_req_val host_dma_req_wr host_dma_req_addr[*] host_dma_req_wdata[*] host_dma_req_len[*]}]
set_output_delay -clock clk -max 0.300 [get_ports {host_dma_req_rdy host_dma_resp_val host_dma_resp_rdata[*] host_dma_done}]
set_output_delay -clock clk -min 0.050 [get_ports {host_dma_req_rdy host_dma_resp_val host_dma_resp_rdata[*] host_dma_done}]

# 5. External Memory Interface Constraints
set_input_delay  -clock clk -max 0.300 [get_ports {ext_mem_rdy ext_mem_resp_val ext_mem_resp_rdata[*]}]
set_input_delay  -clock clk -min 0.050 [get_ports {ext_mem_rdy ext_mem_resp_val ext_mem_resp_rdata[*]}]
set_output_delay -clock clk -max 0.300 [get_ports {ext_mem_val ext_mem_wr ext_mem_addr[*] ext_mem_wdata[*]}]
set_output_delay -clock clk -min 0.050 [get_ports {ext_mem_val ext_mem_wr ext_mem_addr[*] ext_mem_wdata[*]}]

# 6. Environmental Constraints (Library Drive/Load)
set_driving_cell -lib_cell INVX1 [all_inputs -no_clocks]
set_load -pin_load 0.010 [all_outputs]

# 7. Multi-Cycle Paths (Systolic Array Multipliers / Softmax Taylor Division)
set_multicycle_path 2 -setup -through [get_pins -hierarchical *u_pe*/acc_q_reg*]
set_multicycle_path 1 -hold  -through [get_pins -hierarchical *u_pe*/acc_q_reg*]
