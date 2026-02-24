`include "soc_addr_map.vh"

//------------------------------------------------------------------------------
// Bootloader HW: EEPROM (via AXI SPI bridge window) -> RAM
// - boot_pin=1: copies WORDS 32-bit words from SRC_BASE to DEST_BASE
// - boot_pin=0: idle
//
// AXI-Lite notes:
// - Holds *VALID until *READY handshake
// - Holds RREADY high while waiting for RVALID (consumes once)
// - Holds BREADY high while waiting for BVALID (consumes once)
//------------------------------------------------------------------------------
module axi_bootloader_memcpy #(
  parameter integer WORDS     = 256,
  parameter [31:0]  SRC_BASE  = `AXI_SPI_BOOT_BASE,
  parameter [31:0]  DEST_BASE = `AXI_RAM_BASE
)(
  input  wire clk,
  input  wire resetn,
  input  wire boot_pin,

  // AXI-Lite master
  output reg  [31:0] m_awaddr,
  output reg         m_awvalid,
  input  wire        m_awready,
  output reg  [2:0]  m_awprot,

  output reg  [31:0] m_wdata,
  output reg  [3:0]  m_wstrb,
  output reg         m_wvalid,
  input  wire        m_wready,

  input  wire        m_bvalid,
  output reg         m_bready,

  output reg  [31:0] m_araddr,
  output reg         m_arvalid,
  input  wire        m_arready,
  output reg  [2:0]  m_arprot,

  input  wire        m_rvalid,
  output reg         m_rready,
  input  wire [31:0] m_rdata,

  output reg done,
  output reg error,

  // NEW (opcional, mas muito útil no TOP/mux)
  output reg active
);

  reg [31:0] idx;
  reg [31:0] rd_word;

  reg [3:0] state;
  localparam ST_IDLE   = 4'd0;
  localparam ST_AR     = 4'd1;
  localparam ST_R      = 4'd2;
  localparam ST_AW     = 4'd3;
  localparam ST_W      = 4'd4;
  localparam ST_B      = 4'd5;
  localparam ST_NEXT   = 4'd6;
  localparam ST_FINISH = 4'd7;

  // handshake helpers
  wire ar_fire = m_arvalid && m_arready;
  wire r_fire  = m_rvalid  && m_rready;
  wire aw_fire = m_awvalid && m_awready;
  wire w_fire  = m_wvalid  && m_wready;
  wire b_fire  = m_bvalid  && m_bready;

  always @(posedge clk) begin
    if (!resetn) begin
      idx     <= 32'd0;
      rd_word <= 32'd0;

      m_awaddr  <= 32'd0;
      m_awvalid <= 1'b0;
      m_awprot  <= 3'b000;

      m_wdata   <= 32'd0;
      m_wstrb   <= 4'hF;
      m_wvalid  <= 1'b0;

      m_bready  <= 1'b0;

      m_araddr  <= 32'd0;
      m_arvalid <= 1'b0;
      m_arprot  <= 3'b000;

      m_rready  <= 1'b0;

      done   <= 1'b0;
      error  <= 1'b0;
      active <= 1'b0;

      state <= ST_IDLE;

    end else begin
      // default: mantém done latched enquanto boot_pin=1
      // e limpa quando boot_pin cair
      if (!boot_pin) begin
        done   <= 1'b0;
        active <= 1'b0;
      end

      case (state)

        // ------------------------------------------------------------
        // IDLE: waits boot_pin
        // ------------------------------------------------------------
        ST_IDLE: begin
          error  <= 1'b0;

          // canais em default seguro
          m_arvalid <= 1'b0;
          m_rready  <= 1'b0;
          m_awvalid <= 1'b0;
          m_wvalid  <= 1'b0;
          m_bready  <= 1'b0;

          if (boot_pin) begin
            // novo boot: limpa done e começa
            done   <= 1'b0;
            active <= 1'b1;

            idx    <= 32'd0;
            state  <= ST_AR;
          end
        end

        // ------------------------------------------------------------
        // READ address: hold ARVALID until ARREADY
        // ------------------------------------------------------------
        ST_AR: begin
          m_araddr  <= SRC_BASE + (idx << 2);
          m_arprot  <= 3'b000;

          m_arvalid <= 1'b1;

          if (ar_fire) begin
            m_arvalid <= 1'b0;
            m_rready  <= 1'b1;
            state     <= ST_R;
          end
        end

        // ------------------------------------------------------------
        // READ data: hold RREADY until RVALID arrives (consume once)
        // ------------------------------------------------------------
        ST_R: begin
          if (r_fire) begin
            rd_word  <= m_rdata;
            m_rready <= 1'b0;
            state    <= ST_AW;
          end
        end

        // ------------------------------------------------------------
        // WRITE address: hold AWVALID until AWREADY
        // ------------------------------------------------------------
        ST_AW: begin
          m_awaddr  <= DEST_BASE + (idx << 2);
          m_awprot  <= 3'b000;

          m_awvalid <= 1'b1;

          if (aw_fire) begin
            m_awvalid <= 1'b0;
            state     <= ST_W;
          end
        end

        // ------------------------------------------------------------
        // WRITE data: hold WVALID until WREADY
        // ------------------------------------------------------------
        ST_W: begin
          m_wdata  <= rd_word;
          m_wstrb  <= 4'hF;

          m_wvalid <= 1'b1;

          if (w_fire) begin
            m_wvalid <= 1'b0;
            m_bready <= 1'b1;
            state    <= ST_B;
          end
        end

        // ------------------------------------------------------------
        // WRITE response: hold BREADY until BVALID arrives (consume once)
        // ------------------------------------------------------------
        ST_B: begin
          if (b_fire) begin
            m_bready <= 1'b0;
            state    <= ST_NEXT;
          end
        end

        // ------------------------------------------------------------
        // Next word / finish
        // ------------------------------------------------------------
        ST_NEXT: begin
          if (idx == (WORDS-1)) begin
            done  <= 1'b1;   // LATCHED (fica 1 enquanto boot_pin=1)
            state <= ST_FINISH;
          end else begin
            idx   <= idx + 1;
            state <= ST_AR;
          end
        end

        // ------------------------------------------------------------
        // Finish: fica aqui enquanto boot_pin=1
        // Quando boot_pin cair, a lógica no topo limpa done/active
        // e volta para IDLE
        // ------------------------------------------------------------
        ST_FINISH: begin
          // canais em idle
          m_arvalid <= 1'b0;
          m_rready  <= 1'b0;
          m_awvalid <= 1'b0;
          m_wvalid  <= 1'b0;
          m_bready  <= 1'b0;

          if (!boot_pin) begin
            state <= ST_IDLE;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule