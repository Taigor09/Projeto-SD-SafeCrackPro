module cofreHack (
    input  logic CLOCK_50,
    input  logic [3:0] KEY,

    output logic liberado, nao_liberado,
    output logic [2:0] contador,
    output logic [3:0] v1, v2, v3, v4,

    output logic [7:0] LEDG, // LEDs verdes
    output logic [17:0] LEDR, // LEDs vermelhos
    output logic [6:0] HEX4, HEX3, HEX2, HEX1, HEX0 // displays da FPGA, contador, v1, v2, v3, v4
);

// nomes para as lógicas internas do código
logic clk, rstn;
logic [2:0] butao;

assign clk = CLOCK_50; // clock de 50 MHz
assign rstn = KEY[0]; // botão do reset na KEY0
assign butao = {KEY[1], KEY[2], KEY[3]}; // KEY1 = confirmar, KEY2 = incremento, KEY3 = decremento

// DEFINIÇÃO DAS SENHAS
localparam logic [3:0] SENHA1 = 4'd1;
localparam logic [3:0] SENHA2 = 4'd2;
localparam logic [3:0] SENHA3 = 4'd3;
localparam logic [3:0] SENHA4 = 4'd4;

typedef enum logic [5:0] {
    S0 = 6'b000001,
    S1 = 6'b000010,
    S2 = 6'b000100,
    S3 = 6'b001000,
    LIBERADO = 6'b010000,
    NAO_LIBERADO = 6'b100000
} estados;

estados estado_atual, proximo_estado;

logic butao_inc, butao_dec, butao_conf;

logic [2:0] segurado, apertado, butao_ant;
logic [3:0] valor_atual, novo_valor;
logic [3:0] proximo_v1, proximo_v2, proximo_v3, proximo_v4;
// pares atual/proximo, necessario sempre para receber os valores nos combinacionais e atualizar os atuais com os novos no always_ff.

localparam int TEMPO_LIBERADO = 250_000_000;   // Tempo de LED verde
localparam int TEMPO_NAO_LIBERADO = 150_000_000;   // Tempo de LED vermelho

// contador de tempo, principal uso aqui é para os tempos dos LEDs.
logic [$clog2(TEMPO_LIBERADO)-1:0] tempo_atual, proximo_tempo;

// DECODIFICADOR DE SETE SEGMENTOS
// Basicamente uma função para configurar os valores dos displays (HEX[n]) da FPGA.
function automatic logic [6:0] decodifica_7seg (input logic [3:0] digito);
    case (digito)
        4'd0: decodifica_7seg = 7'b1000000;
        4'd1: decodifica_7seg = 7'b1111001;
        4'd2: decodifica_7seg = 7'b0100100;
        4'd3: decodifica_7seg = 7'b0110000;
        4'd4: decodifica_7seg = 7'b0011001;
        4'd5: decodifica_7seg = 7'b0010010;
        4'd6: decodifica_7seg = 7'b0000010;
        4'd7: decodifica_7seg = 7'b1111000;
        4'd8: decodifica_7seg = 7'b0000000;
        4'd9: decodifica_7seg = 7'b0010000;
        default: decodifica_7seg = 7'b1111111;
    endcase
endfunction

always_comb begin // trecho para a verificação de borda, identificação e distinção de ter apertado o botão e estar segurando.
    butao_dec = ~butao[0];
    butao_inc = ~butao[1];
    butao_conf = ~butao[2];
    apertado = {butao_conf, butao_inc, butao_dec} & ~butao_ant; // acabou de apertar
    segurado = {butao_conf, butao_inc, butao_dec} &  butao_ant; // continua apertado
end

