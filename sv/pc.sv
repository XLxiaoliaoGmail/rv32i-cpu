`include "_riscv_defines.sv"

module pc 
import _riscv_defines::*;
(
    input  logic                clk,
    input  logic                rst_n,
    input  logic                we,
    input  logic [DATA_WIDTH-1:0] next_pc,
    output logic [DATA_WIDTH-1:0] now_pc
);


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            now_pc <= '0;
        end else if (we) begin
            now_pc <= next_pc;
        end else begin
            now_pc <= now_pc;
        end
    end

endmodule 