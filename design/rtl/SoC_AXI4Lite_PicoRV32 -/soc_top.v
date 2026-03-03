`include "soc_addr_map.vh"

module soc_top #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer RAM_BYTES_REQ = 64*1024,
    parameter integer REG_COUNT_PER_PORT = 64
)(
    input  wire aclk,
    input  wire aresetn,

    // BOOT control
    input  wire boot_pin,

    // SPI EEPROM pins
    output wire spi_csn,
    output wire spi_sclk,
    output wire spi_mosi,
    input  wire spi_miso,

    // UART
    input  wire uart_rx,
    output wire uart_tx,

    // GPIO (Exemplo: 5 in, 30 out conforme seu IP)
    input  wire [4:0]  gpio_i,
    output wire [29:0] gpio_o,

    // SPI
    output wire spi_sclk_o,
    output wire spi_mosi_o,
    input  wire spi_miso_i,
    output wire spi_ss_n_o,// Chip Select

    // I2C (Tri-state requires inout)
    inout  wire i2c_sda,
    inout  wire i2c_scl,

    // Debug / IRQ Monitor
    output wire trap
);

    // -----------------------------------------------------------
    // 1. Declaração de todos os wires AXI 
    // -----------------------------------------------------------
    
    // CPU AXI master wires
    wire cpu_awvalid, cpu_awready;  wire [ADDR_WIDTH-1:0] cpu_awaddr;   wire [2:0]                cpu_awprot;
    wire cpu_wvalid, cpu_wready;    wire [DATA_WIDTH-1:0] cpu_wdata;    wire [(DATA_WIDTH/8)-1:0] cpu_wstrb;
    wire cpu_bvalid, cpu_bready;
    wire cpu_arvalid, cpu_arready;  wire [ADDR_WIDTH-1:0] cpu_araddr;   wire [2:0]                cpu_arprot;
    wire cpu_rvalid, cpu_rready;    wire [DATA_WIDTH-1:0] cpu_rdata;
    wire cpu_resetn;

    // BOOT master AXI wires
    wire boot_awvalid, boot_awready;    wire [ADDR_WIDTH-1:0] boot_awaddr;  wire [2:0]                boot_awprot;
    wire boot_wvalid, boot_wready;      wire [DATA_WIDTH-1:0] boot_wdata;   wire [(DATA_WIDTH/8)-1:0] boot_wstrb;
    wire boot_bvalid, boot_bready;
    wire boot_arvalid, boot_arready;    wire [ADDR_WIDTH-1:0] boot_araddr;  wire [2:0]                boot_arprot;
    wire boot_rvalid, boot_rready;      wire [DATA_WIDTH-1:0] boot_rdata;
    wire boot_done, boot_error, boot_active;

    // ROOT SLAVES wires: MEM / PERIPH / BOOT
    // S0 MEM
    wire mem_awvalid; wire mem_awready; wire [31:0] mem_awaddr; wire [2:0] mem_awprot;
    wire mem_wvalid;  wire mem_wready;  wire [31:0] mem_wdata;  wire [3:0] mem_wstrb;
    wire mem_bvalid;  wire mem_bready;
    wire mem_arvalid; wire mem_arready; wire [31:0] mem_araddr; wire [2:0] mem_arprot;
    wire mem_rvalid;  wire mem_rready;  wire [31:0] mem_rdata;

    // S1 PERIPH
    wire per_awvalid; wire per_awready; wire [31:0] per_awaddr; wire [2:0] per_awprot;
    wire per_wvalid;  wire per_wready;  wire [31:0] per_wdata;  wire [3:0] per_wstrb;
    wire per_bvalid;  wire per_bready;
    wire per_arvalid; wire per_arready; wire [31:0] per_araddr; wire [2:0] per_arprot;
    wire per_rvalid;  wire per_rready;  wire [31:0] per_rdata;

    // S2 BOOT (SPI bridge)
    wire boot_s_awvalid; wire boot_s_awready; wire [31:0] boot_s_awaddr; wire [2:0] boot_s_awprot;
    wire boot_s_wvalid;  wire boot_s_wready;  wire [31:0] boot_s_wdata;  wire [3:0] boot_s_wstrb;
    wire boot_s_bvalid;  wire boot_s_bready;
    wire boot_s_arvalid; wire boot_s_arready; wire [31:0] boot_s_araddr; wire [2:0] boot_s_arprot;
    wire boot_s_rvalid;  wire boot_s_rready;  wire [31:0] boot_s_rdata;

    // 1x6 outputs -> 6 slaves inputs
    wire [ADDR_WIDTH-1:0]     axi_gpio_awaddr,  axi_timer_awaddr,  axi_uart_awaddr,  axi_spi_awaddr,  axi_i2c_awaddr,  axi_intc_awaddr;
    wire                      axi_gpio_awvalid, axi_timer_awvalid, axi_uart_awvalid, axi_spi_awvalid, axi_i2c_awvalid, axi_intc_awvalid;
    wire                      axi_gpio_awready, axi_timer_awready, axi_uart_awready, axi_spi_awready, axi_i2c_awready, axi_intc_awready;
    wire [DATA_WIDTH-1:0]     axi_gpio_wdata,   axi_timer_wdata,   axi_uart_wdata,   axi_spi_wdata,   axi_i2c_wdata,   axi_intc_wdata;
    wire [(DATA_WIDTH/8)-1:0] axi_gpio_wstrb,   axi_timer_wstrb,   axi_uart_wstrb,   axi_spi_wstrb,   axi_i2c_wstrb,   axi_intc_wstrb;
    wire                      axi_gpio_wvalid,  axi_timer_wvalid,  axi_uart_wvalid,  axi_spi_wvalid,  axi_i2c_wvalid,  axi_intc_wvalid;
    wire                      axi_gpio_wready,  axi_timer_wready,  axi_uart_wready,  axi_spi_wready,  axi_i2c_wready,  axi_intc_wready;
    wire [1:0]                axi_gpio_bresp,   axi_timer_bresp,   axi_uart_bresp,   axi_spi_bresp,   axi_i2c_bresp,   axi_intc_bresp;
    wire                      axi_gpio_bvalid,  axi_timer_bvalid,  axi_uart_bvalid,  axi_spi_bvalid,  axi_i2c_bvalid,  axi_intc_bvalid;
    wire                      axi_gpio_bready,  axi_timer_bready,  axi_uart_bready,  axi_spi_bready,  axi_i2c_bready,  axi_intc_bready;
    wire [ADDR_WIDTH-1:0]     axi_gpio_araddr,  axi_timer_araddr,  axi_uart_araddr,  axi_spi_araddr,  axi_i2c_araddr,  axi_intc_araddr;
    wire                      axi_gpio_arvalid, axi_timer_arvalid, axi_uart_arvalid, axi_spi_arvalid, axi_i2c_arvalid, axi_intc_arvalid;
    wire                      axi_gpio_arready, axi_timer_arready, axi_uart_arready, axi_spi_arready, axi_i2c_arready, axi_intc_arready;
    wire [DATA_WIDTH-1:0]     axi_gpio_rdata,   axi_timer_rdata,   axi_uart_rdata,   axi_spi_rdata,   axi_i2c_rdata,   axi_intc_rdata;
    wire [1:0]                axi_gpio_rresp,   axi_timer_rresp,   axi_uart_rresp,   axi_spi_rresp,   axi_i2c_rresp,   axi_intc_rresp;
    wire                      axi_gpio_rvalid,  axi_timer_rvalid,  axi_uart_rvalid,  axi_spi_rvalid,  axi_i2c_rvalid,  axi_intc_rvalid;
    wire                      axi_gpio_rready,  axi_timer_rready,  axi_uart_rready,  axi_spi_rready,  axi_i2c_rready,  axi_intc_rready;

    // I2C - Sinais internos para lidar com o Tri-state
    wire scl_i, scl_o, scl_t;
    wire sda_i, sda_o, sda_t;

    // IRQs
    wire [4:0] irq_sources; // 5 fontes de IRQ: GPIO, TIMER, UART, SPI, I2C
    wire gpio_irq, timer_irq, uart_irq, spi_irq, i2c_irq;
    wire cpu_global_irq;


    // -----------------------------------------------------------
    // 2. Instância do PicoRV32
    // -----------------------------------------------------------
    picorv32_axi #(
        .PROGADDR_RESET(32'h0000_0000),
        .PROGADDR_IRQ  (32'h0000_0010),
        .BARREL_SHIFTER(1),
        .ENABLE_MUL(1),
        .ENABLE_DIV(1)
    ) u_cpu (
        .clk            (aclk),
        .resetn         (cpu_resetn),
        .trap           (trap),
        .irq            (cpu_global_irq),
        .mem_axi_awvalid(cpu_awvalid),  .mem_axi_awready(cpu_awready),  .mem_axi_awaddr (cpu_awaddr),   .mem_axi_awprot (cpu_awprot),
        .mem_axi_wvalid (cpu_wvalid),   .mem_axi_wready (cpu_wready),   .mem_axi_wdata  (cpu_wdata),    .mem_axi_wstrb  (cpu_wstrb),
        .mem_axi_bvalid (cpu_bvalid),   .mem_axi_bready (cpu_bready),
        .mem_axi_arvalid(cpu_arvalid),  .mem_axi_arready(cpu_arready),  .mem_axi_araddr (cpu_araddr),   .mem_axi_arprot (cpu_arprot),
        .mem_axi_rvalid (cpu_rvalid),   .mem_axi_rready (cpu_rready),   .mem_axi_rdata  (cpu_rdata)
    );

    // -----------------------------------------------------------
    // 3. Interconnect Principal (Root)
    // -----------------------------------------------------------
    axi_interconnect_root #(
        .S0_BASE(`AXI_MEM_REGION_BASE),    .S0_MASK(`AXI_MEM_REGION_MASK),
        .S1_BASE(`AXI_PERIPH_REGION_BASE), .S1_MASK(`AXI_PERIPH_REGION_MASK),
        .S2_BASE(`AXI_BOOT_REGION_BASE),   .S2_MASK(`AXI_BOOT_REGION_MASK)
    ) u_root_ic (
        .clk        (aclk),
        .resetn     (aresetn),
        .boot_active(boot_active), 

        // CPU master
        .cpu_awvalid(cpu_awvalid), .cpu_awready(cpu_awready), .cpu_awaddr (cpu_awaddr), .cpu_awprot (cpu_awprot),
        .cpu_wvalid (cpu_wvalid),  .cpu_wready (cpu_wready),  .cpu_wdata  (cpu_wdata),  .cpu_wstrb  (cpu_wstrb),
        .cpu_bvalid (cpu_bvalid),  .cpu_bready (cpu_bready),
        .cpu_arvalid(cpu_arvalid), .cpu_arready(cpu_arready), .cpu_araddr (cpu_araddr), .cpu_arprot (cpu_arprot),
        .cpu_rvalid (cpu_rvalid),  .cpu_rready (cpu_rready),  .cpu_rdata  (cpu_rdata),

        // BOOT master
        .boot_awvalid(boot_awvalid), .boot_awready(boot_awready), .boot_awaddr (boot_awaddr), .boot_awprot (boot_awprot),
        .boot_wvalid (boot_wvalid),  .boot_wready (boot_wready),  .boot_wdata  (boot_wdata),  .boot_wstrb  (boot_wstrb),
        .boot_bvalid (boot_bvalid),  .boot_bready (boot_bready),
        .boot_arvalid(boot_arvalid), .boot_arready(boot_arready), .boot_araddr (boot_araddr), .boot_arprot (boot_arprot),
        .boot_rvalid (boot_rvalid),  .boot_rready (boot_rready),  .boot_rdata  (boot_rdata),

        // Slave 0 MEM
        .s0_awvalid(mem_awvalid), .s0_awready(mem_awready), .s0_awaddr (mem_awaddr), .s0_awprot (mem_awprot),
        .s0_wvalid (mem_wvalid),  .s0_wready (mem_wready),  .s0_wdata  (mem_wdata),  .s0_wstrb  (mem_wstrb),
        .s0_bvalid (mem_bvalid),  .s0_bready (mem_bready),
        .s0_arvalid(mem_arvalid), .s0_arready(mem_arready), .s0_araddr (mem_araddr), .s0_arprot (mem_arprot),
        .s0_rvalid (mem_rvalid),  .s0_rready (mem_rready),  .s0_rdata  (mem_rdata),

        // Slave 1 PERIPH
        .s1_awvalid(per_awvalid), .s1_awready(per_awready), .s1_awaddr (per_awaddr), .s1_awprot (per_awprot),
        .s1_wvalid (per_wvalid),  .s1_wready (per_wready),  .s1_wdata  (per_wdata),  .s1_wstrb  (per_wstrb),
        .s1_bvalid (per_bvalid),  .s1_bready (per_bready),
        .s1_arvalid(per_arvalid), .s1_arready(per_arready), .s1_araddr (per_araddr), .s1_arprot (per_arprot),
        .s1_rvalid (per_rvalid),  .s1_rready (per_rready),  .s1_rdata  (per_rdata),

        // Slave 2 BOOT
        .s2_awvalid(boot_s_awvalid), .s2_awready(boot_s_awready), .s2_awaddr (boot_s_awaddr), .s2_awprot (boot_s_awprot),
        .s2_wvalid (boot_s_wvalid),  .s2_wready (boot_s_wready),  .s2_wdata  (boot_s_wdata),  .s2_wstrb  (boot_s_wstrb),
        .s2_bvalid (boot_s_bvalid),  .s2_bready (boot_s_bready),
        .s2_arvalid(boot_s_arvalid), .s2_arready(boot_s_arready), .s2_araddr (boot_s_araddr), .s2_arprot (boot_s_arprot),
        .s2_rvalid (boot_s_rvalid),  .s2_rready (boot_s_rready),  .s2_rdata  (boot_s_rdata)
    );

    // -----------------------------------------------------------
    // 4. Memórias e Boot
    // -----------------------------------------------------------
    
    // MEM: AXI-Lite RAM
    axi_mem_ram #(
        .MEM_BYTES_REQ(RAM_BYTES_REQ),
        .BASE_ADDR(`AXI_RAM_BASE),
        .INIT_FILE("")   // bootloader vai carregar via EEPROM
    ) u_ram (
        .clk    (aclk),
        .resetn (aresetn),

        .awvalid(mem_awvalid), .awready(mem_awready), .awaddr (mem_awaddr), .awprot (mem_awprot),
        .wvalid (mem_wvalid),  .wready (mem_wready),  .wdata  (mem_wdata),  .wstrb  (mem_wstrb),
        .bvalid (mem_bvalid),  .bready (mem_bready),
        .arvalid(mem_arvalid), .arready(mem_arready), .araddr (mem_araddr), .arprot (mem_arprot),
        .rvalid (mem_rvalid),  .rready (mem_rready),  .rdata  (mem_rdata)
    );

    // BOOTLOADER (reads SPI window via AXI, writes RAM)
    axi_bootloader_memcpy #(
        .WORDS(256),
        .SRC_BASE (`AXI_SPI_BOOT_BASE),
        .DEST_BASE(`AXI_RAM_BASE)
    ) u_boot (
        .clk     (aclk),
        .resetn  (aresetn),
        .boot_pin(boot_pin),

        .m_awaddr (boot_awaddr), .m_awvalid(boot_awvalid), .m_awready(boot_awready), .m_awprot (boot_awprot),
        .m_wdata  (boot_wdata),  .m_wstrb  (boot_wstrb),   .m_wvalid (boot_wvalid),  .m_wready (boot_wready),
        .m_bvalid (boot_bvalid), .m_bready (boot_bready),
        .m_araddr (boot_araddr), .m_arvalid(boot_arvalid), .m_arready(boot_arready), .m_arprot (boot_arprot),
        .m_rvalid (boot_rvalid), .m_rready (boot_rready),  .m_rdata  (boot_rdata),

        .done (boot_done),
        .error(boot_error)
    );

    // BOOT REGION SLAVE: AXI -> SPI EEPROM bridge
    axi_spi_eeprom_bridge #(
        .CLK_DIV(4)
    ) u_spi_boot (
        .aclk    (aclk),
        .aresetn (aresetn),

        .s_axi_awaddr (boot_s_awaddr), .s_axi_awvalid(boot_s_awvalid), .s_axi_awready(boot_s_awready),
        .s_axi_wdata  (boot_s_wdata),  .s_axi_wstrb  (boot_s_wstrb),   .s_axi_wvalid (boot_s_wvalid),  .s_axi_wready (boot_s_wready),
        .s_axi_bvalid (boot_s_bvalid), .s_axi_bready (boot_s_bready),  .s_axi_bresp  (),
        .s_axi_araddr (boot_s_araddr), .s_axi_arvalid(boot_s_arvalid), .s_axi_arready(boot_s_arready), 
        .s_axi_rvalid (boot_s_rvalid), .s_axi_rready (boot_s_rready),  .s_axi_rdata  (boot_s_rdata),   .s_axi_rresp  (),
        
        .spi_csn (spi_csn),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // -----------------------------------------------------------
    // 5. Interconnect de Periféricos
    // -----------------------------------------------------------
    axi_interconnect_periph #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),

        .SLV0_BASE(`AXI_GPIO_BASE), .SLV0_MASK(`AXI_GPIO_MASK),
        .SLV1_BASE(`AXI_TIMER_BASE),.SLV1_MASK(`AXI_TIMER_MASK),
        .SLV2_BASE(`AXI_UART_BASE), .SLV2_MASK(`AXI_UART_MASK),
        .SLV3_BASE(`AXI_SPI_BASE),  .SLV3_MASK(`AXI_SPI_MASK),
        .SLV4_BASE(`AXI_I2C_BASE),  .SLV4_MASK(`AXI_I2C_MASK),
        .SLV5_BASE(`AXI_INTR_BASE), .SLV5_MASK(`AXI_INTR_MASK)
    ) u_periph_xbar (
        .aclk   (aclk),
        .aresetn(aresetn),

        .s_axi_awaddr (per_awaddr), .s_axi_awvalid (per_awvalid), .s_axi_awready (per_awready), 
        .s_axi_wdata  (per_wdata),  .s_axi_wstrb   (per_wstrb),   .s_axi_wvalid  (per_wvalid),  .s_axi_wready (per_wready),
        .s_axi_bvalid (per_bvalid), .s_axi_bready  (per_bready),  .s_axi_bresp   (),
        .s_axi_araddr (per_araddr), .s_axi_arvalid (per_arvalid), .s_axi_arready (per_arready),
        .s_axi_rdata  (per_rdata),  .s_axi_rvalid  (per_rvalid),  .s_axi_rready  (per_rready),  .s_axi_rresp  (),

        .m0_axi_awaddr (axi_gpio_awaddr),  .m0_axi_awvalid(axi_gpio_awvalid), .m0_axi_awready(axi_gpio_awready),
        .m0_axi_wdata  (axi_gpio_wdata),   .m0_axi_wstrb  (axi_gpio_wstrb),   .m0_axi_wvalid(axi_gpio_wvalid), .m0_axi_wready(axi_gpio_wready),
        .m0_axi_bresp  (axi_gpio_bresp),   .m0_axi_bvalid (axi_gpio_bvalid),  .m0_axi_bready(axi_gpio_bready),
        .m0_axi_araddr (axi_gpio_araddr),  .m0_axi_arvalid(axi_gpio_arvalid), .m0_axi_arready(axi_gpio_arready),
        .m0_axi_rdata  (axi_gpio_rdata),   .m0_axi_rresp  (axi_gpio_rresp),   .m0_axi_rvalid(axi_gpio_rvalid), .m0_axi_rready(axi_gpio_rready),

        .m1_axi_awaddr (axi_timer_awaddr),  .m1_axi_awvalid(axi_timer_awvalid), .m1_axi_awready(axi_timer_awready),
        .m1_axi_wdata  (axi_timer_wdata),   .m1_axi_wstrb  (axi_timer_wstrb),   .m1_axi_wvalid(axi_timer_wvalid), .m1_axi_wready(axi_timer_wready),
        .m1_axi_bresp  (axi_timer_bresp),   .m1_axi_bvalid (axi_timer_bvalid),  .m1_axi_bready(axi_timer_bready),
        .m1_axi_araddr (axi_timer_araddr),  .m1_axi_arvalid(axi_timer_arvalid), .m1_axi_arready(axi_timer_arready),
        .m1_axi_rdata  (axi_timer_rdata),   .m1_axi_rresp  (axi_timer_rresp),   .m1_axi_rvalid(axi_timer_rvalid), .m1_axi_rready(axi_timer_rready),

        .m2_axi_awaddr (axi_uart_awaddr),  .m2_axi_awvalid(axi_uart_awvalid), .m2_axi_awready(axi_uart_awready),
        .m2_axi_wdata  (axi_uart_wdata),   .m2_axi_wstrb  (axi_uart_wstrb),   .m2_axi_wvalid(axi_uart_wvalid), .m2_axi_wready(axi_uart_wready),
        .m2_axi_bresp  (axi_uart_bresp),   .m2_axi_bvalid (axi_uart_bvalid),  .m2_axi_bready(axi_uart_bready),
        .m2_axi_araddr (axi_uart_araddr),  .m2_axi_arvalid(axi_uart_arvalid), .m2_axi_arready(axi_uart_arready),
        .m2_axi_rdata  (axi_uart_rdata),   .m2_axi_rresp  (axi_uart_rresp),   .m2_axi_rvalid(axi_uart_rvalid), .m2_axi_rready(axi_uart_rready),

        .m3_axi_awaddr (axi_spi_awaddr),  .m3_axi_awvalid(axi_spi_awvalid), .m3_axi_awready(axi_spi_awready),
        .m3_axi_wdata  (axi_spi_wdata),   .m3_axi_wstrb  (axi_spi_wstrb),   .m3_axi_wvalid(axi_spi_wvalid), .m3_axi_wready(axi_spi_wready),
        .m3_axi_bresp  (axi_spi_bresp),   .m3_axi_bvalid (axi_spi_bvalid),  .m3_axi_bready(axi_spi_bready),
        .m3_axi_araddr (axi_spi_araddr),  .m3_axi_arvalid(axi_spi_arvalid), .m3_axi_arready(axi_spi_arready),
        .m3_axi_rdata  (axi_spi_rdata),   .m3_axi_rresp  (axi_spi_rresp),   .m3_axi_rvalid(axi_spi_rvalid), .m3_axi_rready(axi_spi_rready),

        .m4_axi_awaddr (axi_i2c_awaddr),  .m4_axi_awvalid(axi_i2c_awvalid), .m4_axi_awready(axi_i2c_awready),
        .m4_axi_wdata  (axi_i2c_wdata),   .m4_axi_wstrb  (axi_i2c_wstrb),   .m4_axi_wvalid(axi_i2c_wvalid), .m4_axi_wready(axi_i2c_wready),
        .m4_axi_bresp  (axi_i2c_bresp),   .m4_axi_bvalid (axi_i2c_bvalid),  .m4_axi_bready(axi_i2c_bready),
        .m4_axi_araddr (axi_i2c_araddr),  .m4_axi_arvalid(axi_i2c_arvalid), .m4_axi_arready(axi_i2c_arready),
        .m4_axi_rdata  (axi_i2c_rdata),   .m4_axi_rresp  (axi_i2c_rresp),   .m4_axi_rvalid(axi_i2c_rvalid), .m4_axi_rready(axi_i2c_rready),

        .m5_axi_awaddr (axi_intc_awaddr),  .m5_axi_awvalid(axi_intc_awvalid), .m5_axi_awready(axi_intc_awready),
        .m5_axi_wdata  (axi_intc_wdata),   .m5_axi_wstrb  (axi_intc_wstrb),   .m5_axi_wvalid(axi_intc_wvalid), .m5_axi_wready(axi_intc_wready),
        .m5_axi_bresp  (axi_intc_bresp),   .m5_axi_bvalid (axi_intc_bvalid),  .m5_axi_bready(axi_intc_bready),
        .m5_axi_araddr (axi_intc_araddr),  .m5_axi_arvalid(axi_intc_arvalid), .m5_axi_arready(axi_intc_arready),
        .m5_axi_rdata  (axi_intc_rdata),   .m5_axi_rresp  (axi_intc_rresp),   .m5_axi_rvalid(axi_intc_rvalid), .m5_axi_rready(axi_intc_rready)
    );


    // -----------------------------------------------------------
    // 6. Instância INDIVIDUAL dos Periféricos
    // -----------------------------------------------------------

    // GPIO (Porta 0 - Base 0x4000_0000)
    axilgpio #(
        .C_AXI_ADDR_WIDTH(5),  // Endereçamento interno pequeno
        .NOUT(30),             // 30 Saídas
        .NIN(5)                // 5 Entradas
    ) u_gpio (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        // Conexões AXI (Vindas do x_m0 do Interconnect 1x6)
        .S_AXI_AWVALID (axi_gpio_awvalid), .S_AXI_AWREADY (axi_gpio_awready), .S_AXI_AWADDR  (axi_gpio_awaddr[5-1:0]), // Truncamos o endereço para [4:0]
        //.S_AXI_AWPROT  (axi_gpio_awprot),
        .S_AXI_WVALID  (axi_gpio_wvalid),  .S_AXI_WREADY  (axi_gpio_wready),  .S_AXI_WDATA   (axi_gpio_wdata),         .S_AXI_WSTRB   (axi_gpio_wstrb),
        .S_AXI_BVALID  (axi_gpio_bvalid),  .S_AXI_BREADY  (axi_gpio_bready),  .S_AXI_BRESP   (axi_gpio_bresp),
        .S_AXI_ARVALID (axi_gpio_arvalid), .S_AXI_ARREADY (axi_gpio_arready), .S_AXI_ARADDR  (axi_gpio_araddr[5-1:0]), // Truncamos o endereço para [4:0]
        //.S_AXI_ARPROT  (axi_gpio_arprot), 
        .S_AXI_RVALID  (axi_gpio_rvalid),  .S_AXI_RREADY  (axi_gpio_rready),  .S_AXI_RDATA   (axi_gpio_rdata),         .S_AXI_RRESP   (axi_gpio_rresp),

        // Pinos Físicos
        .i_gpio (gpio_i),
        .o_gpio (gpio_o),
        .o_int  (gpio_irq) 
    );

    // TIMER (Porta 1 - Base 0x4000_1000)
    timer u_timer (
        .clk_i          (aclk),
        .rst_i          (!aresetn),
        .intr_o         (timer_irq),

        .cfg_awvalid_i  (axi_timer_awvalid), .cfg_awaddr_i(axi_timer_awaddr), .cfg_awready_o(axi_timer_awready),
        .cfg_wvalid_i   (axi_timer_wvalid),  .cfg_wdata_i (axi_timer_wdata),  .cfg_wstrb_i (axi_timer_wstrb),    .cfg_wready_o(axi_timer_wready),
        .cfg_bvalid_o   (axi_timer_bvalid),  .cfg_bready_i(axi_timer_bready), .cfg_bresp_o (axi_timer_bresp),
        .cfg_arvalid_i  (axi_timer_arvalid), .cfg_araddr_i(axi_timer_araddr), .cfg_arready_o(axi_timer_arready),
        .cfg_rvalid_o   (axi_timer_rvalid),  .cfg_rdata_o (axi_timer_rdata),  .cfg_rresp_o (axi_timer_rresp),    .cfg_rready_i(axi_timer_rready)
    );

     // UART LITE (Porta 2 - Base 0x4000_2000)
    uart_lite u_uart (
        .clk_i          (aclk),
        .rst_i          (!aresetn),

        .rx_i           (uart_rx),
        .tx_o           (uart_tx),
        .intr_o         (uart_irq),

        .cfg_awvalid_i(axi_uart_awvalid), .cfg_awaddr_i(axi_uart_awaddr), .cfg_awready_o(axi_uart_awready),
        .cfg_wvalid_i (axi_uart_wvalid),  .cfg_wdata_i (axi_uart_wdata),  .cfg_wstrb_i (axi_uart_wstrb),    .cfg_wready_o(axi_uart_wready),
        .cfg_bvalid_o (axi_uart_bvalid),  .cfg_bready_i(axi_uart_bready), .cfg_bresp_o (axi_uart_bresp),
        .cfg_arvalid_i(axi_uart_arvalid), .cfg_araddr_i(axi_uart_araddr), .cfg_arready_o(axi_uart_arready),
        .cfg_rvalid_o (axi_uart_rvalid),  .cfg_rdata_o (axi_uart_rdata),  .cfg_rresp_o (axi_uart_rresp),    .cfg_rready_i(axi_uart_rready)
    );


    // SPI MASTER (Porta 3 - Base 0x4000_3000)
    spi_master_axil #(
        .NUM_SS_BITS(1),    // 1 chip select
        .FIFO_EXIST(1),     // Habilita a FIFO
        .FIFO_DEPTH(16),    // Tamanho do buffer (16 palavras)
        .AXIL_ADDR_WIDTH(ADDR_WIDTH) // Endereçamento do barramento
    ) u_spi (
        .clk            (aclk),
        .rst            (!aresetn), // Atenção: Este módulo usa Reset ATIVO ALTO
        .irq            (spi_irq),

        // Conexão AXI-Lite (Vinda do Interconnect Porta 3)
        .s_axil_awaddr  (axi_spi_awaddr), .s_axil_awvalid (axi_spi_awvalid), .s_axil_awready (axi_spi_awready), //.s_axil_awprot  (axi_spi_awprot),
        .s_axil_wdata   (axi_spi_wdata),  .s_axil_wstrb   (axi_spi_wstrb),   .s_axil_wvalid  (axi_spi_wvalid),  .s_axil_wready  (axi_spi_wready),
        .s_axil_bresp   (axi_spi_bresp),  .s_axil_bvalid  (axi_spi_bvalid),  .s_axil_bready  (axi_spi_bready),
        .s_axil_araddr  (axi_spi_araddr), .s_axil_arvalid (axi_spi_arvalid), .s_axil_arready (axi_spi_arready), //.s_axil_arprot  (axi_spi_arprot),
        .s_axil_rdata   (axi_spi_rdata),  .s_axil_rresp   (axi_spi_rresp),   .s_axil_rvalid  (axi_spi_rvalid),   .s_axil_rready  (axi_spi_rready),

        // Interface Física SPI
        .spi_sclk_o         (spi_sclk_o),
        .spi_mosi_o         (spi_mosi_o),
        .spi_miso           (spi_miso_i),
        .spi_ncs_o          (spi_ss_n_o)  // Chip Select (Ativo Baixo)
    );


    // I2C MASTER (Porta 4 - Base 0x4000_4000)
    i2c_master_axil #(
        .DEFAULT_PRESCALE(1), // Configura velocidade (ajustável via software depois)
        .FIXED_PRESCALE(0),
        .CMD_FIFO(1),         // Habilita FIFO de comandos
        .CMD_FIFO_DEPTH(32),
        .WRITE_FIFO(1),
        .WRITE_FIFO_DEPTH(32),
        .READ_FIFO(1),
        .READ_FIFO_DEPTH(32)
    ) u_i2c (
        .clk(aclk),
        .rst(!aresetn), // <--- (Módulo usa Ativo Alto)
        //.irq(i2c_irq),

        // Conexão AXI-Lite (Porta 4)
        .s_axil_awaddr  (axi_i2c_awaddr), .s_axil_awvalid (axi_i2c_awvalid), .s_axil_awready (axi_i2c_awready), //.s_axil_awprot  (axi_i2c_awprot),        
        .s_axil_wdata   (axi_i2c_wdata),  .s_axil_wstrb   (axi_i2c_wstrb),   .s_axil_wvalid  (axi_i2c_wvalid),  .s_axil_wready  (axi_i2c_wready),
        .s_axil_bresp   (axi_i2c_bresp),  .s_axil_bvalid  (axi_i2c_bvalid),  .s_axil_bready  (axi_i2c_bready),
        .s_axil_araddr  (axi_i2c_araddr), .s_axil_arvalid (axi_i2c_arvalid), .s_axil_arready (axi_i2c_arready), //.s_axil_arprot  (axi_i2c_arprot),
        .s_axil_rdata   (axi_i2c_rdata),  .s_axil_rresp   (axi_i2c_rresp),   .s_axil_rvalid  (axi_i2c_rvalid),  .s_axil_rready  (axi_i2c_rready),

        // Sinais Internos (IOBUF)
        .i2c_scl_i(scl_i), .i2c_scl_o(scl_o), .i2c_scl_t(scl_t),
        .i2c_sda_i(sda_i), .i2c_sda_o(sda_o), .i2c_sda_t(sda_t)
    );
    assign i2c_irq = 1'b0; // Desabilita temporariamente a interrupção do I2C

    // --- LÓGICA TRI-STATE (IO BUFFERS) ---
    // O I2C funciona como Open-Drain:
    // Se o IP quer enviar '0' (scl_o=0 e scl_t=0), forçamos 0.
    // Em qualquer outro caso (IP quer enviar '1' ou está lendo), deixamos Z.
    
    assign i2c_scl = (scl_t || scl_o) ? 1'bz : 1'b0; 
    assign scl_i   = i2c_scl;

    assign i2c_sda = (sda_t || sda_o) ? 1'bz : 1'b0;
    assign sda_i   = i2c_sda;


    // INTERRUPT CONTROLLER (Porta 5 - Base 0x4000_5000)

    // Vetor de Interrupções
    // Organizado sequencialmente: GPIO(0), Timer(1), UART(2), SPI(3), I2C(4)
    // -------------------------------------------------------------------------
    // Instância do Ultra-Embedded IRQ Controller (Customizado para 5 IRQs)
    irq_ctrl u_intc (
        .clk_i          (aclk),
        .rst_i          (!aresetn),      // Inversão: SoC (Baixo) -> Módulo (Alto) 

        // Entradas de Interrupção Mapeadas
        .interrupt0_i   (gpio_irq),      // Bit 0
        .interrupt1_i   (timer_irq),     // Bit 1
        .interrupt2_i   (uart_irq),      // Bit 2
        .interrupt3_i   (spi_irq),       // Bit 3
        .interrupt4_i   (i2c_irq),       // Bit 4

        // Interface AXI-Lite [cite: 58, 62]
        .cfg_awvalid_i  (axi_intc_awvalid),
        .cfg_awaddr_i   (axi_intc_awaddr),
        .cfg_awready_o  (axi_intc_awready),
        .cfg_wvalid_i   (axi_intc_wvalid),
        .cfg_wdata_i    (axi_intc_wdata),
        .cfg_wstrb_i    (axi_intc_wstrb),
        .cfg_wready_o   (axi_intc_wready),
        .cfg_bvalid_o   (axi_intc_bvalid),
        .cfg_bready_i   (axi_intc_bready),
        .cfg_bresp_o    (axi_intc_bresp),
        .cfg_arvalid_i  (axi_intc_arvalid),
        .cfg_araddr_i   (axi_intc_araddr),
        .cfg_arready_o  (axi_intc_arready),
        .cfg_rvalid_o   (axi_intc_rvalid),
        .cfg_rdata_o    (axi_intc_rdata),
        .cfg_rresp_o    (axi_intc_rresp),
        .cfg_rready_i   (axi_intc_rready),

        // Saída Global 
        .intr_o         (cpu_global_irq)
    );

    // BOOT control / CPU reset gating
    // Boot domina o barramento somente enquanto estiver copiando.
    assign boot_active = boot_pin & ~boot_done;
    // CPU fica em reset enquanto o boot está copiando.
    // - Se boot_pin=0: CPU roda normal.
    // - Se boot_pin=1: CPU só sai do reset quando boot_done=1.
    assign cpu_resetn = aresetn & (~boot_pin | boot_done);

