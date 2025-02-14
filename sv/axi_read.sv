`include "_riscv_defines.sv"

interface axi_read_master_if #(
    parameter _RESP_DATA_WIDTH
);
    import _riscv_defines::*;
    // 请求信号
    logic                      req_valid;
    logic [AXI_ADDR_WIDTH-1:0] req_addr;

    // 响应信号
    logic                   resp_valid;
    logic [_RESP_DATA_WIDTH-1:0] resp_data;

    modport master (
        output req_valid, req_addr,
        input  resp_valid, resp_data
    );

    modport self (
        input  req_valid, req_addr,
        output resp_valid, resp_data
    );
endinterface

module axi_read_master #(
    parameter _RESP_DATA_WIDTH,
    parameter _AR_LEN,
    parameter _AR_SIZE,
    parameter _AR_BURST
) (
    input  logic       clk,
    input  logic       rst_n,

    axi_read_if.master axi_if,

    axi_read_master_if.self axi_read_master_if
);
    import _riscv_defines::*;

    // AXI状态机
    typedef enum logic [1:0] {
        IDLE,
        AR_CHANNEL,
        R_CHANNEL
    } axi_state_t;
    
    axi_state_t now_state, next_state;

    logic [AXI_ADDR_WIDTH-1:0] req_addr_reg;

    logic [$clog2(_AR_LEN+1)-1:0] data_counter;

    logic [_RESP_DATA_WIDTH-1:0] buffer;

    // now_state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            now_state <= IDLE;
        end else begin
            now_state <= next_state;
        end
    end

    // next_state
    always_comb begin
        next_state = now_state;
        case (now_state)
            IDLE: begin
                if (axi_read_master_if.req_valid) begin
                    next_state = AR_CHANNEL;
                end
            end
            AR_CHANNEL: begin
                if (axi_if.arready) begin
                    next_state = R_CHANNEL;
                end
            end
            R_CHANNEL: begin
                if (axi_if.rvalid && axi_if.rlast) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // req_addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_addr_reg <= '0;
        end else if (now_state == IDLE && axi_read_master_if.req_valid) begin
            req_addr_reg <= axi_read_master_if.req_addr;
        end
    end

    // data_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_counter <= '0;
        end else if (now_state == R_CHANNEL && axi_if.rvalid && axi_if.rready) begin
            data_counter <= data_counter + 1;
        end else if (now_state == IDLE) begin
            data_counter <= '0;
        end
    end

    // buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= '0;
        end else if (now_state == R_CHANNEL && axi_if.rvalid && axi_if.rready) begin
            buffer[(data_counter << AXI_ADDR_WIDTH_LOG2) +: AXI_ADDR_WIDTH] <= axi_if.rdata;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_master_if.resp_valid <= '0;
        end else if (now_state == R_CHANNEL && axi_if.rvalid && axi_if.rlast) begin
            axi_read_master_if.resp_valid <= '1;
        end else begin
            axi_read_master_if.resp_valid <= '0;
        end
    end

    // AXI读地址通道信号
    assign axi_if.arvalid = (now_state == AR_CHANNEL);
    assign axi_if.araddr  = req_addr_reg;
    assign axi_if.arlen   = _AR_LEN;
    assign axi_if.arsize  = _AR_SIZE;
    assign axi_if.arburst = _AR_BURST;

    // AXI读数据通道信号
    assign axi_if.rready = (now_state == R_CHANNEL);

    // axi_rm_if响应信号
    assign axi_read_master_if.resp_data = buffer;
endmodule

interface axi_read_slave_if #(
    parameter _RESP_DATA_WIDTH
);
    import _riscv_defines::*;
    // 请求信号
    logic                      req_valid;
    logic [AXI_ADDR_WIDTH-1:0] req_addr;
    logic                      processing;

    // 响应信号
    logic                         resp_valid;
    logic [_RESP_DATA_WIDTH-1:0]  resp_data; 

    modport master (
        output req_valid, req_addr,
        input  resp_valid, resp_data, processing
    );

    modport self (
        input  req_valid, req_addr,
        output resp_valid, resp_data, processing
    );
endinterface

module axi_read_slave #(
    parameter _RESP_DATA_WIDTH,
    parameter _SEND_COUNTER_WIDTH
) (
    input  logic       clk,
    input  logic       rst_n,
    // AXI接口
    axi_read_if.slave  axi_if,
    // IMEM接口
    axi_read_slave_if.master axi_read_slave_if
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
    
    logic [_SEND_COUNTER_WIDTH-1:0] send_counter;

    logic [_RESP_DATA_WIDTH-1:0] buffer;
    
    logic [AXI_ADDR_WIDTH-1:0] addr_reg;

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
                if (axi_read_slave_if.resp_valid) begin
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
            axi_read_slave_if.req_addr <= '0;
        end else if (curr_state == IDLE && axi_if.arvalid) begin
            axi_read_slave_if.req_addr <= axi_if.araddr;
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
            buffer <= '0;
        end else if (curr_state == WAIT_IMEM && axi_read_slave_if.resp_valid) begin
            buffer <= axi_read_slave_if.resp_data;
        end
    end

    // IMEM请求信号
    assign axi_read_slave_if.req_valid = (curr_state == AR_CHANNEL);
    
    // addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg <= '0;
        end else if (curr_state == IDLE && axi_if.arvalid) begin
            addr_reg <= axi_if.araddr;
        end
    end

    // AXI读地址通道信号
    assign axi_if.arready = (curr_state == IDLE);

    // AXI读数据通道信号
    assign axi_if.rvalid = (curr_state == R_CHANNEL);
    assign axi_if.rdata = buffer[(send_counter << AXI_ADDR_WIDTH_LOG2) +: AXI_ADDR_WIDTH];
    assign axi_if.rlast = (curr_state == R_CHANNEL && send_counter == axi_if.arlen);
    assign axi_if.rresp = AXI_RESP_OKAY;

endmodule
