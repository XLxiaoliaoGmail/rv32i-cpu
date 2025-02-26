# RISC-V RV32I Multi-cycle CPU Design

现已有新的流水线版本，请看 [pipeline-branch](https://github.com/XLxiaoliaoGmail/rv32i-cpu/tree/pipeline).

There's a new version of the pipeline available. Please check [pipeline-branch](https://github.com/XLxiaoliaoGmail/rv32i-cpu/tree/pipeline).

## Project Overview
This is a 32-bit multi-cycle CPU design project based on the RISC-V-32I instruction set. Implemented in SystemVerilog hardware description language, it supports the basic instruction system, including arithmetic operations, branch jumps, and memory access operations. The design features instruction and memory caching, with ALU performing different functions at different stages, and all modules communicating through request-response mechanisms.

Simulation verification was performed using Modelsim.

![image](https://github.com/user-attachments/assets/54cfda25-1927-4999-8334-6e444dc1b8f1)


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

- **ALU Multiplexing**
  - Single ALU with multiple functions supporting:
    - Basic arithmetic operations
    - Conditional branch evaluation
    - Jump address calculation
    - Memory address offset computation

- **Cache Characteristics**
  - Implements instruction and data caching mechanisms
  - Communicate with memory using the AXI protocol
  - Instruction cache is read-only
  - Data cache supports both read and write operations
  - The operation of the data cache module is described as follows
  <img src="https://github.com/user-attachments/assets/d87043b4-989d-453e-8d69-1aa2a2666901" width="60%">

### Module Testing

#### Instruction Cache Test (_tb_icache.sv)
- Verify cache miss and cache hit mechanisms
- Test data filling for different cache ways
- Validate LRU (Least Recently Used) replacement policy
- Simulate instruction memory access delay

#### Data Cache Test (_tb_dcache.sv)
- Test read and write operations with different data widths (word/halfword/byte)
- Verify sign extension and zero extension functions
- Test cache replacement strategies
- Validate unaligned access handling
- Test cache coherence

### Overall Functional Testing

Load different test programs through the `imem.sv` module to verify CPU support for various instructions:

#### ALU Instruction Test (alu_test.bin)
- Basic arithmetic operations: addition, subtraction
- Logical operations: AND, OR, XOR
- Shift operations: logical left shift, logical right shift, arithmetic right shift
- Comparison operations: signed and unsigned comparisons

#### Branch and Jump Test (branch_jump_test.bin)
- Conditional branch instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- Unconditional jump (JAL)
- Indirect jump (JALR)
- Branch prediction verification

#### Memory Access Test (mem_test.bin)
- Load instructions for word/halfword/byte (LW, LH, LB, LHU, LBU)
- Store instructions for word/halfword/byte (SW, SH, SB)
- Address alignment check
- Data extension handling

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
