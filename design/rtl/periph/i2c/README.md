# I2C Master Controller

A full-featured I2C master controller with AXI4-Lite interface and programmable instruction execution. This peripheral provides a complete I2C solution with programmable transaction scripts, manual override, and comprehensive error handling for SoC integration.

## Features

- **AXI4-Lite Interface**: Standard 32-bit bus interface for register access and instruction memory
- **AXI-Stream Command Interface**: Byte-wise command stream for flexible I2C transaction control
- **Programmable I2C Scripts**: Execute I2C transactions from instruction memory with conditional flow control
- **Full I2C Protocol Support**: START, STOP, repeated START, 8-bit data transfers with ACK/NACK
- **Multiple Read Modes**: RXK (read with ACK), RXN (read with NAK), RXLK (last byte with ACK), RXLN (last byte with NAK)
- **Clock Stretching Support**: Handles slave-directed clock stretching
- **Collision Detection**: Detects and reports bus contention during write operations
- **Watchdog Timer**: Configurable timeout for stuck bus recovery
- **Manual Override**: Direct SCL/SDA control for debugging and special operations
- **Channel Tagging**: AXI-Stream output channel ID for multi-channel transactions
- **Programmable Clock Rate**: Configurable I2C clock divider
- **Error Handling**: Bus error detection, abort handling, and automatic STOP generation

## Architecture

The I2C controller consists of three hierarchical modules:

1. **lli2cm.v** - Low-level Wishbone-style I2C master for bit-level operations
2. **axisi2c.v** - AXI-Stream based byte-wise I2C driver
3. **axili2ccpu.v** - AXI4-Lite CPU controller with instruction fetch and execution

## Register Map

All registers are 32-bit wide, accessed via AXI4-Lite at offsets shown below.

| Offset | Register | Name | Access | Description |
|--------|----------|------|--------|-------------|
| 0x00 | CONTROL | Control/Status | R/W | Main control and status register |
| 0x04 | OVERRIDE | Manual Override | R/W | Manual SCL/SDA control and received data |
| 0x08 | ADDRESS | Address/Jump | R/W | Instruction memory address / Jump target |
| 0x0C | CKCOUNT | Clock Count | R/W | I2C clock divider |

## Register Descriptions

### CONTROL - Control/Status Register (Offset: 0x00)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 31:28 | half_insn | 0 | R | Upper 4 bits of pending half-instruction |
| 27:25 | - | 0 | R | Reserved |
| 24 | - | 0 | R | Reserved |
| 23 | r_wait | 0 | R | Controller waiting on sync signal |
| 22 | soft_halt | 0 | R/W | Soft halt request (halt after current instruction) |
| 21 | r_aborted | 0 | R/W | Abort flag - bus instructions ignored when set |
| 20 | r_err | 0 | R/W | Error flag - set on bus error, write 1 to clear |
| 19 | hard_halt | 0 | R/W | Hard halt request (halt immediately) |
| 18 | insn_valid | 0 | R | Instruction queued but not yet issued |
| 17 | half_valid | 0 | R | Half-instruction waiting to be issued |
| 16 | imm_cycle | 0 | R | Immediate byte mode for SEND/CHANNEL |
| 15 | o_scl | 1 | R | Output commanded SCL value |
| 14 | o_sda | 1 | R | Output commanded SDA value |
| 13 | i_scl | 1 | R | Input sampled SCL value |
| 12 | i_sda | 1 | R | Input sampled SDA value |
| 11:0 | insn | 0 | R | Current executing instruction (12 bits) |

### OVERRIDE - Manual Override Register (Offset: 0x04)

**Write:**
| Bit | Field | Access | Description |
|-----|-------|--------|-------------|
| 31:16 | - | W | Reserved |
| 15:14 | MANUAL_SCL_SDA | W | Manual SCL/SDA values (when MANUAL enabled) |
| 11 | MANUAL_EN | W | Enable manual override mode |
| 10:8 | - | W | Reserved |
| 7:0 | DATA | W | Write instruction byte when halted |

**Read:**
| Bit | Field | Access | Description |
|-----|-------|--------|-------------|
| 15 | i_scl | R | Input SCL value |
| 14 | i_sda | R | Input SDA value |
| 13 | o_scl | R | Output SCL value |
| 12 | o_sda | R | Output SDA value |
| 11 | r_manual | R | Manual override mode active |
| 10 | r_aborted | R | Abort flag state |
| 9 | ovw_valid | R | Valid data available to read |
| 8 | ovw_tlast | R | TLAST flag of received data |
| 7:0 | rx_data | R | Last data byte received on AXI-Stream |

### ADDRESS - Address/Jump Register (Offset: 0x08)

