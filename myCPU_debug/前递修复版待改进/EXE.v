module EXE_stage(
    input        clk,
    input        reset,
    input        stall,
    input [31:0] pc,
    input [11:0] alu_op,       
    input        data_sram_en,       
    input [3:0]  data_sram_we,       
    input [31:0] data_sram_addr,
    input [31:0] data_sram_wdata,
    input [31:0] data_sram_rdata,
    input [3:0]  rf_we,        
    input [4:0]  rf_waddr, 
    input [4:0]  rf_raddr1,
    input [4:0]  rf_raddr2,   
    
    // 操作数输入
    input [31:0] alu_src1,      // ALU源操作数1
    input [31:0] alu_src2,      // ALU源操作数2

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

    output [31:0] es_pc,

    output [3:0]  sram_we,    // 存储器写使能
    output [31:0] sram_addr,  // 存储器地址
    output [31:0] sram_wdata, // 存储器写数据
    output [3:0]  es_rf_we,        // 寄存器堆写使能
    output [4:0]  es_rf_waddr,     // 寄存器写地址
    output [31:0] es_rf_wdata,

    output es_allow_in,
    output es_ready_go,
    output reg es_valid
);

// reg es_valid;
wire [31:0] alu_result;
wire [31:0] sram_rdata;

// sram 前递
assign sram_rdata = (ms_sram_we && (ms_sram_addr == data_sram_addr) && ms_valid) ? ms_sram_wdata : 
                    (wb_sram_we && (wb_sram_addr == data_sram_addr) && wb_valid) ? wb_sram_wdata : 
                    data_sram_rdata;
// wire [31:0] alu_src1_forward;
// wire [31:0] alu_src2_forward;

// ALU源操作数1前递选择
// assign alu_src1_forward =
//     (ms_rf_we && (ms_rf_waddr != 0) && (ms_rf_waddr == rf_raddr1) && ms_valid) ? ms_rf_wdata :
//     (wb_rf_we  && (wb_rf_waddr  != 0) && (wb_rf_waddr  == rf_raddr1) && wb_valid) ? wb_rf_wdata  :
//     alu_src1;
// ALU源操作数2前递选择
// assign alu_src2_forward = 
//     (ms_rf_we && (ms_rf_waddr != 0) && (ms_rf_waddr == rf_raddr2) && ms_valid) ? ms_rf_wdata :
//     (wb_rf_we  && (wb_rf_waddr  != 0) && (wb_rf_waddr  == rf_raddr2 && wb_valid)) ? wb_rf_wdata  :
//     alu_src2;

alu u_alu(
    .alu_op     (alu_op),
    .alu_src1   (alu_src1),   
    .alu_src2   (alu_src2),  
    .alu_result (alu_result)
);
// 组合逻辑输出
assign es_pc           = pc;
assign sram_en         = es_valid ? data_sram_en : 1'b0;
assign sram_we         = es_valid ? data_sram_we : 4'b0;
assign sram_addr       = alu_result; 
assign sram_wdata      = data_sram_wdata;
assign es_rf_we        = rf_we;
assign es_rf_waddr     = rf_waddr;
assign es_rf_wdata     = data_sram_en ? sram_rdata : alu_result;

always @(posedge clk) begin
    if (reset || stall) begin
        es_valid <= 1'b0;
    end
    else if (es_allow_in) begin
       es_valid <= to_es_valid; 
    end
end

// 流水线控制
assign es_to_ms_valid = to_es_valid ;
assign es_ready_go = 1'b1;
assign es_allow_in = !es_valid || ms_allow_in && es_ready_go;

endmodule

module MEM_reg (
    input        clk,
    input        reset,
    input        es_ready_go,
    input        ms_allow_in,
    // input        EXE_valid,
    input [31:0] EXE_pc,
    input [3:0]  EXE_sram_we,
    input [31:0] EXE_sram_addr,
    input [31:0] EXE_sram_wdata,
    input [3:0]  EXE_rf_we,
    input [4:0]  EXE_rf_waddr,
    input [31:0] EXE_rf_wdata,

    // output reg        MEM_valid,
    output reg [31:0] MEM_pc, 
    output reg [3:0]  MEM_sram_we,       
    output reg [31:0] MEM_sram_addr,
    output reg [31:0] MEM_sram_wdata,   
    output reg [3:0]  MEM_rf_we,
    output reg [4:0]  MEM_rf_waddr,
    output reg [31:0] MEM_rf_wdata      
);
    
always @(posedge clk) begin
    if(reset) begin
        // MEM_valid      <= 1'b0;
        MEM_pc         <= 32'h1c000000;
        MEM_sram_we    <= 4'b0;
        MEM_sram_addr  <= 32'b0;
        MEM_sram_wdata <= 32'b0;
        MEM_rf_we      <= 4'b0;
        MEM_rf_waddr   <= 5'b0;
        MEM_rf_wdata <= 32'b0;
    end
    else if (es_ready_go && ms_allow_in) begin
        // MEM_valid      <= EXE_valid;
        MEM_pc         <= EXE_pc;
        MEM_sram_we    <= EXE_sram_we;
        MEM_sram_addr  <= EXE_sram_addr;
        MEM_sram_wdata <= EXE_sram_wdata;
        MEM_rf_we      <= EXE_rf_we;
        MEM_rf_waddr   <= EXE_rf_waddr;
        MEM_rf_wdata   <= EXE_rf_wdata;
    end
end
endmodule