`include "_riscv_defines.sv"
import _riscv_defines::*;

module _tb_riscv_core();

    // 定义时钟和复位信号
    logic clk;
    logic rst_n;
    logic [DATA_WIDTH-1:0] instruction;

    // 实例化 riscv_core
    riscv_core riscv_core_inst (
        .clk   (clk),
        .rst_n (rst_n),
        .instruction (instruction)
    );


    // 生成时钟信号，周期为 10
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 检查是否到达程序结束指令
    always @(posedge clk) begin
        if (instruction == 32'h0000006F) begin  // JAL x0, 0 指令
            $display("Program execution completed");
            #10;
            $stop;
        end
    end


    // 生成复位信号
    initial begin
        rst_n = 1;
        #10
        rst_n = 0;
        #10 rst_n = 1;
    end

endmodule
