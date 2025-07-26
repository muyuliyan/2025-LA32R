module mycpu_top (
    input         clk,
    input         resetn,
    input  [7:0]  interrupt,
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
    wire pfs_excp_adef;
    // IF
    wire [31:0] fs_pc;
    wire [31:0] inst;
    wire fs_ready_go;
    wire fs_to_ds_valid;
    wire fs_excp_adef;
    // IF/ID reg
    wire pds_valid;
    wire [31:0] pds_inst;
    wire [31:0] pds_pc;
    wire pds_excp_adef;
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
    wire [31:0] ds_rf_wdata;
    wire [4:0]  ds_rf_raddr1;
    wire [4:0]  ds_rf_raddr2;
    wire [31:0] ds_csr_rdata;      
    wire [3:0]  ds_csr_we;
    wire        ds_csr_re;
    wire [13:0] ds_csr_num;
    wire [31:0] ds_csr_wmask;
    wire [31:0] ds_csr_wdata;
    wire ds_ertn;
    wire ds_excp_syscall;
    wire ds_excp_ipe;
    wire ds_excp_break;
    wire ds_excp_ine;
    wire ds_excp_adef;
    wire ds_has_int;
    wire ds_ale_op1;
    wire ds_ale_op2;
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
    wire [3:0]  pes_csr_we;        
    wire pes_csr_re;
    wire [13:0] pes_csr_num;
    wire [31:0] pes_csr_wmask;
    wire [31:0] pes_csr_wdata;
    wire [3:0]  pes_rf_we; 
    wire [4:0]  pes_rf_waddr;
    wire [31:0] pes_rf_wdata; 
    wire pes_ertn;
    wire pes_excp_syscall;
    wire pes_excp_ipe;
    wire pes_excp_break;
    wire pes_excp_ine;
    wire pes_excp_adef;
    wire pes_has_int;
    wire pes_ale_op1;
    wire pes_ale_op2;
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
    wire [3:0]  es_csr_we;
    wire [13:0] es_csr_num;
    wire [31:0]  es_csr_wmask;
    wire [31:0] es_csr_wdata; 
    wire es_ertn;
    wire es_excp_syscall;
    wire es_excp_ale;
    wire es_excp_ine;
    wire es_excp_ipe;
    wire es_excp_break;
    wire es_excp_adef;
    wire es_has_int;
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
    wire [3:0]  pms_csr_we;
    wire [13:0] pms_csr_num;
    wire [31:0] pms_csr_wdata;
    wire [31:0]  pms_csr_wmask;
    wire pms_ertn;
    wire pms_excp_syscall;
    wire pms_excp_break;
    wire pms_excp_ale;
    wire pms_excp_ine;
    wire pms_excp_ipe;
    wire pms_excp_adef;
    wire pms_has_int; 
    wire [3:0]  pms_mem_op;
    // MEM
    wire [3:0]  ms_sram_we;
    wire [31:0] ms_sram_addr;
    wire [31:0] ms_sram_wdata;
    wire [31:0] ms_pc;
    wire [3:0]  ms_rf_we;        
    wire [4:0]  ms_rf_waddr;      
    wire [31:0] ms_rf_wdata; 
    wire [3:0]  ms_csr_we;
    wire [13:0] ms_csr_num;
    wire [31:0] ms_csr_wdata;
    wire [31:0] ms_csr_wmask; 
    wire ms_ertn;
    wire ms_excp_syscall;
    wire ms_excp_ale;
    wire ms_excp_ine;
    wire ms_excp_ipe;
    wire ms_excp_break;
    wire ms_excp_adef;
    wire ms_has_int;
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
    wire [3:0]  pwb_csr_we;
    wire [13:0] pwb_csr_num;
    wire [31:0] pwb_csr_wdata;
    wire [31:0] pwb_csr_wmask; 
    wire pwb_ertn;
    wire pwb_excp_syscall;
    wire pwb_excp_ale;
    wire pwb_excp_break;
    wire pwb_excp_ine;
    wire pwb_excp_ipe;
    wire pwb_excp_adef;
    wire pwb_has_int;
    // WB
    wire wb_valid;
    wire wb_allow_in;
    wire wb_ready_go;
    wire wb_ex;
    wire [5:0]  wb_ecode;
    wire [8:0]  wb_esubcode;
    wire [31:0] wb_pc;
    wire [3:0]  wb_sram_we;
    wire [31:0] wb_sram_addr;
    wire [31:0] wb_sram_wdata;
    wire [3:0]  wb_rf_we;        
    wire [4:0]  wb_rf_waddr;      
    wire [31:0] wb_rf_wdata;
    wire [3:0]  wb_csr_we;
    wire [13:0] wb_csr_num;
    wire [31:0] wb_csr_wdata;
    wire [31:0] wb_csr_wmask;
    wire wb_ertn;
    wire wb_syscall;
    // 全局控制信号
    wire flush;
    wire br_taken_cancel;
    wire stall;
    wire has_int;
    wire [31:0] excp_pc;
    wire [31:0] ertn_pc;
    wire [1:0]  csr_plv;
    wire [63:0] timer_64;
    wire [31:0] csr_tid;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;
    wire [31:0] rf_raddr1;
    wire [31:0] rf_raddr2;
    wire [31:0] ex_entry;
    wire [1:0] plv = csr_plv;
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
    // csr
    csr u_csr(
        .clk          (clk),
        .reset        (reset),
        .csr_re       (ds_csr_re),
        .csr_rnum     (csr_rnum),
        .csr_wnum     (csr_wnum),
        .csr_rdata    (ds_csr_rdata),
        .csr_we       (csr_we),
        .csr_wmask    (wb_csr_wmask),
        .csr_wdata    (csr_wdata),
        .interrupt    (interrupt),

        .ertn_flush   (ertn_flush),  
        .wb_ex        (wb_ex),     
        .wb_ecode     (wb_ecode),       
        .wb_esubcode  (wb_esubcode),    
        .wb_pc        (wb_pc),          
        .excp_pc      (excp_pc),
        .ertn_pc      (ertn_pc),
        .timer_64_out (timer_64),
        .csr_tid_out  (csr_tid),
        .csr_plv      (csr_plv),
        .has_int      (has_int)
    );

//======================= 五级流水线 ========================
    // IF 阶段
    pre_IF_stage u_pre_IF(
        .clk             (clk),
        .reset           (reset),
        .br_taken_cancel (br_taken_cancel),
        .stall           (stall),
        .br_target       (br_target),
        .excp_flush      (excp_flush),
        .ertn_flush      (ertn_flush),
        .excp_pc         (excp_pc),
        .ertn_pc         (ertn_pc),

        .excp_adef       (pfs_excp_adef),
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
        .excp_adef       (pfs_excp_adef),

        .fs_pc           (fs_pc),
        .inst            (inst),  
        .fs_ready_go     (fs_ready_go),
        .fs_valid        (fs_to_ds_valid),
        .fs_excp_adef    (fs_excp_adef)
    );
    // IF/ID reg
    ID_reg u_ID_reg(
        .clk             (clk),
        .reset           (reset),
        .fs_ready_go     (fs_ready_go),
        .ds_allow_in     (ds_allow_in),
        .IF_pc           (fs_pc),
        .IF_inst         (inst),
        .flush           (flush),
        .IF_excp_adef    (fs_excp_adef),

        .ID_inst         (pds_inst),
        .ID_pc           (pds_pc),
        .ID_excp_adef    (pds_excp_adef)
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
        .csr_rdata       (ds_csr_rdata), 
        .flush           (flush), 
        .has_int         (has_int),
        .excp_adef       (pds_excp_adef),
        .csr_plv         (plv),
        .timer_64        (timer_64),
        .csr_tid         (csr_tid),

        .csr_we          (ds_csr_we),
        .csr_re          (ds_csr_re),       
        .csr_num         (ds_csr_num),         
        .csr_wmask       (ds_csr_wmask),
        .csr_wdata       (ds_csr_wdata),   
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
        .rf_wdata        (ds_rf_wdata),
        .ds_allow_in     (ds_allow_in),
        .ds_ready_go     (ds_ready_go),
        .ds_valid        (ds_to_es_valid),
        .ds_ertn         (ds_ertn),
        .ds_excp_syscall (ds_excp_syscall),
        .ds_excp_ipe     (ds_excp_ipe),
        .ds_excp_break   (ds_excp_break),
        .ds_excp_ine     (ds_excp_ine),
        .ds_excp_adef    (ds_excp_adef),
        .ds_has_int      (ds_has_int),
        .ale_op1         (ds_ale_op1),
        .ale_op2         (ds_ale_op2)
    );
    // ID/EXE reg
    EXE_reg u_EXE_reg(
        .clk             (clk),
        .reset           (reset),
        .flush           (flush),
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
        .ID_rf_wdata     (ds_rf_wdata),
        .ID_csr_we       (ds_csr_we),
        .ID_csr_re       (ds_csr_re),    
        .ID_csr_num      (ds_csr_num),       // CSR读地址
        .ID_csr_wmask    (ds_csr_wmask),
        .ID_csr_wdata    (ds_csr_wdata),
        .ID_ertn         (ds_ertn),
        .ID_excp_syscall (ds_excp_syscall),
        .ID_mem_op       (ds_mem_op),
        .ID_excp_ipe     (ds_excp_ipe),
        .ID_excp_break   (ds_excp_break),
        .ID_excp_ine     (ds_excp_ine),
        .ID_excp_adef    (ds_excp_adef),
        .ID_has_int      (ds_has_int),
        .ID_ale_op1      (ds_ale_op1),
        .ID_ale_op2      (ds_ale_op2),
        
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
        .EXE_rf_waddr    (pes_rf_waddr),
        .EXE_rf_wdata    (pes_rf_wdata),  
        .EXE_csr_we      (pes_csr_we),        
        .EXE_csr_re      (pes_csr_re),
        .EXE_csr_num     (pes_csr_num),
        .EXE_csr_wmask   (pes_csr_wmask),
        .EXE_csr_wdata   (pes_csr_wdata),
        .EXE_ertn        (pes_ertn),
        .EXE_excp_syscall(pes_excp_syscall),
        .EXE_excp_ipe    (pes_excp_ipe),
        .EXE_excp_break  (pes_excp_break),
        .EXE_excp_ine    (pes_excp_ine),
        .EXE_excp_adef   (pes_excp_adef),
        .EXE_has_int     (pes_has_int),
        .EXE_ale_op1     (pes_ale_op1),
        .EXE_ale_op2     (pes_ale_op2)
    );
    // EXE 阶段
    EXE_stage u_EXE (
        .clk             (clk),
        .reset           (reset),
        .flush           (flush),
        .pc              (pes_pc),
        .alu_op          (pes_alu_op),       
        .data_sram_en    (pes_sram_en),         
        .data_sram_addr  (pes_sram_addr),
        .data_sram_rdata (data_sram_rdata),
        .data_sram_wdata (pes_sram_wdata),
        .rf_we           (pes_rf_we),        
        .rf_waddr        (pes_rf_waddr),
        .rf_wdata        (pes_rf_wdata), 
        .rf_raddr1       (pes_rf_raddr1),
        .rf_raddr2       (pes_rf_raddr2),
        .csr_we          (pes_csr_we),
        .csr_re          (pes_csr_re),
        .csr_num         (pes_csr_num),
        .csr_wdata       (pes_csr_wdata),
        .csr_wmask       (pes_csr_wmask), 
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
        .ertn            (pes_ertn),
        .excp_syscall    (pes_excp_syscall), 
        .excp_break      (pes_excp_break),
        .excp_ine        (pes_excp_ine),
        .excp_ipe        (pes_excp_ipe),
        .excp_adef       (pes_excp_adef),
        .has_int         (pes_has_int),
        .ale_op1         (pes_ale_op1), 
        .ale_op2         (pes_ale_op2),

        .es_csr_we       (es_csr_we),
        .es_csr_num      (es_csr_num),
        .es_csr_wdata    (es_csr_wdata),
        .es_csr_wmask    (es_csr_wmask),
        .es_mem_op       (es_mem_op),
        .es_pc           (es_pc),
        .sram_rdata      (es_sram_rdata), 
        .sram_addr       (es_sram_addr),  
        .sram_wdata      (es_sram_wdata),     
        .es_rf_we        (es_rf_we),       
        .es_rf_waddr     (es_rf_waddr),     
        .es_rf_wdata     (es_rf_wdata),
        .es_ertn         (es_ertn),
        .es_excp_syscall (es_excp_syscall),
        .es_excp_ale     (es_excp_ale),
        .es_excp_ine     (es_excp_ine),
        .es_excp_ipe     (es_excp_ipe),
        .es_excp_break   (es_excp_break),
        .es_excp_adef    (es_excp_adef),
        .es_has_int      (es_has_int),
        .es_allow_in     (es_allow_in),
        .es_ready_go     (es_ready_go),
        .es_valid        (es_to_ms_valid),
        .div_valid       (div_valid)
    );
    // EXE/MEM reg
    MEM_reg u_MEM_reg(
        .clk             (clk),
        .reset           (reset),
        .flush           (flush),
        .es_ready_go     (es_ready_go),
        .ms_allow_in     (ms_allow_in), 
        .EXE_sram_addr   (es_sram_addr),  
        .EXE_sram_wdata  (es_sram_wdata), 
        .EXE_sram_rdata  (es_sram_rdata), 
        .EXE_pc          (es_pc),
        .EXE_rf_we       (es_rf_we),
        .EXE_rf_waddr    (es_rf_waddr),
        .EXE_rf_wdata    (es_rf_wdata),
        .EXE_csr_we      (es_csr_we),
        .EXE_csr_num     (es_csr_num),
        .EXE_csr_wdata   (es_csr_wdata),
        .EXE_csr_wmask   (es_csr_wmask),
        .EXE_ertn        (es_ertn),
        .EXE_excp_syscall(es_excp_syscall),
        .EXE_excp_break  (es_excp_break),
        .EXE_excp_ale    (es_excp_ale),
        .EXE_excp_ine    (es_excp_ine),
        .EXE_excp_ipe    (es_excp_ipe),
        .EXE_excp_adef   (es_excp_adef),
        .EXE_has_int     (es_has_int),
        .EXE_mem_op      (es_mem_op),

        .MEM_mem_op      (pms_mem_op),
        .MEM_sram_rdata  (pms_sram_rdata),    
        .MEM_sram_addr   (pms_sram_addr),
        .MEM_sram_wdata  (pms_sram_wdata), 
        .MEM_pc          (pms_pc), 
        .MEM_rf_we       (pms_rf_we),
        .MEM_rf_waddr    (pms_rf_waddr),
        .MEM_rf_wdata    (pms_rf_wdata),
        .MEM_csr_we      (pms_csr_we),
        .MEM_csr_num     (pms_csr_num),
        .MEM_csr_wdata   (pms_csr_wdata),
        .MEM_csr_wmask   (pms_csr_wmask),
        .MEM_ertn        (pms_ertn),
        .MEM_excp_syscall(pms_excp_syscall),
        .MEM_excp_break  (pms_excp_break),
        .MEM_excp_ale    (pms_excp_ale),
        .MEM_excp_ine    (pms_excp_ine),
        .MEM_excp_ipe    (pms_excp_ipe),
        .MEM_excp_adef   (pms_excp_adef),
        .MEM_has_int     (pms_has_int)  
    );
    // MEM 阶段
    MEM_stage u_MEM (
        .clk             (clk),
        .reset           (reset),
        .flush           (flush),
        .pc              (pms_pc), 
        .data_sram_wdata (pms_sram_wdata),     
        .data_sram_addr  (pms_sram_addr),    
        .rf_we           (pms_rf_we),         
        .rf_waddr        (pms_rf_waddr),   
        .rf_wdata        (pms_rf_wdata),
        .csr_we          (pms_csr_we),
        .csr_num         (pms_csr_num),
        .csr_wdata       (pms_csr_wdata),
        .csr_wmask       (pms_csr_wmask),
        .ertn            (pms_ertn),
        .excp_syscall    (pms_excp_syscall),
        .excp_break      (pms_excp_break),
        .excp_ale        (pms_excp_ale),
        .excp_ine        (pms_excp_ine),
        .excp_ipe        (pms_excp_ipe),
        .excp_adef       (pms_excp_adef),
        .has_int         (pms_has_int),   
        .mem_op          (pms_mem_op),
        .wb_allow_in     (wb_allow_in),
        .to_ms_valid     (es_to_ms_valid),
        .div_valid       (div_valid),
        
        .ms_pc           (ms_pc),
        .sram_we         (ms_sram_we),   
        .sram_addr       (ms_sram_addr), 
        .sram_wdata      (ms_sram_wdata),
        .ms_rf_we        (ms_rf_we),        
        .ms_rf_waddr     (ms_rf_waddr),      
        .ms_rf_wdata     (ms_rf_wdata),
        .ms_csr_we       (ms_csr_we),
        .ms_csr_num      (ms_csr_num),
        .ms_csr_wdata    (ms_csr_wdata),
        .ms_csr_wmask    (ms_csr_wmask),
        .ms_ertn         (ms_ertn),
        .ms_excp_syscall (ms_excp_syscall),
        .ms_excp_ale     (ms_excp_ale),
        .ms_excp_ine     (ms_excp_ine),
        .ms_excp_ipe     (ms_excp_ipe),
        .ms_excp_break   (ms_excp_break),
        .ms_excp_adef    (ms_excp_adef),
        .ms_has_int      (ms_has_int),
        .ms_allow_in     (ms_allow_in),
        .ms_ready_go     (ms_ready_go),
        .ms_valid        (ms_to_wb_valid)
    );
    // MEM_WB reg
    WB_reg u_WB_reg(
        .clk             (clk),
        .reset           (reset),
        .flush           (flush),
        .ms_ready_go     (ms_ready_go),
        .wb_allow_in     (wb_allow_in),
        .MEM_pc          (ms_pc),
        .MEM_rf_we       (ms_rf_we),
        .MEM_rf_waddr    (ms_rf_waddr),
        .MEM_rf_wdata    (ms_rf_wdata),
        .MEM_sram_we     (ms_sram_we),
        .MEM_sram_wdata  (ms_sram_wdata),    
        .MEM_sram_addr   (ms_sram_addr),
        .MEM_csr_we      (ms_csr_we),
        .MEM_csr_num     (ms_csr_num),
        .MEM_csr_wdata   (ms_csr_wdata),
        .MEM_csr_wmask   (ms_csr_wmask),
        .MEM_ertn        (ms_ertn),
        .MEM_excp_syscall(ms_excp_syscall),
        .MEM_excp_break  (ms_excp_break),
        .MEM_excp_ale    (ms_excp_ale),
        .MEM_excp_ine    (ms_excp_ine),
        .MEM_excp_ipe    (ms_excp_ipe),
        .MEM_excp_adef   (ms_excp_adef),
        .MEM_has_int     (ms_has_int), 

        .WB_pc           (pwb_pc), 
        .WB_rf_we        (pwb_rf_we),
        .WB_rf_waddr     (pwb_rf_waddr),
        .WB_rf_wdata     (pwb_rf_wdata),
        .WB_sram_we      (pwb_sram_we),
        .WB_sram_addr    (pwb_sram_addr),
        .WB_sram_wdata   (pwb_sram_wdata),
        .WB_csr_we       (pwb_csr_we),
        .WB_csr_num      (pwb_csr_num),
        .WB_csr_wdata    (pwb_csr_wdata),
        .WB_csr_wmask    (pwb_csr_wmask),
        .WB_ertn         (pwb_ertn),
        .WB_excp_syscall (pwb_excp_syscall),
        .WB_excp_ale     (pwb_excp_ale),
        .WB_excp_break   (pwb_excp_break),
        .WB_excp_ine     (pwb_excp_ine),
        .WB_excp_ipe     (pwb_excp_ipe),
        .WB_excp_adef    (pwb_excp_adef),
        .WB_has_int      (pwb_has_int)
    );
    // WB 阶段
    WB_stage u_WB (
        .clk             (clk),
        .reset           (reset),
        .pc              (pwb_pc),
        .rf_we           (pwb_rf_we),         
        .rf_waddr        (pwb_rf_waddr),      
        .rf_wdata        (pwb_rf_wdata), 
        .data_sram_we    (pwb_sram_we),
        .data_sram_wdata (pwb_sram_wdata),
        .data_sram_addr  (pwb_sram_addr), 
        .csr_we          (pwb_csr_we),
        .csr_num         (pwb_csr_num),
        .csr_wdata       (pwb_csr_wdata),
        .csr_wmask       (pwb_csr_wmask),
        .ertn            (pwb_ertn),
        .excp_syscall    (pwb_excp_syscall), 
        .excp_break      (pwb_excp_break),
        .excp_ale        (pwb_excp_ale),
        .excp_ipe        (pwb_excp_ipe),
        .excp_ine        (pwb_excp_ine),
        .excp_adef       (pwb_excp_adef),
        .has_int         (pwb_has_int), 
        .to_wb_valid     (ms_to_wb_valid),
        
        .wb_ex           (wb_ex),
        .wb_ecode        (wb_ecode),
        .wb_esubcode     (wb_esubcode),
        .wb_pc           (wb_pc),
        .wb_rf_we        (wb_rf_we),        
        .wb_rf_waddr     (wb_rf_waddr),      
        .wb_rf_wdata     (wb_rf_wdata), 
        .wb_sram_we      (wb_sram_we),
        .wb_sram_wdata   (wb_sram_wdata),
        .wb_sram_addr    (wb_sram_addr),
        .wb_csr_we       (wb_csr_we),
        .wb_csr_num      (wb_csr_num),
        .wb_csr_wdata    (wb_csr_wdata),
        .wb_csr_wmask    (wb_csr_wmask),
        .wb_ertn         (wb_ertn),
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
wire csr_wr_hazard = (es_to_ms_valid && (es_csr_we == 4'hf) && (ds_csr_re == 1'b1) &&
                     (es_csr_num == ds_csr_num)) ||
                     (ms_to_wb_valid && (ms_csr_we == 4'hf) && (ds_csr_re == 1'b1) &&
                     (ms_csr_num == ds_csr_num)) ||
                     (wb_valid && (wb_csr_we == 4'hf) && (ds_csr_re == 1'b1) &&
                     (wb_csr_num == ds_csr_num));

// ================== 刷新信号 ======================
assign ertn_flush = wb_valid && wb_ertn;
assign excp_flush = wb_valid && wb_ex;
assign flush = ertn_flush || excp_flush; 

// ================= DATA_RAM访问控制 =================
assign data_sram_en = ds_sram_en || ms_sram_we;
assign data_sram_we = ms_sram_we;
assign data_sram_addr = ms_sram_we ? ms_sram_addr : 
                        ds_sram_en ? ds_sram_addr :
                        32'b0;       
assign data_sram_wdata = ms_sram_wdata;
assign stall             = csr_wr_hazard || ld_alu_hazard  || stw_ldw_hazard || ~div_valid;
assign rf_raddr1 = ds_rf_raddr1;
assign rf_raddr2 = ds_rf_raddr2;

// ================== CSR访问控制 =====================
wire [13:0] csr_rnum;
assign csr_rnum = ds_csr_re ? ds_csr_num : 14'b0;
wire [13:0] csr_wnum;
assign csr_wnum = wb_csr_we ? wb_csr_num : 14'b0;   
wire [3:0]  csr_we;
assign csr_we = wb_csr_we;
wire [31:0] csr_wdata;
assign csr_wdata = wb_csr_wdata;

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