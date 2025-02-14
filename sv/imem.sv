`include "_riscv_defines.sv"
`include "_axi_if.sv"

// imem顶层模块
module imem (
    input  logic        clk,
    input  logic        rst_n,

    axi_read_if.slave   axi_if
);
    axi_read_slave_if axi_read_slave_if();
    
    imem_core imem_core_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .axi_read_slave_if  (axi_read_slave_if.self)
    );
    
    axi_read_slave axi_read_slave_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .axi_if   (axi_if),
        .axi_read_slave_if  (axi_read_slave_if.master)
    );
endmodule

// imem核心模块
module imem_core (
    input  logic        clk,
    input  logic        rst_n,

    axi_read_slave_if.self axi_read_slave_if
);
    import _riscv_defines::*;

    parameter IMEM_SIZE = 1 << 13;

    // 指令存储器
    logic [31:0] imem_words [IMEM_SIZE];
    
    // 延迟计数器(10周期)
    logic [3:0] delay_counter;
    
    // 保存请求信息
    logic [AXI_ADDR_WIDTH-1:0] curr_addr;

    // 初始化指令存储器
    initial begin
        read_imem();
    end

    task read_imem();
        $readmemh("./sv/test/mem_test.bin", imem_words);
    endtask

    // delay_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_counter <= '0;
        end else if (axi_read_slave_if.req_valid && !axi_read_slave_if.processing) begin
            delay_counter <= 4'd10;  // 模拟读取延迟
        end else if (delay_counter > 0) begin
            delay_counter <= delay_counter - 1;
        end
    end

    // axi_read_slave_if.processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_slave_if.processing <= 1'b0;
        end else if (axi_read_slave_if.req_valid && !axi_read_slave_if.processing) begin
            axi_read_slave_if.processing <= 1'b1;
        end else if (delay_counter == 0 && axi_read_slave_if.processing) begin
            axi_read_slave_if.processing <= 1'b0;
        end
    end

    // 保存请求地址逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_addr <= '0;
        end else if (axi_read_slave_if.req_valid && !axi_read_slave_if.processing) begin
            curr_addr <= axi_read_slave_if.req_addr;
        end
    end

    // 响应有效信号逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_slave_if.resp_valid <= 1'b0;
        end else if (delay_counter == 1) begin
            axi_read_slave_if.resp_valid <= 1'b1;
        end else begin
            axi_read_slave_if.resp_valid <= 1'b0;
        end
    end

    // 响应数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_slave_if.resp_data <= '0;
        end else if (delay_counter == 1) begin
            for (int i = 0; i < 8; i++) begin
                axi_read_slave_if.resp_data[i*32 +: 32] <= imem_words[curr_addr[AXI_ADDR_WIDTH-1:2] + i];
            end
        end
    end
endmodule


