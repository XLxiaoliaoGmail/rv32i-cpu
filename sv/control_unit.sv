`include "_pkg_riscv_defines.sv"

module control_unit
import _pkg_riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    
    alu_if.master       alu_if,
    idecoder_if.master  idecoder_if,
    icache_if.master    icache_if,
    dcache_if.master    dcache_if,
    reg_file_if.master  reg_file_if
);

    logic rst_n_d1;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            rst_n_d1 <= '0;
        end else begin
            rst_n_d1 <= rst_n;
        end
    end
    
    /************************ SIGNAL DECLARATION *****************************/

    logic fet_status_valid;
    logic dec_status_valid;
    logic exe_status_valid;
    logic mem_status_valid;
    logic wb_status_valid;

    logic fet_status_ready;
    logic dec_status_ready;
    logic exe_status_ready;
    logic mem_status_ready;
    logic wb_status_ready;

    logic fet_status_waiting;
    logic dec_status_waiting;
    logic exe_status_waiting;
    logic mem_status_waiting;
    logic wb_status_waiting;

    logic fet_dec_write_en;
    logic dec_exe_write_en;
    logic exe_mem_write_en;
    logic mem_wb_write_en;

    assign fet_dec_write_en = fet_status_valid && dec_status_ready;
    assign dec_exe_write_en = dec_status_valid && exe_status_ready;
    assign exe_mem_write_en = exe_status_valid && mem_status_ready;
    assign mem_wb_write_en = mem_status_valid && wb_status_ready;

    logic fet_dec_write_en_d1;
    logic dec_exe_write_en_d1;
    logic exe_mem_write_en_d1;
    logic mem_wb_write_en_d1;

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            fet_dec_write_en_d1 <= '0;
            dec_exe_write_en_d1 <= '0;
            exe_mem_write_en_d1 <= '0;
            mem_wb_write_en_d1 <= '0;
        end else begin
            fet_dec_write_en_d1 <= fet_dec_write_en;
            dec_exe_write_en_d1 <= dec_exe_write_en;
            exe_mem_write_en_d1 <= exe_mem_write_en;
            mem_wb_write_en_d1 <= mem_wb_write_en;
        end
    end

    pip_reg_fet_dec_t  i_fet_dec;
    pip_reg_dec_exe_t  i_dec_exe;
    pip_reg_exe_mem_t  i_exe_mem;
    pip_reg_mem_wb_t   i_mem_wb;

    pip_reg_fet_dec_t o_fet_dec;
    pip_reg_dec_exe_t o_dec_exe;
    pip_reg_exe_mem_t o_exe_mem;
    pip_reg_mem_wb_t  o_mem_wb;

    logic [DATA_WIDTH-1:0] pc;

    /************************ PIPLINE REGS DATA *****************************/

    // i_fet_dec.instruction
    assign i_fet_dec.instruction = icache_if.resp_data;
    // i_fet_dec.pc
    assign i_fet_dec.pc = pc;

    // i_dec_exe.opcode
    assign i_dec_exe.opcode = idecoder_if.opcode;
    // i_dec_exe.pc
    assign i_dec_exe.pc = o_fet_dec.pc;
    // i_dec_exe.rs1_data
    assign i_dec_exe.rs1_data = reg_file_if.rs1_data;
    // i_dec_exe.rs2_data
    assign i_dec_exe.rs2_data = reg_file_if.rs2_data;
    // i_dec_exe.rd_addr
    assign i_dec_exe.rd_addr = idecoder_if.rd_addr;
    // i_dec_exe.imm
    assign i_dec_exe.imm = idecoder_if.imm;
    // i_dec_exe.funct3
    assign i_dec_exe.funct3 = idecoder_if.funct3;
    // i_dec_exe.funct7
    assign i_dec_exe.funct7 = idecoder_if.funct7;

    // i_exe_mem.opcode
    assign i_exe_mem.opcode = o_dec_exe.opcode;
    // i_exe_mem.pc_plus4
    assign i_exe_mem.pc_plus4 = o_dec_exe.pc + 4;
    // i_exe_mem.alu_result
    assign i_exe_mem.alu_result = alu_if.result;
    // i_exe_mem.rs2_data
    assign i_exe_mem.rs2_data = o_dec_exe.rs2_data;
    // i_exe_mem.rd_addr
    assign i_exe_mem.rd_addr = o_dec_exe.rd_addr;
    // i_exe_mem.funct3
    assign i_exe_mem.funct3 = o_dec_exe.funct3;

    // i_mem_wb.opcode
    assign i_mem_wb.opcode = o_exe_mem.opcode;
    // i_mem_wb.pc_plus4
    assign i_mem_wb.pc_plus4 = o_exe_mem.pc_plus4;
    // i_mem_wb.alu_result
    assign i_mem_wb.alu_result = o_exe_mem.alu_result;
    // i_mem_wb.mem_data
    assign i_mem_wb.mem_data = dcache_if.resp_data;
    // i_mem_wb.rd_addr
    assign i_mem_wb.rd_addr = o_exe_mem.rd_addr;

    /************************ PIPLINE READY *****************************/

    assign fet_status_ready = ~fet_status_waiting && icache_if.resp_ready;
    assign dec_status_ready = ~dec_status_waiting && idecoder_if.resp_ready;
    assign exe_status_ready = ~exe_status_waiting && alu_if.resp_ready;
    assign mem_status_ready = ~mem_status_waiting && dcache_if.resp_ready;
    assign wb_status_ready  = ~wb_status_waiting && reg_file_if.resp_ready;

    /************************ PIPLINE WAITING *****************************/

    // fet_status_waiting
    always_comb begin
        // If has JUMP or BRANCH handling instruction
        fet_status_waiting = '0;
        if (
            o_dec_exe.opcode == OP_JAL ||
            o_dec_exe.opcode == OP_JALR ||
            o_dec_exe.opcode == OP_BRANCH
        ) begin
            // If [ready] is 1, means PC has been written 
            if (exe_status_ready) begin
                // Attention to the priority of code.
                // When JUMP or BRANCH first arrived DECODE stage,
                // FETCH stage already waiting,
                // So after the JUMP or BRANCH instruction transmit to EXE stage and executed,
                // This waiting should be released.
                fet_status_waiting = '0;
            end else begin
                fet_status_waiting = '1;
            end
        end else if (
            idecoder_if.opcode == OP_JAL ||
            idecoder_if.opcode == OP_JALR ||
            idecoder_if.opcode == OP_BRANCH
        ) begin
            fet_status_waiting = '1;
        end
    end

    // dec_status_waiting
    always_comb begin
        // If rs1 rs2 == certain rd in handling instruction
        // Wait them to write back
        dec_status_waiting = '0;
        case (o_dec_exe.opcode)
            // Write back in EXE stage
            // If [ready] is 1, means data has been written 
            OP_R_TYPE,
            OP_I_TYPE,
            OP_LUI,
            OP_AUIPC:
                if (exe_status_ready) begin
                    dec_status_waiting = '0;
                end else if (
                    o_dec_exe.rd_addr == idecoder_if.rs1_addr || 
                    o_dec_exe.rd_addr == idecoder_if.rs2_addr
                ) begin
                    dec_status_waiting = '1;
                end
        endcase
        case (o_exe_mem.opcode)
            // Write back in MEM stage
            // If [ready] is 0, means data has been written 
            OP_LOAD,
            OP_JAL,
            OP_JALR:
                if (mem_status_ready) begin
                    dec_status_waiting = '0;
                end else if (
                    o_exe_mem.rd_addr == idecoder_if.rs1_addr || 
                    o_exe_mem.rd_addr == idecoder_if.rs2_addr
                ) begin
                    dec_status_waiting = '1;
                end
        endcase
    end

    assign exe_status_waiting = '0;

    assign mem_status_waiting = '0;

    assign wb_status_waiting  = '0;

    
    /************************ PIPLINE VALID *****************************/

    _trigValid fet_status_trig(
        .clk(clk),
        .rst(rst_n),
        .self_trig(icache_if.resp_valid),
        .next_ready(dec_status_ready),
        .condition(~fet_status_waiting),
        .self_valid(fet_status_valid)
    );
    
    _trigValid dec_status_trig(
        .clk(clk),
        .rst(rst_n),
        .self_trig(idecoder_if.resp_valid),
        .next_ready(exe_status_ready),
        .condition(~dec_status_waiting),
        .self_valid(dec_status_valid)
    );

    _trigValid exe_status_trig(
        .clk(clk),
        .rst(rst_n),
        .self_trig(alu_if.resp_valid),
        .next_ready(mem_status_ready),
        .condition(~exe_status_waiting),
        .self_valid(exe_status_valid)
    );

    _trigValid mem_status_trig(
        .clk(clk),
        .rst(rst_n),
        .self_trig(dcache_if.resp_valid),
        .next_ready(wb_status_ready),
        .condition(~mem_status_waiting),
        .self_valid(mem_status_valid)
    );

    pip_regs pip_regs(
        .clk(clk),
        .rst_n(rst_n),

        .fet_dec_write_en(fet_dec_write_en),
        .dec_exe_write_en(dec_exe_write_en),
        .exe_mem_write_en(exe_mem_write_en),
        .mem_wb_write_en(mem_wb_write_en),

        .i_fet_dec(i_fet_dec),
        .i_dec_exe(i_dec_exe),
        .i_exe_mem(i_exe_mem),
        .i_mem_wb(i_mem_wb),

        .o_fet_dec(o_fet_dec),
        .o_dec_exe(o_dec_exe),
        .o_exe_mem(o_exe_mem),
        .o_mem_wb(o_mem_wb)
    );

    /************************ PC *****************************/

    logic [DATA_WIDTH-1:0] next_pc;
    logic branch;
    logic [DATA_WIDTH-1:0] pc_branch_to;

    // pc
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= '0;
        end else if (fet_dec_write_en) begin
            pc <= next_pc;
        end else begin
            pc <= pc;
        end
    end

    // next_pc
    always_comb begin
        next_pc = '0;
        if (branch) begin
            next_pc = pc_branch_to;
        end else begin
            next_pc = pc + 4;
        end
    end

    // pc_branch_to
    assign pc_branch_to = o_dec_exe.imm + o_dec_exe.pc;
    
    // branch
    always_comb begin
        branch = 1'b0;
        case (o_dec_exe.opcode)
            OP_JAL, OP_JALR: begin
                branch = 1'b1;
            end
            OP_BRANCH: begin
                case (o_dec_exe.funct3)
                    BRANCH_FUN3_BEQ:  branch = (alu_if.result == 0);
                    BRANCH_FUN3_BNE:  branch = (alu_if.result != 0);
                    BRANCH_FUN3_BLT:  branch = (alu_if.result == 1);
                    BRANCH_FUN3_BGE:  branch = (alu_if.result == 0);
                    BRANCH_FUN3_BLTU: branch = (alu_if.result == 1);
                    BRANCH_FUN3_BGEU: branch = (alu_if.result == 0);
                endcase
            end
        endcase
    end

    /************************ REGISTER FILE *****************************/

    assign reg_file_if.rs1_addr = idecoder_if.rs1_addr;
    assign reg_file_if.rs2_addr = idecoder_if.rs2_addr;

    // reg_file_if.rd_data
    // reg_file_if.rd_addr
    // reg_file_if.write_en
    always_comb begin
        reg_file_if.rd_data  = '0;
        reg_file_if.rd_addr  = '0;
        reg_file_if.write_en = '0;
        if (o_exe_mem.opcode == OP_LOAD) begin
            reg_file_if.rd_data = dcache_if.resp_data;
            reg_file_if.rd_addr = o_exe_mem.rd_addr;
            reg_file_if.write_en = dcache_if.resp_valid;
        end else if (o_dec_exe.opcode == OP_JAL || o_dec_exe.opcode == OP_JALR) begin
            reg_file_if.rd_data = o_dec_exe.pc + 4;
            reg_file_if.rd_addr = o_dec_exe.rd_addr;
            reg_file_if.write_en = alu_if.resp_valid;
        end else begin
            reg_file_if.rd_data = alu_if.result;
            reg_file_if.rd_addr = o_dec_exe.rd_addr;
            reg_file_if.write_en = alu_if.resp_valid;
        end
    end

    /************************ ICACHE *****************************/

    // fet_status_waiting_d1
    logic fet_status_waiting_d1;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            fet_status_waiting_d1 <= '0;
        end else begin
            fet_status_waiting_d1 <= fet_status_waiting;
        end
    end
    // icache_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            icache_if.req_valid <= '0;
        end else if (rst_n && ~rst_n_d1) begin
            // After reset, read the instruction immediately
            icache_if.req_valid <= '1;
        end else if (fet_status_waiting) begin
            // Dont fetch when waiting
            icache_if.req_valid <= '0;
        end else if (~fet_status_waiting && fet_status_waiting_d1) begin
            // When the waiting is released, fetch
            icache_if.req_valid <= '1;
        end else if (fet_dec_write_en) begin
            // When the instruction has been readed, fetch next instruction
            icache_if.req_valid <= '1;
        end else begin
            icache_if.req_valid <= '0;
        end
    end

    assign icache_if.req_addr = pc;

    /************************ IDECODER *****************************/

    idecoder idecoder(
        .clk(clk),
        .rst_n(rst_n),
        .idecoder_if(idecoder_if)
    );

    // idecoder_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            idecoder_if.req_valid <= '0;
        end else if (fet_dec_write_en) begin
            idecoder_if.req_valid <= '1;
        end else begin
            idecoder_if.req_valid <= '0;
        end
    end

    assign idecoder_if.instruction = o_fet_dec.instruction;

    /************************ ALU *****************************/

    // alu_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            alu_if.req_valid <= '0;
        end else if (dec_exe_write_en) begin
            alu_if.req_valid <= '1;
        end else begin
            alu_if.req_valid <= '0;
        end
    end

    // alu_if.operand1
    // alu_if.operand2
    // alu_if.alu_op
    always_comb begin
        alu_if.operand1 = '0;
        alu_if.operand2 = '0;
        alu_if.alu_op = ALU_ADD;
        case (o_dec_exe.opcode)
            OP_R_TYPE: begin
                // R型指令：使用寄存器值
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.rs2_data;
                case (o_dec_exe.funct3)
                    R_FUN3_ADD_SUB:  alu_if.alu_op = (o_dec_exe.funct7[5]) ? ALU_SUB : ALU_ADD;
                    R_FUN3_AND:      alu_if.alu_op = ALU_AND;
                    R_FUN3_OR:       alu_if.alu_op = ALU_OR; 
                    R_FUN3_XOR:      alu_if.alu_op = ALU_XOR;
                    R_FUN3_SLL:      alu_if.alu_op = ALU_SLL;
                    R_FUN3_SRL_SRA:  alu_if.alu_op = (o_dec_exe.funct7[5]) ? ALU_SRA : ALU_SRL;
                    R_FUN3_SLT:      alu_if.alu_op = ALU_SLT;
                    R_FUN3_SLTU:     alu_if.alu_op = ALU_SLTU;
                endcase
            end

            OP_I_TYPE: begin
                // I型指令：使用rs1和立即数
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.imm;
                case (o_dec_exe.funct3)
                    I_FUN3_ADDI:     alu_if.alu_op = ALU_ADD;
                    I_FUN3_ANDI:     alu_if.alu_op = ALU_AND;
                    I_FUN3_ORI:      alu_if.alu_op = ALU_OR;
                    I_FUN3_XORI:     alu_if.alu_op = ALU_XOR;
                    I_FUN3_SLTI:     alu_if.alu_op = ALU_SLT;
                    I_FUN3_SLTIU:    alu_if.alu_op = ALU_SLTU;
                    I_FUN3_SLLI:     alu_if.alu_op = ALU_SLL;
                    I_FUN3_SRLI_SRAI:alu_if.alu_op = (o_dec_exe.funct7[5]) ? ALU_SRA : ALU_SRL;
                endcase
            end

            OP_LOAD, OP_STORE: begin
                // 加载/存储指令：计算地址
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_BRANCH: begin
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.rs2_data;
                
                case(o_dec_exe.funct3)
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
                alu_if.operand2 = o_dec_exe.imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_AUIPC: begin
                // AUIPC：PC加立即数
                alu_if.operand1 = o_dec_exe.pc;
                alu_if.operand2 = o_dec_exe.imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_JAL: begin
                // JAL：PC + imm
                alu_if.operand1 = o_dec_exe.pc;
                alu_if.operand2 = o_dec_exe.imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_JALR: begin
                // JALR：rs1 + imm
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.imm;
                alu_if.alu_op = ALU_ADD;
            end

            OP_FENCE, OP_SYSTEM: begin
                alu_if.operand1 = o_dec_exe.rs1_data;
                alu_if.operand2 = o_dec_exe.rs2_data;
                alu_if.alu_op = ALU_ADD;
            end
        endcase
    end

    /************************ DCACHE *****************************/

    logic need_req_dcache;
    assign need_req_dcache = o_exe_mem.opcode == OP_LOAD || o_exe_mem.opcode == OP_STORE;

    logic dcache_if_req_valid_d1;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            dcache_if_req_valid_d1 <= '0;
        end else begin
            dcache_if_req_valid_d1 <= dcache_if.req_valid;
        end
    end

    // dcache_if.req_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            dcache_if.req_valid <= '0;
        end else if (exe_mem_write_en) begin
            dcache_if.req_valid <= '1;
        end else begin
            dcache_if.req_valid <= '0;
        end
    end
    
    // dcache_if.write_en
    assign dcache_if.write_en = o_exe_mem.opcode == OP_STORE;

    // dcache_if.req_addr
    assign dcache_if.req_addr = o_exe_mem.alu_result;

    // dcache_if.write_data
    assign dcache_if.write_data = o_exe_mem.rs2_data;

    // dcache_if.size
    always_comb begin
        dcache_if.size = MEM_SIZE_W;
        if (o_exe_mem.opcode == OP_LOAD) begin
            case (o_exe_mem.funct3)
                LOAD_FUN3_LB, LOAD_FUN3_LBU:  dcache_if.size = MEM_SIZE_B;
                LOAD_FUN3_LH, LOAD_FUN3_LHU:  dcache_if.size = MEM_SIZE_H;
                LOAD_FUN3_LW:                 dcache_if.size = MEM_SIZE_W;
            endcase
        end else if (o_exe_mem.opcode == OP_STORE) begin
            case (o_exe_mem.funct3)
                STORE_FUN3_SB: dcache_if.size = MEM_SIZE_B;
                STORE_FUN3_SH: dcache_if.size = MEM_SIZE_H;
                STORE_FUN3_SW: dcache_if.size = MEM_SIZE_W;
            endcase
        end
    end

    // dcache_if.sign
    always_comb begin
        dcache_if.sign = 1'b0;
        if (o_exe_mem.opcode == OP_LOAD) begin
            case (o_exe_mem.funct3)
                LOAD_FUN3_LB,
                LOAD_FUN3_LH,
                LOAD_FUN3_LW:  dcache_if.sign = 1'b1;
                LOAD_FUN3_LBU,
                LOAD_FUN3_LHU: dcache_if.sign = 1'b0;
            endcase
        end
    end

endmodule

// When [self_trig] rises, [self_valid] rises immediately.
// When data is taken, [self_valid] falls at the same time.
// If condition is not met, [self_valid] will always be 0.
module _trigValid (
    input logic clk,
    input logic rst,
    input logic self_trig,
    input logic next_ready,
    input logic condition,
    output logic self_valid
);
    logic help;
    always_ff @(posedge clk, negedge rst) begin
        if (!rst) begin
            help <= '0;
        end else if (self_trig) begin
            help <= '1;
        end else if (next_ready && self_valid) begin    
            help <= '0;
        end
    end
    assign self_valid = (self_trig || help) && condition;
endmodule