`include "_axi_defines.sv"
`include "_riscv_defines.sv"
`include "_if_defines.sv"

module _tb_axi_read;
    import _riscv_defines::*;
    import _axi_defines::*;

    // 时钟和复位信号
    logic clk;
    logic rst_n;

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 复位生成
    initial begin
        rst_n = 0;
        #100 rst_n = 1;
    end

    // 接口实例化
    axi_read_master_if master_ctrl_if();
    axi_read_slave_if  slave_mem_if();
    axi_read_if        axi_if();

    // DUT实例化
    axi_read_master master_inst (
        .clk    (clk),
        .rst_n  (rst_n),
        .ctrl_if(master_ctrl_if),
        .axi_if (axi_if)
    );

    axi_read_slave slave_inst (
        .clk    (clk),
        .rst_n  (rst_n),
        .axi_if (axi_if),
        .mem_if (slave_mem_if)
    );

    // 测试存储器模型
    logic [31:0] test_memory [1024];

    // 模拟存储器响应
    always_ff @(posedge clk) begin
        if (slave_mem_if.mem_read_en) begin
            slave_mem_if.mem_rdata <= test_memory[slave_mem_if.mem_addr[11:2]];
        end
    end

    // 测试激励
    initial begin
        // 等待复位完成
        @(posedge rst_n);
        @(posedge clk);

        // 初始化测试数据
        for (int i = 0; i < 1024; i++) begin
            test_memory[i] = i;
        end

        // 测试用例1：单次读取
        $display("Test Case 1: Single Read");
        master_ctrl_if.read_req = 1'b1;
        master_ctrl_if.read_addr = 32'h1 << 2;
        master_ctrl_if.read_len = 8'h0;
        
        wait(master_ctrl_if.read_done);
        @(posedge clk);
        master_ctrl_if.read_req = 1'b0;
        
        // 测试用例2：突发读取
        $display("Test Case 2: Burst Read");
        @(posedge clk);
        master_ctrl_if.read_req = 1'b1;
        master_ctrl_if.read_addr = 32'h40;
        master_ctrl_if.read_len = 8'h7;  // 8次传输
        
        wait(master_ctrl_if.read_done);
        @(posedge clk);
        master_ctrl_if.read_req = 1'b0;

        // 等待一段时间后结束仿真
        #1000;
        $display("Simulation finished");
        $stop;
    end

    // 监视器：打印传输信息
    always @(posedge clk) begin
        if (axi_if.rvalid && axi_if.rready) begin
            $display("Time=%0t Read Data: %h", $time, axi_if.rdata);
        end
    end

    // 检查超时
    initial begin
        #100000;  // 10us
        $display("Timeout!");
        $stop;
    end

endmodule
