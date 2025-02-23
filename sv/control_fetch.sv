`include "_pkg_riscv_defines.sv"

interface pip_fet_dec_if;
    import _pkg_riscv_defines::*;
    /************************ STATUS *****************************/
    logic valid;
    logic ready;
    /************************ DATA *****************************/
    // from current stage
    logic [ADDR_WIDTH-1:0] pc;         
    logic [DATA_WIDTH-1:0] ins;

    modport pre(
        output valid,
        output pc,
        output ins,
        input ready
    );

    modport post(
        input valid,
        input pc,
        input ins,
        output ready
    );
    
endinterface

module control_fetch
import _pkg_riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    // control signal
    icache_if.master icache_if,
    // pip signal
    pip_fet_dec_if.pre pip_to_post_if,
    // pause
    input logic pause,
    // forward
    input logic pc_write_en,
    input [DATA_WIDTH-1:0] pc_next
);
    logic [DATA_WIDTH-1:0] pc;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 0;
        end else if (pc_write_en) begin
            pc <= pc_next;
        end else if (~pause && pip_to_post_if.ready && pip_to_post_if.valid) begin
            pc <= pc + 4;
        end
    end
    logic rst_n_d1;
    always_ff @(posedge clk) begin
        rst_n_d1 <= rst_n;
    end
    logic pause_d1;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pause_d1 <= 0;
        end else begin
            pause_d1 <= pause;
        end
    end
    /************************ TO-POST *****************************/
    // The icache valid & data just keep for one cycle
    // So must sample here.
    // This code will cause a cycle delay, can be optimized.

    // pip_to_post_if.valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.valid <= 0;
        end else if (pip_to_post_if.ready && pip_to_post_if.valid) begin
            // Instruction will be taken.
            pip_to_post_if.valid <= 0;
        end else if (~pause && icache_if.resp_valid) begin
            pip_to_post_if.valid <= 1;
        end
    end
    // pip_to_post_if.ins
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.ins <= 0;
        end else if (~pause && icache_if.resp_valid) begin
            pip_to_post_if.ins <= icache_if.resp_data;
        end
    end
    // pip_to_post_if.pc
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.pc <= 0;
        end else if (~pause && icache_if.resp_valid) begin
            pip_to_post_if.pc <= pc;
        end
    end

    /************************ ICACHE *****************************/
    // icache_if.req_valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icache_if.req_valid <= 0;
        end else if (rst_n && ~rst_n_d1) begin
            icache_if.req_valid <= 1;
        end else if (icache_if.req_valid && icache_if.resp_ready) begin
            icache_if.req_valid <= 0;
        end else if (~pause && pause_d1) begin
            icache_if.req_valid <= 1;
        end else if (~pause && pip_to_post_if.ready && pip_to_post_if.valid) begin
            icache_if.req_valid <= 1;
        end
    end
    // icache_if.req_addr
    assign icache_if.req_addr = pc;
endmodule