`include "_riscv_defines.sv"

// ALU接口定义
interface alu_if;
import _riscv_defines::*;
    logic [DATA_WIDTH-1:0] operand1;  
    logic [DATA_WIDTH-1:0] operand2;  
    logic                  req_valid; 
    alu_op_t               alu_op;     
    
    logic [DATA_WIDTH-1:0] result;    
    logic                  resp_valid;

    // 请求者端口（如执行单元）
    modport requester (
        output operand1,
        output operand2,
        output req_valid,
        output alu_op,
        input  result,
        input  resp_valid
    );

    // 响应者端口（ALU）
    modport responder (
        input  operand1,
        input  operand2,
        input  req_valid,
        input  alu_op,
        output result,
        output resp_valid
    );
endinterface

// ALU模块
module alu
import _riscv_defines::*;
(
    input  logic    clk,
    input  logic    rst_n,
    alu_if.responder alu_if
);
    // 内部信号
    logic signed [DATA_WIDTH-1:0] operand1_signed;
    logic signed [DATA_WIDTH-1:0] operand2_signed;
    logic [3:0] counter;  // 用于计数10个周期
    logic [DATA_WIDTH-1:0] result_reg;
    
    assign operand1_signed = alu_if.operand1;
    assign operand2_signed = alu_if.operand2;

    // 状态机定义
    typedef enum logic [1:0] {
        IDLE,      
        PROCESSING,
        FINISH     
    } state_t;
    
    state_t curr_state, next_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_state <= IDLE;
        end else begin
            curr_state <= next_state;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= '0;
        end else if (curr_state == PROCESSING) begin
            counter <= counter + 1;
        end
    end

    // 状态转换逻辑
    always_comb begin
        next_state = curr_state;
        case (curr_state)
            IDLE: begin
                if (alu_if.req_valid) begin
                    next_state = PROCESSING;
                end
            end
            PROCESSING: begin
                if (counter == 4'd9) begin  // 10个周期后完成
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
        endcase
    end

    // 计算结果
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= '0;
        end else if (curr_state == PROCESSING && counter == 4'd0) begin
            case (alu_if.alu_op)
                ALU_ADD:  result_reg <= alu_if.operand1 + alu_if.operand2;
                ALU_SUB:  result_reg <= alu_if.operand1 - alu_if.operand2;
                ALU_AND:  result_reg <= alu_if.operand1 & alu_if.operand2;
                ALU_OR:   result_reg <= alu_if.operand1 | alu_if.operand2;
                ALU_XOR:  result_reg <= alu_if.operand1 ^ alu_if.operand2;
                ALU_SLT:  result_reg <= {31'b0, operand1_signed < operand2_signed};
                ALU_SLTU: result_reg <= {31'b0, alu_if.operand1 < alu_if.operand2};
                ALU_SLL:  result_reg <= alu_if.operand1 << alu_if.operand2[4:0];
                ALU_SRL:  result_reg <= alu_if.operand1 >> alu_if.operand2[4:0];
                ALU_SRA:  result_reg <= operand1_signed >>> alu_if.operand2[4:0];
                default:  result_reg <= _DEBUG_NO_USE_;
            endcase
        end
    end

    // 输出信号赋值
    assign alu_if.result = result_reg;
    assign alu_if.resp_valid = (curr_state == FINISH);

endmodule