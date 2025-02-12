`include "_riscv_defines.sv"

interface reg_file_if;
    import _riscv_defines::*;
    logic [REG_ADDR_WIDTH-1:0] rs1_addr;
    logic [REG_ADDR_WIDTH-1:0] rs2_addr;
    logic [DATA_WIDTH-1:0]     rs1_data;
    logic [DATA_WIDTH-1:0]     rs2_data;
    logic [REG_ADDR_WIDTH-1:0] rd_addr;
    logic [DATA_WIDTH-1:0]     rd_data;
    logic                      write_en;

    modport self (
        input  rs1_addr,
        input  rs2_addr,
        output rs1_data,
        output rs2_data,
        input  rd_addr,
        input  rd_data,
        input  write_en
    );

    modport master (
        output rs1_addr,
        output rs2_addr,
        input  rs1_data,
        input  rs2_data,
        output rd_addr,
        output rd_data,
        input  write_en
    );
endinterface

module reg_file
import _riscv_defines::*;
(
    input  logic clk,
    input  logic rst_n,
    reg_file_if.self reg_file_if
);
    logic [DATA_WIDTH-1:0] regs [2**REG_ADDR_WIDTH-1:0];

    // Read regs (with write-read forwarding)
    always_comb begin
        // rs1 read logic
        if (reg_file_if.rs1_addr == '0) begin
            reg_file_if.rs1_data = '0;
        end else if (reg_file_if.write_en && reg_file_if.rd_addr == reg_file_if.rs1_addr) begin
            reg_file_if.rs1_data = reg_file_if.rd_data;  // Write-read forwarding
        end else begin
            reg_file_if.rs1_data = regs[reg_file_if.rs1_addr];
        end

        // rs2 read logic
        if (reg_file_if.rs2_addr == '0) begin
            reg_file_if.rs2_data = '0;
        end else if (reg_file_if.write_en && reg_file_if.rd_addr == reg_file_if.rs2_addr) begin
            reg_file_if.rs2_data = reg_file_if.rd_data;  // Write-read forwarding
        end else begin
            reg_file_if.rs2_data = regs[reg_file_if.rs2_addr];
        end
    end

    // Write regs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 2**REG_ADDR_WIDTH; i++) begin
                regs[i] <= '0;
            end
        end else if (reg_file_if.write_en) begin
            regs[reg_file_if.rd_addr] <= reg_file_if.rd_data;
        end
    end

endmodule 