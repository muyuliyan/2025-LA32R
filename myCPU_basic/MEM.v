module MEM_stage(
    input        clk,
    input        reset,
    input        stall,
    input [31:0] pc,
    input        data_sram_en,
    input [3:0]  data_sram_we,  
    input [31:0] data_sram_wdata,     
    input [31:0] data_sram_addr,      
    input [31:0] data_sram_rdata,    
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,   
    input [31:0] rf_wdata, 
    input        wb_allow_in,
    input        to_ms_valid,
    
    output [31:0] ms_pc,
    // 输出到MEM/WB寄存器的信号
    output [3:0]  rf_we_out,        
    output [4:0]  rf_waddr_out,      
    output [31:0] rf_wdata_out, 
    output        sram_en,     
    output [3:0]  sram_we,   
    output [31:0] sram_addr, 
    output [31:0] sram_wdata,  

    output ms_allow_in,
    output ms_ready_go,
    output reg ms_valid
);

assign sram_en    = to_ms_valid ? data_sram_en : 1'b0;
assign sram_we    = to_ms_valid ? data_sram_we : 4'b0;
assign sram_addr  = data_sram_addr;
assign sram_wdata = data_sram_wdata;
assign rf_wdata_out = data_sram_en ? data_sram_rdata : rf_wdata;
assign rf_we_out = rf_we;
assign rf_waddr_out = rf_waddr;

always @(posedge clk) begin
    if(reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allow_in) begin
        ms_valid <= to_ms_valid;
    end
end

assign ms_pc       = pc;
assign ms_ready_go = !stall; 
assign ms_allow_in = !ms_valid || ms_ready_go && wb_allow_in;

endmodule

module WB_reg (
    input        clk,
    input        reset,
    input        ms_ready_go,
    input        wb_allow_in,
    input        MEM_valid,
    input [31:0] MEM_pc,
    input [3:0]  MEM_rf_we,
    input [4:0]  MEM_rf_waddr,
    input [31:0] MEM_rf_wdata,

    output reg WB_valid,
    output reg [31:0] WB_pc, 
    output reg [3:0]  WB_rf_we,
    output reg [4:0]  WB_rf_waddr,
    output reg [31:0] WB_rf_wdata
);
    
always @(posedge clk) begin
    if(reset) begin
        WB_valid    <= 1'b0;
        WB_pc       <= 32'h1c000000;
        WB_rf_we    <= 4'b0;
        WB_rf_waddr <= 5'b0;
        WB_rf_wdata <= 32'b0;
    end
    else if (ms_ready_go && wb_allow_in) begin
        WB_valid    <= MEM_valid;
        WB_pc       <= MEM_pc;
        WB_rf_we    <= MEM_rf_we;
        WB_rf_waddr <= MEM_rf_waddr;
        WB_rf_wdata <= MEM_rf_wdata;
    end
end

endmodule