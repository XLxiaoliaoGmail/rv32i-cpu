`include "_riscv_defines.sv"

module data_memory
import _riscv_defines::*;
(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    input  logic [1:0]              size_type,  // 00: byte, 01: halfword, 10: word
    input  logic                    sign_ext,   // 1: 进行符号扩展, 0: 零扩展
    output logic [DATA_WIDTH-1:0]   rdata
);

    // 数据存储器，大小为4KB
    logic [7:0] mem [4096];
    
    // 内部信号
    logic [7:0]  byte_data;    // 选中的字节
    logic [15:0] half_data;    // 选中的半字
    logic [31:0] word_data;    // 完整字

    // 根据地址选择相应的字节和半字
    assign byte_data = mem[addr];
    assign half_data = {mem[addr+1], mem[addr]};
    assign word_data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};

    // 读取数据处理（包含符号扩展）
    always_comb begin
        case (size_type)
            2'b00: rdata = sign_ext ? {{24{byte_data[7]}}, byte_data} : {24'b0, byte_data};    // byte
            2'b01: rdata = sign_ext ? {{16{half_data[15]}}, half_data} : {16'b0, half_data};   // halfword
            2'b10: rdata = word_data;                                                           // word
            default: rdata = word_data;
        endcase
    end

    // 写入数据
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4096; i++) begin
                mem[i] <= 8'h0;
            end
        end else if (we) begin
            mem[addr]   <= wdata[7:0];
            mem[addr+1] <= wdata[15:8];
            mem[addr+2] <= wdata[23:16];
            mem[addr+3] <= wdata[31:24];
        end
    end

endmodule 