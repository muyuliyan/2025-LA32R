module WB_stage(
    input        clk,
    input        reset,
    input [31:0] pc,
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,      
    input [31:0] rf_wdata, 
    input        csr_we,
    input [13:0] csr_num,
    input [31:0] csr_wdata,
    input [4:0]  csr_wmask,     
    input        to_wb_valid,
    
    output [3:0]  wb_rf_we,        
    output [4:0]  wb_rf_waddr,      
    output [31:0] wb_rf_wdata,
    output        wb_csr_we,
    output [13:0] wb_csr_num,
    output [31:0] wb_csr_wdata,
    output [4:0]  wb_csr_wmask, 

    output wb_allow_in,
    output wb_ready_go,
    output reg wb_valid
);
assign wb_csr_we   = wb_valid ? csr_we : 1'b0;
assign wb_csr_num  = csr_num;
assign wb_csr_wdata = csr_wdata;
assign wb_csr_wmask = csr_wmask;
assign wb_rf_we    = wb_valid ? rf_we : 4'b0;
assign wb_rf_waddr = rf_waddr;
assign wb_rf_wdata = rf_wdata;

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