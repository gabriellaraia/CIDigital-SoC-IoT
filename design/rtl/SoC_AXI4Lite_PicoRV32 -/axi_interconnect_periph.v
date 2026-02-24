// -----------------------------------------------------------------------------
// AXI4-Lite Interconnect 1x6 (1 master -> 6 slaves)
// - AXI4-Lite only (no bursts, no IDs)
// - Independent read/write paths
// - Latches target on AW/AR handshake to route W/B and R
// - Unmapped access returns DECERR
// - BASE/MASK defaults come from soc_addr_map.vh
// -----------------------------------------------------------------------------

`include "soc_addr_map.vh"

module axi_interconnect_periph #(
    parameter ADDR_WIDTH = 32,
    parameter MASK_WIDTH = 32,
    parameter DATA_WIDTH = 32,

    // Address decode: (addr & MASK) == BASE -> selects slave
    parameter [ADDR_WIDTH-1:0] SLV0_BASE = `AXI_GPIO_BASE,
    parameter [MASK_WIDTH-1:0] SLV0_MASK = `AXI_GPIO_MASK,

    parameter [ADDR_WIDTH-1:0] SLV1_BASE = `AXI_TIMER_BASE,
    parameter [MASK_WIDTH-1:0] SLV1_MASK = `AXI_TIMER_MASK,

    parameter [ADDR_WIDTH-1:0] SLV2_BASE = `AXI_UART_BASE,
    parameter [MASK_WIDTH-1:0] SLV2_MASK = `AXI_UART_MASK,

    parameter [ADDR_WIDTH-1:0] SLV3_BASE = `AXI_SPI_BASE,
    parameter [MASK_WIDTH-1:0] SLV3_MASK = `AXI_SPI_MASK,

    parameter [ADDR_WIDTH-1:0] SLV4_BASE = `AXI_I2C_BASE,
    parameter [MASK_WIDTH-1:0] SLV4_MASK = `AXI_I2C_MASK,

    parameter [ADDR_WIDTH-1:0] SLV5_BASE = `AXI_INTR_BASE,
    parameter [MASK_WIDTH-1:0] SLV5_MASK = `AXI_INTR_MASK
) (
    input  wire                           aclk,
    input  wire                           aresetn,

    // ---------------- Master side (S = Slave of the interconnect) ----------------
    // Write address channel
    input  wire [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  wire                            s_axi_awvalid,
    output reg                             s_axi_awready,

    // Write data channel
    input  wire [DATA_WIDTH-1:0]     s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                            s_axi_wvalid,
    output reg                             s_axi_wready,

    // Write response channel
    output reg  [1:0]                      s_axi_bresp,
    output reg                             s_axi_bvalid,
    input  wire                            s_axi_bready,

    // Read address channel
    input  wire [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  wire                            s_axi_arvalid,
    output reg                             s_axi_arready,

    // Read data channel
    output reg  [DATA_WIDTH-1:0]     s_axi_rdata,
    output reg  [1:0]                      s_axi_rresp,
    output reg                             s_axi_rvalid,
    input  wire                            s_axi_rready,

    // ---------------- Slave side (M = Master of the interconnect) ----------------
    // Port 0
    output wire [ADDR_WIDTH-1:0]     m0_axi_awaddr,
    output wire                            m0_axi_awvalid,
    input  wire                            m0_axi_awready,
    output wire [DATA_WIDTH-1:0]     m0_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m0_axi_wstrb,
    output wire                            m0_axi_wvalid,
    input  wire                            m0_axi_wready,
    input  wire [1:0]                      m0_axi_bresp,
    input  wire                            m0_axi_bvalid,
    output wire                            m0_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m0_axi_araddr,
    output wire                            m0_axi_arvalid,
    input  wire                            m0_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m0_axi_rdata,
    input  wire [1:0]                      m0_axi_rresp,
    input  wire                            m0_axi_rvalid,
    output wire                            m0_axi_rready,

    // Port 1
    output wire [ADDR_WIDTH-1:0]     m1_axi_awaddr,
    output wire                            m1_axi_awvalid,
    input  wire                            m1_axi_awready,
    output wire [DATA_WIDTH-1:0]     m1_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m1_axi_wstrb,
    output wire                            m1_axi_wvalid,
    input  wire                            m1_axi_wready,
    input  wire [1:0]                      m1_axi_bresp,
    input  wire                            m1_axi_bvalid,
    output wire                            m1_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m1_axi_araddr,
    output wire                            m1_axi_arvalid,
    input  wire                            m1_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m1_axi_rdata,
    input  wire [1:0]                      m1_axi_rresp,
    input  wire                            m1_axi_rvalid,
    output wire                            m1_axi_rready,

    // Port 2
    output wire [ADDR_WIDTH-1:0]     m2_axi_awaddr,
    output wire                            m2_axi_awvalid,
    input  wire                            m2_axi_awready,
    output wire [DATA_WIDTH-1:0]     m2_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m2_axi_wstrb,
    output wire                            m2_axi_wvalid,
    input  wire                            m2_axi_wready,
    input  wire [1:0]                      m2_axi_bresp,
    input  wire                            m2_axi_bvalid,
    output wire                            m2_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m2_axi_araddr,
    output wire                            m2_axi_arvalid,
    input  wire                            m2_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m2_axi_rdata,
    input  wire [1:0]                      m2_axi_rresp,
    input  wire                            m2_axi_rvalid,
    output wire                            m2_axi_rready,

    // Port 3
    output wire [ADDR_WIDTH-1:0]     m3_axi_awaddr,
    output wire                            m3_axi_awvalid,
    input  wire                            m3_axi_awready,
    output wire [DATA_WIDTH-1:0]     m3_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m3_axi_wstrb,
    output wire                            m3_axi_wvalid,
    input  wire                            m3_axi_wready,
    input  wire [1:0]                      m3_axi_bresp,
    input  wire                            m3_axi_bvalid,
    output wire                            m3_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m3_axi_araddr,
    output wire                            m3_axi_arvalid,
    input  wire                            m3_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m3_axi_rdata,
    input  wire [1:0]                      m3_axi_rresp,
    input  wire                            m3_axi_rvalid,
    output wire                            m3_axi_rready,

    // Port 4
    output wire [ADDR_WIDTH-1:0]     m4_axi_awaddr,
    output wire                            m4_axi_awvalid,
    input  wire                            m4_axi_awready,
    output wire [DATA_WIDTH-1:0]     m4_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m4_axi_wstrb,
    output wire                            m4_axi_wvalid,
    input  wire                            m4_axi_wready,
    input  wire [1:0]                      m4_axi_bresp,
    input  wire                            m4_axi_bvalid,
    output wire                            m4_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m4_axi_araddr,
    output wire                            m4_axi_arvalid,
    input  wire                            m4_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m4_axi_rdata,
    input  wire [1:0]                      m4_axi_rresp,
    input  wire                            m4_axi_rvalid,
    output wire                            m4_axi_rready,

    // Port 5
    output wire [ADDR_WIDTH-1:0]     m5_axi_awaddr,
    output wire                            m5_axi_awvalid,
    input  wire                            m5_axi_awready,
    output wire [DATA_WIDTH-1:0]     m5_axi_wdata,
    output wire [(DATA_WIDTH/8)-1:0] m5_axi_wstrb,
    output wire                            m5_axi_wvalid,
    input  wire                            m5_axi_wready,
    input  wire [1:0]                      m5_axi_bresp,
    input  wire                            m5_axi_bvalid,
    output wire                            m5_axi_bready,
    output wire [ADDR_WIDTH-1:0]     m5_axi_araddr,
    output wire                            m5_axi_arvalid,
    input  wire                            m5_axi_arready,
    input  wire [DATA_WIDTH-1:0]     m5_axi_rdata,
    input  wire [1:0]                      m5_axi_rresp,
    input  wire                            m5_axi_rvalid,
    output wire                            m5_axi_rready
);

    localparam [1:0] RESP_OKAY   = 2'b00;
    localparam [1:0] RESP_DECERR = 2'b11;

    // ---------------------- Address Decode ----------------------
    function [2:0] decode;
        input [ADDR_WIDTH-1:0] addr;
        begin
            if ((addr & SLV0_MASK) == SLV0_BASE) decode = 3'd0;
            else if ((addr & SLV1_MASK) == SLV1_BASE) decode = 3'd1;
            else if ((addr & SLV2_MASK) == SLV2_BASE) decode = 3'd2;
            else if ((addr & SLV3_MASK) == SLV3_BASE) decode = 3'd3;
            else if ((addr & SLV4_MASK) == SLV4_BASE) decode = 3'd4;
            else if ((addr & SLV5_MASK) == SLV5_BASE) decode = 3'd5;
            else decode = 3'd7; // invalid
        end
    endfunction

    wire [2:0] dec_aw = decode(s_axi_awaddr[31:0]);
    wire [2:0] dec_ar = decode(s_axi_araddr[31:0]);

    // ---------------------- Write path ----------------------
    reg aw_captured;
    reg [2:0] aw_sel;

    wire aw_accept = s_axi_awvalid && s_axi_awready && !aw_captured;

    always @(posedge aclk) begin
        if (!aresetn) begin
            aw_captured <= 1'b0;
            aw_sel      <= 3'd7;
        end else begin
            if (aw_accept) begin
                aw_captured <= 1'b1;
                aw_sel      <= dec_aw;
            end else if (s_axi_bvalid && s_axi_bready) begin
                aw_captured <= 1'b0; // write completes on B handshake
                aw_sel      <= 3'd7;
            end
        end
    end

    // AW channel
    wire aw_to_valid = s_axi_awvalid && !aw_captured;

    assign m0_axi_awaddr  = s_axi_awaddr;
    assign m1_axi_awaddr  = s_axi_awaddr;
    assign m2_axi_awaddr  = s_axi_awaddr;
    assign m3_axi_awaddr  = s_axi_awaddr;
    assign m4_axi_awaddr  = s_axi_awaddr;
    assign m5_axi_awaddr  = s_axi_awaddr;

    assign m0_axi_awvalid = aw_to_valid && (dec_aw == 3'd0);
    assign m1_axi_awvalid = aw_to_valid && (dec_aw == 3'd1);
    assign m2_axi_awvalid = aw_to_valid && (dec_aw == 3'd2);
    assign m3_axi_awvalid = aw_to_valid && (dec_aw == 3'd3);
    assign m4_axi_awvalid = aw_to_valid && (dec_aw == 3'd4);
    assign m5_axi_awvalid = aw_to_valid && (dec_aw == 3'd5);

    always @(*) begin
        if (!aresetn) begin
            s_axi_awready = 1'b0;
        end else if (aw_captured) begin
            s_axi_awready = 1'b0; // não aceita novo AW até completar B
        end else begin
            case (dec_aw)
                3'd0: s_axi_awready = m0_axi_awready;
                3'd1: s_axi_awready = m1_axi_awready;
                3'd2: s_axi_awready = m2_axi_awready;
                3'd3: s_axi_awready = m3_axi_awready;
                3'd4: s_axi_awready = m4_axi_awready;
                3'd5: s_axi_awready = m5_axi_awready;
                default: s_axi_awready = 1'b1; // aceita p/ responder DECERR depois
            endcase
        end
    end

    // W channel routed by aw_sel
    assign m0_axi_wdata  = s_axi_wdata;
    assign m1_axi_wdata  = s_axi_wdata;
    assign m2_axi_wdata  = s_axi_wdata;
    assign m3_axi_wdata  = s_axi_wdata;
    assign m4_axi_wdata  = s_axi_wdata;
    assign m5_axi_wdata  = s_axi_wdata;

    assign m0_axi_wstrb  = s_axi_wstrb;
    assign m1_axi_wstrb  = s_axi_wstrb;
    assign m2_axi_wstrb  = s_axi_wstrb;
    assign m3_axi_wstrb  = s_axi_wstrb;
    assign m4_axi_wstrb  = s_axi_wstrb;
    assign m5_axi_wstrb  = s_axi_wstrb;

    assign m0_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd0);
    assign m1_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd1);
    assign m2_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd2);
    assign m3_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd3);
    assign m4_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd4);
    assign m5_axi_wvalid = s_axi_wvalid && aw_captured && (aw_sel == 3'd5);

    always @(*) begin
        case (aw_sel)
            3'd0: s_axi_wready = m0_axi_wready;
            3'd1: s_axi_wready = m1_axi_wready;
            3'd2: s_axi_wready = m2_axi_wready;
            3'd3: s_axi_wready = m3_axi_wready;
            3'd4: s_axi_wready = m4_axi_wready;
            3'd5: s_axi_wready = m5_axi_wready;
            default: s_axi_wready = 1'b1; // “sink” p/ write inválido
        endcase
    end

    // B channel mux
    assign m0_axi_bready = s_axi_bready && (aw_sel == 3'd0);
    assign m1_axi_bready = s_axi_bready && (aw_sel == 3'd1);
    assign m2_axi_bready = s_axi_bready && (aw_sel == 3'd2);
    assign m3_axi_bready = s_axi_bready && (aw_sel == 3'd3);
    assign m4_axi_bready = s_axi_bready && (aw_sel == 3'd4);
    assign m5_axi_bready = s_axi_bready && (aw_sel == 3'd5);

    always @(*) begin
        case (aw_sel)
            3'd0: begin s_axi_bvalid = m0_axi_bvalid; s_axi_bresp = m0_axi_bresp; end
            3'd1: begin s_axi_bvalid = m1_axi_bvalid; s_axi_bresp = m1_axi_bresp; end
            3'd2: begin s_axi_bvalid = m2_axi_bvalid; s_axi_bresp = m2_axi_bresp; end
            3'd3: begin s_axi_bvalid = m3_axi_bvalid; s_axi_bresp = m3_axi_bresp; end
            3'd4: begin s_axi_bvalid = m4_axi_bvalid; s_axi_bresp = m4_axi_bresp; end
            3'd5: begin s_axi_bvalid = m5_axi_bvalid; s_axi_bresp = m5_axi_bresp; end
            default: begin
                s_axi_bvalid = aw_captured; // segura até bready
                s_axi_bresp  = RESP_DECERR;
            end
        endcase
    end

    // ---------------------- Read path ----------------------
    reg ar_captured;
    reg [2:0] ar_sel;

    wire ar_accept = s_axi_arvalid && s_axi_arready && !ar_captured;

    always @(posedge aclk) begin
        if (!aresetn) begin
            ar_captured <= 1'b0;
            ar_sel      <= 3'd7;
        end else begin
            if (ar_accept) begin
                ar_captured <= 1'b1;
                ar_sel      <= dec_ar;
            end else if (s_axi_rvalid && s_axi_rready) begin
                ar_captured <= 1'b0; // read completes on R handshake
                ar_sel      <= 3'd7;
            end
        end
    end

    wire ar_to_valid = s_axi_arvalid && !ar_captured;

    assign m0_axi_araddr  = s_axi_araddr;
    assign m1_axi_araddr  = s_axi_araddr;
    assign m2_axi_araddr  = s_axi_araddr;
    assign m3_axi_araddr  = s_axi_araddr;
    assign m4_axi_araddr  = s_axi_araddr;
    assign m5_axi_araddr  = s_axi_araddr;

    assign m0_axi_arvalid = ar_to_valid && (dec_ar == 3'd0);
    assign m1_axi_arvalid = ar_to_valid && (dec_ar == 3'd1);
    assign m2_axi_arvalid = ar_to_valid && (dec_ar == 3'd2);
    assign m3_axi_arvalid = ar_to_valid && (dec_ar == 3'd3);
    assign m4_axi_arvalid = ar_to_valid && (dec_ar == 3'd4);
    assign m5_axi_arvalid = ar_to_valid && (dec_ar == 3'd5);

    always @(*) begin
        if (!aresetn) begin
            s_axi_arready = 1'b0;
        end else if (ar_captured) begin
            s_axi_arready = 1'b0; // não aceita novo AR até completar R
        end else begin
            case (dec_ar)
                3'd0: s_axi_arready = m0_axi_arready;
                3'd1: s_axi_arready = m1_axi_arready;
                3'd2: s_axi_arready = m2_axi_arready;
                3'd3: s_axi_arready = m3_axi_arready;
                3'd4: s_axi_arready = m4_axi_arready;
                3'd5: s_axi_arready = m5_axi_arready;
                default: s_axi_arready = 1'b1; // aceita p/ responder DECERR
            endcase
        end
    end

    // R channel mux
    assign m0_axi_rready = s_axi_rready && (ar_sel == 3'd0);
    assign m1_axi_rready = s_axi_rready && (ar_sel == 3'd1);
    assign m2_axi_rready = s_axi_rready && (ar_sel == 3'd2);
    assign m3_axi_rready = s_axi_rready && (ar_sel == 3'd3);
    assign m4_axi_rready = s_axi_rready && (ar_sel == 3'd4);
    assign m5_axi_rready = s_axi_rready && (ar_sel == 3'd5);

    always @(*) begin
        case (ar_sel)
            3'd0: begin s_axi_rvalid = m0_axi_rvalid; s_axi_rdata = m0_axi_rdata; s_axi_rresp = m0_axi_rresp; end
            3'd1: begin s_axi_rvalid = m1_axi_rvalid; s_axi_rdata = m1_axi_rdata; s_axi_rresp = m1_axi_rresp; end
            3'd2: begin s_axi_rvalid = m2_axi_rvalid; s_axi_rdata = m2_axi_rdata; s_axi_rresp = m2_axi_rresp; end
            3'd3: begin s_axi_rvalid = m3_axi_rvalid; s_axi_rdata = m3_axi_rdata; s_axi_rresp = m3_axi_rresp; end
            3'd4: begin s_axi_rvalid = m4_axi_rvalid; s_axi_rdata = m4_axi_rdata; s_axi_rresp = m4_axi_rresp; end
            3'd5: begin s_axi_rvalid = m5_axi_rvalid; s_axi_rdata = m5_axi_rdata; s_axi_rresp = m5_axi_rresp; end
            default: begin
                s_axi_rvalid = ar_captured; // segura até rready
                s_axi_rdata  = {DATA_WIDTH{1'b0}};
                s_axi_rresp  = RESP_DECERR;
            end
        endcase
    end

endmodule
