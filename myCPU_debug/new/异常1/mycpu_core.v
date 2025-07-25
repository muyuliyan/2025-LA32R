module mycpu_top (
    input          clk,
    input          resetn,
    // 指令存储器接口
    input  [31:0] inst_sram_rdata,
    output [31:0] inst_sram_addr,
    output        inst_sram_en,
    output [3:0]  inst_sram_we,
    output [31:0] inst_sram_wdata,
    // 数据存储器接口
    input  [31:0] data_sram_rdata,
    output        data_sram_en,
    output [3:0]  data_sram_we,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    // debug
    output [31:0] debug_wb_pc,
    output [3:0]  debug_wb_rf_we,
    output [31:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

// 慢一拍进入流水线
reg reset;
always @(posedge clk) begin
    reset <= ~resetn;
end

//======================= 模块间连接信号 =======================
    // pre_IF
    wire [31:0] pfs_pc;
    wire to_fs_valid;
    // IF
    wire [31:0] fs_pc;
    wire [31:0] inst;
    wire fs_ready_go;
    wire fs_to_ds_valid;
    // IF/ID reg
    wire pds_valid;
    wire [31:0] pds_inst;
    wire [31:0] pds_pc;
    // ID
    wire [31:0] ds_pc;
    wire [31:0] br_target;
    wire [32:0] ds_alu_src1;
    wire [32:0] ds_alu_src2;
    wire [17:0] ds_alu_op;
    wire        ds_sram_en;
    wire [3:0]  ds_sram_we;
    wire [31:0] ds_sram_addr;
    wire [31:0] ds_sram_wdata;
    wire [3:0]  ds_rf_we;
    wire [4:0]  ds_rf_waddr;
    wire [4:0]  ds_rf_raddr1;
    wire [4:0]  ds_rf_raddr2;
    wire [3:0]  ds_mem_op;
    wire ds_allow_in;
    wire ds_ready_go;
    wire ds_to_es_valid;
    // ID/EXE reg
    wire pes_valid;
    wire [4:0]  pes_rf_raddr1;
    wire [4:0]  pes_rf_raddr2;
    wire [31:0] pes_pc;
    wire [32:0] pes_alu_src1;
    wire [32:0] pes_alu_src2;
    wire [17:0] pes_alu_op;       
    wire pes_sram_en;       
    wire [3:0]  pes_sram_we;
    wire [31:0] pes_sram_addr;
    wire [31:0] pes_sram_wdata;
    wire [3:0]  pes_rf_we; 
    wire [4:0]  pes_rf_waddr; 
    wire [3:0]  pes_mem_op;
    // EXE
    wire [31:0] es_pc;
    wire es_sram_en;
    wire [3:0]  es_sram_we;    
    wire [31:0] es_sram_addr;  
    wire [31:0] es_sram_wdata;  
    wire [31:0] es_sram_rdata;   
    wire [3:0]  es_rf_we;       
    wire [4:0]  es_rf_waddr;     
    wire [31:0] es_rf_wdata;
    wire [3:0]  es_mem_op;
    wire es_allow_in;
    wire es_ready_go;
    wire es_to_ms_valid;
    wire div_valid;
    // EXE/MEM reg
    wire pms_valid;
    wire [31:0] pms_pc;
    wire pms_sram_en;
    wire [3:0]  pms_sram_we;       
    wire [31:0] pms_sram_addr;
    wire [31:0] pms_sram_wdata;
    wire [31:0] pms_sram_rdata; 
    wire [3:0]  pms_rf_we;         
    wire [4:0]  pms_rf_waddr;
    wire [31:0] pms_rf_wdata;
    wire [3:0]  pms_mem_op;
    // MEM
    wire [3:0]  ms_sram_we;
    wire [31:0] ms_sram_addr;
    wire [31:0] ms_sram_wdata;
    wire [31:0] ms_pc;
    wire [3:0]  ms_rf_we;        
    wire [4:0]  ms_rf_waddr;      
    wire [31:0] ms_rf_wdata; 
    wire ms_allow_in;
    wire ms_ready_go;
    wire ms_to_wb_valid;
    // MEM/WB reg
    wire pwb_valid;
    wire [31:0] pwb_pc; 
    wire [3:0]  pwb_sram_we;
    wire [31:0] pwb_sram_wdata;
    wire [31:0] pwb_sram_addr;
    wire [3:0]  pwb_rf_we;
    wire [4:0]  pwb_rf_waddr;
    wire [31:0] pwb_rf_wdata;
    // WB
    wire wb_valid;
    wire wb_allow_in;
    wire wb_ready_go;
    wire [3:0]  wb_sram_we;
    wire [31:0] wb_sram_addr;
    wire [31:0] wb_sram_wdata;
    wire [3:0]  wb_rf_we;        
    wire [4:0]  wb_rf_waddr;      
    wire [31:0] wb_rf_wdata; 
    // 全局控制信号
    wire br_taken_cancel;
    wire stall;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_raddr1;
    wire [31:0] rf_raddr2;
//======================= 模块实例化 =======================
    // 寄存器堆
    regfile u_regfile (
        .clk    (clk),
        .reset  (reset),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (wb_rf_we),
        .waddr  (wb_rf_waddr),
        .wdata  (wb_rf_wdata)
    );
    // int_controller u_irq_ctrl (
    //     .clk       (clk),
    //     .reset     (reset),
    //     .ext_irq   (irq_sync),
    //     .mie       (csr_rdata[3]),  // mstatus.MIE
    //     .int_req   (int_req),
    //     .int_cause (int_cause)
    // );
    // trap_handler u_trap_handler (
    //     .clk         (clk),
    //     .reset       (reset),
    //     // 流水线异常输入
    //     .if_ex       (if_exception),
    //     .id_ex       (id_exception),
    //     .ex_ex       (ex_exception),
    //     .mem_ex      (mem_exception),
    //     .wb_ex       (wb_exception),
    //     // 中断输入
    //     .int_req     (int_req),
    //     .int_cause   (int_cause),
    //     // CSR接口
    //     .csr_rdata   (csr_rdata),
    //     // 控制输出
    //     .flush       (flush),
    //     .new_pc      (new_pc),
    //     .csr_we      (csr_we),
    //     .csr_addr    (csr_addr),
    //     .csr_wdata   (csr_wdata)
    // );

//======================= 五级流水线 ========================
    // IF 阶段
    pre_IF_stage u_pre_IF(
        .clk             (clk),
        .reset           (reset),
        .br_taken_cancel (br_taken_cancel),
        .stall           (stall),
        .br_target       (br_target),

        .inst_sram_en    (inst_sram_en),
        .inst_sram_we    (inst_sram_we),
        .inst_sram_addr  (inst_sram_addr),
        .inst_sram_wdata (inst_sram_wdata),
        .pc              (pfs_pc),
        .to_fs_valid     (to_fs_valid)
    );
    IF_stage u_IF (
        .clk             (clk),
        .reset           (reset),
        .to_fs_valid     (to_fs_valid),
        .pc              (pfs_pc),
        .inst_sram_rdata (inst_sram_rdata),
        .ds_allow_in     (ds_allow_in),
        .br_taken_cancel (br_taken_cancel),
        .stall           (stall),

        .fs_pc           (fs_pc),
        .inst            (inst),  
        .fs_ready_go     (fs_ready_go),
        .fs_valid        (fs_to_ds_valid)
    );
    // IF/ID reg
    ID_reg u_ID_reg(
        .clk             (clk),
        .reset           (reset),
        .fs_ready_go     (fs_ready_go),
        .ds_allow_in     (ds_allow_in),
        .IF_pc           (fs_pc),
        .IF_inst         (inst),

        .ID_inst         (pds_inst),
        .ID_pc           (pds_pc)
    );
    // ID 阶段
    ID_stage u_ID (
        .clk             (clk),
        .reset           (reset),
        .pc              (pds_pc),
        .inst            (pds_inst),
        .stall           (stall),
        .to_ds_valid     (fs_to_ds_valid),
        .rf_rdata1       (rf_rdata1),  
        .rf_rdata2       (rf_rdata2), 
        .es_allow_in     (es_allow_in),
        // 前递 
        .es_valid        (es_to_ms_valid),
        .es_rf_we        (es_rf_we),       
        .es_rf_waddr     (es_rf_waddr),    
        .es_rf_wdata     (es_rf_wdata),
        .ms_valid        (ms_to_wb_valid),
        .ms_rf_we        (ms_rf_we),       
        .ms_rf_waddr     (ms_rf_waddr),    
        .ms_rf_wdata     (ms_rf_wdata),
        .wb_valid        (wb_valid),
        .wb_rf_we        (wb_rf_we), 
        .wb_rf_waddr     (wb_rf_waddr),      
        .wb_rf_wdata     (wb_rf_wdata),     
        
        .mem_op          (ds_mem_op),
        .ds_pc           (ds_pc),
        .br_taken_cancel (br_taken_cancel),
        .br_target       (br_target),
        .rf_raddr1       (ds_rf_raddr1),
        .rf_raddr2       (ds_rf_raddr2),
        .alu_src1        (ds_alu_src1),
        .alu_src2        (ds_alu_src2),
        .alu_op          (ds_alu_op),
        .data_sram_wdata (ds_sram_wdata),
        .data_sram_en    (ds_sram_en), 
        .data_sram_addr  (ds_sram_addr),
        .rf_we           (ds_rf_we),
        .rf_waddr        (ds_rf_waddr),
        .ds_allow_in     (ds_allow_in),
        .ds_ready_go     (ds_ready_go),
        .ds_valid        (ds_to_es_valid)
    );
    // ID/EXE reg
    EXE_reg u_EXE_reg(
        .clk             (clk),
        .reset           (reset),
        .ds_ready_go     (ds_ready_go),
        .es_allow_in     (es_allow_in),
        .ID_rf_raddr1    (ds_rf_raddr1),
        .ID_rf_raddr2    (ds_rf_raddr2),
        .ID_pc           (ds_pc),
        .ID_alu_src1     (ds_alu_src1),
        .ID_alu_src2     (ds_alu_src2),
        .ID_alu_op       (ds_alu_op),
        .ID_sram_wdata   (ds_sram_wdata),
        .ID_sram_en      (ds_sram_en),
        .ID_sram_addr    (ds_sram_addr),
        .ID_rf_we        (ds_rf_we),
        .ID_rf_waddr     (ds_rf_waddr),
        .ID_mem_op       (ds_mem_op),
        
        .EXE_mem_op      (pes_mem_op),
        .EXE_rf_raddr1   (pes_rf_raddr1),
        .EXE_rf_raddr2   (pes_rf_raddr2),
        .EXE_pc          (pes_pc),
        .EXE_alu_src1    (pes_alu_src1),
        .EXE_alu_src2    (pes_alu_src2),
        .EXE_alu_op      (pes_alu_op),       
        .EXE_sram_en     (pes_sram_en),
        .EXE_sram_addr   (pes_sram_addr),
        .EXE_sram_wdata  (pes_sram_wdata),
        .EXE_rf_we       (pes_rf_we),  
        .EXE_rf_waddr    (pes_rf_waddr)   
    );
    // EXE 阶段
    EXE_stage u_EXE (
        .clk             (clk),
        .reset           (reset),
        .pc              (pes_pc),
        .alu_op          (pes_alu_op),       
        .data_sram_en    (pes_sram_en),         
        .data_sram_addr  (pes_sram_addr),
        .data_sram_rdata (data_sram_rdata),
        .data_sram_wdata (pes_sram_wdata),
        .rf_we           (pes_rf_we),        
        .rf_waddr        (pes_rf_waddr), 
        .rf_raddr1       (pes_rf_raddr1),
        .rf_raddr2       (pes_rf_raddr2),
        .stall           (stall),     
        .alu_src1        (pes_alu_src1),      
        .alu_src2        (pes_alu_src2),
        .ms_allow_in     (ms_allow_in),
        .to_es_valid     (ds_to_es_valid),
        .mem_op          (pes_mem_op),
        // 前递      
        .ms_valid        (ms_to_wb_valid),
        .ms_sram_we      (ms_sram_we),
        .ms_sram_addr    (ms_sram_addr),
        .ms_sram_wdata   (ms_sram_wdata),
        .wb_valid        (wb_valid),
        .wb_sram_we      (wb_sram_we),
        .wb_sram_addr    (wb_sram_addr),
        .wb_sram_wdata   (wb_sram_wdata), 

        .es_mem_op       (es_mem_op),
        .es_pc           (es_pc),
        .sram_rdata      (es_sram_rdata), 
        .sram_addr       (es_sram_addr),  
        .sram_wdata      (es_sram_wdata),     
        .es_rf_we        (es_rf_we),       
        .es_rf_waddr     (es_rf_waddr),     
        .es_rf_wdata     (es_rf_wdata),
        .es_allow_in     (es_allow_in),
        .es_ready_go     (es_ready_go),
        .es_valid        (es_to_ms_valid),
        .div_valid       (div_valid)
    );
    // EXE/MEM reg
    MEM_reg u_MEM_reg(
        .clk             (clk),
        .reset           (reset),
        .es_ready_go     (es_ready_go),
        .ms_allow_in     (ms_allow_in), 
        .EXE_sram_addr   (es_sram_addr),  
        .EXE_sram_wdata  (es_sram_wdata), 
        .EXE_sram_rdata  (es_sram_rdata), 
        .EXE_pc          (es_pc),
        .EXE_rf_we       (es_rf_we),
        .EXE_rf_waddr    (es_rf_waddr),
        .EXE_rf_wdata    (es_rf_wdata),
        .EXE_mem_op      (es_mem_op),

        .MEM_mem_op      (pms_mem_op),
        .MEM_sram_rdata  (pms_sram_rdata),    
        .MEM_sram_addr   (pms_sram_addr),
        .MEM_sram_wdata  (pms_sram_wdata), 
        .MEM_pc          (pms_pc), 
        .MEM_rf_we       (pms_rf_we),
        .MEM_rf_waddr    (pms_rf_waddr),
        .MEM_rf_wdata    (pms_rf_wdata)
    );
    // MEM 阶段
    MEM_stage u_MEM (
        .clk             (clk),
        .reset           (reset),
        .pc              (pms_pc), 
        .data_sram_wdata (pms_sram_wdata),     
        .data_sram_addr  (pms_sram_addr),    
        .rf_we           (pms_rf_we),         
        .rf_waddr        (pms_rf_waddr),   
        .rf_wdata        (pms_rf_wdata), 
        .mem_op          (pms_mem_op),
        .wb_allow_in     (wb_allow_in),
        .to_ms_valid     (es_to_ms_valid),
        .div_valid       (div_valid),
        
        .ms_pc           (ms_pc),
        .sram_we         (ms_sram_we),   
        .sram_addr       (ms_sram_addr), 
        .sram_wdata      (ms_sram_wdata),
        .rf_we_out       (ms_rf_we),        
        .rf_waddr_out    (ms_rf_waddr),      
        .rf_wdata_out    (ms_rf_wdata), 
        .ms_allow_in     (ms_allow_in),
        .ms_ready_go     (ms_ready_go),
        .ms_valid        (ms_to_wb_valid)
    );
    // MEM_WB reg
    WB_reg u_WB_reg(
        .clk             (clk),
        .reset           (reset),
        .ms_ready_go     (ms_ready_go),
        .wb_allow_in     (wb_allow_in),
        .MEM_sram_we     (ms_sram_we),
        .MEM_sram_wdata  (ms_sram_wdata),    
        .MEM_sram_addr   (ms_sram_addr),
        .MEM_pc          (ms_pc),
        .MEM_rf_we       (ms_rf_we),
        .MEM_rf_waddr    (ms_rf_waddr),
        .MEM_rf_wdata    (ms_rf_wdata),

        .WB_pc           (pwb_pc), 
        .WB_sram_we      (pwb_sram_we),
        .WB_sram_addr    (pwb_sram_addr),
        .WB_sram_wdata   (pwb_sram_wdata),
        .WB_rf_we        (pwb_rf_we),
        .WB_rf_waddr     (pwb_rf_waddr),
        .WB_rf_wdata     (pwb_rf_wdata)
    );
    // WB 阶段
    WB_stage u_WB (
        .clk             (clk),
        .reset           (reset),
        .pc              (pwb_pc),
        .data_sram_we    (pwb_sram_we),
        .data_sram_wdata (pwb_sram_wdata),
        .data_sram_addr  (pwb_sram_addr),
        .rf_we           (pwb_rf_we),         
        .rf_waddr        (pwb_rf_waddr),      
        .rf_wdata        (pwb_rf_wdata),     
        .to_wb_valid     (ms_to_wb_valid),
        
        .wb_sram_we      (wb_sram_we),
        .wb_sram_wdata   (wb_sram_wdata),
        .wb_sram_addr    (wb_sram_addr),
        .rf_we_out       (wb_rf_we),        
        .rf_waddr_out    (wb_rf_waddr),      
        .rf_wdata_out    (wb_rf_wdata), 
        .wb_allow_in     (wb_allow_in),
        .wb_ready_go     (wb_ready_go),
        .wb_valid        (wb_valid)
    );

// ================= 冲突检测信号 =================
wire ld_alu_hazard  = (ds_mem_op[3:2] == 2'b01) && es_to_ms_valid &&
      ((es_rf_waddr == ds_rf_raddr1 && ds_rf_raddr1 != 0) || 
       (es_rf_waddr == ds_rf_raddr2 && ds_rf_raddr2 != 0));
wire stw_ldw_hazard = (ms_sram_we && ms_to_wb_valid && 
                        ds_to_es_valid && ds_sram_en) ;
// wire st_hazard = (ds_mem_op[3:2] == 2'b01) && (es_mem_op[3:2] == 2'b01);

// ================= RAM访问控制 =================
assign data_sram_en = ds_sram_en || ms_sram_we;
assign data_sram_we = ms_sram_we;
assign data_sram_addr = ms_sram_we ? ms_sram_addr : 
                        ds_sram_en ? ds_sram_addr :
                        32'b0;       
assign data_sram_wdata = ms_sram_wdata;
assign stall             = ld_alu_hazard  || stw_ldw_hazard || ~div_valid;
assign rf_raddr1 = ds_rf_raddr1;
assign rf_raddr2 = ds_rf_raddr2;
// debug info generate
assign debug_wb_pc       = pwb_pc;
assign debug_wb_rf_we    = wb_rf_we;
assign debug_wb_rf_wnum  = {27'b0 , {wb_rf_waddr}};
assign debug_wb_rf_wdata = wb_rf_wdata;

// // 添加调试语句
// always @(posedge clk) begin
//     $display("PC=%h, reset=%b, br_taken_c=%b, waddr=%h", 
//              pfs_pc, reset, br_taken_cancel, wb_rf_waddr);
// end
// always @(posedge clk) begin
//     $display("IF: en=%b addr=%h rdata=%h inst=%h we=%b", 
//              inst_sram_en, 
//              inst_sram_addr,
//              inst_sram_rdata,
//              inst,
//              inst_sram_we);
// end

endmodule