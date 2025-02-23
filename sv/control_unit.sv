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

    control_fetch control_fetch_inst (
        .clk(clk),
        .rst_n(rst_n),
        .icache_if(icache_if),
        .pip_to_post_if(pip_fet_dec_if),
        .pause(),
        .pc_write_en(),
        .pc_next()
    );

    control_decode control_decode_inst (
        .clk(clk),
        .rst_n(rst_n),
        .idecoder_if(idecoder_if),
        .reg_file_if(reg_file_if),
        .pip_to_pre_if(pip_fet_dec_if),
        .pip_to_post_if(pip_dec_exe_if),
        .pause(),
        .wb_rd_addr(),
        .wb_rd_data(),
        .wb_rd_en()
    );

    control_execute control_execute_inst (
        .clk(clk),
        .rst_n(rst_n),
        .alu_if(alu_if),
        .pip_to_pre_if(pip_dec_exe_if),
        .pip_to_post_if(pip_exe_mem_if),
        .pause()
    );

    control_memory control_memory_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dcache_if(dcache_if),
        .pip_to_pre_if(pip_exe_mem_if),
        .pause()
    );
    
endmodule