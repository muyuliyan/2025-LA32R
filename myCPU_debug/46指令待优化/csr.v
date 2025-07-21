module csr (
    input         clk,
    input         reset,

    // CSR读写接口
    input         csr_re,
    input  [31:0] csr_num,
    output [31:0] csr_rvalue,
    input  [3:0]  csr_we,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wvalue,

    // 异常输入
    input         wb_ex,          // 异常发生标志
    input  [5:0]  wb_ecode,       // 异常编码
    input  [9:0]  wb_esubcode,    // 异常子编码
    input  [31:0] wb_pc,          // 异常指令PC
    input  [31:0] wb_badvaddr,    // 出错地址
    
    // 中断控制信号
    input         ext_int,        // 外部中断
    input         timer_int,      // 定时器中断
    
    // 系统控制输出
    output        int_enable,     // 全局中断使能
    output [31:0] eentry_addr,    // 异常入口地址
    output [31:0] era_addr,       // 异常返回地址
    output [1:0]  current_plv     // 当前特权级
);

// ================== CSR寄存器地址定义 ==================
localparam CSR_CRMD    = 12'h000; // 当前模式信息
localparam CSR_PRMD    = 12'h001; // 异常前模式信息
localparam CSR_ECFG    = 12'h004; // 异常配置
localparam CSR_ESTAT   = 12'h005; // 异常状态
localparam CSR_ERA     = 12'h006; // 异常返回地址
localparam CSR_BADV    = 12'h007; // 出错地址
localparam CSR_EENTRY  = 12'h00c; // 异常入口地址
localparam CSR_SAVE0   = 12'h030; // 上下文保存寄存器0
localparam CSR_SAVE1   = 12'h031; // 上下文保存寄存器1
localparam CSR_SAVE2   = 12'h032; // 上下文保存寄存器2
localparam CSR_SAVE3   = 12'h033; // 上下文保存寄存器3

// ================== 寄存器定义 ==================
reg [31:0] crmd;   // 当前模式信息
reg [31:0] prmd;   // 异常前模式信息
reg [31:0] ecfg;   // 异常配置
reg [31:0] estat;  // 异常状态
reg [31:0] era;    // 异常返回地址
reg [31:0] badv;   // 出错地址
reg [31:0] eentry; // 异常入口地址
reg [31:0] save0;  // 上下文保存寄存器
reg [31:0] save1;
reg [31:0] save2;
reg [31:0] save3;

// ================== 字段定义 ==================
// CRMD字段
wire [1:0] crmd_plv = crmd[1:0];   // 特权等级
wire       crmd_ie  = crmd[2];     // 中断使能

// ECFG字段
wire [12:0] ecfg_lie = ecfg[12:0]; // 本地中断使能

// ESTAT字段
reg  [12:0] estat_is; // 中断待处理状态
wire [5:0]  estat_ecode = estat[21:16];
wire [9:0]  estat_esubcode = estat[31:22];

// 中断检测
wire int_pending = |(estat_is & ecfg_lie) && crmd_ie;

// ================== 系统控制输出 ==================
assign int_enable  = crmd_ie;
assign eentry_addr = eentry;
assign era_addr    = era;
assign current_plv = crmd_plv;

// ================== 寄存器写入逻辑 ==================
always @(posedge clk) begin
    if (reset) begin
        // 复位初始化
        crmd   <= 32'b0;   // PLV=0, IE=0
        prmd   <= 32'b0;
        ecfg   <= 32'b0;
        estat  <= 32'b0;
        era    <= 32'b0;
        badv   <= 32'b0;
        eentry <= 32'hbfc00000; // 默认异常入口
        save0  <= 32'b0;
        save1  <= 32'b0;
        save2  <= 32'b0;
        save3  <= 32'b0;
        estat_is <= 13'b0;
    end
    else begin
        // 中断状态更新
        estat_is[11] <= ext_int;    // 外部中断
        estat_is[9]  <= timer_int;  // 定时器中断
        
        // 异常处理 - 优先级最高
        if (wb_ex || int_pending) begin
            // 保存当前状态到PRMD
            prmd <= {29'b0, crmd_ie, crmd_plv};
            
            // 更新ESTAT
            estat[31:16] <= wb_ex ? {wb_esubcode, wb_ecode} : 
                                      {10'b0, 6'h0}; // 中断编码0
            
            // 保存返回地址和出错地址
            era <= wb_pc;
            if (wb_ex) badv <= wb_badvaddr;
            
            // 更新CRMD：进入异常处理模式
            crmd[1:0] <= 2'b0; // 最高特权级
            crmd[2] <= 1'b0;   // 禁用中断
        end
        // CSR写操作
        else if (|csr_we) begin
            case (csr_num[11:0])
                CSR_CRMD: begin
                    if (csr_we[0]) crmd[7:0] <= (crmd[7:0] & ~csr_wmask[7:0]) | 
                                               (csr_wvalue[7:0] & csr_wmask[7:0]);
                end
                CSR_PRMD: begin
                    if (csr_we[0]) prmd[7:0] <= (prmd[7:0] & ~csr_wmask[7:0]) | 
                                               (csr_wvalue[7:0] & csr_wmask[7:0]);
                end
                CSR_ECFG: begin
                    if (csr_we[0]) ecfg[12:0] <= (ecfg[12:0] & ~csr_wmask[12:0]) | 
                                                (csr_wvalue[12:0] & csr_wmask[12:0]);
                end
                CSR_ESTAT: begin
                    // IS字段可写
                    if (csr_we[0]) estat[12:0] <= (estat[12:0] & ~csr_wmask[12:0]) | 
                                                 (csr_wvalue[12:0] & csr_wmask[12:0]);
                end
                CSR_ERA: begin
                    if (csr_we[0]) era[7:0]   <= (era[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) era[15:8]  <= (era[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) era[23:16] <= (era[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) era[31:24] <= (era[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_BADV: begin
                    if (csr_we[0]) badv[7:0]   <= (badv[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) badv[15:8]  <= (badv[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) badv[23:16] <= (badv[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) badv[31:24] <= (badv[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_EENTRY: begin
                    if (csr_we[0]) eentry[7:0]   <= (eentry[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) eentry[15:8]  <= (eentry[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) eentry[23:16] <= (eentry[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) eentry[31:24] <= (eentry[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_SAVE0: begin
                    if (csr_we[0]) save0[7:0]   <= (save0[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) save0[15:8]  <= (save0[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) save0[23:16] <= (save0[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) save0[31:24] <= (save0[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_SAVE1: begin
                    if (csr_we[0]) save1[7:0]   <= (save1[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) save1[15:8]  <= (save1[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) save1[23:16] <= (save1[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) save1[31:24] <= (save1[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_SAVE2: begin
                    if (csr_we[0]) save2[7:0]   <= (save2[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) save2[15:8]  <= (save2[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) save2[23:16] <= (save2[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) save2[31:24] <= (save2[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
                CSR_SAVE3: begin
                    if (csr_we[0]) save3[7:0]   <= (save3[7:0]   & ~csr_wmask[7:0]) | (csr_wvalue[7:0] & csr_wmask[7:0]);
                    if (csr_we[1]) save3[15:8]  <= (save3[15:8]  & ~csr_wmask[15:8]) | (csr_wvalue[15:8] & csr_wmask[15:8]);
                    if (csr_we[2]) save3[23:16] <= (save3[23:16] & ~csr_wmask[23:16]) | (csr_wvalue[23:16] & csr_wmask[23:16]);
                    if (csr_we[3]) save3[31:24] <= (save3[31:24] & ~csr_wmask[31:24]) | (csr_wvalue[31:24] & csr_wmask[31:24]);
                end
            endcase
        end
    end
end

// ================== CSR读取逻辑 ==================
reg [31:0] csr_rvalue_reg;
always @(*) begin
    case (csr_num[11:0])
        CSR_CRMD:   csr_rvalue_reg = crmd;
        CSR_PRMD:   csr_rvalue_reg = prmd;
        CSR_ECFG:   csr_rvalue_reg = ecfg;
        CSR_ESTAT:  csr_rvalue_reg = {estat[31:13], estat_is};
        CSR_ERA:    csr_rvalue_reg = era;
        CSR_BADV:   csr_rvalue_reg = badv;
        CSR_EENTRY: csr_rvalue_reg = eentry;
        CSR_SAVE0:  csr_rvalue_reg = save0;
        CSR_SAVE1:  csr_rvalue_reg = save1;
        CSR_SAVE2:  csr_rvalue_reg = save2;
        CSR_SAVE3:  csr_rvalue_reg = save3;
        default:    csr_rvalue_reg = 32'h0;
    endcase
end

assign csr_rvalue = csr_re ? csr_rvalue_reg : 32'b0;

endmodule