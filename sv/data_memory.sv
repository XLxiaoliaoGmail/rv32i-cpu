`include "_riscv_defines.sv"

module data_memory
import _riscv_defines::*;
(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    we,
    input  logic [ADDR_WIDTH-1:0]   addr,
    input  logic [DATA_WIDTH-1:0]   wdata,
    output logic [DATA_WIDTH-1:0]   rdata
);

    // 数据存储器，大小为4KB
    logic [7:0] mem [4096];

    // 读取数据（小端序）
    assign rdata = {
        mem[addr+3],
        mem[addr+2],
        mem[addr+1],
        mem[addr]
    };

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