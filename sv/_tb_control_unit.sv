`include "_riscv_defines.sv"

module _tb_control_unit;
    import _riscv_defines::*;

    // Test signals
    logic [6:0]     opcode;
    logic [2:0]     funct3;
    logic [6:0]     funct7;
    logic           reg_write;
    logic           mem_write;
    logic           mem_read;
    logic           branch;
    logic           jump;
    logic           alu_src;
    logic [1:0]     mem_to_reg;
    alu_op_t        alu_op;

    // Instantiate DUT
    control_unit dut (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .branch(branch),
        .jump(jump),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op)
    );

    // Result verification task
    task check_control_signals(
        input logic exp_reg_write,
        input logic exp_mem_write,
        input logic exp_mem_read,
        input logic exp_branch,
        input logic exp_jump,
        input logic exp_alu_src,
        input logic [1:0] exp_mem_to_reg,
        input alu_op_t exp_alu_op,
        input string test_name
    );
        if (reg_write !== exp_reg_write || mem_write !== exp_mem_write || 
            mem_read !== exp_mem_read || branch !== exp_branch ||
            jump !== exp_jump || alu_src !== exp_alu_src ||
            mem_to_reg !== exp_mem_to_reg || alu_op !== exp_alu_op) begin
            
            $error("Test Failed - %s:", test_name);
            $error("Expected: reg_write=%b, mem_write=%b, mem_read=%b, branch=%b, jump=%b, alu_src=%b, mem_to_reg=%b, alu_op=%s",
                   exp_reg_write, exp_mem_write, exp_mem_read, exp_branch, exp_jump, exp_alu_src, exp_mem_to_reg, exp_alu_op.name());
            $error("Actual:   reg_write=%b, mem_write=%b, mem_read=%b, branch=%b, jump=%b, alu_src=%b, mem_to_reg=%b, alu_op=%s",
                   reg_write, mem_write, mem_read, branch, jump, alu_src, mem_to_reg, alu_op.name());
        end else begin
            $display("Test Passed - %s", test_name);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting Control Unit test...");

        // Test R-type instructions
        opcode = OP_R_TYPE;
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, ALU_ADD, "R-type ADD");

        funct7 = 7'b0100000;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, ALU_SUB, "R-type SUB");

        funct3 = 3'b111;
        funct7 = 7'b0000000;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 2'b00, ALU_AND, "R-type AND");

        // Test I-type instructions
        opcode = OP_I_TYPE;
        funct3 = 3'b000;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, ALU_ADD, "I-type ADDI");

        funct3 = 3'b010;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, ALU_SLT, "I-type SLTI");

        // Test Load instructions
        opcode = OP_LOAD;
        funct3 = 3'b010;  // LW
        #1 check_control_signals(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, 2'b01, ALU_ADD, "Load Word");

        // Test Store instructions
        opcode = OP_STORE;
        funct3 = 3'b010;  // SW
        #1 check_control_signals(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, ALU_ADD, "Store Word");

        // Test Branch instructions
        opcode = OP_BRANCH;
        funct3 = 3'b000;  // BEQ
        #1 check_control_signals(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, ALU_SUB, "Branch Equal");

        // Test JAL instruction
        opcode = OP_JAL;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 2'b10, ALU_ADD, "JAL");

        // Test JALR instruction
        opcode = OP_JALR;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 2'b10, ALU_ADD, "JALR");

        // Test LUI instruction
        opcode = OP_LUI;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, ALU_ADD, "LUI");

        // Test AUIPC instruction
        opcode = OP_AUIPC;
        #1 check_control_signals(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, ALU_ADD, "AUIPC");

        $display("Control Unit test completed");
        $stop;
    end

    // Coverage monitoring
    covergroup control_coverage @(alu_op);
        opcode_cp: coverpoint opcode {
            bins r_type = {OP_R_TYPE};
            bins i_type = {OP_I_TYPE};
            bins load = {OP_LOAD};
            bins store = {OP_STORE};
            bins branch = {OP_BRANCH};
            bins jal = {OP_JAL};
            bins jalr = {OP_JALR};
            bins lui = {OP_LUI};
            bins auipc = {OP_AUIPC};
        }

        funct3_cp: coverpoint funct3 {
            bins all_values[] = {[0:7]};
        }

        funct7_cp: coverpoint funct7 {
            bins zero = {7'b0000000};
            bins sub = {7'b0100000};
            bins others = default;
        }

        control_signals_cp: coverpoint {reg_write, mem_write, mem_read, branch, jump} {
            bins valid_combinations[] = {[0:31]};
        }

        alu_op_cp: coverpoint alu_op {
            bins all_ops[] = {ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
                             ALU_SLT, ALU_SLTU, ALU_SLL, ALU_SRL, ALU_SRA};
        }

        op_cross: cross opcode_cp, funct3_cp, alu_op_cp;
    endgroup

    control_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_control_unit.vcd");
        $dumpvars(0, _tb_control_unit);
    end

endmodule 