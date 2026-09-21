// 边界值：0、±1、最大正数、最小负数、字节边界、交替位
reg [15:0] corner [0:11];
initial begin
    corner[0] = 16'h0000; corner[1]  = 16'h0001; corner[2]  = 16'h7FFF; corner[3]  = 16'h8000;
    corner[4] = 16'h8001; corner[5]  = 16'hFFFF; corner[6]  = 16'h00FF; corner[7]  = 16'hFF00;
    corner[8] = 16'h000F; corner[9]  = 16'h0010; corner[10] = 16'hAAAA; corner[11] = 16'h5555;
end
