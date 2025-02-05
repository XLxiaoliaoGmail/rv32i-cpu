`include "_riscv_defines.sv"

module register_file
import _riscv_defines::*;
(
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      we,
    input  logic [REG_ADDR_WIDTH-1:0] rs1_addr,
    input  logic [REG_ADDR_WIDTH-1:0] rs2_addr,
    input  logic [REG_ADDR_WIDTH-1:0] rd_addr,
    input  logic [DATA_WIDTH-1:0]     rd_data,
    output logic [DATA_WIDTH-1:0]     rs1_data,
    output logic [DATA_WIDTH-1:0]     rs2_data
);
    // Use parameterized number of registers
    logic [DATA_WIDTH-1:0] registers [32];

    // Read registers (with write-read forwarding)
    always_comb begin
        // rs1 read logic
        if (rs1_addr == '0) begin
            rs1_data = '0;
        end else if (we && rs1_addr == rd_addr) begin
            rs1_data = rd_data;  // Write-read forwarding
        end else begin
            rs1_data = registers[rs1_addr];
        end

        // rs2 read logic
        if (rs2_addr == '0) begin
            rs2_data = '0;
        end else if (we && rs2_addr == rd_addr) begin
            rs2_data = rd_data;  // Write-read forwarding
        end else begin
            rs2_data = registers[rs2_addr];
        end
    end

    // Write registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= '0;
            end
        end else if (we && rd_addr != '0) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule 