module regfile(
    input  wire        clk,
    input              reset,
    // READ PORT 1
    input  wire [ 4:0] raddr1,
    output wire [31:0] rdata1,
    // READ PORT 2
    input  wire [ 4:0] raddr2,
    output wire [31:0] rdata2,
    // WRITE PORT
    input  wire [3:0]  we,       
    input  wire [ 4:0] waddr,
    input  wire [31:0] wdata
);
reg  [31:0] rf[31:0];
wire [31:0] f_raddr1 = {27'b0 , {raddr1}};
wire [31:0] f_raddr2 = {27'b0 , {raddr2}};
wire [31:0] f_waddr  = {27'b0 , {waddr}};
integer i;

// 同步复位和写入逻辑
always @(posedge clk) begin
    if (reset) begin
        for (i = 0; i < 32; i = i + 1)
            rf[i] <= 32'b0;
    end
    else if (we && |waddr) begin
        rf[f_waddr] <= wdata;
    end
end

//READ OUT 1
assign rdata1 = (raddr1==5'b0) ? 32'b0 : rf[f_raddr1];

//READ OUT 2
assign rdata2 = (raddr2==5'b0) ? 32'b0 : rf[f_raddr2];
// always @(posedge clk) begin
//     $display("[regfile] raddr1=%h rdata1=%h, raddr2=%h rdata2=%h",
//              raddr1, rdata1, raddr2, rdata2);
// end


endmodule
