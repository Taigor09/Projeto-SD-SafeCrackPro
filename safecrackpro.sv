module safecrackpro_fsm #( // Paramêtros -> configurações fixas
    // digits[0] = 1º dígito (HEX3) ... digits[3] = 4º dígito (HEX0)
    // Senha padrão: 1-2-3-4
    // Bloco de hardware com entradas e saídas que funciona como um chip
    parameter logic [3:0][3:0] SENHA = {4'd4, 4'd3, 4'd2, 4'd1},
    parameter int FREQ_CLOCK  = 50_000_000,
    parameter int GREEN_SEC = 5, // segundos que o led verde fica acesso -> 5
    parameter int RED_SEC   = 3  // led vermelho -> 3
)( // inputs são como "fios" que ligam o módulo ao "mundo externo"
    input  logic        clk, // clock(sincroniza)
    input  logic        rstn, // reset, o "n" indica que é resetado quando apertado               // KEY[0] (ativo baixo, assíncrono)
    input  logic [2:0]  btn, // os 3 botões                  // btn[0]=KEY1, btn[1]=KEY2, btn[2]=KEY3 (ativos baixo)
    output logic [3:0][3:0] digitos, // os 4 dígitos que são mostrados no display, 4 grupos de 4 bits -> 4 dígitos com 4 bits cada
    output logic [1:0]  posicao_atual, //qual dígito está sendo editado
    output logic [17:0] led_red, //led
    output logic [8:0]  led_green //led
);

    localparam int GREEN_TIME = GREEN_SEC * FREQ_CLOCK;
    localparam int RED_TIME   = RED_SEC   * FREQ_CLOCK;
    localparam int CNT_W      = $clog2(GREEN_TIME + 1);
    
    typedef enum logic [1:0] { //3 estados que a finite state machine está:
        ENTRY      = 2'b00,   // edição dos dígitos -> digitando...
        WAIT_GREEN = 2'b01,   // senha correta: LEDs verdes -> senha correta
        WAIT_RED   = 2'b10    // senha errada: LEDs vermelhos -> senha incorreta
    } state_t;

    state_t estado_atual, proximo_estado;

    logic [3:0][3:0]  proximos_digitos; // guarda o valor que os digitos terão no próximo pulso do clock
    logic [1:0]       proxima_posicao; // guarda a posicao que estará sendo editada no próximo pulso
    logic [CNT_W-1:0] led_time_cnt, next_led_time_cnt; // valor do contador de tempo dos leds

    // ---------------- detecção de borda dos botões ----------------
    logic [2:0] btn_pos, btn_prev, btn_edge; // o código inverte, agora 1 = apertado, cada aperto gera um único pulso, no instante que o botão desce

    always_comb begin // código inverte e cada aperto gera um único pulso
        btn_pos  = ~btn;                 // ativo alto
        btn_edge = btn_pos & ~btn_prev;  // borda 0 -> 1
    end

    wire edge_confirm = btn_edge[0];  // KEY[1] -> confirma o dígito
    wire edge_inc     = btn_edge[1];  // KEY[2] -> incrementa o dígito
    wire edge_dec     = btn_edge[2];  // KEY[3] -> decrementa o dígito

    // ---------------- registradores ----------------
    // ff vem de flipflop
    always_ff @(posedge clk or negedge rstn) begin // memória, a cada subida do clock copie os valores para os registradores
        if (~rstn) begin // reset : volta tudo ao início
            btn_prev             <= 3'b000; // atribuir no próximo pulso do relógio
            estado_atual         <= ENTRY;
            digitos              <= '0;
            posicao_atual        <= 2'd0;
            led_time_cnt         <= '0;
        end else begin
            btn_prev             <= btn_pos;
            estado_atual         <= proximo_estado;
            digitos              <= proximos_digitos;
            posicao_atual        <= proxima_posicao;
            led_time_cnt         <= next_led_time_cnt;
        end
    end

    // ---------------- lógica de próximo estado ----------------
    always_comb begin // logica combinacional
        proximo_estado        = estado_atual; // código decide o que o próximo estado deve ser
        proximos_digitos       = digitos;
        proxima_posicao          = posicao_atual;
        next_led_time_cnt = led_time_cnt;

        unique case (estado_atual) // casos que podem acontecer
            ENTRY: begin
                if (edge_inc) begin //botão de incremento [key2]
                    proximos_digitos[posicao_atual] =
                        (digitos[posicao_atual] == 4'd9) ? 4'd0 // se o digito é 9 o proximo vale zero, senão vale o digito + 1
                                                               : digitos[posicao_atual] + 4'd1;
                end else if (edge_dec) begin //botão de decremento [key3]
                    proximos_digitos[posicao_atual] =
                        (digitos[posicao_atual] == 4'd0) ? 4'd9 // mesma ideia só que ao contrário
                                                               : digitos[posicao_atual] - 4'd1;
                end else if (edge_confirm) begin //botão de confirmar [key1] 
                    if (posicao_atual == 2'd3) begin
                        // 4º dígito confirmado: verifica a senha
                        if (digitos == SENHA) begin
                            proximo_estado        = WAIT_GREEN;
                            next_led_time_cnt = CNT_W'(GREEN_TIME - 1);
                        end else begin
                            proximo_estado        = WAIT_RED;
                            next_led_time_cnt = CNT_W'(RED_TIME - 1);
                        end
                    end else begin
                        proxima_posicao = posicao_atual + 2'd1; // se não for o 4° dígito
                    end
                end
            end

            WAIT_GREEN, WAIT_RED: begin
                if (led_time_cnt == '0) begin
                    proximo_estado  = ENTRY;
                    proximos_digitos = '0;
                    proxima_posicao    = 2'd0;
                end else begin
                    next_led_time_cnt = led_time_cnt - 1'b1;
                end
            end

            default: proximo_estado = ENTRY;
        endcase
    end

    // ---------------- saídas ----------------
    always_comb begin
        led_green = (estado_atual == WAIT_GREEN) ? 9'h1FF   : 9'h000;
        led_red   = (estado_atual == WAIT_RED)   ? 18'h3FFFF : 18'h00000;
    end

endmodule