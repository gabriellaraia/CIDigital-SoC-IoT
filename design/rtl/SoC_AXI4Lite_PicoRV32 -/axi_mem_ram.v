module axi_mem_ram #(
    // =======================
    // ONDE ALTERAR O TAMANHO:
    // =======================
    // Tamanho "pedido" da RAM em bytes (pode ser qualquer valor).
    // O módulo vai arredondar para cima para uma POTÊNCIA DE 2 (WINDOW_BYTES).
    parameter integer MEM_BYTES_REQ = 64*1024,

    // ===========================
    // ONDE ALTERAR O ENDEREÇO BASE:
    // ===========================
    // Base address ABSOLUTO (mesmo do soc_addr_map.vh).
    // IMPORTANTE: Deve ser alinhado com WINDOW_BYTES.
    parameter [31:0] BASE_ADDR = 32'h0001_0000,

    // “string” em Verilog-2001: vetor de bytes
    parameter [8*256-1:0] INIT_FILE = "firmware_timer_test.hex"
)(
    input  wire        clk,
    input  wire        resetn,

    // AW (write address)
    input  wire        awvalid,
    output reg         awready,
    input  wire [31:0] awaddr,
    input  wire [ 2:0] awprot,  // ignorado

    // W (write data)
    input  wire        wvalid,
    output reg         wready,
    input  wire [31:0] wdata,
    input  wire [ 3:0] wstrb,

    // B (write response)
    output reg         bvalid,
    input  wire        bready,

    // AR (read address)
    input  wire        arvalid,
    output reg         arready,
    input  wire [31:0] araddr,
    input  wire [ 2:0] arprot,  // ignorado

    // R (read data)
    output reg         rvalid,
    input  wire        rready,
    output reg [31:0]  rdata
);

    // -------- helpers --------
    function integer CLOG2;
        input integer v;
        integer i;
        begin
            v = v - 1;
            for (i = 0; v > 0; i = i + 1)
                v = v >> 1;
            CLOG2 = i;
        end
    endfunction

    // Próxima potência de 2 >= v (para janelas limpas em BASE/MASK)
    function integer NEXT_POW2;
        input integer v;
        integer p;
        begin
            p = 1;
            while (p < v)
                p = p << 1;
            NEXT_POW2 = p;
        end
    endfunction

    localparam integer WINDOW_BYTES = NEXT_POW2(MEM_BYTES_REQ); // tamanho REAL mapeável via MASK
    localparam integer WORDS        = (WINDOW_BYTES + 3) / 4;
    localparam integer A_LSB        = 2;
    localparam integer A_W          = CLOG2(WORDS);
    localparam integer WORDS_MAX    = WORDS - 1;

    reg [31:0] mem [0:WORDS-1];

