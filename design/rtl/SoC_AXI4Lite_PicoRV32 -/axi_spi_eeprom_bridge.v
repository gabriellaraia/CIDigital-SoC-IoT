`include "soc_addr_map.vh"

//------------------------------------------------------------------------------
// AXI4-Lite (slave) to SPI EEPROM (master) bridge  (Verilog-2001 only)
//  - On AXI read, performs SPI READ (0x03) + 16-bit address, reads 4 bytes
//  - Returns 32-bit little-endian word: rdata = {b3,b2,b1,b0}
//  - SPI Mode 0 (CPOL=0, CPHA=0): sample MISO on rising edge, change MOSI on falling
//
// Address dependency:
//  - Only accepts reads when (ARADDR & AXI_SPI_BOOT_MASK) == (AXI_SPI_BOOT_BASE & mask)
//  - EEPROM byte address used = (ARADDR - AXI_SPI_BOOT_BASE)[15:0]
//  - If address is outside: returns DECERR
//
// Notes:
//  - Simple single-beat reads.
//  - Writes are accepted (OKAY) but do nothing.
//------------------------------------------------------------------------------
module axi_spi_eeprom_bridge
#(
    parameter integer CLK_DIV = 4  // SPI half-period divider (>=1). Larger => slower SPI.
)
(
    input  wire         aclk,
    input  wire         aresetn,

    // AXI4-Lite Slave Interface (READ)
    input  wire [31:0]  s_axi_araddr,
    input  wire         s_axi_arvalid,
    output reg          s_axi_arready,

    output reg  [31:0]  s_axi_rdata,
    output reg  [1:0]   s_axi_rresp,
    output reg          s_axi_rvalid,
    input  wire         s_axi_rready,

    // AXI4-Lite Slave Interface (WRITE - dummy)
    input  wire [31:0]  s_axi_awaddr,
    input  wire         s_axi_awvalid,
    output reg          s_axi_awready,

    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output reg          s_axi_wready,

    output reg  [1:0]   s_axi_bresp,
    output reg          s_axi_bvalid,
    input  wire         s_axi_bready,

    // SPI Master pins
    output reg          spi_csn,
    output reg          spi_sclk,
    output reg          spi_mosi,
    input  wire         spi_miso
);

    // --------------------------
    // Address window check
    // --------------------------
    wire hit_boot_window;
    assign hit_boot_window =
        ((s_axi_araddr & `AXI_SPI_BOOT_MASK) == (`AXI_SPI_BOOT_BASE & `AXI_SPI_BOOT_MASK));

    // EEPROM byte address offset (relative to AXI_SPI_BOOT_BASE)
    wire [31:0] ar_off;
    assign ar_off = (s_axi_araddr - `AXI_SPI_BOOT_BASE);

    // --------------------------
    // AXI read capture
    // --------------------------
    reg [15:0]  rd_addr16;
    reg         rd_pending;
    reg         rd_oob;

    // --------------------------
    // SPI engine
    // --------------------------
    localparam [7:0] CMD_READ = 8'h03;

    reg [2:0] state;
    localparam ST_IDLE   = 3'd0;
    localparam ST_START  = 3'd1;
    localparam ST_SHIFT  = 3'd2;
    localparam ST_DONE   = 3'd3;

    reg [7:0]  div_cnt;
    reg        tick;

    reg [5:0]  bit_cnt;       // 0..55 (24 cmd+addr + 32 data)
    reg [1:0]  byte_idx;      // 0..3
    reg [2:0]  bit_in_byte;   // 0..7

    reg [7:0]  data_b0, data_b1, data_b2, data_b3;
    reg [7:0]  rx_byte_shift;

    wire [23:0] cmd_addr;
    assign cmd_addr = {CMD_READ, rd_addr16};

    // --------------------------
    // SPI clock divider tick (toggle request)
    // --------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            div_cnt <= 8'd0;
            tick    <= 1'b0;
        end else begin
            tick <= 1'b0;
            if (state == ST_SHIFT) begin
                if (div_cnt == (CLK_DIV-1)) begin
                    div_cnt <= 8'd0;
                    tick    <= 1'b1;
                end else begin
                    div_cnt <= div_cnt + 8'd1;
                end
            end else begin
                div_cnt <= 8'd0;
            end
        end
    end

    // --------------------------
    // Main FSM
    // --------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            // AXI defaults
            s_axi_arready <= 1'b0;
            s_axi_rdata   <= 32'd0;
            s_axi_rresp   <= 2'b00;
            s_axi_rvalid  <= 1'b0;

            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_bvalid  <= 1'b0;

            rd_addr16     <= 16'd0;
            rd_pending    <= 1'b0;
            rd_oob        <= 1'b0;

            // SPI defaults
            spi_csn       <= 1'b1;
            spi_sclk      <= 1'b0;
            spi_mosi      <= 1'b0;

            state         <= ST_IDLE;
            bit_cnt       <= 6'd0;
            byte_idx      <= 2'd0;
            bit_in_byte   <= 3'd0;
            rx_byte_shift <= 8'd0;

            data_b0       <= 8'd0;
            data_b1       <= 8'd0;
            data_b2       <= 8'd0;
            data_b3       <= 8'd0;

        end else begin
            // ------------------------------------------------------
            // AXI write (dummy): accept AW+W and respond OKAY
            // ------------------------------------------------------
            if (!s_axi_bvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                if (s_axi_awvalid && s_axi_wvalid) begin
                    s_axi_bvalid <= 1'b1;
                    s_axi_bresp  <= 2'b00; // OKAY
                end
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                end
            end

            // ------------------------------------------------------
            // AXI read address handshake (FIX: require ARREADY)
            // ------------------------------------------------------
            if ((state == ST_IDLE) && (!s_axi_rvalid) && (!rd_pending)) begin
                s_axi_arready <= 1'b1;
                if (s_axi_arvalid && s_axi_arready) begin
                    s_axi_arready <= 1'b0;

                    rd_oob     <= ~hit_boot_window;
                    rd_addr16  <= ar_off[15:0];
                    rd_pending <= 1'b1;
                end
            end else begin
                s_axi_arready <= 1'b0;
            end

            // ------------------------------------------------------
            // SPI FSM
            // ------------------------------------------------------
            case (state)
                ST_IDLE: begin
                    spi_csn  <= 1'b1;
                    spi_sclk <= 1'b0;
                    spi_mosi <= 1'b0;

                    if (rd_pending) begin
                        // Out-of-window => DECERR
                        if (rd_oob) begin
                            if (!s_axi_rvalid) begin
                                s_axi_rdata  <= 32'h0000_0000;
                                s_axi_rresp  <= 2'b11; // DECERR
                                s_axi_rvalid <= 1'b1;
                            end
                            if (s_axi_rvalid && s_axi_rready) begin
                                s_axi_rvalid <= 1'b0;
                                rd_pending   <= 1'b0;
                                rd_oob       <= 1'b0;
                            end
                        end else begin
                            // prepare SPI transfer
                            bit_cnt       <= 6'd0;
                            byte_idx      <= 2'd0;
                            bit_in_byte   <= 3'd0;
                            rx_byte_shift <= 8'd0;

                            data_b0       <= 8'd0;
                            data_b1       <= 8'd0;
                            data_b2       <= 8'd0;
                            data_b3       <= 8'd0;

                            state         <= ST_START;
                        end
                    end
                end

                ST_START: begin
                    // Assert CSn and setup MOSI for first bit before first rising edge
                    spi_csn  <= 1'b0;
                    spi_sclk <= 1'b0;

                    // First bit (bit_cnt=0): cmd_addr[23]
                    spi_mosi <= cmd_addr[23];

                    rd_pending <= 1'b0;
                    state      <= ST_SHIFT;
                end

                ST_SHIFT: begin
                    if (tick) begin
                        // Toggle SCLK
                        spi_sclk <= ~spi_sclk;

                        if (spi_sclk == 1'b0) begin
                            // 0->1 rising edge: sample MISO (data phase after 24 bits)
                            if (bit_cnt >= 6'd24) begin
                                rx_byte_shift <= {rx_byte_shift[6:0], spi_miso};
                                bit_in_byte   <= bit_in_byte + 3'd1;

                                if (bit_in_byte == 3'd7) begin
                                    // commit assembled byte
                                    case (byte_idx)
                                        2'd0: data_b0 <= {rx_byte_shift[6:0], spi_miso};
                                        2'd1: data_b1 <= {rx_byte_shift[6:0], spi_miso};
                                        2'd2: data_b2 <= {rx_byte_shift[6:0], spi_miso};
                                        2'd3: data_b3 <= {rx_byte_shift[6:0], spi_miso};
                                    endcase
                                    byte_idx      <= byte_idx + 2'd1;
                                    bit_in_byte   <= 3'd0;
                                    rx_byte_shift <= 8'd0;
                                end
                            end

                            bit_cnt <= bit_cnt + 6'd1;

                            if (bit_cnt == 6'd55) begin
                                state <= ST_DONE;
                            end

                        end else begin
                            // 1->0 falling edge: update MOSI for next bit
                            // FIX: correct indexing so we do not skip bits
                            // After ST_START sent [23], when bit_cnt==1 we must send [22], ...
                            if (bit_cnt < 6'd24) begin
                                spi_mosi <= cmd_addr[23 - bit_cnt];
                            end else begin
                                spi_mosi <= 1'b0;
                            end
                        end
                    end
                end

                ST_DONE: begin
                    spi_csn  <= 1'b1;
                    spi_sclk <= 1'b0;
                    spi_mosi <= 1'b0;

                    if (!s_axi_rvalid) begin
                        s_axi_rdata  <= {data_b3, data_b2, data_b1, data_b0};
                        s_axi_rresp  <= 2'b00; // OKAY
                        s_axi_rvalid <= 1'b1;
                    end

                    if (s_axi_rvalid && s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        state        <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule