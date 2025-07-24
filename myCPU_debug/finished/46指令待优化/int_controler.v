module int_controller (
    input         clk,
    input         reset,          // 低电平复位
    
    // 中断输入信号
    input  [7:0]  ext_irq,        // 外部中断信号 (8个)
    input         timer_irq,      // 定时器中断信号
    
    // CSR接口
    input         mie,            // 全局中断使能 (来自CSR_CRMD)
    input  [12:0] ecfg_lie,       // 本地中断使能 (来自CSR_ECFG)
    output [12:0] estat_is,       // 中断待处理状态 (输出到CSR_ESTAT)
    
    // 中断控制信号
    output        int_req,        // 中断请求
    output [5:0]  int_cause,      // 中断原因编码
    output [31:0] int_pc,         // 中断发生时PC值
    
    // 流水线控制接口
    input         wb_valid,       // WB阶段有效
    input  [31:0] wb_pc,          // WB阶段PC值
    input         flush,          // 流水线刷新信号
    input         ertn,           // 异常返回指令
    input         in_exception    // 当前处于异常处理中
);

// ================== 参数定义 ==================
// 中断原因编码 (根据龙芯架构手册)
localparam INT_EXT0   = 6'd0;      // 外部中断0
localparam INT_EXT1   = 6'd1;      // 外部中断1
localparam INT_TIMER  = 6'd11;     // 定时器中断

// ================== 寄存器定义 ==================
reg [7:0] ext_irq_sync;          // 同步后的外部中断
reg       timer_irq_sync;         // 同步后的定时器中断
reg [7:0] ext_irq_pending;        // 外部中断待处理状态
reg       timer_irq_pending;      // 定时器中断待处理状态
reg [31:0] int_pc_reg;            // 中断发生时PC值寄存器

// ================== 中断同步逻辑 ==================
// 同步外部中断信号（避免亚稳态）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ext_irq_sync <= 8'b0;
        timer_irq_sync <= 1'b0;
    end else begin
        ext_irq_sync <= ext_irq;
        timer_irq_sync <= timer_irq;
    end
end

// ================== 中断检测逻辑 ==================
// 检测中断信号上升沿
wire [7:0] ext_irq_rise = ext_irq_sync & ~{ext_irq_sync[7:1], ext_irq_sync[0]};
wire timer_irq_rise = timer_irq_sync & ~timer_irq_sync;

// 更新中断待处理状态
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ext_irq_pending <= 8'b0;
        timer_irq_pending <= 1'b0;
    end else if (flush || ertn) begin
        // 流水线刷新或异常返回时清除所有中断
        ext_irq_pending <= 8'b0;
        timer_irq_pending <= 1'b0;
    end else begin
        // 检测并记录新中断
        for (int i = 0; i < 8; i++) begin
            if (ext_irq_rise[i]) 
                ext_irq_pending[i] <= 1'b1;
        end
        
        if (timer_irq_rise)
            timer_irq_pending <= 1'b1;
    end
end

// ================== 中断优先级逻辑 ==================
// 组合中断待处理状态向量
// [0-7]: 外部中断0-7, [8]: 保留, [9]: 定时器中断
assign estat_is = {3'b0, timer_irq_pending, 1'b0, ext_irq_pending};

// 中断使能掩码
wire [12:0] int_enabled = estat_is & ecfg_lie;

// 中断优先级编码 (定时器 > 外部中断0 > 外部中断1 > ...)
wire has_timer_int = int_enabled[9];
wire has_ext_int   = |int_enabled[7:0];

// 生成中断原因编码
assign int_cause = has_timer_int ? INT_TIMER : 
                  has_ext_int   ? INT_EXT0 : 
                  6'b0; // 无中断

// ================== 中断请求逻辑 ==================
// 仅在以下条件下产生中断请求：
// 1. 全局中断使能 (mie)
// 2. 有待处理的中断
// 3. 当前未处于异常处理中
// 4. 流水线处于稳定状态 (WB阶段有效)
assign int_req = mie && (has_timer_int || has_ext_int) && 
                !in_exception && wb_valid;

// ================== 中断PC记录逻辑 ==================
// 当中断发生时，记录当前PC值
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        int_pc_reg <= 32'b0;
    end else if (int_req) begin
        int_pc_reg <= wb_pc;
    end
end

assign int_pc = int_pc_reg;

endmodule