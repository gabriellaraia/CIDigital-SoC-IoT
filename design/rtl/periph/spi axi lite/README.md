# SPI-Lite Master Controller

A lightweight AXI4-Lite compliant SPI master controller designed for SoC integration. This peripheral provides a simple, register-based interface for SPI communication with support for multiple clock modes, chip select management, and interrupt-driven operation.

## Features

- **AXI4-Lite Interface**: Standard 32-bit bus interface for easy SoC integration
- **Full-duplex SPI**: Simultaneous transmit and receive
- **8-bit Data Transfer**: Fixed 8-bit word size
- **4-entry FIFOs**: Separate TX and RX FIFOs (4 bytes each)
- **8 Chip Select Lines**: Independent slave select control
- **Multiple SPI Modes**: Support for all 4 SPI clock modes (CPOL/CPHA combinations)
- **Configurable Bit Order**: MSB-first or LSB-first transmission
- **Loopback Mode**: Internal loopback for testing
- **Interrupt Support**: TX FIFO empty interrupt with masking
- **Software Reset**: Transfer/FIFO reset via register write

## Register Map

All registers are 32-bit wide. Only the lower 8 bits of the data bus are used for most registers.

| Offset | Register | Name | Access | Description |
|--------|----------|------|--------|-------------|
| 0x1C | SPI_DGIER | Global Interrupt Enable | R/W | Global interrupt enable bit |
| 0x20 | SPI_IPISR | Interrupt Status | R/W | Interrupt status flags |
| 0x28 | SPI_IPIER | Interrupt Enable | R/W | Interrupt enable mask |
| 0x40 | SPI_SRR | Software Reset | W | Software reset register |
| 0x60 | SPI_CR | Control | R/W | SPI operation control |
| 0x64 | SPI_SR | Status | R | FIFO and operation status |
| 0x68 | SPI_DTR | Data Transmit | W | Transmit data FIFO write |
| 0x6C | SPI_DRR | Data Receive | R | Receive data FIFO read |
| 0x70 | SPI_SSR | Slave Select | R/W | Chip select control |

## Register Descriptions

### SPI_DGIER - Global Interrupt Enable (Offset: 0x1C)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 31 | GIE | 0 | R/W | Global Interrupt Enable. Must be set to 1 to enable any interrupts. |
| 30:0 | - | 0 | R | Reserved, read as 0 |

### SPI_IPISR - Interrupt Status (Offset: 0x20)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 2 | TX_EMPTY | 0 | R/W | TX FIFO Empty Interrupt Status. Set when TX FIFO becomes empty. Write 1 to clear. |
| 1:0 | - | 0 | R | Reserved, read as 0 |

### SPI_IPIER - Interrupt Enable (Offset: 0x28)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 2 | TX_EMPTY | 0 | R/W | TX FIFO Empty Interrupt Enable. Set to 1 to enable TX empty interrupt. |
| 1:0 | - | 0 | R | Reserved, read as 0 |

### SPI_SRR - Software Reset (Offset: 0x40)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 31:0 | RESET | 0 | W | Write `0x0000000A` to flush SPI transfer state and FIFOs. Auto-clears after write. |

### SPI_CR - Control Register (Offset: 0x60)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 9 | LSB_FIRST | 0 | R/W | LSB First. 0 = MSB transmitted first, 1 = LSB transmitted first |
| 8 | TRANS_INHIBIT | 0 | R/W | Transfer Inhibit. 1 = Prevent automatic transfer initiation |
| 7 | MANUAL_SS | 0 | R/W | Manual Slave Select. 1 = Manual control via SPI_SSR |
| 6 | RXFIFO_RST | 0 | W | RX FIFO Reset. Write 1 to clear RX FIFO. Auto-clears. |
| 5 | TXFIFO_RST | 0 | W | TX FIFO Reset. Write 1 to clear TX FIFO. Auto-clears. |
| 4 | CPHA | 0 | R/W | Clock Phase. See SPI Modes table below |
| 3 | CPOL | 0 | R/W | Clock Polarity. See SPI Modes table below |
| 2 | MASTER | 0 | R/W | Master Mode. Must be set to 1 for master operation |
| 1 | SPE | 0 | R/W | SPI Enable. 1 = Enable SPI operation |
| 0 | LOOP | 0 | R/W | Loopback Mode. 1 = Internal loopback (MOSI connected to MISO) |

**SPI Modes (CPOL/CPHA combinations):**

