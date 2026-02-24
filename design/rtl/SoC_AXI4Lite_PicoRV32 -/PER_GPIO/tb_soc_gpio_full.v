`timescale 1ns / 1ps

// =============================================================================
// DESCRICAO: Testbench para Contador 7 Segmentos (GPIO)
// =============================================================================

module tb_soc_gpio_full;

// =========================================================================
    // 1. CONFIGURACOES
    // =========================================================================
    parameter MODO_OPERACAO = 0; 
    
    localparam CLOCK_PERIOD = 10; // 100 MHz
    
    // Tabela de Codigos 7 Segmentos
    reg [7:0] segment_map [0:9];

    // BLOCO DE INICIALIZACAO DA TABELA (Roda no tempo 0)
    initial begin
        segment_map[0] = 8'h3F; // 0
        segment_map[1] = 8'h06; // 1
        segment_map[2] = 8'h5B; // 2
        segment_map[3] = 8'h4F; // 3
        segment_map[4] = 8'h66; // 4
        segment_map[5] = 8'h6D; // 5
        segment_map[6] = 8'h7D; // 6
        segment_map[7] = 8'h07; // 7
        segment_map[8] = 8'h7F; // 8
        segment_map[9] = 8'h6F; // 9
    end

    // =========================================================================
    // 2. SINAIS
    // =========================================================================
    reg clk;
    reg rst;
    reg uart_rx_i;
    wire uart_tx_o;

    // GPIO
    reg  [4:0]  gpio_in_dummy;
    wire [29:0] gpio_out;      
    
    // =========================================================================
    // 3. INSTANCIACAO DO SoC
    // =========================================================================
    soc_top_teste_mem_periph #(
        .RAM_BYTES_REQ(64*1024)
    ) u_dut (
        .aclk(clk), 
        .aresetn(!rst), 
        
        .uart_rx(uart_rx_i), 
        .uart_tx(uart_tx_o), 
        .uart_irq(),

        .gpio_i(gpio_in_dummy),
        .gpio_o(gpio_out),
        
        .trap() 
    );

    // =========================================================================
    // 4. GERADOR DE FIRMWARE
    // =========================================================================
    integer file_handle;
    integer i, k;
    reg [31:0] opcode;

    initial begin
        // Inicializa Sinais
        clk = 0;
        rst = 1;
        uart_rx_i = 1;
        gpio_in_dummy = 0;

        #10; // Delay inicial

        if (MODO_OPERACAO == 0) begin
            $display("[TB] Gerando Firmware...");
            file_handle = $fopen("firmware.hex", "w");
            
            // 1. SETUP BASE ADDR (LUI x20, 0x40000) -> Base GPIO
            $fdisplay(file_handle, "%h", 32'h40000A37);

            // 2. LOOP 0 a 9
            for (i = 0; i <= 9; i = i + 1) begin
                // ADDI x1, x0, VALOR_DO_SEGMENTO
                opcode = ({20'b0, segment_map[i]} << 20) | (5'd0 << 15) | (3'b000 << 12) | (5'd1 << 7) | 7'h13;
                $fdisplay(file_handle, "%h", opcode); 

                // SW x1, 0(x20) -> Escreve no GPIO
                $fdisplay(file_handle, "%h", 32'h001A2023);

                // DELAY: Aumentado para 50 NOPs (Processador fica mais lento para o TB ver)
                for (k=0; k<50; k=k+1) begin
                    $fdisplay(file_handle, "%h", 32'h00000013); 
                end
            end

            // 3. TRAVA NO FINAL (Loop infinito no ultimo valor)
            $fdisplay(file_handle, "%h", 32'h0000006f); 

            $fclose(file_handle);
        end

        // Backdoor Load & Start
        #100;
        $readmemh("firmware.hex", u_dut.u_ram.mem);
        #100;
        $display("[TB] Reset liberado. CPU iniciando...");
        rst = 0; 
    end

    // Clock gen
    always #(CLOCK_PERIOD/2) clk = ~clk;

    // =========================================================================
    // 5. MONITORAMENTO (Baseado em Eventos)
    // =========================================================================
    integer expected_idx;
    integer success_count;

    initial begin
        expected_idx = 0;
        success_count = 0;
        wait(!rst); // Espera o processador ligar
        
        $display("[TB] Monitor iniciado. Aguardando transicoes no GPIO...");
        
        // Timeout Global (Segurança)
        #200000; 
        if (success_count < 10) begin
            $display("[TB] [TIMEOUT] Falha! Nao contou ate 9 a tempo.");
            $finish;
        end
    end

    // SEMPRE que o GPIO mudar, verificamos se é o número que esperamos
    always @(gpio_out) begin
        if (!rst) begin // Só verifica se o reset já foi solto
            
            // Filtra: Ignora se for 0 (estado inicial do GPIO antes do primeiro SW)
            if (gpio_out[7:0] !== 8'h00) begin
                
                // Verifica se é o número esperado
                if (gpio_out[7:0] === segment_map[expected_idx]) begin
                    $display("[TB] [CHECK] Numero %0d detectado! (GPIO: %h)", expected_idx, gpio_out[7:0]);
                    expected_idx = expected_idx + 1;
                    success_count = success_count + 1;
                    
                    // Se chegou no 9, fim do teste
                    if (expected_idx > 9) begin
                        $display("\n===========================================");
                        $display("[TB] [SUCESSO] Contagem de 0 a 9 completada!");
                        $display("===========================================\n");
                        $finish;
                    end
                end 
                else begin
                    // Se apareceu um número fora de ordem, avisa (opcional)
                    // Útil para debug se pular números
                    // $display("[TB] Aviso: Valor %h ignorado (Esperado: %h)", gpio_out[7:0], segment_map[expected_idx]);
                end
            end
        end
    end

    // Dump
    initial begin
        $dumpfile("soc_gpio_test.vcd");
        $dumpvars(0, tb_soc_gpio_full);
    end

endmodule