endmodule



/*
    // INTERRUPT CONTROLLER (Porta 5 - Base 0x4000_5000)

    // Vetor de Interrupções
    // Organizado sequencialmente: GPIO(0), Timer(1), UART(2), SPI(3), I2C(4)
    // -------------------------------------------------------------------------
    assign irq_sources = {
        i2c_irq,     // Bit 4: I2C
        spi_irq,     // Bit 3: SPI
        uart_irq,    // Bit 2: UART
        timer_irq,   // Bit 1: Timer
        gpio_irq     // Bit 0: GPIO
    };

    axil_intc #(
        .IRQ_WIDTH(5) // 5 fontes de IRQ
    ) u_intc (
        .S_AXI_ACLK    (aclk),
        .S_AXI_ARESETN (aresetn),

        // Conexão AXI-Lite (Porta 5)
        .S_AXI_AWADDR  (axi_intc_awaddr), .S_AXI_AWVALID (axi_intc_awvalid), .S_AXI_AWREADY (axi_intc_awready), //.S_AXI_AWPROT  (axi_intc_awprot),
        .S_AXI_WDATA   (axi_intc_wdata),  .S_AXI_WSTRB   (axi_intc_wstrb),   .S_AXI_WVALID  (axi_intc_wvalid),  .S_AXI_WREADY  (axi_intc_wready),
        .S_AXI_BRESP   (axi_intc_bresp),  .S_AXI_BVALID  (axi_intc_bvalid),  .S_AXI_BREADY  (axi_intc_bready),
        .S_AXI_ARADDR  (axi_intc_araddr), .S_AXI_ARVALID (axi_intc_arvalid), .S_AXI_ARREADY (axi_intc_arready), //.S_AXI_ARPROT  (axi_intc_arprot),
        .S_AXI_RDATA   (axi_intc_rdata),  .S_AXI_RRESP   (axi_intc_rresp),   .S_AXI_RVALID  (axi_intc_rvalid),  .S_AXI_RREADY  (axi_intc_rready),

        // Sinais de Interrupção
        .irq_inputs_i  (irq_sources),
        .irq_output_o  (cpu_global_irq)
    );
*/