/************************************
This module is the Timestamp Counter.

This module counts the number of clock
cycles that have passed.
*************************************/
module timestamp_counter #(
    parameter TIMESTAMP_WIDTH = 32
)(
    input logic clk,
    input logic reset,
    input logic enable,
    output logic [TIMESTAMP_WIDTH-1:0] timestamp
);

always_ff @(posedge clk) begin

    if (reset) begin
        timestamp <= '0;
    end

    else if (enable) begin
        timestamp <= timestamp + 1'b1;
    end

end

endmodule