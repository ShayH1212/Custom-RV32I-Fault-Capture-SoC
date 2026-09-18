/*******************************************************
This module is the Serial Signal Comparator

This module stores the 8 most recent samples of a single
digital signal.

Once the history is full the stored samples are compared against
user desinef  fault codes.

A fault is raised when the signal history matches 
any enabled fault code.
*******************************************************/

module serial_signal_compare #(
    parameter HISTORY_WIDTH = 8
)(

input logic clk,
input logic reset,
input logic enable,
input logic sample_enable,
input logic serial_input,
input logic [HISTORY_WIDTH-1:0] fault_code_0,
input logic [HISTORY_WIDTH-1:0] fault_code_1,
input logic [HISTORY_WIDTH-1:0] fault_code_2,
input logic [HISTORY_WIDTH-1:0] fault_code_3,
input logic [HISTORY_WIDTH-1:0] fault_code_4,
input logic [HISTORY_WIDTH-1:0] fault_code_5,
input logic [HISTORY_WIDTH-1:0] fault_code_6,
input logic [HISTORY_WIDTH-1:0] fault_code_7,
input logic  [7:0] fault_enable,

output logic [HISTORY_WIDTH-1:0] signal_history,
output logic fault

);

logic [3:0] sample_count;
logic history_full; // determines how many samples are needed to collect 
 
always_ff @(posedge clk) begin

    if (reset) begin
        signal_history <= '0;
        sample_count <= 4'b0000;
        history_full <= 1'b0;
    end

    else if (enable && sample_enable) begin

        signal_history <= { signal_history[HISTORY_WIDTH-2:0], serial_input}; // shift logic

        if(!history_full) begin

            if(sample_count == HISTORY_WIDTH - 1) begin

                history_full <= 1'b1;

            end

            else begin
                
                sample_count <= sample_count + 1'b1;

            end

        end

    end

end

always_comb begin

    fault = 1'b0;

    if (enable && history_full) begin

        if ((fault_enable[0] && (signal_history == fault_code_0)) ||
            (fault_enable[1] && (signal_history == fault_code_1)) ||
            (fault_enable[2] && (signal_history == fault_code_2)) ||
            (fault_enable[3] && (signal_history == fault_code_3)) ||
            (fault_enable[4] && (signal_history == fault_code_4)) ||
            (fault_enable[5] && (signal_history == fault_code_5)) ||
            (fault_enable[6] && (signal_history == fault_code_6)) ||
            (fault_enable[7] && (signal_history == fault_code_7))) begin

            fault = 1'b1;

        end

    end

end

endmodule
