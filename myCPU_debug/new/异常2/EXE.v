module EXE_stage(
    input        clk,
    input        reset,
    input        stall,
    input        flush,
    input [31:0] pc,
    input [17:0] alu_op,       
    input        data_sram_en,            
    input [31:0] data_sram_addr,
    input [31:0] data_sram_wdata,
    input [31:0] data_sram_rdata,
    input [3:0]  rf_we,        
    input [4:0]  rf_waddr, 
    input [31:0] rf_wdata,
    input [4:0]  rf_raddr1,
    input [4:0]  rf_raddr2,  
    input [3:0]  csr_we,
    input        csr_re,
    input [13:0] csr_num,
    input [31:0] csr_wdata,
    input [31:0] csr_wmask, 
    // 操作数输入
    input [32:0] alu_src1,      // ALU源操作数1
    input [32:0] alu_src2,      // ALU源操作数2
    // 前递输入
    input        ms_valid,
    input [3:0]  ms_sram_we,
    input [31:0] ms_sram_addr,
    input [31:0] ms_sram_wdata,
    input        wb_valid,
    input [3:0]  wb_sram_we,
    input [31:0] wb_sram_addr,
    input [31:0] wb_sram_wdata,

    input        ms_allow_in,
    input        to_es_valid,
    input [3:0]  mem_op,
    input        ertn,
    input        excp_syscall,
    input        excp_break,
    input        excp_ine,
    input        excp_ipe,
    input        excp_adef,
    input        has_int,  
    input        ale_op1,
    input        ale_op2,     
    
    output        es_ertn,
    output        es_excp_syscall,
    output        es_excp_ale,
    output        es_excp_ine,
    output        es_excp_ipe,
    output        es_excp_break,
    output        es_excp_adef,
    output        es_has_int,
    output [3:0]  es_mem_op,
    output [31:0] es_pc,
    output        div_valid,
    output [31:0] sram_rdata,
    output [31:0] sram_addr,  // 存储器地址
    output [31:0] sram_wdata, // 存储器写数据
    output [3:0]  es_rf_we,        // 寄存器堆写使能
    output [4:0]  es_rf_waddr,     // 寄存器写地址
    output [31:0] es_rf_wdata,
    output [3:0]  es_csr_we,
    output [13:0] es_csr_num,
    output [31:0] es_csr_wdata,
    output [31:0] es_csr_wmask, 

    output es_allow_in,
    output es_ready_go,
    output reg es_valid
);

wire [31:0]  loaded_data;
wire [31:0] alu_result;
wire [1:0]  saddr_ls = data_sram_addr[1:0];

