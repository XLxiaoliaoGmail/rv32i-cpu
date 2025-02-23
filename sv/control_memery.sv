`include "_pkg_riscv_defines.sv"

module control_memory
import _pkg_riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    // control signal
    dcache_if.master dcache_if,
    // pip signal
    pip_exe_mem_if.post pip_to_pre_if,
    // pause
    input logic pause
);
    logic pause_d1;
    always_ff @(posedge clk) begin
        pause_d1 <= pause;
    end

    /************************ TO-PRE *****************************/
    // pip_to_pre_if.ready
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_pre_if.ready <= 1;
        end else if (pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            pip_to_pre_if.ready <= 0;
        end else if (~pause && dcache_if.ready) begin
            pip_to_pre_if.ready <= 1;
        end
    end

    /************************ DCACHE *****************************/

    // dcache_if.req_valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcache_if.req_valid <= 0;
        end else if (~pause && pause_d1) begin
            dcache_if.req_valid <= 1;
        end else if (dcache_if.req_valid && dcache_if.resp_ready) begin
            dcache_if.req_valid <= 0;
        end else if (~pause && pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            dcache_if.req_valid <= 1;
        end
    end

    assign dcache_if.write_data = pip_to_pre_if.rs2_data;
    assign dcache_if.req_addr = pip_to_pre_if.alu_result;
    assign dcache_if.write_en = pip_to_pre_if.opcode == OP_STORE;

    // dcache_if.size
    always_comb begin
        dcache_if.size = MEM_SIZE_W;
        if (pip_to_pre_if.opcode == OP_LOAD) begin
            case (pip_to_pre_if.funct3)
                LOAD_FUN3_LB, LOAD_FUN3_LBU:  dcache_if.size = MEM_SIZE_B;
                LOAD_FUN3_LH, LOAD_FUN3_LHU:  dcache_if.size = MEM_SIZE_H;
                LOAD_FUN3_LW:                 dcache_if.size = MEM_SIZE_W;
            endcase
        end else if (pip_to_pre_if.opcode == OP_STORE) begin
            case (pip_to_pre_if.funct3)
                STORE_FUN3_SB: dcache_if.size = MEM_SIZE_B;
                STORE_FUN3_SH: dcache_if.size = MEM_SIZE_H;
                STORE_FUN3_SW: dcache_if.size = MEM_SIZE_W;
            endcase
        end
    end

    // dcache_if.sign
    always_comb begin
        dcache_if.sign = 1'b0;
        if (pip_to_pre_if.opcode == OP_LOAD) begin
            case (pip_to_pre_if.funct3)
                LOAD_FUN3_LB,
                LOAD_FUN3_LH,
                LOAD_FUN3_LW:  dcache_if.sign = 1'b1;
                LOAD_FUN3_LBU,
                LOAD_FUN3_LHU: dcache_if.sign = 1'b0;
            endcase
        end
    end
endmodule