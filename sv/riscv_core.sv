`include "_riscv_defines.sv"

module riscv_core
import _riscv_defines::*;
(
    input  logic                  clk,
    input  logic                  rst_n,
    output logic [DATA_WIDTH-1:0] instruction
);

    // Internal signal definitions
    logic [DATA_WIDTH-1:0]     current_pc;      // Current program counter value
    logic [DATA_WIDTH-1:0]     next_pc;         // Next program counter value
    logic [DATA_WIDTH-1:0]     pc_plus4;        // PC+4 value for sequential execution
    logic [DATA_WIDTH-1:0]     branch_target;   // Branch target address
    // logic [DATA_WIDTH-1:0]     instruction;     // Current instruction
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;        // Source register 1 address
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;        // Source register 2 address
    logic [REG_ADDR_WIDTH-1:0] rd_addr;         // Destination register address
    logic [6:0]                opcode;          // Instruction opcode
    logic [6:0]                funct7;          // Function code 7
    logic [2:0]                funct3;          // Function code 3
    logic [DATA_WIDTH-1:0]     imm;             // Immediate value
    logic [DATA_WIDTH-1:0]     rs1_data;        // Source register 1 data
    logic [DATA_WIDTH-1:0]     rs2_data;        // Source register 2 data
    logic [DATA_WIDTH-1:0]     alu_operand1;    // ALU operand 1
    logic [DATA_WIDTH-1:0]     alu_operand2;    // ALU operand 2
    logic [DATA_WIDTH-1:0]     alu_result;      // ALU calculation result
    logic                      take_branch;     // Branch/jump decision result
    logic [DATA_WIDTH-1:0]     mem_rdata;       // Memory read data
    logic [DATA_WIDTH-1:0]     wb_data;         // Write back data

    // Control signals
    logic                      reg_write;       // Register write enable
    logic                      mem_write;       // Memory write enable
    logic                      mem_read;        // Memory read enable
    logic                      branch;          // Branch instruction flag
    logic                      jump;            // Jump instruction flag
    logic                      alu_src;         // ALU operand 2 select signal
    logic [1:0]                mem_to_reg;      // Write back data select signal
    alu_op_t                   alu_op;          // ALU operation type
    logic [1:0]                size_type;       // Memory access size type
    logic                      sign_ext;        // Memory access sign extension

    // PC update logic
    assign pc_plus4 = current_pc + 4;
    assign branch_target = current_pc + imm;    // Calculate branch target address
    
    always_comb begin
        if (take_branch) begin
            if (opcode == OP_JALR) begin
                // JALR instruction: jump to rs1 + imm
                next_pc = {alu_result[31:1], 1'b0};  // Force lowest bit to 0
            end else begin
                // Branch instruction and JAL: jump to PC + imm
                next_pc = branch_target;
            end
        end else begin
            next_pc = pc_plus4;  // Sequential execution
        end
    end

    // ALU operand selection
    assign alu_operand1 = rs1_data;
    assign alu_operand2 = alu_src ? imm : rs2_data;

    // Write back data selection
    always_comb begin
        case (mem_to_reg)
            2'b00: wb_data = alu_result;    // ALU result
            2'b01: wb_data = mem_rdata;     // Memory read data
            2'b10: wb_data = pc_plus4;      // PC+4 (for JAL/JALR)
            default: wb_data = alu_result;
        endcase
    end

    // Program counter
    pc pc_inst (
        .clk        (clk),
        .rst_n      (rst_n),
        .next_pc    (next_pc),
        .current_pc (current_pc)
    );

    // Instruction memory
    instruction_memory imem (
        .clk         (clk),
        .addr        (current_pc),
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

    // Control unit
    control_unit ctrl_unit (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .reg_write (reg_write),
        .mem_write (mem_write),
        .mem_read  (mem_read),
        .branch    (branch),
        .jump      (jump),
        .alu_src   (alu_src),
        .mem_to_reg(mem_to_reg),
        .alu_op    (alu_op),
        .size_type (size_type),
        .sign_ext  (sign_ext)
    );

    // Register file
    register_file reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (reg_write),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (wb_data),
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

    // Branch judge unit
    branch_judge branch_judge_inst (
        .funct3     (funct3),
        .rs1_data   (rs1_data),
        .rs2_data   (rs2_data),
        .branch     (branch),
        .jump       (jump),
        .take_branch(take_branch)
    );

    // Data memory
    data_memory dmem (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (mem_write),
        .addr     (alu_result),
        .wdata    (rs2_data),
        .size_type(size_type),
        .sign_ext (sign_ext),
        .rdata    (mem_rdata)
    );

endmodule 