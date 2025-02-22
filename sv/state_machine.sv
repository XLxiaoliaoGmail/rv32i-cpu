`include "_riscv_defines.sv"

interface sm_if;
    import _riscv_defines::*;

    logic    state_finish;
    opcode_t opcode;
    state_t  now_state;
    state_t  now_state_d1;
    state_t  next_state;

    // 定义模块端口方向
    modport master (
        output state_finish,
        output opcode,
        input  now_state,
        input  now_state_d1,
        input  next_state
    );

    modport self (
        input state_finish,
        input opcode,
        output now_state,
        output now_state_d1,
        output next_state
    );
endinterface

module state_machine
import _riscv_defines::*;
(
    input  logic clk,
    input  logic rst_n,
    sm_if.self sm_if
);
    // now_state_d1
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sm_if.now_state_d1 <= WRITEBACK;
        end else begin
            sm_if.now_state_d1 <= sm_if.now_state;
        end
    end

    // now_state
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            sm_if.now_state <= FETCH;
        end else if (sm_if.state_finish) begin
            sm_if.now_state <= sm_if.next_state;
        end
    end

    // next_state
    always_comb begin
        sm_if.next_state = IDLE;
        case (sm_if.now_state)
            FETCH: begin
                sm_if.next_state = DECODE;
            end
            DECODE: begin
                sm_if.next_state = EXECUTE;
            end
            EXECUTE: begin
                case (sm_if.opcode)
                    OP_BRANCH:  sm_if.next_state = FETCH;      // 分支指令执行后直接取指
                    OP_LOAD:    sm_if.next_state = MEMORY;     // 加载指令需要访存
                    OP_STORE:   sm_if.next_state = MEMORY;     // 存储指令需要访存
                    OP_R_TYPE:  sm_if.next_state = WRITEBACK;  // R型指令直接写回
                    OP_I_TYPE:  sm_if.next_state = WRITEBACK;  // I型算术指令直接写回
                    OP_JAL:     sm_if.next_state = WRITEBACK;  // JAL需要写回
                    OP_JALR:    sm_if.next_state = WRITEBACK;  // JALR需要写回
                    OP_LUI:     sm_if.next_state = WRITEBACK;  // LUI直接写回
                    OP_AUIPC:   sm_if.next_state = WRITEBACK;  // AUIPC直接写回
                endcase
            end
            MEMORY: begin
                case (sm_if.opcode)
                    OP_LOAD:    sm_if.next_state = WRITEBACK;  // 加载指令需要写回
                    OP_STORE:   sm_if.next_state = FETCH;      // 存储指令完成后直接取指
                endcase
            end
            WRITEBACK: begin
                sm_if.next_state = FETCH;
            end
        endcase
    end
endmodule 