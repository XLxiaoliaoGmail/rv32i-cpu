`include "_riscv_defines.sv"

module control_unit
import _riscv_defines::*;
(
    input  logic                    clk,
    input  logic                    rst_n,
    input  opcode_t                 opcode,
    input  logic [2:0]              funct3,
    input  logic [6:0]              funct7,
    input  logic [DATA_WIDTH-1:0]   rs1_data,
    input  logic [DATA_WIDTH-1:0]   rs2_data,
    input  logic [DATA_WIDTH-1:0]   current_pc,
    input  logic [DATA_WIDTH-1:0]   imm,
    input  logic [DATA_WIDTH-1:0]   alu_result,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    
    output logic                    reg_we,
    output logic [DATA_WIDTH-1:0]   reg_wb_data,

    output logic [DATA_WIDTH-1:0]   alu_operand1,
    output logic [DATA_WIDTH-1:0]   alu_operand2,
    output alu_op_t                 alu_op,

    output logic [1:0]              mem_size,
    output logic                    mem_sign,
    output logic                    mem_we,

    output logic [DATA_WIDTH-1:0]   next_pc,
    output logic                    pc_we
);

    state_t current_state;
    logic branch;
    logic [DATA_WIDTH-1:0] pc_plus4_reg;
    logic [DATA_WIDTH-1:0] next_pc_reg;

    assign next_pc = next_pc_reg;

    state_machine state_machine_inst (
        .clk(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .current_state(current_state)
    );

    alu_controller  alu_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        .current_state(current_state),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .imm(imm),
        .current_pc(current_pc),
        .alu_operand1(alu_operand1),
        .alu_operand2(alu_operand2),
        .alu_op(alu_op)
    );

    // pc_we 控制逻辑
    always_comb begin
        case (current_state)
            EXECUTE: begin
                if (opcode == OP_BRANCH || opcode == OP_JAL || opcode == OP_JALR) begin
                    pc_we = 1'b1;  // 分支和跳转指令在EXECUTE阶段结束时更新PC
                end else begin
                    pc_we = 1'b0;
                end
            end
            MEMORY: begin
                if (opcode == OP_STORE) begin
                    pc_we = 1'b1;  // 存储指令在MEMORY阶段结束时更新PC
                end else begin
                    pc_we = 1'b0;
                end
            end
            WRITEBACK: begin
                pc_we = 1'b1;  // 其他所有指令在WRITEBACK阶段结束时更新PC
            end
            default: pc_we = 1'b0;
        endcase
    end
    
    // pc_plus4_reg 寄存器
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_reg <= '0;
        end else if (current_state == EXECUTE) begin
            // ALU 在 FETCH 阶段计算 PC+4
            // 在 EXECUTE 阶段存入
            pc_plus4_reg <= alu_result;
        end else begin
            pc_plus4_reg <= pc_plus4_reg;
        end
    end

    // reg_wb_data 写回数据选择
    always_comb begin
        case (opcode)
            OP_LOAD:         reg_wb_data = mem_rdata;     // 加载指令选择内存数据
            OP_JAL, OP_JALR: reg_wb_data = pc_plus4_reg;  // 跳转指令选择PC+4
            default: reg_wb_data = alu_result;
        endcase
    end

    // reg_we 寄存器写使能信号
    always_comb begin
        if (current_state == WRITEBACK) begin  // 只在WRITEBACK状态允许写寄存器
            case (opcode)
                OP_R_TYPE, OP_I_TYPE, OP_LOAD, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC: 
                    reg_we = 1'b1;
                default: reg_we = 1'b0;
            endcase
        end else begin
            reg_we = 1'b0;
        end
    end

    // branch 分支条件判断逻辑
    always_comb begin
        case (opcode)
            OP_JAL, OP_JALR: begin
                branch = 1'b1;
            end
            OP_BRANCH: begin
                case (funct3)
                    BRANCH_FUN3_BEQ:  branch = (alu_result == 0);        // 相等时ALU结果为0
                    BRANCH_FUN3_BNE:  branch = (alu_result != 0);        // 不相等时ALU结果不为0
                    BRANCH_FUN3_BLT:  branch = (alu_result == 1);        // SLT结果为1表示小于
                    BRANCH_FUN3_BGE:  branch = (alu_result == 0);        // SLT结果为0表示大于等于
                    BRANCH_FUN3_BLTU: branch = (alu_result == 1);        // SLTU结果为1表示无符号小于
                    BRANCH_FUN3_BGEU: branch = (alu_result == 0);        // SLTU结果为0表示无符号大于等于
                    default: branch = 1'b0;
                endcase
            end
            default: branch = 1'b0;
        endcase
    end

    // next_pc_reg 下一个PC值的计算
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            next_pc_reg <= '0;
        end else if (current_state == DECODE) begin
            if (branch) begin
                next_pc_reg <= {alu_result[31:1], 1'b0};
            end else begin
                next_pc_reg <= pc_plus4_reg;  // 顺序执行
            end
        end else begin
            next_pc_reg <= next_pc_reg;
        end
    end


    // 内存写使能信号
    assign mem_we = (current_state == MEMORY) && (opcode == OP_STORE);

    // 内存访问大小和符号扩展控制
    always_comb begin
        // 默认值设置
        mem_sign = 1'b1;
        mem_size = 2'b10;
        if (opcode == OP_LOAD) begin
            case (funct3)
                3'b000: begin  // LB
                    mem_size = 2'b00;
                    mem_sign = 1'b1;
                end
                3'b001: begin  // LH
                    mem_size = 2'b01;
                    mem_sign = 1'b1;
                end
                3'b010: begin  // LW
                    mem_size = 2'b10;
                    mem_sign = 1'b1;
                end
                3'b100: begin  // LBU
                    mem_size = 2'b00;
                    mem_sign = 1'b0;
                end
                3'b101: begin  // LHU
                    mem_size = 2'b01;
                    mem_sign = 1'b0;
                end
                default: begin
                    mem_size = 2'b10;
                    mem_sign = 1'b1;
                end
            endcase
        end else if (opcode == OP_STORE) begin
            case (funct3)
                STORE_FUN3_SB: mem_size = 2'b00;  // SB
                STORE_FUN3_SH: mem_size = 2'b01;  // SH
                STORE_FUN3_SW: mem_size = 2'b10;  // SW
                default:       mem_size = 2'b10;
            endcase
        end
    end

endmodule 