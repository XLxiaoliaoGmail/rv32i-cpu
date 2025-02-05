`include "_riscv_defines.sv"

module instruction_memory
import _riscv_defines::*;
(
    input  logic                clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] instruction
);

    // 指令存储器，大小为4KB
    logic [7:0] mem [4096];

    // 读取指令（小端序）
    assign instruction = {
        mem[addr+3],
        mem[addr+2],
        mem[addr+1],
        mem[addr]
    };

    // 指向下一条要添加的指令地址
    int next_instr_addr;

    // 复位时初始化指针
    initial begin
        next_instr_addr = 0;

        // 初始化寄存器
        // x1 用于存储结果
        // x2 用于存储当前数字
        // x3 用于存储最大值10
        add_instruction(32'h00000093);      // addi x1, x0, 0    # x1 = 0 (结果)
        add_instruction(32'h00100113);      // addi x2, x0, 1    # x2 = 1 (计数器)
        add_instruction(32'h00A00193);      // addi x3, x0, 10   # x3 = 10 (最大值)

        // 循环开始
        add_instruction(32'h002080B3);      // add x4, x1, x2    # x4 = x1 + x2
        // add_instruction(32'h00000093);      // addi x1, x0, 0    # x1 = 0 (结果)
        
        // 计数器加1
        add_instruction(32'h00110113);      // addi x2, x2, 1    # x2 = x2 + 1
        
        // 将x4的值复制到x1
        add_instruction(32'h00040093);      // addi x1, x4, 0    # x1 = x4 + 0
        
        // 比较是否达到最大值
        add_instruction(32'hfe311ce3);      // bne x2, x3, -4    # 如果x2!=x3,跳回循环开始

        // 程序结束，死循环
        add_instruction(32'h0000006F);      // jal x0, 0         # 死循环
    end

    // 添加指令的task
    task add_instruction;
        input logic [31:0] instr;
        begin
            mem[next_instr_addr]   = instr[7:0];  
            mem[next_instr_addr+1] = instr[15:8]; 
            mem[next_instr_addr+2] = instr[23:16];
            mem[next_instr_addr+3] = instr[31:24];
            next_instr_addr = next_instr_addr + 4;
        end
    endtask

endmodule 