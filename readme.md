# RISC-V Pipelined CPU Design

## Language
查看中文版，点击 [readme-cn.md](https://github.com/XLxiaoliaoGmail/rv32i-cpu/blob/pipeline/readme-cn.md).

For chinese version, click [readme-cn.md](https://github.com/XLxiaoliaoGmail/rv32i-cpu/blob/pipeline/readme-cn.md).

## Project Overview
This is a 32-bit pipelined CPU design project based on the RISC-V-32I instruction set. Implemented in SystemVerilog hardware description language, it supports the basic instruction system, implements instruction cache and data cache, adopts a classic five-stage pipeline design.

The design has been simulated and verified using Modelsim, validating arithmetic operations, branch jumps, and memory access operations.

## **Datapath**
  - As shown in the figure below, all functional components communicate directly with the control unit. Control logic is determined only within the control unit, ensuring the design independence and operational reliability of each unit. Detailed introduction follows.

  ![image](https://github.com/user-attachments/assets/af1d61ff-fc9c-4dd3-a420-8fe2b73fda86)

## **Pipeline Execution**:

The control unit is the core of the entire system, executing internally in a pipelined manner. It contains four sub-units controlling fetch, decode, execute, memory access, and writeback stages. Each instruction execution passes through these four sub-units sequentially.

Sub-units communicate through handshaking, reading data from the previous unit's output buffer, processing it, and storing it in their own output buffer. This ensures unit design independence and high expandability (e.g., output buffer can be expanded).

Each sub-control unit's internal implementation uses a handshake protocol with the following signal interfaces:
   - Input signals: pre-valid (previous stage data valid), pre-data (previous stage data), post-ready (next stage ready)
   - Output signals: self-valid (current stage data valid), self-data (current stage data), self-ready (current stage ready)

Control flow:
   1. During reset or idle, set self-ready to 1 (indicating ready to receive data), self-valid to 0 (indicating no valid data)
   2. Wait for previous stage data valid (pre-valid=1)
   3. After receiving data, set self-ready to 0, begin processing previous stage data
   4. After data processing completes, set self-data and self-valid to 1
   5. Wait for next stage ready (post-ready=1) and current stage data valid (self-valid=1), next stage will take data, then current stage returns to idle state

This handshake protocol-based design ensures reliable data transmission between pipeline stages and enables independent and convenient module design.

The control logic diagram below shows the workflow of a sub-control unit.

![image](https://github.com/user-attachments/assets/116491fb-fed1-4cee-a630-e25f843d563e)

When hazards occur, certain previous stages will be stalled until the hazard is resolved, including:
  1. Data hazard: If EXECUTE and MEMORY stages write to register addresses that match DECODE stage's read register address, DECODE is stalled.
  2. Control hazard: If DECODE identifies a jump or branch instruction, FETCH is stalled until PC value updates.
     
## Cache
Implement an instruction and data cache mechanism, using the AXI protocol to communicate with memory.

The instruction cache supports only read operations, while the data cache supports both read and write operations.

The operation of the data cache module is described in the diagram below, and the instruction cache follows a similar process.

### Control Flow:
1. Idle, waiting for a valid cache request.
2. If there is a request, check whether the cache hits.
3. If it hits, read/write immediately.
4. If it misses and the cache block to be replaced is dirty, write back the old data and refill with new data from memory.
5. If no write-back is needed, refill with new data directly from memory.
6. If it is a write operation, write to the cache.
  <img src="https://github.com/user-attachments/assets/d87043b4-989d-453e-8d69-1aa2a2666901" width="80%">
