`include "_riscv_defines.sv"

module control_unit
import _riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    
    alu_if.master       alu_if,
    sm_if.master        sm_if,
    idecoder_if.master  idecoder_if,
    icache_if.master    icache_if,
    dcache_if.master    dcache_if,
    reg_file_if.master  reg_file_if
);
    /************************ HELP *****************************/

    logic decode_state_decoder_finish;
    logic decode_state_alu_finish;
    logic just_enter_new_state;

    assign just_enter_new_state = sm_if.now_state != sm_if.now_state_d1;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            decode_state_decoder_finish <= '0;
        end else if (sm_if.now_state == DECODE && idecoder_if.resp_valid) begin
            decode_state_decoder_finish <= '1;
        end else if (sm_if.now_state != DECODE) begin
            decode_state_decoder_finish <= '0;
        end
    end

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            decode_state_alu_finish <= '0;
        end else if (sm_if.now_state == DECODE && alu_if.resp_valid) begin
            decode_state_alu_finish <= '1;
        end else if (sm_if.now_state != DECODE) begin
            decode_state_alu_finish <= '0;
        end
    end

    /************************ PC *****************************/
    logic [DATA_WIDTH-1:0] now_pc;
    logic [DATA_WIDTH-1:0] next_pc;
    logic pc_write_en;
    logic branch;
    logic [DATA_WIDTH-1:0] pc_branch_to_reg;
    logic [DATA_WIDTH-1:0] pc_plus4;

    // pc_plus4
    assign pc_plus4 = now_pc + 4;

    // pc_write_en
    always_comb begin
        pc_write_en = sm_if.next_state == FETCH && sm_if.state_finish;
    end

    // now_pc
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            now_pc <= '0;
        end else if (pc_write_en) begin
            now_pc <= next_pc;
        end else begin
            now_pc <= now_pc;
        end
    end

    // next_pc
    always_comb begin
        if (branch) begin
            next_pc = pc_branch_to_reg;
        end else begin
            next_pc = pc_plus4;
        end
    end

    // pc_branch_to_reg
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pc_branch_to_reg <= '0;
        end else if (sm_if.now_state == DECODE && alu_if.resp_valid) begin
            pc_branch_to_reg <= {alu_if.result[31:1], 1'b0};
        end
    end
    
    // branch
    always_comb begin
        // 注意 ALU 在 EXECUTE 阶段计算是否分支
        // brnach 仅在 EXECUTE 阶段有效
        branch = 1'b0;
        case (idecoder_if.opcode)
            OP_JAL, OP_JALR: begin
                branch = 1'b1;
            end
            OP_BRANCH: begin
                case (idecoder_if.funct3)
                    BRANCH_FUN3_BEQ:  branch = (alu_if.result == 0);        // 相等时ALU结果为0
                    BRANCH_FUN3_BNE:  branch = (alu_if.result != 0);        // 不相等时ALU结果不为0
                    BRANCH_FUN3_BLT:  branch = (alu_if.result == 1);        // SLT结果为1表示小于
                    BRANCH_FUN3_BGE:  branch = (alu_if.result == 0);        // SLT结果为0表示大于等于
                    BRANCH_FUN3_BLTU: branch = (alu_if.result == 1);        // SLTU结果为1表示无符号小于
                    BRANCH_FUN3_BGEU: branch = (alu_if.result == 0);        // SLTU结果为0表示无符号大于等于
                endcase
            end
        endcase
    end

    /************************ SM *****************************/

    // opcode
    assign sm_if.opcode = idecoder_if.opcode;

    // state_finish
    always_comb begin
        sm_if.state_finish = 1'b0;
        case (sm_if.now_state)
            FETCH: begin
                sm_if.state_finish = icache_if.resp_valid;
            end
            DECODE: begin
                case (idecoder_if.opcode)
                    OP_JAL, OP_JALR, OP_BRANCH: begin
                        // 若有跳转命令，则要等到 decoder 和 alu 都完成
                        sm_if.state_finish = (idecoder_if.resp_valid && decode_state_alu_finish) || 
                                             (alu_if.resp_valid && decode_state_decoder_finish);
                    end
                    default: begin
                        sm_if.state_finish = idecoder_if.resp_valid;
                    end
                endcase
            end
            EXECUTE: begin
                sm_if.state_finish = alu_if.resp_valid;
            end
            MEMORY: begin
                // 若是写入内存，则无需等待
                if (idecoder_if.opcode == OP_STORE) begin
                    sm_if.state_finish = '1;
                end else begin
                    sm_if.state_finish = dcache_if.resp_valid;
                end
            end
            WRITEBACK: begin
                // 假设寄存器写入是瞬间完成的
                sm_if.state_finish = '1;
            end
        endcase
    end

    /************************ ICACHE *****************************/

    logic need_to_request_icache;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            need_to_request_icache <= '0;
        end else if (sm_if.now_state == FETCH && just_enter_new_state) begin
            need_to_request_icache <= '1;
        end else if (icache_if.req_valid) begin
            need_to_request_icache <= '0;
        end
    end

    // icache_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            icache_if.req_valid <= '0;
        end else if (need_to_request_icache && icache_if.resp_ready) begin
            icache_if.req_valid <= '1;
        end else if (sm_if.now_state == FETCH && just_enter_new_state && icache_if.resp_ready) begin
            icache_if.req_valid <= '1;
        end else begin
            icache_if.req_valid <= '0;
        end
    end

    always_comb begin
        icache_if.req_addr = now_pc;
    end

    /************************ DECODER *****************************/

    // req_valid
    assign idecoder_if.req_valid = (sm_if.now_state == DECODE) && !decode_state_decoder_finish;

    // instruction
    assign idecoder_if.instruction = icache_if.resp_data;

    /************************ REG_FILE *****************************/

    assign reg_file_if.rs1_addr = idecoder_if.rs1_addr;
    assign reg_file_if.rs2_addr = idecoder_if.rs2_addr;
    assign reg_file_if.rd_addr = idecoder_if.rd_addr;
    
    assign reg_file_if.write_en = sm_if.now_state == WRITEBACK;

    // reg_file_if.rd_data
    always_comb begin
        reg_file_if.rd_data = alu_if.result;
        case (idecoder_if.opcode)
            OP_LOAD:         reg_file_if.rd_data = dcache_if.resp_data;
            OP_JAL, OP_JALR: reg_file_if.rd_data = pc_plus4;
        endcase
    end

    /************************ ALU *****************************/

    // alu_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            alu_if.req_valid <= '0;
        end else if (alu_if.resp_valid) begin
            alu_if.req_valid <= '0;
        end else if (sm_if.now_state_d1 != sm_if.now_state && sm_if.now_state == EXECUTE)begin
            alu_if.req_valid <= '1;
        end else begin
            case (idecoder_if.opcode)
                OP_JAL, OP_BRANCH, OP_JALR: begin
                    alu_if.req_valid <= just_enter_new_state;
                end
            endcase
        end
    end

    // alu_if.operand1
    // alu_if.operand2
    // alu_if.alu_op
    always_comb begin
        alu_if.operand1 = '0;
        alu_if.operand2 = '0;
        alu_if.alu_op = ALU_ADD;
        // 由于是上升沿触发 需要提前一个状态
        case (sm_if.now_state)
            // DECODE 阶段计算跳转
            DECODE: begin
                case (idecoder_if.opcode)
                    OP_JAL, OP_BRANCH: begin
                        // JAL和BRANCH指令：PC + imm
                        alu_if.operand1 = now_pc;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end
                    
                    OP_JALR: begin
                        // JALR指令：rs1 + imm
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end
                endcase
            end

            EXECUTE: begin
                case (idecoder_if.opcode)
                    OP_R_TYPE: begin
                        // R型指令：使用寄存器值
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = reg_file_if.rs2_data;
                        case (idecoder_if.funct3)
                            R_FUN3_ADD_SUB:  alu_if.alu_op = (idecoder_if.funct7[5]) ? ALU_SUB : ALU_ADD;
                            R_FUN3_AND:      alu_if.alu_op = ALU_AND;
                            R_FUN3_OR:       alu_if.alu_op = ALU_OR; 
                            R_FUN3_XOR:      alu_if.alu_op = ALU_XOR;
                            R_FUN3_SLL:      alu_if.alu_op = ALU_SLL;
                            R_FUN3_SRL_SRA:  alu_if.alu_op = (idecoder_if.funct7[5]) ? ALU_SRA : ALU_SRL;
                            R_FUN3_SLT:      alu_if.alu_op = ALU_SLT;
                            R_FUN3_SLTU:     alu_if.alu_op = ALU_SLTU;
                        endcase
                    end

                    OP_I_TYPE: begin
                        // I型指令：使用rs1和立即数
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = idecoder_if.imm;
                        case (idecoder_if.funct3)
                            I_FUN3_ADDI:     alu_if.alu_op = ALU_ADD;
                            I_FUN3_ANDI:     alu_if.alu_op = ALU_AND;
                            I_FUN3_ORI:      alu_if.alu_op = ALU_OR;
                            I_FUN3_XORI:     alu_if.alu_op = ALU_XOR;
                            I_FUN3_SLTI:     alu_if.alu_op = ALU_SLT;
                            I_FUN3_SLTIU:    alu_if.alu_op = ALU_SLTU;
                            I_FUN3_SLLI:     alu_if.alu_op = ALU_SLL;
                            I_FUN3_SRLI_SRAI:alu_if.alu_op = (idecoder_if.funct7[5]) ? ALU_SRA : ALU_SRL;
                        endcase
                    end

                    OP_LOAD, OP_STORE: begin
                        // 加载/存储指令：计算地址
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end

                    OP_BRANCH: begin
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = reg_file_if.rs2_data;
                        
                        case(idecoder_if.funct3)
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
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end

                    OP_AUIPC: begin
                        // AUIPC：PC加立即数
                        alu_if.operand1 = now_pc;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end

                    OP_JAL: begin
                        // JAL：PC + imm
                        alu_if.operand1 = now_pc;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end

                    OP_JALR: begin
                        // JALR：rs1 + imm
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = idecoder_if.imm;
                        alu_if.alu_op = ALU_ADD;
                    end

                    OP_FENCE, OP_SYSTEM: begin
                        alu_if.operand1 = reg_file_if.rs1_data;
                        alu_if.operand2 = reg_file_if.rs2_data;
                        alu_if.alu_op = ALU_ADD;
                    end

                endcase
            end
        endcase
    end

    /************************ DCACHE *****************************/

    logic dcache_if_req_valid_d1;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            dcache_if_req_valid_d1 <= '0;
        end else begin
            dcache_if_req_valid_d1 <= dcache_if.req_valid;
        end
    end

    // dcache_if.req_valid
    assign dcache_if.req_valid = sm_if.now_state == MEMORY && dcache_if.resp_ready && !dcache_if_req_valid_d1;

    // dcache_if.write_en
    assign dcache_if.write_en = sm_if.now_state == MEMORY && idecoder_if.opcode == OP_STORE;

    // dcache_if.req_addr
    always_comb begin
        dcache_if.req_addr = '0;
        if (sm_if.now_state == MEMORY) begin
            dcache_if.req_addr = alu_if.result;
        end 
    end

    // dcache_if.write_data
    always_comb begin
        dcache_if.write_data = '0;
        if (sm_if.now_state == MEMORY && idecoder_if.opcode == OP_STORE) begin
            dcache_if.write_data = reg_file_if.rs2_data;
        end
    end

    // dcache_if.size
    always_comb begin
        dcache_if.size = MEM_SIZE_W;
        if (idecoder_if.opcode == OP_LOAD) begin
            case (idecoder_if.funct3)
                LOAD_FUN3_LB, LOAD_FUN3_LBU:  dcache_if.size = MEM_SIZE_B;
                LOAD_FUN3_LH, LOAD_FUN3_LHU:  dcache_if.size = MEM_SIZE_H;
                LOAD_FUN3_LW:                 dcache_if.size = MEM_SIZE_W;
            endcase
        end else if (idecoder_if.opcode == OP_STORE) begin
            case (idecoder_if.funct3)
                STORE_FUN3_SB: dcache_if.size = MEM_SIZE_B;
                STORE_FUN3_SH: dcache_if.size = MEM_SIZE_H;
                STORE_FUN3_SW: dcache_if.size = MEM_SIZE_W;
            endcase
        end
    end

    // dcache_if.sign
    always_comb begin
        dcache_if.sign = 1'b0;
        if (idecoder_if.opcode == OP_LOAD) begin
            case (idecoder_if.funct3)
                LOAD_FUN3_LB,
                LOAD_FUN3_LH,
                LOAD_FUN3_LW:  dcache_if.sign = 1'b1;
                LOAD_FUN3_LBU,
                LOAD_FUN3_LHU: dcache_if.sign = 1'b0;
            endcase
        end
    end

endmodule 