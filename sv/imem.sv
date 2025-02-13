`include "_riscv_defines.sv"
`include "_axi_if.sv"

// imem顶层模块
module imem (
    input  logic        clk,
    input  logic        rst_n,

    axi_read_if.slave   axi_if
);
    _imem_if _imem_if();
    
    imem_core imem_core_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        ._imem_if  (_imem_if.responder)
    );
    
    axi_read_slave axi_read_slave_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .axi_if   (axi_if),
        ._imem_if  (_imem_if.requester)
    );
endmodule

// imem核心到AXI从机的接口
interface _imem_if;
    import _riscv_defines::*;
    // 请求信号
    logic                      req_valid;
    logic [AXI_ADDR_WIDTH-1:0] req_addr;
    logic                      processing;

    // 响应信号
    logic                           resp_valid;
    logic [ICACHE_LINE_BIT_LEN*8-1:0]  resp_data;  // 8个字(32字节)数据

    modport requester (
        output req_valid, req_addr,
        input  resp_valid, resp_data, processing
    );

    modport responder (
        input  req_valid, req_addr,
        output resp_valid, resp_data, processing
    );
endinterface

// imem核心模块
module imem_core (
    input  logic        clk,
    input  logic        rst_n,

    _imem_if.responder _imem_if
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
        end else if (_imem_if.req_valid && !_imem_if.processing) begin
            delay_counter <= 4'd10;  // 模拟读取延迟
        end else if (delay_counter > 0) begin
            delay_counter <= delay_counter - 1;
        end
    end

    // _imem_if.processing
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _imem_if.processing <= 1'b0;
        end else if (_imem_if.req_valid && !_imem_if.processing) begin
            _imem_if.processing <= 1'b1;
        end else if (delay_counter == 0 && _imem_if.processing) begin
            _imem_if.processing <= 1'b0;
        end
    end

    // 保存请求地址逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_addr <= '0;
        end else if (_imem_if.req_valid && !_imem_if.processing) begin
            curr_addr <= _imem_if.req_addr;
        end
    end

    // 响应有效信号逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _imem_if.resp_valid <= 1'b0;
        end else if (delay_counter == 1) begin
            _imem_if.resp_valid <= 1'b1;
        end else begin
            _imem_if.resp_valid <= 1'b0;
        end
    end

    // 响应数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _imem_if.resp_data <= '0;
        end else if (delay_counter == 1) begin
            for (int i = 0; i < 8; i++) begin
                _imem_if.resp_data[i*32 +: 32] <= imem_words[curr_addr[AXI_ADDR_WIDTH-1:2] + i];
            end
        end
    end
endmodule

// AXI读从机模块
module axi_read_slave (
    input  logic       clk,
    input  logic       rst_n,
    // AXI接口
    axi_read_if.slave  axi_if,
    // IMEM接口
    _imem_if.requester _imem_if
);
    import _riscv_defines::*;

    // AXI状态机
    typedef enum logic [2:0] {
        IDLE,
        AR_CHANNEL,
        WAIT_IMEM,
        R_CHANNEL,
        R_DONE
    } axi_state_t;
    
    axi_state_t curr_state, next_state;
    
    // 数据发送计数器
    logic [7:0] send_counter;
    // 缓存从imem接收的数据
    logic [ICACHE_LINE_BIT_LEN*8-1:0] cached_data;
    
    // 地址和长度寄存器
    logic [AXI_ADDR_WIDTH-1:0] addr_reg;
    logic [7:0]                len_reg;

    // curr_state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    // next_state
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (axi_if.arvalid) begin
                    next_state = AR_CHANNEL;
                end
            end
            AR_CHANNEL: begin
                next_state = WAIT_IMEM;
            end
            WAIT_IMEM: begin
                if (_imem_if.resp_valid) begin
                    next_state = R_CHANNEL;
                end
            end
            R_CHANNEL: begin
                if (axi_if.rvalid && axi_if.rready && send_counter == axi_if.arlen) begin
                    next_state = R_DONE;
                end
            end
            R_DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // req_addr
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _imem_if.req_addr <= '0;
        end else if (curr_state == IDLE && axi_if.arvalid) begin
            _imem_if.req_addr <= axi_if.araddr;
        end
    end

    // 发送计数器逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_counter <= '0;
        end else if (curr_state == R_CHANNEL && axi_if.rvalid && axi_if.rready) begin
            send_counter <= send_counter + 1;
        end else if (curr_state == IDLE) begin
            send_counter <= '0;
        end
    end

    // 缓存数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cached_data <= '0;
        end else if (curr_state == WAIT_IMEM && _imem_if.resp_valid) begin
            cached_data <= _imem_if.resp_data;
        end
    end

    // IMEM请求信号
    assign _imem_if.req_valid = (curr_state == AR_CHANNEL);
    
    // addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg <= '0;
        end else if (curr_state == IDLE && axi_if.arvalid) begin
            addr_reg <= axi_if.araddr;
        end
    end

    // len_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len_reg <= '0;
        end else if (curr_state == IDLE && axi_if.arvalid) begin
            len_reg <= axi_if.arlen;
        end
    end

    // AXI读地址通道信号
    assign axi_if.arready = (curr_state == IDLE);

    // AXI读数据通道信号
    assign axi_if.rvalid = (curr_state == R_CHANNEL);
    assign axi_if.rdata = send_counter[3] ? 0 : cached_data[send_counter * 32 +: 32];
    assign axi_if.rlast = (curr_state == R_CHANNEL && send_counter == axi_if.arlen);
    assign axi_if.rresp = AXI_RESP_OKAY;

endmodule