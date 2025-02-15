`include "_riscv_defines.sv"

// 外部接口
interface icache_if;
import _riscv_defines::*;
    // PC -> ICache信号
    logic [ADDR_WIDTH-1:0] pc_addr;     // 程序计数器地址
    logic                  req_valid;    // PC地址有效信号
    
    // ICache -> PC信号
    logic [DATA_WIDTH-1:0] instruction; // 指令数据
    logic                  resp_valid; // 指令有效信号

    modport master (
        output pc_addr,
        output req_valid,
        input  instruction,
        input  resp_valid
    );

    modport self (
        input  pc_addr,
        input  req_valid,
        output instruction,
        output resp_valid
    );
endinterface

// icache顶层模块
module icache (
    input  logic clk,
    input  logic rst_n,
    // CPU接口
    icache_if.self icache_if,
    // AXI接口
    axi_read_if.master  axi_if
);
    import _riscv_defines::*;
    axi_read_master_if #(
        ._RESP_DATA_WIDTH(ICACHE_LINE_SIZE*8)
    ) axi_read_master_if();
    
    icache_core icache_core_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .icache_if(icache_if),
        .axi_read_master_if(axi_read_master_if.master)
    );
    
    axi_read_master #(
        ._RESP_DATA_WIDTH(ICACHE_LINE_SIZE*8),
        ._AR_LEN(8'h7),
        ._AR_SIZE(AXI_SIZE_4B),
        ._AR_BURST(AXI_BURST_INCR)
    ) axi_read_master_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .axi_if      (axi_if),
        .axi_read_master_if(axi_read_master_if.self)
    );
endmodule

// icache核心模块
module icache_core (
    input  logic        clk,
    input  logic        rst_n,

    icache_if.self icache_if,

    axi_read_master_if.master axi_read_master_if
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

    logic [ICACHE_TAG_WIDTH-1:0]     addr_tag;
    logic [ICACHE_INDEX_WIDTH-1:0]   addr_index;
    logic [ICACHE_LINE_OFFSET-1:0]   addr_line_offset;

    assign addr_tag = icache_if.pc_addr[DATA_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH];
    assign addr_index = icache_if.pc_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH];
    assign addr_line_offset = icache_if.pc_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-ICACHE_LINE_OFFSET];

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,           // 空闲状态
        LOOKUP,         // 查找状态
        REFILL          // 重填状态
    } state_t;
    
    state_t now_state, next_state;

    // 命中检查逻辑
    logic [ICACHE_WAY_NUM-1:0] hit;
    logic hit_valid;

    assign hit_valid = |hit;
    
    // hit
    always_comb begin
        for(int i = 0; i < ICACHE_WAY_NUM; i++) begin
            hit[i] = cache_mem[i][addr_index].valid && 
                    (cache_mem[i][addr_index].tag == addr_tag);
        end
    end

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
                if (icache_if.req_valid) begin
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
                if (axi_read_master_if.resp_valid) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // icache_if.resp_valid
    always_comb begin
        icache_if.resp_valid = 1'b0;
        if (now_state == LOOKUP && hit_valid) begin
            icache_if.resp_valid = 1'b1;
        end else if (now_state == REFILL && axi_read_master_if.resp_valid) begin
            icache_if.resp_valid = 1'b1;
        end
    end

    // axi_read_master_if.req_valid
    always_comb begin
        axi_read_master_if.req_valid = 1'b0;
        if (now_state == LOOKUP && !hit_valid) begin
            axi_read_master_if.req_valid = 1'b1;
        end
    end

    // icache_if.instruction
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icache_if.instruction <= '0;
        end else if (now_state == LOOKUP && hit_valid) begin
            // Just 2 ways
            icache_if.instruction <= cache_mem[hit[1] ? 1'b1 : 1'b0][addr_index].data[
                addr_line_offset * 32 +: 32];
        end else if (now_state == REFILL && axi_read_master_if.resp_valid) begin
            icache_if.instruction <= axi_read_master_if.resp_data[addr_line_offset * 32 +: 32];
        end
    end

    // axi_read_master_if.req_addr
    always_comb begin
        axi_read_master_if.req_addr = 32'b0;
        if (now_state == LOOKUP && !hit_valid) begin
            // 一次请求 ICACHE_LINE_OFFSET 个命令, 故需要偏移 ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET 个字节
            axi_read_master_if.req_addr = {icache_if.pc_addr[DATA_WIDTH-1:ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET], {(ICACHE_LINE_OFFSET+ICACHE_BYTE_OFFSET){1'b0}}};
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
        end else if (now_state == REFILL && axi_read_master_if.resp_valid) begin
            cache_mem[replace_way][addr_index].valid <= 1'b1;
            cache_mem[replace_way][addr_index].tag <= addr_tag;
            cache_mem[replace_way][addr_index].data <= axi_read_master_if.resp_data;
        end
    end

    // lru
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ICACHE_SET_NUM; i++) begin
                lru[i] <= 1'b0;
            end
        end else if (now_state == REFILL && axi_read_master_if.resp_valid) begin
            lru[addr_index] <= ~replace_way;
        end
    end
endmodule
