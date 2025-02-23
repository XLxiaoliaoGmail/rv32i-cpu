`include "_pkg_riscv_defines.sv"

interface axi_read_if;
    import _pkg_riscv_defines::*;
    // AXI读地址通道
    logic [ADDR_WIDTH-1:0] araddr;
    logic [AXI_ARLEN_WIDTH-1:0]                arlen;
    axi_size_t                 arsize;
    axi_burst_type_t           arburst;
    logic                      arvalid;
    logic                      arready;

    // AXI读数据通道
    logic [DATA_WIDTH-1:0] rdata;
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

// axi_write_if 接口
interface axi_write_if;
import _pkg_riscv_defines::*;
    // AXI写地址通道
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [AXI_ARLEN_WIDTH-1:0]                 awlen;
    axi_size_t                  awsize;
    axi_burst_type_t           awburst;
    logic                      awvalid;
    logic                      awready;

    // AXI写数据通道
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH/8-1:0] wstrb;
    logic                      wlast;
    logic                      wvalid;
    logic                      wready;

    // AXI写响应通道
    axi_resp_t                 bresp;
    logic                      bvalid;
    logic                      bready;

    // 主设备端口
    modport master (
        output awaddr, awlen, awsize, awburst, awvalid,
        input  awready,
        output wdata, wstrb, wlast, wvalid,
        input  wready,
        input  bresp, bvalid,
        output bready
    );

    // 从设备端口
    modport slave (
        input  awaddr, awlen, awsize, awburst, awvalid,
        output awready,
        input  wdata, wstrb, wlast, wvalid,
        output wready,
        output bresp, bvalid,
        input  bready
    );
endinterface