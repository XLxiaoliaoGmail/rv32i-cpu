`include "../_riscv_defines.sv"

module _tb_instruction_decoder;
    import _riscv_defines::*;

    // Test signals
    logic [31:0]               instruction;
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;
    logic [REG_ADDR_WIDTH-1:0] rd_addr;
    opcode_t                   opcode;
    logic [2:0]                funct3;
    logic [6:0]                funct7;
    logic [DATA_WIDTH-1:0]     imm;

    // Instantiate DUT
    instruction_decoder dut (
        .instruction(instruction),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .imm(imm)
    );

    // Result verification task
    task check_decode(
        input [31:0] test_instruction,
        input [4:0]  exp_rs1,
        input [4:0]  exp_rs2,
        input [4:0]  exp_rd,
        input [6:0]  exp_opcode,
        input [2:0]  exp_funct3,
        input [6:0]  exp_funct7,
        input [31:0] exp_imm,
        input string test_name
    );
        instruction = test_instruction;
        #1;
        
        if (rs1_addr !== exp_rs1 || rs2_addr !== exp_rs2 || rd_addr !== exp_rd ||
            opcode !== exp_opcode || funct3 !== exp_funct3 || funct7 !== exp_funct7 ||
            imm !== exp_imm) begin
            
            $error("Test Failed - %s:", test_name);
            $display("Expected: rs1=%h, rs2=%h, rd=%h, opcode=%h, funct3=%h, funct7=%h, imm=%h",
                   exp_rs1, exp_rs2, exp_rd, exp_opcode, exp_funct3, exp_funct7, exp_imm);

            $display("Actual:   rs1=%h, rs2=%h, rd=%h, opcode=%h, funct3=%h, funct7=%h, imm=%h",
                   rs1_addr, rs2_addr, rd_addr, opcode, funct3, funct7, imm);
        end else begin
            $display("Test Passed - %s", test_name);
        end
    endtask

    // Main test process
    initial begin
        $display("Starting Instruction Decoder test...");

        // Test R-type instruction (ADD)
        // ADD x1, x2, x3
        check_decode(
            32'b0000000_00011_00010_000_00001_0110011,  // instruction
            5'd2,        // rs1
            5'd3,        // rs2
            5'd1,        // rd
            7'b0110011,  // opcode (OP_R_TYPE)
            3'b000,      // funct3
            7'b0000000,  // funct7
            32'h0,       // imm (R-type doesn't use immediate)
            "R-type ADD instruction"
        );

        // Test I-type instruction (ADDI)
        // ADDI x1, x2, 15
        check_decode(
            32'b000000001111_00010_000_00001_0010011,  // instruction
            5'd2,        // rs1
            5'd0,        // rs2 (not used in I-type)
            5'd1,        // rd
            7'b0010011,  // opcode (OP_I_TYPE)
            3'b000,      // funct3
            7'b0000000,  // funct7 (not used in I-type)
            32'd15,      // imm
            "I-type ADDI instruction"
        );

        // Test S-type instruction (SW)
        // SW x2, 16(x3)
        check_decode(
            32'b0000000_00010_00011_010_10000_0100011,  // instruction
            5'd3,        // rs1
            5'd2,        // rs2
            5'd0,        // rd (not used in S-type)
            7'b0100011,  // opcode (OP_STORE)
            3'b010,      // funct3
            7'b0000000,  // funct7 (not used in S-type)
            32'd16,      // imm
            "S-type SW instruction"
        );

        // Test B-type instruction (BEQ)
        // BEQ x1, x2, 16
        check_decode(
            32'b0000000_00010_00001_000_10000_1100011,  // instruction
            5'd1,        // rs1
            5'd2,        // rs2
            5'd0,        // rd (not used in B-type)
            7'b1100011,  // opcode (OP_BRANCH)
            3'b000,      // funct3
            7'b0000000,  // funct7 (not used in B-type)
            32'd16,      // imm
            "B-type BEQ instruction"
        );

        // Test J-type instruction (JAL)
        // JAL x1, 32 (跳转到前向32字节)
        check_decode(
            32'b00000010000000000000_00001_1101111,  // instruction
            5'd0,        // rs1 (not used in J-type)
            5'd0,        // rs2 (not used in J-type)
            5'd1,        // rd
            7'b1101111,  // opcode (OP_JAL)
            3'b000,      // funct3 (not used in J-type)
            7'b0000000,  // funct7 (not used in J-type)
            32'h20,      // imm (跳转偏移量为32字节)
            "J-type JAL instruction"
        );

        // Test U-type instruction (LUI)
        // LUI x1, 0x12345
        check_decode(
            32'b00010010001101000101_00001_0110111,  // instruction
            5'd0,        // rs1 (not used in U-type)
            5'd0,        // rs2 (not used in U-type)
            5'd1,        // rd
            7'b0110111,  // opcode (OP_LUI)
            3'b000,      // funct3 (not used in U-type)
            7'b0000000,  // funct7 (not used in U-type)
            32'h12345000,// imm
            "U-type LUI instruction"
        );

        // Test negative immediate value (I-type)
        // ADDI x1, x2, -123
        check_decode(
            //  111110000101_00000_000_00000_0010011
            32'b111110000101_00010_000_00001_0010011,  // instruction，修正立即数字段为-123的补码
            5'd2,        // rs1
            5'd0,        // rs2 (not used in I-type)
            5'd1,        // rd
            7'b0010011,  // opcode (OP_I_TYPE)
            3'b000,      // funct3
            7'b0000000,  // funct7 (not used in I-type)
            32'hffffff85,    // imm (-123 in hex)
            "I-type ADDI with negative immediate"
        );

        $display("Instruction Decoder test completed");
        $stop;
    end

    // Coverage monitoring
    covergroup instruction_coverage @(instruction);
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

        immediate_sign_cp: coverpoint imm[31] {
            bins positive = {1'b0};
            bins negative = {1'b1};
        }

        instruction_fields_cross: cross opcode_cp, funct3_cp;
    endgroup

    instruction_coverage cg = new();

    // Add waveform tracing
    initial begin
        $dumpfile("./waveform/_tb_instruction_decoder.vcd");
        $dumpvars(0, _tb_instruction_decoder);
    end

endmodule
