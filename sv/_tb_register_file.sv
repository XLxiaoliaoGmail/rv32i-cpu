`include "_riscv_defines.sv"

module _tb_register_file;
    import _riscv_defines::*;

    // Clock and reset signals
    logic                      clk;
    logic                      rst_n;
    logic                      we;
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;
    logic [REG_ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0]     rd_data;
    logic [DATA_WIDTH-1:0]     rs1_data;
    logic [DATA_WIDTH-1:0]     rs2_data;

    // Instantiate register file
    register_file dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (we),
        .rs1_addr (rs1_addr),
        .rs2_addr (rs2_addr),
        .rd_addr  (rd_addr),
        .rd_data  (rd_data),
        .rs1_data (rs1_data),
        .rs2_data (rs2_data)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test vectors
    typedef struct {
        logic [REG_ADDR_WIDTH-1:0] write_addr;
        logic [DATA_WIDTH-1:0]     write_data;
        logic [REG_ADDR_WIDTH-1:0] read_addr1;
        logic [REG_ADDR_WIDTH-1:0] read_addr2;
        logic [DATA_WIDTH-1:0]     expected_data1;
        logic [DATA_WIDTH-1:0]     expected_data2;
    } test_vector_t;

    // Test task
    task automatic run_test(input string test_name, input test_vector_t vec);
        @(negedge clk);
        we       = 1'b1;
        rd_addr  = vec.write_addr;
        rd_data  = vec.write_data;
        rs1_addr = vec.read_addr1;
        rs2_addr = vec.read_addr2;
        
        @(posedge clk);
        @(negedge clk);
        we = 1'b0;
        
        if (rs1_data !== vec.expected_data1) begin
            $display("Error: %s - rs1_data mismatch. Expected: %h, Actual: %h", 
                    test_name, vec.expected_data1, rs1_data);
            $stop;
        end
        
        if (rs2_data !== vec.expected_data2) begin
            $display("Error: %s - rs2_data mismatch. Expected: %h, Actual: %h", 
                    test_name, vec.expected_data2, rs2_data);
            $stop;
        end
        
        $display("Pass: %s", test_name);
    endtask

    // Test cases
    initial begin
        // Initialize signals
        rst_n = 0;
        we = 0;
        rs1_addr = 0;
        rs2_addr = 0;
        rd_addr = 0;
        rd_data = 0;

        // Wait a few clock cycles then release reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        
        // Test case 1: Write and read x1 register
        begin
            test_vector_t test1;
            test1.write_addr = 5'd1;
            test1.write_data = 32'h12345678;
            test1.read_addr1 = 5'd1;
            test1.read_addr2 = 5'd0;
            test1.expected_data1 = 32'h12345678;
            test1.expected_data2 = 32'h0;
            run_test("Test 1: Basic write/read operation", test1);
        end

        // Test case 2: Verify x0 register is always 0
        begin
            test_vector_t test2;
            test2.write_addr = 5'd0;
            test2.write_data = 32'hFFFFFFFF;
            test2.read_addr1 = 5'd0;
            test2.read_addr2 = 5'd0;
            test2.expected_data1 = 32'h0;
            test2.expected_data2 = 32'h0;
            run_test("Test 2: x0 register write protection", test2);
        end

        // Test case 3: Write-read forwarding
        begin
            test_vector_t test3;
            test3.write_addr = 5'd2;
            test3.write_data = 32'hABCDEF01;
            test3.read_addr1 = 5'd2;
            test3.read_addr2 = 5'd2;
            test3.expected_data1 = 32'hABCDEF01;
            test3.expected_data2 = 32'hABCDEF01;
            run_test("Test 3: Write-read forwarding", test3);
        end

        // Test case 4: Multiple register concurrent read
        begin
            test_vector_t test4;
            // First write to x3
            test4.write_addr = 5'd3;
            test4.write_data = 32'h55555555;
            test4.read_addr1 = 5'd1;  // Read previously written x1
            test4.read_addr2 = 5'd3;  // Read newly written x3
            test4.expected_data1 = 32'h12345678;
            test4.expected_data2 = 32'h55555555;
            run_test("Test 4: Multiple register concurrent read", test4);
        end

        // Test case 5: Boundary value test
        begin
            test_vector_t test5;
            test5.write_addr = 5'd31;
            test5.write_data = 32'hFFFFFFFF;
            test5.read_addr1 = 5'd31;
            test5.read_addr2 = 5'd31;
            test5.expected_data1 = 32'hFFFFFFFF;
            test5.expected_data2 = 32'hFFFFFFFF;
            run_test("Test 5: Maximum register address test", test5);
        end

        // All tests complete
        $display("All test cases completed!");
        $stop;
    end

    // Assertion checks
    property valid_addr_range;
        @(posedge clk) (rs1_addr < 32) && (rs2_addr < 32) && (rd_addr < 32);
    endproperty

    property x0_rs1_always_zero;
        @(posedge clk) (rs1_addr == 0 |-> rs1_data == 0);
    endproperty

    property x0_rs2_always_zero;
        @(posedge clk) (rs2_addr == 0 |-> rs2_data == 0);
    endproperty

    assert property (valid_addr_range) else $error("Address out of valid range");
    assert property (x0_rs1_always_zero) else $error("x0 register rs1_data is not zero");
    assert property (x0_rs2_always_zero) else $error("x0 register rs2_data is not zero");

    // Coverage monitoring
    covergroup reg_coverage @(posedge clk);
        rd_addr_cp: coverpoint rd_addr {
            bins zero = {0};
            bins others[6] = {[1:31]};
        }
        
        we_cp: coverpoint we {
            bins write = {1};
            bins no_write = {0};
        }
        
        rd_data_cp: coverpoint rd_data {
            bins zero = {0};
            bins others = {[1:$]};
        }
        
        write_cross: cross rd_addr_cp, we_cp;
    endgroup

    reg_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_register_file.vcd");
        $dumpvars(0, _tb_register_file);
    end


endmodule 