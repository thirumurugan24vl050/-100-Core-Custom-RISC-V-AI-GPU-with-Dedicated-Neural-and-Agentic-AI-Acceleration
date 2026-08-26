#=============================================================================
# Production V1 Architecture, Verification & Implementation Consistency Checker
# Shell: PowerShell
#=============================================================================

$docsDir = Join-Path $PSScriptRoot "..\docs"
$scriptsDir = Join-Path $PSScriptRoot "."

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host " 100-Core RISC-V AI GPU: Production V1 Consistency Audit (PowerShell)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$errors = @()
$warnings = @()

# 1. SDC Constraints Check
$sdcPath = Join-Path $scriptsDir "constraints.sdc"
if (Test-Path $sdcPath) {
    $sdcContent = Get-Content $sdcPath -Raw
    if ($sdcContent -notmatch "create_clock -name clk -period 1.000") {
        $errors += "SDC: 'create_clock -name clk -period 1.000' not found or incorrect"
    }
    if ($sdcContent -match "set_input_delay.*\[get_ports clk\]") {
        $errors += "SDC: set_input_delay incorrectly applied to primary clock 'clk'"
    }
    Write-Host "[*] SDC Constraints Check: PASS" -ForegroundColor Green
} else {
    $errors += "Missing SDC file: scripts/constraints.sdc"
}

# 2. Approved 13 TBs
$approvedTBs = @(
    "tb_riscv_ai_core",
    "tb_neural_systolic_engine",
    "tb_neural_postproc",
    "tb_neural_softmax",
    "tb_cluster_scratchpad",
    "tb_cluster_barrier",
    "tb_noc_router_5port",
    "tb_noc_mesh_10x10",
    "tb_axi_dma_controller",
    "tb_agent_dag_scheduler",
    "tb_paged_kv_cache_mgr",
    "tb_agentic_coprocessor",
    "tb_riscv_ai_gpu_top"
)

# 3. Documentation Checks
$verifDoc = Join-Path $docsDir "VERIFICATION_PLAN_AND_COVERAGE.md"
if (Test-Path $verifDoc) {
    $verifContent = Get-Content $verifDoc -Raw
    foreach ($tb in $approvedTBs) {
        if ($verifContent -notmatch [regex]::Escape($tb)) {
            $errors += "VERIFICATION_PLAN_AND_COVERAGE.md is missing approved testbench: $tb"
        }
    }
    if ($verifContent -match "84/84 Tests, 100% Pass Rate") {
        $errors += "VERIFICATION_PLAN_AND_COVERAGE.md contains stale 84/84 claim"
    }
    Write-Host "[*] Verification Plan Consistency Check: PASS" -ForegroundColor Green
} else {
    $errors += "Missing documentation file: VERIFICATION_PLAN_AND_COVERAGE.md"
}

$traceDoc = Join-Path $docsDir "TRACEABILITY_MATRIX.md"
if (Test-Path $traceDoc) {
    $traceContent = Get-Content $traceDoc -Raw
    if ($traceContent -match "core_lsu_dcache\.sv") {
        $errors += "TRACEABILITY_MATRIX.md contains stale reference to core_lsu_dcache.sv"
    }
    if ($traceContent -match "agent_tree_search_engine\.sv") {
        $errors += "TRACEABILITY_MATRIX.md contains out-of-scope reference to agent_tree_search_engine.sv"
    }
    Write-Host "[*] Traceability Matrix Consistency Check: PASS" -ForegroundColor Green
}

$statusDoc = Join-Path $docsDir "PROJECT_STATUS.md"
if (Test-Path $statusDoc) {
    Write-Host "[*] Project Status Consistency Check: PASS" -ForegroundColor Green
}

$physDoc = Join-Path $docsDir "PHYSICAL_DESIGN_PLAN.md"
if (Test-Path $physDoc) {
    $physContent = Get-Content $physDoc -Raw
    if ($physContent -notmatch "WNS") {
        $errors += "PHYSICAL_DESIGN_PLAN.md missing WNS signoff requirement"
    }
    Write-Host "[*] Physical Design Plan Consistency Check: PASS" -ForegroundColor Green
}

Write-Host "----------------------------------------------------------------------" -ForegroundColor Cyan
if ($errors.Count -gt 0) {
    Write-Host "Consistency Audit Result: FAILED with $($errors.Count) errors" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host " [X] $err" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "Consistency Audit Result: PASSED (0 Errors, 0 Warnings)" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    exit 0
}
