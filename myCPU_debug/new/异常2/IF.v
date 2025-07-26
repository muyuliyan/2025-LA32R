module IF_stage (
    input clk,
    input reset,
    input to_fs_valid,
    input excp_adef,
    input [31:0] pc,
    input [31:0] inst_sram_rdata,
    input ds_allow_in,
    input br_taken_cancel,
    input stall,
    
    output        fs_excp_adef,
    output [31:0] fs_pc,
    output [31:0] inst,
    output        fs_ready_go,
    output reg    fs_valid
);

always @(posedge clk) begin
    if(reset) begin
        fs_valid <= 1'b1;
    end
    else if(fs_allow_in) begin
        fs_valid <= to_fs_valid;
    end
    else if (br_taken_cancel) begin
        fs_valid <= 1'b0;
    end
end

assign fs_excp_adef = excp_adef;
assign fs_pc = pc;
assign inst = inst_sram_rdata;
assign fs_allow_in = !fs_valid || fs_ready_go && ds_allow_in;
assign fs_ready_go = !stall;
endmodule

module ID_reg (
    input clk,
    input reset,
    input fs_ready_go,
    input ds_allow_in,
    input flush,
    input [31:0] IF_pc,
    input [31:0] IF_inst,
    input        IF_excp_adef,

    output reg [31:0] ID_inst,
    output reg [31:0] ID_pc,
    output reg        ID_excp_adef
);

always @(posedge clk) begin
    if(reset || flush) begin
        ID_pc <= 32'h1c000000;
        ID_inst <= 32'b0;
        ID_excp_adef <= 1'b0;
    end
    else if(fs_ready_go && ds_allow_in) begin
        ID_pc <= IF_pc;
        ID_inst <= IF_inst;
        ID_excp_adef <= IF_excp_adef;
    end
end
endmodule