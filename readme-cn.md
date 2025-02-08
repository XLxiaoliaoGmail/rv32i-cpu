# RV32I 多周期CPU实现

基于RISC-V架构设计实现了支持SV32I指令集的多周期CPU。使用SystemVerilog描述，实现了完整的数据通路和控制单元。每条指令有不同执行阶段，可能包括取指、译码、执行、访存、写回，通过状态机控制每条指令需要执行哪些阶段。内设一控制单元协调各个功能部件的工作，所有主要模块均直接与且仅与控制单元通信，控制更为集中。通过ModelSim进行功能仿真验证，成功执行了运算、数据传输、条件跳转等基础指令。

![diagram](https://github.com/user-attachments/assets/fc700223-306e-4b5f-8352-03abe10515fd)

## 特性

- 支持RV32I基本指令集
- 多周期实现架构
- 模块化设计，代码结构清晰
- 包含完整的测试框架
- SystemVerilog实现

## 目录结构

```
sv/
├── _riscv_defines.sv      # RISC-V 指令和控制信号定义
├── riscv_core.sv          # CPU核心模块
├── control_unit.sv        # 控制单元
├── state_machine.sv       # 状态机实现
├── alu.sv                 # 算术逻辑单元
├── alu_controller.sv      # ALU控制器
├── data_memory.sv         # 数据存储器
├── instruction_memory.sv  # 指令存储器
├── instruction_decoder.sv # 指令解码器
├── pc.sv                  # 程序计数器
├── register_file.sv       # 寄存器文件
├── _tb_riscv_core.sv      # 顶层测试模块
└── test/                  # 测试文件目录
```

## 模块说明

- **Core (riscv_core.sv)**: CPU的顶层模块，整合了所有功能部件
- **控制单元 (control_unit.sv)**: 负责生成控制信号，协调各个部件的工作
- **状态机 (state_machine.sv)**: 实现多周期CPU的状态转换
- **ALU (alu.sv)**: 执行算术逻辑运算
- **数据存储器 (data_memory.sv)**: 用于数据存储
- **指令存储器 (instruction_memory.sv)**: 存储程序指令
- **寄存器文件 (register_file.sv)**: 实现CPU通用寄存器组

## 指令支持

支持RV32I基本指令集，包括：
- 算术运算指令
- 逻辑运算指令
- 数据传输指令
- 分支跳转指令

## 测试

项目包含完整的测试框架：
- 提供了基础的测试程序
- 支持ALU运算测试
- 支持分支跳转测试
- 支持内存访问测试
