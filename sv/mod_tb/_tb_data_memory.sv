`include "../_riscv_defines.sv"

module _tb_data_memory;
    import _riscv_defines::*;

    // Test signals
    logic                      clk;
    logic                      rst_n;
    logic                      we;
    logic [ADDR_WIDTH-1:0]     addr;
    logic [DATA_WIDTH-1:0]     wdata;
    logic [DATA_WIDTH-1:0]     rdata;

    // Instantiate DUT
    data_memory dut (
        .clk(clk),
        .rst_n(rst_n),
        .we(we),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test vectors
    typedef struct {
        logic [ADDR_WIDTH-1:0] test_addr;
        logic [DATA_WIDTH-1:0] test_data;
        logic                  test_we;
        logic                  test_re;
        logic [DATA_WIDTH-1:0] expected_data;
    } test_vector_t;

    // Result verification task
    task automatic check_memory(
        input string test_name,
        input test_vector_t vec
    );
        @(negedge clk);
        addr = vec.test_addr;
        wdata = vec.test_data;
        we = vec.test_we;
        
        @(posedge clk);
        @(negedge clk);
        we = 1'b0;
        
        if (vec.test_re && rdata !== vec.expected_data) begin
            $display("Test Failed - %s:", test_name);
            $display("Address: %h", vec.test_addr);
            $display("Expected data: %h", vec.expected_data);
            $display("Actual data: %h", rdata);
        end else begin
            $display("Test Passed - %s", test_name);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting Data Memory test...");

        // Initialize signals
        rst_n = 0;
        we = 0;
        addr = 0;
        wdata = 0;

        // Wait a few clock cycles then release reset
        repeat(5) @(posedge clk);
        rst_n = 1;

        // Test case 1: Write and read to address 0
        begin
            test_vector_t test1;
            test1.test_addr = 32'h0;
            test1.test_data = 32'h12345678;
            test1.test_we = 1'b1;
            test1.test_re = 1'b0;
            test1.expected_data = 32'h12345678;
            check_memory("Test 1: Write to address 0", test1);

            test1.test_we = 1'b0;
            test1.test_re = 1'b1;
            check_memory("Test 1: Read from address 0", test1);
        end

        // Test case 2: Write and read to maximum address
        begin
            test_vector_t test2;
            test2.test_addr = 32'hFFC;  // Last word-aligned address
            test2.test_data = 32'hABCDEF01;
            test2.test_we = 1'b1;
            test2.test_re = 1'b0;
            test2.expected_data = 32'hABCDEF01;
            check_memory("Test 2: Write to max address", test2);

            test2.test_we = 1'b0;
            test2.test_re = 1'b1;
            check_memory("Test 2: Read from max address", test2);
        end

        // Test case 3: Write-Read-Write-Read sequence
        begin
            test_vector_t test3;
            test3.test_addr = 32'h100;
            test3.test_data = 32'h55555555;
            test3.test_we = 1'b1;
            test3.test_re = 1'b0;
            test3.expected_data = 32'h55555555;
            check_memory("Test 3: First write", test3);

            test3.test_we = 1'b0;
            test3.test_re = 1'b1;
            check_memory("Test 3: First read", test3);

            test3.test_data = 32'hAAAAAAAA;
            test3.test_we = 1'b1;
            test3.test_re = 1'b0;
            test3.expected_data = 32'hAAAAAAAA;
            check_memory("Test 3: Second write", test3);

            test3.test_we = 1'b0;
            test3.test_re = 1'b1;
            check_memory("Test 3: Second read", test3);
        end

        // Test case 4: Read without write (should return 0)
        begin
            test_vector_t test4;
            test4.test_addr = 32'h200;
            test4.test_data = 32'h0;
            test4.test_we = 1'b0;
            test4.test_re = 1'b1;
            test4.expected_data = 32'h0;
            check_memory("Test 4: Read unwritten address", test4);
        end

        // Test case 5: Write with no read enable
        begin
            test_vector_t test5;
            test5.test_addr = 32'h300;
            test5.test_data = 32'hFFFFFFFF;
            test5.test_we = 1'b1;
            test5.test_re = 1'b0;
            test5.expected_data = 32'hFFFFFFFF;
            check_memory("Test 5: Write only", test5);
        end

        $display("Data Memory test completed");
        $stop;
    end

    // Assertions
    // Address must be word-aligned
    property addr_aligned;
        @(posedge clk) (addr[1:0] == 2'b00);
    endproperty

    // Address must be within valid range
    property addr_range;
        @(posedge clk) (addr < 4096);
    endproperty

    assert property (addr_aligned)
        else $warning("Address is not word-aligned");
    assert property (addr_range)
        else $error("Address is out of range");

    // Coverage monitoring
    covergroup memory_coverage @(posedge clk);
        addr_cp: coverpoint addr {
            bins start_addr = {0};
            bins aligned_addr[] = {[4:1020]};
            bins end_addr = {1023};
            bins unaligned_addr = {[1:3], [5:7], [9:11], [13:15]};
        }

        data_cp: coverpoint wdata {
            bins zero = {0};
            bins others[4] = {[1:32'hFFFFFFFF]};
        }

        we_cp: coverpoint we {
            bins write = {1};
            bins no_write = {0};
        }

        access_cross: cross we_cp, addr_cp;
    endgroup

    memory_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_data_memory.vcd");
        $dumpvars(0, _tb_data_memory);
    end

endmodule
