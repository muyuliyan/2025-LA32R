module MEM_stage(
    input        clk,
    input        reset,
    input        flush,
    input [31:0] pc,
    input [31:0] data_sram_wdata,     
    input [31:0] data_sram_addr,
    input [3:0]  rf_we,         
    input [4:0]  rf_waddr,   
    input [31:0] rf_wdata,
    input [3:0]  csr_we,
    input [13:0] csr_num,
    input [31:0] csr_wdata,
    input [4:0]  csr_wmask,  
    input        wb_allow_in,
    input        to_ms_valid,
    input        div_valid,
    input        ertn,
    input        syscall,
    input [14:0] syscall_code,
    input [3:0]  mem_op,
    
    output [31:0] ms_pc,
    // 输出到MEM/WB寄存器的信号
    output [3:0]  ms_rf_we,        
    output [4:0]  ms_rf_waddr,      
    output [31:0] ms_rf_wdata, 
    output [3:0]  sram_we,   
    output [31:0] sram_addr, 
    output [31:0] sram_wdata,
    output [3:0]  ms_csr_we, 
    output [13:0] ms_csr_num,
    output [31:0] ms_csr_wdata,
    output [4:0]  ms_csr_wmask,  

    output        ms_ertn,
    output        ms_syscall,
    output [14:0] ms_syscall_code,
    output ms_allow_in,
    output ms_ready_go,
    output reg ms_valid
);
wire is_st_b = (mem_op == 4'b0100);
wire is_st_h = (mem_op == 4'b0101);
wire is_st_w = (mem_op == 4'b0110);
wire [1:0] saddr_ls = data_sram_addr[1:0];

wire [3:0] final_sram_we = is_st_b ? (saddr_ls == 2'b00 ? 4'b0001 : 
        saddr_ls == 2'b01 ? 4'b0010 : saddr_ls == 2'b10 ? 4'b0100 : 
        4'b1000 ):
                           is_st_h ? (saddr_ls == 2'b00 ? 4'b0011 : 4'b1100) :
                           is_st_w ? 4'b1111 : 4'b0000;

assign sram_we      = div_valid ? (ms_valid ? final_sram_we : 4'b0) : 4'b0;
assign sram_addr    = data_sram_addr;
assign sram_wdata   = data_sram_wdata;
assign ms_rf_wdata  = rf_wdata;
assign ms_rf_we     = rf_we;
assign ms_rf_waddr  = rf_waddr;
assign ms_csr_num   = csr_num;
assign ms_csr_wdata = csr_wdata;
assign ms_csr_wmask = csr_wmask; 
assign ms_ertn      = ertn;
assign ms_syscall   = syscall;
assign ms_syscall_code =syscall_code;

always @(posedge clk) begin
    if(reset || flush) begin
        ms_valid <= 1'b0;
    end
    else if(~div_valid) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allow_in) begin
        ms_valid <= to_ms_valid;
    end
end

assign ms_pc       = pc;
assign ms_ready_go = 1'b1; 
assign ms_allow_in = !ms_valid || ms_ready_go && wb_allow_in;
endmodule

module WB_reg (
    input        clk,
    input        reset,
    input        flush,
    input        ms_ready_go,
    input        wb_allow_in,
    input [31:0] MEM_pc,
    input [3:0]  MEM_rf_we,
    input [4:0]  MEM_rf_waddr,
    input [31:0] MEM_rf_wdata,
    input [3:0]  MEM_csr_we,
    input [13:0] MEM_csr_num,
    input [31:0] MEM_csr_wdata,
    input [4:0]  MEM_csr_wmask,
    input        MEM_ertn,
    input        MEM_syscall,
    input [14:0] MEM_syscall_code, 

    output reg [31:0] WB_pc, 
    output reg [3:0]  WB_rf_we,
    output reg [4:0]  WB_rf_waddr,
    output reg [31:0] WB_rf_wdata,
    output reg [3:0]  WB_csr_we,
    output reg [13:0] WB_csr_num,
    output reg [31:0] WB_csr_wdata,
    output reg [4:0]  WB_csr_wmask,
    output reg        WB_ertn,
    output reg        WB_syscall,
    output reg [14:0] WB_syscall_code
);
    
always @(posedge clk) begin
    if(reset || flush) begin
        WB_pc        <= 32'h1c000000;
        WB_rf_we     <= 4'b0;
        WB_rf_waddr  <= 5'b0;
        WB_rf_wdata  <= 32'b0;
        WB_csr_we    <= 4'b0;
        WB_csr_num   <= 14'b0;
        WB_csr_wdata <= 32'b0;
        WB_csr_wmask <= 5'b0; 
        WB_ertn      <= 1'b0;
        WB_syscall   <= 1'b0;
        WB_syscall_code <= 15'b0;
    end
    else if (ms_ready_go && wb_allow_in) begin
        WB_pc        <= MEM_pc;
        WB_rf_we     <= MEM_rf_we;
        WB_rf_waddr  <= MEM_rf_waddr;
        WB_rf_wdata  <= MEM_rf_wdata;
        WB_csr_we    <= MEM_csr_we;
        WB_csr_num   <= MEM_csr_num;
        WB_csr_wdata <= MEM_csr_wdata;
        WB_csr_wmask <= MEM_csr_wmask; 
        WB_ertn      <= MEM_ertn;
        WB_syscall   <= MEM_syscall;
        WB_syscall_code <= MEM_syscall_code;
    end
end

endmodule