wire is_ld_b = (mem_op == 4'b1000);
wire is_ld_h = (mem_op == 4'b1001);
wire is_ld_w = (mem_op == 4'b1010);
wire is_ld_bu = (mem_op == 4'b1100);
wire is_ld_hu = (mem_op == 4'b1101);

assign loaded_data = 
    is_ld_b ? (
        saddr_ls == 2'b00 ? { {24{sram_rdata[7]}}, sram_rdata[7:0] } :
        saddr_ls == 2'b01 ? { {24{sram_rdata[15]}}, sram_rdata[15:8] } :
        saddr_ls == 2'b10 ? { {24{sram_rdata[23]}}, sram_rdata[23:16] } :
                            { {24{sram_rdata[31]}}, sram_rdata[31:24] }
    ) :
    is_ld_h ? (
        saddr_ls == 2'b00 ? { {16{sram_rdata[15]}}, sram_rdata[15:0] } :
        saddr_ls == 2'b01 ? { {16{sram_rdata[23]}}, sram_rdata[23:8] } : // 非对齐访问
        saddr_ls == 2'b10 ? { {16{sram_rdata[31]}}, sram_rdata[31:16] } :
                            { {16{sram_rdata[31]}}, sram_rdata[31:24], sram_rdata[7:0] } // 非对齐
    ) :
    is_ld_bu ? (
        saddr_ls == 2'b00 ? { 24'b0, sram_rdata[7:0] } :
        saddr_ls == 2'b01 ? { 24'b0, sram_rdata[15:8] } :
        saddr_ls == 2'b10 ? { 24'b0, sram_rdata[23:16] } :
                            { 24'b0, sram_rdata[31:24] }
    ) :
    is_ld_hu ? (
        saddr_ls == 2'b00 ? { 16'b0, sram_rdata[15:0] } :
        saddr_ls == 2'b01 ? { 16'b0, sram_rdata[15:8], 8'b0 } : // 非对齐
        saddr_ls == 2'b10 ? { 16'b0, sram_rdata[31:16] } :
                            { 16'b0, sram_rdata[31:24], 8'b0 } // 非对齐
    ) :
    sram_rdata; // 默认情况

// sram 前递
assign sram_rdata = (ms_sram_we && (ms_sram_addr == data_sram_addr) && ms_valid) ? ms_sram_wdata : 
                    (wb_sram_we && (wb_sram_addr == data_sram_addr) && wb_valid) ? wb_sram_wdata : 
                    data_sram_rdata;

alu u_alu(
    .clk        (clk),
    .reset      (reset),
    .flush      (flush),
    .alu_op     (alu_op),
    .alu_src1   (alu_src1),   
    .alu_src2   (alu_src2),  
    .alu_result (alu_result),
    .div_valid  (div_valid)
);
// 组合逻辑输出
assign es_pc           = pc;
assign sram_en         = es_valid ? data_sram_en : 1'b0;
assign sram_addr       = data_sram_addr; 
assign sram_wdata      = data_sram_wdata;
assign es_rf_we        = rf_we;
assign es_rf_waddr     = rf_waddr;
assign es_rf_wdata     = csr_re ? rf_wdata : 
                         data_sram_en ? loaded_data : alu_result;
assign es_csr_we       = csr_we;
assign es_csr_num      = csr_num;
assign es_csr_wdata    = csr_wdata;
assign es_csr_wmask    = csr_wmask; 
assign es_mem_op       = es_valid ? mem_op : 4'b0;
assign es_ertn         = ertn;
assign es_excp_syscall = excp_syscall;  
assign es_excp_ale     = ale_op1 && (data_sram_addr[0] & 1'b0)
                       | ale_op2 && (data_sram_addr[1] | data_sram_addr[0]);
assign es_excp_break   = excp_break;
assign es_excp_ine     = excp_ine;
assign es_excp_ipe     = excp_ipe;
assign es_excp_adef    = excp_adef;
assign es_has_int      = has_int;
always @(posedge clk) begin
    if (reset || flush) begin
        es_valid <= 1'b0;
    end
    else if (stall && !(es_valid && !div_valid)) begin 
        es_valid <= 1'b0;
    end
    else if (es_allow_in) begin
        es_valid <= to_es_valid; 
    end
end

// 流水线控制
assign es_to_ms_valid = to_es_valid ;
assign es_ready_go = reset ? 1'b1 : div_valid;
assign es_allow_in = !es_valid || ms_allow_in && es_ready_go;

endmodule

module MEM_reg (
    input        clk,
    input        reset,
    input        flush,
    input        es_ready_go,
    input        ms_allow_in,
    input [31:0] EXE_pc,
    input [31:0] EXE_sram_addr,
    input [31:0] EXE_sram_wdata,
    input [31:0] EXE_sram_rdata,
    input [3:0]  EXE_rf_we,
    input [4:0]  EXE_rf_waddr,
    input [31:0] EXE_rf_wdata,
    input [3:0]  EXE_csr_we,
    input [13:0] EXE_csr_num,
    input [31:0] EXE_csr_wdata,
    input [31:0] EXE_csr_wmask, 
    input [3:0]  EXE_mem_op,
    input        EXE_ertn,
    input        EXE_excp_syscall,
    input        EXE_excp_break,
    input        EXE_excp_ale,
    input        EXE_excp_ine,
    input        EXE_excp_ipe,
    input        EXE_excp_adef,
    input        EXE_has_int, 

    output reg [3:0]  MEM_mem_op,
    output reg [31:0] MEM_sram_rdata,
    output reg [31:0] MEM_pc,       
    output reg [31:0] MEM_sram_addr,
    output reg [31:0] MEM_sram_wdata,   
    output reg [3:0]  MEM_rf_we,
    output reg [4:0]  MEM_rf_waddr,
    output reg [31:0] MEM_rf_wdata,
    output reg [3:0]  MEM_csr_we,
    output reg [13:0] MEM_csr_num,
    output reg [31:0] MEM_csr_wdata,
    output reg [31:0] MEM_csr_wmask,
    output reg        MEM_ertn,
    output reg        MEM_excp_syscall,
    output reg        MEM_excp_break,
    output reg        MEM_excp_ale,
    output reg        MEM_excp_ine,
    output reg        MEM_excp_ipe,
    output reg        MEM_excp_adef,
    output reg        MEM_has_int    
);
    
always @(posedge clk) begin
    if(reset || flush) begin
        MEM_pc         <= 32'h1c000000;
        MEM_sram_addr  <= 32'b0;
        MEM_sram_wdata <= 32'b0;
        MEM_sram_rdata <= 32'b0;
        MEM_rf_we      <= 4'b0;
        MEM_rf_waddr   <= 5'b0;
        MEM_rf_wdata   <= 32'b0;
        MEM_csr_we     <= 4'b0;
        MEM_csr_num    <= 14'b0;
        MEM_csr_wdata  <= 32'b0;
        MEM_csr_wmask  <= 32'b0; 
        MEM_mem_op     <= 4'b0; 
        MEM_ertn       <= 1'b0;
        MEM_excp_syscall <= 1'b0; 
        MEM_excp_break <= 1'b0;
        MEM_excp_ale   <= 1'b0;
        MEM_excp_ine   <= 1'b0;
        MEM_excp_ipe   <= 1'b0;
        MEM_excp_adef  <= 1'b0;
        MEM_has_int    <= 1'b0;          
    end
    else if (es_ready_go && ms_allow_in) begin
        MEM_pc         <= EXE_pc;
        MEM_sram_rdata <= EXE_sram_rdata;
        MEM_sram_addr  <= EXE_sram_addr;
        MEM_sram_wdata <= EXE_sram_wdata;
        MEM_rf_we      <= EXE_rf_we;
        MEM_rf_waddr   <= EXE_rf_waddr;
        MEM_rf_wdata   <= EXE_rf_wdata;
        MEM_csr_we     <= EXE_csr_we;
        MEM_csr_num    <= EXE_csr_num;
        MEM_csr_wdata  <= EXE_csr_wdata;
        MEM_csr_wmask  <= EXE_csr_wmask;
        MEM_mem_op     <= EXE_mem_op;
        MEM_ertn       <= EXE_ertn;
        MEM_excp_syscall <= EXE_excp_syscall;
        MEM_excp_ale   <= EXE_excp_ale;
        MEM_excp_break <= EXE_excp_break;
        MEM_excp_ine   <= EXE_excp_ine;
        MEM_excp_ipe   <= EXE_excp_ipe;
        MEM_excp_adef  <= EXE_excp_adef;
        MEM_has_int    <= EXE_has_int;
    end
end
endmodule