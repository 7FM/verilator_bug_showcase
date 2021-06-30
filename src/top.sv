module top #(
)(
    input  logic clk,
    input  logic rst_n,
    output logic [63:0] data_o
);
    localparam int unsigned AXI_USER_WIDTH    = 1;
    localparam int unsigned AXI_ADDRESS_WIDTH = 64;
    localparam int unsigned AXI_DATA_WIDTH    = 64;

    localparam logic[63:0] DebugLength    = 64'h1000;
    localparam logic[63:0] ROMLength      = 64'h04000;
    localparam logic[63:0] DMEMLength     = 64'h04000;

    localparam logic[63:0] DebugBase = 64'h1200_0000;
    localparam logic[63:0] ROMBase      = 64'h0000_0000;
    localparam logic[63:0] DMEMBase     = 64'h0000_4000;

    localparam NB_SLAVE = 2;
    localparam NB_MASTER = 2;
    localparam IdWidth = 4;
    localparam IdWidthSlave = IdWidth + $clog2(NB_SLAVE);

    logic                test_en;
    assign test_en = 1'b0;

    logic clk_i, rst_ni;
    assign clk_i = clk;
    assign rst_ni = rst_n;

    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH   ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH      ),
        .AXI_ID_WIDTH   ( IdWidth ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH      )
    ) slave[NB_SLAVE-1:0]();


    AXI_BUS #(
        .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH        ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH           ),
        .AXI_ID_WIDTH   ( IdWidthSlave ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH           )
    ) master[NB_MASTER-1:0]();

    assign data_o = slave[0].r_data;

    generate
        genvar i;
        for (i=0; i < NB_MASTER; i++) begin
            assign master[i].r_data = 64'hDEADBEEF_F457F00D + i;    
        end
    endgenerate

    // AXI Interconnect
    localparam NB_REGION = 1;
    axi_node_intf_wrap #(
        .NB_SLAVE           ( NB_SLAVE                   ),
        .NB_MASTER          ( NB_MASTER                  ),
        .NB_REGION          ( NB_REGION                  ),
        .AXI_ADDR_WIDTH     ( AXI_ADDRESS_WIDTH          ),
        .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH             ),
        .AXI_USER_WIDTH     ( AXI_USER_WIDTH             ),
        .AXI_ID_WIDTH       ( IdWidth                    )
        // .MASTER_SLICE_DEPTH ( 0                          ),
        // .SLAVE_SLICE_DEPTH  ( 0                          )
    ) i_axi_xbar (
        .clk          ( clk_i      ),
        .rst_n        ( rst_n ),
        .test_en_i    ( test_en    ),
        .slave        ( slave      ),
        .master       ( master     ),
        .start_addr_i ({
            DebugBase,
            ROMBase
        }),
        .end_addr_i   ({
            DebugBase    + DebugLength - 1,
            ROMBase      + ROMLength - 1
        }),
        .valid_rule_i ({(NB_REGION * NB_MASTER){1'b1}})
    );

endmodule
