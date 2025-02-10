`include "_riscv_defines.sv"
`include "_axi_defines.sv"

module tb_icache;
    import _riscv_defines::*;
    import _axi_defines::*;

    // 时钟和复位信号
    logic clk;
    logic rst_n;
    
    // CPU接口信号
    logic [ADDR_WIDTH-1:0] cpu_addr;
    logic                  cpu_req;
    logic [DATA_WIDTH-1:0] cpu_rdata;
    logic                  cpu_ready;
    
    // AXI接口信号
    logic [AXI_ID_WIDTH-1:0]   axi_arid;
    logic [AXI_ADDR_WIDTH-1:0] axi_araddr;
    logic [7:0]                axi_arlen;
    logic [2:0]                axi_arsize;
    logic [1:0]                axi_arburst;
    logic                      axi_arvalid;
    logic                      axi_arready;
    logic [AXI_ID_WIDTH-1:0]   axi_rid;
    logic [AXI_DATA_WIDTH-1:0] axi_rdata;
    logic [1:0]                axi_rresp;
    logic                      axi_rlast;
    logic                      axi_rvalid;
    logic                      axi_rready;

    // 实例化 icache
    icache dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_addr),
        .cpu_req(cpu_req),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),
        .axi_arid(axi_arid),
        .axi_araddr(axi_araddr),
        .axi_arlen(axi_arlen),
        .axi_arsize(axi_arsize),
        .axi_arburst(axi_arburst),
        .axi_arvalid(axi_arvalid),
        .axi_arready(axi_arready),
        .axi_rid(axi_rid),
        .axi_rdata(axi_rdata),
        .axi_rresp(axi_rresp),
        .axi_rlast(axi_rlast),
        .axi_rvalid(axi_rvalid),
        .axi_rready(axi_rready)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试任务：检查数据是否正确
    task check_data;
        input [DATA_WIDTH-1:0] expected;
        input string test_name;
        begin
            if (cpu_rdata === expected) begin
                $display("[PASS] %s: Expected: %h, Got: %h", test_name, expected, cpu_rdata);
            end else begin
                $display("[FAIL] %s: Expected: %h, Got: %h", test_name, expected, cpu_rdata);
            end
        end
    endtask

    // 模拟AXI内存响应
    task axi_memory_response;
        input [AXI_DATA_WIDTH-1:0] data;
        begin
            @(posedge clk);
            axi_arready <= 1;
            @(posedge clk);
            axi_arready <= 0;
            
            repeat(2) @(posedge clk);
            
            axi_rvalid <= 1;
            axi_rdata <= data;
            axi_rid <= axi_arid;
            axi_rresp <= AXI_RESP_OKAY;
            axi_rlast <= 1;
            
            @(posedge clk);
            while (!axi_rready) @(posedge clk);
            
            axi_rvalid <= 0;
            axi_rlast <= 0;
        end
    endtask

    // 测试主体
    initial begin
        // 初始化信号
        rst_n = 0;
        cpu_addr = 0;
        cpu_req = 0;
        axi_arready = 0;
        axi_rvalid = 0;
        axi_rdata = 0;
        axi_rid = 0;
        axi_rresp = 0;
        axi_rlast = 0;

        // 等待5个时钟周期后释放复位
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        // 测试1：Cache Miss - 第一次访问
        $display("\n=== Test 1: Cache Miss (First Access) ===");
        cpu_addr = 32'h1000;
        cpu_req = 1;
        fork
            begin
                axi_memory_response(32'hdeadbeef);
            end
            begin
                @(posedge cpu_ready);
                check_data(32'hdeadbeef, "Cache Miss");
            end
        join
        cpu_req = 0;
        @(posedge clk);

        // 测试2：Cache Hit - 访问相同地址
        $display("\n=== Test 2: Cache Hit (Same Address) ===");
        repeat(2) @(posedge clk);
        cpu_addr = 32'h1000;
        cpu_req = 1;
        @(posedge cpu_ready);
        check_data(32'hdeadbeef, "Cache Hit");
        cpu_req = 0;
        @(posedge clk);

        // 测试3：Cache Miss - 访问不同组的地址
        $display("\n=== Test 3: Cache Miss (Different Set) ===");
        cpu_addr = 32'h2000;
        cpu_req = 1;
        fork
            begin
                axi_memory_response(32'hcafebabe);
            end
            begin
                @(posedge cpu_ready);
                check_data(32'hcafebabe, "Cache Miss Different Set");
            end
        join
        cpu_req = 0;
        @(posedge clk);

        // 测试4：Cache Hit - 再次访问第一个地址
        $display("\n=== Test 4: Cache Hit (First Address Again) ===");
        cpu_addr = 32'h1000;
        cpu_req = 1;
        @(posedge cpu_ready);
        check_data(32'hdeadbeef, "Cache Hit Previous Data");
        cpu_req = 0;

        // 测试结束
        repeat(5) @(posedge clk);
        $display("\n=== All tests completed ===\n");
        $finish;
    end

    // 超时保护
    initial begin
        #10000;
        $display("Timeout! Test failed.");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("icache_test.vcd");
        $dumpvars(0, tb_icache);
    end

endmodule
