`include "_riscv_defines.sv"

module _tb_instruction_memory;
    import _riscv_defines::*;

    // Test signals
    logic                clk;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] instruction;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate DUT
    instruction_memory dut (
        .clk(clk),
        .addr(addr),
        .instruction(instruction)
    );

    // Test program memory initialization
    initial begin
        // Create a temporary program.hex file for testing
        int fd;
        fd = $fopen("program.hex", "w");
        // Write some test instructions
        // NOP (ADDI x0, x0, 0)
        $fdisplay(fd, "13"); 
        $fdisplay(fd, "00");
        $fdisplay(fd, "00");
        $fdisplay(fd, "00");
        
        // ADDI x1, x0, 1
        $fdisplay(fd, "93");
        $fdisplay(fd, "00");
        $fdisplay(fd, "10");
        $fdisplay(fd, "00");
        
        // ADDI x2, x0, 2
        $fdisplay(fd, "13");
        $fdisplay(fd, "01");
        $fdisplay(fd, "20");
        $fdisplay(fd, "00");
        
        // ADD x3, x1, x2
        $fdisplay(fd, "b3");
        $fdisplay(fd, "81");
        $fdisplay(fd, "20");
        $fdisplay(fd, "00");
        
        $fclose(fd);
    end

    // Result verification task
    task check_instruction(
        input [ADDR_WIDTH-1:0] test_addr,
        input [DATA_WIDTH-1:0] exp_instruction,
        input string test_name
    );
        addr = test_addr;
        @(negedge clk);
        #1;
        
        if (instruction !== exp_instruction) begin
            $display("Test Failed - %s:", test_name);
            $display("Address: %h", test_addr);
            $display("Expected instruction: %h", exp_instruction);
            $display("Actual instruction: %h", instruction);
        end else begin
            $display("Test Passed - %s", test_name);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting Instruction Memory test...");

        // Initialize signals
        addr = '0;


        // Test 1: Read first instruction (NOP)
        check_instruction(
            32'h0,        // address
            32'h00000013, // NOP instruction
            "Read NOP instruction"
        );

        // Test 2: Read second instruction (ADDI x1, x0, 1)
        check_instruction(
            32'h4,        // address
            32'h00100093, // ADDI instruction
            "Read ADDI instruction"
        );

        // Test 3: Read third instruction (ADDI x2, x0, 2)
        check_instruction(
            32'h8,        // address
            32'h00200113, // ADDI instruction
            "Read second ADDI instruction"
        );

        // Test 4: Read fourth instruction (ADD x3, x1, x2)
        check_instruction(
            32'hC,        // address
            32'h002081b3, // ADD instruction
            "Read ADD instruction"
        );

        $display("Instruction Memory test completed");
        $stop;
    end

    // Coverage monitoring
    covergroup instruction_memory_coverage @(posedge clk);
        addr_cp: coverpoint addr {
            bins start_addr = {0};
            bins aligned_addr[] = {[4:1020]};
            bins end_addr = {1023};
            bins unaligned_addr = {[1:3], [5:7], [9:11], [13:15]};
        }

        instruction_cp: coverpoint instruction {
            bins valid_instructions[] = {
                32'h00000013, // NOP
                32'h00100093, // ADDI x1, x0, 1
                32'h00200113, // ADDI x2, x0, 2
                32'h002081b3  // ADD x3, x1, x2
            };
            bins others = default;
        }
    endgroup

    instruction_memory_coverage cg = new();

    // Assertions
    // Address must be word-aligned for proper operation
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
        else $display("Address is out of range");

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_instruction_memory.vcd");
        $dumpvars(0, _tb_instruction_memory);
    end

endmodule
