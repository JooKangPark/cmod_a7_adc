module adc_if (
    input  wire       clk,
    input  wire       rst,
    input  wire       vauxp,
    input  wire       vauxn,
    output reg [11:0] data_out,
    output reg        data_valid
);

    reg  [6:0]  daddr_in;
    wire        enable;
    wire [15:0] do_out;
    wire        drdy_out;

    localparam [6:0] CH_ADDR = 7'h14; // VAUX4 address

    wire clk_100m;
    wire clk_locked;

    clk_wiz_0 u_clk_wiz_0 (
    .clk_in1	(clk),
    .clk_out1	(clk_100m),
    .locked		(clk_locked)
	);

    wire xadc_rst = rst | ~clk_locked;

    xadc_wiz_0 u_xadc (
        .dclk_in   (clk_100m),
        .reset_in  (xadc_rst),

        // DRP ports
        .daddr_in  (daddr_in),  // input, Address bus
        .den_in    (enable),    // input, Enable signal
        .di_in     (16'h0000),  // input, Input data bus (DRP), not use
        .do_out    (do_out),    // output, Data out, [15:4], total 16 bits
        .drdy_out  (drdy_out),  // output, Data ready
        .dwe_in    (1'b0),      // input, Write enable, not use

        // Only declare these if you want to use pins 15 and 16 as single ended analog inputs. pin 15 -> vaux4, pin16 -> vaux12
        .vauxp4    (vauxp),     // input, VAUX positive pin
        .vauxn4    (vauxn),     // input, VAUX negative pin

        .eoc_out   (enable)     // output, end of conversion, wiring with den_in

        // .channel_out (),
        // .eos_out   (),          // end of sequence
        // .alarm_out (),          // alarm out
        // .vp_in     (1'b0),      // analog in (positive)
        // .vn_in     (1'b0)       // analog in (negative)
    );

    // 100 MHz domain
    reg [11:0] sample_buf_100m;
    reg        sample_toggle_100m;

    always @(posedge clk_100m) begin
        if (xadc_rst) begin
            daddr_in           <= CH_ADDR;
            sample_buf_100m    <= 12'd0;
            sample_toggle_100m <= 1'b0;
        end else begin
            daddr_in <= CH_ADDR;

            if (drdy_out) begin
                sample_buf_100m    <= do_out[15:4];
                sample_toggle_100m <= ~sample_toggle_100m;
            end
        end
    end

    // 12 MHz domain
    reg sync1, sync2, sync2_d;

    always @(posedge clk) begin
        if (rst) begin
            sync1      <= 1'b0;
            sync2      <= 1'b0;
            sync2_d    <= 1'b0;
            data_out   <= 12'd0;
            data_valid <= 1'b0;
        end else begin
            sync1      <= sample_toggle_100m;
            sync2      <= sync1;
            sync2_d    <= sync2;
            data_valid <= 1'b0;

            if (sync2 ^ sync2_d) begin
                data_out   <= sample_buf_100m;
                data_valid <= 1'b1;
            end
        end
    end

endmodule