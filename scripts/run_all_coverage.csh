#!/bin/tcsh
# Automate irun and imc for all testbenches
source /home/ece-server/cadance_install/cshrc

set modules = ( \
    tb_neural_softmax \
    tb_noc_router_5port \
    tb_riscv_ai_core \
    tb_paged_kv_cache_mgr \
    tb_neural_systolic_engine \
    tb_neural_activation \
    tb_ai_gpu_cluster \
    tb_agent_tree_search \
    tb_agent_dag_scheduler \
    tb_riscv_ai_gpu_top \
)

mkdir -p work
cd work

foreach tb ($modules)
    echo "========================================"
    echo "Running simulation for $tb"
    echo "========================================"
    
    # Extract DUT name from TB name (assuming tb_<dut_name>)
    set dut = `echo $tb | sed 's/^tb_//'`

    irun -sv -64bit -access +rwc -coverage all -covdut $dut -covworkdir ./cov_work -covtest $tb -covoverwrite -incdir ../rtl/include -f ../scripts/rtl_files.f ../tb/unit_tb/$tb.sv -top $tb -run -exit
    
    if ($status != 0) then
        echo "Simulation failed for $tb. Stopping."
        exit 1
    endif
    
    echo "Generating coverage report for $tb..."
    imc -execcmd "load -run cov_work/scope/$tb; report -overwrite -out coverage_reports/$tb -html; exit"
end

echo "========================================"
echo "All simulations completed successfully."
echo "HTML reports are in work/coverage_reports/"
echo "========================================"
