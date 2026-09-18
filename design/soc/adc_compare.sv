/************************************************************
This module is the ADC Comparator

This module determines when an ADC sample goes above or below
the configured threshold values.

Threshold values will be configured by firmware and stored in
programmable registers.
**************************************************************/

module adc_compare #(
    parameter DATA_WIDTH = 16
)(
    input logic signed [DATA_WIDTH - 1:0] sample_reading,
    input logic signed [DATA_WIDTH - 1:0] upper_threshold,
    input logic signed [DATA_WIDTH - 1:0] lower_threshold,
    input logic enable,

    output logic fault_above,
    output logic fault_below,
    output logic fault
);

always_comb begin

    fault_above = 1'b0;
    fault_below = 1'b0;
    fault = 1'b0;

    if (enable) begin
        if (sample_reading > upper_threshold) begin
            fault = 1'b1;
            fault_above = 1'b1;
        end

        else if (sample_reading < lower_threshold) begin
            fault = 1'b1;
            fault_below = 1'b1;
        end
    end

end

endmodule 