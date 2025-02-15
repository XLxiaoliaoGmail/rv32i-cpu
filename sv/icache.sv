`include "_riscv_defines.sv"

// 外部接口
interface icache_if;
    import _riscv_defines::*;
    // PC -> ICache
    logic [ADDR_WIDTH-1:0] req_addr; 
    logic                  req_valid;
    // ICache -> PC
    logic [DATA_WIDTH-1:0] resp_data; 
    logic                  resp_valid;
    logic                  resp_ready;

    modport master (
        output req_addr,
        output req_valid,
        input  resp_data,
        input  resp_valid,
        input  resp_ready
    );

    modport self (
        input  req_addr,
        input  req_valid,
        output resp_data,
        output resp_valid,
        input  resp_ready
    );
endinterface

// icache顶层模块
module icache (
    input  logic clk,
    input  logic rst_n,
    // CPU接口
    icache_if.self icache_if,
    // AXI接口
    axi_read_if.master axi_if
);
    import _riscv_defines::*;

    // 缓存行结构体定义
    typedef struct packed {
        logic valid; // 有效位
        logic [ICACHE_TAG_WIDTH-1:0] tag;   // tag域
        logic [ICACHE_LINE_SIZE*8-1:0] data;// 数据域(32字节=256位)
    } cache_line_t;

    cache_line_t [ICACHE_WAY_NUM-1:0][ICACHE_SET_NUM-1:0] cache_mem; // 缓存存储器

    logic [3:0] rx_counter;

    // 组选择器
    logic [ICACHE_SET_NUM-1:0] lru; // LRU位

    // Choose a way to replace
    logic replace_way;

    logic [ICACHE_TAG_WIDTH-1:0]     addr_tag;
    logic [ICACHE_INDEX_WIDTH-1:0]   addr_index;
    logic [ICACHE_LINE_OFFSET-1:0]   addr_line_offset;

    assign addr_tag = icache_if.req_addr[DATA_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH];
    assign addr_index = icache_if.req_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH];
    assign addr_line_offset = icache_if.req_addr[DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-1 : DATA_WIDTH-ICACHE_TAG_WIDTH-ICACHE_INDEX_WIDTH-ICACHE_LINE_OFFSET];

    /************************ HIT CHECK *****************************/

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

    /************************ STATE MACHINE *****************************/

    // state_t
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        AXI_AR,
        AXI_R
    } state_t;
    
    state_t now_state, next_state, now_state_d1;

    // now_state_d1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            now_state_d1 <= IDLE;
        end else begin
            now_state_d1 <= now_state;
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
                    next_state = AXI_AR;
                end
            end
            AXI_AR: begin
                if (axi_if.arready) begin
                    next_state = AXI_R;
                end
            end
            AXI_R: begin
                if (axi_if.rlast) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    /************************ ICACHE IF *****************************/

    // icache_if.resp_ready
    assign icache_if.resp_ready = now_state == IDLE;

    // icache_if.resp_data
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            icache_if.resp_data <= '0;
        end else if (now_state == LOOKUP && hit_valid) begin
            // Just 2 ways
            icache_if.resp_data <= cache_mem[hit[1] ? 1'b1 : 1'b0][addr_index].data[
                addr_line_offset * 8 +: DATA_WIDTH];
        end else if (now_state == AXI_R && rx_counter == addr_line_offset) begin
            icache_if.resp_data <= axi_if.rdata;
        end
    end

    // icache_if.resp_valid
    always_comb begin
        icache_if.resp_valid = 1'b0;
        if (now_state == LOOKUP && hit_valid) begin
            icache_if.resp_valid = 1'b1;
        end else if (now_state == AXI_R && rx_counter == addr_line_offset && axi_if.rvalid && axi_if.rready) begin
            icache_if.resp_valid = 1'b1;
        end
    end

    always_comb begin
        replace_way = lru[addr_index];
    end

    /************************ AXI IF *****************************/

    // axi_if.arvalid
    always_comb begin
        axi_if.arvalid = (now_state == AXI_AR);
    end

    // axi_if.araddr
    assign axi_if.araddr = (now_state == AXI_AR) ? {icache_if.req_addr[31:5], 5'b0} : '0;

    // axi_if.arlen
    assign axi_if.arlen = 8'd7;

    // axi_if.arsize
    assign axi_if.arsize = AXI_SIZE_4B;

    // axi_if.arburst
    assign axi_if.arburst = AXI_BURST_INCR;

    // axi_if.rready
    always_comb begin
        axi_if.rready = (now_state == AXI_R);
    end

    // rx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_counter <= 4'd0;
        end else if (axi_if.rvalid && axi_if.rready) begin
            rx_counter <= rx_counter + 1;
        end else begin
            rx_counter <= 4'd0;
        end
    end

    /************************ CACHE MEM *****************************/

    // cache_memdata
    always_ff @(posedge clk or negedge rst_n) begin
        if (axi_if.rvalid && axi_if.rready) begin
            cache_mem[replace_way][addr_index].data[rx_counter * DATA_WIDTH +: DATA_WIDTH] <= axi_if.rdata;
        end
    end

    // cache_mem.valid
    // cache_mem.tag
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ICACHE_WAY_NUM; i++) begin
                for (int j = 0; j < ICACHE_SET_NUM; j++) begin
                    cache_mem[i][j].valid <= 1'b0;
                    cache_mem[i][j].tag <= '0;
                end
            end
        end else if (axi_if.rlast) begin
            cache_mem[replace_way][addr_index].valid <= 1'b1;
            cache_mem[replace_way][addr_index].tag <= addr_tag;
        end
    end

    // lru
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < ICACHE_SET_NUM; i++) begin
                lru[i] <= 1'b0;
            end
        end else if (axi_if.rlast) begin
            lru[addr_index] <= ~replace_way;
        end
    end
endmodule