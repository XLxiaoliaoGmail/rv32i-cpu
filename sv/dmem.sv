`include "_riscv_defines.sv"
`include "_axi_if.sv"

module dmem (
    input  logic        clk,
    input  logic        rst_n,
    axi_read_if.slave   axi_read_if,
    axi_write_if.slave  axi_write_if
);
    import _riscv_defines::*;

    typedef enum logic [2:0] {
        IDLE,
        AR_CHANNEL,
        READ_MEM,
        R_CHANNEL,
        AW_CHANNEL,
        W_CHANNEL,
        WRITE_MEM,
        B_CHANNEL
    } axi_state_t;

    parameter DMEM_SIZE = 1 << 16;

    logic [7:0] dmem [DMEM_SIZE-1:0];
    
    logic [DATA_WIDTH*8-1:0] buffer;
    
    axi_state_t now_state, next_state;
    
    logic [4:0] tx_counter;
    logic [4:0] rx_counter;
    
    logic [ADDR_WIDTH-1:0] read_addr_reg;
    logic [ADDR_WIDTH-1:0] write_addr_reg;
    
    /************************ SIMULATED DELAY *****************************/
    logic [3:0] _delay_counter;
    logic _delay_counter_en;
    logic _mem_op_finish;

    assign _mem_op_finish = _delay_counter_en && _delay_counter == 0;

    // _delay_counter_en
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _delay_counter_en <= 1'b0;
        end else if ((axi_read_if.arvalid && axi_read_if.arready) || 
                    (axi_write_if.wvalid && axi_write_if.wready)) begin
            _delay_counter_en <= 1'b1;
        end else if (_mem_op_finish) begin
            _delay_counter_en <= 1'b0;
        end
    end

    // _delay_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _delay_counter <= '0;
        end else if ((axi_read_if.arvalid && axi_read_if.arready) || 
                    (axi_write_if.wvalid && axi_write_if.wready)) begin
            _delay_counter <= 10;
        end else if (_delay_counter != 0) begin
            _delay_counter <= _delay_counter - 1;
        end
    end

    // buffer
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer <= '0;
        end else if (_mem_op_finish && now_state == READ_MEM) begin
            for (int i = 0; i < 32; i++) begin
                buffer[i*8 +: 8] <= dmem[{read_addr_reg[ADDR_WIDTH-1:2], 2'b00} + i];
            end
        end else if (axi_write_if.wvalid && axi_write_if.wready) begin
            // Assume wstrb is 4'b1111
            buffer[rx_counter*32 +: 32] <= axi_write_if.wdata;
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
                if (axi_read_if.arvalid) begin
                    next_state = AR_CHANNEL;
                end else if (axi_write_if.awvalid) begin
                    next_state = AW_CHANNEL;
                end
            end
            AR_CHANNEL: begin
                next_state = READ_MEM;
            end
            READ_MEM: begin
                if (_mem_op_finish) begin
                    next_state = R_CHANNEL;
                end
            end
            R_CHANNEL: begin
                if (axi_read_if.rvalid && axi_read_if.rready && axi_read_if.rlast) begin
                    next_state = IDLE;
                end
            end
            AW_CHANNEL: begin
                next_state = W_CHANNEL;
            end
            W_CHANNEL: begin
                if (axi_write_if.wvalid && axi_write_if.wready && axi_write_if.wlast) begin
                    next_state = WRITE_MEM;
                end
            end
            WRITE_MEM: begin
                if (_mem_op_finish) begin
                    next_state = B_CHANNEL;
                end
            end
            B_CHANNEL: begin
                if (axi_write_if.bready) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    /************************ AXI READ IF *****************************/
    // read_addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr_reg <= '0;
        end else if (now_state == IDLE && axi_read_if.arvalid) begin
            read_addr_reg <= axi_read_if.araddr;
        end
    end

    // tx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_counter <= '0;
        end else if (axi_read_if.rlast) begin
            tx_counter <= 0;
        end else if (axi_read_if.rvalid && axi_read_if.rready) begin
            tx_counter <= tx_counter + 1;
        end
    end

    assign axi_read_if.arready = (now_state == IDLE);
    
    // rvalid
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_read_if.rvalid <= 1'b0;
        end else if (_mem_op_finish && now_state == READ_MEM) begin
            axi_read_if.rvalid <= 1'b1;
        end else if (axi_read_if.rlast) begin
            axi_read_if.rvalid <= 1'b0;
        end
    end

    assign axi_read_if.rdata = buffer[tx_counter*32 +: 32];
    assign axi_read_if.rlast = axi_read_if.rvalid && axi_read_if.rready && tx_counter == axi_read_if.arlen;
    assign axi_read_if.rresp = AXI_RESP_OKAY;

    /************************ AXI 写接口 *****************************/
    // write_addr_reg
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr_reg <= '0;
        end else if (now_state == IDLE && axi_write_if.awvalid) begin
            write_addr_reg <= axi_write_if.awaddr;
        end
    end

    // rx_counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_counter <= '0;
        end else if (axi_write_if.wlast) begin
            rx_counter <= 0;
        end else if (axi_write_if.wvalid && axi_write_if.wready) begin
            rx_counter <= rx_counter + 1;
        end
    end

    // dmem
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < DMEM_SIZE; i++) begin
                dmem[i] <= 8'h0;
            end
        end else if (_mem_op_finish && now_state == WRITE_MEM) begin
            for (int i = 0; i < axi_write_if.awlen + 1; i++) begin
                for (int j = 0; j < 4; j++) begin
                    automatic int offset = i*4 + j;
                    dmem[{write_addr_reg[ADDR_WIDTH-1:2], 2'b00} + offset] <= buffer[offset*8 +: 8];
                end
            end
        end
    end

    assign axi_write_if.awready = (now_state == IDLE);
    assign axi_write_if.wready = (now_state == W_CHANNEL);
    assign axi_write_if.bvalid = (now_state == B_CHANNEL);
    assign axi_write_if.bresp = AXI_RESP_OKAY;

endmodule