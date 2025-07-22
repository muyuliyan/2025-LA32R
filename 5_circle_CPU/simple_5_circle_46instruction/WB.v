module WB_stage(
    input        clk,
    input        reset,
    input [31:0] pc,
    input [3:0]  data_sram_we,
    input [31:0] data_sram_wdata,
    input [31:0] data_sram_addr,
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,      
    input [31:0] rf_wdata,     
    input        to_wb_valid,
    
    output [3:0]  wb_sram_we,
    output [31:0] wb_sram_wdata,
    output [31:0] wb_sram_addr,
    output [3:0]  rf_we_out,        
    output [4:0]  rf_waddr_out,      
    output [31:0] rf_wdata_out, 

    output wb_allow_in,
    output wb_ready_go,
    output reg wb_valid
);
assign wb_sram_we = data_sram_we;
assign wb_sram_wdata = data_sram_wdata;
assign wb_sram_addr = data_sram_addr;
assign rf_we_out    = wb_valid ? rf_we : 4'b0;
assign rf_waddr_out = rf_waddr;
assign rf_wdata_out = rf_wdata;

always @(posedge clk) begin
    if(reset) begin
        wb_valid <= 1'b0;
    end
    else if (wb_allow_in) begin
        wb_valid <= to_wb_valid;
    end
end

assign wb_allow_in = !wb_valid || wb_ready_go;
assign wb_ready_go = 1'b1;
endmodule