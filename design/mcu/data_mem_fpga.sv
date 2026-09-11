/*
This module is for the data memmory
The data memmory stores the values that your program is working with
we will have 512 locatons for memory each of which are 32 bits wide

clk : controls when a write happens
mem_write : 1 - write to memory
            0 - dont write
adress : what location we want to write to
write_data : the value to be stored
read_data : value stores at an address
*/

module data_mem (
    input  logic clk,
    input  logic mem_write,
    input logic [31:0] read_address,
    input logic [31:0] write_address,
    input logic [31:0] write_data,
    output logic [31:0] read_data
);

logic [31:0] memory [0:511];


always_ff @(posedge clk) begin
    if (mem_write) begin

        memory[write_address[10:2]] <= write_data;

    end

    read_data <= memory[read_address[10:2]];

end
endmodule