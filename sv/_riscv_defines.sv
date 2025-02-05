package _riscv_defines;
    // 基本参数定义
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter REG_ADDR_WIDTH = 5;
    
    // 操作码定义
    parameter OP_R_TYPE  = 7'b0110011;  // R类型指令
    parameter OP_I_TYPE  = 7'b0010011;  // I类型指令
    parameter OP_LOAD    = 7'b0000011;  // 加载指令
    parameter OP_STORE   = 7'b0100011;  // 存储指令
    parameter OP_BRANCH  = 7'b1100011;  // 分支指令
    parameter OP_JAL     = 7'b1101111;  // JAL指令
    parameter OP_JALR    = 7'b1100111;  // JALR指令
    parameter OP_LUI     = 7'b0110111;  // 高位立即数加载
    parameter OP_AUIPC   = 7'b0010111;  // PC相对地址加载

    // ALU操作定义
    typedef enum logic [3:0] {
        ALU_ADD  = 4'b0000,
        ALU_SUB  = 4'b0001,
        ALU_AND  = 4'b0010,
        ALU_OR   = 4'b0011,
        ALU_XOR  = 4'b0100,
        ALU_SLT  = 4'b0101,
        ALU_SLTU = 4'b0110,
        ALU_SLL  = 4'b0111,
        ALU_SRL  = 4'b1000,
        ALU_SRA  = 4'b1001
    } alu_op_t;
endpackage 