`ifndef SYNTHESIS
    reg [8*256-1:0] firmware_file;
    integer i;

    initial begin
        // Preenche com NOP (0x00000013) por default
        for (i = 0; i < WORDS; i = i + 1)
            mem[i] = 32'h00000013;

        // Seleciona arquivo: default INIT_FILE, pode ser sobrescrito por +firmware=...
        firmware_file = INIT_FILE;
        if ($value$plusargs("firmware=%s", firmware_file))
            $display("axi_lite_ram: usando +firmware=%0s", firmware_file);
        else
            $display("axi_lite_ram: usando INIT_FILE=%0s", INIT_FILE);

        // Report do tamanho real (janela)
        $display("axi_lite_ram: MEM_BYTES_REQ=%0d bytes, WINDOW_BYTES(POW2)=%0d bytes, WORDS=%0d",
                 MEM_BYTES_REQ, WINDOW_BYTES, WORDS);

        // Checagem de alinhamento do BASE
        if ((BASE_ADDR & (WINDOW_BYTES-1)) != 0) begin
            $display("axi_lite_ram: ERRO: BASE_ADDR=0x%08h nao alinhado em WINDOW_BYTES=%0d",
                     BASE_ADDR, WINDOW_BYTES);
            $fatal(1);
        end

        // Só tenta carregar se firmware_file não estiver vazio
        if (firmware_file[7:0] != 8'd0) begin
            $display("axi_lite_ram: $readmemh(%0s)", firmware_file);
            $readmemh(firmware_file, mem);
        end else begin
            $display("axi_lite_ram: firmware_file vazio -> sem $readmemh (bootloader vai carregar via EEPROM)");
        end

        for (i = 0; i < 8; i = i + 1)
            $display("RAM mem[%0d] = %08x", i, mem[i]);
    end
`endif

    // -------- latches/índices --------
    reg        aw_hold, w_hold, ar_hold;
    reg [31:0] aw_addr_q, w_data_q, ar_addr_q;
    reg [ 3:0] w_strb_q;

    // Endereço relativo à base (evita depender do slice direto do addr absoluto)
    wire [31:0] aw_rel = aw_addr_q - BASE_ADDR;
    wire [31:0] ar_rel = ar_addr_q - BASE_ADDR;

    // Índice em palavras
    wire [A_W-1:0] aw_idx = aw_rel[A_LSB +: A_W];
    wire [A_W-1:0] ar_idx = ar_rel[A_LSB +: A_W];

    // In-range por comparação de endereços absolutos
    wire aw_in_range = (aw_addr_q >= BASE_ADDR) && (aw_addr_q < (BASE_ADDR + WINDOW_BYTES));
    wire ar_in_range = (ar_addr_q >= BASE_ADDR) && (ar_addr_q < (BASE_ADDR + WINDOW_BYTES));

    always @(posedge clk) begin
        if (!resetn) begin
            awready <= 0; wready <= 0; bvalid <= 0;
            arready <= 0; rvalid <= 0; rdata  <= 32'h0;

            aw_hold <= 0; w_hold <= 0; ar_hold <= 0;
            aw_addr_q <= 32'h0; w_data_q <= 32'h0; w_strb_q <= 4'h0;
            ar_addr_q <= 32'h0;
        end else begin
            // defaults 1-ciclo
            awready <= 0; wready <= 0; arready <= 0;

            // ===== WRITE =====
            if (!aw_hold && awvalid) begin
                aw_hold   <= 1'b1;
                aw_addr_q <= awaddr;
                awready   <= 1'b1;
            end
            if (!w_hold && wvalid) begin
                w_hold   <= 1'b1;
                w_data_q <= wdata;
                w_strb_q <= wstrb;
                wready   <= 1'b1;
            end
            if (!bvalid && aw_hold && w_hold) begin
                if (aw_in_range) begin
                    if (w_strb_q[0]) mem[aw_idx][ 7: 0] <= w_data_q[ 7: 0];
                    if (w_strb_q[1]) mem[aw_idx][15: 8] <= w_data_q[15: 8];
                    if (w_strb_q[2]) mem[aw_idx][23:16] <= w_data_q[23:16];
                    if (w_strb_q[3]) mem[aw_idx][31:24] <= w_data_q[31:24];
                end
                // mesmo fora de faixa: responde (padrão AXI-lite simples)
                bvalid  <= 1'b1;
                aw_hold <= 1'b0;
                w_hold  <= 1'b0;
            end
            if (bvalid && bready)
                bvalid <= 1'b0;

            // ===== READ =====
            if (!ar_hold && arvalid) begin
                ar_hold   <= 1'b1;
                ar_addr_q <= araddr;
                arready   <= 1'b1;
            end
            // latência 1
            if (ar_hold && !rvalid) begin
                rdata  <= ar_in_range ? mem[ar_idx] : 32'h0000_0000;
                rvalid <= 1'b1;
                ar_hold<= 1'b0;
            end
            if (rvalid && rready)
                rvalid <= 1'b0;
        end
    end

endmodule