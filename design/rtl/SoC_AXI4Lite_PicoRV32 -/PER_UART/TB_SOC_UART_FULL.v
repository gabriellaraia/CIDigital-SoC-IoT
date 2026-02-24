`timescale 1ns / 1ps

// =============================================================================
// DESCRICAO: Testbench para SoC RISC-V com UART Lite (Versão Integrada)
//
// FUNCIONALIDADES:
// 1. Gera o arquivo "firmware.hex" na raiz do projeto (../firmware.hex).
// 2. Instancia o SoC completo (com CPU, RAM e UART internas).
// 3. Monitora pino TX da UART e exibe no console.
// =============================================================================

module tb_soc_uart_full;

    // =========================================================================
    // 1. CONFIGURACOES
    // =========================================================================
    
    // MODO_OPERACAO:
    // 0 = Gera o firmware.hex com a mensagem abaixo e roda.
    // 1 = Apenas roda (assume que o firmware.hex já existe e está correto).
    parameter MODO_OPERACAO = 0; 

    // MODO_EXIBICAO:
    // 0 = Tempo Real (Caractere por caractere).
    // 1 = Bufferizado (Frase completa no final).
    parameter MODO_EXIBICAO = 1;

    // Mensagem a ser enviada pelo PicoRV32 via UART
    reg [8*256:1] texto_msg = "Ola SoC RISC-V! Teste AXI-Lite OK.";

    // Clocks e Baud Rate
    localparam CLOCK_PERIOD = 10;          // 100 MHz
    localparam BIT_TIME     = 25 * CLOCK_PERIOD; // Divisor fixo em 24+1 (ver uart_lite.v)

    // =========================================================================
    // 2. SINAIS GLOBAIS
    // =========================================================================
    // Sinais para os novos periféricos
    reg clk;
    reg rst;
    reg uart_rx_i = 1'b1;
    wire uart_tx_o;
    wire uart_irq_o;
    
    wire spi_sck;
    wire spi_mosi;
    wire spi_miso = 1'b0;
    wire spi_ss_n;
    
    wire i2c_sda;
    wire i2c_scl;

    // Pull-ups para I2C (simulação)
    pullup(i2c_sda);
    pullup(i2c_scl);

    // =========================================================================
    // 3. INSTANCIACAO DO SoC (DEVICE UNDER TEST)
    // =========================================================================
    // Nota: O DUT usa Reset Ativo BAIXO (aresetn), o TB usa Ativo ALTO (rst).
    // Invertemos o sinal na conexão.
    
    soc_top_teste_mem_periph #(
        .RAM_BYTES_REQ(64*1024)
    ) u_dut (
        .aclk(clk), 
        .aresetn(!rst),      // Inverte: TB(1)=Reset -> DUT(0)=Reset
        
        // Pinos da UART
        .uart_rx(uart_rx_i), // Entrada RX do SoC (idle 1)
        .uart_tx(uart_tx_o), // Saída TX do SoC (Monitorada aqui)
        // GPIO
        .gpio_i  (gpio_val),
        .gpio_o  (gpio_out),

        // SPI
        .spi_sclk_o (spi_sck),
        .spi_mosi_o (spi_mosi),
        .spi_miso_i   (spi_miso),
        .spi_ss_n_o  (spi_ss_n),

        // I2C
        .i2c_sda (i2c_sda),
        .i2c_scl (i2c_scl),

        // Trap/Debug
        .trap    ()
    );

    // =========================================================================
    // 4. GERADOR DE FIRMWARE E CARREGAMENTO (Tudo em um)
    // =========================================================================
    integer file_handle;
    integer str_idx;
    reg [7:0] char_tmp;
    reg [31:0] opcode_tmp;

    initial begin
        // Inicializa sinais
        clk = 0;
        rst = 1;      // Mantém o SoC em Reset enquanto geramos o firmware
        uart_rx_i = 1;

        // ---------------------------------------------------------------------
        // 1. GERAÇÃO DO ARQUIVO .HEX
        // ---------------------------------------------------------------------
        if (MODO_OPERACAO == 0) begin
            $display("[TB] 1. Gerando firmware em: ../firmware.hex");
            
            file_handle = $fopen("firmware.hex", "w");
            if (file_handle == 0) begin
                $display("[TB] ERRO CRITICO: Nao foi possivel criar o arquivo.");
                $finish;
            end

            // --- ESCREVENDO O ASSEMBLY (HEX) ---
            
            // LUI x10, 0x40002 (Base UART)
            $fdisplay(file_handle, "%h", 32'h40002537); 

            // Loop da mensagem
            for (str_idx = 0; str_idx < 256; str_idx = str_idx + 1) begin
                char_tmp = texto_msg[(256-str_idx)*8 -: 8];
                if (char_tmp != 0) begin
                    // POLLING: LW, ANDI, BNE
                    $fdisplay(file_handle, "%h", 32'h00852283); 
                    $fdisplay(file_handle, "%h", 32'h0082F293);
                    $fdisplay(file_handle, "%h", 32'hFE029CE3);
                    
                    // CARREGA E ENVIA
                    opcode_tmp = ({20'b0, char_tmp} << 20) | 32'h00000593;
                    $fdisplay(file_handle, "%h", opcode_tmp);
                    $fdisplay(file_handle, "%h", 32'h00B52223);

                    // DELAYS (NOPs)
                    $fdisplay(file_handle, "%h", 32'h00000013);
                    $fdisplay(file_handle, "%h", 32'h00000013);
                    $fdisplay(file_handle, "%h", 32'h00000013);
                    $fdisplay(file_handle, "%h", 32'h00000013);
                end
            end

            // FIM (Stop Byte e Loop)
            $fdisplay(file_handle, "%h", 32'h00852283);
            $fdisplay(file_handle, "%h", 32'h0082F293);
            $fdisplay(file_handle, "%h", 32'hFE029CE3);
            $fdisplay(file_handle, "%h", 32'h0FF00593); 
            $fdisplay(file_handle, "%h", 32'h00B52223);
            $fdisplay(file_handle, "%h", 32'h0000006f);

            $fclose(file_handle);
            $display("[TB] Arquivo gerado.");
        end

        // ---------------------------------------------------------------------
        // 2. FORÇA O CARREGAMENTO NA MEMÓRIA (Backdoor Load)
        // ---------------------------------------------------------------------
        // Esperamos um pequeno tempo para garantir que o arquivo foi fechado pelo OS
        #100; 
        
        $display("[TB] 2. Carregando firmware na memoria do SoC...");
        
        // Aqui acessamos a memoria DENTRO do SoC usando hierarquia (ponto a ponto)
        // u_dut = soc_top
        // u_ram = axi_lite_ram (dentro do soc_top)
        // mem   = array de registradores (dentro do axi_lite_ram)
        $readmemh("firmware.hex", u_dut.u_ram.mem);

        // ---------------------------------------------------------------------
        // 3. INICIA A SIMULAÇÃO
        // ---------------------------------------------------------------------
        #100;
        $display("[TB] 3. Liberando Reset. O processador vai rodar agora!");
        rst = 0; // Solta o reset, CPU começa a ler o endereço 0x00000000
    end

    // =========================================================================
    // 5. GERAÇÃO DE CLOCK E TIMEOUT
    // =========================================================================
    always #(CLOCK_PERIOD/2) clk = ~clk;

    initial begin
        // Timeout de Segurança (caso trave ou não envie nada)
        // 5ms de simulação é suficiente para a mensagem curta
        #5000000; 
        $display("\n[TB] TIMEOUT: Stop Byte nao detectado. O sistema travou?");
        $finish;
    end

    // =========================================================================
    // 6. MONITOR SERIAL (RX)
    // =========================================================================
    reg [7:0] rx_byte;
    reg [7:0] rx_buffer [0:1023];
    integer k;
    integer buf_idx;

    initial begin
        buf_idx = 0;
        wait(!rst); // Espera sair do reset
        
        $display("--------------------------------------------------");
        $display("   MONITOR SERIAL INICIADO");
        $display("--------------------------------------------------");
        
        forever begin
            // 1. Detecta Start Bit (Borda de descida no TX)
            @(negedge uart_tx_o);
            
            // 2. Espera 1.5 bits para amostrar o meio do bit 0 (LSB)
            #(BIT_TIME * 1.5);
            
            // 3. Amostra os 8 bits de dados
            for (k=0; k<8; k=k+1) begin 
                rx_byte[k] = uart_tx_o;
                #(BIT_TIME); 
            end
            
            // 4. Verifica Byte de Parada (nosso protocolo de teste define 0xFF como fim)
            if (rx_byte == 8'hFF) begin
                if (MODO_EXIBICAO == 1) begin
                    $display("\n==================================================");
                    $display("MENSAGEM RECEBIDA DO SOC:");
                    for (k=0; k < buf_idx; k=k+1) $write("%c", rx_buffer[k]);
                    $display("\n==================================================\n");
                end
                $display("[TB] Sucesso! Fim da transmissao.");
                $finish;
            end else begin
                // Processa caractere normal
                if (MODO_EXIBICAO == 0) begin
                    $display("[RX] '%c' (Hex: %h)", rx_byte, rx_byte);
                end else begin
                    rx_buffer[buf_idx] = rx_byte;
                    buf_idx = buf_idx + 1;
                end
            end
        end
    end

    // Dump para visualização de ondas
    initial begin
        $dumpfile("soc_uart_full.vcd");
        $dumpvars(0, tb_soc_uart_full);
    end

endmodule