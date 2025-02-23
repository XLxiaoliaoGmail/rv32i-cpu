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
    pip_fet_dec_if pip_fet_dec_if();
    pip_dec_exe_if pip_dec_exe_if();
    pip_exe_mem_if pip_exe_mem_if();

    /************************ FORWARD PC *****************************/

    forward_pc_if forward_pc_from_exe_if();

    logic wb_pc_en;
    logic [DATA_WIDTH-1:0] wb_pc;

    logic pause_fetch;
    always_comb begin
        pause_fetch = 0;
        // If jump or branch, pause fetch until EXE is ready 
        if (~pip_dec_exe_if.ready) begin
            case (pip_dec_exe_if.opcode)
                OP_JAL, OP_JALR, OP_BRANCH:
                    pause_fetch = 1;
            endcase
        end
    end
    
    assign wb_pc = forward_pc_from_exe_if.pc;
    assign wb_pc_en = forward_pc_from_exe_if.req;

    /************************ FORWARD REG *****************************/

    forward_regs_if forward_regs_from_exe_if();
    forward_regs_if forward_regs_from_mem_if();

    logic is_forward_from_exe;
    
    logic pause_decode;
    always_comb begin
        pause_decode = 0;
        // If DEC is about to use rs1 or rs2 that
        // the same as rd in EXE or MEM, pause
        // If EXE or MEM is ready,
        // means write back has been done, can continue
        if (~pip_dec_exe_if.ready) begin
            case (pip_dec_exe_if.rd_addr)
                idecoder_if.rs1_addr,
                idecoder_if.rs2_addr:
                    pause_decode = 1;
            endcase
        end
        if (~pip_exe_mem_if.ready) begin
            case (pip_exe_mem_if.rd_addr)
                idecoder_if.rs1_addr,
                idecoder_if.rs2_addr:
                    pause_decode = 1;
            endcase
        end
    end

    always_comb begin
        reg_file_if.rd_addr = 0;
        reg_file_if.rd_data = 0;
        is_forward_from_exe = 0;
        // Req will always be 1 until resp is 1
        if (forward_regs_from_mem_if.req) begin
            // MEM has higher priority
            reg_file_if.rd_addr = forward_regs_from_mem_if.addr;
            reg_file_if.rd_data = forward_regs_from_mem_if.data;
            is_forward_from_exe = 0;
        end else if (forward_regs_from_exe_if.req) begin
            reg_file_if.rd_addr = forward_regs_from_exe_if.addr;
            reg_file_if.rd_data = forward_regs_from_exe_if.data;
            is_forward_from_exe = 1;
        end
    end

    assign forward_regs_from_exe_if.resp = reg_file_if.write_en &&  is_forward_from_exe;
    assign forward_regs_from_mem_if.resp = reg_file_if.write_en && !is_forward_from_exe;

    assign reg_file_if.write_en = forward_regs_from_mem_if.req || forward_regs_from_exe_if.req;

    /************************ INSTANTIATION *****************************/

    control_fetch control_fetch_inst (
        .clk(clk),
        .rst_n(rst_n),
        .icache_if(icache_if),
        .pip_to_post_if(pip_fet_dec_if),
        .pause(pause_fetch),
        .pc_write_en(wb_pc_en),
        .pc_next(wb_pc)
    );

    control_decode control_decode_inst (
        .clk(clk),
        .rst_n(rst_n),
        .idecoder_if(idecoder_if),
        .reg_file_if(reg_file_if),
        .pip_to_pre_if(pip_fet_dec_if),
        .pip_to_post_if(pip_dec_exe_if),
        .pause(pause_decode)
    );

    control_execute control_execute_inst (
        .clk(clk),
        .rst_n(rst_n),
        .alu_if(alu_if),
        .pip_to_pre_if(pip_dec_exe_if),
        .pip_to_post_if(pip_exe_mem_if),
        .pause('0),
        .forward_regs_if(forward_regs_from_exe_if),
        .forward_pc_if(forward_pc_from_exe_if)
    );

    control_memory control_memory_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dcache_if(dcache_if),
        .pip_to_pre_if(pip_exe_mem_if),
        .pause('0),
        .forward_regs_if(forward_regs_from_mem_if)
    );
    
endmodule