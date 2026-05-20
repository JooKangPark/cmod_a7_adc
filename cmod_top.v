module top (
    input  wire        clk_12m,
    input  wire        rst, // btn 1
    input  wire        vauxp,
    input  wire        vauxn, // not use
    output wire        tx
);

    wire [11:0] adc_data;
    wire        adc_valid;

    adc_if u_adc_if (
        .clk       (clk_12m),
        .rst       (rst),
        .vauxp     (vauxp),
        .vauxn     (vauxn),
        .data_out  (adc_data),
        .data_valid(adc_valid)
    );

    localparam [11:0] THRESHOLD = 12'd512;

    wire [11:0] trig_data;
    wire        trig_valid;

    trigger_gate u_trigger_gate (
        .clk           (clk_12m),
        .rst           (rst),
        .data_in       (adc_data),
        .data_valid_in (adc_valid),
        .threshold     (THRESHOLD),
        .data_out      (trig_data),
        .data_valid_out(trig_valid)
    );

    // DEBUG
    // assign trig_data = adc_data;
    // assign trig_valid = adc_valid;

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

    always @(posedge clk_12m) begin
        if (rst) begin
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
                    // IDLE -> SEND, sent_first 0 -> BUSY, sent_first 0 to 1 -> SEND, sent_first 1 -> BUSY, sent_first 1, event num +1 -> IDLE, sent_first 1 to 0
                    if (uart_busy) begin

                    end else begin
                        if (!sent_first) begin
                            sent_first <= 1'b1;
                            state      <= S_SEND;
                        end else begin
                            event_num <= event_num + 2'd1;
                            state     <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    uart_tx #(
        .CLK_FREQ_HZ(12_000_000),
        .BAUD_RATE  (115200)
    ) u_uart_tx (
        .clk    (clk_12m),
        .rst    (rst),
        .data_in(uart_data),
        .send   (uart_send),
        // .send   (1'b1), // debug
        .tx     (tx),
        .busy   (uart_busy)
    );

endmodule