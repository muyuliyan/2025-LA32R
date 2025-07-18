module ID_stage(
    input        clk,           
    input        reset,         
    input [31:0] pc,            
    input [31:0] inst,          
    input        stall, 
    input        to_ds_valid,     
    input        es_allow_in,      
    input [31:0] rf_rdata1,
    input [31:0] rf_rdata2,
    // 前递信息传递
    input        es_valid,
    input [3:0]  es_rf_we,      
    input [4:0]  es_rf_waddr,   
    input [31:0] es_rf_wdata,
    input        ms_valid,
    input [3:0]  ms_rf_we,       // MEM阶段写使能
    input [4:0]  ms_rf_waddr,   // MEM阶段写地址
    input [31:0] ms_rf_wdata,   // MEM阶段写数据
    input        wb_valid,
    input [3:0]  wb_rf_we,         // WB阶段寄存器写使能
    input [4:0]  wb_rf_waddr,      // WB阶段寄存器写地址
    input [31:0] wb_rf_wdata,      // WB阶段写回数据
    
    output [31:0] ds_pc,
    // 分支/跳转信号
    output        br_taken_cancel,
    output [31:0] br_target,      // 分支目标地址
    
    // 寄存器读地址
    output [4:0]  rf_raddr1,     // 寄存器读地址1
    output [4:0]  rf_raddr2,     // 寄存器读地址2
    
    // 需要传递到下一流水线
    output [31:0] alu_src1,
    output [31:0] alu_src2,
    output [11:0] alu_op,
    output [31:0] data_sram_wdata,
    output        data_sram_en,
    output [3:0]  data_sram_we,
    output [31:0] data_sram_addr,

    output [3:0]  rf_we,
    output [4:0]  rf_waddr,

    output ds_allow_in,   
    output ds_ready_go,
    output  reg ds_valid
);


// 指令字段解码
wire [5:0] op_31_26 = inst[31:26];
wire [3:0] op_25_22 = inst[25:22];
wire [1:0] op_21_20 = inst[21:20];
wire [4:0] op_19_15 = inst[19:15];
wire [4:0] rd       = inst[4:0];
wire [4:0] rj       = inst[9:5];
wire [4:0] rk       = inst[14:10];
    
// 立即数字段
wire [11:0] i12 = inst[21:10];
wire [19:0] i20 = inst[24:5];
wire [15:0] i16 = inst[25:10];
wire [25:0] i26 = {inst[9:0], inst[25:10]};
    
