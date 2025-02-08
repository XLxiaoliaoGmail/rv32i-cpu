# RV32I 多周期CPU实现

这是一个基于SystemVerilog实现的RISC-V RV32I多周期CPU。该CPU支持RV32I基本指令集，采用多周期实现方式，具有清晰的状态机控制和模块化设计。

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