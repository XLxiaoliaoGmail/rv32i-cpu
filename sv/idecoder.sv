`include "_pkg_riscv_defines.sv"

// RISC-V 指令格式:
//
// R-type format (Register-Register)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |   funct7   |  rs2   |  rs1   |funct3|   rd    | opcode |
// 
// I-type format (Immediate-Register)
// 31                   20 19    15 14  12 11      7 6       0
// |       imm[11:0]      |  rs1   |funct3|   rd    | opcode |
//
// S-type format (Store)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |  imm[11:5] |  rs2   |  rs1   |funct3|imm[4:0] | opcode |
//
// B-type format (Branch)
// 31        25 24     20 19     15 14  12 11      7 6      0
// |imm[12|10:5]|  rs2   |  rs1   |funct3|imm[4:1|11]|opcode|
//
// U-type format (Upper Immediate)
// 31                                  12 11      7 6      0
// |              imm[31:12]             |   rd    | opcode |
//
// J-type format (Jump)
// 31                                  12 11      7 6      0
// |        imm[20|10:1|11|19:12]        |   rd    | opcode |

interface idecoder_if;
    import _pkg_riscv_defines::*;

    logic [31:0]               instruction;
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;
    logic [REG_ADDR_WIDTH-1:0] rd_addr;
    opcode_t                   opcode;
    logic [2:0]                funct3;
    logic [6:0]                funct7;
    logic [DATA_WIDTH-1:0]     imm;
    logic                      req_valid;
    logic                      resp_valid;
    logic                      resp_ready;

    modport master (
        output instruction,
        input  rs1_addr,
        input  rs2_addr,
        input  rd_addr,
        input  opcode,
        input  funct3,
        input  funct7,
        input  imm,
        input  req_valid,
        output resp_valid,
        input  resp_ready
    );

    modport self (
        input  instruction,
        output rs1_addr,
        output rs2_addr,
        output rd_addr,
        output opcode,
        output funct3,
        output funct7,
        output imm,
        input  req_valid,
        output resp_valid,
        input  resp_ready
    );
endinterface

module idecoder
import _pkg_riscv_defines::*;
(
    input  logic clk,
    input  logic rst_n,
    idecoder_if.self idecoder_if
);
    parameter _SIMULATED_DELAY = 4;

    logic [2:0] _counter;
    logic handling;

    // handling
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            handling <= '0;
        end else if (idecoder_if.req_valid) begin
            handling <= '1;
        end else if (idecoder_if.resp_valid) begin
            handling <= '0;
        end
    end

    // _counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            _counter <= _SIMULATED_DELAY;
        end else if (handling) begin
            _counter <= _counter - 1;
        end else begin
            _counter <= _SIMULATED_DELAY;
        end
    end

    assign idecoder_if.resp_ready = ~handling;

    // resp_valid
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            idecoder_if.resp_valid <= '0;
        end else if (_counter == 0) begin
            idecoder_if.resp_valid <= '1;
        end else begin
            idecoder_if.resp_valid <= '0;
        end
    end

    // 指令字段提取
    assign idecoder_if.opcode = opcode_t'(idecoder_if.instruction[6:0]);  // 添加显式类型转换  

    // 根据指令类型选择性地提取字段
    always_comb begin
        // 默认值
        idecoder_if.rs1_addr = '0;
        idecoder_if.rs2_addr = '0;
        idecoder_if.rd_addr = '0;
        idecoder_if.funct3 = '0;
        idecoder_if.funct7 = '0;
        idecoder_if.imm = '0;

        case (idecoder_if.opcode)
            // R型指令
            OP_R_TYPE: begin
                idecoder_if.rd_addr = idecoder_if.instruction[11:7];
                idecoder_if.funct3 = idecoder_if.instruction[14:12];
                idecoder_if.rs1_addr = idecoder_if.instruction[19:15];
                idecoder_if.rs2_addr = idecoder_if.instruction[24:20];
                idecoder_if.funct7 = idecoder_if.instruction[31:25];
            end

            // I-type format (Immediate-Register)
            OP_I_TYPE, OP_LOAD, OP_JALR: begin
                idecoder_if.rd_addr = idecoder_if.instruction[11:7];
                idecoder_if.funct3 = idecoder_if.instruction[14:12];
                idecoder_if.rs1_addr = idecoder_if.instruction[19:15];
                idecoder_if.funct7 = idecoder_if.instruction[31:25];
                idecoder_if.imm = {{20{idecoder_if.instruction[31]}}, idecoder_if.instruction[31:20]};
            end

            // S型指令
            OP_STORE: begin
                idecoder_if.funct3 = idecoder_if.instruction[14:12];
                idecoder_if.rs1_addr = idecoder_if.instruction[19:15];
                idecoder_if.rs2_addr = idecoder_if.instruction[24:20];
                idecoder_if.imm = {{20{idecoder_if.instruction[31]}}, idecoder_if.instruction[31:25], idecoder_if.instruction[11:7]};
            end

            // B型指令
            OP_BRANCH: begin
                idecoder_if.funct3 = idecoder_if.instruction[14:12];
                idecoder_if.rs1_addr = idecoder_if.instruction[19:15];
                idecoder_if.rs2_addr = idecoder_if.instruction[24:20];
                idecoder_if.imm = {{20{idecoder_if.instruction[31]}}, idecoder_if.instruction[7], idecoder_if.instruction[30:25], 
                      idecoder_if.instruction[11:8], 1'b0};
            end

            // J-type format (Jump)
            // 31                                  12 11      7 6      0
            // |        idecoder_if.imm[20|10:1|11|19:12]        |   rd    | idecoder_if.opcode |
            OP_JAL: begin
                idecoder_if.rd_addr = idecoder_if.instruction[11:7];
                idecoder_if.imm = {
                    {12{idecoder_if.instruction[31]}},    // 符号扩展 [31:20]
                    idecoder_if.instruction[19:12],       // idecoder_if.imm[19:12]
                    idecoder_if.instruction[20],          // idecoder_if.imm[11]
                    idecoder_if.instruction[30:21],       // idecoder_if.imm[10:1]
                    1'b0                      // idecoder_if.imm[0]
                };
            end

            // U型指令
            OP_LUI, OP_AUIPC: begin
                idecoder_if.rd_addr = idecoder_if.instruction[11:7];
                idecoder_if.imm = {idecoder_if.instruction[31:12], 12'b0};
            end

            default: begin
                idecoder_if.rs1_addr = '0;
                idecoder_if.rs2_addr = '0;
                idecoder_if.rd_addr = '0;
                idecoder_if.funct3 = '0;
                idecoder_if.funct7 = '0;
                idecoder_if.imm = '0;
            end
        endcase
    end

endmodule