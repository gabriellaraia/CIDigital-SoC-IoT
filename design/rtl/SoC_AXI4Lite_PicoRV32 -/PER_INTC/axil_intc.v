module axil_intc #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer IRQ_WIDTH = 5
)(
    input  wire                                  S_AXI_ACLK,
    input  wire                                  S_AXI_ARESETN,
    // Interface AXI-Lite Slave
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_AWADDR,
    input  wire                                  S_AXI_AWVALID,
    output wire                                  S_AXI_AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0]       S_AXI_WSTRB,
    input  wire                                  S_AXI_WVALID,
    output wire                                  S_AXI_WREADY,
    output wire [1:0]                            S_AXI_BRESP,
    output wire                                  S_AXI_BVALID,
    input  wire                                  S_AXI_BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]         S_AXI_ARADDR,
    input  wire                                  S_AXI_ARVALID,
    output wire                                  S_AXI_ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0]         S_AXI_RDATA,
    output wire [1:0]                            S_AXI_RRESP,
    output wire                                  S_AXI_RVALID,
    input  wire                                  S_AXI_RREADY,
    // Interrupções
    input  wire [IRQ_WIDTH-1:0]                  irq_inputs_i,
    output wire                                  irq_output_o
);

    // ========================================
    // Registradores
    // ========================================
    reg [IRQ_WIDTH-1:0] irq_enable_reg;      // 0x00: Enable
    reg [IRQ_WIDTH-1:0] irq_polarity_reg;    // 0x04: Polaridade
    
    // Aplicar polarity (invert se necessário)
    wire [IRQ_WIDTH-1:0] irq_inputs_adj = irq_inputs_i ^ irq_polarity_reg;
    
    // ========================================
    // Sinais de controle AXI
    // ========================================
    reg axi_awready, axi_wready, axi_bvalid;
    reg axi_arready, axi_rvalid;
    reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;

    // ========================================
    // Lógica de Interrupção (Combinacional)
    // ========================================
    assign irq_output_o = |(irq_inputs_adj & irq_enable_reg);

    // ========================================
    // Máquina de Estados AXI-Lite
    // ========================================
    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            // Inicializar TODOS os sinais
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 32'h0;
            irq_enable_reg   <= 5'h0;
            irq_polarity_reg <= 5'h0;
        end else begin
            
            // ========== CANAL DE ESCRITA ==========
            // Write Address Channel
            if (S_AXI_AWVALID && S_AXI_WVALID && !axi_bvalid) begin
                // Aceita escrita quando ambos (AW e W) são válidos
                // e não há resposta pendente
                axi_awready <= 1'b1;
                axi_wready  <= 1'b1;
                
                // Escreve no registrador correto
                case (S_AXI_AWADDR[3:0])
                    4'h0: irq_enable_reg   <= S_AXI_WDATA[IRQ_WIDTH-1:0];
                    4'h4: irq_polarity_reg <= S_AXI_WDATA[IRQ_WIDTH-1:0];
                    default: ; // Ignore invalid addresses
                endcase
            end else begin
                axi_awready <= 1'b0;
                axi_wready  <= 1'b0;
            end

            // Write Response Channel
            if (axi_awready && axi_wready && S_AXI_AWVALID && S_AXI_WVALID) begin
                // Se escrita foi aceita, próximo ciclo gera resposta
                axi_bvalid <= 1'b1;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                // Limpa resposta quando host lê (BREADY=1)
                axi_bvalid <= 1'b0;
            end

            // ========== CANAL DE LEITURA ==========
            // Read Address Channel
            if (S_AXI_ARVALID && !axi_rvalid) begin
                // Aceita leitura quando há requisição e sem leitura pendente
                axi_arready <= 1'b1;
                
                // Lê registrador
                case (S_AXI_ARADDR[3:0])
                    4'h0: axi_rdata <= {{C_S_AXI_DATA_WIDTH-IRQ_WIDTH{1'b0}}, irq_enable_reg};
                    4'h4: axi_rdata <= {{C_S_AXI_DATA_WIDTH-IRQ_WIDTH{1'b0}}, irq_polarity_reg};
                    4'h8: axi_rdata <= {{C_S_AXI_DATA_WIDTH-IRQ_WIDTH{1'b0}}, (irq_inputs_adj & irq_enable_reg)};
                    default: axi_rdata <= 32'h0;
                endcase
            end else begin
                axi_arready <= 1'b0;
            end

            // Read Data Channel
            if (axi_arready && S_AXI_ARVALID) begin
                // Se leitura foi aceita, próximo ciclo gera dado
                axi_rvalid <= 1'b1;
            end else if (S_AXI_RREADY && axi_rvalid) begin
                // Limpa dado quando host lê (RREADY=1)
                axi_rvalid <= 1'b0;
            end
        end
    end

    // ========================================
    // Atribuições de Saída
    // ========================================
    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = 2'b00;  // OKAY response
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = 2'b00;  // OKAY response
    assign S_AXI_RVALID  = axi_rvalid;

endmodule