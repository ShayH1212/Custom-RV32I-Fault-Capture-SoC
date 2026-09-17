/****************************************************************************
THis is the instruction memmory
This is a read only storage block and will surfice for out single cycle CPU 
******************************************************************************/

module instruction_mem (

    input  logic [31:0] address,
    output logic [31:0] instruction

);

    logic [31:0] memory [0:255];

// Type instructions here
initial begin

    memory[0] = 32'h00500093; // addi x1, x0, 5
    memory[1] = 32'h00108133; // add  x2, x1, x1 
    memory[2] = 32'h00000013; 
    memory[3] = 32'h00000013; 
    memory[4] = 32'h00000013; 
    memory[5] = 32'h00000013; 

end

    assign instruction = memory[address[9:2]];

endmodule