module trigger_gate (
    input  wire        clk,
    input  wire        rst,             // active high
    input  wire [11:0] data_in,
    input  wire        data_valid_in,
    input  wire [11:0] threshold,

    output reg  [11:0] data_out,
    output reg         data_valid_out
);

    always @(posedge clk) begin
        if (rst) begin
            data_out       <= 12'd0;
            data_valid_out <= 1'b0;
        end else begin
            data_valid_out <= 1'b0;

            if (data_valid_in && (data_in >= threshold)) begin
                data_out       <= data_in;
                data_valid_out <= 1'b1;
            end
        end
    end

endmodule
