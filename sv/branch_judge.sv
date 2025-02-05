`include "_riscv_defines.sv"

module branch_judge
import _riscv_defines::*;
(
    input  logic [2:0]             funct3,         // 功能码，用于确定分支类型
    input  logic [DATA_WIDTH-1:0]  rs1_data,       // 第一个源操作数
    input  logic [DATA_WIDTH-1:0]  rs2_data,       // 第二个源操作数
    input  logic                   branch,         // 分支指令标志
    input  logic                   jump,           // 跳转指令标志
    output logic                   take_branch     // 是否进行分支/跳转
);

    // 内部信号
    logic signed [DATA_WIDTH-1:0] rs1_signed;
    logic signed [DATA_WIDTH-1:0] rs2_signed;
    logic                        branch_condition;

    // 将输入转换为有符号数，用于有符号比较
    assign rs1_signed = rs1_data;
    assign rs2_signed = rs2_data;

    // 分支条件判断逻辑
    always_comb begin
        if (jump) begin
            // 对于JAL和JALR指令，无条件跳转
            branch_condition = 1'b1;
        end else if (branch) begin
            // 根据funct3判断分支类型
            unique case (funct3)
                3'b000:  branch_condition = (rs1_data == rs2_data);     // BEQ
                3'b001:  branch_condition = (rs1_data != rs2_data);     // BNE
                3'b100:  branch_condition = (rs1_signed < rs2_signed);  // BLT
                3'b101:  branch_condition = (rs1_signed >= rs2_signed); // BGE
                3'b110:  branch_condition = (rs1_data < rs2_data);      // BLTU
                3'b111:  branch_condition = (rs1_data >= rs2_data);     // BGEU
                default: branch_condition = 1'b0;
            endcase
        end else begin
            branch_condition = 1'b0;
        end
    end

    // 最终的分支/跳转决定
    assign take_branch = (branch & branch_condition) | jump;

endmodule 