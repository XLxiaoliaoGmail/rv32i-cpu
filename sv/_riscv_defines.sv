package _riscv_defines;
    // 基本参数定义
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;
    parameter REG_ADDR_WIDTH = 5;
    parameter INSTR_MEM_SIZE = 4096;
    parameter _DEBUG_NO_USE_ = 'x;

    // 操作码定义
    typedef enum logic [6:0] {
        OP_R_TYPE  = 7'b0110011,  // R类型指令
        OP_I_TYPE  = 7'b0010011,  // I类型指令
        OP_LOAD    = 7'b0000011,  // 加载指令
        OP_STORE   = 7'b0100011,  // 存储指令
        OP_BRANCH  = 7'b1100011,  // 分支指令
        OP_JAL     = 7'b1101111,  // JAL指令
        OP_JALR    = 7'b1100111,  // JALR指令
        OP_LUI     = 7'b0110111,  // 高位立即数加载
        OP_AUIPC   = 7'b0010111,  // PC相对地址加载
        OP_FENCE   = 7'b0001111,  // FENCE指令
        OP_SYSTEM  = 7'b1110011   // 系统指令
    } opcode_t;

    // R类型指令的fun3定义
    typedef enum logic [2:0] {
        R_FUN3_ADD_SUB = 3'b000,  // ADD/SUB
        R_FUN3_SLL     = 3'b001,  // 逻辑左移
        R_FUN3_SLT     = 3'b010,  // 有符号小于比较
        R_FUN3_SLTU    = 3'b011,  // 无符号小于比较
        R_FUN3_XOR     = 3'b100,  // 异或
        R_FUN3_SRL_SRA = 3'b101,  // 逻辑/算术右移
        R_FUN3_OR      = 3'b110,  // 或
        R_FUN3_AND     = 3'b111   // 与
    } r_fun3_t;

    // I类型指令的fun3定义
    typedef enum logic [2:0] {
        I_FUN3_ADDI    = 3'b000,  // 立即数加
        I_FUN3_SLLI    = 3'b001,  // 立即数逻辑左移
        I_FUN3_SLTI    = 3'b010,  // 立即数有符号小于比较
        I_FUN3_SLTIU   = 3'b011,  // 立即数无符号小于比较
        I_FUN3_XORI    = 3'b100,  // 立即数异或
        I_FUN3_SRLI_SRAI = 3'b101,// 立即数逻辑/算术右移
        I_FUN3_ORI     = 3'b110,  // 立即数或
        I_FUN3_ANDI    = 3'b111   // 立即数与
    } i_fun3_t;

    // Load类型指令的fun3定义
    typedef enum logic [2:0] {
        LOAD_FUN3_LB   = 3'b000,  // 加载字节
        LOAD_FUN3_LH   = 3'b001,  // 加载半字
        LOAD_FUN3_LW   = 3'b010,  // 加载字
        LOAD_FUN3_LBU  = 3'b100,  // 加载无符号字节
        LOAD_FUN3_LHU  = 3'b101   // 加载无符号半字
    } load_fun3_t;

    // Store类型指令的fun3定义
    typedef enum logic [2:0] {
        STORE_FUN3_SB  = 3'b000,  // 存储字节
        STORE_FUN3_SH  = 3'b001,  // 存储半字
        STORE_FUN3_SW  = 3'b010   // 存储字
    } store_fun3_t;

    // Branch类型指令的fun3定义
    typedef enum logic [2:0] {
        BRANCH_FUN3_BEQ  = 3'b000,  // 相等跳转
        BRANCH_FUN3_BNE  = 3'b001,  // 不等跳转
        BRANCH_FUN3_BLT  = 3'b100,  // 小于跳转
        BRANCH_FUN3_BGE  = 3'b101,  // 大于等于跳转
        BRANCH_FUN3_BLTU = 3'b110,  // 无符号小于跳转
        BRANCH_FUN3_BGEU = 3'b111   // 无符号大于等于跳转
    } branch_fun3_t;

    // System指令的fun3定义
    typedef enum logic [2:0] {
        SYS_FUN3_PRIV   = 3'b000,  // ECALL/EBREAK
        SYS_FUN3_CSRRW  = 3'b001,  // CSR读写
        SYS_FUN3_CSRRS  = 3'b010,  // CSR置位
        SYS_FUN3_CSRRC  = 3'b011,  // CSR清零
        SYS_FUN3_CSRRWI = 3'b101,  // CSR立即数读写
        SYS_FUN3_CSRRSI = 3'b110,  // CSR立即数置位
        SYS_FUN3_CSRRCI = 3'b111   // CSR立即数清零
    } sys_fun3_t;

    // FENCE指令的fun3定义
    typedef enum logic [2:0] {
        FENCE_FUN3_FENCE = 3'b000  // FENCE
    } fence_fun3_t;

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
        ALU_SRA  = 4'b1001,
        ALU_DEBUG_NO_USE = _DEBUG_NO_USE_
    } alu_op_t;

    // 状态编码
    typedef enum logic [2:0] {
        FETCH    = 3'b000,
        DECODE   = 3'b001,
        EXECUTE  = 3'b010,
        MEMORY   = 3'b011,
        WRITEBACK = 3'b100
    } state_t;
endpackage 