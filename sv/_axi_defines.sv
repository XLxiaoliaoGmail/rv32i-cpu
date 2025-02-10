// AXI总线参数定义
package _axi_defines;

    // AXI地址宽度和数据宽度
    parameter AXI_ADDR_WIDTH = 32;
    parameter AXI_DATA_WIDTH = 32;
    parameter AXI_ID_WIDTH   = 4;
    parameter AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;

    // 突发类型
    typedef enum logic [1:0] {
        AXI_BURST_FIXED = 2'b00,
        AXI_BURST_INCR  = 2'b01,
        AXI_BURST_WRAP  = 2'b10
    } axi_burst_type_t;

    // 响应类型
    typedef enum logic [1:0] {
        AXI_RESP_OKAY   = 2'b00,
        AXI_RESP_EXOKAY = 2'b01,
        AXI_RESP_SLVERR = 2'b10,
        AXI_RESP_DECERR = 2'b11
    } axi_resp_t;

endpackage 