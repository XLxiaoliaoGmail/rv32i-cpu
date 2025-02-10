`include "_riscv_defines.sv"
`include "_axi_defines.sv"

module imem
import _riscv_defines::*, _axi_defines::*;
(
    input  logic                clk,
    input  logic                rst_n,
    
    // AXI读地址通道
    input  logic [AXI_ID_WIDTH-1:0]   axi_arid,
    input  logic [AXI_ADDR_WIDTH-1:0] axi_araddr,
    input  logic [7:0]                axi_arlen,
    input  logic [2:0]                axi_arsize,
    input  logic [1:0]                axi_arburst,
    input  logic                      axi_arvalid,
    output logic                      axi_arready,
    
    // AXI读数据通道
    output logic [AXI_ID_WIDTH-1:0]   axi_rid,
    output logic [AXI_DATA_WIDTH-1:0] axi_rdata,
    output logic [1:0]                axi_rresp,
    output logic                      axi_rlast,
    output logic                      axi_rvalid,
    input  logic                      axi_rready
);

    // 指令存储器，大小为4KB
    logic [7:0] mem [IMEM_SIZE];

    // AXI状态机
    typedef enum logic [1:0] {
        IDLE,
        READ_DATA,
        WAIT_READY
    } axi_state_t;

    axi_state_t current_state, next_state;
    
    // AXI控制信号
    logic [7:0] burst_count;
    logic [AXI_ADDR_WIDTH-1:0] read_addr;
    logic [AXI_ID_WIDTH-1:0] read_id;

    // current_state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // next_state
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (axi_arvalid) begin
                    next_state = READ_DATA;
                end
            end
            READ_DATA: begin
                if (axi_rready) begin
                    if (burst_count == axi_arlen) begin
                        next_state = IDLE;
                    end
                end else begin
                    next_state = WAIT_READY;
                end
            end
            WAIT_READY: begin
                if (axi_rready) begin
                    next_state = READ_DATA;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // AXI读地址通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arready <= 1'b0;
            read_addr <= '0;
            read_id <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (axi_arvalid && !axi_arready) begin
                        axi_arready <= 1'b1;
                        read_addr <= axi_araddr;
                        read_id <= axi_arid;
                    end
                end
                default: begin
                    axi_arready <= 1'b0;
                end
            endcase
        end
    end
    
    // 模拟读取延迟
    logic [3:0] delay_counter;
    parameter READ_DELAY = 4'd2;

    // AXI读数据通道控制
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_rvalid <= 1'b0;
            axi_rlast <= 1'b0;
            burst_count <= '0;
            axi_rdata <= '0;
            axi_rid <= '0;
            axi_rresp <= AXI_RESP_OKAY;
        end else begin
            case (current_state)
                READ_DATA: begin
                    if (axi_rready || !axi_rvalid) begin
                        if (delay_counter == READ_DELAY) begin
                            axi_rvalid <= 1'b1;
                            axi_rid <= read_id;
                            // 读取32位数据（小端序）
                            axi_rdata <= {
                                mem[read_addr + burst_count*4 + 3],
                                mem[read_addr + burst_count*4 + 2],
                                mem[read_addr + burst_count*4 + 1],
                                mem[read_addr + burst_count*4]
                            };
                            axi_rlast <= (burst_count == axi_arlen);
                            // 主机接收数据后，burst_count加1，delay_counter清零
                            if (axi_rready) begin
                                burst_count <= burst_count + 1;
                                delay_counter <= '0;
                            end
                        end else begin
                            delay_counter <= delay_counter + 1;
                            axi_rvalid <= 1'b0;
                        end
                    end
                end
                default: begin
                    if (axi_rready) begin
                        axi_rvalid <= 1'b0;
                        axi_rlast <= 1'b0;
                        burst_count <= '0;
                    end
                end
            endcase
        end
    end

    // 指向下一条要添加的指令地址
    int next_instr_addr;

    // 复位时初始化指针
    logic [31:0] temp_mem[0:IMEM_SIZE/4-1];
    
    // 复位时初始化内存
    initial begin
        // 从文件加载32位指令到临时数组
        $readmemh(IMEM_PATH, temp_mem);
        
        // 将32位指令拆分为8位存储到mem中
        for (int i = 0; i < IMEM_SIZE/4; i++) begin
            // 小端序存储 (Little Endian)
            mem[i*4+0] = temp_mem[i][7:0];  
            mem[i*4+1] = temp_mem[i][15:8]; 
            mem[i*4+2] = temp_mem[i][23:16];
            mem[i*4+3] = temp_mem[i][31:24];
        end
    end

    // 添加指令的task
    task add_instruction;
        input logic [31:0] instr;
        begin
            mem[next_instr_addr]   = instr[7:0];  
            mem[next_instr_addr+1] = instr[15:8]; 
            mem[next_instr_addr+2] = instr[23:16];
            mem[next_instr_addr+3] = instr[31:24];
            next_instr_addr = next_instr_addr + 4;
        end
    endtask

endmodule 