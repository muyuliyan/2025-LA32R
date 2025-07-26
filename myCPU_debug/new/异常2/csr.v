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
    input  [7:0]  interrupt,
    // 异常输入
    input         wb_ex,          // 异常发生标志
    input  [5:0]  wb_ecode,       // 异常编码
    input  [8:0]  wb_esubcode,    // 异常子编码
    input  [31:0] wb_pc,          // 异常指令PC
    output        csr_plv,
    output        has_int,
    output [63:0] timer_64_out,
    output [31:0] csr_tid_out,
    output [31:0] ertn_pc,
    output [31:0] excp_pc       // 异常入口地址
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
reg [12:0] csr_ecfg_lie;
reg [1:0]  csr_estat_is;
reg [5:0]  csr_estat_ecode;
reg [8:0]  csr_estat_esubcode;
reg [31:0] csr_era_pc;
reg [31:0] csr_badv_vaddr;
reg [25:0] csr_eentry_va;
reg [31:0] csr_save0_data;
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;
reg [31:0] csr_tid_tid;
reg        csr_tcfg_en;
reg        csr_tcfg_periodic;
reg [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;
reg [31:0] timer_cnt;
reg [63:0] timer_64;

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

// ECFG的LIE域
always @(posedge clk) begin
    if(reset) 
        csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_wnum == `CSR_ECFG)
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wdata[`CSR_ECFG_LIE]
                      | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
end

// always @(posedge clk) begin
//     if (reset) begin
//         // 初始化 estat 的部分字段
//         csr_estat[ 1: 0] <= 2'b0;     // 保留位初始化为 0
// 		csr_estat[10]    <= 1'b0;     // 软件中断位初始化为 0
// 		csr_estat[12]    <= 1'b0;     // 保留位初始化为 0
//         csr_estat[15:13] <= 3'b0;     // 保留位初始化为 0
//         csr_estat[31]    <= 1'b0;     // 保留位初始化为 0
        
//         timer_en <= 1'b0;             // 定时器使能初始化为 0
//     end
//     else begin
//         if (ticlr_wen && wr_data[`CLR]) begin
//             // 如果 TICK 中断清除有效
//             csr_estat[11] <= 1'b0;    // 清除 TICK 中断
//         end
//         else if (tcfg_wen) begin
//             // 如果定时器配置写使能有效
//             timer_en <= wr_data[`EN]; // 更新定时器使能状态
//         end
//         else if (timer_en && (csr_tval == 32'b0)) begin
//             // 如果定时器使能且计数器值为 0
//             csr_estat[11] <= 1'b1;    // 触发 TICK 中断
//             timer_en      <= csr_tcfg[`PERIODIC];  // 如果是周期模式，重启定时器
//         end
//         csr_estat[9:2] <= interrupt;  // 更新外部中断状态
//         if (excp_flush) begin
//             // 如果异常 flush，更新异常码和子码
//             csr_estat[   `ECODE] <= ecode_in;      // 写入新的异常码
//             csr_estat[`ESUBCODE] <= esubcode_in;   // 写入新的子异常码
//         end
//         else if (estat_wen) begin
//             // 如果写使能 estat 有效，写入新的异常状态
//             csr_estat[      1:0] <= wr_data[      1:0];  // 写入新的保留位
//         end
//     end
// end
// ESTAT的IS
always @(posedge clk) begin
    if(reset) begin
        csr_estat_is[1:0] <= 2'b0;
        csr_estat_is[9:2] <= 8'b0;
        csr_estat_is[10]  <= 1'b0;
        csr_estat_is[12]  <= 1'b0;
    end
    else begin
        if (csr_we && csr_wnum == `CSR_ESTAT) begin
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wdata[`CSR_ESTAT_IS10]
                              | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0];
        end else begin
            csr_estat_is[1:0] <= csr_estat_is[1:0]; // 显式保持
        end
        csr_estat_is[9:2] <= interrupt; // 或保持原设计 interrupt[7:0]
        csr_estat_is[10] <= 1'b0;
        if (csr_we && csr_wnum == `CSR_TICLR && 
            csr_wmask[`CSR_TICLR_CLR] && csr_wdata[`CSR_TICLR_CLR]) 
        begin
            csr_estat_is[11] <= 1'b0;
        end
        else if (timer_cnt[31:0] == 32'b0) begin
            csr_estat_is[11] <= 1'b1;
        end
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

// BADV的VAddr
wire wb_ex_addr_err;
assign wb_ex_addr_err = (wb_ecode == `ECODE_ADE) || (wb_ecode == `ECODE_ALE);
always @(posedge clk) begin
    if (wb_ex && wb_ex_addr_err) begin
        csr_badv_vaddr <= (wb_ecode == `ECODE_ADE &&
        wb_esubcode == `ESUBCODE_ADEF) & wb_pc;
    end
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

// TID
always @(posedge clk) begin
    if(reset)
        csr_tid_tid <= 32'b0;
    else if (csr_we && csr_wnum == `CSR_TID) begin
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wdata[`CSR_TID_TID]
                    | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    end
end

// TCFG的En、Periodic和InitVal
always @(posedge clk) begin
    if(reset)
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_wnum == `CSR_TCFG) begin
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wdata[`CSR_TCFG_EN]
                    | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    end
    if(csr_we && csr_wnum == `CSR_TCFG) begin
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wdata[`CSR_TCFG_PERIOD]
                          | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITVAL] & csr_wdata[`CSR_TCFG_INITVAL]
                          | ~csr_wmask[`CSR_TCFG_INITVAL] & csr_tcfg_initval;
    end     
end

// TVAL的TimeVal
assign tcfg_next_value = csr_wmask[31:0] & csr_wdata[31:0]
                       | ~csr_wmask[31:0] & {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};
always @(posedge clk) begin
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_wnum==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];

// TICLR
assign csr_ticlr_clr = 1'b0;

//timer_64
wire is_full = & timer_64;
always @(posedge clk) begin
   if (reset || is_full) begin
     timer_64 <= 64'b0;
   end else begin
     timer_64 <= timer_64 + 1'b1;
   end
end
assign timer_64_out = timer_64;
assign csr_tid_out = csr_tid_tid;
// ================== CSR读取逻辑 ==================
wire [31:0] csr_crmd = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie , csr_crmd_plv};
wire [31:0] csr_prmd = {29'b0, csr_prmd_pie, csr_prmd_pplv};
wire [31:0] csr_estat = {1'b0, csr_estat_esubcode, csr_estat_ecode, 16'b0};
wire [31:0] csr_era = csr_era_pc;
wire [31:0] csr_eentry =  {csr_eentry_va, 6'b0};

assign csr_plv = csr_crmd[`CSR_CRMD_PLV];
assign has_int = (|(csr_estat_is & csr_ecfg_lie)) & csr_crmd_ie;
assign excp_pc = csr_eentry;
assign ertn_pc = csr_era;
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
