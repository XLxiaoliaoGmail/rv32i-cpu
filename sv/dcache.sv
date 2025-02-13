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
    input  logic   clk,
    input  logic   rst_n,
    dcache_if.self dcache_if
);
    import _riscv_defines::*;

    parameter _SIMULATED_DELAY = 4;

    logic [7:0] mem [4096];
    logic [4:0] _counter;
    
    logic [7:0]  byte_data;
    logic [15:0] half_data;
    logic [31:0] word_data;

    assign byte_data = mem[dcache_if.addr];
    assign half_data = {mem[dcache_if.addr+1], mem[dcache_if.addr]};
    assign word_data = {mem[dcache_if.addr+3], mem[dcache_if.addr+2], mem[dcache_if.addr+1], mem[dcache_if.addr]};

    // _counter
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            _counter <= _SIMULATED_DELAY;
        end else if (dcache_if.req_valid) begin
            _counter <= _counter - 1;
        end else begin
            _counter <= _SIMULATED_DELAY;
        end
    end

    // mem
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 4096; i++) begin
                mem[i] <= '0;
            end
        end else if (dcache_if.req_valid && dcache_if.write_en) begin
            case (dcache_if.size)
                MEM_SIZE_B: begin
                    mem[dcache_if.addr] <= dcache_if.write_data[7:0];
                end
                MEM_SIZE_H: begin 
                    mem[dcache_if.addr]   <= dcache_if.write_data[7:0];
                    mem[dcache_if.addr+1] <= dcache_if.write_data[15:8];
                end
                MEM_SIZE_W: begin
                    mem[dcache_if.addr]   <= dcache_if.write_data[7:0];
                    mem[dcache_if.addr+1] <= dcache_if.write_data[15:8];
                    mem[dcache_if.addr+2] <= dcache_if.write_data[23:16];
                    mem[dcache_if.addr+3] <= dcache_if.write_data[31:24];
                end
            endcase
        end
    end

    // resp_valid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dcache_if.resp_valid <= 1'b0;
        end else if (_counter == 0) begin
            dcache_if.resp_valid <= 1'b1;
        end else begin
            dcache_if.resp_valid <= 1'b0;
        end
    end
    
    // read_data
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            dcache_if.read_data <= '0;
        end else if (_counter == 0) begin
            case (dcache_if.size)
                MEM_SIZE_B: dcache_if.read_data <= dcache_if.sign ? {{24{byte_data[7]}}, byte_data} : {24'b0, byte_data};
                MEM_SIZE_H: dcache_if.read_data <= dcache_if.sign ? {{16{half_data[15]}}, half_data} : {16'b0, half_data};   
                MEM_SIZE_W: dcache_if.read_data <= word_data;
            endcase
        end
    end

endmodule

