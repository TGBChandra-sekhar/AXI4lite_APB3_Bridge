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



    // ---------------- STAGE 0 ----------------
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

    // ---------------- STAGE 1 ----------------
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

    // ---------------- STAGE 2 ----------------
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

    // ---------------- STAGE 3 ----------------
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








module apb_stage2_setup (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        in_valid,
    input  wire        in_write,
    input  wire [31:0] in_addr,
    input  wire [31:0] in_wdata,
    output reg         out_valid,
    output reg         out_write,
    output reg [31:0]  out_addr,
    output reg [31:0]  out_wdata
);
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            out_valid <= 0;
        else begin
            out_valid <= in_valid;
            if (in_valid) begin
                out_write <= in_write;
                out_addr  <= in_addr;
                out_wdata <= in_wdata;
            end
        end
    end
endmodule



module apb_stage3_enable (
    input  wire        aclk,
    input  wire        aresetn,

    // From Stage-2
    input  wire        in_valid,
    input  wire        in_write,
    input  wire [31:0] in_addr,
    input  wire [31:0] in_wdata,

    // APB
    output reg  [31:0] paddr,
    output reg         pwrite,
    output reg         psel,
    output reg         penable,
    output reg  [31:0] pwdata,
    input  wire [31:0] prdata,
    input  wire        pready,

    // AXI write response
    output reg         bvalid,
    output reg  [1:0]  bresp,
    input  wire        bready,

    // AXI read response
    output reg         rvalid,
    output reg  [1:0]  rresp,
    output reg  [31:0] rdata,
    input  wire        rready,

    output wire        stage3_busy
);

    // ------------------------------------------------
    // REQUEST LATCH
    // ------------------------------------------------
    reg        req_valid;
    reg        req_write;
    reg [31:0] req_addr;
    reg [31:0] req_wdata;
    reg [31:0] prdata_reg;

    // ------------------------------------------------
    // FSM STATES
    // ------------------------------------------------
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ENABLE = 2'b10,
        RESP   = 2'b11
    } state_t;

    state_t state;

    assign stage3_busy = req_valid;

    // ------------------------------------------------
    // MAIN FSM
    // ------------------------------------------------
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            state      <= IDLE;

            psel       <= 0;
            penable    <= 0;
            paddr      <= 0;
            pwrite     <= 0;
            pwdata     <= 0;

            req_valid  <= 0;
            req_write  <= 0;
            req_addr   <= 0;
            req_wdata  <= 0;
            prdata_reg <= 0;

            bvalid     <= 0;
            bresp      <= 2'b00;
            rvalid     <= 0;
            rresp      <= 2'b00;
            rdata      <= 0;
        end else begin

            // ----------------------------------------
            // LATCH REQUEST (ONCE)
            // ----------------------------------------
            if (in_valid && !req_valid) begin
                req_valid <= 1'b1;
                req_write <= in_write;
                req_addr  <= in_addr;
                req_wdata <= in_wdata;
            end

            // ----------------------------------------
            // AXI RESPONSE HANDSHAKES
            // ----------------------------------------
            if (bvalid && bready)
                bvalid <= 1'b0;

            if (rvalid && rready)
                rvalid <= 1'b0;

            // ----------------------------------------
            // FSM
            // ----------------------------------------
            case (state)

                // ----------------------
                // IDLE
                // ----------------------
                IDLE: begin
                    psel    <= 0;
                    penable <= 0;

                    if (req_valid && !bvalid && !rvalid) begin
                        paddr  <= req_addr;
                        pwrite <= req_write;
                        pwdata <= req_wdata;
                        psel   <= 1'b1;
                        state  <= SETUP;
                    end
                end

                // ----------------------
                // SETUP
                // ----------------------
                SETUP: begin
                    penable <= 1'b1;
                    state   <= ENABLE;
                end

                // ----------------------
                // ENABLE
                // ----------------------
                ENABLE: begin
                    if (pready) begin
                        penable <= 0;
                        psel    <= 0;

                        if (!req_write)
                            prdata_reg <= prdata; // READ DATA SAFE CAPTURE

                        state <= RESP;
                    end
                end

                // ----------------------
                // RESP
                // ----------------------
                RESP: begin
                    if (req_write) begin
                        bvalid <= 1'b1;
                        bresp  <= 2'b00;
                        if (bready) begin
                            req_valid <= 0;
                            state <= IDLE;
                        end
                    end else begin
                        rvalid <= 1'b1;
                        rresp  <= 2'b00;
                        rdata  <= prdata;
                        if (rready) begin
                            req_valid <= 0;
                            state <= IDLE;
                        end
                    end
                end

            endcase
        end
    end

endmodule
