`include "_riscv_defines.sv"

// RISC-V 指令格式:
//
// R-type format (Register-Register)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |   funct7   |  rs2   |  rs1   |funct3|   rd    | opcode |
// 
// I-type format (Immediate-Register)
// 31                   20 19    15 14  12 11      7 6       0
// |       imm[11:0]      |  rs1   |funct3|   rd    | opcode |
//
// S-type format (Store)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |  imm[11:5] |  rs2   |  rs1   |funct3|imm[4:0] | opcode |
//
// B-type format (Branch)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |imm[12|10:5]|  rs2   |  rs1   |funct3|imm[4:1|11]|opcode|
//
// U-type format (Upper Immediate)
// 31                                  12 11      7 6      0
// |              imm[31:12]             |   rd    | opcode |
//
// J-type format (Jump)
// 31                                  12 11      7 6      0
// |        imm[20|10:1|11|19:12]        |   rd    | opcode |


module instruction_decoder
import _riscv_defines::*;
(
    input  logic [31:0]               instruction,
    output logic [REG_ADDR_WIDTH-1:0] rs1_addr,
    output logic [REG_ADDR_WIDTH-1:0] rs2_addr,
    output logic [REG_ADDR_WIDTH-1:0] rd_addr,
    output logic [6:0]                opcode,
    output logic [2:0]                funct3,
    output logic [6:0]                funct7,
    output logic [DATA_WIDTH-1:0]     imm
);
    // 指令字段提取
    assign opcode = instruction[6:0];

    // 根据指令类型选择性地提取字段
    always_comb begin
        // 默认值
        rs1_addr = '0;
        rs2_addr = '0;
        rd_addr = '0;
        funct3 = '0;
        funct7 = '0;
        imm = '0;

        case (opcode)
            // R型指令
            OP_R_TYPE: begin
                rd_addr = instruction[11:7];
                funct3 = instruction[14:12];
                rs1_addr = instruction[19:15];
                rs2_addr = instruction[24:20];
                funct7 = instruction[31:25];
            end

            // I-type format (Immediate-Register)
            // 31                   20 19    15 14  12 11      7 6       0
            // |       imm[11:0]      |  rs1   |funct3|   rd    | opcode |
            OP_I_TYPE, OP_LOAD, OP_JALR: begin
                rd_addr = instruction[11:7];
                funct3 = instruction[14:12];
                rs1_addr = instruction[19:15];
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S型指令
            OP_STORE: begin
                funct3 = instruction[14:12];
                rs1_addr = instruction[19:15];
                rs2_addr = instruction[24:20];
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // B型指令
            OP_BRANCH: begin
                funct3 = instruction[14:12];
                rs1_addr = instruction[19:15];
                rs2_addr = instruction[24:20];
                imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], 
                      instruction[11:8], 1'b0};
            end

            // J-type format (Jump)
            // 31                                  12 11      7 6      0
            // |        imm[20|10:1|11|19:12]        |   rd    | opcode |
            OP_JAL: begin
                rd_addr = instruction[11:7];
                imm = {
                    {12{instruction[31]}},    // 符号扩展 [31:20]
                    instruction[19:12],       // imm[19:12]
                    instruction[20],          // imm[11]
                    instruction[30:21],       // imm[10:1]
                    1'b0                      // imm[0]
                };
            end

            // U型指令
            OP_LUI, OP_AUIPC: begin
                rd_addr = instruction[11:7];
                imm = {instruction[31:12], 12'b0};
            end

            default: begin
                rs1_addr = '0;
                rs2_addr = '0;
                rd_addr = '0;
                funct3 = '0;
                funct7 = '0;
                imm = '0;
            end
        endcase
    end

endmodule