`include "_riscv_defines.sv"

module _tb_alu;
    import _riscv_defines::*;

    // Test signals
    logic [DATA_WIDTH-1:0] operand1;
    logic [DATA_WIDTH-1:0] operand2;
    alu_op_t               alu_op;
    logic [DATA_WIDTH-1:0] result;

    // Instantiate DUT
    alu dut (
        .operand1(operand1),
        .operand2(operand2),
        .alu_op(alu_op),
        .result(result)
    );

    // Result verification task
    task check_result(
        input [DATA_WIDTH-1:0] expected,
        input string op_name
    );
        if (result !== expected) begin
            $error("Test Failed - %s: Expected = %h, Actual = %h", op_name, expected, result);
        end else begin
            $display("Test Passed - %s: Result = %h", op_name, result);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting ALU test...");

        // 1. Test addition (ADD)
        operand1 = 32'h0000_0005;
        operand2 = 32'h0000_0003;
        alu_op = ALU_ADD;
        #1 check_result(32'h0000_0008, "ADD - Positive Addition");

        operand1 = 32'hFFFF_FFFF;
        operand2 = 32'h0000_0001;
        #1 check_result(32'h0000_0000, "ADD - Overflow Test");

        // 2. Test subtraction (SUB)
        operand1 = 32'h0000_000A;
        operand2 = 32'h0000_0003;
        alu_op = ALU_SUB;
        #1 check_result(32'h0000_0007, "SUB - Positive Subtraction");

        operand1 = 32'h0000_0003;
        operand2 = 32'h0000_0005;
        #1 check_result(32'hFFFF_FFFE, "SUB - Negative Result");

        // 3. Test logical AND
        operand1 = 32'hF0F0_F0F0;
        operand2 = 32'hFF00_FF00;
        alu_op = ALU_AND;
        #1 check_result(32'hF000_F000, "AND");

        // 4. Test logical OR
        operand1 = 32'hF0F0_F0F0;
        operand2 = 32'h0F0F_0F0F;
        alu_op = ALU_OR;
        #1 check_result(32'hFFFF_FFFF, "OR");

        // 5. Test XOR
        operand1 = 32'hFFFF_FFFF;
        operand2 = 32'hF0F0_F0F0;
        alu_op = ALU_XOR;
        #1 check_result(32'h0F0F_0F0F, "XOR");

        // 6. Test signed comparison (SLT)
        operand1 = 32'hFFFF_FFFF; // -1
        operand2 = 32'h0000_0001; // 1
        alu_op = ALU_SLT;
        #1 check_result(32'h0000_0001, "SLT - Negative Compare");

        operand1 = 32'h0000_0002;
        operand2 = 32'h0000_0001;
        #1 check_result(32'h0000_0000, "SLT - Positive Compare");

        // 7. Test unsigned comparison (SLTU)
        operand1 = 32'hFFFF_FFFF; // Max unsigned value
        operand2 = 32'h0000_0001;
        alu_op = ALU_SLTU;
        #1 check_result(32'h0000_0000, "SLTU");

        // 8. Test logical left shift (SLL)
        operand1 = 32'h0000_0001;
        operand2 = 32'h0000_0004; // Shift left by 4
        alu_op = ALU_SLL;
        #1 check_result(32'h0000_0010, "SLL");

        // 9. Test logical right shift (SRL)
        operand1 = 32'h8000_0000;
        operand2 = 32'h0000_0001; // Shift right by 1
        alu_op = ALU_SRL;
        #1 check_result(32'h4000_0000, "SRL");

        // 10. Test arithmetic right shift (SRA)
        operand1 = 32'h8000_0000; // Negative number
        operand2 = 32'h0000_0001; // Shift right by 1
        alu_op = ALU_SRA;
        #1 check_result(32'hC000_0000, "SRA - Negative");

        operand1 = 32'h4000_0000; // Positive number
        #1 check_result(32'h2000_0000, "SRA - Positive");

        // 11. Test default case
        alu_op = alu_op_t'('1);
        #1 check_result(32'h0000_0000, "Default Case");

        $display("ALU test completed");
        $stop;
    end

    // Coverage monitoring
    covergroup alu_coverage @(result);
        alu_op_cp: coverpoint alu_op {
            bins all_ops[] = {ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
                             ALU_SLT, ALU_SLTU, ALU_SLL, ALU_SRL, ALU_SRA};
        }
        
        operand1_cp: coverpoint operand1 {
            bins zero = {'0};
            bins max_pos = {32'h7FFF_FFFF};
            bins max_neg = {32'h8000_0000};
            bins others = {[1:32'h7FFF_FFFE], [32'h8000_0001:32'hFFFF_FFFF]};
        }
        
        operand2_cp: coverpoint operand2 {
            bins zero = {'0};
            bins max_pos = {32'h7FFF_FFFF};
            bins max_neg = {32'h8000_0000};
            bins others = {[1:32'h7FFF_FFFE], [32'h8000_0001:32'hFFFF_FFFF]};
        }
        
        op_cross: cross alu_op_cp, operand1_cp, operand2_cp;
    endgroup

    alu_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_alu.vcd");
        $dumpvars(0, _tb_alu);
    end

endmodule