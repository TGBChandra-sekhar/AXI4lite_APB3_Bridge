module axi_stage0_capture (
    input  wire        aclk,
    input  wire        aresetn,
    input  wire        busy,

    input  wire [31:0] awaddr,
    input  wire        awvalid,
    output reg         awready,

    input  wire [31:0] wdata,
    input  wire        wvalid,
    output reg         wready,

    input  wire [31:0] araddr,
    input  wire        arvalid,
    output reg         arready,

    output reg         out_valid,
    output reg         out_write,
    output reg [31:0]  out_addr,
    output reg [31:0]  out_wdata
);

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            awready  <= 0;
            wready   <= 0;
            arready  <= 0;
            out_valid<= 0;
        end else begin
            awready   <= !busy;
            wready    <= !busy;
            arready   <= !busy;
            out_valid <= 0;

            // WRITE has priority (AXI rule)
            if (!busy && awvalid && wvalid) begin
                out_valid <= 1;
                out_write <= 1;
                out_addr  <= awaddr;
                out_wdata <= wdata;
            end

            // READ (independent)
            else if (!busy && arvalid) begin
                out_valid <= 1;
                out_write <= 0;
                out_addr  <= araddr;
                out_wdata <= 32'd0;
            end
        end
    end
endmodule
