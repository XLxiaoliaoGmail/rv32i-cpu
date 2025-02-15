`include "_riscv_defines.sv"
`include "_axi_if.sv"

module _tb_dcache;
    import _riscv_defines::*;

    // Clock and reset signals
    logic clk;
    logic rst_n;

    // Interface instantiation
    dcache_if dcache_if();
    axi_read_if axi_read_if();
    axi_write_if axi_write_if();

    // DUT instantiation
    dcache dcache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .dcache_if(dcache_if),
        .axi_read_if(axi_read_if),
        .axi_write_if(axi_write_if)
    );

    dmem dmem_inst (
        .clk(clk),
        .rst_n(rst_n),
        .axi_read_if(axi_read_if),
        .axi_write_if(axi_write_if)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset task
    task reset_system;
        rst_n = 0;
        dcache_if.req_valid = 0;
        dcache_if.write_en = 0;
        dcache_if.req_addr = '0;
        dcache_if.write_data = '0;
        dcache_if.size = MEM_SIZE_W;
        dcache_if.sign = 0;
        repeat(5) @(posedge clk);
        rst_n = 1;
    endtask

    // Memory read task
    task read_memory(
        input logic [31:0] addr,
        input mem_read_size_t size,
        input logic sign
    );
        dcache_if.write_en = 0;
        dcache_if.req_addr = addr;
        dcache_if.size = size;
        dcache_if.sign = sign;
        dcache_if.req_valid = 1;
        @(posedge clk);
        dcache_if.req_valid = 0;
        @(posedge clk);
        wait(dcache_if.resp_ready);
        repeat(10) @(posedge clk);
    endtask

    // Memory write task
    task write_memory(
        input logic [31:0] addr,
        input logic [31:0] data,
        input mem_read_size_t size
    );
        dcache_if.req_addr = addr;
        dcache_if.write_data = data;
        dcache_if.size = size;
        dcache_if.req_valid = 1;
        dcache_if.write_en = 1;
        @(posedge clk);
        dcache_if.req_valid = 0;
        dcache_if.write_en = 0;
        @(posedge clk);
        wait(dcache_if.resp_ready);
        repeat(10) @(posedge clk);
    endtask

    // Main test process
    initial begin
        // Initialize and reset
        reset_system();

        // Test case 1: Word write and read (cache miss)
        write_memory(32'h0000_1004, 32'h11223344, MEM_SIZE_W);
        read_memory(32'h0000_1004, MEM_SIZE_W, 1'b0);
        
        // Test case 2: Cache hit (same address)
        read_memory(32'h0000_1004, MEM_SIZE_W, 1'b0);

        // Test case 3: Half word access with sign extension
        write_memory(32'h0000_1002, 32'h55667788, MEM_SIZE_H);
        read_memory(32'h0000_1002, MEM_SIZE_H, 1'b1); // Should sign extend

        // Test case 4: Byte access with zero extension
        write_memory(32'h0000_1008, 32'h0000_00FF, MEM_SIZE_B);
        read_memory(32'h0000_1008, MEM_SIZE_B, 1'b0); // Should zero extend

        // Fill up
        write_memory(32'h0000_100a, 32'h11111111, MEM_SIZE_H);
        write_memory(32'h0000_100c, 32'h22222222, MEM_SIZE_W);
        write_memory(32'h0000_1010, 32'h33333333, MEM_SIZE_W);
        write_memory(32'h0000_1014, 32'h44444444, MEM_SIZE_W);
        write_memory(32'h0000_1018, 32'h55555555, MEM_SIZE_W);
        write_memory(32'h0000_101c, 32'h66666666, MEM_SIZE_W);

        // Test case 5: Unaligned access
        write_memory(32'h0000_1001, 32'h12345678, MEM_SIZE_W);
        read_memory(32'h0000_1001, MEM_SIZE_W, 1'b0);

        // Test case 6: Different cache ways
        write_memory(32'h0000_2000, 32'hAAAAAAAA, MEM_SIZE_W); // Different index
        read_memory(32'h0000_2000, MEM_SIZE_W, 1'b0);

        // Test case 7: LRU replacement
        write_memory(32'h0000_3000, 32'hBBBBBBBB, MEM_SIZE_W); // Will cause replacement
        read_memory(32'h0000_3000, MEM_SIZE_W, 1'b0);

        // Verify previous data still accessible
        read_memory(32'h0000_2000, MEM_SIZE_W, 1'b0);

        // Test complete
        repeat(10) @(posedge clk);
        $display("Test completed successfully!");
        $stop;
    end

    // Timeout protection
    initial begin
        #50000;
        $display("Timeout Error!");
        $stop;
    end

    // Monitor for read responses
    always @(posedge clk) begin
        if (dcache_if.resp_valid && !dcache_if.write_en) begin
            $display("Read Data: 0x%h", dcache_if.resp_data);
        end
    end

endmodule
