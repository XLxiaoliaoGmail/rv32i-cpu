// `include "_axi_defines.sv"
`include "_if_defines.sv"
`include "_riscv_defines.sv"

module icache 
import _riscv_defines::*, _axi_defines::*;
(
    input  logic clk,
    input  logic rst_n,
    
    // CPU接口
    cpu_cache_if.cache cpu_if,
    
    // AXI接口
    axi_read_if.master axi_if
);

    // Cache配置参数
    localparam WAYS_NUM      = 2;            // 2路组相联
    localparam INDEX_WIDTH   = 6;            // 索引位宽：6位
    localparam OFFSET_WIDTH  = 5;            // 偏移位宽：5位
    localparam TAG_WIDTH     = ADDR_WIDTH - INDEX_WIDTH - OFFSET_WIDTH;  // Tag位宽：21位
    localparam SETS_NUM      = 1 << INDEX_WIDTH; // 组数：64
    localparam LINE_SIZE     = 1 << OFFSET_WIDTH;// Cache line大小：32字节

    // Cache存储结构
    typedef struct packed {
        logic                  valid;
        logic                  lru;
        logic [TAG_WIDTH-1:0]  tag;
        logic [LINE_SIZE*8-1:0] data;
    } cache_line_t;

    cache_line_t [WAYS_NUM-1:0][SETS_NUM] cache_mem;

    // 地址分解
    logic [TAG_WIDTH-1:0]    addr_tag;
    logic [INDEX_WIDTH-1:0]  addr_index;
    logic [OFFSET_WIDTH-1:0] addr_offset;
    logic [$clog2(LINE_SIZE/4)-1:0] refill_count;

    // TAG INDEX OFFSET
    assign addr_tag    = cpu_if.addr[ADDR_WIDTH-1:INDEX_WIDTH+OFFSET_WIDTH];
    assign addr_index  = cpu_if.addr[INDEX_WIDTH+OFFSET_WIDTH-1:OFFSET_WIDTH];
    assign addr_offset = cpu_if.addr[OFFSET_WIDTH-1:0];

    // Cache状态机
    typedef enum logic [1:0] {
        IDLE,
        COMPARE_TAG,
        REFILL,
        WAIT_AXI
    } cache_state_t;

    cache_state_t current_state, next_state;

    // Cache控制信号
    logic hit;
    logic [WAYS_NUM-1:0] way_hit;
    logic [WAYS_NUM-1:0] replace_way;

    // AXI读控制器接口
    axi_read_master_if axi_master_if(clk);

    // 实例化AXI读控制器
    axi_read_master axi_read_master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .ctrl_if(axi_master_if.handler),
        .axi_if(axi_if)
    );

    // 状态机
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // next_state
    always_comb begin
        case(current_state)
            IDLE: begin
                if(cpu_if.req) next_state = COMPARE_TAG;
                else next_state = IDLE;
            end
            COMPARE_TAG: begin
                if(hit) next_state = IDLE;
                else next_state = REFILL;
            end
            REFILL: begin
                if(axi_master_if.read_ready && axi_master_if.read_req) next_state = WAIT_AXI;
                else next_state = REFILL;
            end
            WAIT_AXI: begin
                if(axi_master_if.read_done) next_state = IDLE;
                else next_state = WAIT_AXI;
            end
            default: next_state = current_state;
        endcase
    end

    // 命中检查
    always_comb begin
        way_hit = '0;
        hit = 1'b0;
        for(int i = 0; i < WAYS_NUM; i++) begin
            if(cache_mem[i][addr_index].valid && 
               cache_mem[i][addr_index].tag == addr_tag) begin
                way_hit[i] = 1'b1;
                hit = 1'b1;
            end
        end
    end

    // LRU更新逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(int i = 0; i < SETS_NUM; i++) begin
                cache_mem[0][i].lru <= 1'b0;
                cache_mem[1][i].lru <= 1'b0;
            end
        end else if(hit && cpu_if.req) begin
            // 更新LRU位
            cache_mem[0][addr_index].lru <= way_hit[1];
            cache_mem[1][addr_index].lru <= way_hit[0];
        end
    end

    // AXI读请求控制
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            axi_master_if.read_req <= 1'b0;
            axi_master_if.read_addr <= '0;
            axi_master_if.read_len <= '0;
        end else if(current_state == REFILL && !axi_master_if.read_req) begin
            axi_master_if.read_req <= 1'b1;
            axi_master_if.read_addr <= {cpu_if.addr[ADDR_WIDTH-1:OFFSET_WIDTH], {OFFSET_WIDTH{1'b0}}};
            axi_master_if.read_len <= LINE_SIZE/4 - 1;
        end else if(axi_master_if.read_req && axi_master_if.read_ready) begin
            axi_master_if.read_req <= 1'b0;
        end
    end
    
    // 替换 way 选择
    assign replace_way[0] = !cache_mem[0][addr_index].valid ? 1'b1 :
                           !cache_mem[1][addr_index].valid ? 1'b0 :
                           cache_mem[1][addr_index].lru;
    assign replace_way[1] = !replace_way[0];

    // Cache填充
    always_ff @(posedge clk) begin
        if(current_state == WAIT_AXI && axi_if.rvalid) begin
            for(int i = 0; i < WAYS_NUM; i++) begin
                if(replace_way[i]) begin
                    cache_mem[i][addr_index].data[refill_count*32 +: 32] <= axi_master_if.read_data;
                    if(axi_if.rlast) begin
                        cache_mem[i][addr_index].valid <= 1'b1;
                        cache_mem[i][addr_index].tag <= addr_tag;
                    end
                end
            end
        end
    end

    // refill_count 计数器
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            refill_count <= '0;
        end else if(current_state == WAIT_AXI && axi_if.rvalid) begin
            if(axi_if.rlast) begin
                refill_count <= '0;
            end else begin
                refill_count <= refill_count + 1;
            end
        end
    end

    // 输出控制
    always_comb begin
        cpu_if.ready = (current_state == COMPARE_TAG && hit) || 
                       (current_state == WAIT_AXI && axi_master_if.read_done);
        
        // 从Cache中读取数据
        if(hit) begin
            for(int i = 0; i < WAYS_NUM; i++) begin
                if(way_hit[i]) begin
                    cpu_if.rdata = cache_mem[i][addr_index].data[addr_offset*8 +: 32];
                end
            end
        end else begin
            cpu_if.rdata = axi_master_if.read_data;
        end
    end
endmodule 