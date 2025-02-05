`include "_riscv_defines.sv"

module control_unit
import _riscv_defines::*;
(
    input  logic [6:0]     opcode,
    input  logic [2:0]     funct3,
    input  logic [6:0]     funct7,
    output logic           reg_write,
    output logic           mem_write,
    output logic           mem_read,
    output logic           branch,
    output logic           jump,           // 添加jump信号
    output logic           alu_src,
    output logic [1:0]     mem_to_reg,
    output alu_op_t        alu_op
);

    always_comb begin
        // 默认值
        reg_write  = 1'b0;
        mem_write  = 1'b0;
        mem_read   = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;    // 默认不跳转
        alu_src    = 1'b0;
        mem_to_reg = 2'b00;
        alu_op     = ALU_ADD;

        unique case (opcode)
            // R类型指令
            OP_R_TYPE: begin
                reg_write = 1'b1;
                unique case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                endcase
            end

            // I类型指令
            OP_I_TYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                unique case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b111: alu_op = ALU_AND;
                    3'b110: alu_op = ALU_OR;
                    3'b100: alu_op = ALU_XOR;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                endcase
            end

            // 加载指令
            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b01;
            end

            // 存储指令
            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
            end

            // 分支指令
            OP_BRANCH: begin
                branch = 1'b1;
                alu_op = ALU_SUB;  // 用于比较
            end

            // JAL指令
            OP_JAL: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                mem_to_reg = 2'b10;  // 选择PC+4
            end

            // JALR指令
            OP_JALR: begin
                reg_write  = 1'b1;
                jump       = 1'b1;
                alu_src    = 1'b1;
                mem_to_reg = 2'b10;  // 选择PC+4
                alu_op     = ALU_ADD; // rs1 + imm
            end

            // LUI指令
            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end

            // AUIPC指令
            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end

            default: begin
                // 保持默认值
            end
        endcase
    end

endmodule 