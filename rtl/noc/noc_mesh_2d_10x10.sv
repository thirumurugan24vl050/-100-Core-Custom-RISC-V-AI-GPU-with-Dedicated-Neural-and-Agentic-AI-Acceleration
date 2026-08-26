//=============================================================================
// Project: 100-Core Custom RISC-V AI GPU with Neural & Agentic Acceleration
// File: noc_mesh_2d_10x10.sv
// Description: 10x10 2D-Mesh Interconnect Fabric:
//              - 100 5-Port Virtual-Channel Routers
//              - Dimension-Order Routing (XY DOR)
//              - Dedicated Credit-Ready Handshake Flow Control
// Standard: IEEE 1800-2017 SystemVerilog
//=============================================================================

`timescale 1ns / 1ps

module noc_mesh_2d_10x10 import riscv_ai_gpu_pkg::*; (
    input  logic                   clk,
    input  logic                   rst_n,

    // Local Port Interfaces for all 100 Nodes [X][Y]
    input  noc_flit_t              node_flit_in   [NOC_MESH_X-1:0][NOC_MESH_Y-1:0],
    input  logic                   node_valid_in  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0],
    output logic                   node_ready_out [NOC_MESH_X-1:0][NOC_MESH_Y-1:0],

    output noc_flit_t              node_flit_out  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0],
    output logic                   node_valid_out [NOC_MESH_X-1:0][NOC_MESH_Y-1:0],
    input  logic                   node_ready_in  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0]
);

    // Internal Link Wires between Routers
    // [X][Y][Direction]: 0=Local, 1=North, 2=South, 3=East, 4=West
    noc_flit_t flit_link   [NOC_MESH_X-1:0][NOC_MESH_Y-1:0][4:0];
    logic      valid_link  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0][4:0];
    logic      ready_link  [NOC_MESH_X-1:0][NOC_MESH_Y-1:0][4:0];

    // Generate 10x10 Router Grid
    genvar x, y;
    generate
        for (x = 0; x < NOC_MESH_X; x++) begin : gen_mesh_x
            for (y = 0; y < NOC_MESH_Y; y++) begin : gen_mesh_y

                // Wire mapping for 5 ports:
                noc_flit_t r_flit_in   [4:0];
                logic      r_valid_in  [4:0];
                logic      r_ready_out [4:0];

                noc_flit_t r_flit_out  [4:0];
                logic      r_valid_out [4:0];
                logic      r_ready_in  [4:0];

                // 1. Port 0: Local Node Connection
                assign r_flit_in[0]               = node_flit_in[x][y];
                assign r_valid_in[0]              = node_valid_in[x][y];
                assign node_ready_out[x][y]       = r_ready_out[0];

                assign node_flit_out[x][y]        = r_flit_out[0];
                assign node_valid_out[x][y]       = r_valid_out[0];
                assign r_ready_in[0]              = node_ready_in[x][y];

                // 2. Port 1: North Link (Y+1)
                if (y < NOC_MESH_Y-1) begin : gen_north
                    assign r_flit_in[1]    = flit_link[x][y+1][2]; // From South of North neighbor
                    assign r_valid_in[1]   = valid_link[x][y+1][2];
                    assign ready_link[x][y+1][2] = r_ready_out[1];
                end else begin : gen_north_boundary
                    assign r_flit_in[1]    = '0;
                    assign r_valid_in[1]   = 1'b0;
                end

                // 3. Port 2: South Link (Y-1)
                if (y > 0) begin : gen_south
                    assign r_flit_in[2]    = flit_link[x][y-1][1]; // From North of South neighbor
                    assign r_valid_in[2]   = valid_link[x][y-1][1];
                    assign ready_link[x][y-1][1] = r_ready_out[2];
                end else begin : gen_south_boundary
                    assign r_flit_in[2]    = '0;
                    assign r_valid_in[2]   = 1'b0;
                end

                // 4. Port 3: East Link (X+1)
                if (x < NOC_MESH_X-1) begin : gen_east
                    assign r_flit_in[3]    = flit_link[x+1][y][4]; // From West of East neighbor
                    assign r_valid_in[3]   = valid_link[x+1][y][4];
                    assign ready_link[x+1][y][4] = r_ready_out[3];
                end else begin : gen_east_boundary
                    assign r_flit_in[3]    = '0;
                    assign r_valid_in[3]   = 1'b0;
                end

                // 5. Port 4: West Link (X-1)
                if (x > 0) begin : gen_west
                    assign r_flit_in[4]    = flit_link[x-1][y][3]; // From East of West neighbor
                    assign r_valid_in[4]   = valid_link[x-1][y][3];
                    assign ready_link[x-1][y][3] = r_ready_out[4];
                end else begin : gen_west_boundary
                    assign r_flit_in[4]    = '0;
                    assign r_valid_in[4]   = 1'b0;
                end

                // Output bindings to link wires
                assign flit_link[x][y][1]   = r_flit_out[1];
                assign valid_link[x][y][1]  = r_valid_out[1];
                assign r_ready_in[1]        = (y < NOC_MESH_Y-1) ? ready_link[x][y][1] : 1'b1;

                assign flit_link[x][y][2]   = r_flit_out[2];
                assign valid_link[x][y][2]  = r_valid_out[2];
                assign r_ready_in[2]        = (y > 0) ? ready_link[x][y][2] : 1'b1;

                assign flit_link[x][y][3]   = r_flit_out[3];
                assign valid_link[x][y][3]  = r_valid_out[3];
                assign r_ready_in[3]        = (x < NOC_MESH_X-1) ? ready_link[x][y][3] : 1'b1;

                assign flit_link[x][y][4]   = r_flit_out[4];
                assign valid_link[x][y][4]  = r_valid_out[4];
                assign r_ready_in[4]        = (x > 0) ? ready_link[x][y][4] : 1'b1;

                // Instantiate 5-Port Router Instance at (x, y)
                noc_router_5port u_router (
                    .clk            (clk),
                    .rst_n          (rst_n),
                    .router_x       (4'(x)),
                    .router_y       (4'(y)),
                    .in_valid       (r_valid_in),
                    .in_flit        (r_flit_in),
                    .in_ready       (r_ready_out),
                    .out_valid      (r_valid_out),
                    .out_flit       (r_flit_out),
                    .out_ready      (r_ready_in)
                );

            end
        end
    endgenerate

endmodule
