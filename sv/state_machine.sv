`include "_riscv_defines.sv"

module state_machine
import _riscv_defines::*;
(
    input  logic        clk,
    input  logic        rst_n,
    input  opcode_t     opcode,
    output state_t      current_state
);

    // 状态寄存器
    state_t current_state_reg, next_state;

    // 时序逻辑：状态更新
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            current_state_reg <= FETCH;
        end else begin
            current_state_reg <= next_state;
        end
    end

    // 组合逻辑：下一状态计算
    always_comb begin
        // 默认下一状态
        next_state = FETCH;

        case (current_state_reg)
            FETCH: begin
                next_state = DECODE;
            end

            DECODE: begin
                next_state = EXECUTE;
            end

            EXECUTE: begin
                case (opcode)
                    OP_BRANCH:  next_state = FETCH;      // 分支指令执行后直接取指
                    OP_LOAD:    next_state = MEMORY;     // 加载指令需要访存
                    OP_STORE:   next_state = MEMORY;     // 存储指令需要访存
                    OP_R_TYPE:  next_state = WRITEBACK;  // R型指令直接写回
                    OP_I_TYPE:  next_state = WRITEBACK;  // I型算术指令直接写回
                    OP_JAL:     next_state = WRITEBACK;  // JAL需要写回
                    OP_JALR:    next_state = WRITEBACK;  // JALR需要写回
                    OP_LUI:     next_state = WRITEBACK;  // LUI直接写回
                    OP_AUIPC:   next_state = WRITEBACK;  // AUIPC直接写回
                    default:    next_state = FETCH;
                endcase
            end

            MEMORY: begin
                case (opcode)
                    OP_LOAD:    next_state = WRITEBACK;  // 加载指令需要写回
                    OP_STORE:   next_state = FETCH;      // 存储指令完成后直接取指
                    default:    next_state = FETCH;
                endcase
            end

            WRITEBACK: begin
                next_state = FETCH;
            end

            default: begin
                next_state = FETCH;
            end
        endcase
    end

    // 输出当前状态
    assign current_state = current_state_reg;

endmodule 