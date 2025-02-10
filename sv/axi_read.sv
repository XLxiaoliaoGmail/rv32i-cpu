`include "_axi_defines.sv"
`include "_riscv_defines.sv"
`include "_if_defines.sv"

// AXI 读取主控模块
module axi_read_master
import _riscv_defines::*, _axi_defines::*;
(
    input  logic clk,
    input  logic rst_n,

    // 控制接口
    axi_read_master_if.handler ctrl_if,

    // AXI读接口
    axi_read_if.master  axi_if
);

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,
        ADDR,
        DATA,
        DONE
    } state_t;

    state_t current_state, next_state;

    // 计数器
    logic [$clog2(256)-1:0] data_count;

    // 状态机转换
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 下一状态逻辑
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (ctrl_if.read_req) next_state = ADDR;
            end
            ADDR: begin
                if (axi_if.arvalid && axi_if.arready) next_state = DATA;
            end
            DATA: begin
                if (axi_if.rvalid && axi_if.rlast) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // AXI读地址通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_if.arvalid <= 1'b0;
            axi_if.araddr  <= '0;
            axi_if.arlen   <= '0;
            axi_if.arburst <= AXI_BURST_INCR;
            axi_if.arsize  <= 3'b010;  // 4字节
            axi_if.arid    <= '0;
        end else if (current_state == ADDR && !axi_if.arvalid) begin
            axi_if.arvalid <= 1'b1;
            axi_if.araddr  <= ctrl_if.read_addr;
            axi_if.arlen   <= ctrl_if.read_len;
        end else if (axi_if.arvalid && axi_if.arready) begin
            axi_if.arvalid <= 1'b0;
        end
    end

    // AXI读数据通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_count <= '0;
            axi_if.rready <= 1'b0;
        end else if (current_state == DATA) begin
            axi_if.rready <= 1'b1;
            if (axi_if.rvalid) begin
                if (axi_if.rlast) begin
                    data_count <= '0;
                end else begin
                    data_count <= data_count + 1;
                end
            end
        end else begin
            axi_if.rready <= 1'b0;
        end
    end

    // 输出控制
    assign ctrl_if.read_ready = (current_state == IDLE);
    assign ctrl_if.read_done = (current_state == DONE);
    assign ctrl_if.read_data = axi_if.rdata;

endmodule

// AXI 读取从机模块
module axi_read_slave
import _riscv_defines::*, _axi_defines::*;
(
    input  logic clk,
    input  logic rst_n,

    // AXI读接口
    axi_read_if.slave  axi_if,

    // 内存接口
    axi_read_slave_if.controller mem_if
);

    // 状态机定义
    typedef enum logic [1:0] {
        S_IDLE,     // 空闲状态
        S_ADDR,     // 地址接收状态
        S_DATA,     // 数据发送状态
        S_WAIT      // 等待状态
    } state_t;

    state_t current_state, next_state;

    // 内部寄存器
    logic [7:0]  burst_count;    // 突发传输计数器
    logic [7:0]  burst_length;   // 突发传输长度
    logic [AXI_ADDR_WIDTH-1:0] current_addr;  // 当前地址

    // 状态机转换
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // 下一状态逻辑
    always_comb begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (axi_if.arvalid) next_state = S_ADDR;
            end
            S_ADDR: begin
                next_state = S_DATA;
            end
            S_DATA: begin
                if (axi_if.rready && axi_if.rvalid && axi_if.rlast) begin
                    next_state = S_IDLE;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

    // 地址通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_if.arready <= 1'b0;
            burst_length <= '0;
            current_addr <= '0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    axi_if.arready <= 1'b1;
                    if (axi_if.arvalid && axi_if.arready) begin
                        burst_length <= axi_if.arlen;
                        current_addr <= axi_if.araddr;
                        axi_if.arready <= 1'b0;
                    end
                end
                default: axi_if.arready <= 1'b0;
            endcase
        end
    end

    // 数据通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_if.rvalid <= 1'b0;
            axi_if.rlast  <= 1'b0;
            axi_if.rresp  <= AXI_RESP_OKAY;
            burst_count   <= '0;
            mem_if.mem_read_en <= 1'b0;
        end else begin
            case (current_state)
                S_ADDR: begin
                    mem_if.mem_read_en <= 1'b1;
                    burst_count <= '0;
                    axi_if.rvalid <= 1'b1;
                end
                S_DATA: begin
                    if (axi_if.rready && axi_if.rvalid) begin
                        if (burst_count == burst_length) begin
                            axi_if.rlast <= 1'b1;
                            mem_if.mem_read_en <= 1'b0;
                        end else begin
                            burst_count <= burst_count + 1;
                            current_addr <= current_addr + 4;  // 假设每次传输4字节
                            mem_if.mem_read_en <= 1'b1;
                        end
                    end
                end
                default: begin
                    axi_if.rvalid <= 1'b0;
                    axi_if.rlast  <= 1'b0;
                    mem_if.mem_read_en <= 1'b0;
                end
            endcase
        end
    end

    // 输出赋值
    assign mem_if.mem_addr = current_addr;
    assign axi_if.rdata = mem_if.mem_rdata;
    assign axi_if.rid = '0;  // 在这个简单实现中，我们不使用ID

endmodule 