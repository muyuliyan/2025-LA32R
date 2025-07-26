module WB_stage(
    input        clk,
    input        reset,
    input [31:0] pc,
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,      
    input [31:0] rf_wdata, 
    input [3:0]  data_sram_we,
    input [31:0] data_sram_wdata,
    input [31:0] data_sram_addr,
    input [3:0]  csr_we,
    input [13:0] csr_num,
    input [31:0] csr_wdata,
    input [31:0] csr_wmask,     
    input        to_wb_valid,
    input        ertn,
    input        excp_syscall,
    input        excp_break,
    input        excp_ale,
    input        excp_ipe,
    input        excp_ine,
    input        excp_adef,
    input        has_int,    
    
    output        wb_ex,
    output [5:0]  wb_ecode,
    output [8:0]  wb_esubcode,
    output [31:0] wb_pc,
    output [3:0]  wb_rf_we,        
    output [4:0]  wb_rf_waddr,      
    output [31:0] wb_rf_wdata,
    output [3:0]  wb_sram_we,
    output [31:0] wb_sram_wdata,
    output [31:0] wb_sram_addr,
    output [3:0]  wb_csr_we,
    output [13:0] wb_csr_num,
    output [31:0] wb_csr_wdata,
    output [31:0] wb_csr_wmask, 

    output        wb_ertn,
    output        wb_allow_in,
    output        wb_ready_go,
    output reg wb_valid
);
//====================== 异常编码 =====================//
assign wb_ertn     = ertn;
assign wb_ex       = wb_valid && (excp_syscall | excp_break |excp_ale | excp_adef |
                   | excp_ine | excp_ipe | has_int) ;
assign wb_ecode = has_int       ? 6'h00 :  // 中断(INT)
                  excp_adef     ? 6'h08 :  // 取指地址错(ADEF)
                  excp_ipe      ? 6'h0E :  // 指令特权等级错(IPE)
                  excp_ine      ? 6'h0D :  // 指令不存在(INE)
                  excp_ale      ? 6'h09 :  // 地址非对齐(ALE)
                  excp_syscall  ? 6'h0B :  // 系统调用(SYS)
                  excp_break    ? 6'h0C :  // 断点(BRK)
                  6'h00;                 

assign wb_esubcode = 9'h000;
assign wb_pc       = pc;

assign wb_csr_we   = wb_valid ? csr_we : 1'b0;
assign wb_csr_num  = csr_num;
assign wb_csr_wdata = csr_wdata;
assign wb_csr_wmask = csr_wmask;
assign wb_rf_we    = wb_valid ? rf_we : 4'b0;
assign wb_rf_waddr = rf_waddr;
assign wb_rf_wdata = rf_wdata;
assign wb_sram_we = data_sram_we;
assign wb_sram_wdata = data_sram_wdata;
assign wb_sram_addr = data_sram_addr;

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
