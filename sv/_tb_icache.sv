`include "_riscv_defines.sv"
`include "_if_defines.sv"

module _tb_icache;
    import _riscv_defines::*;

    // 时钟和复位信号
    logic clk;
    logic rst_n;

    // 接口实例化
    icache_if icache_if();
    axi_read_if axi_if();

    // DUT实例化
    icache icache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .icache_if(icache_if),
        .axi_if(axi_if)
    );

    imem imem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .axi_if(axi_if)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试任务
    task reset_system;
        rst_n = 0;
        icache_if.pc_valid = 0;
        icache_if.pc_addr = '0;
        repeat(5) @(posedge clk);
        rst_n = 1;
    endtask

    // 请求指令任务
    task request_instruction(input logic [31:0] addr);
        @(posedge clk);
        icache_if.pc_valid = 1;
        icache_if.pc_addr = addr;
        wait(icache_if.instr_valid);
        @(posedge clk);
        icache_if.pc_valid = 0;
        repeat(10) @(posedge clk);
    endtask

    // 主测试过程
    initial begin
        // 初始化和复位
        reset_system();

        // 测试用例1: 缓存缺失
        request_instruction(32'b0000000000000000000_000001_00010_00);

        // 测试用例2: 缓存命中 (访问相同地址)
        request_instruction(32'b0000000000000000000_000001_00010_00);

        // 测试用例3: 填充另一路
        request_instruction(32'b0000000000000000001_000001_00010_00); // 不同的tag，相同的index

        // 测试用例4: LRU替换
        request_instruction(32'b0000000000000000010_000001_00010_00); // 将替换最少使用的路

        // 验证LRU替换是否正确
        request_instruction(32'b0000000000000000001_000001_00010_00); // 应该还在缓存中

        // 测试完成
        repeat(10) @(posedge clk);
        $stop;
    end

    // 超时保护
    initial begin
        #10000;
        $display("Time out!");
        $stop;
    end

endmodule