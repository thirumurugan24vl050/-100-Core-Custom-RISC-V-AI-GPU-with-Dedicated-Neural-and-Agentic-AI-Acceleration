#=============================================================================
# Synopsys Design Constraints (SDC 2.1): 100-Core Custom RISC-V AI GPU
# Baseline: Production V1 Architecture (Cadence Genus / Tempus / Innovus)
# Target Operating Period: 1.000 ns (1.0 GHz Architectural Target)
#=============================================================================

#-----------------------------------------------------------------------------
# 1. Authoritative Primary Clock Definition
#-----------------------------------------------------------------------------
# Target: 1.0 GHz (Tclk = 1.000 ns). Achieved frequency signed off by Tempus.
create_clock -name clk -period 1.000 [get_ports clk]

# Clock Uncertainty and Transition Budgets (Assumed baseline pending PD flow)
set_clock_uncertainty -setup 0.050 [get_clocks clk]
set_clock_uncertainty -hold  0.020 [get_clocks clk]
set_clock_transition 0.050 [get_clocks clk]

# Note: No input delay is applied to the primary clock port 'clk'.

#-----------------------------------------------------------------------------
# 2. Reset and Asynchronous Paths
#-----------------------------------------------------------------------------
# Asynchronous assertion, synchronous deassertion via 2-stage synchronizer
set_false_path -from [get_ports rst_n]

#-----------------------------------------------------------------------------
# 3. Host CSR Interface Constraints (Synchronous 32-bit MMIO)
#-----------------------------------------------------------------------------
set_input_delay  -clock [get_clocks clk] -max 0.250 [get_ports {host_csr_valid host_csr_write host_csr_addr[*] host_csr_wdata[*]}]
set_input_delay  -clock [get_clocks clk] -min 0.050 [get_ports {host_csr_valid host_csr_write host_csr_addr[*] host_csr_wdata[*]}]
set_output_delay -clock [get_clocks clk] -max 0.250 [get_ports {host_csr_ready host_csr_rdata[*]}]
set_output_delay -clock [get_clocks clk] -min 0.050 [get_ports {host_csr_ready host_csr_rdata[*]}]

#-----------------------------------------------------------------------------
# 4. Host DMA Interface Constraints (512-bit Streaming Bus)
#-----------------------------------------------------------------------------
set_input_delay  -clock [get_clocks clk] -max 0.300 [get_ports {host_dma_req_val host_dma_req_wr host_dma_req_addr[*] host_dma_req_wdata[*] host_dma_req_len[*]}]
set_input_delay  -clock [get_clocks clk] -min 0.050 [get_ports {host_dma_req_val host_dma_req_wr host_dma_req_addr[*] host_dma_req_wdata[*] host_dma_req_len[*]}]
set_output_delay -clock [get_clocks clk] -max 0.300 [get_ports {host_dma_req_rdy host_dma_resp_val host_dma_resp_rdata[*] host_dma_done}]
set_output_delay -clock [get_clocks clk] -min 0.050 [get_ports {host_dma_req_rdy host_dma_resp_val host_dma_resp_rdata[*] host_dma_done}]

#-----------------------------------------------------------------------------
# 5. External Memory Interface Constraints (512-bit PHY Channel)
#-----------------------------------------------------------------------------
set_input_delay  -clock [get_clocks clk] -max 0.300 [get_ports {ext_mem_rdy ext_mem_resp_val ext_mem_resp_rdata[*]}]
set_input_delay  -clock [get_clocks clk] -min 0.050 [get_ports {ext_mem_rdy ext_mem_resp_val ext_mem_resp_rdata[*]}]
set_output_delay -clock [get_clocks clk] -max 0.300 [get_ports {ext_mem_val ext_mem_wr ext_mem_addr[*] ext_mem_wdata[*]}]
set_output_delay -clock [get_clocks clk] -min 0.050 [get_ports {ext_mem_val ext_mem_wr ext_mem_addr[*] ext_mem_wdata[*]}]

#-----------------------------------------------------------------------------
# 6. Environmental Constraints (Standard Cell Drive & Load)
#-----------------------------------------------------------------------------
set_driving_cell -lib_cell INVX1 [all_inputs -no_clocks]
set_load -pin_load 0.010 [all_outputs]

#-----------------------------------------------------------------------------
# 7. Multi-Cycle Paths (Systolic Array Multipliers & Accumulators)
#-----------------------------------------------------------------------------
set_multicycle_path 2 -setup -through [get_pins -hierarchical *u_pe*/acc_q_reg*]
set_multicycle_path 1 -hold  -through [get_pins -hierarchical *u_pe*/acc_q_reg*]
