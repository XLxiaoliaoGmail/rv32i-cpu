# RISC-V RV32I Multi-cycle CPU Design

## Project Overview
This is a 32-bit multi-cycle CPU design project based on the RISC-V-32I instruction set. It is implemented using the SystemVerilog hardware description language and supports a basic instruction set, including basic operations, branch jumps, and memory access operations. The design simulates the delays of some components and implements basic cache functionality. Communication between modules is handled via interfaces.

Simulation and verification were conducted using ModelSim.

![image](https://github.com/user-attachments/assets/52b76d8e-1400-4e2a-85b7-5071cf069289)

## Core Features
- **Multi-cycle Execution**: Instructions are executed in five precisely controlled stages
  - Instruction Fetch
  - Decode
  - Execute
  - Memory Access
  - Write Back

- **Efficient Control Structure**
  - Dynamic scheduling of execution stages using state machine
  - Intelligent stage selection based on instruction type

- **Modular Design**
  - Functional modules connected through standardized interfaces
  - Centralized control with direct communication between modules and control unit
  - Implementation of request-response communication pattern for reliable data transfer

- **Resource Optimization**
  - Single multi-functional ALU supporting:
    - Basic arithmetic operations
    - Conditional branch evaluation
    - Jump address calculation
    - Memory address offset computation

- **Performance Optimization**
  - Implementation of instruction and data cache mechanisms
  - Simulation of certain real hardware delay characteristics

## Module Description

### Control Unit (control_unit)
The control unit is the central hub of the CPU, responsible for coordinating various functional modules:
- Implements PC (Program Counter) update control
- Handles branch and jump instruction control logic
- Coordinates requests and responses between functional modules
- Implements datapath control
- Manages state transitions across execution stages

### ALU Module (alu)
Arithmetic Logic Unit supporting all operations in the RISC-V basic integer instruction set:
- Basic arithmetic operations: add, subtract, AND, OR, XOR
- Shift operations: logical left shift, logical right shift, arithmetic right shift
- Comparison operations: signed and unsigned comparisons
- Hardware delay simulation with configurable operation delays
- Request-response communication mechanism

### Instruction Cache (icache)
Instruction cache module optimizing instruction fetch efficiency:
- Implements 2-way set-associative cache structure
- Uses LRU replacement policy
- Supports AXI bus interface
- Cache line size of 32 bytes (8 instructions)

### Instruction Memory (imem)
Instruction memory module:
- Supports program loading from file
- Implements AXI bus interface
- Provides instruction prefetch functionality
- Simulates memory access delays

### Data Cache (dcache)
Not yet implemented

### Data Memory (dmem)
Main data memory module:
- 4KB storage space
- Supports different granularity of data access (byte, half-word, word)
- Implements sign extension of data
- Supports byte-aligned access operations

### Instruction Decoder (idecoder)
Instruction decode module completing instruction parsing:
- Supports decoding of all RISC-V RV32I basic instruction set
- Extracts operation codes, function codes, register addresses, and immediates
- Implements correct extension of instruction fields
- Simulates decode delay

### Register File (reg_file)
General-purpose register module:
- 32 32-bit general-purpose registers
- Supports dual-port read and single-port write
- Implements write priority control
- Supports data forwarding (write-after-read)

### State Machine (state_machine)
Instruction execution state control module:
- Implements five-stage execution state transitions
- Determines execution path based on instruction type
- Controls instruction pipeline advancement
- Handles state transitions for special instructions
