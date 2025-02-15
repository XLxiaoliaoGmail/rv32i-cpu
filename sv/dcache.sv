`include "_riscv_defines.sv"

interface dcache_if;
    import _riscv_defines::*;
    // PC -> DCache
    logic                    req_valid;
    logic                    write_en;
    logic [ADDR_WIDTH-1:0]   req_addr;
    logic [DATA_WIDTH-1:0]   write_data;
    mem_read_size_t          size;
    logic                    sign;
    // DCache -> PC
    logic [DATA_WIDTH-1:0]   resp_data;
    logic                    resp_valid;
    logic                    resp_ready;

    modport self (
        input  req_valid,
        input  write_en,
        input  req_addr,
        input  write_data,
        input  size,
        input  sign,
        output resp_data,
        output resp_valid,
        input  resp_ready
    );

    modport master (
        output req_valid,
        output write_en,
        output req_addr,
        output write_data,
        output size,
        output sign,
        input  resp_data,
        input  resp_valid,
        input  resp_ready
    );
endinterface

module dcache (
    input  logic clk,
    input  logic rst_n,
    dcache_if.self dcache_if,
    axi_read_if.master  axi_read_if,
    axi_write_if.master axi_write_if
);
    import _riscv_defines::*;

    // 缓存行结构体定义
    typedef struct packed {
        logic valid; // 有效位
        logic dirty; // 脏位
        logic [DCACHE_TAG_WIDTH-1:0] tag;   // tag域
        logic [2**DCACHE_OFFSET_WIDTH-1:0][7:0] bytes;// 数据域(32字节=256位)
    } cache_line_t;

    cache_line_t [DCACHE_WAY_NUM-1:0][DCACHE_SET_NUM-1:0] cache_mem;

    // Save option
    typedef struct packed {
        logic                    write_en;
        logic [ADDR_WIDTH-1:0]   req_addr;
        logic [DATA_WIDTH-1:0]   write_data;
        mem_read_size_t          size;
        logic                    sign;
    } save_option_t;

    save_option_t save_option;

    logic [3:0] rx_counter;
    logic [3:0] tx_counter;

    logic [DCACHE_WAY_NUM-1:0] way_hit_flag;
    logic some_way_hit;
    logic hit_way_index;
    logic replace_way;

    logic [DCACHE_SET_NUM-1:0] lru;

    logic [DCACHE_TAG_WIDTH-1:0]     addr_tag;
    logic [DCACHE_INDEX_WIDTH-1:0]   addr_index;
    logic [DCACHE_OFFSET_WIDTH-1:0]   addr_line_offset;
    logic [DCACHE_OFFSET_WIDTH-1:0]   addr_line_offset_align_to_word;
    logic [DCACHE_OFFSET_WIDTH-1:0]   addr_line_offset_align_to_hword;

    assign addr_tag = save_option.req_addr[DATA_WIDTH-1 : DATA_WIDTH-DCACHE_TAG_WIDTH];
    assign addr_index = save_option.req_addr[DATA_WIDTH-DCACHE_TAG_WIDTH-1 : DATA_WIDTH-DCACHE_TAG_WIDTH-DCACHE_INDEX_WIDTH];

    assign addr_line_offset = save_option.req_addr[DCACHE_OFFSET_WIDTH-1 : 0];
    assign addr_line_offset_align_to_word = {save_option.req_addr[DCACHE_OFFSET_WIDTH-1 : 2], 2'b00};
    assign addr_line_offset_align_to_hword = {save_option.req_addr[DCACHE_OFFSET_WIDTH-1 : 1], 1'b0};

    /************************ SAVE OPTION *****************************/

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            save_option <= '0;
        end else if (dcache_if.req_valid) begin
            save_option.write_en <= dcache_if.write_en;
            save_option.req_addr <= dcache_if.req_addr;
            save_option.write_data <= dcache_if.write_data;
            save_option.size <= dcache_if.size;
            save_option.sign <= dcache_if.sign;
        end
    end
    /************************ STATE MACHINE *****************************/

    // state_t
    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        REFILL_AXI_AR,
        REFILL_AXI_R,
        WRITE_BACK_AXI_AW,
        WRITE_BACK_AXI_W,
        WRITE_BACK_AXI_B
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
                if (dcache_if.req_valid) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                if (some_way_hit) begin
                    next_state = IDLE;
                end else if (cache_mem[replace_way][addr_index].valid && 
                           cache_mem[replace_way][addr_index].dirty) begin
                    next_state = WRITE_BACK_AXI_AW;
                end else begin
                    next_state = REFILL_AXI_AR;
                end
            end
            WRITE_BACK_AXI_AW: begin
                if (axi_write_if.awready) begin
                    next_state = WRITE_BACK_AXI_W;
                end
            end
            WRITE_BACK_AXI_W: begin
                if (axi_write_if.wready && axi_write_if.wlast) begin
                    next_state = WRITE_BACK_AXI_B;
                end
            end
            WRITE_BACK_AXI_B: begin
                if (axi_write_if.bvalid) begin
                    next_state = REFILL_AXI_AR;
                end
            end
            REFILL_AXI_AR: begin
                if (axi_read_if.arready) begin
                    next_state = REFILL_AXI_R;
                end
            end
            REFILL_AXI_R: begin
                if (axi_read_if.rlast) begin
                    next_state = save_option.write_en ? LOOKUP : IDLE;
                end
            end
        endcase
    end

    /************************ HIT CHECK *****************************/

    assign some_way_hit = |way_hit_flag;

    // way_hit_flag
    always_comb begin
        way_hit_flag[0] = cache_mem[0][addr_index].valid && 
                    (cache_mem[0][addr_index].tag == addr_tag);
        way_hit_flag[1] = cache_mem[1][addr_index].valid && 
                    (cache_mem[1][addr_index].tag == addr_tag);
    end

    // hit_way_index
    always_comb begin
        hit_way_index = 0;
        if (way_hit_flag[0]) begin
            hit_way_index = 0;
        end else if (way_hit_flag[1]) begin
            hit_way_index = 1;
        end
    end

    assign replace_way = lru[addr_index];

    /************************ READ HANDLE *****************************/

    logic [DATA_WIDTH-1:0] read_buf;

    // read_buf
    always_comb begin
        read_buf <= '0;
        if (now_state == LOOKUP && some_way_hit) begin
            case (save_option.size)
                MEM_SIZE_W: begin
                    read_buf <= {
                        cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd3],
                        cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd2],
                        cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd1],
                        cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd0]
                    };
                end
                MEM_SIZE_H: begin
                    if (save_option.sign) begin
                        read_buf <= {
                            {16{cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 'd1][7]}},
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 'd1],
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 'd0]
                        };
                    end else begin
                        read_buf <= {
                            16'h0000,
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 'd1],
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 'd0]
                        };
                    end
                end
                MEM_SIZE_B: begin
                    if (save_option.sign) begin
                        read_buf <= {
                            {24{cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd0][7]}},
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd0]
                        };
                    end else begin
                        read_buf <= {
                            24'h000000,
                            cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 'd0]
                        };
                    end
                end
            endcase
        end
    end

    /************************ DCACHE IF *****************************/
    assign dcache_if.resp_ready = now_state == IDLE;

    // dcache_if.resp_valid
    always_comb begin
        dcache_if.resp_valid = 1'b0;
        if (!save_option.write_en && now_state == LOOKUP && some_way_hit) begin
            dcache_if.resp_valid = 1'b1;
        end else if (!save_option.write_en && axi_read_if.rvalid && axi_read_if.rready && rx_counter == addr_line_offset) begin
            dcache_if.resp_valid = 1'b1;
        end
    end

    // dcache_if.resp_data
    assign dcache_if.resp_data = read_buf;

    /************************ AXI READ IF *****************************/

    // axi_read_if.arvalid
    assign axi_read_if.arvalid = (now_state == REFILL_AXI_AR);

    // axi_read_if.araddr
    // Must read hole line at once, align to 2**DCACHE_OFFSET_WIDTH bytes
    assign axi_read_if.araddr = (now_state == REFILL_AXI_AR) ? {save_option.req_addr[ADDR_WIDTH-1:DCACHE_OFFSET_WIDTH], {(DCACHE_OFFSET_WIDTH){1'b0}}} : '0;

    // axi_read_if.arlen
    // Read once is 32bit/4B, so must read 2**DCACHE_OFFSET_WIDTH / 4 times
    assign axi_read_if.arlen = 2**DCACHE_OFFSET_WIDTH / 4 - 1;

    // axi_read_if.arsize
    assign axi_read_if.arsize = AXI_SIZE_4B;

    // axi_read_if.arburst
    assign axi_read_if.arburst = AXI_BURST_INCR;

    // axi_read_if.rready
    always_comb begin
        axi_read_if.rready = (now_state == REFILL_AXI_R);
    end

    // rx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_counter <= 4'd0;
        end else if (axi_read_if.rvalid && axi_read_if.rready) begin
            rx_counter <= rx_counter + 1;
        end else begin
            rx_counter <= 4'd0;
        end
    end

    /************************ AXI WRITE IF *****************************/
    
    // axi_write_if.awvalid
    assign axi_write_if.awvalid = (now_state == WRITE_BACK_AXI_AW);
    
    // axi_write_if.awaddr
    // 写回整个缓存行，对齐到2**DCACHE_OFFSET_WIDTH字节
    assign axi_write_if.awaddr = (now_state == WRITE_BACK_AXI_AW) ? 
        {cache_mem[replace_way][addr_index].tag, 
         addr_index, 
         {(DCACHE_OFFSET_WIDTH){1'b0}}} : '0;
    
    // axi_write_if.awlen
    // 一次写32位/4字节，所以需要写2**DCACHE_OFFSET_WIDTH / 4次
    assign axi_write_if.awlen = 2**DCACHE_OFFSET_WIDTH / 4 - 1;
    
    // axi_write_if.awsize
    assign axi_write_if.awsize = AXI_SIZE_4B;
    
    // axi_write_if.awburst
    assign axi_write_if.awburst = AXI_BURST_INCR;
    
    // axi_write_if.wvalid
    assign axi_write_if.wvalid = (now_state == WRITE_BACK_AXI_W);

    // tx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_counter <= 4'd0;
        end else if (axi_write_if.wvalid && axi_write_if.wready) begin
            tx_counter <= tx_counter + 1;
        end else begin
            tx_counter <= 4'd0;
        end
    end
    
    // axi_write_if.wdata
    assign axi_write_if.wdata = (now_state == WRITE_BACK_AXI_W) ? {
        cache_mem[replace_way][addr_index].bytes[tx_counter * 4 + 3],
        cache_mem[replace_way][addr_index].bytes[tx_counter * 4 + 2],
        cache_mem[replace_way][addr_index].bytes[tx_counter * 4 + 1],
        cache_mem[replace_way][addr_index].bytes[tx_counter * 4 + 0]
    } : '0;
    
    // axi_write_if.wlast
    assign axi_write_if.wlast = (now_state == WRITE_BACK_AXI_W) && (tx_counter == axi_write_if.awlen);
    
    // axi_write_if.wstrb
    assign axi_write_if.wstrb = 4'b1111;
    
    // axi_write_if.bready
    assign axi_write_if.bready = (now_state == WRITE_BACK_AXI_B);
    

    /************************ CACHE MEM *****************************/

    // cache_mem.dirty
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DCACHE_WAY_NUM; i++) begin
                for (int j = 0; j < DCACHE_SET_NUM; j++) begin
                    cache_mem[i][j].dirty <= 1'b0;
                end
            end
        end else if (axi_read_if.rlast) begin
            cache_mem[replace_way][addr_index].dirty <= 1'b0;

        end else if (save_option.write_en && some_way_hit) begin
            cache_mem[hit_way_index][addr_index].dirty <= 1'b1;
        end
    end

    // cache_mem.bytes
    always_ff @(posedge clk or negedge rst_n) begin
        if (axi_read_if.rvalid && axi_read_if.rready) begin
            cache_mem[replace_way][addr_index].bytes[rx_counter * 4 + 0] <= axi_read_if.rdata[7:0];
            cache_mem[replace_way][addr_index].bytes[rx_counter * 4 + 1] <= axi_read_if.rdata[15:8];
            cache_mem[replace_way][addr_index].bytes[rx_counter * 4 + 2] <= axi_read_if.rdata[23:16];
            cache_mem[replace_way][addr_index].bytes[rx_counter * 4 + 3] <= axi_read_if.rdata[31:24];
        end else if (save_option.write_en && some_way_hit) begin
            case (save_option.size)
                MEM_SIZE_B: begin
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset] <= save_option.write_data[7:0];
                end
                MEM_SIZE_H: begin
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 0] <= save_option.write_data[7:0];
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_hword + 1] <= save_option.write_data[15:8];
                end
                MEM_SIZE_W: begin
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 0] <= save_option.write_data[7:0];
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 1] <= save_option.write_data[15:8];
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 2] <= save_option.write_data[23:16];
                    cache_mem[hit_way_index][addr_index].bytes[addr_line_offset_align_to_word + 3] <= save_option.write_data[31:24];
                end
            endcase
        end
    end

    // cache_mem.valid
    // cache_mem.tag
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DCACHE_WAY_NUM; i++) begin
                for (int j = 0; j < DCACHE_SET_NUM; j++) begin
                    cache_mem[i][j].valid <= 1'b0;
                    cache_mem[i][j].tag <= '0;
                end
            end
        end else if (axi_read_if.rlast) begin
            cache_mem[replace_way][addr_index].valid <= 1'b1;
            cache_mem[replace_way][addr_index].tag <= addr_tag;
        end
    end

    // lru
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DCACHE_SET_NUM; i++) begin
                lru[i] <= 1'b0;
            end
        end else if (axi_read_if.rlast) begin
            lru[addr_index] <= ~replace_way;
        end
    end
endmodule
