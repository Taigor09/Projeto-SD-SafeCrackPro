module safepro (
    input logic clk,
    input logic rst,
    input logic [3:0] key,

    output logic [34:0] hex,
    output logic [17:0] led_vermelho,
    output logic [6:0] led_verde
);

    logic [3:0] valor_atual;

always_ff @(posedge clk) begin

    if (rst) begin
        valor_atual <= 4'd0;




endmodule
