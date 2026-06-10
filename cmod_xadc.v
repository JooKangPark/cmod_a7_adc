module adc_if (
    input  wire       clk_100m,
    input  wire       clk_locked,
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

        .vauxp4    (vauxp),
        .vauxn4    (vauxn),
        
        .eoc_out   (enable)     // output, end of conversion, wiring with den_in
    );

    always @(posedge clk_100m) begin
        if (xadc_rst) begin
            daddr_in   <= CH_ADDR;
            data_out   <= 12'd0;
            data_valid <= 1'b0;
        end else begin
            daddr_in   <= CH_ADDR;
            data_valid <= 1'b0;

            if (drdy_out) begin
                data_out   <= do_out[15:4];
                data_valid <= 1'b1;
            end
        end
    end

endmodule
