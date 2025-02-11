`include "_riscv_defines.sv"
`include "_if_defines.sv"

// icache顶层模块
module icache (
    input  logic        clk,
    input  logic        rst_n,
    // CPU接口
    pc_icache_if.icache pc_icache_if,
    // AXI接口
    axi_read_if.master  axi_if
);
    // 内部信号和接口
    inner_if_icache_core_to_axi inner_if();
    
    // 实例化子模块
    icache_core icache_core_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .pc_icache_if(pc_icache_if),
        .inner_if(inner_if.requester)
    );
    
    axi_read_master axi_read_master_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .axi_if      (axi_if),
        .inner_if(inner_if.responder)
    );
endmodule

// inner_if_icache_core_to_axi 接口
interface inner_if_icache_core_to_axi;
    import _riscv_defines::*;
    // 请求信号
    logic                      req_valid;
    logic [AXI_ADDR_WIDTH-1:0] req_addr;

    // 响应信号
    logic                   resp_valid;
    logic [ICACHE_LINE_SIZE*8-1:0] resp_data;

    // icache-core端口
    modport requester (
        output req_valid, req_addr,
        input  resp_valid, resp_data
    );

    // axi_if-read-master端口
    modport responder (
        input  req_valid, req_addr,
        output resp_valid, resp_data
    );
endinterface

