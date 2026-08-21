//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: tb_noc_router_5port.sv
// Description: Self-Checking Testbench for 5-Port Virtual-Channel NoC Router.
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module tb_noc_router_5port;
    import riscv_ai_gpu_pkg::*;

    logic clk;
    logic rst_n;

    logic [3:0] router_x;
    logic [3:0] router_y;

    logic       in_valid [4:0];
    noc_flit_t  in_flit  [4:0];
    logic       in_ready [4:0];

    logic       out_valid [4:0];
    noc_flit_t  out_flit  [4:0];
    logic       out_ready [4:0];

    int test_pass_count = 0;
    int test_fail_count = 0;

    // Clock
    initial begin
        clk = 0;
        forever #0.5 clk = ~clk;
    end

    // Instantiate DUT (Node at X=2, Y=2)
    noc_router_5port dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .router_x  (router_x),
        .router_y  (router_y),
        .in_valid  (in_valid),
        .in_flit   (in_flit),
        .in_ready  (in_ready),
        .out_valid (out_valid),
        .out_flit  (out_flit),
        .out_ready (out_ready)
    );

    initial begin
        $display("=========================================================");
        $display(" [TESTBENCH] START: tb_noc_router_5port");
        $display("=========================================================");

        rst_n    = 0;
        router_x = 4'd2;
        router_y = 4'd2;

        for (int p = 0; p < 5; p++) begin
            in_valid[p]  = 0;
            in_flit[p]   = '0;
            out_ready[p] = 1;
        end

        #2 rst_n = 1;
        #2;

        // 1. Send Flit from Local (Port 0) destined for (X=5, Y=2) -> Must route EAST (Port 3)
        $display(" [INFO] Injecting flit at Local port targeting (X=5, Y=2)...");
        @(posedge clk);
        in_valid[0]             <= 1'b1;
        in_flit[0].flit_type    <= FLIT_SINGLE;
        in_flit[0].vc_id        <= VC_REQ;
        in_flit[0].src_x        <= 4'd2;
        in_flit[0].src_y        <= 4'd2;
        in_flit[0].dst_x        <= 4'd5;
        in_flit[0].dst_y        <= 4'd2;
        in_flit[0].msg_type     <= 8'h01;
        in_flit[0].payload      <= 128'hCAFE_BABE_0000_1111;

        @(posedge clk);
        in_valid[0] <= 1'b0;
        #0.1;

        // Verify flit appears at East Outbound port (Index 3)
        if (out_valid[3] && out_flit[3].payload == 128'hCAFE_BABE_0000_1111) begin
            $display(" [PASS] Test 1: XY Dimension-Order Routing successfully routed packet East (Port 3)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 1: Packet did not route to East port correctly (out_valid[3]=%b)", out_valid[3]);
            test_fail_count++;
        end
        @(posedge clk);

        // 2. Send Flit from North (Port 1) destined for (X=2, Y=2) -> Must route LOCAL (Port 0)
        $display(" [INFO] Injecting flit at North port targeting Local (X=2, Y=2)...");
        @(posedge clk);
        in_valid[1]             <= 1'b1;
        in_flit[1].flit_type    <= FLIT_SINGLE;
        in_flit[1].vc_id        <= VC_RESP;
        in_flit[1].src_x        <= 4'd2;
        in_flit[1].src_y        <= 4'd0;
        in_flit[1].dst_x        <= 4'd2;
        in_flit[1].dst_y        <= 4'd2;
        in_flit[1].msg_type     <= 8'h03;
        in_flit[1].payload      <= 128'hFEED_FACE_2222_3333;

        @(posedge clk);
        in_valid[1] <= 1'b0;
        #0.1;

        // Verify flit appears at Local Outbound port (Index 0)
        if (out_valid[0] && out_flit[0].payload == 128'hFEED_FACE_2222_3333) begin
            $display(" [PASS] Test 2: Ingress Packet correctly terminated at Local destination port (Port 0)");
            test_pass_count++;
        end else begin
            $display(" [FAIL] Test 2: Local delivery failed (out_valid[0]=%b)", out_valid[0]);
            test_fail_count++;
        end
        @(posedge clk);

        $display("=========================================================");
        $display(" [TESTBENCH SUMMARY] tb_noc_router_5port: %0d PASSED, %0d FAILED", test_pass_count, test_fail_count);
        $display("=========================================================");

        if (test_fail_count == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");

        $finish;
    end

endmodule
