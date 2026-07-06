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
