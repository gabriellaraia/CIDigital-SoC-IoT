# Timer Peripheral

A 32-bit system tick timer with prescaler and postscaler support, designed for SoC integration via AXI4-Lite interface. Provides periodic and one-shot timing with interrupt generation.

## Features

- **AXI4-Lite Interface**: Standard 32-bit bus interface for easy SoC integration
- **32-bit Counter**: Full 32-bit up-counter with programmable compare value
- **16-bit Prescaler**: Clock division (N:1) for configurable tick rates
- **8-bit Postscaler**: Match event division (M:1) for interrupt rate control
- **Auto-Reload Mode**: Optional periodic operation with automatic counter reset
- **One-Shot Mode**: Single-shot timing without auto-reload
- **Sticky Status Flags**: Write-1-to-Clear (W1C) match and interrupt pending flags
- **Interrupt Output**: Configurable interrupt generation on match events

## Register Map

All registers are 32-bit wide.

| Offset | Register | Name | Access | Description |
|--------|----------|------|--------|-------------|
| 0x08 | TIMER_CTRL0 | Control | R/W | Timer enable, autoreload, interrupt enable |
| 0x0C | TIMER_CMP0 | Compare Value | R/W | Counter compare value |
| 0x10 | TIMER_VAL0 | Current Value | R/W | Current counter value (read/write) |
| 0x20 | TIMER_PRESCALE0 | Prescaler | R/W | Prescaler divider (N) |
| 0x24 | TIMER_POSTSCALE0 | Postscaler | R/W | Postscaler divider (M) |
| 0x28 | TIMER_STATUS0 | Status | R/W | Match pending and IRQ pending flags (W1C) |

## Register Descriptions

### TIMER_CTRL0 - Control Register (Offset: 0x08)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 3 | AUTORELOAD | 0 | R/W | Auto-reload enable. 1 = Counter resets to 0 on match |
| 2 | ENABLE | 0 | R/W | Timer enable. 1 = Counter increments |
| 1 | INTERRUPT | 0 | R/W | Interrupt enable. 1 = Enable interrupt generation |
| 0 | - | 0 | R | Reserved |

### TIMER_CMP0 - Compare Value (Offset: 0x0C)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 31:0 | VALUE | 0 | R/W | Compare value. Match occurs when counter equals this value |

### TIMER_VAL0 - Current Value (Offset: 0x10)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 31:0 | CURRENT | 0 | R/W | Current counter value. Can be read or written to load specific value |

**Note:** Writing to VAL0 loads the counter and resets the prescaler counter.

### TIMER_PRESCALE0 - Prescaler (Offset: 0x20)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 15:0 | DIV | 1 | R/W | Prescaler divider. Value of 0 is treated as 1. Counter increments every N clock cycles |

**Example:** DIV = 5 means counter increments every 5 clock cycles.

### TIMER_POSTSCALE0 - Postscaler (Offset: 0x24)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 7:0 | DIV | 1 | R/W | Postscaler divider. Value of 0 is treated as 1. IRQ generated every M matches |

**Example:** DIV = 3 means interrupt generated every 3rd match event.

### TIMER_STATUS0 - Status (Offset: 0x28)

| Bit | Field | Default | Access | Description |
|-----|-------|---------|--------|-------------|
| 1 | IRQ_PEND | 0 | R/W | IRQ Pending. Set when postscaler expires and interrupt enabled. Write 1 to clear |
| 0 | MATCH_PEND | 0 | R/W | Match Pending. Set when counter reaches compare value. Write 1 to clear |

**Note:** Status flags are sticky and require writing 1 to the bit to clear (W1C).

## Usage Guide

### Basic One-Shot Timer

```c
// 1. Set compare value (count to 1000)
TIMER_CMP0 = 1000;

// 2. Configure prescaler (optional, N=1 means no division)
TIMER_PRESCALE0 = 1;

// 3. Set postscaler (optional, M=1 means every match)
TIMER_POSTSCALE0 = 1;

// 4. Enable timer
TIMER_CTRL0 = (1 << 2);              // ENABLE = 1

// 5. Poll for match
while (!(TIMER_STATUS0 & 0x1));      // Wait for MATCH_PEND

// 6. Clear status
TIMER_STATUS0 = 0x1;                 // Clear match pending
```

### Periodic Timer with Interrupt

```c
// 1. Configure for 1ms period at 100MHz
// Period = (CMP + 1) * PRESCALE / Fclk
// For 1ms: CMP = 99999, PRESCALE = 1
TIMER_CMP0 = 99999;
TIMER_PRESCALE0 = 1;

// 2. Enable interrupts
TIMER_POSTSCALE0 = 1;
TIMER_CTRL0 = (1 << 1)               // INTERRUPT = 1
            | (1 << 2)               // ENABLE = 1
            | (1 << 3);              // AUTORELOAD = 1

// 3. In interrupt handler
if (TIMER_STATUS0 & 0x2) {           // IRQ_PEND set
    TIMER_STATUS0 = 0x3;             // Clear both flags (W1C)
    // Handle timer event
}
```

### Using Postscaler (Every N Matches)

