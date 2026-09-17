module digital_compare #(
    parameter DATA_WIDTH = 4
)(
    input logic [DATA_WIDTH-1:0] digital_input,
    input logic [DATA_WIDTH-1:0] fault_code_0,
    input logic [DATA_WIDTH-1:0] fault_code_1,
    input logic [DATA_WIDTH-1:0] fault_code_2,
    input logic [DATA_WIDTH-1:0] fault_code_3,
    input logic [DATA_WIDTH-1:0] fault_code_4,
    input logic [DATA_WIDTH-1:0] fault_code_5,
    input logic [DATA_WIDTH-1:0] fault_code_6,
    input logic [DATA_WIDTH-1:0] fault_code_7,
    input logic [DATA_WIDTH-1:0] fault_code_8,
    input logic [DATA_WIDTH-1:0] fault_code_9,
    input logic [DATA_WIDTH-1:0] fault_code_10,
    input logic [DATA_WIDTH-1:0] fault_code_11,
    input logic [DATA_WIDTH-1:0] fault_code_12,
    input logic [DATA_WIDTH-1:0] fault_code_13,
    input logic [DATA_WIDTH-1:0] fault_code_14,
    input logic [14:0] fault_enable,
    input logic enable,

    output logic fault
);



always_comb begin

    fault = 1'b0;

    if (enable) begin

        if ((fault_enable[0] && (digital_input == fault_code_0)) ||
            (fault_enable[1] && (digital_input == fault_code_1)) ||
            (fault_enable[2] && (digital_input == fault_code_2)) ||
            (fault_enable[3] && (digital_input == fault_code_3)) ||
            (fault_enable[4] && (digital_input == fault_code_4)) ||
            (fault_enable[5] && (digital_input == fault_code_5)) ||
            (fault_enable[6] && (digital_input == fault_code_6)) ||
            (fault_enable[7] && (digital_input == fault_code_7)) ||
            (fault_enable[8] && (digital_input == fault_code_8)) ||
            (fault_enable[9] && (digital_input == fault_code_9)) ||
            (fault_enable[10] && (digital_input == fault_code_10)) ||
            (fault_enable[11] && (digital_input == fault_code_11)) ||
            (fault_enable[12] && (digital_input == fault_code_12)) ||
            (fault_enable[13] && (digital_input == fault_code_13)) ||
            (fault_enable[14] && (digital_input == fault_code_14))) begin

            fault = 1'b1;

        end

    end

end

endmodule