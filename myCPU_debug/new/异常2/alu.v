module alu(
  input         clk,
  input         reset,
  input         flush,
  input [17:0]  alu_op,
  input [32:0]  alu_src1,
  input [32:0]  alu_src2,
  output [31:0] alu_result,
  output        div_valid
); 

wire [31:0] src1 = alu_src1[31:0];
wire [31:0] src2 = alu_src2[31:0];
wire [63:0] div_mod_uresult;
wire [63:0] div_mod_result;
wire dividend_tready;
wire dividend_tready_u;
wire divisor_tready;
wire divisor_tready_u;
wire out_valid;
wire out_valid_u;


wire op_add;   //add operation
wire op_sub;   //sub operation
wire op_slt;   //signed compared and set less than
wire op_sltu;  //unsigned compared and set less than
wire op_and;   //bitwise and
wire op_nor;   //bitwise nor
wire op_or;    //bitwise or
wire op_xor;   //bitwise xor
wire op_sll;   //logic left shift
wire op_srl;   //logic right shift
wire op_sra;   //arithmetic right shift
wire op_lui;   //Load Upper Immediate
wire op_hmul;
wire op_mul;
wire op_div;
wire op_mod;
wire op_udiv;
wire op_umod;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_hmul = alu_op[12];
assign op_mul  = alu_op[13];
assign op_div  = alu_op[14];
assign op_mod  = alu_op[15];
assign op_udiv = alu_op[16];
assign op_umod = alu_op[17];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [31:0] sra_result;
wire [31:0] srl_result;
wire [31:0] shft_src;
wire [31:0] shft_res;
wire [31:0] sra_mask;
wire [31:0] hmul_result;
wire [31:0] mul_result;
wire [31:0] div_result;
wire [31:0] mod_result;
wire [31:0] udiv_result;
wire [31:0] umod_result;
 
// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;

assign adder_a   = src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~src2 : src2;  //src1 - src2 rj-rk
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout, adder_result} = adder_a + adder_b + adder_cin;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;   //rj < rk 1
assign slt_result[0]    = (src1[31] & ~src2[31])
                        | ((src1[31] ~^ src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = src1 & src2;
assign or_result  = src1 | src2;
assign nor_result = ~or_result;
assign xor_result = src1 ^ src2;
assign lui_result = {src2[31:12], 12'b0};

// SLL,SRL, SRA result
assign sll_result = src1 << src2[4:0];
assign srl_result = src1 >> src2[4:0];
assign sra_result = $signed(src1) >>> src2[4:0];

// MUL result
wire [65:0] mul_prod = $signed(alu_src1) * $signed(alu_src2);
assign hmul_result = mul_prod[63:32];
assign mul_result =mul_prod[31:0];

// 除法控制信号
wire is_div = op_div | op_mod | op_udiv | op_umod;
reg div_allowed;
always @(posedge clk) begin
    if (reset) begin
        div_allowed <= 1'b1;
    end else begin
        div_allowed <= ~is_div | div_valid;
    end
end

// 除法器握手信号
reg dividend_tvalid;
reg divisor_tvalid;
reg dividend_tvalid_u;
reg divisor_tvalid_u;

always @(posedge clk) begin
    if (reset || flush) begin
        dividend_tvalid   <= 1'b0;
        divisor_tvalid    <= 1'b0;
        dividend_tvalid_u <= 1'b0;
        divisor_tvalid_u  <= 1'b0;
    end else begin
        // 有符号除法握手
        if ((op_div || op_mod) && div_allowed) begin
            dividend_tvalid <= 1'b1;
            divisor_tvalid  <= 1'b1;
        end
        else if (dividend_tready && divisor_tready) begin
            dividend_tvalid <= 1'b0;
            divisor_tvalid  <= 1'b0;
        end 
        // 无符号除法握手
        if ((op_udiv || op_umod) && div_allowed) begin
            dividend_tvalid_u <= 1'b1;
            divisor_tvalid_u  <= 1'b1;
        end
        else if (dividend_tready_u && divisor_tready_u) begin
            dividend_tvalid_u <= 1'b0;
            divisor_tvalid_u  <= 1'b0;
        end  
    end
end

div_gen_0 u_div_gen_0 (
  .aclk                    (clk),
  .s_axis_dividend_tdata   (src1),
  .s_axis_divisor_tdata    (src2),
  .s_axis_dividend_tvalid  (dividend_tvalid),
  .s_axis_divisor_tvalid   (divisor_tvalid),
  
  .s_axis_dividend_tready  (dividend_tready),
  .s_axis_divisor_tready   (divisor_tready),
  .m_axis_dout_tdata       (div_mod_result),
  .m_axis_dout_tvalid      (out_valid)
);
div_gen_1 u_div_gen_1 (
  .aclk                    (clk),
  .s_axis_dividend_tdata   (src1),
  .s_axis_divisor_tdata    (src2),
  .s_axis_dividend_tvalid  (dividend_tvalid_u),
  .s_axis_divisor_tvalid   (divisor_tvalid_u),
  
  .s_axis_dividend_tready  (dividend_tready_u),
  .s_axis_divisor_tready   (divisor_tready_u),
  .m_axis_dout_tdata       (div_mod_uresult),
  .m_axis_dout_tvalid      (out_valid_u)
);

//DIV MOD result
assign div_result  = div_mod_result[63:32];
assign mod_result  = div_mod_result[31:0];
assign udiv_result = div_mod_uresult[63:32];
assign umod_result = div_mod_uresult[31:0];

assign div_valid = ~is_div | (out_valid | out_valid_u);

// final result mux
assign alu_result = ({32{op_add|op_sub}} & add_sub_result)
                  | ({32{op_slt       }} & slt_result)
                  | ({32{op_sltu      }} & sltu_result)
                  | ({32{op_and       }} & and_result)
                  | ({32{op_nor       }} & nor_result)
                  | ({32{op_or        }} & or_result)
                  | ({32{op_xor       }} & xor_result)
                  | ({32{op_lui       }} & lui_result)
                  | ({32{op_sll       }} & sll_result)
                  | ({32{op_srl       }} & srl_result)
                  | ({32{op_sra       }} & sra_result)
                  | ({32{op_hmul      }} & hmul_result)
                  | ({32{op_mul       }} & mul_result)
                  | ({32{op_div       }} & div_result)
                  | ({32{op_mod       }} & mod_result)
                  | ({32{op_udiv      }} & udiv_result)
                  | ({32{op_umod      }} & umod_result);

endmodule