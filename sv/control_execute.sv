`include "_pkg_riscv_defines.sv"

interface pip_exe_mem_if;
    import _pkg_riscv_defines::*;
    /************************ STATUS *****************************/
    logic valid;
    logic ready;
    /************************ DATA *****************************/
    // from pre stage
    opcode_t                    opcode;
    logic [2:0]                 funct3;
    logic [DATA_WIDTH-1:0]      rs2_data;
    logic [REG_ADDR_WIDTH-1:0]  rd_addr;
    // from current stage
    logic [DATA_WIDTH-1:0]      alu_result;

    modport pre(
        output valid,
        input  ready,
        output opcode,
        output alu_result,
        output rs2_data,
        output rd_addr,
        output funct3
    );

    modport post(
        input  valid,
        output ready,
        input  opcode,
        input  alu_result,
        input  rs2_data,
        input  rd_addr,
        input  funct3
    );
endinterface

module control_execute
import _pkg_riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    // control signal
    alu_if.master alu_if,
    // pip signal
    pip_dec_exe_if.post pip_to_pre_if,
    pip_exe_mem_if.pre pip_to_post_if,
    // pause
    input logic pause,
    // forward
    forward_regs_if.from forward_regs_if,
    forward_pc_if.from forward_pc_if
);
    logic pause_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pause_d1 <= 0;
        end else begin
            pause_d1 <= pause;
        end
    end
    /************************ SAVE DATA FROM PRE *****************************/
    
    logic [ADDR_WIDTH-1:0]      _pre_pc;
    opcode_t                    _pre_opcode;
    logic [DATA_WIDTH-1:0]      _pre_rs1_data;
    logic [DATA_WIDTH-1:0]      _pre_rs2_data;
    logic [REG_ADDR_WIDTH-1:0]  _pre_rd_addr;
    logic [DATA_WIDTH-1:0]      _pre_imm;  
    logic [2:0]                 _pre_funct3;
    logic [6:0]                 _pre_funct7;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _pre_pc <= '0;
            _pre_opcode <= OP_R_TYPE;
            _pre_rs1_data <= '0;
            _pre_rs2_data <= '0;
            _pre_rd_addr <= '0;
            _pre_imm <= '0;
            _pre_funct3 <= '0;
            _pre_funct7 <= '0;
        end else if (pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            _pre_pc <= pip_to_pre_if.pc;
            _pre_opcode <= pip_to_pre_if.opcode;
            _pre_rs1_data <= pip_to_pre_if.rs1_data;
            _pre_rs2_data <= pip_to_pre_if.rs2_data;
            _pre_rd_addr <= pip_to_pre_if.rd_addr;
            _pre_imm <= pip_to_pre_if.imm;
            _pre_funct3 <= pip_to_pre_if.funct3;
            _pre_funct7 <= pip_to_pre_if.funct7;
        end
    end
    
    /************************ FORWARD *****************************/
    // reg file
    assign forward_regs_if.addr = _pre_rd_addr;
    // assign forward_regs_if.data = pip_to_post_if.alu_result;
    always_comb begin
        forward_regs_if.data = pip_to_post_if.alu_result;
        if (_pre_opcode == OP_JALR || _pre_opcode == OP_JAL) begin
            forward_regs_if.data = _pre_pc + 4;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            forward_regs_if.req <= 0;
        end else if (forward_regs_if.resp) begin
            forward_regs_if.req <= 0;
        end else if (alu_if.resp_valid) begin
            case (_pre_opcode)
                OP_R_TYPE, OP_I_TYPE, OP_LUI, OP_AUIPC, OP_JAL, OP_JALR:
                    forward_regs_if.req <= 1;
            endcase
        end
    end
    // pc
    // assign forward_pc_if.pc = _pre_pc + _pre_imm;
    always_comb begin
        forward_pc_if.pc = _pre_pc + _pre_imm;
        if (_pre_opcode == OP_JALR) begin
            forward_pc_if.pc = alu_if.result;
        end
    end
    always_comb begin
        forward_pc_if.branch = 0;
        forward_pc_if.valid = 0;
        if (alu_if.resp_valid) begin
            case (_pre_opcode)
                OP_JAL, OP_JALR: begin
                    forward_pc_if.branch = 1;
                    forward_pc_if.valid = 1;
                end
                OP_BRANCH: begin
                    case (_pre_funct3)
                        BRANCH_FUN3_BEQ:  forward_pc_if.branch = (alu_if.result == 0);
                        BRANCH_FUN3_BNE:  forward_pc_if.branch = (alu_if.result != 0);
                        BRANCH_FUN3_BLT:  forward_pc_if.branch = (alu_if.result == 1);
                        BRANCH_FUN3_BGE:  forward_pc_if.branch = (alu_if.result == 0);
                        BRANCH_FUN3_BLTU: forward_pc_if.branch = (alu_if.result == 1);
                        BRANCH_FUN3_BGEU: forward_pc_if.branch = (alu_if.result == 0);
                    endcase
                    forward_pc_if.valid = 1;
                end
            endcase
        end
    end
    /************************ TO-PRE *****************************/
    // pip_to_pre_if.ready
    logic pip_to_pre_if_ready_pre;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_pre_if_ready_pre <= 1;
        end else if (pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            pip_to_pre_if_ready_pre <= 0;
        end else if (~pause && alu_if.resp_valid) begin
            pip_to_pre_if_ready_pre <= 1;
        end
    end
    // If data to post stage havent been taken, cannot receive pre stage data
    assign pip_to_pre_if.ready = pip_to_pre_if_ready_pre && ~pip_to_post_if.valid;

    /************************ TO-POST *****************************/
    // The idecoder valid & data just keep for one cycle
    // So must sample here.
    // This code will cause a cycle delay, can be optimized.

    // pip_to_post_if.valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.valid <= 0;
        end else if (pip_to_post_if.ready && pip_to_post_if.valid) begin
            pip_to_post_if.valid <= 0;
        end else if (~pause && alu_if.resp_valid &&(
            _pre_opcode == OP_LOAD ||
            _pre_opcode == OP_STORE
        )) begin
            pip_to_post_if.valid <= 1;
        end
    end
    // pip_to_post_if.data
    assign pip_to_post_if.opcode   = _pre_opcode;
    assign pip_to_post_if.rs2_data = _pre_rs2_data;
    assign pip_to_post_if.rd_addr  = _pre_rd_addr;
    assign pip_to_post_if.funct3   = _pre_funct3;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.alu_result <= '0;
        end else if (alu_if.resp_valid) begin
            pip_to_post_if.alu_result <= alu_if.result;
        end
    end

    /************************ ALU *****************************/

    // alu_if.req_valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_if.req_valid <= 0;
        end else if (~pause && pause_d1) begin
            alu_if.req_valid <= 1;
        end else if (alu_if.req_valid && alu_if.resp_ready) begin
            alu_if.req_valid <= 0;
        end else if (~pause && pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            alu_if.req_valid <= 1;
        end
    end

    // alu_if.operand1
    // alu_if.operand2
    // alu_if.alu_op
    always_comb begin
        alu_if.operand1 = '0;
        alu_if.operand2 = '0;
        alu_if.alu_op = ALU_ADD;
        case (_pre_opcode)
            OP_R_TYPE: begin
                // R型指令：使用寄存器值
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_rs2_data;
                case (_pre_funct3)
                    R_FUN3_ADD_SUB:  alu_if.alu_op = (_pre_funct7[5]) ? ALU_SUB : ALU_ADD;
                    R_FUN3_AND:      alu_if.alu_op = ALU_AND;
                    R_FUN3_OR:       alu_if.alu_op = ALU_OR; 
                    R_FUN3_XOR:      alu_if.alu_op = ALU_XOR;
                    R_FUN3_SLL:      alu_if.alu_op = ALU_SLL;
                    R_FUN3_SRL_SRA:  alu_if.alu_op = (_pre_funct7[5]) ? ALU_SRA : ALU_SRL;
                    R_FUN3_SLT:      alu_if.alu_op = ALU_SLT;
                    R_FUN3_SLTU:     alu_if.alu_op = ALU_SLTU;
                endcase
            end

            OP_I_TYPE: begin
                // I型指令：使用rs1和立即数
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_imm;
                case (_pre_funct3)
                    I_FUN3_ADDI:     alu_if.alu_op = ALU_ADD;
                    I_FUN3_ANDI:     alu_if.alu_op = ALU_AND;
                    I_FUN3_ORI:      alu_if.alu_op = ALU_OR;
                    I_FUN3_XORI:     alu_if.alu_op = ALU_XOR;
                    I_FUN3_SLTI:     alu_if.alu_op = ALU_SLT;
                    I_FUN3_SLTIU:    alu_if.alu_op = ALU_SLTU;
                    I_FUN3_SLLI:     alu_if.alu_op = ALU_SLL;
                    I_FUN3_SRLI_SRAI:alu_if.alu_op = (_pre_funct7[5]) ? ALU_SRA : ALU_SRL;
                endcase
            end

            OP_LOAD, OP_STORE: begin
                // 加载/存储指令：计算地址
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_BRANCH: begin
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_rs2_data;
                
                case(_pre_funct3)
                    BRANCH_FUN3_BEQ:  alu_if.alu_op = ALU_SUB;  // beq: 相等判断用减法
                    BRANCH_FUN3_BNE:  alu_if.alu_op = ALU_SUB;  // bne: 不相等判断用减法
                    BRANCH_FUN3_BLT:  alu_if.alu_op = ALU_SLT;  // blt: 有符号小于比较
                    BRANCH_FUN3_BGE:  alu_if.alu_op = ALU_SLT;  // bge: 有符号大于等于用小于的反
                    BRANCH_FUN3_BLTU: alu_if.alu_op = ALU_SLTU; // bltu: 无符号小于比较
                    BRANCH_FUN3_BGEU: alu_if.alu_op = ALU_SLTU; // bgeu: 无符号大于等于用小于的反
                endcase

            end

            OP_LUI: begin
                // LUI：直接传递立即数
                alu_if.operand1 = 32'b0;
                alu_if.operand2 = _pre_imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_AUIPC: begin
                // AUIPC：PC加立即数
                alu_if.operand1 = _pre_pc;
                alu_if.operand2 = _pre_imm;
                alu_if.alu_op = ALU_ADD;
            end

            // OP_JAL: begin
            //     // JAL：PC + imm
            //     alu_if.operand1 = _pre_pc;
            //     alu_if.operand2 = _pre_imm;
            //     alu_if.alu_op = ALU_ADD;
            // end

            OP_JALR: begin
                // JALR：rs1 + imm
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_FENCE, OP_SYSTEM: begin
                alu_if.operand1 = _pre_rs1_data;
                alu_if.operand2 = _pre_rs2_data;
                alu_if.alu_op = ALU_ADD;
            end
        endcase
    end

endmodule