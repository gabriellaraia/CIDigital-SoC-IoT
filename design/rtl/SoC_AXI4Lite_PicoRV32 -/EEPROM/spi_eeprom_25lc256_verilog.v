`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// SPI EEPROM model (inspired by Microchip 25LC256 / 25AA256) - Verilog-2001
//  - 32K x 8 bytes (256 kbit)
//  - SPI Mode 0 (CPOL=0, CPHA=0)
//  - READ (0x03) + 16-bit address supported (enough for bootloader tests)
//  - Optional minimal RDSR/WREN/WRDI/WRITE (simplified)
//
// IMPORTANT ABOUT INIT_FILE FORMAT:
//  This model supports two initialization formats, selected by parameter INIT_IS_WORDS:
//
//   INIT_IS_WORDS = 0: file is BYTE-per-line (00..FF) or byte tokens, loaded directly into mem[]
//   INIT_IS_WORDS = 1: file is WORD-per-line (32-bit hex per line, like PicoRV32 firmware hex).
//                      The file is loaded into a 32-bit temp array and expanded to bytes
//                      in LITTLE-ENDIAN order: b0,b1,b2,b3.
//
// Example for PicoRV32 firmware hex:
//   spi_eeprom_25lc256 #(.INIT_FILE("firmware_timer_test.hex"), .INIT_IS_WORDS(1)) u_eep (...);
// -----------------------------------------------------------------------------
module spi_eeprom_25lc256 #(
    parameter integer MEM_BYTES = 1024,
    parameter [8*256-1:0] INIT_FILE = "firmware_timer_test.hex",
    parameter integer INIT_IS_WORDS = 1
)(
    input  wire csn,
    input  wire sclk,
    input  wire mosi,
    output reg  miso
);

    reg [7:0] mem [0:MEM_BYTES-1];

`ifndef SYNTHESIS
    integer i;
    // temp for word-per-line
    localparam integer MAX_WORDS = (MEM_BYTES + 3) / 4;
    reg [31:0] mem32 [0:MAX_WORDS-1];

    initial begin
        // default fill
        for (i=0; i<MEM_BYTES; i=i+1) mem[i] = 8'hFF;

        if (INIT_IS_WORDS != 0) begin
            for (i=0; i<MAX_WORDS; i=i+1) mem32[i] = 32'h00000013; // NOP-ish
            $readmemh(INIT_FILE, mem32);

            for (i=0; i<MAX_WORDS; i=i+1) begin
                if ((i*4+0) < MEM_BYTES) mem[i*4+0] = mem32[i][ 7: 0];
                if ((i*4+1) < MEM_BYTES) mem[i*4+1] = mem32[i][15: 8];
                if ((i*4+2) < MEM_BYTES) mem[i*4+2] = mem32[i][23:16];
                if ((i*4+3) < MEM_BYTES) mem[i*4+3] = mem32[i][31:24];
            end

            $display("spi_eeprom_25lc256: loaded WORD-per-line hex (LE expand) from %0s", INIT_FILE);
        end else begin
            $readmemh(INIT_FILE, mem);
            $display("spi_eeprom_25lc256: loaded BYTE-per-line hex from %0s", INIT_FILE);
        end

        for (i=0; i<16; i=i+1) $display("EEPROM[%0d]=%02x", i, mem[i]);
    end
`endif

    // commands
    localparam [7:0] CMD_READ  = 8'h03;
    localparam [7:0] CMD_WRITE = 8'h02;
    localparam [7:0] CMD_WREN  = 8'h06;
    localparam [7:0] CMD_WRDI  = 8'h04;
    localparam [7:0] CMD_RDSR  = 8'h05;

    reg [7:0]  cmd;
    reg [15:0] addr;
    reg [7:0]  sr;      // [0]=WIP (unused), [1]=WEL
    reg [2:0]  bitcnt;
    reg [7:0]  sh_in;
    reg [7:0]  sh_out;
    reg [1:0]  phase;   // 0=cmd,1=addr_hi,2=addr_lo,3=data

    // input shift (sample on rising edge)
    always @(posedge sclk or posedge csn) begin
        if (csn) begin
            bitcnt <= 3'd0;
            sh_in  <= 8'h00;
            phase  <= 2'd0;
        end else begin
            sh_in  <= {sh_in[6:0], mosi};
            bitcnt <= bitcnt + 3'd1;

            if (bitcnt == 3'd7) begin
                case (phase)
                    2'd0: begin
                        cmd   <= {sh_in[6:0], mosi};
                        phase <= 2'd1;
                        if ({sh_in[6:0], mosi} == CMD_WREN) sr[1] <= 1'b1;
                        if ({sh_in[6:0], mosi} == CMD_WRDI) sr[1] <= 1'b0;
                        if ({sh_in[6:0], mosi} == CMD_RDSR) sh_out <= sr;
                    end
                    2'd1: begin
                        addr[15:8] <= {sh_in[6:0], mosi};
                        phase      <= 2'd2;
                    end
                    2'd2: begin
                        addr[7:0] <= {sh_in[6:0], mosi};
                        phase     <= 2'd3;
                        if (cmd == CMD_READ) sh_out <= mem[{addr[15:8], {sh_in[6:0], mosi}} % MEM_BYTES];
                    end
                    2'd3: begin
                        if (cmd == CMD_WRITE && sr[1]) begin
                            mem[addr % MEM_BYTES] <= {sh_in[6:0], mosi};
                            addr <= addr + 16'd1;
                        end else if (cmd == CMD_READ) begin
                            addr   <= addr + 16'd1;
                            sh_out <= mem[(addr + 16'd1) % MEM_BYTES];
                        end else if (cmd == CMD_RDSR) begin
                            sh_out <= sr;
                        end
                    end
                endcase
            end
        end
    end

    // output shift (change on falling edge)
    always @(negedge sclk or posedge csn) begin
        if (csn) begin
            miso   <= 1'bZ;
            sh_out <= 8'hFF;
        end else begin
            miso   <= sh_out[7];
            sh_out <= {sh_out[6:0], 1'b0};
        end
    end

endmodule
