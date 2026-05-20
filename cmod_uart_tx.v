module uart_tx #(
    parameter integer CLK_FREQ_HZ = 12_000_000,
    parameter integer BAUD_RATE   = 115200
)(
    input  wire       clk,
    input  wire       rst,       // active high
    input  wire [7:0] data_in,
    input  wire       send,      // 1-cycle pulse
    output reg        tx,
    output reg        busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ_HZ / BAUD_RATE;

    reg [15:0] clk_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  data_buf;

    always @(posedge clk) begin
        if (rst) begin
            tx      <= 1'b1;   // idle
            busy    <= 1'b0;
            clk_cnt <= 16'd0;
            bit_idx <= 4'd0;
            data_buf<= 8'd0;
        end else begin
            if (!busy) begin
                tx <= 1'b1; // idle high

                if (send) begin
                    busy    <= 1'b1;
                    data_buf<= data_in;
                    clk_cnt <= 16'd0;
                    bit_idx <= 4'd0;
                    tx      <= 1'b0; // start bit
                end
            end else begin
                if (clk_cnt == CLKS_PER_BIT - 1) begin
                    clk_cnt <= 16'd0;

                    case (bit_idx)
                        4'd0: begin tx <= data_buf[0]; bit_idx <= 4'd1; end
                        4'd1: begin tx <= data_buf[1]; bit_idx <= 4'd2; end
                        4'd2: begin tx <= data_buf[2]; bit_idx <= 4'd3; end
                        4'd3: begin tx <= data_buf[3]; bit_idx <= 4'd4; end
                        4'd4: begin tx <= data_buf[4]; bit_idx <= 4'd5; end
                        4'd5: begin tx <= data_buf[5]; bit_idx <= 4'd6; end
                        4'd6: begin tx <= data_buf[6]; bit_idx <= 4'd7; end
                        4'd7: begin tx <= data_buf[7]; bit_idx <= 4'd8; end
                        4'd8: begin
                            tx      <= 1'b1; // stop bit
                            bit_idx <= 4'd9;
                        end
                        4'd9: begin
                            tx      <= 1'b1;
                            busy    <= 1'b0;
                            bit_idx <= 4'd0;
                        end
                        default: begin
                            tx      <= 1'b1;
                            busy    <= 1'b0;
                            bit_idx <= 4'd0;
                        end
                    endcase
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end
            end
        end
    end

endmodule