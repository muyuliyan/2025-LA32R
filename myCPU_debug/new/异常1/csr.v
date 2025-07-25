`include "myCPU.vh"
module csr(
    input         clk,
    input         reset,

    // CSR读写接口
    input         csr_re,
    input  [13:0] csr_rnum, 
    input  [13:0] csr_wnum,
    output [31:0] csr_rdata,
    input  [3:0]  csr_we,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wdata,
    // ertn指令接口
    input         ertn_flush,           // ertn指令执行信号
    // 异常输入
    input         wb_ex,          // 异常发生标志
    input  [5:0]  wb_ecode,       // 异常编码
    input  [8:0]  wb_esubcode,    // 异常子编码
    input  [31:0] wb_pc,          // 异常指令PC
    // 中断控制信号
    // input         ext_int,        // 外部中断
    // input         timer_int,      // 定时器中断
    // // 系统控制输出
    // output        int_enable,     // 全局中断使能
    output [31:0] ex_entry       // 异常入口地址
);

// ================== 寄存器定义 ==================
reg [1:0]  csr_crmd_plv;
reg        csr_crmd_ie;
wire       csr_crmd_da;
wire       csr_crmd_pg;
wire       csr_crmd_datf;
wire       csr_crmd_datm;
reg [1:0]  csr_prmd_pplv;
reg        csr_prmd_pie;
reg [1:0]  csr_estat_is;
reg [5:0]  csr_estat_ecode;
reg [8:0]  csr_estat_esubcode;
reg [31:0] csr_era_pc;
reg [25:0] csr_eentry_va;
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;

// 简化中断检测（仅依赖全局中断使能）
// wire int_pending = |estat_is && crmd_ie;
// ================== 寄存器写入逻辑 ==================
// CRMD的PLV、IE
always @(posedge clk) begin
    if(reset) begin 
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if(wb_ex) begin 
        csr_crmd_plv <= 2'b0;
        csr_crmd_ie <= 1'b0;
    end
    else if(ertn_flush) begin 
        csr_crmd_plv <= csr_prmd_pplv; 
        csr_crmd_ie <= csr_prmd_pie;
    end
    else if(csr_we && csr_wnum == `CSR_CRMD) begin
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wdata[`CSR_CRMD_PLV]
                     | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wdata[`CSR_CRMD_IE]
                    | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
    end
end
// CRMD的DA、PG、DATF、DATM（还未实现内存管理总线）
assign csr_crmd_da = 1'b1;
assign csr_crmd_pg = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;

// PRMD的PPLV、PIE
always @(posedge clk) begin
    if (wb_ex) begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie; 
    end
    else if (csr_we && csr_wnum == `CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wdata[`CSR_PRMD_PPLV]
                      | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wmask[`CSR_PRMD_PIE] & csr_wdata[`CSR_PRMD_PIE]
                      | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

// ESTAT的Ecode、EsubCode
always @(posedge clk) begin
    if(wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

// ERA的PC
always @(posedge clk) begin
    if(wb_ex)
        csr_era_pc <= wb_pc;
    else if(csr_we && csr_wnum == `CSR_ERA)
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wdata[`CSR_ERA_PC]
                   | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end

// EENTRY的VA
always @(posedge clk) begin
    if (reset) 
        csr_eentry_va <= 26'b0;
    if(csr_we && csr_wnum == `CSR_EENTRY)
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wdata[`CSR_EENTRY_VA]
                      | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end

// SAVE0~3
always @(posedge clk) begin
    if(csr_we && csr_wnum == `CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wdata[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save0_data;
    if(csr_we && csr_wnum == `CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wdata[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save1_data;
    if(csr_we && csr_wnum == `CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wdata[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save2_data;
    if(csr_we && csr_wnum == `CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA] & csr_wdata[`CSR_SAVE_DATA]
                       | ~csr_wmask[`CSR_SAVE_DATA] & csr_save3_data;
end

// ================== CSR读取逻辑 ==================
wire [31:0] csr_crmd = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie , csr_crmd_plv};
wire [31:0] csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 16'b0};
wire [31:0] csr_era = csr_era_pc;
wire [31:0] csr_eentry = {csr_eentry_va, 6'b0};

assign ex_entry    = csr_eentry;
assign csr_rdata =  (csr_rnum[13:0] == `CSR_CRMD)   ? csr_crmd   :
                    (csr_rnum[13:0] == `CSR_PRMD)   ? csr_prmd   :
                    (csr_rnum[13:0] == `CSR_ESTAT)  ? csr_estat  :
                    (csr_rnum[13:0] == `CSR_ERA)    ? csr_era    :
                    (csr_rnum[13:0] == `CSR_EENTRY) ? csr_eentry :
                    (csr_rnum[13:0] == `CSR_SAVE0)  ? csr_save0_data :
                    (csr_rnum[13:0] == `CSR_SAVE1)  ? csr_save1_data :
                    (csr_rnum[13:0] == `CSR_SAVE2)  ? csr_save2_data :
                    (csr_rnum[13:0] == `CSR_SAVE3)  ? csr_save3_data : 32'h0;
endmodule