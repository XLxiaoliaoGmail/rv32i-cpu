`include "_riscv_defines.sv"

module instruction_memory
import _riscv_defines::*;
(
    input  logic                clk,
    input  logic [ADDR_WIDTH-1:0] addr,
    output logic [DATA_WIDTH-1:0] instruction
);

    // 指令存储器，大小为4KB
    logic [7:0] mem [INSTR_MEM_SIZE];

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
    logic [31:0] temp_mem[0:INSTR_MEM_SIZE/4-1];
    
    // 复位时初始化内存
    initial begin
        // 从文件加载32位指令到临时数组
        $readmemh("./sv/test/alu_test", temp_mem);
        
        // 将32位指令拆分为8位存储到mem中
        for (int i = 0; i < INSTR_MEM_SIZE/4; i++) begin
            // 小端序存储 (Little Endian)
            mem[i*4+0] = temp_mem[i][7:0];  
            mem[i*4+1] = temp_mem[i][15:8]; 
            mem[i*4+2] = temp_mem[i][23:16];
            mem[i*4+3] = temp_mem[i][31:24];
        end
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