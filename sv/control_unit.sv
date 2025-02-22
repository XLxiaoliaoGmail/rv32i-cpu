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

    /************************ PIPLINE REGS *****************************/

    pip_reg_fet_dec_t  pip_reg_fet_dec;
    pip_reg_dec_exe_t  pip_reg_dec_exe;
    pip_reg_exe_mem_t  pip_reg_exe_mem;
    pip_reg_mem_wb_t   pip_reg_mem_wb;
    
    phase_status_t status_fet;
    phase_status_t status_dec;
    phase_status_t status_exe;
    phase_status_t status_mem;
    phase_status_t status_wb;

    // status_fet
    assign status_fet.valid = icache_if.resp_valid;
    assign status_fet.ready = '1;

    // status_dec
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            status_dec <= '0;
        end
    end

    // status_exe
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            status_exe <= '0;
        end
    end

    // status_mem
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            status_mem <= '0;
        end
    end

    // status_wb    
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            status_wb <= '0;
        end
    end

    // pip_reg_fet_dec
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pip_reg_fet_dec <= '0;
        end
    end

    // pip_reg_dec_exe
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pip_reg_dec_exe <= '0;
        end
    end

    // pip_reg_exe_mem
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pip_reg_exe_mem <= '0;
        end
    end

    // pip_reg_mem_wb
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            pip_reg_mem_wb <= '0;
        end
    end

    /************************ ICACHE *****************************/

    logic [ADDR_WIDTH-1:0] now_pc;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            now_pc <= '0;
        end
    end

    logic [DATA_WIDTH-1:0] instruction;
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            instruction <= '0;
        end else if (icache_if.resp_valid) begin
            instruction <= icache_if.resp_data;
        end
    end

    logic instruction_readed;

    // icache_if.req_valid
    assign icache_if.req_valid = instruction_readed;
    assign icache_if.req_addr = now_pc;
endmodule