**Write:**
| Bit | Field | Access | Description |
|-----|-------|--------|-------------|
| 31:0 | ADDR | W | Jump target address / Set instruction fetch address |

Writing to this register when halted causes a jump to the specified address and clears the halt state.

**Read:**
| Bit | Field | Access | Description |
|-----|-------|--------|-------------|
| 31:0 | PC | R | Current instruction fetch address |

### CKCOUNT - Clock Count Register (Offset: 0x0C)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 11:0 | CKCOUNT | 0xFFF | R/W | I2C clock divider (0 = max speed) |

Controls the number of system clock cycles per I2C bit clock. Lower values = faster I2C.

## Instruction Set

The controller executes instructions from instruction memory. Each byte contains two 4-bit instructions.

| Opcode | Name | Description |
|--------|------|-------------|
| 0x0 | NOP | No operation |
| 0x1 | START | Generate START condition |
| 0x2 | STOP | Generate STOP condition |
| 0x3 | SEND | Send byte (followed by immediate byte) |
| 0x4 | RXK | Receive byte with ACK |
| 0x5 | RXN | Receive byte with NAK |
| 0x6 | RXLK | Receive last byte with ACK |
| 0x7 | RXLN | Receive last byte with NAK |
| 0x8 | WAIT | Wait for sync signal |
| 0x9 | HALT | Halt controller |
| 0xA | ABORT | Set abort address to next instruction |
| 0xB | TARGET | Set jump target address |
| 0xC | JUMP | Jump to target address |
| 0xD | CHANNEL | Set AXI-Stream channel ID (followed by immediate) |
| 0xE | - | Undefined/Illegal |
| 0xF | - | Undefined/Illegal |

## Usage Guide

### Basic I2C Write Transaction

```c
// Base address of I2C controller
#define I2C_BASE  0x40001000

// Registers
#define I2C_CTRL   (*(volatile uint32_t *)(I2C_BASE + 0x00))
#define I2C_OVRD   (*(volatile uint32_t *)(I2C_BASE + 0x04))
#define I2C_ADDR   (*(volatile uint32_t *)(I2C_BASE + 0x08))
#define I2C_CKCNT  (*(volatile uint32_t *)(I2C_BASE + 0x0C))

void i2c_write(uint8_t dev_addr, uint8_t reg_addr, uint8_t data)
{
    // Assuming instruction memory at 0x0000_0000
    // Program: START | DEV_ADDR<<1 | SEND reg_addr | SEND data | STOP

    // Write clock divider (optional)
    // Lower CKCOUNT -> faster SCL, higher CKCOUNT -> slower SCL
    I2C_CKCNT = 0x040;  // Example divider value

    // Write instruction memory (implementation-specific)
    // Instructions:
    // 0x10 = START followed by NOP
    // 0xA0 = DEV_ADDR<<1 (7-bit << 1, write = 0)
    // 0x30 = reg_addr follows
    // 0x00 = Immediate byte
    // 0x30 = data follows
    // 0x00 = Immediate byte
    // 0x20 = STOP

    // Start execution at address 0
    I2C_ADDR = 0x00000000;

    // Wait for completion (poll CONTROL.halted or insn_valid)
    while (!(I2C_CTRL & (1 << 19))) ;  // Wait for hard_halt
}
```

### I2C Read Transaction

```c
// Read single byte from register
void i2c_read_byte(uint8_t dev_addr, uint8_t reg_addr, uint8_t *data)
{
    // First, send register address (write phase)
    // Program: START | DEV_ADDR<<1 | SEND reg_addr | START | DEV_ADDR<<1|READ | RXLN

    // Write instructions to memory, then execute
    // ...

    // Check received data in OVERRIDE register
    *data = I2C_OVRD & 0xFF;
}
```

### Using Manual Override

```c
void i2c_manual_control(void)
{
    // Enable manual override mode
    I2C_OVRD = (1 << 11);  // Set MANUAL_EN

    // Drive SCL and SDA manually
    // Bit 15 = manual SCL, Bit 14 = manual SDA
    I2C_OVRD = (1 << 11) | (1 << 15) | (1 << 14);  // Both high

    // Generate START: SDA low while SCL high
    I2C_OVRD = (1 << 11) | (1 << 15) | (0 << 14);

    // Generate STOP: SDA high while SCL high
    I2C_OVRD = (1 << 11) | (1 << 15) | (1 << 14);

    // Disable manual override
    I2C_OVRD = 0;
}
```

### Error Handling

