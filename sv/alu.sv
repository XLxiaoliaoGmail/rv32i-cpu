`include "_riscv_defines.sv"

module alu
import _riscv_defines::*;
(
    input  logic [DATA_WIDTH-1:0] operand1,
    input  logic [DATA_WIDTH-1:0] operand2,
    input  alu_op_t               alu_op,
    output logic [DATA_WIDTH-1:0] result
);

    logic signed [DATA_WIDTH-1:0] operand1_signed;
    logic signed [DATA_WIDTH-1:0] operand2_signed;
    
    assign operand1_signed = operand1;
    assign operand2_signed = operand2;

    // 计算结果
    always_comb begin
        unique case (alu_op)
            ALU_ADD:  result = operand1 + operand2;
            ALU_SUB:  result = operand1 - operand2;
            ALU_AND:  result = operand1 & operand2;
            ALU_OR:   result = operand1 | operand2;
            ALU_XOR:  result = operand1 ^ operand2;
            ALU_SLT:  result = {31'b0, operand1_signed < operand2_signed};
            ALU_SLTU: result = {31'b0, operand1 < operand2};
            ALU_SLL:  result = operand1 << operand2[4:0];
            ALU_SRL:  result = operand1 >> operand2[4:0];
            ALU_SRA:  result = operand1_signed >>> operand2[4:0];
            default:  result = '0;
        endcase
    end
endmodule 