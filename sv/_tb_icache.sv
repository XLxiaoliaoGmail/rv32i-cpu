`include "_axi_defines.sv"
`include "_if_defines.sv"
`include "_riscv_defines.sv"

module _tb_icache;
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

    // 实例化接口
    cpu_cache_if cpu_if(clk);
    axi_read_if axi_if(clk);

    // DUT实例化
    icache dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_if(cpu_if.cache),
        .axi_if(axi_if.master)
    );

    // AXI从机模拟
    logic [31:0] test_memory [1024];
    logic [7:0] axi_read_count;
    
    initial begin
        // 初始化测试内存
        for(int i = 0; i < 1024; i++) begin
            test_memory[i] = i;
        end
    end

    // AXI从机响应逻辑
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_if.arready <= 0;
            axi_if.rvalid <= 0;
            axi_if.rlast <= 0;
            axi_if.rdata <= 0;
            axi_read_count <= 0;
        end else begin
            // 地址通道
            if(axi_if.arvalid && !axi_if.arready) begin
                axi_if.arready <= 1;
            end else begin
                axi_if.arready <= 0;
            end

            // 数据通道
            if(axi_if.arvalid && axi_if.arready) begin
                axi_read_count <= 0;
            end else if(axi_if.rvalid && axi_if.rready) begin
                axi_read_count <= axi_read_count + 1;
            end

            if(axi_if.arvalid && axi_if.arready) begin
                axi_if.rvalid <= 1;
                axi_if.rdata <= test_memory[axi_if.araddr[11:2]];
            end else if(axi_if.rvalid && axi_if.rready && !axi_if.rlast) begin
                axi_if.rdata <= test_memory[axi_if.araddr[11:2] + axi_read_count + 1];
            end else if(axi_if.rlast && axi_if.rready) begin
                axi_if.rvalid <= 0;
            end

            axi_if.rlast <= axi_if.rvalid && (axi_read_count == 7);
        end
    end

    // 测试任务
    task test_cache_miss;
        input [31:0] addr;
        begin
            $display("Testing cache miss at address %h", addr);
            cpu_if.addr <= addr;
            cpu_if.req <= 1;
            @(posedge clk);
            wait(cpu_if.ready);
            cpu_if.req <= 0;
            $display("Read data: %h", cpu_if.rdata);
        end
    endtask

    task test_cache_hit;
        input [31:0] addr;
        begin
            $display("Testing cache hit at address %h", addr);
            cpu_if.addr <= addr;
            cpu_if.req <= 1;
            @(posedge clk);
            wait(cpu_if.ready);
            cpu_if.req <= 0;
            $display("Read data: %h", cpu_if.rdata);
        end
    endtask

    // 测试过程
    initial begin
        // 等待复位完成
        wait(rst_n);
        @(posedge clk);

        // 初始化CPU接口信号
        cpu_if.req <= 0;
        cpu_if.addr <= 0;

        // 测试用例1：缓存未命中
        #100;
        test_cache_miss(32'h0000_0000);
        
        // 测试用例2：缓存命中（重复访问相同地址）
        #100;
        test_cache_hit(32'h0000_0000);
        
        // 测试用例3：访问不同的cache line
        #100;
        test_cache_miss(32'h0000_1000);
        
        // 测试用例4：测试替换策略
        #100;
        test_cache_miss(32'h0000_2000);
        test_cache_miss(32'h0000_3000);
        test_cache_hit(32'h0000_2000);

        // 结束仿真
        #1000;
        $display("Simulation finished");
        $stop;
    end

endmodule