```c
int i2c_check_error(void)
{
    uint32_t ctrl = I2C_CTRL;

    // Check error flag
    if (ctrl & (1 << 20)) {
        // Clear error by writing 1 to bit 20
        I2C_CTRL = (1 << 20);
        return -1;  // Error occurred
    }

    // Check aborted flag
    if (ctrl & (1 << 21)) {
        // Clear abort by writing 1 to bit 21
        I2C_CTRL = (1 << 21);
        return -2;  // Transaction was aborted
    }

    return 0;  // No error
}

void i2c_reset(void)
{
    // Hard halt to stop any ongoing transaction
    I2C_CTRL = (1 << 19);  // Set hard_halt

    // Clear error and abort flags
    I2C_CTRL = (1 << 20) | (1 << 21);

    // Jump to reset address to restart
    I2C_ADDR = 0x00000000;
}
```

## SoC Integration Guide

### Interface Overview

The `axili2ccpu` module provides AXI4-Lite slave interface for register access and instruction memory reads.

### Port List

**Clock and Reset:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| S_AXI_ACLK | Input | 1 | System clock |
| S_AXI_ARESETN | Input | 1 | Active-low reset |

**AXI4-Lite Slave Interface:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| S_AXI_AWVALID | Input | 1 | Write address valid |
| S_AXI_AWREADY | Output | 1 | Write address ready |
| S_AXI_AWADDR | Input | 4 | Write address (only lower bits used) |
| S_AXI_AWPROT | Input | 3 | Write protection type |
| S_AXI_WVALID | Input | 1 | Write data valid |
| S_AXI_WREADY | Output | 1 | Write data ready |
| S_AXI_WDATA | Input | 32 | Write data |
| S_AXI_WSTRB | Input | 4 | Write strobe (byte enable) |
| S_AXI_BVALID | Output | 1 | Write response valid |
| S_AXI_BRESP | Output | 2 | Write response (00 = OK) |
| S_AXI_BREADY | Input | 1 | Write response ready |
| S_AXI_ARVALID | Input | 1 | Read address valid |
| S_AXI_ARREADY | Output | 1 | Read address ready |
| S_AXI_ARADDR | Input | 4 | Read address |
| S_AXI_ARPROT | Input | 3 | Read protection type |
| S_AXI_RVALID | Output | 1 | Read data valid |
| S_AXI_RDATA | Output | 32 | Read data |
| S_AXI_RRESP | Output | 2 | Read response (00 = OK) |
| S_AXI_RREADY | Input | 1 | Read data ready |

**Instruction Memory AXI Master (for fetch):**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| M_INSN_ARVALID | Output | 1 | Instruction read address valid |
| M_INSN_ARREADY | Input | 1 | Instruction read address ready |
| M_INSN_ARADDR | Output | AW | Instruction fetch address |
| M_INSN_ARPROT | Output | 3 | Instruction read protection |
| M_INSN_RVALID | Input | 1 | Instruction data valid |
| M_INSN_RREADY | Output | 1 | Instruction data ready |
| M_INSN_RDATA | Input | DW | Instruction byte data |
| M_INSN_RRESP | Input | 2 | Instruction read response |

**AXI-Stream Output (Received Data):**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| M_AXIS_TVALID | Output | 1 | Data valid |
| M_AXIS_TREADY | Input | 1 | Data ready |
| M_AXIS_TDATA | Output | 8 | Received data byte |
| M_AXIS_TLAST | Output | 1 | Last byte in packet |
| M_AXIS_TID | Output | ID | Channel ID (optional) |

**I2C Physical Interface:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| i_i2c_sda | Input | 1 | I2C SDA input (from pad) |
| i_i2c_scl | Input | 1 | I2C SCL input (from pad) |
| o_i2c_sda | Output | 1 | I2C SDA output (to pad) |
| o_i2c_scl | Output | 1 | I2C SCL output (to pad) |

**Control and Debug:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| i_sync_signal | Input | 1 | Sync signal for WAIT instruction |
| o_debug | Output | 32 | Debug signals |

### Address Decoding

The module decodes the lower 2 bits of the address for register selection. System integrator must provide upper address decoding.

**Register Offsets:**
| Address | Register |
|---------|----------|
| Base + 0x00 | CONTROL |
| Base + 0x04 | OVERRIDE |
| Base + 0x08 | ADDRESS |
| Base + 0x0C | CKCOUNT |

### Instantiation Example

