`timescale 1ns/1ps
module tb_mycpu;
    reg clk;
    reg resetn;
    reg [31:0] inst_mem [0:31];
    reg [31:0] data_mem [0:31];
    wire [31:0] inst_sram_addr;
    wire        inst_sram_en;
    wire [3:0]  inst_sram_we;
    wire [31:0] inst_sram_wdata;
    reg  [31:0] inst_sram_rdata;
    wire [31:0] data_sram_addr;
    wire [3:0]  data_sram_en;
    wire        data_sram_we;
    wire [31:0] data_sram_wdata;
    reg  [31:0] data_sram_rdata;
    wire [31:0] debug_wb_pc;
    wire [3:0]  debug_wb_rf_we;
    wire [31:0] debug_wb_rf_wnum;
    wire [31:0] debug_wb_rf_wdata;

    // 实例化CPU顶层
    mycpu_top uut (
        .clk(clk),
        .resetn(resetn),
        .inst_sram_rdata(inst_sram_rdata),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_wdata(inst_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    // 时钟生成
    initial clk = 0;
    always #5 clk = ~clk;

    // 指令和数据初始化
    initial begin
        resetn = 0;
        #20;
        resetn = 1;
    end

    // 指令存储器仿真（模拟SRAM延迟，确保PC和指令配对）
    // 说明：
    //   真实硬件中，PC变化后，指令存储器需要一个时钟周期才能输出新指令。
    //   这里用寄存器 inst_sram_rdata_reg 实现延迟，保证IF阶段的PC和inst_sram_rdata一一对应。
    //   如果直接用组合逻辑赋值，会导致PC和指令错位，影响流水线正确性。
    reg [31:0] inst_sram_rdata_reg;
    always @(posedge clk) begin
        if (inst_sram_en && inst_sram_we == 4'b0000)
            inst_sram_rdata_reg <= inst_mem[inst_sram_addr[6:2]]; // 取指令，延迟一个周期输出
        else
            inst_sram_rdata_reg <= 32'h0;
    end
    assign inst_sram_rdata = inst_sram_rdata_reg;

    // 数据存储器仿真（组合逻辑，简化实现）
    // 读：data_sram_en有效且data_sram_we为0时，输出对应内存数据
    // 写：data_sram_en有效且data_sram_we非0时，写入数据
    always @(*) begin
        if (data_sram_en != 0 && data_sram_we == 0)
            data_sram_rdata = data_mem[data_sram_addr[6:2]];
        else
            data_sram_rdata = 32'h0;
    end
    always @(posedge clk) begin
        if (data_sram_en != 0 && data_sram_we != 0)
            data_mem[data_sram_addr[6:2]] <= data_sram_wdata;
    end

    // 任务：输出寄存器写回
    // 每当有寄存器写回时，输出写回周期、PC、写寄存器号、写回数据，便于调试和结果判定
    always @(posedge clk) begin
        if (debug_wb_rf_we != 0)
            $display("[cycle %0d] WB: pc=%h, wnum=%d, wdata=%h", $time/10, debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata);
    end

    // 任务：输出关键信号
    // 可根据需要补充更多信号输出

    // =====================
    // 各类流水线时序问题测试样例
    // =====================
    // 1. Load-Use冒险
    //    lw r1, 0(r0) -> add r2, r1, r1
    //    检查load-use冒险时，add是否被正确暂停/前递，r2应为20。
    // 2. 前递冒险
    //    add r4, r1, r2 -> add r6, r2, r3
    //    检查EXE/MEM/WB前递是否正确，r4、r6应为正确前递结果。
    // 3. 分支取消
    //    add r4, r1, r0 -> beq r1, r0, +2 -> add r4, r1, r2(应被取消) -> add r6, r1, r3
    //    检查分支跳转后，流水线中错误指令是否被清除，r4应未被写入，r6应被写入。
    // 4. 写后读冒险
    //    add r4, r1, r0 -> add r8, r2, r0
    //    检查WB写回和ID读出时序是否冲突，r8应为正确结果。
    //
    // 每个测试点后，仿真结束时输出判定标准，便于快速定位问题类型。
    initial begin
        // 清空
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            inst_mem[i] = 32'h0;
            data_mem[i] = 32'h0;
        end
        // 数据初始化
        data_mem[0] = 32'h0000000a; // MEM[0] = 10
        // Load-Use
        inst_mem[0] = 32'h8c010000; // lw r1, 0(r0)
        inst_mem[1] = 32'h00210820; // add r2, r1, r1
        inst_mem[2] = 32'h00000000; // nop
        // 前递冒险
        inst_mem[4] = 32'h00220020; // add r4, r1, r2
        inst_mem[5] = 32'h00432020; // add r6, r2, r3
        // 分支取消
        inst_mem[8] = 32'h00200020; // add r4, r1, r0
        inst_mem[9] = 32'h10200002; // beq r1, r0, +2
        inst_mem[10] = 32'h00220020; // add r4, r1, r2 (应被取消)
        inst_mem[11] = 32'h00230020; // add r6, r1, r3
        // 写后读冒险
        inst_mem[16] = 32'h00200020; // add r4, r1, r0
        inst_mem[17] = 32'h00402020; // add r8, r2, r0
        // 结束
        inst_mem[20] = 32'h00000000; // nop
        #500;
        $display("\n==== 测试结果分析 ====");
        $display("1. Load-Use冒险: r2应为20, 若不为20则暂停/前递有bug");
        $display("2. 前递冒险: r4, r6应为正确前递结果, 若不对则前递有bug");
        $display("3. 分支取消: r4应未被写入, r6应被写入, 若r4被写入则分支取消有bug");
        $display("4. 写后读冒险: r8应为正确结果, 若不对则WB/ID时序有bug");
        $finish;
    end
endmodule 