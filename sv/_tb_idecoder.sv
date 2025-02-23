`include "_pkg_riscv_defines.sv"

module _tb_idecoder;
    import _pkg_riscv_defines::*;
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

    //always #5  clk = ! clk ;

endmodule