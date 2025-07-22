module trap_handler (
    input         clk,
    input         reset,
    
    // 流水线异常输入
    input         if_ex,          // IF阶段异常
    input  [5:0]  if_ecode,       // IF异常编码
    input  [31:0] if_badvaddr,    // IF出错地址
    input  [31:0] if_pc,          // IF阶段PC
    
    input         id_ex,          // ID阶段异常
    input  [5:0]  id_ecode,       // ID异常编码
    input  [31:0] id_badvaddr,    // ID出错地址
    input  [31:0] id_pc,          // ID阶段PC
    
    input         ex_ex,          // EXE阶段异常
    input  [5:0]  ex_ecode,       // EXE异常编码
    input  [31:0] ex_badvaddr,    // EXE出错地址
    input  [31:0] ex_pc,          // EXE阶段PC
    
    input         mem_ex,         // MEM阶段异常
    input  [5:0]  mem_ecode,      // MEM异常编码
    input  [31:0] mem_badvaddr,   // MEM出错地址
    input  [31:0] mem_pc,         // MEM阶段PC
    
    input         wb_ex,          // WB阶段异常
    input  [5:0]  wb_ecode,       // WB异常编码
    input  [31:0] wb_badvaddr,    // WB出错地址
    input  [31:0] wb_pc,          // WB阶段PC
    
    // 中断输入
    input         int_req,        // 中断请求
    input  [5:0]  int_cause,      // 中断原因编码
    input  [31:0] int_pc,         // 中断发生时PC
    
    // CSR接口
    input  [31:0] csr_rdata,      // CSR读取数据
    
    // 控制输出
    output        flush,          // 流水线刷新信号
    output [31:0] new_pc,         // 新PC值(异常入口地址)
    output [3:0]  csr_we,         // CSR写使能
    output [31:0] csr_addr,       // CSR地址
    output [31:0] csr_wdata,      // CSR写数据
    
    // 系统状态输出
    output        in_exception,   // 当前处于异常处理中
    output        ertn_executed   // 异常返回指令执行
);

// ================== 参数定义 ==================
// CSR地址定义
localparam CSR_CRMD    = 12'h000; // 当前模式信息
localparam CSR_PRMD    = 12'h001; // 异常前模式信息
localparam CSR_ECFG    = 12'h004; // 异常配置
localparam CSR_ESTAT   = 12'h005; // 异常状态
localparam CSR_ERA     = 12'h006; // 异常返回地址
localparam CSR_BADV    = 12'h007; // 出错地址
localparam CSR_EENTRY  = 12'h00c; // 异常入口地址

// ================== 寄存器定义 ==================
reg [1:0] state;                 // 状态机状态
reg [5:0] trap_ecode;            // 捕获的异常编码
reg [9:0] trap_esubcode;         // 捕获的异常子编码
reg [31:0] trap_pc;              // 捕获的异常PC
reg [31:0] trap_badvaddr;        // 捕获的出错地址
reg trap_type;                   // 0=异常, 1=中断

// ================== 状态机定义 ==================
localparam IDLE        = 2'b00;  // 空闲状态
localparam HANDLE_TRAP = 2'b01;  // 处理异常/中断
localparam ERTN_WAIT   = 2'b10;  // 等待ertn指令完成

// ================== 异常优先级逻辑 ==================
// 异常优先级: WB > MEM > EXE > ID > IF > 中断
wire any_exception = wb_ex | mem_ex | ex_ex | id_ex | if_ex | int_req;

// 选择最高优先级的异常
always @(*) begin
    trap_ecode = 6'b0;
    trap_esubcode = 10'b0;
    trap_pc = 32'b0;
    trap_badvaddr = 32'b0;
    trap_type = 1'b0;
    
    if (wb_ex) begin
        trap_ecode = wb_ecode;
        trap_pc = wb_pc;
        trap_badvaddr = wb_badvaddr;
        trap_type = 1'b0; // 异常
    end
    else if (mem_ex) begin
        trap_ecode = mem_ecode;
        trap_pc = mem_pc;
        trap_badvaddr = mem_badvaddr;
        trap_type = 1'b0; // 异常
    end
    else if (ex_ex) begin
        trap_ecode = ex_ecode;
        trap_pc = ex_pc;
        trap_badvaddr = ex_badvaddr;
        trap_type = 1'b0; // 异常
    end
    else if (id_ex) begin
        trap_ecode = id_ecode;
        trap_pc = id_pc;
        trap_badvaddr = id_badvaddr;
        trap_type = 1'b0; // 异常
    end
    else if (if_ex) begin
        trap_ecode = if_ecode;
        trap_pc = if_pc;
        trap_badvaddr = if_badvaddr;
        trap_type = 1'b0; // 异常
    end
    else if (int_req) begin
        trap_ecode = int_cause;
        trap_pc = int_pc;
        trap_type = 1'b1; // 中断
    end
end

// ================== 状态机控制 ==================
reg [31:0] prmd_save; // 保存的PRMD值
reg [31:0] era_save;  // 保存的ERA值

always @(posedge clk or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        prmd_save <= 32'b0;
        era_save <= 32'b0;
    end else begin
        case (state)
            IDLE: begin
                if (any_exception) begin
                    state <= HANDLE_TRAP;
                    // 保存当前状态
                    prmd_save <= csr_rdata; // 假设读取的是CRMD
                    era_save <= trap_pc;
                end
            end
            
            HANDLE_TRAP: begin
                // 处理完成后返回空闲状态
                state <= IDLE;
            end
            
            ERTN_WAIT: begin
                // 等待ertn指令完成
                state <= IDLE;
            end
        endcase
    end
end

// ================== 输出控制逻辑 ==================
assign flush = (state == HANDLE_TRAP); // 处理异常时刷新流水线
assign new_pc = {csr_rdata[31:2], 2'b0}; // EENTRY地址(低2位为0)

// CSR写控制
assign csr_we = (state == HANDLE_TRAP) ? 4'b1111 : 4'b0000;
assign csr_addr = (state == HANDLE_TRAP) ? CSR_PRMD : 12'b0;
assign csr_wdata = prmd_save; // 写入PRMD

// 系统状态
assign in_exception = (state != IDLE);
assign ertn_executed = (state == ERTN_WAIT);

// ================== 异常处理时序 ==================
/*
1. 检测到异常或中断
2. 进入HANDLE_TRAP状态
3. 刷新流水线(flush=1)
4. 设置新PC为EENTRY(new_pc)
5. 写PRMD保存先前状态
6. 同时更新以下CSR寄存器:
   - ESTAT: 记录异常原因
   - ERA: 保存返回地址
   - BADV: 保存出错地址(如果是地址异常)
   - CRMD: 更新当前特权级和中断使能
*/

endmodule