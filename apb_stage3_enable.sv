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

    // REQUEST LATCH
    reg        req_valid;
    reg        req_write;
    reg [31:0] req_addr;
    reg [31:0] req_wdata;
    reg [31:0] prdata_reg;

    // FSM STATES
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ENABLE = 2'b10,
        RESP   = 2'b11
    } state_t;

    state_t state;

    assign stage3_busy = req_valid;

    // MAIN FSM
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

            // Latch request
            if (in_valid && !req_valid) begin
                req_valid <= 1'b1;
                req_write <= in_write;
                req_addr  <= in_addr;
                req_wdata <= in_wdata;
            end

            // AXI response handshakes
            if (bvalid && bready)
                bvalid <= 1'b0;

            if (rvalid && rready)
                rvalid <= 1'b0;

            // ----------------------------------------
            // FSM
            // ----------------------------------------
            case (state)

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

                SETUP: begin
                    penable <= 1'b1;
                    state   <= ENABLE;
                end

                ENABLE: begin
                    if (pready) begin
                        penable <= 0;
                        psel    <= 0;

                        if (!req_write)
                            prdata_reg <= prdata; // READ DATA SAFE CAPTURE

                        state <= RESP;
                    end
                end

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
