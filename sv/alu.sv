`include "_pkg_riscv_defines.sv"

// ALU接口定义
interface alu_if;
import _pkg_riscv_defines::*;
    logic [DATA_WIDTH-1:0] operand1;  
    logic [DATA_WIDTH-1:0] operand2;  
    logic                  req_valid; 
    alu_op_t               alu_op;     
    
    logic [DATA_WIDTH-1:0] result;    
    logic                  resp_valid;
    logic                  resp_ready;

    // 请求者端口（如执行单元）
    modport master (
        output operand1,
        output operand2,
        output req_valid,
        output alu_op,
        input  result,
        input  resp_valid,
        output resp_ready
    );

    // 响应者端口（ALU）
    modport self (
        input  operand1,
        input  operand2,
        input  req_valid,
        input  alu_op,
        output result,
        output resp_valid,
        input  resp_ready
    );
endinterface

// ALU模块
module alu
import _pkg_riscv_defines::*;
(
    input  logic    clk,
    input  logic    rst_n,
    alu_if.self alu_if
);
    parameter _SIMULATED_DELAY = 10;

    logic signed [DATA_WIDTH-1:0] src1_signed;
    logic signed [DATA_WIDTH-1:0] src2_signed;

    logic [3:0] _counter;
    logic _counter_is_zero;
    logic _counter_is_zero_d1;

    logic [DATA_WIDTH-1:0] src1;
    logic [DATA_WIDTH-1:0] src2;
    alu_op_t op;

    // src1 src2 op
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            src1 <= '0;
            src2 <= '0;
            op <= ALU_ADD;
        end else if (alu_if.req_valid && alu_if.resp_ready) begin
            src1 <= alu_if.operand1;
            src2 <= alu_if.operand2;
            op <= alu_if.alu_op;
        end
    end

    assign src1_signed = src1;
    assign src2_signed = src2;

    // _counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _counter <= _SIMULATED_DELAY;
        end else if (alu_if.req_valid && alu_if.resp_ready) begin
            _counter <= _SIMULATED_DELAY;
        end else if (~_counter_is_zero) begin
            _counter <= _counter - 1;
        end
    end

    assign _counter_is_zero = _counter == 0;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            _counter_is_zero_d1 <= '0;
        end else begin
            _counter_is_zero_d1 <= _counter_is_zero;
        end
    end

    // 计算结果
    always_comb begin
        case (op)
                ALU_ADD:  alu_if.result <= src1 + src2;
                ALU_SUB:  alu_if.result <= src1 - src2;
                ALU_AND:  alu_if.result <= src1 & src2;
                ALU_OR:   alu_if.result <= src1 | src2;
                ALU_XOR:  alu_if.result <= src1 ^ src2;
                ALU_SLT:  alu_if.result <= {31'b0, src1_signed < src2_signed};
                ALU_SLTU: alu_if.result <= {31'b0, src1 < src2};
                ALU_SLL:  alu_if.result <= src1 << src2[4:0];
                ALU_SRL:  alu_if.result <= src1 >> src2[4:0];
                ALU_SRA:  alu_if.result <= src1_signed >>> src2[4:0];
            endcase
    end

    // 输出信号赋值
    assign alu_if.resp_valid = _counter_is_zero && ~_counter_is_zero_d1;
    assign alu_if.resp_ready = _counter_is_zero;

endmodule