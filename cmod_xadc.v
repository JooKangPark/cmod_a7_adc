module adc_if (
    input  wire       clk_100m,
    input  wire       clk_locked,
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

    wire xadc_rst = rst | ~clk_locked;

    xadc_wiz_0 u_xadc (
        .dclk_in   (clk_100m),
        .reset_in  (xadc_rst),

        .daddr_in  (daddr_in),
        .den_in    (enable),
        .di_in     (16'h0000),
        .do_out    (do_out),
        .drdy_out  (drdy_out),
        .dwe_in    (1'b0),

        .vauxp4    (vauxp),
        .vauxn4    (vauxn),

        .eoc_out   (enable)
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