```verilog
axili2ccpu #(
    .ADDRESS_WIDTH(32),
    .DATA_WIDTH(32),
    .I2C_WIDTH(8),
    .AXIS_ID_WIDTH(4),
    .RESET_ADDRESS(0),
    .OPT_START_HALTED(1),
    .OPT_MANUAL(1),
    .OPT_WATCHDOG(10000),
    .OPT_LOWPOWER(0)
) u_i2c (
    .S_AXI_ACLK(sys_clk),
    .S_AXI_ARESETN(!sys_rst),

    // AXI4-Lite slave
    .S_AXI_AWVALID(i_awvalid),
    .S_AXI_AWREADY(o_awready),
    .S_AXI_AWADDR(i_awaddr[3:0]),
    .S_AXI_AWPROT(i_awprot),
    .S_AXI_WVALID(i_wvalid),
    .S_AXI_WREADY(o_wready),
    .S_AXI_WDATA(i_wdata),
    .S_AXI_WSTRB(i_wstrb),
    .S_AXI_BVALID(o_bvalid),
    .S_AXI_BREADY(i_bready),
    .S_AXI_BRESP(o_bresp),
    .S_AXI_ARVALID(i_arvalid),
    .S_AXI_ARREADY(o_arready),
    .S_AXI_ARADDR(i_araddr[3:0]),
    .S_AXI_ARPROT(i_arprot),
    .S_AXI_RVALID(o_rvalid),
    .S_AXI_RREADY(i_rready),
    .S_AXI_RDATA(o_rdata),
    .S_AXI_RRESP(o_rresp),

    // Instruction memory interface
    .M_INSN_ARVALID(o_insn_arvalid),
    .M_INSN_ARREADY(i_insn_arready),
    .M_INSN_ARADDR(o_insn_araddr),
    .M_INSN_ARPROT(o_insn_arprot),
    .M_INSN_RVALID(i_insn_rvalid),
    .M_INSN_RREADY(o_insn_rready),
    .M_INSN_RDATA(i_insn_rdata),
    .M_INSN_RRESP(i_insn_rresp),

    // I2C interface
    .i_i2c_sda(i2c_sda_in),
    .i_i2c_scl(i2c_scl_in),
    .o_i2c_sda(o_i2c_sda_out),
    .o_i2c_scl(o_i2c_scl_out),

    // AXI-Stream received data
    .M_AXIS_TVALID(o_rx_valid),
    .M_AXIS_TREADY(i_rx_ready),
    .M_AXIS_TDATA(o_rx_data),
    .M_AXIS_TLAST(o_rx_last),
    .M_AXIS_TID(o_rx_id),

    // Control
    .i_sync_signal(sync_interrupt),
    .o_debug(debug signals)
);
```

### Clock Considerations

- **System Clock**: `S_AXI_ACLK` drives all logic including I2C bit timing
- **I2C Clock**: Generated internally using programmable divider
  - Bit clock = `S_AXI_ACLK / (2 * CKCOUNT)`
  - Default CKCOUNT = 0xFFF (slowest default SCL)

### Reset Strategy

The peripheral uses active-low reset input (`S_AXI_ARESETN`) sampled in clocked logic (`S_AXI_ACLK`).

**Recommended Reset Sequence:**
1. Assert system reset (S_AXI_ARESETN = 0)
2. Wait for reset to propagate
3. Deassert reset
4. Configure CKCOUNT for desired I2C speed
5. Write instruction memory with desired I2C sequence
6. Optionally enable manual override mode
7. Write ADDRESS register to start execution

### Timing Considerations

- **AXI4-Lite Latency**: Single-cycle response for all register accesses
- **Instruction Fetch**: Additional latency based on instruction memory
- **I2C Transaction**: Multiple system clocks per I2C bit (2 × CKCOUNT)
- **Clock Stretching**: Controller waits for slave to release SCL before proceeding

### Interrupt Routing

No dedicated interrupt output. Software polls CONTROL register bits:
- **bit 23 (r_wait)**: Controller waiting on sync signal
- **bit 20 (r_err)**: Error occurred on bus
- **bit 19 (hard_halt)**: Controller halted (transaction complete)

Connect `i_sync_signal` to external interrupt for WAIT instruction support.

## File Structure

```
design/rtl/periph/i2c/
├── axili2ccpu.v    # Top-level AXI4-Lite I2C CPU controller
├── axisi2c.v       # AXI-Stream I2C byte driver
├── lli2cm.v        # Low-level Wishbone I2C master
├── tb_axili2ccpu.v # Testbench
└── README.md       # This file
```

## Running the Local Testbench

This directory contains `tb_axili2ccpu.v` for quick sanity simulation.

```bash
cd design/rtl/periph/i2c
iverilog -g2012 -o tb_axili2ccpu.vvp axilfetch.v axisi2c.v lli2cm.v axili2ccpu.v tb_axili2ccpu.v
vvp tb_axili2ccpu.vvp
```

## Version History

- **V1.0** - Initial release
  - AXI4-Lite register interface
  - Programmable instruction execution
  - Full I2C protocol support
  - Collision detection and abort handling
  - Manual override mode
  - AXI-Stream data output
  - Watchdog timer support

## License

LGPL - See source files for full license text

## References

- I2C-bus Specification (NXP Semiconductors)
- AXI4-Lite Specification (ARM)
- AXI4-Stream Specification (ARM)
