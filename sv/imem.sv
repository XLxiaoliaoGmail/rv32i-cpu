`include "_riscv_defines.sv"
`include "_axi_if.sv"

// imem顶层模块
module imem (
    input  logic        clk,
    input  logic        rst_n,

    axi_read_if.slave   axi_if
);
    import _riscv_defines::*;

    typedef enum logic [2:0] {
        IDLE,
        AR_CHANNEL,
        READ_MEM,
        R_CHANNEL
    } axi_state_t;

    parameter IMEM_SIZE = 1 << 16;

    logic [7:0] imem [IMEM_SIZE];
    
    logic [ADDR_WIDTH*8-1:0] buffer;
    
    axi_state_t now_state, next_state;
    
    logic [4:0] tx_counter;
    
    logic [ADDR_WIDTH-1:0] addr_reg;

    initial begin
        logic [31:0] _tmp_mem [IMEM_SIZE/4];
        // $readmemh("./sv/test/alu_test.bin", _tmp_mem);
        for (int i = 0; i < IMEM_SIZE/4; i++) begin
            _tmp_mem[i] = i;
        end
        for (int i = 0; i < IMEM_SIZE/4; i++) begin
            imem[i*4+0] = _tmp_mem[i][7:0];
            imem[i*4+1] = _tmp_mem[i][15:8]; 
            imem[i*4+2] = _tmp_mem[i][23:16];
            imem[i*4+3] = _tmp_mem[i][31:24];
        end
    end
    
    /************************ SIMULATE DELAY *****************************/

    logic [3:0] _buffer_counter;
    logic _buffer_counter_en;
    logic _reading_finish;

    assign _reading_finish = _buffer_counter_en && _buffer_counter == 0;

    // _buffer_counter_en
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _buffer_counter_en <= 1'b0;
        end else if (axi_if.arvalid && axi_if.arready) begin
            _buffer_counter_en <= 1'b1;
        end else if (_reading_finish) begin
            _buffer_counter_en <= 1'b0;
        end
    end

    // _buffer_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _buffer_counter <= '0;
        end else if (axi_if.arvalid && axi_if.arready) begin
            _buffer_counter <= 10;
        end else if (_buffer_counter != 0) begin
            _buffer_counter <= _buffer_counter - 1;
        end
    end

    /************************ STATE MACHINE *****************************/

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
                if (axi_if.arvalid) begin
                    next_state = AR_CHANNEL;
                end
            end
            AR_CHANNEL: begin
                next_state = READ_MEM;
            end
            READ_MEM: begin
                if (_reading_finish) begin
                    next_state = R_CHANNEL;
                end
            end
            R_CHANNEL: begin
                if (axi_if.rvalid && axi_if.rready && axi_if.rlast) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    /************************ AXI IF *****************************/

    // addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg <= '0;
        end else if (now_state == IDLE && axi_if.arvalid) begin
            addr_reg <= axi_if.araddr;
        end
    end

    // buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= '0;
        end else if (_reading_finish) begin
            // Simulate the delay of reading memory
            for (int i = 0; i < axi_if.arlen + 1; i++) begin
                for (int j = 0; j < 4; j++) begin
                    automatic int offset = i*4 + j;
                    buffer[offset*8 +: 8] <= imem[{addr_reg[ADDR_WIDTH-1:2], 2'b00} + offset];
                end
            end
        end
    end

    // rvalid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_if.rvalid <= 1'b0;
        end else if (_reading_finish) begin
            axi_if.rvalid <= 1'b1;
        end else if (axi_if.rlast) begin
            axi_if.rvalid <= 1'b0;
        end
    end

    // tx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_counter <= '0;
        end else if (axi_if.rlast) begin
            // attention the priority of code
            tx_counter <= 0;
        end else if (axi_if.rvalid && axi_if.rready && !axi_if.rlast) begin
            tx_counter <= tx_counter + 1;
        end
    end

    assign axi_if.arready = (now_state == IDLE);

    assign axi_if.rdata = buffer[tx_counter*32 +: 32];

    assign axi_if.rlast = axi_if.rvalid && axi_if.rready && tx_counter == axi_if.arlen;

    assign axi_if.rresp = AXI_RESP_OKAY;
endmodule