`include "_riscv_defines.sv"

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