// 指令识别
wire inst_add_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h00);
wire inst_sub_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h02);
wire inst_slt     = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h04);
wire inst_sltu    = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h05);
wire inst_nor     = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h08);
wire inst_and     = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h09);
wire inst_or      = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h0a);
wire inst_xor     = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h0b);
wire inst_slli_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'h1) & (op_21_20 == 2'h0) & (op_19_15 == 5'h01);
wire inst_srli_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'h1) & (op_21_20 == 2'h0) & (op_19_15 == 5'h09);
wire inst_srai_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'h1) & (op_21_20 == 2'h0) & (op_19_15 == 5'h11);
wire inst_addi_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'ha);
wire inst_ld_w    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h2);
wire inst_st_w    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h6);
wire inst_jirl    = (op_31_26 == 6'h13);
wire inst_b       = (op_31_26 == 6'h14);
wire inst_bl      = (op_31_26 == 6'h15);
wire inst_beq     = (op_31_26 == 6'h16);
wire inst_bne     = (op_31_26 == 6'h17);
wire inst_lu12i_w = (op_31_26 == 6'h05) & ~inst[25];
    
// 辅助信号
wire need_ui5      = inst_slli_w | inst_srli_w | inst_srai_w;
wire need_si12     = inst_addi_w | inst_ld_w | inst_st_w;
wire need_si16     = inst_jirl | inst_beq | inst_bne;
wire need_si20     = inst_lu12i_w;
wire need_si26     = inst_b | inst_bl;
wire src2_is_4     = inst_jirl | inst_bl;
wire src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
wire src1_is_pc    = inst_jirl | inst_bl;
wire dst_is_r1     = inst_bl;
wire is_imm        = inst_slli_w | inst_srli_w | inst_srai_w | 
                     inst_addi_w | inst_ld_w | inst_st_w | 
                     inst_lu12i_w | inst_jirl | inst_bl | inst_b;
    
// 寄存器读地址选择
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;
    
// 立即数生成
wire [31:0] imm = 
    need_si20 ? {i20[19:0], 12'b0} : // lui12i_w
    need_ui5  ? {27'b0, inst[14:10]} : 
    need_si12 ? {{20{i12[11]}}, i12} : // 符号扩展
    need_si16 ? {{16{i16[15]}}, i16} : // 符号扩展
    src2_is_4 ? 32'h4 : 
    32'b0;

// 分支偏移量计算
wire [31:0] br_offs = need_si26 ? {{4{i26[25]}}, i26, 2'b0} : 
                                  {{14{i16[15]}}, i16, 2'b0};
    
wire [31:0] jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
    
// 寄存器前递逻辑
wire [31:0] rf_rdata1_forward = 
    (es_valid && es_rf_we && (es_rf_waddr != 0) && (es_rf_waddr == rf_raddr1)) ? es_rf_wdata :
    (ms_valid && ms_rf_we && (ms_rf_waddr != 0) && (ms_rf_waddr == rf_raddr1)) ? ms_rf_wdata :
    (wb_rf_we && (wb_rf_waddr != 0) && (wb_rf_waddr == rf_raddr1) && wb_valid) ? wb_rf_wdata :
    rf_rdata1;

wire [31:0] rf_rdata2_forward = 
    (es_valid && es_rf_we && (es_rf_waddr != 0) && (es_rf_waddr == rf_raddr2)) ? es_rf_wdata :
    (ms_valid && ms_rf_we && (ms_rf_waddr != 0) && (ms_rf_waddr == rf_raddr2)) ? ms_rf_wdata :
    (wb_rf_we && (wb_rf_waddr != 0) && (wb_rf_waddr == rf_raddr2) && wb_valid) ? wb_rf_wdata :
    rf_rdata2;

// 分支判断
wire rj_eq_rd = (rf_rdata1_forward == rf_rdata2_forward);
    
assign br_taken_cancel = ds_valid ? (inst_beq && rj_eq_rd) ||
                         (inst_bne && !rj_eq_rd) || inst_bl || inst_jirl ||
                          inst_b : 1'b0;
    
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc + br_offs) : 
                      inst_jirl ? (rf_rdata1_forward + jirl_offs) : 32'b0;
    
// ALU 操作数选择
assign alu_src1 = src1_is_pc ? pc : rf_rdata1_forward;
assign alu_src2 = is_imm ? imm : rf_rdata2_forward;
    
// ALU 操作码生成
assign alu_op[0]  = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl;
assign alu_op[1]  = inst_sub_w;
assign alu_op[2]  = inst_slt;
assign alu_op[3]  = inst_sltu;
assign alu_op[4]  = inst_and;
assign alu_op[5]  = inst_nor;
assign alu_op[6]  = inst_or;
assign alu_op[7]  = inst_xor;
assign alu_op[8]  = inst_slli_w;
assign alu_op[9]  = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;
    
// 控制信号生成
assign data_sram_en = ds_valid ? inst_ld_w : 1'b0;
assign data_sram_we = {4{inst_st_w}};
assign data_sram_addr = alu_src1 + alu_src2;
assign data_sram_wdata = rf_rdata2_forward;
assign rf_we =  {4{!(inst_st_w | inst_beq | inst_bne | inst_b)}};
assign rf_waddr = dst_is_r1 ? 5'd1 : rd;
    
always @(posedge clk) begin
    if(reset) begin
        ds_valid <= 1'b1;
    end
    else if (br_taken_cancel) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allow_in) begin
        ds_valid <= to_ds_valid;
    end   
end

assign ds_pc = pc;
assign ds_ready_go = !stall;
assign ds_allow_in = !ds_valid || es_allow_in && ds_ready_go;

always @(posedge clk) begin
    $display("[ID_stage] br_offs=%h",
             br_offs);
end
endmodule

module EXE_reg (
    input clk,
    input reset,
    input stall,
    input ds_ready_go,
    input es_allow_in,
    // input ID_valid,
    input [4:0] ID_rf_raddr1,
    input [4:0] ID_rf_raddr2,
    input [31:0] ID_pc,
    input [31:0] ID_alu_src1,
    input [31:0] ID_alu_src2,
    input [11:0] ID_alu_op,
    input        ID_sram_en,
    input [3:0]  ID_sram_we,
    input [31:0] ID_sram_addr,
    input [31:0] ID_sram_wdata,
    input [3:0]  ID_rf_we,
    input [4:0]  ID_rf_waddr,
    
    // output reg EXE_valid,
    output reg [4:0]  EXE_rf_raddr1,
    output reg [4:0]  EXE_rf_raddr2,
    output reg [31:0] EXE_pc,
    output reg [31:0] EXE_alu_src1,
    output reg [31:0] EXE_alu_src2,
    output reg [11:0] EXE_alu_op,        // ALU操作码
    output reg        EXE_sram_en,       // 内存使能
    output reg [3:0]  EXE_sram_we,       // 存储器写使能
    output reg [31:0] EXE_sram_wdata,
    output reg [31:0] EXE_sram_addr,
    output reg [3:0]  EXE_rf_we,         // 寄存器堆写使能
    output reg [4:0]  EXE_rf_waddr       // 寄存器写地址
);
    // ================== 寄存器更新逻辑 ==================
    always @(posedge clk) begin
        if (reset) begin
            // EXE_valid     <= 1'b0;
            EXE_pc        <= 32'h1c000000;
            EXE_alu_src1  <= 32'b0;
            EXE_alu_src2  <= 32'b0;
            EXE_alu_op    <= 12'b0;
            EXE_sram_en   <= 1'b0;
            EXE_sram_we   <= 4'b0;
            EXE_sram_addr <= 32'b0;
            EXE_sram_wdata<= 32'b0;
            EXE_rf_we     <= 4'b0;
            EXE_rf_waddr  <= 5'b0;
            EXE_rf_raddr1 <= 5'b0;
            EXE_rf_raddr2 <= 5'b0;
        end
        else if(ds_ready_go && es_allow_in) begin
            EXE_pc        <= ID_pc;
            EXE_alu_src1  <= ID_alu_src1;
            EXE_alu_src2  <= ID_alu_src2;
            EXE_alu_op    <= ID_alu_op;
            EXE_sram_en   <= ID_sram_en;
            EXE_sram_we   <= ID_sram_we;
            EXE_sram_addr <= ID_sram_addr;
            EXE_sram_wdata<= ID_sram_wdata;
            EXE_rf_we     <= ID_rf_we;
            EXE_rf_waddr  <= ID_rf_waddr;
            EXE_rf_raddr1 <= ID_rf_raddr1;
            EXE_rf_raddr2 <= ID_rf_raddr2;
        end
    end
endmodule 