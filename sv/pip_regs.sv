`include "_pkg_riscv_defines.sv"

module pip_regs
import _pkg_riscv_defines::*;
(

    input  logic clk,
    input  logic rst_n,
 
    input  logic fet_dec_write_en,
    input  logic dec_exe_write_en,
    input  logic exe_mem_write_en,
    input  logic mem_wb_write_en,
 
    input  pip_reg_fet_dec_t  i_fet_dec,
    input  pip_reg_dec_exe_t  i_dec_exe,
    input  pip_reg_exe_mem_t  i_exe_mem,
    input  pip_reg_mem_wb_t   i_mem_wb,

    output pip_reg_fet_dec_t o_fet_dec,
    output pip_reg_dec_exe_t o_dec_exe,
    output pip_reg_exe_mem_t o_exe_mem,
    output pip_reg_mem_wb_t  o_mem_wb
    
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_fet_dec <= '0;
        end else if (i_fet_dec_write_en) begin
            o_fet_dec <= i_fet_dec;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_dec_exe <= '0;
        end else if (i_dec_exe_write_en) begin
            o_dec_exe <= i_dec_exe;
        end
    end     

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_exe_mem <= '0;
        end else if (i_exe_mem_write_en) begin
            o_exe_mem <= i_exe_mem;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_mem_wb <= '0;
        end else if (i_mem_wb_write_en) begin
            o_mem_wb <= i_mem_wb;
        end
    end
endmodule

