module ID_stage(
    input        clk,           
    input        reset,         
    input [31:0] pc,            
    input [31:0] inst,  
    input        flush,        
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
    input [4:0]  ms_rf_waddr,    // MEM阶段写地址
    input [31:0] ms_rf_wdata,    // MEM阶段写数据
    input        wb_valid,
    input [3:0]  wb_rf_we,         // WB阶段寄存器写使能
    input [4:0]  wb_rf_waddr,      // WB阶段寄存器写地址
    input [31:0] wb_rf_wdata,      // WB阶段写回数据
    // csr寄存器接口
    input  [31:0] csr_rdata,      // CSR读取值

    output [3:0]  csr_we,
    output        csr_re,          // CSR读使能
    output [13:0] csr_num,         // CSR读地址
    output [4:0]  csr_wmask,
    output [31:0] csr_wdata,
    output [31:0] ds_pc,
    // 分支/跳转信号
    output        br_taken_cancel,
    output [31:0] br_target,      // 分支目标地址
    // 寄存器读地址
    output [4:0]  rf_raddr1,     // 寄存器读地址1
    output [4:0]  rf_raddr2,     // 寄存器读地址2
    // 需要传递到下一流水线
    output [32:0] alu_src1,
    output [32:0] alu_src2,
    output [17:0] alu_op,
    output [31:0] data_sram_wdata,
    output        data_sram_en,
    output [31:0] data_sram_addr,
    output [3:0]  rf_we,
    output [4:0]  rf_waddr,
    output [31:0] rf_wdata_csr,

    output        ertn,
    output        syscall,
    output [14:0] syscall_code, 
    output        ds_allow_in,   
    output        ds_ready_go,
    output reg [3:0] mem_op,
    output reg    ds_valid
);

