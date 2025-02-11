`include "_riscv_defines.sv"

// pc和icache之间的接口
interface pc_icache_if;
import _riscv_defines::*;
    // PC -> ICache信号
    logic [ADDR_WIDTH-1:0] pc_addr;     // 程序计数器地址
    logic                  pc_valid;    // PC地址有效信号
    
    // ICache -> PC信号
    logic [DATA_WIDTH-1:0] instruction; // 指令数据
    logic                  instr_valid; // 指令有效信号

    // PC视角的端口
    modport pc (
        output pc_addr,
        output pc_valid,
        input  instruction,
        input  instr_valid
    );

    // ICache视角的端口
    modport icache (
        input  pc_addr,
        input  pc_valid,
        output instruction,
        output instr_valid
    );
endinterface

// axi_read_if 接口
interface axi_read_if;
import _riscv_defines::*;
    // AXI读地址通道
    logic [AXI_ADDR_WIDTH-1:0] araddr;
    logic [7:0]                arlen;
    axi_size_t                 arsize;
    axi_burst_type_t           arburst;
    logic                      arvalid;
    logic                      arready;

    // AXI读数据通道
    logic [AXI_DATA_WIDTH-1:0] rdata;
    logic                      rlast;
    axi_resp_t                 rresp;
    logic                      rvalid;
    logic                      rready;

    // 主设备端口
    modport master (
        output araddr, arlen, arsize, arburst, arvalid,
        input  arready,
        input  rdata, rlast, rresp, rvalid,
        output rready
    );

    // 从设备端口
    modport slave (
        input  araddr, arlen, arsize, arburst, arvalid,
        output arready,
        output rdata, rlast, rresp, rvalid,
        input  rready
    );
endinterface