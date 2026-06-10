module top (
    input  wire        clk_12m,
    input  wire        rst,     // btn 1, active high
    input  wire        vauxp,
    input  wire        vauxn,   // for VAUX4 negative input
    output wire        tx,
    output reg         done     // Peak detection signal
);

// ============================================================
// Clocking
// Board clock: 12 MHz
// Internal system clock: 100 MHz
// ============================================================
wire clk_100m;
wire clk_locked;

clk_wiz_0 u_clk_wiz_0 (
    .clk_in1  (clk_12m),
    .clk_out1 (clk_100m),
    .locked   (clk_locked)
);

// All 100 MHz-domain logic should stay reset until clk_wiz is locked
wire sys_rst = rst | ~clk_locked;

// ============================================================
// ADC interface
// ============================================================
wire [11:0] adc_data;
wire        adc_valid;

adc_if u_adc_if (
    .clk_100m   (clk_100m),
    .clk_locked (clk_locked),
    .rst        (rst),
    .vauxp      (vauxp),
    .vauxn      (vauxn),
    .data_out   (adc_data),
    .data_valid (adc_valid)
);

// ============================================================
// Trigger gate
// ============================================================
localparam [11:0] THRESHOLD = 12'd512;

wire [11:0] trig_data;
wire        trig_valid;

trigger_gate u_trigger_gate (
    .clk            (clk_100m),
    .rst            (sys_rst),
    .data_in        (adc_data),
    .data_valid_in  (adc_valid),
    .threshold      (THRESHOLD),
    .data_out       (trig_data),
    .data_valid_out (trig_valid)
);

// ============================================================
// Peak Detection Logic
// ============================================================
reg [11:0] prev_adc_data;
reg        tracking_active;

always @(posedge clk_100m) begin
    if (sys_rst) begin
        prev_adc_data   <= 12'd0;
        tracking_active <= 1'b0;
        done            <= 1'b0;
    end else begin
        // 매 클럭마다 기본적으로 0으로 초기화하여 1-cycle pulse 구현
        done <= 1'b0; 

    // Trigger 발생: tracking 시작
    if (trig_valid && !tracking_active) begin
        tracking_active <= 1'b1;
        prev_adc_data   <= trig_data;
        // 이곳에서는 done 신호를 발생시키지 않음
    end 
    // Tracking 중: 들어오는 ADC 데이터 비교
    else if (tracking_active && adc_valid) begin
        if (adc_data < prev_adc_data) begin
            // Peak 통과 (값이 감소): done 신호를 1사이클 동안 1로 펄스 발생, tracking 종료
            done            <= 1'b1;
            tracking_active <= 1'b0;
        end else begin
            // 값이 여전히 상승 중이거나 같음: 최댓값 갱신
            prev_adc_data <= adc_data;
        end
    end
end
end


// ============================================================
// UART packet FSM
// ============================================================
reg  [7:0] uart_data;
reg        uart_send;
wire       uart_busy;

reg [11:0] latched_data;
reg [1:0]  event_num;

reg [1:0] state;
reg       sent_first;

localparam S_IDLE = 2'd0;
localparam S_SEND = 2'd1;
localparam S_BUSY = 2'd2;

always @(posedge clk_100m) begin
    if (sys_rst) begin
        uart_data    <= 8'd0;
        uart_send    <= 1'b0;
        latched_data <= 12'd0;
        event_num    <= 2'd0;
        state        <= S_IDLE;
        sent_first   <= 1'b0;
    end else begin
        uart_send <= 1'b0;

    case (state)
        S_IDLE: begin
            // Note: This latches the threshold-crossing value.
            // If you intend to send the peak value via UART instead, 
            // you should trigger this state transition when tracking_active drops to 0
            // and assign latched_data <= prev_adc_data.
            if (trig_valid) begin
                latched_data <= trig_data;
                sent_first   <= 1'b0;
                state        <= S_SEND;
            end
        end

        S_SEND: begin
            if (!uart_busy) begin
                if (!sent_first)
                    uart_data <= {event_num, latched_data[11:6]};
                else
                    uart_data <= {event_num, latched_data[5:0]};

                uart_send <= 1'b1;
                state     <= S_BUSY;
            end
        end

        S_BUSY: begin
            if (!uart_busy) begin
                if (!sent_first) begin
                    sent_first <= 1'b1;
                    state      <= S_SEND;
                end else begin
                    event_num <= event_num + 2'd1;
                    state     <= S_IDLE;
                end
            end
        end

        default: begin
            state <= S_IDLE;
        end
    endcase
end
end

// ============================================================
// UART TX
// ============================================================
uart_tx #(
    .CLK_FREQ_HZ(100_000_000),
    .BAUD_RATE  (115200)
) u_uart_tx (
    .clk    (clk_100m),
    .rst    (sys_rst),
    .data_in(uart_data),
    .send   (uart_send),
    .tx     (tx),
    .busy   (uart_busy)
);
endmodule
