// modulo chamao de Safecrack_pro , basicamente é um bloco de hardware  com entradas e saidas 
// tudo que estiver dentro do modulo são as portas , ou seja os "fios" que ligam o modulo ao resto do circuito
module safecrackpro_fsm (
    input logic clk, // entrada de um bit com o clock, ou seja a FSM só muda de estado nas bordas desse sinal 
    input logic [3:0] btn, // entrada de 4 bits , uma para cada botão da placa , que correspondem as KEYS 

    // Armazena os quatro dígitos da senha.
    // Cada posição utiliza 4 bits e começa com valor zero.
    output logic [3:0][3:0] digits = '0, //  aqui temos a saida que guarda a senha digitada pelo usuario 

    // Indica qual dos quatro dígitos está selecionado.
    // O índice interno varia de 0 a 3 e começa na primeira posição.
    output logic [1:0] current_position_idx = '0,

    // Saídas utilizadas para sinalizar o resultado da tentativa.
    output logic [17:0] led_red,
    output logic [8:0] led_green
);

    // ============================
    // DEFINIÇÃO DOS ESTADOS DA FSM
    // ============================

    // Cada estado representa uma etapa do funcionamento do cofre:
    // CONFIGURANDO: permite alterar e confirmar os dígitos da senha.
    // VERIFICANDO: compara a senha inserida com a senha correta.
    // DESBLOQUEADO: indica que a senha foi inserida corretamente.
    // BLOQUEADO: indica que a senha inserida está incorreta.
    typedef enum logic [1:0] {
        CONFIGURANDO,
        VERIFICANDO,
        DESBLOQUEADO,
        BLOQUEADO
    } estado_t;

    // O estado inicial é CONFIGURANDO, garantindo que o sistema
    // comece aguardando a entrada de uma nova senha.
    estado_t state = CONFIGURANDO;

    // Armazena o estado para o qual a FSM deverá avançar.
    estado_t next_state;

    // ===============================
    // DEFINIÇÃO DA SENHA E DOS BOTÕES
    // ===============================

    // Senha correta do cofre: 1-2-3-4.
    // Como a concatenação coloca o elemento mais significativo
    // à esquerda, digits[0] corresponde ao primeiro dígito (1),
    // enquanto digits[3] corresponde ao último dígito (4).
    localparam logic [3:0][3:0] SENHA = {
        4'd4, 4'd3, 4'd2, 4'd1
    };

    // Índices dos botões utilizados para controlar a entrada da senha.
    // btn[0] é reservado exclusivamente para o reset (KEY0).
    // btn[1] confirma o dígito (KEY1).
    // btn[2] incrementa o dígito (KEY2).
    // btn[3] decrementa o dígito (KEY3).
    localparam int BTN_CONFIRMAR = 1;
    localparam int BTN_INCREMENTAR = 2;
    localparam int BTN_DECREMENTAR = 3;

    // ========================
    // REGISTRADORES AUXILIARES
    // ========================

    // Armazena o estado anterior dos três botões de comando.
    // O valor inicial 111 representa todos os botões soltos,
    // considerando que os push buttons da placa são ativos em nível baixo.
    logic [3:1] btn_prev = 3'b111;

    // Indica se ocorreu uma borda de pressionamento em cada botão.
    logic [3:1] btn_edge;

    // Resultado da comparação entre a senha inserida e a senha correta.
    logic senha_correta;

    // Contador utilizado para controlar o tempo de sinalização dos LEDs.
    // Começa em zero para que a contagem seja iniciada somente
    // quando o sistema entrar nos estados DESBLOQUEADO ou BLOQUEADO.
    logic [31:0] timer_count = '0;

    // ===================================
    // DEFINIÇÃO DOS TEMPOS DE SINALIZAÇÃO
    // ===================================

    // Os valores consideram a frequência de clock de 50 MHz da DE2-115.
    // 250.000.000 ciclos em 5 segundos.
    // 150.000.000 ciclos em 3 segundos.
    localparam logic [31:0] TEMPO_DESBLOQUEADO = 32'd250000000;
    localparam logic [31:0] TEMPO_BLOQUEADO = 32'd150000000;

    // ============================
    // DETECÇÃO DE BORDA DOS BOTÕES
    // ============================

    // Atualiza o histórico dos botões na borda de subida do clock.
    // O reset assíncrono pelo KEY0 também restaura o histórico
    // para 111, indicando que todos os botões estão soltos.
    always_ff @(posedge clk or negedge btn[0]) begin
        if (!btn[0])
            btn_prev <= 3'b111;
        else
            btn_prev <= btn[3:1];
    end

    // Os botões são ativos em nível baixo:
    // 1 representa botão solto e 0 representa botão pressionado.
    //
    // A expressão identifica a transição de 1 para 0, comparando
    // o estado atual dos botões com o estado armazenado anteriormente.
    // Dessa forma, a ação ocorre uma única vez por pressionamento,
    // sem se repetir enquanto o botão permanecer pressionado.
    always_comb begin
        btn_edge = ~btn[3:1] & btn_prev;
    end

    // =============================
    // CONTROLE DOS DÍGITOS DA SENHA
    // =============================

    // Controla os valores dos quatro dígitos e a posição
    // atualmente selecionada pelo usuário.
    always_ff @(posedge clk or negedge btn[0]) begin

        // O KEY0 realiza o reset assíncrono, independentemente
        // do clock, restaurando todos os dígitos para zero
        // e selecionando novamente a primeira posição.
        if (!btn[0]) begin
            digits <= '0;
            current_position_idx <= '0;
        end

        // Quando termina o tempo de sinalização do resultado,
        // os dígitos são apagados e a seleção retorna à primeira posição.
        else if ((state == DESBLOQUEADO && timer_count >= TEMPO_DESBLOQUEADO) || (state == BLOQUEADO && timer_count >= TEMPO_BLOQUEADO)) 
        begin
            digits <= '0;
            current_position_idx <= '0;
        end

        else begin

            // Incrementa o valor do dígito atualmente selecionado.
            // Ao atingir 9, o próximo incremento retorna o valor para 0.
            if (state == CONFIGURANDO && btn_edge[BTN_INCREMENTAR]) begin
                if (digits[current_position_idx] == 4'd9)
                    digits[current_position_idx] <= 4'd0;
                else
                    digits[current_position_idx] <= digits[current_position_idx] + 4'd1;
            end

            // Decrementa o valor do dígito atualmente selecionado.
            // Ao atingir 0, o próximo decremento retorna o valor para 9.
            else if (state == CONFIGURANDO && btn_edge[BTN_DECREMENTAR]) begin
                if (digits[current_position_idx] == 4'd0)
                    digits[current_position_idx] <= 4'd9;
                else
                    digits[current_position_idx] <= digits[current_position_idx] - 4'd1;
            end

            // Confirma o dígito atual e avança para a próxima posição.
            // O índice só é incrementado enquanto for diferente de 3,
            // evitando ultrapassar a última das quatro posições.
            else if (state == CONFIGURANDO && btn_edge[BTN_CONFIRMAR]) begin
                if (current_position_idx != 2'd3)
                    current_position_idx <= current_position_idx + 2'd1;
            end
        end
    end

    // ====================
    // VERIFICAÇÃO DA SENHA
    // ====================
    // Esse bloco consiste basicamente em definir o que é a senha correta.
    // Nesse caso é quando os digitos são iguais a senha pré-definida como a certa.
    always_comb begin
        senha_correta = (digits == SENHA); // compara os 16 bits de digits com os da senha e ve se é true ou false.
    end

    // ===============================
    // LÓGICA DE TRANSIÇÃO DOS ESTADOS
    // ===============================
    // esse bloco é a toda a lógica de transição dos valores e de estados
    // para os próximos. Vale então o de configuração para o de verificação e os estados de 
    // desbloqueado ou bloqueado para o estado incial do sistema.
    always_comb begin
        next_state = state; // próximo estado vai ser igual ao estado atual

        // Aqui vai a checagem para saber se o estado atual é o de configuração e se o index da lógica de posição
        // atual é 3 (no caso aqui o ultimo), ele irá para o estado de verificação.
        if (state == CONFIGURANDO && current_position_idx == 2'd3 && btn_edge[BTN_CONFIRMAR]) begin
            next_state = VERIFICANDO;
        end

        // No estado de verificação basta somente checar se a senha está correta
        // ou não e partir disso ir para um dos dois estados de desbloqueado ou bloqueado.
        else if (state == VERIFICANDO) begin
            if (senha_correta)
                next_state = DESBLOQUEADO;
            else
                next_state = BLOQUEADO;
        end

        // Se o usuario pós a senha e foi correta, a coisa lógica a se fazer é
        // após terminado o tempo de desbloqueio o sistema voltar ao estado inicial com
        // tudo zerado
        else if (state == DESBLOQUEADO && timer_count >= TEMPO_DESBLOQUEADO) begin
            next_state = CONFIGURANDO;
        end

        // Mesma ideia do desbloqueado so que para o bloqueado.
        else if (state == BLOQUEADO && timer_count >= TEMPO_BLOQUEADO) begin
            next_state = CONFIGURANDO;
        end
    end

    // ===========================
    // REGISTRADOR DO ESTADO ATUAL
    // ===========================

    // esse é o bloco de flip-flops que constantemente atualiza as portas lógicas,
    // o sistema de modo geral ou reseta tudo caso seja apertada a KEY0 que é o botão de
    // reset do nosso módulo.
    always_ff @(posedge clk or negedge btn[0]) begin
        if (!btn[0]) // negação pois o aperto do botão para a FPGA significa 0, quando solto é 1.
            state <= CONFIGURANDO; // Logo ao apertar o reset o sistema é totalmente atualizado pelos flip-flops pelo estado inicial.
        else // enquanto não for apertado o reset, as portas continuaram sendo atualizadas com os próximos estados.
            state <= next_state;
    end

    // =================
    // CONTROLE DOS LEDS
    // =================

    // Quando a senha está correta e a FSM está no estado DESBLOQUEADO,
    // todos os LEDs verdes são acionados simultaneamente.
    // Nos demais estados, todos permanecem apagados.
    always_comb begin
        if (state == DESBLOQUEADO)
            led_green = '1;
        else
            led_green = '0;
    end

    // Quando a senha está incorreta e a FSM está no estado BLOQUEADO,
    // todos os LEDs vermelhos são acionados simultaneamente.
    // Nos demais estados, todos permanecem apagados.
    always_comb begin
        if (state == BLOQUEADO)
            led_red = '1;
        else
            led_red = '0;
    end

    // ===========================
    // TEMPORIZADOR DA SINALIZAÇÃO
    // ===========================

    // Conta os ciclos de clock enquanto o sistema sinaliza
    // o resultado da tentativa por meio dos LEDs.
    //
    // No estado DESBLOQUEADO, a contagem corresponde a 5 segundos.
    // No estado BLOQUEADO, a contagem corresponde a 3 segundos.
    //
    // Ao atingir o tempo definido, o contador é zerado.
    // Nos demais estados, permanece zerado, aguardando uma nova tentativa.
    always_ff @(posedge clk or negedge btn[0]) begin
        if (!btn[0])
            timer_count <= '0;

        else if (
            (state == DESBLOQUEADO && timer_count >= TEMPO_DESBLOQUEADO) ||
            (state == BLOQUEADO && timer_count >= TEMPO_BLOQUEADO)
        )
            timer_count <= '0;

        else if (state == DESBLOQUEADO || state == BLOQUEADO)
            timer_count <= timer_count + 32'd1;

        else
            timer_count <= '0;
    end

endmodule


// ============================================================
// bcd_to_7segment_anodo.sv
// ============================================================

// Módulo responsável por converter um número de 0 a 9
// em sinais que representam os segmentos de um display de 7 segmentos.
module bcd_to_7segment_anodo (

    // Recebe o número em formato BCD, utilizando 4 bits.
    input logic [3:0] bcd,

    // Envia os sinais que controlam os 7 segmentos do display.
    output logic [6:0] seg
);

    // Define quais segmentos devem acender de acordo com o número recebido.
    always_comb begin
        case (bcd)

            // Cada combinação representa um número de 0 a 9.
            // Como o display é de ânodo comum, os segmentos são ativos em nível baixo:
            // 0 acende o segmento e 1 mantém o segmento apagado.

            4'd0: seg = 7'b1000000; // Exibe o número 0.
            4'd1: seg = 7'b1111001; // Exibe o número 1.
            4'd2: seg = 7'b0100100; // Exibe o número 2.
            4'd3: seg = 7'b0110000; // Exibe o número 3.
            4'd4: seg = 7'b0011001; // Exibe o número 4.
            4'd5: seg = 7'b0010010; // Exibe o número 5.
            4'd6: seg = 7'b0000010; // Exibe o número 6.
            4'd7: seg = 7'b1111000; // Exibe o número 7.
            4'd8: seg = 7'b0000000; // Exibe o número 8.
            4'd9: seg = 7'b0010000; // Exibe o número 9.

            // Caso seja recebido um valor diferente de 0 a 9,
            // mantém o display em branco.
            default: seg = 7'b1111111;

        endcase
    end

endmodule


// ============================================================
// safecrackpro_top.sv
// ============================================================

// Módulo principal do SafeCrack Pro.
// Responsável por conectar a lógica do cofre aos componentes físicos da DE2-115.
module safecrackpro_top (

    // Clock principal da placa.
    input logic clk,

    // Vetor dos quatro push buttons da placa.
    // Todos são ativos em nível baixo.
    input logic [3:0] btn,

    // Displays de 7 segmentos utilizados para mostrar os dígitos da senha.
    output logic [6:0] HEX0,
    output logic [6:0] HEX1,
    output logic [6:0] HEX2,
    output logic [6:0] HEX3,

    // Display que indica a posição atualmente selecionada.
    output logic [6:0] HEX4,

    // LEDs vermelhos e verdes utilizados para indicar o resultado da tentativa.
    output logic [17:0] led_red,
    output logic [8:0] led_green
);

    // =====================================================
    // SINAIS INTERNOS
    // =====================================================

    // Armazena os quatro dígitos que compõem a senha.
    // Cada dígito utiliza 4 bits, permitindo representar valores de 0 a 9.
    logic [3:0][3:0] digits;

    // Armazena a posição atualmente selecionada na entrada da senha.
    // Os índices utilizados internamente vão de 0 a 3.
    logic [1:0] current_position_idx;


    // =====================================================
    // INSTÂNCIA DA MÁQUINA DE ESTADOS
    // =====================================================

    // Conecta a máquina de estados ao módulo principal.
    // Ela controla os botões, os dígitos, a verificação da senha e os LEDs.
    safecrackpro_fsm fsm_inst (
        .clk(clk),
        .btn(btn),
        .digits(digits),
        .current_position_idx(current_position_idx),
        .led_red(led_red),
        .led_green(led_green)
    );

    // =====================================================
    // CONEXÃO DOS DISPLAYS DA SENHA
    // =====================================================

    // Cada instância do decodificador recebe um dos dígitos
    // armazenados na FSM e converte seu valor para os segmentos do display.

    // HEX3 exibe o primeiro dígito da senha.
    bcd_to_7segment_anodo dec_hex3 (
        .bcd(digits[0]),
        .seg(HEX3)
    );

    // HEX2 exibe o segundo dígito da senha.
    bcd_to_7segment_anodo dec_hex2 (
        .bcd(digits[1]),
        .seg(HEX2)
    );

    // HEX1 exibe o terceiro dígito da senha.
    bcd_to_7segment_anodo dec_hex1 (
        .bcd(digits[2]),
        .seg(HEX1)
    );

    // HEX0 exibe o quarto dígito da senha.
    bcd_to_7segment_anodo dec_hex0 (
        .bcd(digits[3]),
        .seg(HEX0)
    );

    // =====================================================
    // INDICAÇÃO DA POSIÇÃO ATIVA (HEX4)
    // =====================================================

    // A posição interna utiliza índices de 0 a 3.
    // Somamos 1 para exibir as posições de 1 a 4 no HEX4.
    bcd_to_7segment_anodo dec_hex4 (
        .bcd({2'b00, current_position_idx} + 4'd1),
        .seg(HEX4)
    );

endmodule