| Mode | CPOL | CPHA | Clock Idle | Sample Edge | Drive Edge |
|------|------|------|------------|-------------|------------|
| 0 | 0 | 0 | Low | Rising | Falling |
| 1 | 0 | 1 | Low | Falling | Rising |
| 2 | 1 | 0 | High | Falling | Rising |
| 3 | 1 | 1 | High | Rising | Falling |

### SPI_SR - Status Register (Offset: 0x64)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 3 | TX_FULL | 0 | R | TX FIFO Full. 1 = TX FIFO is full |
| 2 | TX_EMPTY | 1 | R | TX FIFO Empty. 1 = TX FIFO is empty |
| 1 | RX_FULL | 0 | R | RX FIFO Full. 1 = RX FIFO is full |
| 0 | RX_EMPTY | 1 | R | RX FIFO Empty. 1 = RX FIFO is empty |

### SPI_DTR - Data Transmit (Offset: 0x68)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 7:0 | DATA | 0 | W | Transmit Data. Writing pushes data to TX FIFO and initiates transfer if SPI enabled. |
| 31:8 | - | 0 | - | Reserved |

### SPI_DRR - Data Receive (Offset: 0x6C)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 7:0 | DATA | 0 | R | Receive Data. Reading pops data from RX FIFO. |
| 31:8 | - | 0 | - | Reserved |

### SPI_SSR - Slave Select (Offset: 0x70)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 7:0 | VALUE | 0x01 | R/W | Slave Select Value. Active-low chip select outputs. Bit 0 = CS0, Bit 1 = CS1, etc. |
| 31:8 | - | 0 | - | Reserved |

## Usage Guide

### Basic SPI Transfer

```c
// 1. Configure SPI (Mode 0, Master, Enabled)
SPI_CR = (1 << 1)  // SPE = 1
       | (1 << 2)  // MASTER = 1
       | (0 << 3)  // CPOL = 0
       | (0 << 4); // CPHA = 0

// 2. Select slave (manual mode)
SPI_CR |= (1 << 7);           // Enable manual SS
SPI_SSR = 0xFE;               // CS0 low (active)

// 3. Write data to transmit
SPI_DTR = 0x55;               // Transmit 0x55

// 4. Wait for transfer complete
while (SPI_SR & 0x01);        // Wait while RX_EMPTY

// 5. Read received data
uint8_t rx = SPI_DRR;

// 6. Deselect slave
SPI_SSR = 0xFF;               // All CS high
```

### Using Interrupts

```c
// 1. Enable interrupts
SPI_IPIER = (1 << 2);         // Enable TX empty interrupt
SPI_DGIER = (1 << 31);        // Global enable

// 2. In interrupt handler
if (SPI_IPISR & (1 << 2)) {   // TX empty interrupt
    SPI_IPISR = (1 << 2);     // Clear interrupt
    // Add more data to SPI_DTR or handle completion
}
```

### Reset Sequence

```c
// Software reset
SPI_SRR = 0x0000000A;

// Or reset individual FIFOs
SPI_CR |= (1 << 5);           // TX FIFO reset
SPI_CR |= (1 << 6);           // RX FIFO reset
```

## SoC Integration Guide

### Interface Overview

The `spi_lite` module provides an AXI4-Lite slave interface for register access and SPI master signals for external communication.

### Port List

**Clock and Reset:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| clk_i | Input | 1 | System clock |
| rst_i | Input | 1 | Active-high reset |

**AXI4-Lite Write Address Channel:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cfg_awvalid_i | Input | 1 | Write address valid |
| cfg_awaddr_i | Input | 32 | Write address |
| cfg_awready_o | Output | 1 | Write address ready |

**AXI4-Lite Write Data Channel:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cfg_wvalid_i | Input | 1 | Write data valid |
| cfg_wdata_i | Input | 32 | Write data |
| cfg_wstrb_i | Input | 4 | Write strobe (byte enable) |
| cfg_wready_o | Output | 1 | Write data ready |

**AXI4-Lite Write Response Channel:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cfg_bvalid_o | Output | 1 | Write response valid |
| cfg_bresp_o | Output | 2 | Write response (00 = OK) |
| cfg_bready_i | Input | 1 | Write response ready |

**AXI4-Lite Read Address Channel:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cfg_arvalid_i | Input | 1 | Read address valid |
| cfg_araddr_i | Input | 32 | Read address |
| cfg_arready_o | Output | 1 | Read address ready |

