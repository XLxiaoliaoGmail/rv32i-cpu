`include "_riscv_defines.sv"
`include "_axi_if.sv"

module riscv_core
import _riscv_defines::*;
(
    input  logic clk,
    input  logic rst_n,
    output logic [DATA_WIDTH-1:0] instruction
);

    alu_if      alu_if();
    sm_if       sm_if();
    idecoder_if idecoder_if();
    icache_if   icache_if();
    dcache_if   dcache_if();
    reg_file_if reg_file_if();
    axi_read_if #(
        
    ) imem_axi_if();

    assign instruction = icache_if.instruction; 

    control_unit control_unit_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .alu_if       (alu_if.master),
        .sm_if        (sm_if.master),
        .idecoder_if  (idecoder_if.master),
        .icache_if    (icache_if.master),
        .dcache_if    (dcache_if.master),
        .reg_file_if  (reg_file_if.master)
    );

    alu alu_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .alu_if  (alu_if.self)
    );

    state_machine state_machine_inst (
        .clk     (clk),
        .rst_n   (rst_n),
        .sm_if   (sm_if.self)
    );
    
    idecoder idecoder_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .idecoder_if  (idecoder_if.self)
    );

    icache icache_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .icache_if    (icache_if.self),
        .axi_if       (imem_axi_if.master)
    );

    imem imem_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .axi_if       (imem_axi_if.slave)
    );

    dcache dcache_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .dcache_if    (dcache_if.self)
    );

    // dmem dmem_inst (
    //     .clk          (clk),
    //     .rst_n        (rst_n),
    //     .dmem_if      (dmem_if.self)
    // );

    reg_file reg_file_inst (
        .clk          (clk),
        .rst_n        (rst_n),
        .reg_file_if  (reg_file_if.self)
    );

endmodule