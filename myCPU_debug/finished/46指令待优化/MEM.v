module MEM_stage(
    input        clk,
    input        reset,
    input [31:0] pc,
    input [31:0] data_sram_wdata,     
    input [31:0] data_sram_addr,
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,   
    input [31:0] rf_wdata, 
    input        wb_allow_in,
    input        to_ms_valid,
    input        div_valid,
    input [3:0]  mem_op,
    
    output [31:0] ms_pc,
    // 输出到MEM/WB寄存器的信号
    output [3:0]  rf_we_out,        
    output [4:0]  rf_waddr_out,      
    output [31:0] rf_wdata_out, 
    output [3:0]  sram_we,   
    output [31:0] sram_addr, 
    output [31:0] sram_wdata,  

    output ms_allow_in,
    output ms_ready_go,
    output reg ms_valid
);
wire is_st_b = (mem_op == 4'b0100);
wire is_st_h = (mem_op == 4'b0101);
wire is_st_w = (mem_op == 4'b0110);
wire saddr_ls = data_sram_addr[1:0];

wire [3:0] final_sram_we = is_st_b ? (saddr_ls == 2'b00 ? 4'b0001 : 
        saddr_ls == 2'b01 ? 4'b0010 : saddr_ls == 2'b10 ? 4'b0100 : 
        4'b1000 ):
        is_st_h ? (saddr_ls == 2'b00 ? 4'b0011 : 4'b1100) :
        is_st_w ? 4'b1111 : 4'b0000;

assign sram_we    = div_valid ? (ms_valid ? final_sram_we : 4'b0) : 4'b0;
assign sram_addr  = data_sram_addr;
assign sram_wdata = data_sram_wdata;
assign rf_wdata_out = rf_wdata;
assign rf_we_out = rf_we;
assign rf_waddr_out = rf_waddr;

always @(posedge clk) begin
    if(reset) begin
        ms_valid <= 1'b0;
    end
    else if(~div_valid) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allow_in) begin
        ms_valid <= to_ms_valid;
    end
end

// assign ms_to_wb_valid = to_ms_valid;
assign ms_pc       = pc;
assign ms_ready_go = 1'b1; 
assign ms_allow_in = !ms_valid || ms_ready_go && wb_allow_in;

endmodule

module WB_reg (
    input        clk,
    input        reset,
    input        ms_ready_go,
    input        wb_allow_in,
    input [31:0] MEM_pc,
    input [3:0]  MEM_sram_we,
    input [31:0] MEM_sram_wdata,
    input [31:0] MEM_sram_addr,
    input [3:0]  MEM_rf_we,
    input [4:0]  MEM_rf_waddr,
    input [31:0] MEM_rf_wdata,

    output reg [3:0]  WB_sram_we,
    output reg [31:0] WB_sram_addr,
    output reg [31:0] WB_sram_wdata,
    output reg [31:0] WB_pc, 
    output reg [3:0]  WB_rf_we,
    output reg [4:0]  WB_rf_waddr,
    output reg [31:0] WB_rf_wdata
);
    
always @(posedge clk) begin
    if(reset) begin
        WB_sram_we   <= 4'b0;
        WB_sram_addr <= 32'b0;
        WB_sram_wdata<= 32'b0;
        WB_pc        <= 32'h1c000000;
        WB_rf_we     <= 4'b0;
        WB_rf_waddr  <= 5'b0;
        WB_rf_wdata  <= 32'b0;
    end
    else if (ms_ready_go && wb_allow_in) begin
        WB_sram_we   <= MEM_sram_we;
        WB_sram_addr <= MEM_sram_addr;
        WB_sram_wdata<= MEM_sram_wdata;
        WB_pc        <= MEM_pc;
        WB_rf_we     <= MEM_rf_we;
        WB_rf_waddr  <= MEM_rf_waddr;
        WB_rf_wdata  <= MEM_rf_wdata;
    end
end

endmodule