**AXI4-Lite Read Data Channel:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| cfg_rvalid_o | Output | 1 | Read data valid |
| cfg_rdata_o | Output | 32 | Read data |
| cfg_rresp_o | Output | 2 | Read response (00 = OK) |
| cfg_rready_i | Input | 1 | Read data ready |

**SPI Interface:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| spi_clk_o | Output | 1 | SPI clock output |
| spi_mosi_o | Output | 1 | Master Out Slave In |
| spi_miso_i | Input | 1 | Master In Slave Out |
| spi_cs_o | Output | 8 | Chip select (active low) |
| intr_o | Output | 1 | Interrupt output |

### Address Decoding

The module only decodes the lower 8 bits of the address (`cfg_awaddr_i[7:0]` and `cfg_araddr_i[7:0]`). The system integrator must provide address decoding to route transactions to this peripheral based on upper address bits.

**Example Address Map:**
```
Base Address: 0x4000_0000
Address Range: 0x4000_0000 - 0x4000_00FF (256 bytes)
```

**Integration Example:**
```verilog
// Address decoder for 4KB address space
wire spi_sel = (axi_addr[31:12] == 20'h40000);  // 0x4000_0000 - 0x4000_0FFF

spi_lite u_spi (
    .clk_i          (sys_clk),
    .rst_i          (sys_rst),
    
    // AXI4-Lite connections
    .cfg_awvalid_i  (spi_sel & axi_awvalid),
    .cfg_awaddr_i   (axi_awaddr),
    .cfg_awready_o  (spi_awready),
    // ... other AXI signals
    
    // SPI signals
    .spi_clk_o      (spi_sck),
    .spi_mosi_o     (spi_mosi),
    .spi_miso_i     (spi_miso),
    .spi_cs_o       (spi_cs),
    .intr_o         (spi_irq)
);
```

### Clock Considerations

- **System Clock**: `clk_i` drives the AXI4-Lite interface and internal logic
- **SPI Clock**: SCK frequency = `clk_i / C_SCK_RATIO` (default: divide by 32)
- The `C_SCK_RATIO` parameter can be modified at instantiation:

```verilog
spi_lite #(
    .C_SCK_RATIO(16)  // Change clock divider to 16
) u_spi (...);
```

### Reset Strategy

The peripheral uses active-high synchronous reset (`rst_i`). Registers reset to defaults from `spi_lite_defs.v` (for example, `SPI_SSR = 0x01`).

**Recommended Reset Sequence:**
1. Assert system reset
2. Wait for clock cycles
3. Deassert reset
4. Optionally write `0x0000000A` to `SPI_SRR` to flush transfer/FIFO state
5. Configure SPI_CR before use

### Timing Considerations

- **AXI4-Lite Latency**: Single-cycle response for both reads and writes
- **SPI Transfer**: 16 system clock cycles per bit (default C_SCK_RATIO=32), 128 clocks per byte
- **FIFO Depth**: 4 bytes each for TX and RX - ensure software polls status or uses interrupts

### Interrupt Routing

Connect `intr_o` to the system interrupt controller. The interrupt is level-triggered and active-high. Software must clear the interrupt by writing to SPI_IPISR.

### Synthesis Attributes

The RTL includes Xilinx IOB placement pragmas for SPI signals:
```verilog
//synthesis attribute IOB of spi_clk_q is "TRUE"
//synthesis attribute IOB of spi_mosi_q is "TRUE"
//synthesis attribute IOB of spi_cs_o is "TRUE"
```

These ensure SPI signals are placed in I/O blocks for better timing.

## File Structure

```
design/rtl/periph/spi axi lite/
├── spi_lite.v         # Main module with FIFO implementation
├── spi_lite_defs.v    # Register address and bit definitions
└── README.md          # This file
```

## Running the Local Testbench

Use the testbench under `tb/`:

```bash
cd design/rtl/periph/spi\ axi\ lite/tb
make compile
make run
make lint
```

## Version History

- **V1.0** - Initial release
  - AXI4-Lite interface
  - 8-bit SPI transfers
  - 4-entry FIFOs
  - 8 chip select lines
  - All 4 SPI modes supported

## License

LGPL - See source files for full license text

## References

- AXI4-Lite Specification (ARM)
- SPI Protocol Specification (Motorola)
- Xilinx SPI IP documentation (compatible register map)
