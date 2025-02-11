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