// icache核心模块
module icache_core (
    input  logic        clk,
    input  logic        rst_n,
    // CPU接口
    pc_icache_if.icache pc_icache_if,
    // AXI读主机接口
    inner_if_icache_core_to_axi.requester inner_if
);
    import _riscv_defines::*;

    // 缓存行结构体定义
    typedef struct packed {
        logic valid; // 有效位
        logic [ICACHE_TAG_WIDTH-1:0] tag;   // tag域
        logic [ICACHE_LINE_SIZE*8-1:0] data;// 数据域(32字节=256位)
    } cache_line_t;

    // 缓存存储
    cache_line_t [ICACHE_WAY_NUM-1:0][ICACHE_SET_NUM-1:0] cache_mem; // 缓存存储器

    // 组选择器
    logic [ICACHE_SET_NUM-1:0] lru; // LRU位

    // Choose a way to replace
    logic replace_way;

    // 地址分解
    logic [ICACHE_TAG_WIDTH-1:0]     addr_tag;
    logic [ICACHE_INDEX_WIDTH-1:0]   addr_index;
    logic [ICACHE_LINE_OFFSET-1:0]   addr_line_offset;
    // 地址分解逻辑
    assign addr_tag = pc_icache_if.pc_addr[DATA_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH];
    assign addr_index = pc_icache_if.pc_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH];
    assign addr_line_offset = pc_icache_if.pc_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-ICACHE_LINE_OFFSET];

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,           // 空闲状态
        LOOKUP,         // 查找状态
        REFILL          // 重填状态
    } state_t;
    
    state_t curr_state, next_state;

    // 命中检查逻辑
    logic [ICACHE_WAY_NUM-1:0] hit;
    logic hit_valid;

    assign hit_valid = |hit;
    
    always_comb begin
        for(int i = 0; i < ICACHE_WAY_NUM; i++) begin
            hit[i] = cache_mem[i][addr_index].valid && 
                    (cache_mem[i][addr_index].tag == addr_tag);
        end
    end

    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    // 状态转换和控制逻辑

    // next_state
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (pc_icache_if.pc_valid) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                if (hit_valid) begin
                    next_state = IDLE;
                end else begin
                    next_state = REFILL;
                end
            end
            REFILL: begin
                if (inner_if.resp_valid) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // pc_icache_if.instr_valid
    always_comb begin
        pc_icache_if.instr_valid = 1'b0;
        if (curr_state == LOOKUP && hit_valid) begin
            pc_icache_if.instr_valid = 1'b1;
        end else if (curr_state == REFILL && inner_if.resp_valid) begin
            pc_icache_if.instr_valid = 1'b1;
        end
    end

    // inner_if.req_valid
    always_comb begin
        inner_if.req_valid = 1'b0;
        if (curr_state == LOOKUP && !hit_valid) begin
            inner_if.req_valid = 1'b1;
        end
    end

    // pc_icache_if.instruction
    always_comb begin
        pc_icache_if.instruction = 32'b0;
        if (curr_state == LOOKUP && hit_valid) begin
            // Just 2 ways
            pc_icache_if.instruction = cache_mem[hit[1] ? 1'b1 : 1'b0][addr_index].data[
                addr_line_offset * 32 +: 32];
        end else if (curr_state == REFILL && inner_if.resp_valid) begin
            pc_icache_if.instruction = inner_if.resp_data[addr_line_offset * 32 +: 32];
        end
    end

    // inner_if.req_addr
    always_comb begin
        inner_if.req_addr = 32'b0;
        if (curr_state == LOOKUP && !hit_valid) begin
            // 一次请求 ICACHE_LINE_OFFSET 个命令, 故需要偏移 ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET 个字节
            inner_if.req_addr = {pc_icache_if.pc_addr[DATA_WIDTH-1:ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET], {(ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET){1'b0}}};
        end
    end

    always_comb begin
        replace_way = lru[addr_index];
    end

    // cache_mem
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ICACHE_WAY_NUM; i++) begin
                for (int j = 0; j < ICACHE_SET_NUM; j++) begin
                    cache_mem[i][j].valid <= 1'b0;
                end
            end
        end else if (curr_state == REFILL && inner_if.resp_valid) begin
            cache_mem[replace_way][addr_index].valid <= 1'b1;
            cache_mem[replace_way][addr_index].tag <= addr_tag;
            cache_mem[replace_way][addr_index].data <= inner_if.resp_data;
        end
    end

    // lru
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ICACHE_SET_NUM; i++) begin
                lru[i] <= 1'b0;
            end
        end else if (curr_state == REFILL && inner_if.resp_valid) begin
            lru[addr_index] <= ~replace_way;
        end
    end

    
endmodule

// AXI读主机模块
module axi_read_master (
    input  logic       clk,
    input  logic       rst_n,
    // AXI接口
    axi_read_if.master axi_if,
    // AXI读主机接口
    inner_if_icache_core_to_axi.responder inner_if
);
    import _riscv_defines::*;

    // AXI状态机
    typedef enum logic [1:0] {
        IDLE,
        AR_CHANNEL,
        R_CHANNEL
    } axi_state_t;
    
    axi_state_t curr_state, next_state;

    // 保存请求地址
    logic [AXI_ADDR_WIDTH-1:0] req_addr_reg;
    // 数据计数器（用于接收32字节数据）
    logic [4:0] data_counter;
    // 缓存接收到的数据
    logic [ICACHE_LINE_SIZE*8-1:0] cached_data;

    // 状态机时序逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    // 状态转换逻辑
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (inner_if.req_valid) begin
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

    // 保存请求地址
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            req_addr_reg <= '0;
        end else if (curr_state == IDLE && inner_if.req_valid) begin
            req_addr_reg <= inner_if.req_addr;
        end
    end

    // 数据计数器逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_counter <= '0;
        end else if (curr_state == R_CHANNEL && axi_if.rvalid && axi_if.rready) begin
            data_counter <= data_counter + 1;
        end else if (curr_state == IDLE) begin
            data_counter <= '0;
        end
    end

    // 缓存数据逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cached_data <= '0;
        end else if (curr_state == R_CHANNEL && axi_if.rvalid && axi_if.rready) begin
            cached_data[data_counter * 32 +: 32] <= axi_if.rdata;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inner_if.resp_valid <= '0;
        end else if (curr_state == R_CHANNEL && axi_if.rvalid && axi_if.rlast) begin
            inner_if.resp_valid <= '1;
        end else begin
            inner_if.resp_valid <= '0;
        end
    end

    // AXI读地址通道信号
    assign axi_if.arvalid = (curr_state == AR_CHANNEL);
    assign axi_if.araddr  = req_addr_reg;
    assign axi_if.arlen   = 8'h7;           // 8次传输（32字节）
    assign axi_if.arsize  = AXI_SIZE_4B;    // 每次4字节
    assign axi_if.arburst = AXI_BURST_INCR; // INCR模式

    // AXI读数据通道信号
    assign axi_if.rready = (curr_state == R_CHANNEL);

    // axi_rm_if响应信号
    // assign inner_if.resp_valid = (curr_state == R_CHANNEL && axi_if.rvalid && axi_if.rlast);
    assign inner_if.resp_data = cached_data;
endmodule