```c
// Generate interrupt every 10 matches
TIMER_CMP0 = 1000;
TIMER_PRESCALE0 = 1;
TIMER_POSTSCALE0 = 10;               // IRQ every 10th match

TIMER_CTRL0 = (1 << 1) | (1 << 2) | (1 << 3);

// With autoreload, this creates a periodic interrupt
// with period = 10 * (CMP + 1) * PRESCALE / Fclk
```

### Manual Counter Loading

```c
// Load counter with specific start value
TIMER_VAL0 = 500;                    // Start counting from 500
TIMER_CMP0 = 1000;                   // Match at 1000
TIMER_PRESCALE0 = 1;

TIMER_CTRL0 = (1 << 2);              // Start timer

// Timer will count 500 -> 1000 (500 cycles)
```

## SoC Integration Guide

### Interface Overview

The `timer` module provides an AXI4-Lite slave interface for register access and a single interrupt output.

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

**Interrupt:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| intr_o | Output | 1 | Interrupt output (active-high) |

### Address Decoding

The module only decodes the lower 8 bits of the address (`cfg_awaddr_i[7:0]` and `cfg_araddr_i[7:0]`). The system integrator must provide address decoding to route transactions to this peripheral based on upper address bits.

**Example Address Map:**
```
Base Address: 0x4001_0000
Address Range: 0x4001_0000 - 0x4001_00FF (256 bytes)
```

**Integration Example:**
```verilog
// Address decoder
wire timer_sel = (axi_addr[31:12] == 20'h40010);  // 0x4001_0000

timer u_timer (
    .clk_i          (sys_clk),
    .rst_i          (sys_rst),
    
    // AXI4-Lite connections
    .cfg_awvalid_i  (timer_sel & axi_awvalid),
    .cfg_awaddr_i   (axi_awaddr),
    .cfg_awready_o  (timer_awready),
    // ... other AXI signals
    
    // Interrupt
    .intr_o         (timer_irq)
);
```

### Clock Considerations

- **System Clock**: `clk_i` drives the AXI4-Lite interface and counter
- **Tick Rate**: Counter increments every `PRESCALE` clock cycles
- **Interrupt Rate**: With postscaler, interrupt every `PRESCALE * (CMP + 1) * POSTSCALE` cycles

### Reset Strategy

The peripheral uses active-high synchronous reset (`rst_i`). All registers reset to 0 (or default values):
- CTRL0: 0x0000_0000 (disabled)
- CMP0: 0x0000_0000
- VAL0: 0x0000_0000
- PRESCALE0: 0x0000_0001 (no division)
- POSTSCALE0: 0x0000_0001 (no division)
- STATUS0: 0x0000_0000

**Recommended Reset Sequence:**
1. Assert system reset
2. Wait for clock cycles
3. Deassert reset
4. Configure CMP0, PRESCALE0, POSTSCALE0
5. Enable timer via CTRL0

### Timing Considerations

- **AXI4-Lite Latency**: Single-cycle response for both reads and writes
- **Counter Increment**: Every `PRESCALE` clock cycles when enabled
- **Match Detection**: Single-cycle pulse when counter equals CMP0
- **Interrupt Latency**: Up to 1 clock cycle after postscaler expiration

### Interrupt Routing

Connect `intr_o` to the system interrupt controller. The interrupt is level-triggered and active-high while both `IRQ_PEND` and `INTERRUPT` enable are set. Software must clear the interrupt by writing to `STATUS0`.

**Note:** The `intr_o` signal is gated by the `ENABLE` bit - when timer is disabled, `intr_o` goes low even if `IRQ_PEND` is set.

## File Structure

```
design/rtl/periph/timer/
├── timer.v              # Main timer module
├── timer_defs.v         # Register address and bit definitions
├── README.md            # This file
└── tb/
    ├── timer_tb.v       # Comprehensive testbench
    ├── Makefile         # Build automation
    └── README.md        # Testbench documentation
```

## Testing

A comprehensive testbench is available in the `tb/` directory with the following test scenarios:

1. **Reset Verification** - Validates all register defaults
2. **Register Access** - Tests read/write to all registers
3. **Basic Timer Operation** - One-shot mode functionality
4. **Auto-Reload Mode** - Periodic timer operation
5. **Prescaler Functionality** - Clock division testing
6. **Postscaler Functionality** - Interrupt rate division
7. **Interrupt Generation** - Enable/disable and clearing
8. **Status Register W1C** - Write-1-to-clear behavior
9. **Combined Scaling** - Prescaler + postscaler together
10. **Manual Counter Load** - Loading arbitrary counter values

### Running the Local Testbench

```bash
cd tb
make sim    # Compile and run simulation
make view   # View waveforms in GTKWave
make lint   # Run Verilator lint
```

## Version History

- **V1.0** - Initial release
  - AXI4-Lite interface
  - 32-bit counter
  - 16-bit prescaler
  - 8-bit postscaler
  - Auto-reload mode
  - Sticky status flags (W1C)
  - Interrupt support

## License

BSD - See source files for full license text

## References

- AXI4-Lite Specification (ARM)
- Ultra-Embedded timer design
