/**********************************************
This is the fault capture module

This assigns faults to a specific timestamp.
**********************************************/
module fault_capture #(
    parameter DATA_WIDTH = 64,
    parameter BUFFER_DEPTH = 64,
    parameter TIMESTAMP_WIDTH = 32
)(
    input logic clk,
    input logic reset,
    input logic clear_fault,
    input logic adc_0_fault_above,
    input logic adc_0_fault_below,
    input logic adc_1_fault_above,
    input logic adc_1_fault_below,
    input logic adc_2_fault_above,
    input logic adc_2_fault_below,
    input logic digital_fault,
    input logic serial_fault_0,
    input logic serial_fault_1,
    input logic [TIMESTAMP_WIDTH-1:0] timestamp,
    input logic signed [15:0] adc_sample_0,
    input logic signed [15:0] adc_sample_1,
    input logic signed [15:0] adc_sample_2,
    input logic [3:0] digital_input,
    input logic serial_input_0,
    input logic serial_input_1,

    output logic fault_triggered,
    output logic capture_complete,
    output logic [TIMESTAMP_WIDTH-1:0] fault_timestamp  
);

localparam ADDRESS_WIDTH = $clog2(BUFFER_DEPTH);
localparam COUNT_WIDTH = $clog2(BUFFER_DEPTH / 2);
logic [COUNT_WIDTH-1:0] post_fault_count;
logic [DATA_WIDTH-1:0] capture_memory [0:BUFFER_DEPTH-1]; //Stores all captured samples
logic [DATA_WIDTH-1:0] sample_data;
logic [ADDRESS_WIDTH-1:0] buffer_index; // Which memory location to write to next
logic any_fault;


assign any_fault = adc_0_fault_above ||
                   adc_0_fault_below ||
                   adc_1_fault_above ||
                   adc_1_fault_below ||
                   adc_2_fault_above ||
                   adc_2_fault_below ||
                   digital_fault ||
                   serial_fault_0 ||
                   serial_fault_1;

always_comb begin
    
    sample_data = '0;

    // Define entire signal
    sample_data[15:0] = adc_sample_0;
    sample_data[31:16] = adc_sample_1;
    sample_data[47:32] = adc_sample_2;
    sample_data[51:48] = digital_input;
    sample_data[52] = serial_input_0;
    sample_data[53] = serial_input_1;
    sample_data[54] = adc_0_fault_above;
    sample_data[55] = adc_0_fault_below;
    sample_data[56] = adc_1_fault_above;
    sample_data[57] = adc_1_fault_below;
    sample_data[58] = adc_2_fault_above;
    sample_data[59] = adc_2_fault_below;
    sample_data[60] = digital_fault;
    sample_data[61] = serial_fault_0;
    sample_data[62] = serial_fault_1;

end

always_ff @(posedge clk) begin

    if (reset || clear_fault) begin

        fault_triggered <= 1'b0;
        fault_timestamp <= '0;

    end

    else if (!fault_triggered && any_fault) begin

        fault_triggered <= 1'b1;
        fault_timestamp <= timestamp;

    end
end

always_ff @(posedge clk) begin

    if (reset || clear_fault) begin

        buffer_index <= '0;
        post_fault_count <= '0;
        capture_complete <= 1'b0;

    end

    else if (!capture_complete) begin

        capture_memory[buffer_index] <= sample_data;

        if (buffer_index == BUFFER_DEPTH - 1) begin
            buffer_index <= '0;
        end

        else begin
            buffer_index <= buffer_index + 1'b1;
        end

        if (fault_triggered) begin

            if (post_fault_count == (BUFFER_DEPTH / 2) - 2) begin

                capture_complete <= 1'b1;

            end

            else begin

                post_fault_count <= post_fault_count + 1'b1;

            end

        end

    end

end

endmodule




