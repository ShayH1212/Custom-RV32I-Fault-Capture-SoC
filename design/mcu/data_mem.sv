/**********************************************************************
This module is for the data memmory
The data memmory stores the values that your program is working with.
We will have 512 locatons for memory each of which are 32 bits wide

***********************************************************************/

module data_mem (
    input  logic clk,
    input  logic mem_write,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    input logic [31:0] read_address,
    input logic [31:0] write_address
);

logic [31:0] memory [0:511];

assign read_data = memory[write_address[10:2]];

always_ff @(posedge clk) begin 
    if (mem_write) 
        memory[write_address[10:2]] <= write_data; 
end

endmodule