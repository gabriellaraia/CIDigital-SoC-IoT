`include "soc_addr_map.vh"

//------------------------------------------------------------------------------
// Root AXI-Lite interconnect: 2 masters (CPU/BOOT) -> 3 slaves (MEM/PERIPH/BOOT)
// FIX: safe switching between masters using latched selection boot_sel_q.
//------------------------------------------------------------------------------
module axi_interconnect_root #(
    localparam ADDR_WIDTH = 32,
    localparam MASK_WIDTH = 32,
    localparam DATA_WIDTH = 32,

    parameter [ADDR_WIDTH-1:0] S0_BASE = `AXI_MEM_REGION_BASE,
    parameter [MASK_WIDTH-1:0] S0_MASK = `AXI_MEM_REGION_MASK,

    parameter [ADDR_WIDTH-1:0] S1_BASE = `AXI_PERIPH_REGION_BASE,
    parameter [MASK_WIDTH-1:0] S1_MASK = `AXI_PERIPH_REGION_MASK,

    parameter [ADDR_WIDTH-1:0] S2_BASE = `AXI_BOOT_REGION_BASE,
    parameter [MASK_WIDTH-1:0] S2_MASK = `AXI_BOOT_REGION_MASK
)(
    input  wire clk,
    input  wire resetn,
    input  wire boot_active, // request: 1=BOOT master wants bus

    // ---------------- Master 0 = CPU ----------------
    input  wire        cpu_awvalid,
    output wire        cpu_awready,
    input  wire [ADDR_WIDTH-1:0] cpu_awaddr,
    input  wire [2:0]  cpu_awprot,

    input  wire        cpu_wvalid,
    output wire        cpu_wready,
    input  wire [DATA_WIDTH-1:0] cpu_wdata,
    input  wire [(DATA_WIDTH/8)-1:0]  cpu_wstrb,

    output wire        cpu_bvalid,
    input  wire        cpu_bready,

    input  wire        cpu_arvalid,
    output wire        cpu_arready,
    input  wire [ADDR_WIDTH-1:0] cpu_araddr,
    input  wire [2:0]  cpu_arprot,

    output wire        cpu_rvalid,
    input  wire        cpu_rready,
    output wire [DATA_WIDTH-1:0] cpu_rdata,

    // ---------------- Master 1 = BOOT ----------------
    input  wire        boot_awvalid,
    output wire        boot_awready,
    input  wire [ADDR_WIDTH-1:0] boot_awaddr,
    input  wire [2:0]  boot_awprot,

    input  wire        boot_wvalid,
    output wire        boot_wready,
    input  wire [DATA_WIDTH-1:0] boot_wdata,
    input  wire [(DATA_WIDTH/8)-1:0]  boot_wstrb,

    output wire        boot_bvalid,
    input  wire        boot_bready,

    input  wire        boot_arvalid,
    output wire        boot_arready,
    input  wire [ADDR_WIDTH-1:0] boot_araddr,
    input  wire [2:0]  boot_arprot,

    output wire        boot_rvalid,
    input  wire        boot_rready,
    output wire [DATA_WIDTH-1:0] boot_rdata,

    // ---------------- Slave 0 = MEM ----------------
    output wire        s0_awvalid,
    input  wire        s0_awready,
    output wire [ADDR_WIDTH-1:0] s0_awaddr,
    output wire [2:0]  s0_awprot,

    output wire        s0_wvalid,
    input  wire        s0_wready,
    output wire [DATA_WIDTH-1:0] s0_wdata,
    output wire [(DATA_WIDTH/8)-1:0]  s0_wstrb,

    input  wire        s0_bvalid,
    output wire        s0_bready,

    output wire        s0_arvalid,
    input  wire        s0_arready,
    output wire [ADDR_WIDTH-1:0] s0_araddr,
    output wire [2:0]  s0_arprot,

    input  wire        s0_rvalid,
    output wire        s0_rready,
    input  wire [DATA_WIDTH-1:0] s0_rdata,

    // ---------------- Slave 1 = PERIPH ----------------
    output wire        s1_awvalid,
    input  wire        s1_awready,
    output wire [ADDR_WIDTH-1:0] s1_awaddr,
    output wire [2:0]  s1_awprot,

    output wire        s1_wvalid,
    input  wire        s1_wready,
    output wire [DATA_WIDTH-1:0] s1_wdata,
    output wire [(DATA_WIDTH/8)-1:0]  s1_wstrb,

    input  wire        s1_bvalid,
    output wire        s1_bready,

    output wire        s1_arvalid,
    input  wire        s1_arready,
    output wire [ADDR_WIDTH-1:0] s1_araddr,
    output wire [2:0]  s1_arprot,

    input  wire        s1_rvalid,
    output wire        s1_rready,
    input  wire [DATA_WIDTH-1:0] s1_rdata,

    // ---------------- Slave 2 = BOOT REGION ----------------
    output wire        s2_awvalid,
    input  wire        s2_awready,
    output wire [ADDR_WIDTH-1:0] s2_awaddr,
    output wire [2:0]  s2_awprot,

    output wire        s2_wvalid,
    input  wire        s2_wready,
    output wire [DATA_WIDTH-1:0] s2_wdata,
    output wire [(DATA_WIDTH/8)-1:0]  s2_wstrb,

    input  wire        s2_bvalid,
    output wire        s2_bready,

    output wire        s2_arvalid,
    input  wire        s2_arready,
    output wire [ADDR_WIDTH-1:0] s2_araddr,
    output wire [2:0]  s2_arprot,

    input  wire        s2_rvalid,
    output wire        s2_rready,
    input  wire [DATA_WIDTH-1:0] s2_rdata
);

    localparam ID_MEM    = 2'd0; // Corresponde a S0
    localparam ID_PERIPH = 2'd1; // Corresponde a S1
    localparam ID_BOOT   = 2'd2; // Corresponde a S2
    localparam ID_ERROR  = 2'd3; // OOB (Out of Bound)

    // =========================================================================
    // SAFE MASTER SELECT (latched)
    // =========================================================================
    reg boot_sel_q;

    // respostas internas (para master ATIVO)
    wire        m_awready_i, m_wready_i, m_bvalid_i;
    wire        m_arready_i, m_rvalid_i;
    wire [DATA_WIDTH-1:0] m_rdata_i;

    // flags internos (declaração antecipada pois usados no can_switch)
    reg  wr_have_aw, wr_have_w;
    reg  wr_oob;
    reg  bvalid_int;

    reg  rd_busy;
    reg  rd_oob;
    reg  rvalid_int;

    // Seguro trocar somente quando tudo estiver idle
    wire can_switch;
    assign can_switch =
                    (!rd_busy) && (!rvalid_int) &&  // Remover m_rvalid_i daqui
                    (!wr_have_aw) && (!wr_have_w) && (!m_bvalid_i) && (!bvalid_int);

    always @(posedge clk) begin
        if (!resetn) begin
            boot_sel_q <= 1'b1; // começa em BOOT por segurança (pode ser 0 se preferir)
        end else begin
            if (can_switch)
                boot_sel_q <= boot_active; // segue o request só quando idle
        end
    end

    // =========================================================================
    // MUX MASTER (AGORA USA boot_sel_q e NÃO boot_active direto)
    // =========================================================================
    wire        m_awvalid = boot_sel_q ? boot_awvalid : cpu_awvalid;
    wire [ADDR_WIDTH-1:0] m_awaddr  = boot_sel_q ? boot_awaddr  : cpu_awaddr;
    wire [2:0]  m_awprot  = boot_sel_q ? boot_awprot  : cpu_awprot;

    wire        m_wvalid  = boot_sel_q ? boot_wvalid : cpu_wvalid;
    wire [DATA_WIDTH-1:0] m_wdata   = boot_sel_q ? boot_wdata  : cpu_wdata;
    wire [(DATA_WIDTH/8)-1:0]  m_wstrb   = boot_sel_q ? boot_wstrb  : cpu_wstrb;

    wire        m_bready  = boot_sel_q ? boot_bready : cpu_bready;

    wire        m_arvalid = boot_sel_q ? boot_arvalid : cpu_arvalid;
    wire [ADDR_WIDTH-1:0] m_araddr  = boot_sel_q ? boot_araddr  : cpu_araddr;
    wire [2:0]  m_arprot  = boot_sel_q ? boot_arprot  : cpu_arprot;

    wire        m_rready  = boot_sel_q ? boot_rready : cpu_rready;

    // devolve só ao master ativo (AGORA usa boot_sel_q)
    assign cpu_awready  = (!boot_sel_q) ? m_awready_i : 1'b0;
    assign cpu_wready   = (!boot_sel_q) ? m_wready_i  : 1'b0;
    assign cpu_bvalid   = (!boot_sel_q) ? m_bvalid_i  : 1'b0;
    assign cpu_arready  = (!boot_sel_q) ? m_arready_i : 1'b0;
    assign cpu_rvalid   = (!boot_sel_q) ? m_rvalid_i  : 1'b0;
    assign cpu_rdata    = (!boot_sel_q) ? m_rdata_i   : 32'h0;

    assign boot_awready = ( boot_sel_q) ? m_awready_i : 1'b0;
    assign boot_wready  = ( boot_sel_q) ? m_wready_i  : 1'b0;
    assign boot_bvalid  = ( boot_sel_q) ? m_bvalid_i  : 1'b0;
    assign boot_arready = ( boot_sel_q) ? m_arready_i : 1'b0;
    assign boot_rvalid  = ( boot_sel_q) ? m_rvalid_i  : 1'b0;
    assign boot_rdata   = ( boot_sel_q) ? m_rdata_i   : 32'h0;

    // =========================================================================
    // DECODE
    // =========================================================================
    wire hit_s0_aw = ((m_awaddr & S0_MASK) == (S0_BASE & S0_MASK));
    wire hit_s1_aw = ((m_awaddr & S1_MASK) == (S1_BASE & S1_MASK));
    wire hit_s2_aw = ((m_awaddr & S2_MASK) == (S2_BASE & S2_MASK));

    wire hit_s0_ar = ((m_araddr & S0_MASK) == (S0_BASE & S0_MASK));
    wire hit_s1_ar = ((m_araddr & S1_MASK) == (S1_BASE & S1_MASK));
    wire hit_s2_ar = ((m_araddr & S2_MASK) == (S2_BASE & S2_MASK));

    // =========================================================================
    // WRITE (AW/W/B)  (seu código original abaixo, só removi re-declarações)
    // =========================================================================
    reg [1:0] wr_target_id; 

    assign s0_awvalid = m_awvalid && !wr_have_aw && hit_s0_aw;
    assign s1_awvalid = m_awvalid && !wr_have_aw && hit_s1_aw;
    assign s2_awvalid = m_awvalid && !wr_have_aw && hit_s2_aw;

    assign s0_awaddr  = m_awaddr;  assign s1_awaddr = m_awaddr;  assign s2_awaddr = m_awaddr;
    assign s0_awprot  = m_awprot;  assign s1_awprot = m_awprot;  assign s2_awprot = m_awprot;

    assign m_awready_i = (!wr_have_aw) ? ( hit_s0_aw ? s0_awready :
                                          hit_s1_aw ? s1_awready :
                                          hit_s2_aw ? s2_awready :
                                                      1'b1 )
                                       : 1'b0;

    always @(posedge clk) begin
        if (!resetn) begin
            wr_have_aw <= 1'b0;
            wr_have_w  <= 1'b0;
            wr_target_id     <= 2'b00;
            wr_oob     <= 1'b0;
        end else begin
            if (!wr_have_aw && m_awvalid && m_awready_i) begin
                wr_have_aw <= 1'b1;
                if (hit_s0_aw)      begin wr_target_id <= ID_MEM;    wr_oob <= 1'b0; end
                else if (hit_s1_aw) begin wr_target_id <= ID_PERIPH; wr_oob <= 1'b0; end
                else if (hit_s2_aw) begin wr_target_id <= ID_BOOT;   wr_oob <= 1'b0; end
                else begin wr_target_id <= 2'b00; wr_oob <= 1'b1; end
            end

            if (!wr_have_w && m_wvalid && m_wready_i)
                wr_have_w <= 1'b1;

            if (m_bvalid_i && m_bready) begin
                wr_have_aw <= 1'b0;
                wr_have_w  <= 1'b0;
            end
        end
    end

    assign s0_wvalid = m_wvalid && wr_have_aw && !wr_oob && (wr_target_id == ID_MEM)    && !wr_have_w;
    assign s1_wvalid = m_wvalid && wr_have_aw && !wr_oob && (wr_target_id == ID_PERIPH) && !wr_have_w;
    assign s2_wvalid = m_wvalid && wr_have_aw && !wr_oob && (wr_target_id == ID_BOOT)   && !wr_have_w;

    assign s0_wdata  = m_wdata;  assign s1_wdata = m_wdata;  assign s2_wdata = m_wdata;
    assign s0_wstrb  = m_wstrb;  assign s1_wstrb = m_wstrb;  assign s2_wstrb = m_wstrb;

    assign m_wready_i = (wr_have_aw && !wr_have_w) ?
                      ( wr_oob ? 1'b1 :
                      (wr_target_id == ID_MEM)    ? s0_wready :
                      (wr_target_id == ID_PERIPH) ? s1_wready :
                                                    s2_wready ) : 1'b0;

    assign m_bvalid_i = wr_oob ? bvalid_int :
                    (wr_target_id == ID_MEM)    ? s0_bvalid :
                    (wr_target_id == ID_PERIPH) ? s1_bvalid :
                                                  s2_bvalid;

    assign s0_bready = (!wr_oob && (wr_target_id == ID_MEM))    ? m_bready : 1'b0;
    assign s1_bready = (!wr_oob && (wr_target_id == ID_PERIPH)) ? m_bready : 1'b0;
    assign s2_bready = (!wr_oob && (wr_target_id == ID_BOOT))   ? m_bready : 1'b0;

    always @(posedge clk) begin
        if (!resetn) begin
            bvalid_int <= 1'b0;
        end else begin
            if (wr_oob) begin
                if (!bvalid_int && wr_have_aw && wr_have_w)
                    bvalid_int <= 1'b1;
                if (bvalid_int && m_bready)
                    bvalid_int <= 1'b0;
            end else begin
                bvalid_int <= 1'b0;
            end
        end
    end

    // =========================================================================
    // READ (AR/R)  
    // =========================================================================
    reg [1:0] rd_sel; // 01=S0, 00=S1, 10=S2
    reg [31:0] rdata_int;

    assign s0_arvalid = m_arvalid && !rd_busy && hit_s0_ar;
    assign s1_arvalid = m_arvalid && !rd_busy && hit_s1_ar;
    assign s2_arvalid = m_arvalid && !rd_busy && hit_s2_ar;

    assign s0_araddr  = m_araddr;  assign s1_araddr = m_araddr;  assign s2_araddr = m_araddr;
    assign s0_arprot  = m_arprot;  assign s1_arprot = m_arprot;  assign s2_arprot = m_arprot;

    assign m_arready_i = (!rd_busy) ? ( hit_s0_ar ? s0_arready :
                                       hit_s1_ar ? s1_arready :
                                       hit_s2_ar ? s2_arready :
                                                   1'b1 )
                                    : 1'b0;

    always @(posedge clk) begin
    if (!resetn) begin
        rd_busy    <= 1'b0;
        rd_sel     <= ID_MEM; // Pode iniciar com um valor seguro
        rd_oob     <= 1'b0;
        rvalid_int <= 1'b0;
        rdata_int  <= 32'h0;
    end else begin
        if (!rd_busy && m_arvalid && m_arready_i) begin
            rd_busy <= 1'b1;
            if (hit_s0_ar)      begin rd_sel <= ID_MEM;    rd_oob <= 1'b0; end
            else if (hit_s1_ar) begin rd_sel <= ID_PERIPH; rd_oob <= 1'b0; end
            else if (hit_s2_ar) begin rd_sel <= ID_BOOT;   rd_oob <= 1'b0; end
            else begin
                rd_sel     <= ID_ERROR; // Boa prática definir erro
                rd_oob     <= 1'b1;
                rvalid_int <= 1'b1;
                rdata_int  <= 32'hDEAD_BEEF;
            end
        end

        if (m_rvalid_i && m_rready) begin
            rd_busy    <= 1'b0;
            rvalid_int <= 1'b0;
        end
    end
end

    // Ativa a mux SOMENTE quando rd_busy=1
    assign m_rvalid_i = !rd_busy ? 1'b0 : (rd_oob ? rvalid_int :
                        (rd_sel == ID_MEM)    ? s0_rvalid :
                        (rd_sel == ID_PERIPH) ? s1_rvalid :
                                                s2_rvalid);

    assign m_rdata_i  = !rd_busy ? 32'h0 : (rd_oob ? rdata_int :
                        (rd_sel == ID_MEM)    ? s0_rdata :
                        (rd_sel == ID_PERIPH) ? s1_rdata :
                                                s2_rdata);

    assign s0_rready = (rd_busy && !rd_oob && (rd_sel == ID_MEM))    ? m_rready : 1'b0;
    assign s1_rready = (rd_busy && !rd_oob && (rd_sel == ID_PERIPH)) ? m_rready : 1'b0;
    assign s2_rready = (rd_busy && !rd_oob && (rd_sel == ID_BOOT))   ? m_rready : 1'b0;

endmodule