`include "_riscv_defines.sv"

module alu_controller
import _riscv_defines::*;
(
    input  logic                    clk,
    input  logic                    rst_n,
    // 控制信号输入
    input  logic [2:0]              current_state,  // 当前状态
    input  opcode_t                 opcode,         // 操作码
    input  logic [2:0]              funct3,         // 功能码3
    input  logic [6:0]              funct7,         // 功能码7
    

    // 数据输入
    input  logic [DATA_WIDTH-1:0]   rs1_data,      // 寄存器1数据
    input  logic [DATA_WIDTH-1:0]   rs2_data,      // 寄存器2数据
    input  logic [DATA_WIDTH-1:0]   imm,           // 立即数
    input  logic [DATA_WIDTH-1:0]   current_pc,    // 当前PC值
    
    // ALU控制输出
    output logic [DATA_WIDTH-1:0]   alu_operand1,  // ALU操作数1
    output logic [DATA_WIDTH-1:0]   alu_operand2,  // ALU操作数2
    output alu_op_t                 alu_op         // ALU操作类型
);
    // ALU操作数和操作类型选择逻辑
    always_comb begin
        case (current_state)
            FETCH: begin
                // PC+4计算
                alu_operand1 = current_pc;
                alu_operand2 = 32'd4;
                alu_op = ALU_ADD;
            end

            DECODE: begin
                case (opcode)
                    OP_JAL, OP_BRANCH: begin
                        // JAL和BRANCH指令：PC + imm
                        alu_operand1 = current_pc;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end
                    
                    OP_JALR: begin
                        // JALR指令：rs1 + imm
                        alu_operand1 = rs1_data;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    default: begin
                        alu_operand1 = 32'hffff;
                        alu_operand2 = 32'hffff;
                        alu_op = ALU_NONE;
                    end
                endcase
            end

            EXECUTE: begin
                case (opcode)

                    OP_R_TYPE: begin
                        // R型指令：使用寄存器值
                        alu_operand1 = rs1_data;
                        alu_operand2 = rs2_data;
                        case (funct3)
                            R_FUN3_ADD_SUB:  alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                            R_FUN3_AND:      alu_op = ALU_AND;
                            R_FUN3_OR:       alu_op = ALU_OR; 
                            R_FUN3_XOR:      alu_op = ALU_XOR;
                            R_FUN3_SLL:      alu_op = ALU_SLL;
                            R_FUN3_SRL_SRA:  alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                            R_FUN3_SLT:      alu_op = ALU_SLT;
                            R_FUN3_SLTU:     alu_op = ALU_SLTU;
                            default: begin
                                alu_operand1 = 32'hffff;
                                alu_operand2 = 32'hffff;
                                alu_op = ALU_NONE;
                            end
                        endcase
                    end

                    OP_I_TYPE: begin
                        // I型指令：使用rs1和立即数
                        alu_operand1 = rs1_data;
                        alu_operand2 = imm;
                        case (funct3)
                            I_FUN3_ADDI:     alu_op = ALU_ADD;
                            I_FUN3_ANDI:     alu_op = ALU_AND;
                            I_FUN3_ORI:      alu_op = ALU_OR;
                            I_FUN3_XORI:     alu_op = ALU_XOR;
                            I_FUN3_SLTI:     alu_op = ALU_SLT;
                            I_FUN3_SLTIU:    alu_op = ALU_SLTU;
                            I_FUN3_SLLI:     alu_op = ALU_SLL;
                            I_FUN3_SRLI_SRAI:alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                            default: begin
                                alu_operand1 = 32'hffff;
                                alu_operand2 = 32'hffff;
                                alu_op = ALU_NONE;
                            end
                        endcase
                    end

                    OP_LOAD, OP_STORE: begin
                        // 加载/存储指令：计算地址
                        alu_operand1 = rs1_data;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    OP_BRANCH: begin
                        alu_operand1 = rs1_data;
                        alu_operand2 = rs2_data;
                        
                        case(funct3)
                            BRANCH_FUN3_BEQ:  alu_op = ALU_SUB;  // beq: 相等判断用减法
                            BRANCH_FUN3_BNE:  alu_op = ALU_SUB;  // bne: 不相等判断用减法
                            BRANCH_FUN3_BLT:  alu_op = ALU_SLT;  // blt: 有符号小于比较
                            BRANCH_FUN3_BGE:  alu_op = ALU_SLT;  // bge: 有符号大于等于用小于的反
                            BRANCH_FUN3_BLTU: alu_op = ALU_SLTU; // bltu: 无符号小于比较
                            BRANCH_FUN3_BGEU: alu_op = ALU_SLTU; // bgeu: 无符号大于等于用小于的反
                            default: begin
                                alu_operand1 = 32'hffff;
                                alu_operand2 = 32'hffff;
                                alu_op = ALU_NONE;
                            end
                        endcase

                    end

                    OP_LUI: begin
                        // LUI：直接传递立即数
                        alu_operand1 = 32'b0;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    OP_AUIPC: begin
                        // AUIPC：PC加立即数
                        alu_operand1 = current_pc;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    OP_JAL: begin
                        // JAL：PC + imm
                        alu_operand1 = current_pc;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    OP_JALR: begin
                        // JALR：rs1 + imm
                        alu_operand1 = rs1_data;
                        alu_operand2 = imm;
                        alu_op = ALU_ADD;
                    end

                    OP_FENCE, OP_SYSTEM: begin
                        alu_operand1 = rs1_data;
                        alu_operand2 = rs2_data;
                        alu_op = ALU_ADD;
                    end

                    default: begin
                        alu_operand1 = 32'hffff;
                        alu_operand2 = 32'hffff;
                        alu_op = ALU_NONE;
                    end
                endcase
            end
            default: begin
                alu_operand1 = 32'hffff;
                alu_operand2 = 32'hffff;
                alu_op = ALU_NONE;
            end
        endcase
    end
endmodule 