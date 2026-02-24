`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// Pure Verilog-2001 testbench for spi_eeprom_25lc256
// - Reads first 32 bytes using READ (0x03)
// - Compares against firmware_timer_test.hex interpreted as 32-bit words,
//   expanded to bytes LITTLE-ENDIAN.
// -----------------------------------------------------------------------------
module tb_spi_eeprom;

    reg csn  = 1'b1;
    reg sclk = 1'b0;
    reg mosi = 1'b0;
    wire miso;

    // DUT
    spi_eeprom_25lc256 #(
        .INIT_FILE("firmware_timer_test.hex"),
        .INIT_IS_WORDS(1)
    ) dut (
        .csn(csn),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso)
    );

    // reference
    reg [31:0] ref_words [0:8191];
    reg [7:0]  exp_bytes [0:255];
    reg [7:0]  rx_bytes  [0:255];
    integer i;

    // SPI helpers (Mode 0)
    task spi_half;
        begin
            #50 sclk = ~sclk;
        end
    endtask

    task spi_bit;
        input b;
        begin
            mosi = b;
            spi_half(); // rising
            spi_half(); // falling
        end
    endtask

    task spi_byte_tx;
        input [7:0] v;
        integer k;
        begin
            for (k=7; k>=0; k=k-1)
                spi_bit(v[k]);
        end
    endtask

    task spi_byte_rx;
        output [7:0] v;
        integer k;
        reg [7:0] tmp;
        begin
            tmp = 8'h00;
            for (k=7; k>=0; k=k-1) begin
                mosi = 1'b0;
                spi_half();      // rising
                tmp[k] = miso;   // sample
                spi_half();      // falling
            end
            v = tmp;
        end
    endtask

    task eeprom_read;
        input [15:0] addr;
        input integer nbytes;
        integer k;
        reg [7:0] r;
        begin
            csn = 1'b0;
            #20;
            spi_byte_tx(8'h03);
            spi_byte_tx(addr[15:8]);
            spi_byte_tx(addr[7:0]);
            for (k=0; k<nbytes; k=k+1) begin
                spi_byte_rx(r);
                rx_bytes[k] = r;
            end
            #20;
            csn = 1'b1;
            #200;
        end
    endtask

    initial begin
        // init ref
        for (i=0; i<8192; i=i+1) ref_words[i] = 32'h00000013;
        $readmemh("firmware_timer_test.hex", ref_words);

        // expected bytes (first 32 bytes = 8 words * 4 bytes), little-endian
        for (i=0; i<8; i=i+1) begin
            exp_bytes[i*4+0] = ref_words[i][ 7: 0];
            exp_bytes[i*4+1] = ref_words[i][15: 8];
            exp_bytes[i*4+2] = ref_words[i][23:16];
            exp_bytes[i*4+3] = ref_words[i][31:24];
        end

        #500;

        eeprom_read(16'h0000, 32);

        for (i=0; i<32; i=i+1) begin
            if (rx_bytes[i] !== exp_bytes[i]) begin
                $display("TB FAIL @%0d: got=%02x exp=%02x", i, rx_bytes[i], exp_bytes[i]);
                $fatal(1);
            end else begin
                $display("OK @%0d: %02x", i, rx_bytes[i]);
            end
        end

        $display("TB PASS: EEPROM READ matches firmware_timer_test.hex (LE expansion).");
        $finish;
    end

endmodule
