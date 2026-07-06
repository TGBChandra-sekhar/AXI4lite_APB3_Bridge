`timescale 1ns/1ps

module tb_axi_apb_bridge;

    // ------------------------------------
    // Clock & Reset
    // ------------------------------------
    reg aclk;
    reg aresetn;

    always #5 aclk = ~aclk; // 100 MHz

    // ------------------------------------
    // AXI Signals
    // ------------------------------------
    reg  [31:0] awaddr;
    reg         awvalid;
    wire        awready;

    reg  [31:0] wdata;
    reg         wvalid;
    wire        wready;

    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;

    reg  [31:0] araddr;
    reg         arvalid;
    wire        arready;

    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    // ------------------------------------
    // APB Signals
    // ------------------------------------
    wire [31:0] paddr;
    wire        pwrite;
    wire        psel;
    wire        penable;
    wire [31:0] pwdata;
    reg  [31:0] prdata;
    reg         pready;

    // ------------------------------------
    // APB SLAVE MEMORY (256 x 32-bit)
    // ------------------------------------
    reg [31:0] apb_mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            apb_mem[i] = 32'hDEADBEEF; // predefined value
    end
    
    initial begin
        awaddr = 0;
        araddr = 0;
    end

    // APB READ
    always @(posedge aclk) begin
        if (psel && penable && !pwrite)
            prdata <= apb_mem[paddr[9:2]];
    end

    // APB WRITE
    always @(posedge aclk) begin
        if (psel && penable && pwrite)
            apb_mem[paddr[9:2]] <= pwdata;
    end

    // APB READY (zero wait-state slave)
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            pready <= 1'b0;
        else
            pready <= 1'b1;
    end

    // ------------------------------------
    // DUT
    // ------------------------------------
    axi_apb_bridge_top dut (
        .aclk(aclk),
        .aresetn(aresetn),

        .s_axi_awaddr(awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),

        .s_axi_wdata(wdata),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),

        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),

        .s_axi_araddr(araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),

        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready),

        .paddr(paddr),
        .pwrite(pwrite),
        .psel(psel),
        .penable(penable),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready)
    );

    // ------------------------------------
    // AXI WRITE TASK (PROTOCOL-CORRECT)
    // ------------------------------------
    task axi_write(input [31:0] addr, input [31:0] data);
    begin
        @(posedge aclk);
        awaddr  <= addr;
        wdata   <= data;
        awvalid <= 1;
        wvalid  <= 1;

        wait (awready && wready);
        @(posedge aclk);
        awvalid <= 0;
        wvalid  <= 0;

        bready <= 1;
        wait (bvalid);
        @(posedge aclk);
        bready <= 0;
    end
    endtask

    // ------------------------------------
    // AXI READ TASK (PROTOCOL-CORRECT)
    // ------------------------------------
    task axi_read(input [31:0] addr, output [31:0] data);
    begin
        @(posedge aclk);
        araddr  <= addr;
        arvalid <= 1;

        wait (arready);
        @(posedge aclk);
        arvalid <= 0;

        rready <= 1;
        wait (rvalid && rready);
        //s@(posedge aclk);
        data = rdata;
        @(posedge aclk);
        rready <= 0;
    end
    endtask

    // ------------------------------------
    // TEST SEQUENCE
    // ------------------------------------
    reg [31:0] read_data;

    initial begin
        // Init
        aclk     = 0;
        aresetn = 0;
        awvalid = 0;
        wvalid  = 0;
        arvalid = 0;
        bready  = 0;
        rready  = 0;
        prdata  = 0;

        #20;
        aresetn = 1;

        // --------------------------------
        // WRITE known value
        // --------------------------------
        $display("WRITE: Addr=0x00000010 Data=0x12345678");
        axi_write(32'h00000010, 32'h12345678);

        // --------------------------------
        // READ back same address
        // --------------------------------
        axi_read(32'h00000010, read_data);
        $display("READ : Addr=0x00000010 Data=0x%08X", read_data);

        // --------------------------------
        // CHECK
        // --------------------------------
        if (read_data == 32'h12345678)
            $display(" TEST PASSED: Read data is correct");
        else
            $display(" TEST FAILED: Data mismatch");

        #50;
        $finish;
    end

endmodule
