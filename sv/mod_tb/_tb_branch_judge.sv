`include "../_riscv_defines.sv"

module _tb_branch_judge;
    import _riscv_defines::*;

    // Test signals
    logic [2:0]             funct3;
    logic [DATA_WIDTH-1:0]  rs1_data;
    logic [DATA_WIDTH-1:0]  rs2_data;
    logic                   branch;
    logic                   jump;
    logic                   take_branch;

    // Instantiate DUT
    branch_judge dut (
        .funct3(funct3),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .branch(branch),
        .jump(jump),
        .take_branch(take_branch)
    );

    // Result verification task
    task check_result(
        input logic expected,
        input string test_name
    );
        if (take_branch !== expected) begin
            $error("Test Failed - %s: Expected = %b, Actual = %b", test_name, expected, take_branch);
        end else begin
            $display("Test Passed - %s: Result = %b", test_name, take_branch);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting Branch Judge test...");

        branch = 1'b0;
        jump = 1'b0;
        
        // 1. Test BEQ (funct3 = 3'b000)
        funct3 = 3'b000;
        branch = 1'b1;
        rs1_data = 32'h0000_0005;
        rs2_data = 32'h0000_0005;
        #1 check_result(1'b1, "BEQ - Equal values");

        rs2_data = 32'h0000_0006;
        #1 check_result(1'b0, "BEQ - Unequal values");

        // 2. Test BNE (funct3 = 3'b001)
        funct3 = 3'b001;
        rs1_data = 32'h0000_0005;
        rs2_data = 32'h0000_0006;
        #1 check_result(1'b1, "BNE - Unequal values");

        rs2_data = 32'h0000_0005;
        #1 check_result(1'b0, "BNE - Equal values");

        // 3. Test BLT (funct3 = 3'b100)
        funct3 = 3'b100;
        rs1_data = 32'hFFFF_FFFF; // -1
        rs2_data = 32'h0000_0000; // 0
        #1 check_result(1'b1, "BLT - Negative < Positive");

        rs1_data = 32'h0000_0001;
        rs2_data = 32'h0000_0000;
        #1 check_result(1'b0, "BLT - Positive > Zero");

        // 4. Test BGE (funct3 = 3'b101)
        funct3 = 3'b101;
        rs1_data = 32'h0000_0001;
        rs2_data = 32'h0000_0000;
        #1 check_result(1'b1, "BGE - Positive >= Zero");

        rs1_data = 32'hFFFF_FFFF; // -1
        rs2_data = 32'h0000_0000; // 0
        #1 check_result(1'b0, "BGE - Negative < Zero");

        // 5. Test BLTU (funct3 = 3'b110)
        funct3 = 3'b110;
        rs1_data = 32'h0000_0001;
        rs2_data = 32'hFFFF_FFFF;
        #1 check_result(1'b1, "BLTU - Unsigned comparison 1 < max");

        rs1_data = 32'hFFFF_FFFF;
        rs2_data = 32'h0000_0001;
        #1 check_result(1'b0, "BLTU - Unsigned comparison max > 1");

        // 6. Test BGEU (funct3 = 3'b111)
        funct3 = 3'b111;
        rs1_data = 32'hFFFF_FFFF;
        rs2_data = 32'h0000_0001;
        #1 check_result(1'b1, "BGEU - Unsigned comparison max >= 1");

        rs1_data = 32'h0000_0001;
        rs2_data = 32'hFFFF_FFFF;
        #1 check_result(1'b0, "BGEU - Unsigned comparison 1 < max");

        // 7. Test Jump instruction
        branch = 1'b0;
        jump = 1'b1;
        #1 check_result(1'b1, "JUMP - Unconditional jump");

        // 8. Test no branch/jump
        branch = 1'b0;
        jump = 1'b0;
        #1 check_result(1'b0, "No branch/jump");

        $display("Branch Judge test completed");
        $stop;
    end

    // Coverage monitoring
    covergroup branch_judge_coverage @(take_branch);
        funct3_cp: coverpoint funct3 {
            bins beq  = {3'b000};
            bins bne  = {3'b001};
            bins blt  = {3'b100};
            bins bge  = {3'b101};
            bins bltu = {3'b110};
            bins bgeu = {3'b111};
        }
        
        branch_cp: coverpoint branch;
        jump_cp: coverpoint jump;
        
        rs1_data_cp: coverpoint rs1_data {
            bins zero = {'0};
            bins pos_values = {[1:32'h7FFF_FFFF]};
            bins neg_values = {[32'h8000_0000:32'hFFFF_FFFF]};
        }
        
        rs2_data_cp: coverpoint rs2_data {
            bins zero = {'0};
            bins pos_values = {[1:32'h7FFF_FFFF]};
            bins neg_values = {[32'h8000_0000:32'hFFFF_FFFF]};
        }
        
        take_branch_cp: coverpoint take_branch;
        
        branch_cross: cross funct3_cp, branch_cp, take_branch_cp;
        jump_cross: cross jump_cp, take_branch_cp;
    endgroup

    branch_judge_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_branch_judge.vcd");
        $dumpvars(0, _tb_branch_judge);
    end

endmodule 