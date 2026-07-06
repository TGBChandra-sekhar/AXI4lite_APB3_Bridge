`timescale 1ns/1ps

module axi_apb_bridge_top (
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite
    //write address channel
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    //write data channel
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    //write resp. channel
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    //read addr. channel
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    // read data channel
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // APB
    output wire [31:0] paddr,
    output wire        pwrite,
    output wire        psel,
    output wire        penable,
    output wire [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready
);

    // Pipeline signals
    wire s0_valid, s0_write;
    wire [31:0] s0_addr, s0_wdata;

    wire s1_valid, s1_write;
    wire [31:0] s1_addr, s1_wdata;

    wire s2_valid, s2_write;
    wire [31:0] s2_addr, s2_wdata;
    
    wire stage3_busy;


    // Global pipeline busy
    wire pipeline_busy = stage3_busy;



    // STAGE 0 
    axi_stage0_capture u_s0 (
        .aclk(aclk),
        .aresetn(aresetn),
        .busy(pipeline_busy),

        .awaddr(s_axi_awaddr),
        .awvalid(s_axi_awvalid),
        .awready(s_axi_awready),

        .wdata(s_axi_wdata),
        .wvalid(s_axi_wvalid),
        .wready(s_axi_wready),

        .araddr(s_axi_araddr),
        .arvalid(s_axi_arvalid),
        .arready(s_axi_arready),

        .out_valid(s0_valid),
        .out_write(s0_write),
        .out_addr(s0_addr),
        .out_wdata(s0_wdata)
    );

    // STAGE 1 
    axi_stage1_reg u_s1 (
        .aclk(aclk),
        .aresetn(aresetn),
        .in_valid(s0_valid),
        .in_write(s0_write),
        .in_addr(s0_addr),
        .in_wdata(s0_wdata),
        .out_valid(s1_valid),
        .out_write(s1_write),
        .out_addr(s1_addr),
        .out_wdata(s1_wdata)
    );

    // STAGE 2 
    apb_stage2_setup u_s2 (
        .aclk(aclk),
        .aresetn(aresetn),
        .in_valid(s1_valid),
        .in_write(s1_write),
        .in_addr(s1_addr),
        .in_wdata(s1_wdata),
        .out_valid(s2_valid),
        .out_write(s2_write),
        .out_addr(s2_addr),
        .out_wdata(s2_wdata)
    );

    // STAGE 3 
    apb_stage3_enable u_s3 (
        .aclk(aclk),
        .aresetn(aresetn),
        .in_valid(s2_valid),
        .in_write(s2_write),
        .in_addr(s2_addr),
        .in_wdata(s2_wdata),

        .paddr(paddr),
        .pwrite(pwrite),
        .psel(psel),
        .penable(penable),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),

        .bvalid(s_axi_bvalid),
        .bresp(s_axi_bresp),
        .bready(s_axi_bready),

        .rvalid(s_axi_rvalid),
        .rresp(s_axi_rresp),
        .rdata(s_axi_rdata),
        .rready(s_axi_rready),
        .stage3_busy(stage3_busy)
    );

endmodule
