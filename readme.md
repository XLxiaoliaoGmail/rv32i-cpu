# RISC-V RV32I Multi-cycle CPU Design

## Project Overview
This is a 32-bit multi-cycle CPU design project based on the RISC-V-32I instruction set. Implemented in SystemVerilog hardware description language, it supports the basic instruction system, including arithmetic operations, branch jumps, and memory access operations. The design features instruction and memory caching, with ALU performing different functions at different stages, and all modules communicating through request-response mechanisms.

Simulation verification was performed using Modelsim.

![image](https://github.com/user-attachments/assets/52b76d8e-1400-4e2a-85b7-5071cf069289)

## **Core Features**
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
  - Functional modules defined through standardized interfaces
  - Centralized control with direct communication between modules and control unit
  - Request-response communication pattern ensuring reliable data transfer

- **Resource Optimization**
  - Single ALU with multiple functions supporting:
    - Basic arithmetic operations
    - Conditional branch evaluation
    - Jump address calculation
    - Memory address offset computation

- **Performance Optimization**
  - Implementation of instruction and data caching mechanisms
  - Simulation of certain real hardware delay characteristics

## Module Description

### Control Unit (control_unit)
The control unit is the central hub of the CPU, coordinating the operation of various functional modules:
- Implements PC (Program Counter) update control
- Handles branch and jump instruction control logic
- Coordinates module requests and responses
- Implements datapath control
- Manages execution stage state transitions

### ALU Module (alu)
Arithmetic Logic Unit supporting all operations in the RISC-V basic integer instruction set:
- Basic arithmetic operations: add, subtract, AND, OR, XOR
- Shift operations: logical left shift, logical right shift, arithmetic right shift
- Comparison operations: signed and unsigned comparisons
- Simulated computation delay
- Request-response communication mechanism

### Instruction Cache (icache)
Instruction cache module optimizing instruction fetch efficiency:
- Implements 2-way set-associative cache structure
- Uses LRU replacement strategy
- AXI bus interface

### Instruction Memory (imem)
Instruction memory module:
- Supports program loading from file
- AXI bus interface
- Simulated memory access delay

### Data Cache (dcache)
Data cache module optimizing data access efficiency:
- Implements 2-way set-associative cache structure
- Uses LRU replacement strategy with write-back before replacement
- AXI bus interface
- Supports different granularity of data access (byte, half-word, word)
- Implements data sign extension
- Supports byte-aligned access operations

### Data Memory (dmem)
Data memory module:
- AXI bus interface
- Simulated memory operation delay

### Instruction Decoder (idecoder)
Instruction decode module completing instruction parsing:
- Supports decoding of all RISC-V RV32I basic instruction set
- Extracts operation codes, function codes, register addresses, and immediates
- Implements correct instruction field extension
- Simulated decode delay

### Register File (reg_file)
General-purpose register group module:
- Supports dual-port read and single-port write
- Implements write priority control
- Supports data forwarding (write-after-read)

### State Machine (state_machine)
Instruction execution state control module:
- Implements five-stage execution state transitions
- Determines execution path based on instruction type
- Controls instruction pipeline advancement
- Handles special instruction state transitions