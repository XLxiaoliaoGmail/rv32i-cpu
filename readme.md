# Language

For chinese version, click [here](https://github.com/XLxiaoliaoGmail/rv32i-cpu/blob/mul-cycle/readme-cn.md).

阅读中文版本，点击[这里](https://github.com/XLxiaoliaoGmail/rv32i-cpu/blob/mul-cycle/readme-cn.md)。

# RV32I Multi-cycle CPU Implementation

A multi-cycle CPU supporting the RV32I instruction set based on RISC-V architecture. Implemented in SystemVerilog, it features a complete datapath and control unit. Each instruction has different execution stages, which may include fetch, decode, execute, memory access, and write-back, controlled by a state machine that determines which stages each instruction needs to execute. A central control unit coordinates the operation of all functional components, with all major modules communicating directly and exclusively with the control unit for more centralized control. Functional simulation verification was performed using ModelSim, successfully executing basic instructions including arithmetic operations, data transfer, and conditional jumps.

![diagram](https://github.com/user-attachments/assets/ee11d5d4-11f7-4229-b856-445513f70fb4)


## Features

- Supports RV32I basic instruction set
- Multi-cycle implementation architecture
- Modular design with clear code structure
- Complete testing framework
- Implemented in SystemVerilog

## Directory Structure

```
sv/
├── _riscv_defines.sv      # RISC-V instruction and control signal definitions
├── riscv_core.sv          # CPU core module
├── control_unit.sv        # Control unit
├── state_machine.sv       # State machine implementation
├── alu.sv                 # Arithmetic Logic Unit
├── alu_controller.sv      # ALU controller
├── data_memory.sv         # Data memory
├── instruction_memory.sv  # Instruction memory
├── instruction_decoder.sv # Instruction decoder
├── pc.sv                  # Program counter
├── register_file.sv       # Register file
├── _tb_riscv_core.sv      # Top-level test module
└── test/                  # Test files directory
```

## Module Description

- **Core (riscv_core.sv)**: Top-level CPU module integrating all functional components
- **Control Unit (control_unit.sv)**: Generates control signals and coordinates component operations
- **State Machine (state_machine.sv)**: Implements state transitions for the multi-cycle CPU
- **ALU (alu.sv)**: Executes arithmetic and logical operations
- **Data Memory (data_memory.sv)**: For data storage
- **Instruction Memory (instruction_memory.sv)**: Stores program instructions
- **Register File (register_file.sv)**: Implements CPU general-purpose registers

## Instruction Support

Supports the RV32I basic instruction set, including:
- Arithmetic instructions
- Logical instructions
- Data transfer instructions
- Branch and jump instructions

## Testing

The project includes a complete testing framework:
- Provides basic test programs
- Supports ALU operation testing
- Supports branch and jump testing
- Supports memory access testing