always_ff @(posedge clk or negedge rstn) begin
    if (~rstn) begin // bloco de flip para sempre manter os valores atualizados
        butao_ant <= 3'b000; // aqui seria a atualização dos valores caso apertado o reset, todo mundo volta para os estados iniciais.
        estado_atual <= S0;
        v1 <= 4'd0;
        v2 <= 4'd0;
        v3 <= 4'd0;
        v4 <= 4'd0;
        tempo_atual <= 0;
    end
    else begin // aqui atualização constante de novos valores para novos estados enquanto não houver reset.                          
        butao_ant <= {butao_conf, butao_inc, butao_dec};
        estado_atual <= proximo_estado;
        v1 <= proximo_v1;
        v2 <= proximo_v2;
        v3 <= proximo_v3;
        v4 <= proximo_v4;
        tempo_atual <= proximo_tempo;
    end
end

    // Aqui é o bloco de escolha dos digitos dependo do estado e a lógica de incremento e decremento com a transição de 9 para 0 e vice-versa.
always_comb begin
    unique case (estado_atual)
        S0: valor_atual = v1;
        S1: valor_atual = v2;
        S2: valor_atual = v3;
        S3: valor_atual = v4;
        default: valor_atual = 4'd0;
    endcase
    if (apertado[1]) // inc
        novo_valor = (valor_atual == 4'd9 ? 4'd0 : valor_atual + 4'd1);
    else if (apertado[0]) // dec
        novo_valor = (valor_atual == 4'd0 ? 4'd9 : valor_atual - 4'd1);
    else // nenhum inc/dec apertado
        novo_valor = valor_atual;
end

// lógica de transições para novos valores.
always_comb begin
    proximo_estado = estado_atual;
    proximo_v1 = v1;
    proximo_v2 = v2;
    proximo_v3 = v3;
    proximo_v4 = v4;
    proximo_tempo = '0;
    unique case (estado_atual)
        S0: begin
            proximo_v1 = novo_valor;
            if (apertado[2]) proximo_estado = S1;
        end
        S1: begin
            proximo_v2 = novo_valor;
            if (apertado[2]) proximo_estado = S2;
        end
        S2: begin
            proximo_v3 = novo_valor;
            if (apertado[2]) proximo_estado = S3;
        end
        S3: begin
            proximo_v4 = novo_valor;
            if (apertado[2]) begin // aqui é o unico estado em que a transição é peculiar pois saimos do ultimo estado para a checagem da senha e partir daí ver se deve ser liberado ou não.
                if ((SENHA1 == proximo_v1) && (SENHA2 == proximo_v2) && (SENHA3 == proximo_v3) && (SENHA4 == proximo_v4)) begin
                    proximo_estado = LIBERADO;
                    proximo_tempo = TEMPO_LIBERADO;
                end
                else begin
                    proximo_estado = NAO_LIBERADO;
                    proximo_tempo = TEMPO_NAO_LIBERADO;
                end
            end
        end

        LIBERADO, NAO_LIBERADO: begin
            if (tempo_atual > 0) proximo_tempo = tempo_atual - 1;
            else begin
                proximo_v1 = 4'd0;
                proximo_v2 = 4'd0;
                proximo_v3 = 4'd0;
                proximo_v4 = 4'd0;
                proximo_estado = S0;
            end
        end
        default: proximo_estado = S0;
    endcase
end

// as logicas de leds para se for liberado ou não
always_comb begin
    liberado = (estado_atual == LIBERADO);
    nao_liberado = (estado_atual == NAO_LIBERADO);

    unique case (estado_atual)
        S0: contador = 3'd1;
        S1: contador = 3'd2;
        S2: contador = 3'd3;
        S3: contador = 3'd4;
        default: contador = 3'd1;
    endcase
end

// definições dos leds e displays na FPGA
always_comb begin
    LEDG = {8{liberado}}; // LEDs verdes
    LEDR = {18{nao_liberado}}; // LEDs vermelhos

    HEX4 = decodifica_7seg({1'b0, contador}); // 1º display (esquerda): posição
    HEX3 = decodifica_7seg(v1);
    HEX2 = decodifica_7seg(v2);
    HEX1 = decodifica_7seg(v3);
    HEX0 = decodifica_7seg(v4); // último display (direita)
end

endmodule
