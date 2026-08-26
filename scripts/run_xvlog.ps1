$XVLOG = "C:\Xilinx24VL044\Vivado\2018.3\bin\xvlog.bat"
$args = "-sv -i ./rtl/include ./rtl/include/riscv_ai_gpu_pkg.sv ./rtl/core/core_fetch_unit.sv ./rtl/core/core_decode_unit.sv ./rtl/core/core_regfile.sv ./rtl/core/core_scalar_alu.sv ./rtl/core/core_vector_unit.sv ./rtl/core/core_warp_scheduler.sv ./rtl/core/core_reconvergence_stack.sv ./rtl/core/core_lsu.sv ./rtl/core/riscv_ai_core.sv"

$p = Start-Process -FilePath $XVLOG -ArgumentList $args -RedirectStandardOutput "comp_out.txt" -RedirectStandardError "comp_err.txt" -NoNewWindow -Wait -PassThru
Get-Content "comp_out.txt"
Get-Content "comp_err.txt"
Write-Host "EXIT_CODE: $($p.ExitCode)"
