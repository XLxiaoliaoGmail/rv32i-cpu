`include "_riscv_defines.sv"

module pc 
import _riscv_defines::*;
(
    input  logic                clk,
    input  logic                rst_n,
    input  logic [DATA_WIDTH-1:0] next_pc,
    output logic [DATA_WIDTH-1:0] current_pc
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pc <= '0;
        end else begin
            current_pc <= next_pc;
        end
    end

endmodule 