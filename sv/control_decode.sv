`include "_pkg_riscv_defines.sv"

interface pip_dec_exe_if;
    import _pkg_riscv_defines::*;
    /************************ STATUS *****************************/
    logic valid;
    logic ready;
    /************************ DATA *****************************/
    // from pre stage
    logic [ADDR_WIDTH-1:0]      pc;
    // from current stage
    opcode_t                    opcode;
    logic [DATA_WIDTH-1:0]      rs1_data;
    logic [DATA_WIDTH-1:0]      rs2_data;
    logic [REG_ADDR_WIDTH-1:0]  rd_addr;
    logic [DATA_WIDTH-1:0]      imm;  
    logic [2:0]                 funct3;
    logic [6:0]                 funct7;

    modport pre(
        output valid,
        input  ready,
        output opcode,
        output pc,
        output rs1_data,
        output rs2_data,
        output rd_addr,
        output imm,  
        output funct3,
        output funct7
    );

    modport post(
        input  valid,
        output ready,
        input  opcode,
        input  pc,
        input  rs1_data,
        input  rs2_data,
        input  rd_addr,
        input  imm,  
        input  funct3,
        input  funct7
    );
endinterface

module control_decode
import _pkg_riscv_defines::*;
(
    input logic clk,
    input logic rst_n,
    // control signal
    idecoder_if.master idecoder_if,
    reg_file_if.master reg_file_if,
    // pip signal
    pip_fet_dec_if.post pip_to_pre_if,
    pip_dec_exe_if.pre pip_to_post_if,
    // pause
    input logic pause,
    input logic [REG_ADDR_WIDTH-1:0] wb_rd_addr,
    input logic [DATA_WIDTH-1:0] wb_rd_data,
    input logic wb_rd_en
);
    logic pause_d1;
    always_ff @(posedge clk) begin
        pause_d1 <= pause;
    end
    /************************ TO-PRE *****************************/
    // pip_to_pre_if.ready
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.ready <= 1;
        end else if (pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            pip_to_post_if.ready <= 0;
        end else if (~pause && idecoder_if.valid) begin
            pip_to_post_if.ready <= 1;
        end
    end
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
        end else if (~pause && idecoder_if.resp_valid) begin
            pip_to_post_if.valid <= 1;
        end
    end
    // pip_to_post_if.data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pip_to_post_if.opcode    <= '0;
            pip_to_post_if.pc        <= '0;
            pip_to_post_if.rs1_data  <= '0;
            pip_to_post_if.rs2_data  <= '0;
            pip_to_post_if.rd_addr   <= '0;
            pip_to_post_if.imm       <= '0;
            pip_to_post_if.funct3    <= '0;
            pip_to_post_if.funct7    <= '0;
        end else if (idecoder_if.resp_valid) begin
            // from idecoder
            pip_to_post_if.opcode    <= idecoder_if.opcode;
            pip_to_post_if.rd_addr   <= idecoder_if.rd_addr;
            pip_to_post_if.imm       <= idecoder_if.imm;  
            pip_to_post_if.funct3    <= idecoder_if.funct3;
            pip_to_post_if.funct7    <= idecoder_if.funct7;
            // from reg_file
            pip_to_post_if.rs1_data  <= reg_file_if.rs1_data;
            pip_to_post_if.rs2_data  <= reg_file_if.rs2_data;
            // from pre stage
            pip_to_post_if.pc        <= pip_to_pre_if.pc;
        end
    end
    /************************ IDECODER *****************************/
    // idecoder_if.req_valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idecoder_if.req_valid <= 0;
        end else if (~pause && pause_d1) begin
            idecoder_if.req_valid <= 1;
        end else if (idecoder_if.req_valid && idecoder_if.resp_ready) begin
            idecoder_if.req_valid <= 0;
        end else if (~pause && pip_to_pre_if.valid && pip_to_pre_if.ready) begin
            idecoder_if.req_valid <= 1;
        end
    end

    /************************ REG-FILE *****************************/
    // rs1 rs2
    assign reg_file_if.rs1_addr = idecoder_if.rs1_addr;
    assign reg_file_if.rs2_addr = idecoder_if.rs2_addr;
    // write back
    assign reg_file_if.rd_addr = wb_rd_addr;
    assign reg_file_if.rd_data = wb_rd_data;
    assign reg_file_if.write_en = wb_rd_en;
endmodule