`ifndef SOC_ADDR_MAP_VH
`define SOC_ADDR_MAP_VH

// -----------------------------------------------------------------------------
// SoC Address Map (AXI-Lite)
// Decode rule (interconnect): (addr & MASK) == BASE
// -----------------------------------------------------------------------------

// ---------------- Root regions (TOP: AXI 2M -> 1x3) ----------------
// MEM region: 128KB at 0x0000_0000
`define AXI_MEM_REGION_BASE     32'h0000_0000
`define AXI_MEM_REGION_MASK     32'hFFFE_0000   // 128 KiB window

// PERIPH region: 64KB at 0x4000_0000
`define AXI_PERIPH_REGION_BASE  32'h4000_0000
`define AXI_PERIPH_REGION_MASK  32'hFFFF_0000   // 64 KiB window

// BOOT region: 64KB at 0x5000_0000  (FORA do range de periféricos)
`define AXI_BOOT_REGION_BASE    32'h5000_0000
`define AXI_BOOT_REGION_MASK    32'hFFFF_0000   // 64 KiB window

// ---------------- Sub-regions inside MEM ----------------
// RAM: 64KB at 0x0000_0000
`define AXI_RAM_BASE            32'h0000_0000
`define AXI_RAM_MASK            32'hFFFF_0000   // 64 KiB

// (Optional) ROM alias: keep if you use
`define AXI_ROM_BASE            32'h0001_0000
`define AXI_ROM_MASK            32'hFFFF_0000   // 64 KiB

// ---------------- BOOT sub-region ----------------
// SPI Boot window mapped inside BOOT region
// Ex: CPU/BOOT reads from 0x5000_0000 + offset -> SPI EEPROM byte address
`define AXI_SPI_BOOT_BASE       32'h5000_0000
`define AXI_SPI_BOOT_MASK       32'hFFFF_F000   // 4 KiB window (0x000..0xFFF)

// ---------------- Peripheral windows (AXI 1x6) ----------------
`define AXI_PERIPH_MASK_4KB     32'hFFFF_F000
`define AXI_PERIPH_MASK_256B    32'hFFFF_FF00

`define AXI_GPIO_BASE           32'h4000_0000
`define AXI_TIMER_BASE          32'h4000_1000
`define AXI_UART_BASE           32'h4000_2000
`define AXI_SPI_BASE            32'h4000_3000
`define AXI_I2C_BASE            32'h4000_4000
`define AXI_INTR_BASE           32'h4000_5000

`define AXI_GPIO_MASK           `AXI_PERIPH_MASK_4KB
`define AXI_TIMER_MASK          `AXI_PERIPH_MASK_256B
`define AXI_UART_MASK           `AXI_PERIPH_MASK_4KB
`define AXI_SPI_MASK            `AXI_PERIPH_MASK_4KB
`define AXI_I2C_MASK            `AXI_PERIPH_MASK_4KB
`define AXI_INTR_MASK           `AXI_PERIPH_MASK_4KB

// ---------------- Timer absolute addresses (optional helpers) ----------------
`define AXI_TIMER_CTRL0_ADDR      (`AXI_TIMER_BASE + 32'h0000_0008)
`define AXI_TIMER_CMP0_ADDR       (`AXI_TIMER_BASE + 32'h0000_000C)
`define AXI_TIMER_VAL0_ADDR       (`AXI_TIMER_BASE + 32'h0000_0010)
`define AXI_TIMER_PRESCALE0_ADDR  (`AXI_TIMER_BASE + 32'h0000_0020)
`define AXI_TIMER_POSTSCALE0_ADDR (`AXI_TIMER_BASE + 32'h0000_0024)
`define AXI_TIMER_STATUS0_ADDR    (`AXI_TIMER_BASE + 32'h0000_0028)
`define AXI_TIMER_END_ADDR        (`AXI_TIMER_BASE + 32'h0000_00FF)

`endif