// 指令字段解码
wire [5:0] op_31_26 = inst[31:26];
wire [7:0] op_31_24 = inst[31:24];
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
wire inst_sll_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h0e); 
wire inst_srl_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h0f); 
wire inst_sra_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h10); 
wire inst_mul_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h18);
wire inst_mulh_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h19);
wire inst_mulh_wu = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h1) & (op_19_15 == 5'h1a);
wire inst_div_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h2) & (op_19_15 == 5'h00);
wire inst_mod_w   = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h2) & (op_19_15 == 5'h01);
wire inst_div_wu  = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h2) & (op_19_15 == 5'h02);
wire inst_mod_wu  = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h2) & (op_19_15 == 5'h03);
wire inst_addi_w  = (op_31_26 == 6'h00) & (op_25_22 == 4'ha);
wire inst_slti    = (op_31_26 == 6'h00) & (op_25_22 == 4'h8);   
wire inst_sltui   = (op_31_26 == 6'h00) & (op_25_22 == 4'h9);   
wire inst_andi    = (op_31_26 == 6'h00) & (op_25_22 == 4'hd);   
wire inst_ori     = (op_31_26 == 6'h00) & (op_25_22 == 4'he);   
wire inst_xori    = (op_31_26 == 6'h00) & (op_25_22 == 4'hf);   
wire inst_ld_w    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h2);
wire inst_ld_b    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h0);  // ld.b
wire inst_ld_h    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h1);  // ld.h
wire inst_ld_bu   = (op_31_26 == 6'h0a) & (op_25_22 == 4'h8);  // ld.bu
wire inst_ld_hu   = (op_31_26 == 6'h0a) & (op_25_22 == 4'h9);  // ld.hu
wire inst_st_b    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h4);  // st.b
wire inst_st_h    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h5);  // st.h
wire inst_st_w    = (op_31_26 == 6'h0a) & (op_25_22 == 4'h6);
wire inst_jirl    = (op_31_26 == 6'h13);
wire inst_b       = (op_31_26 == 6'h14);
wire inst_bl      = (op_31_26 == 6'h15);
wire inst_beq     = (op_31_26 == 6'h16);
wire inst_bne     = (op_31_26 == 6'h17);
wire inst_blt     = (op_31_26 == 6'h18);  // 有符号小于
wire inst_bge     = (op_31_26 == 6'h19);  // 有符号大于等于
wire inst_bltu    = (op_31_26 == 6'h1a);  // 无符号小于
wire inst_bgeu    = (op_31_26 == 6'h1b);  // 无符号大于等于
wire inst_pcaddu12i = (op_31_26 == 6'h07) & ~inst[25]; 
wire inst_lu12i_w = (op_31_26 == 6'h05) & ~inst[25];

wire inst_csrrd   = (op_31_24 == 8'h04) & (rj == 5'h00);
wire inst_csrwr   = (op_31_24 == 8'h04) & (rj == 5'h01);
wire inst_csrxchg = (op_31_24 == 8'h04) & (rj != 5'h00) & (rj != 5'h01);
wire inst_ertn    = (op_31_26 == 6'h01) & (op_25_22 == 4'h9) & (op_21_20 == 'h2) &
                    (op_19_15 == 5'h10) & (inst[14:0] == 15'h3800);
wire inst_syscall = (op_31_26 == 6'h00) & (op_25_22 == 4'h0) & (op_21_20 == 2'h2) & (op_19_15 == 5'h16); 
    
// 辅助信号
wire need_ui5        = inst_slli_w | inst_srli_w | inst_srai_w;
wire need_si12       = inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui
                       | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu
                       | inst_st_b | inst_st_h;
wire need_ui12       = inst_andi | inst_ori | inst_xori;
wire need_si16       = inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
wire need_si20       = inst_lu12i_w | inst_pcaddu12i;
wire need_si26       = inst_b | inst_bl;
wire need_sign_ext   = inst_mul_w | inst_mulh_w;  // 需要符号扩展的乘法
wire need_csr        = inst_csrrd;  // CSR指令需要读CSR
wire src2_is_4       = inst_jirl | inst_bl;
wire src_reg_is_rd   =  inst_st_w | inst_st_b | inst_st_h | 
                        inst_beq | inst_bne | inst_blt | inst_bge | 
                        inst_bltu | inst_bgeu| inst_csrwr | inst_csrxchg;
wire src1_is_pc      = inst_jirl | inst_bl | inst_pcaddu12i;
wire dst_is_r1       = inst_bl;
wire is_imm          = inst_slli_w | inst_srli_w | inst_srai_w | 
                       inst_addi_w | inst_ld_w | inst_st_w | 
                       inst_lu12i_w | inst_jirl | inst_bl | inst_b |
                       inst_slti | inst_sltui | inst_andi | inst_ori | 
                       inst_xori | inst_pcaddu12i | inst_ld_b | 
                       inst_ld_h | inst_ld_bu | inst_ld_hu |
                       inst_st_b | inst_st_h | inst_csrrd; 
wire is_mul          = inst_mul_w | inst_mulh_w | inst_mulh_wu;
    
// 寄存器读地址选择
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

// 立即数生成
wire [31:0] imm = 
    need_csr  ? csr_rdata :    // CSR值作为特殊"立即数"
    need_si20 ? {i20[19:0], 12'b0} : // lui12i_w
    need_ui5  ? {27'b0, inst[14:10]} : 
    need_si12 ? {{20{i12[11]}}, i12} : // 符号扩展
    need_ui12 ? {20'b0, i12} : 
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
    
assign br_taken_cancel = ds_valid ? (inst_beq && rj_eq_rd) || (inst_bne && !rj_eq_rd)
                         || inst_bl || inst_jirl || inst_b || 
                         (inst_blt  && ($signed(rf_rdata1_forward) < $signed(rf_rdata2_forward))) ||
                         (inst_bge  && ($signed(rf_rdata1_forward) >= $signed(rf_rdata2_forward))) ||
                         (inst_bltu && (rf_rdata1_forward < rf_rdata2_forward)) ||
                         (inst_bgeu && (rf_rdata1_forward >= rf_rdata2_forward))
                         : 1'b0;
                          
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b || 
                   inst_blt || inst_bge || inst_bltu || inst_bgeu) ? (pc + br_offs) : 
                      inst_jirl ? (rf_rdata1_forward + jirl_offs) : 32'b0;
    
// ALU 操作数选择
wire [31:0] src1 = src1_is_pc ? pc : rf_rdata1_forward;
wire [31:0] src2 = is_imm ? imm : rf_rdata2_forward;
assign alu_src1 = need_sign_ext ? {{src1[31]}, src1[31:0]} : {{1'b0}, src1[31:0]};
assign alu_src2 = need_sign_ext ? {{src2[31]}, src2[31:0]} : {{1'b0}, src2[31:0]};
    
// ALU 操作码生成
assign alu_op[0]  = inst_add_w | inst_addi_w | inst_ld_w | inst_ld_b | 
                    inst_ld_bu | inst_ld_h | inst_ld_hu | 
                    inst_st_w | inst_st_b | inst_st_h | inst_jirl | inst_bl |
                    inst_pcaddu12i | inst_csrrd;
assign alu_op[1]  = inst_sub_w;
assign alu_op[2]  = inst_slt | inst_slti;
assign alu_op[3]  = inst_sltu | inst_sltui;
assign alu_op[4]  = inst_and | inst_andi;
assign alu_op[5]  = inst_nor;
assign alu_op[6]  = inst_or | inst_ori;
assign alu_op[7]  = inst_xor | inst_xori;
assign alu_op[8]  = inst_slli_w | inst_sll_w;   // 左移
assign alu_op[9]  = inst_srli_w | inst_srl_w;   // 逻辑右移
assign alu_op[10] = inst_srai_w | inst_sra_w;   // 算术右移
assign alu_op[11] = inst_lu12i_w;
assign alu_op[12] = inst_mulh_w | inst_mulh_wu; 
assign alu_op[13] = inst_mul_w;
assign alu_op[14] = inst_div_w;    
assign alu_op[15] = inst_mod_w;    // 有符号取模
assign alu_op[16] = inst_div_wu;   // 无符号除法
assign alu_op[17] = inst_mod_wu;   // 无符号取模
    
// 加载存储操作码
// 内存操作类型编码
// [3]: 1=加载 0=存储, [2:0]: 类型
always @(*) begin
    if (inst_ld_b)       mem_op = 4'b1000; // 加载-字节
    else if (inst_ld_h)  mem_op = 4'b1001; // 加载-半字
    else if (inst_ld_w)  mem_op = 4'b1010; // 加载-字
    else if (inst_ld_bu) mem_op = 4'b1100; // 加载-无符号字节
    else if (inst_ld_hu) mem_op = 4'b1101; // 加载-无符号半字

    else if (inst_st_b)  mem_op = 4'b0100; // 存储-字节
    else if (inst_st_h)  mem_op = 4'b0101; // 存储-半字
    else if (inst_st_w)  mem_op = 4'b0110; // 存储-字
    else mem_op = 4'b0000; // 非内存操作
end

// 控制信号生成
assign data_sram_en = ds_valid ? (inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu | 
                                  inst_st_w | inst_st_b | inst_st_h) : 1'b0;
assign data_sram_addr = alu_src1 + alu_src2;

// st_data
wire [31:0] st_data = inst_st_b ? {4{rf_rdata2_forward[7:0]}} :
                      inst_st_h ? {2{rf_rdata2_forward[15:0]}} :
                                     rf_rdata2_forward[31:0];
assign data_sram_wdata = st_data;

// 通用寄存器使能地址
assign rf_we =  {4{!(inst_st_w | inst_st_b | inst_st_h | 
                    inst_beq | inst_bne | inst_b | 
                    inst_blt | inst_bge | inst_bltu | inst_bgeu)}};
assign rf_waddr = dst_is_r1 ? 5'd1 : rd;
assign rf_wdata_csr = csr_rdata;

// CSR使能地址
assign csr_we = ds_valid & (inst_csrwr | inst_csrxchg);
assign csr_re = ds_valid & (inst_csrrd | inst_csrwr | inst_csrxchg);
assign csr_num = inst[23:10];
assign csr_wmask = rj; 
assign csr_wdata = rf_rdata2_forward;

always @(posedge clk) begin
    if(reset || flush) begin
        ds_valid <= 1'b1;
    end
    else if (br_taken_cancel) begin
        ds_valid <= 1'b0;
    end
    else if(ds_allow_in) begin
        ds_valid <= to_ds_valid;
    end   
end

assign syscall_code = inst_syscall ? inst[14:0] : 15'b0; 
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
    input ds_ready_go,
    input es_allow_in,
    input flush,
    input [4:0] ID_rf_raddr1,
    input [4:0] ID_rf_raddr2,
    input [31:0] ID_pc,
    input [32:0] ID_alu_src1,
    input [32:0] ID_alu_src2,
    input [17:0] ID_alu_op,
    input        ID_sram_en,
    input [31:0] ID_sram_addr,
    input [31:0] ID_sram_wdata,
    input [3:0]  ID_rf_we,
    input [4:0]  ID_rf_waddr,
    input [31:0] ID_rf_wdata,
    input [3:0]  ID_mem_op,
    input        ID_csr_we,
    input        ID_csr_re,    
    input [13:0] ID_csr_num,       // CSR读地址
    input [4:0]  ID_csr_wmask,
    input [31:0] ID_csr_wdata,
    input        ID_ertn,
    input        ID_syscall,
    input [14:0] ID_syscall_code, 

    output reg [4:0]  EXE_rf_raddr1,
    output reg [4:0]  EXE_rf_raddr2,
    output reg [31:0] EXE_pc,
    output reg [32:0] EXE_alu_src1,
    output reg [32:0] EXE_alu_src2,
    output reg [17:0] EXE_alu_op,        // ALU操作码
    output reg        EXE_sram_en,       // 内存使能
    output reg [31:0] EXE_sram_wdata,
    output reg [31:0] EXE_sram_addr,
    output reg [3:0]  EXE_rf_we,         // 寄存器堆写使能
    output reg [4:0]  EXE_rf_waddr,      // 寄存器写地址
    output reg [31:0] EXE_rf_wdata,
    output reg [3:0]  EXE_mem_op,
    output reg [3:0]  EXE_csr_we,        
    output reg        EXE_csr_re,
    output reg [13:0] EXE_csr_num,
    output reg [4:0]  EXE_csr_wmask,
    output reg [31:0] EXE_csr_wdata,
    output reg        EXE_ertn,
    output reg        EXE_syscall,
    output reg [14:0] EXE_syscall_code
);
    // ================== 寄存器更新逻辑 ==================
    always @(posedge clk) begin
        if (reset || flush) begin
            EXE_pc        <= 32'h1c000000;
            EXE_alu_src1  <= 33'b0;
            EXE_alu_src2  <= 33'b0;
            EXE_alu_op    <= 18'b0;
            EXE_sram_en   <= 1'b0;
            EXE_sram_addr <= 32'b0;
            EXE_sram_wdata<= 32'b0;
            EXE_rf_we     <= 4'b0;
            EXE_rf_waddr  <= 5'b0;
            EXE_rf_wdata  <= 32'b0;
            EXE_rf_raddr1 <= 5'b0;
            EXE_rf_raddr2 <= 5'b0;
            EXE_mem_op    <= 4'b0;
            EXE_csr_we    <= 4'b0;
            EXE_csr_re    <= 1'b0;
            EXE_csr_num   <= 14'b0;
            EXE_csr_wmask <= 5'b0;
            EXE_csr_wdata <= 31'b0;
            EXE_ertn      <= 1'b0;
            EXE_syscall   <= 1'b0;
            EXE_syscall_code <= 15'b0;
            
        end
        else if(ds_ready_go && es_allow_in) begin
            EXE_pc        <= ID_pc;
            EXE_alu_src1  <= ID_alu_src1;
            EXE_alu_src2  <= ID_alu_src2;
            EXE_alu_op    <= ID_alu_op;
            EXE_sram_en   <= ID_sram_en;
            EXE_sram_addr <= ID_sram_addr;
            EXE_sram_wdata<= ID_sram_wdata;
            EXE_rf_we     <= ID_rf_we;
            EXE_rf_waddr  <= ID_rf_waddr;
            EXE_rf_wdata  <= ID_rf_wdata;
            EXE_rf_raddr1 <= ID_rf_raddr1;
            EXE_rf_raddr2 <= ID_rf_raddr2;
            EXE_mem_op    <= ID_mem_op;
            EXE_csr_we    <= ID_csr_we;
            EXE_csr_re    <= ID_csr_re;
            EXE_csr_num   <= ID_csr_num;
            EXE_csr_wmask <= ID_csr_wmask;
            EXE_csr_wdata <= ID_csr_wdata;
            EXE_ertn      <= ID_ertn;
            EXE_syscall   <= ID_syscall;
            EXE_syscall_code <= ID_syscall_code;
        end
    end
endmodule 