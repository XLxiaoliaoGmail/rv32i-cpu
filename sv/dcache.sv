`include "_riscv_defines.sv"

interface dcache_if;
    import _riscv_defines::*;

    logic                    req_valid;
    logic                    write_en;
    logic [ADDR_WIDTH-1:0]   addr;
    logic [DATA_WIDTH-1:0]   write_data;
    mem_read_size_t          size;
    logic                    sign;
    logic [DATA_WIDTH-1:0]   read_data;
    logic                    resp_valid;

    modport self (
        input  req_valid,
        input  write_en,
        input  addr,
        input  write_data,
        input  size,
        input  sign,
        output read_data,
        output resp_valid
    );

    modport master (
        output req_valid,
        output write_en,
        output addr,
        output write_data,
        output size,
        output sign,
        input  read_data,
        input  resp_valid
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
    axi_read_master_if #(
        ._RESP_DATA_WIDTH(DCACHE_LINE_SIZE*8)
    ) axi_read_master_if();
    
    dcache_core dcache_core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dcache_if(dcache_if),
        .axi_read_master_if(axi_read_master_if.master)
    );
    
    axi_read_master #(
        ._RESP_DATA_WIDTH(DCACHE_LINE_SIZE*8),
        ._AR_LEN(8'h7),
        ._AR_SIZE(AXI_SIZE_4B),
        ._AR_BURST(AXI_BURST_INCR)
    ) axi_read_master_inst (
        .clk(clk),
        .rst_n(rst_n),
        .axi_if(axi_read_if),
        .axi_read_master_if(axi_read_master_if.self)
    );

    // axi_write_master axi_write_master_inst (
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .axi_if(axi_write_if),
    //     .axi_read_master_if(axi_read_master_if.self)
    // );
endmodule

module dcache_core (
    input  logic clk,
    input  logic rst_n,
    dcache_if.self dcache_if,
    axi_read_master_if.master axi_read_master_if
);
    import _riscv_defines::*;

    typedef struct packed {
        logic valid;                
        logic dirty;                 
        logic [DCACHE_TAG_WIDTH-1:0] tag; 
        logic [DCACHE_LINE_SIZE*8-1:0] data;
    } cache_line_t;

    cache_line_t [DCACHE_WAY_NUM-1:0][DCACHE_SET_NUM-1:0] cache_mem;
    
    logic [DCACHE_SET_NUM-1:0] lru;

    logic [DCACHE_TAG_WIDTH-1:0]     addr_tag;
    logic [DCACHE_INDEX_WIDTH-1:0]   addr_index;
    logic [DCACHE_LINE_OFFSET-1:0]   addr_offset;

    assign addr_tag    = dcache_if.addr[DATA_WIDTH-1 : DATA_WIDTH-DCACHE_TAG_WIDTH];
    assign addr_index  = dcache_if.addr[DATA_WIDTH-DCACHE_TAG_WIDTH-1 : DCACHE_LINE_OFFSET];
    
    // addr_offset
    always_comb begin
        addr_offset = '0;
        case (dcache_if.size)
            MEM_SIZE_B: begin  // 字节访问
                addr_offset = dcache_if.addr[DCACHE_LINE_OFFSET-1:0];
            end
            MEM_SIZE_H: begin  // 半字访问
                addr_offset = {dcache_if.addr[DCACHE_LINE_OFFSET-1:1], 1'b0};
            end
            MEM_SIZE_W: begin  // 字访问
                addr_offset = {dcache_if.addr[DCACHE_LINE_OFFSET-1:2], 2'b00};
            end
        endcase
    end

    typedef enum logic [2:0] {
        IDLE,           
        LOOKUP,         
        WRITE_BACK,     
        REFILL,         
        WRITE_CACHE     
    } state_t;
    
    state_t now_state, next_state;

    logic [DCACHE_WAY_NUM-1:0] hit;
    logic hit_valid;

    assign hit_valid = |hit;
    
    // hit
    always_comb begin
        for(int i = 0; i < DCACHE_WAY_NUM; i++) begin
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
                if (dcache_if.req_valid) begin
                    next_state = LOOKUP;
                end
            end
            LOOKUP: begin
                if (!dcache_if.write_en) begin
                    if (hit_valid) begin
                        next_state = IDLE;
                    end else begin
                        next_state = REFILL;
                    end
                end else begin  
                    next_state = LOOKUP;
                end
            end
            REFILL: begin
                if (axi_read_master_if.read_resp_valid) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // dcache_if.resp_valid
    always_comb begin
        dcache_if.resp_valid = 1'b0;
        if (!dcache_if.write_en) begin
            if (now_state == LOOKUP && hit_valid) begin
                dcache_if.resp_valid = 1'b1;
            end else if (now_state == REFILL && axi_read_master_if.read_resp_valid) begin
                dcache_if.resp_valid = 1'b1;
            end
        end
    end

    /************************ READ *****************************/

    // axi_read_master_if.read_req_valid
    always_comb begin
        axi_read_master_if.read_req_valid = 1'b0;
        if (now_state == LOOKUP && !hit_valid && !dcache_if.write_en) begin
            axi_read_master_if.read_req_valid = 1'b1;
        end
    end

    // axi_read_master_if.read_addr
    always_comb begin
        axi_read_master_if.read_addr = '0;
        if (now_state == LOOKUP && !hit_valid && !dcache_if.write_en) begin
            axi_read_master_if.read_addr = {dcache_if.addr[DATA_WIDTH-1:DCACHE_LINE_OFFSET], {DCACHE_LINE_OFFSET{1'b0}}};
        end
    end

    // replace_way
    logic replace_way;
    assign replace_way = lru[addr_index];

    // cache_mem
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DCACHE_WAY_NUM; i++) begin
                for (int j = 0; j < DCACHE_SET_NUM; j++) begin
                    cache_mem[i][j].valid <= 1'b0;
                    cache_mem[i][j].dirty <= 1'b0;
                end
            end
        end else if (now_state == REFILL && axi_read_master_if.read_resp_valid) begin
            cache_mem[replace_way][addr_index].valid <= 1'b1;
            cache_mem[replace_way][addr_index].dirty <= 1'b0;
            cache_mem[replace_way][addr_index].tag <= addr_tag;
            cache_mem[replace_way][addr_index].data <= axi_read_master_if.read_data;
        end
    end

    // lru
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DCACHE_SET_NUM; i++) begin
                lru[i] <= 1'b0;
            end
        end else if ((now_state == LOOKUP && hit_valid) || 
                    (now_state == REFILL && axi_read_master_if.read_resp_valid)) begin
            lru[addr_index] <= hit_valid ? ~hit[1] : ~replace_way;
        end
    end

    // dcache_if.read_data
    always_comb begin
        dcache_if.read_data = '0;
        if (now_state == LOOKUP && hit_valid) begin
            logic [DCACHE_LINE_SIZE*8-1:0] line_data;
            line_data = cache_mem[hit[1] ? 1'b1 : 1'b0][addr_index].data;
            case (dcache_if.size)
                MEM_SIZE_B: begin
                    logic [7:0] byte_data;
                    byte_data = line_data[addr_offset * 8 +: 8];
                    dcache_if.read_data = dcache_if.sign ? {{24{byte_data[7]}}, byte_data} : {24'b0, byte_data};
                end
                MEM_SIZE_H: begin
                    logic [15:0] half_data;
                    half_data = line_data[addr_offset * 8 +: 16];
                    dcache_if.read_data = dcache_if.sign ? {{16{half_data[15]}}, half_data} : {16'b0, half_data};
                end
                MEM_SIZE_W: begin
                    dcache_if.read_data = line_data[addr_offset * 8 +: 32];
                end
            endcase
        end else if (now_state == REFILL && axi_read_master_if.read_resp_valid) begin
            case (dcache_if.size)
                MEM_SIZE_B: begin
                    logic [7:0] byte_data;
                    byte_data = axi_read_master_if.read_data[addr_offset * 8 +: 8];
                    dcache_if.read_data = dcache_if.sign ? {{24{byte_data[7]}}, byte_data} : {24'b0, byte_data};
                end
                MEM_SIZE_H: begin
                    logic [15:0] half_data;
                    half_data = axi_read_master_if.read_data[addr_offset * 8 +: 16];
                    dcache_if.read_data = dcache_if.sign ? {{16{half_data[15]}}, half_data} : {16'b0, half_data};
                end
                MEM_SIZE_W: begin
                    dcache_if.read_data = axi_read_master_if.read_data[addr_offset * 8 +: 32];
                end
            endcase
        end
    end
    
endmodule

