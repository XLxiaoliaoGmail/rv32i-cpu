`include "_riscv_defines.sv"
`include "_axi_defines.sv"

interface cpu_cache_if
import _riscv_defines::*;
(
);

    logic [ADDR_WIDTH-1:0] addr;
    logic                  req;
    logic [DATA_WIDTH-1:0] rdata;
    logic                  ready;

    // CPU视角的端口
    modport cpu (
        output addr,
        output req,
        input  rdata,
        input  ready
    );

    // Cache视角的端口
    modport cache (
        input  addr,
        input  req,
        output rdata,
        output ready
    );
endinterface

// AXI读主控接口
interface axi_read_master_if
import _riscv_defines::*;
(
);
    // 控制信号
    logic        read_req;      // 读请求信号
    logic [31:0] read_addr;     // 读地址
    logic [7:0]  read_len;      // 读取长度（突发传输长度）
    logic        read_ready;    // 读就绪信号
    logic        read_done;     // 读完成信号
    logic [31:0] read_data;     // 读取的数据

    // Cache视角的端口（发送请求方）
    modport requester (
        output read_req,
        output read_addr,
        output read_len,
        input  read_ready,
        input  read_done,
        input  read_data
    );

    // Master视角的端口（处理请求方）
    modport handler (
        input  read_req,
        input  read_addr,
        input  read_len,
        output read_ready,
        output read_done,
        output read_data
    );
endinterface

interface axi_read_if
import _axi_defines::*;
(
);
    // 读地址通道
    logic [AXI_ID_WIDTH-1:0]   arid;
    logic [AXI_ADDR_WIDTH-1:0] araddr;
    logic [7:0]                arlen;
    logic [2:0]                arsize;
    logic [1:0]                arburst;
    logic                      arvalid;
    logic                      arready;
    
    // 读数据通道
    logic [AXI_ID_WIDTH-1:0]   rid;
    logic [AXI_DATA_WIDTH-1:0] rdata;
    logic [1:0]                rresp;
    logic                      rlast;
    logic                      rvalid;
    logic                      rready;

    // 主设备（Master）视角的端口
    modport master (
        output arid,
        output araddr,
        output arlen,
        output arsize,
        output arburst,
        output arvalid,
        input  arready,
        input  rid,
        input  rdata,
        input  rresp,
        input  rlast,
        input  rvalid,
        output rready
    );

    // 从设备（Slave）视角的端口
    modport slave (
        input  arid,
        input  araddr,
        input  arlen,
        input  arsize,
        input  arburst,
        input  arvalid,
        output arready,
        output rid,
        output rdata,
        output rresp,
        output rlast,
        output rvalid,
        input  rready
    );
endinterface

// AXI读从机接口
interface axi_read_slave_if
import _riscv_defines::*, _axi_defines::*;
(
);
    // 内存接口信号
    logic [AXI_DATA_WIDTH-1:0] mem_rdata;    // 从内存读取的数据
    logic [AXI_ADDR_WIDTH-1:0] mem_addr;     // 发送给内存的地址
    logic                      mem_read_en;   // 内存读使能信号

    // 内存视角的端口（提供数据方）
    modport memory (
        output mem_rdata,
        input  mem_addr,
        input  mem_read_en
    );

    // Slave视角的端口（请求数据方）
    modport controller (
        input  mem_rdata,
        output mem_addr,
        output mem_read_en
    );

endinterface
