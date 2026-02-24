# AXI4-Lite GPIO Peripheral

A simple and flexible AXI4-Lite compliant General Purpose Input/Output (GPIO) module. This peripheral supports a configurable number of input and output bits, providing a register-based interface for bitwise operations (Set, Clear, Toggle) on outputs and interrupt-driven event detection on inputs.

## Features

- **AXI4-Lite Interface**: Standard 32-bit bus interface for easy SoC integration.
- **Configurable Widths**: Independent parameters for number of output (`NOUT`) and input (`NIN`) bits.
- **Bitwise Output Control**: Dedicated registers for Load, Set, Clear, and Toggle operations.
- **Input Event Detection**: Hardware detection of input toggles with a dedicated status register.
- **Interrupt Support**: Configurable interrupt masking for input toggle events.
- **CDC Support**: Two-register Clock Domain Crossing (CDC) for asynchronous input signals.
- **Skid Buffer**: Optional skid buffer (`OPT_SKIDBUFFER`) to increase bus throughput to 100%.
- **Low Power Option**: Optional low power mode (`OPT_LOWPOWER`) to minimize signal toggling.

## Register Map

All registers are 32-bit wide. The address space is 32 bytes (5-bit address width).

| Offset | Register | Name | Access | Description |
|--------|----------|------|--------|-------------|
| 0x00 | GPIO_LOAD | Output Load | R/W | Overwrite all output bits |
| 0x04 | GPIO_SET | Output Set | W | Set specific output bits (OR operation) |
| 0x08 | GPIO_CLEAR | Output Clear | W | Clear specific output bits (AND NOT operation) |
| 0x0C | GPIO_TOGGLE | Output Toggle | W | Toggle specific output bits (XOR operation) |
| 0x10 | GPIO_INPUT | Input Data | R | Current state of input pins (after CDC) |
| 0x14 | GPIO_CHANGED | Toggle Status | R/W1C | Bits set if input toggled. Write 1 to clear. |
| 0x18 | GPIO_MASK | Interrupt Mask | R/W | 1 = Mask interrupt for corresponding input |
| 0x1C | GPIO_INT | Active Interrupts | R | AND of Toggle Status and inverted Mask |

*Note: If `NIN == 0`, registers from 0x10 to 0x1C repeat the functionality of 0x00 to 0x0C.*

## Register Descriptions

### GPIO_LOAD (Offset: 0x00)
Writing to this register overwrites the `o_gpio` output bits directly with the written value.

### GPIO_SET (Offset: 0x04)
For every bit set in the write data, the corresponding bit in `o_gpio` will be set to 1.
`OUTPUT[k] = OLD_BIT[k] | NEW_BIT[k]`

### GPIO_CLEAR (Offset: 0x08)
For every bit set in the write data, the corresponding bit in `o_gpio` will be cleared to 0.
`OUTPUT[k] = OLD_BIT[k] & (~NEW_BIT[k])`

### GPIO_TOGGLE (Offset: 0x0C)
For every bit set in the write data, the corresponding bit in `o_gpio` will be inverted.
`OUTPUT[k] = OLD_BIT[k] ^ NEW_BIT[k]`

### GPIO_INPUT (Offset: 0x10)
Returns the current state of the `i_gpio` pins. Signals pass through a two-stage synchronizer to prevent metastability.

### GPIO_CHANGED (Offset: 0x14)
A bit is set in this register if the associated input bit has toggled since the last clear. Write a '1' to a bit to clear its status.

### GPIO_MASK (Offset: 0x18)
Interrupt mask register. If a bit is set to '1', the corresponding input toggle will **not** trigger an interrupt on `o_int`.

### GPIO_INT (Offset: 0x1C)
Read-only register showing which input toggles are currently triggering an interrupt. It is the bitwise AND of `GPIO_CHANGED` and `~GPIO_MASK`.

## Usage Guide

### Basic Output Control

```c
// 1. Set all outputs to a specific value
GPIO_LOAD = 0x000000FF;

// 2. Set bit 8 without affecting others
GPIO_SET = (1 << 8);

// 3. Clear bit 0
GPIO_CLEAR = (1 << 0);

// 4. Toggle bit 4
GPIO_TOGGLE = (1 << 4);
```

### Handling Input Interrupts

```c
// 1. Configure Mask (Enable interrupts for bits 0 and 1)
GPIO_MASK = ~0x00000003;

// 2. In Interrupt Service Routine (ISR)
uint32_t status = GPIO_INT;
if (status & 0x1) {
    // Handle input 0 toggle
    GPIO_CHANGED = 0x1; // Clear status
}
```

## SoC Integration Guide

### Port List

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| S_AXI_ACLK | Input | 1 | System Clock |
| S_AXI_ARESETN | Input | 1 | Active-low Synchronous Reset |
| S_AXI_AW* | Input/Output | - | AXI4-Lite Write Address Channel |
| S_AXI_W* | Input/Output | - | AXI4-Lite Write Data Channel |
| S_AXI_B* | Input/Output | - | AXI4-Lite Write Response Channel |
| S_AXI_AR* | Input/Output | - | AXI4-Lite Read Address Channel |
| S_AXI_R* | Input/Output | - | AXI4-Lite Read Data Channel |
| o_gpio | Output | NOUT | GPIO Output Pins |
| i_gpio | Input | NIN | GPIO Input Pins |
| o_int | Output | 1 | Interrupt Output (Active High) |

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| NOUT | 30 | Number of output bits |
| NIN | 5 | Number of input bits |
| DEFAULT_OUTPUT | 0 | Initial value of outputs after reset |
| OPT_SKIDBUFFER | 1'b1 | Enable skid buffer for 100% throughput |
| OPT_LOWPOWER | 0 | Enable low power optimizations |

## Running the Local Testbench

This directory includes `tb_axilgpio.v` for quick functional checks.

```bash
cd design/rtl/periph/gpio
iverilog -g2012 -o tb_axilgpio.vvp axilgpio.v skidbuffer.v tb_axilgpio.v
vvp tb_axilgpio.vvp
```

## File Structure

```
design/rtl/periph/gpio/
├── axilgpio.v      # Main GPIO module with AXI4-Lite interface
├── skidbuffer.v    # AXI-Lite throughput optimization buffer
├── tb_axilgpio.v   # Testbench for the GPIO module
└── README.md       # This file
```

## License

Licensed under the Apache License, Version 2.0. See source files for full license text.
