`include "_riscv_defines.sv"

module riscv_core
import _riscv_defines::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    output logic [DATA_WIDTH-1:0] instruction
);

    // Internal signal definitions
    logic [DATA_WIDTH-1:0]     now_pc;      // Current program counter value
    logic [DATA_WIDTH-1:0]     next_pc;         // Next program counter value
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;        // Source register 1 address
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;        // Source register 2 address
    logic [REG_ADDR_WIDTH-1:0] rd_addr;         // Destination register address
    opcode_t                   opcode;          // Instruction opcode
    logic [6:0]                funct7;          // Function code 7
    logic [2:0]                funct3;          // Function code 3
    logic [DATA_WIDTH-1:0]     imm;             // Immediate value
    logic [DATA_WIDTH-1:0]     rs1_data;        // Source register 1 data
    logic [DATA_WIDTH-1:0]     rs2_data;        // Source register 2 data
    logic [DATA_WIDTH-1:0]     alu_operand1;    // ALU operand 1
    logic [DATA_WIDTH-1:0]     alu_operand2;    // ALU operand 2
    logic [DATA_WIDTH-1:0]     alu_result;      // ALU calculation result
    logic [DATA_WIDTH-1:0]     mem_rdata;       // Memory read data
    logic [DATA_WIDTH-1:0]     reg_wb_data;     // Write back data

    // Control signals
    logic                      pc_write_en;           // PC write enable
    logic                      reg_write_en;          // Register write enable
    logic                      mem_we;          // Memory write enable
    alu_op_t                   alu_op;          // ALU operation type
    mem_size_t                 mem_size;        // Memory access size type
    logic                      mem_sign;        // Memory access sign extension

    control_unit ctrl_unit (
        .clk(clk),
        .rst_n(rst_n),
        // input
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .now_pc(now_pc),
        .imm(imm),
        .alu_result(alu_result),
        .mem_rdata(mem_rdata),
        // output
        .reg_write_en(reg_write_en),
        .reg_wb_data(reg_wb_data),

        .alu_operand1(alu_operand1),
        .alu_operand2(alu_operand2),
        .alu_op(alu_op),
        
        .mem_size(mem_size),
        .mem_sign(mem_sign),
        .mem_we(mem_we),

        .next_pc(next_pc),
        .pc_write_en(pc_write_en)
    );

    // Program counter
    pc pc_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .we         (pc_write_en),
        .next_pc    (next_pc),
        .now_pc (now_pc)
    );

    // Instruction memory
    instruction_memory imem (
        .clk         (clk),
        .addr        (now_pc),
        .instruction (instruction)
    );

    // Instruction decoder
    instruction_decoder decoder (
        .instruction(instruction),
        .rs1_addr   (rs1_addr),
        .rs2_addr   (rs2_addr),
        .rd_addr    (rd_addr),
        .opcode     (opcode),
        .funct3     (funct3),
        .funct7     (funct7),
        .imm        (imm)
    );

    // Register file
    register_file reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (reg_write_en),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (reg_wb_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // ALU
    alu alu_inst (
        .operand1   (alu_operand1),
        .operand2   (alu_operand2),
        .alu_op     (alu_op),
        .result     (alu_result)
    );

    // Data memory
    data_memory dmem (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (mem_we),
        .addr     (alu_result),
        .wdata    (rs2_data),
        .size     (mem_size),
        .sign     (mem_sign),
        .rdata    (mem_rdata)
    );

endmodule 