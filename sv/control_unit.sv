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
    input  logic [DATA_WIDTH-1:0]   now_pc,
    input  logic [DATA_WIDTH-1:0]   imm,
    input  logic [DATA_WIDTH-1:0]   alu_result,
    input  logic [DATA_WIDTH-1:0]   mem_rdata,
    
    output logic                    reg_write_en,
    output logic [DATA_WIDTH-1:0]   reg_wb_data,

    output logic [DATA_WIDTH-1:0]   alu_operand1,
    output logic [DATA_WIDTH-1:0]   alu_operand2,
    output alu_op_t                 alu_op,

    output mem_size_t               mem_size,
    output logic                    mem_sign,
    output logic                    mem_we,

    output logic [DATA_WIDTH-1:0]   next_pc,
    output logic                    pc_write_en
);

    // 需要声明 state 否则编译器会错误判断类型
    state_t now_state;
    state_t next_state;
    logic branch;
    logic [DATA_WIDTH-1:0] pc_plus4_reg;
    logic [DATA_WIDTH-1:0] pc_branch_to_reg;
    logic [DATA_WIDTH-1:0] mem_rdata_reg;

    assign pc_plus4_reg = now_pc + 4;

    state_machine state_machine_inst (
        .clk(clk),
        .rst_n(rst_n),
        .opcode(opcode),
        .now_state(now_state),
        .next_state(next_state)
    );

    alu_controller  alu_controller_inst (
        .clk(clk),
        .now_state(now_state),
        .next_state(next_state),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .imm(imm),
        .now_pc(now_pc),
        .alu_operand1(alu_operand1),
        .alu_operand2(alu_operand2),
        .alu_op(alu_op)
    );

    // pc_write_en
    always_comb begin
        pc_write_en = next_state == FETCH;
    end

    always_ff @(posedge clk) begin
        // 注意 ALU 仅在 DECODE 阶段计算分支去向
        if (now_state == DECODE) begin
            pc_branch_to_reg <= {alu_result[31:1], 1'b0};
        end
    end

    // branch
    always_comb begin
        // 注意 ALU 在 EXECUTE 阶段计算是否分支
        // brnach 仅在 EXECUTE 阶段有效
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

    // next_pc
    always_comb begin
        // brnach 仅在 EXECUTE 阶段有效
        if (branch) begin
            next_pc = pc_branch_to_reg;
        end else begin
            next_pc = pc_plus4_reg;  // 顺序执行
        end
    end

    // reg_wb_data 写回数据选择
    always_comb begin
        case (opcode)
            OP_LOAD:         reg_wb_data = mem_rdata_reg; // 加载指令选择内存数据
            OP_JAL, OP_JALR: reg_wb_data = pc_plus4_reg;  // 跳转指令选择PC+4
            default: reg_wb_data = alu_result;
        endcase
    end

    // ALU 在 EXECUTE 阶段计算 MEM 读地址
    always_ff @(posedge clk) begin
        if (now_state == EXECUTE && opcode == OP_LOAD) begin
            mem_rdata_reg <= mem_rdata;
        end else begin
            mem_rdata_reg <= _DEBUG_NO_USE_;
        end
    end

    // reg_write_en 寄存器写使能信号
    always_comb begin
        // 提前拉高 reg_write_en
        if (next_state == WRITEBACK) begin  
            case (opcode)
                OP_R_TYPE, OP_I_TYPE, OP_LOAD, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC: 
                    reg_write_en <= 1'b1;
                default: reg_write_en <= 1'b0;
            endcase
        end else begin
            reg_write_en <= 1'b0;
        end
    end

    // 内存写使能信号
    assign mem_we = (next_state == MEMORY) && (opcode == OP_STORE);

    // 内存访问大小控制
    always_comb begin
        if (opcode == OP_LOAD) begin
            case (funct3)
                LOAD_FUN3_LB, LOAD_FUN3_LBU:  mem_size = MEM_SIZE_B;  // LB/LBU
                LOAD_FUN3_LH, LOAD_FUN3_LHU:  mem_size = MEM_SIZE_H;  // LH/LHU
                LOAD_FUN3_LW:                 mem_size = MEM_SIZE_W;  // LW
                default:                      mem_size = _MEM_SIZE_DEBUG_NO_USE;
            endcase
        end else if (opcode == OP_STORE) begin
            case (funct3)
                STORE_FUN3_SB: mem_size = MEM_SIZE_B;  // SB
                STORE_FUN3_SH: mem_size = MEM_SIZE_H;  // SH
                STORE_FUN3_SW: mem_size = MEM_SIZE_W;  // SW
                default:       mem_size = _MEM_SIZE_DEBUG_NO_USE;
            endcase
        end else begin
            mem_size = _MEM_SIZE_DEBUG_NO_USE;
        end
    end

    // 符号扩展控制
    always_comb begin
        if (opcode == OP_LOAD) begin
            case (funct3)
                LOAD_FUN3_LB,
                LOAD_FUN3_LH,
                LOAD_FUN3_LW:  mem_sign = 1'b1;  // 有符号加载
                LOAD_FUN3_LBU,
                LOAD_FUN3_LHU: mem_sign = 1'b0;  // 无符号加载
                default:       mem_sign = _DEBUG_NO_USE_;
            endcase
        end else begin
            mem_sign = _DEBUG_NO_USE_;
        end
    end

endmodule 