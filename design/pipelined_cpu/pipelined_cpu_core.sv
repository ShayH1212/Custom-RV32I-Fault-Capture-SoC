/*
This CPU will be separated into multiple stages
Fetch -> Decode -> Exicute -> Memory -> Writeback
Each arrow will contain a pipeline register
*/
module pipelined_cpu_core (
    input logic clk,
    input logic reset,

    // Data Memory
    input  logic [31:0] data_read_data,
    output logic [31:0] data_write_data,
    output logic data_write_enable,
    output logic [31:0] data_address,
    output logic [31:0] data_read_address,

    // Instruction Memory
    input  logic [31:0] instruction_data,
    output logic [31:0] instruction_address

);

/*<><<><><><><><><><><><><><><><><><><><><><><><>
            INSTIANTIATE ALL SIGNALS
<><<><><><><><><><><><><><><><><><><><><><><><>*/

//FETCH
logic [31:0] pc_fetch;
logic [31:0] pc_next_fetch;

// FETCH -> DECODE PIPELINE
logic [31:0] pc_decode;
logic [31:0] instruction_decode;

// DECODE
logic [6:0] opcode_decode;
logic [2:0] funct3_decode;
logic [6:0] funct7_decode;
logic [4:0] rs1_decode;
logic [4:0] rs2_decode;
logic [4:0] rd_decode;
logic [31:0] read_reg1_decode;
logic [31:0] read_reg2_decode;
logic [31:0] immediate_decode;
logic reg_write_decode;
logic mem_write_decode;
logic val_sec_decode;
logic branch_decode;
logic jump_decode;
logic jalr_decode;
logic [1:0] result_src_decode;
logic [3:0] alu_op_decode;
logic [1:0] alu_a_src_decode;

// REGISTER FILE
logic [31:0] writeback_value_writeback;
logic [4:0] rd_writeback;
logic reg_write_writeback;

//  DECODE -> EXICUTE PIPELINE
logic [31:0] pc_execute;
logic [31:0] read_reg1_execute;
logic [31:0] read_reg2_execute;
logic [31:0] immediate_execute;
logic [2:0] funct3_execute;
logic [4:0] rs1_execute;
logic [4:0] rs2_execute;
logic [4:0] rd_execute;
logic [3:0] alu_op_execute;
logic val_sec_execute;
logic reg_write_execute;
logic mem_write_execute;
logic [1:0] result_src_execute;
logic branch_execute;
logic jump_execute;
logic jalr_execute;
logic [1:0] alu_a_src_execute;

 // EXICUTE
logic [31:0] alu_b_execute;
logic [31:0] alu_result_execute;
logic zero_execute;
logic branch_successful_execute;
logic [31:0] branch_target_execute;
logic [31:0] pc_add4_execute;

//   EXICUTE -> MEMORY PIPELINE
logic [31:0] alu_result_memory;
logic [31:0] read_reg2_memory;
logic [31:0] pc_add4_memory;
logic [4:0] rd_memory;
logic mem_write_memory;
logic reg_write_memory;
logic [1:0] result_src_memory;

 // MEMORY 
logic [31:0] writeback_value_memory;

// HAZARDS
logic stall;
logic flush;
logic [1:0] forward_a;
logic [1:0] forward_b;
logic [31:0] forwarded_a_execute;
logic [31:0] forwarded_b_execute;
logic [31:0] alu_a_execute;






/*<><<><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
        INSTIANTIATE ALL MODULES AND ADD NECESSARY LOGIC
<><<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>*/


/*******
  FETCH
********/
//instiantiate pc module
prog_count program_counter (
    .clk(clk),  
    .reset(reset),
    .pc_next(pc_next_fetch),
    .pc(pc_fetch),
    .enable(!stall)
);

// Instantiate instruction memory
assign instruction_address = pc_fetch;


/*************************
  FETCH -> DECODE PIPELINE
*************************/
//instiantiate fetch decoder pipeline module
fetch_decode_register fetch_decode_reg (
    .clk(clk),
    .reset(reset),
    .pc_in(pc_fetch),
    .instruction_in(instruction_data),
    .pc_out(pc_decode),
    .instruction_out(instruction_decode),
    .enable(!stall),
    .flush(flush)
);


/*******
 DECODE 
********/
// Break instruction up into arts
assign opcode_decode = instruction_decode[6:0];
assign rd_decode = instruction_decode[11:7];
assign funct3_decode = instruction_decode[14:12];
assign rs1_decode = instruction_decode[19:15];
assign rs2_decode = instruction_decode[24:20];
assign funct7_decode = instruction_decode[31:25];


// Instiantiate the decoder
decoder control_unit (
    .opcode(opcode_decode),
    .funct3(funct3_decode),
    .funct7(funct7_decode),
    .reg_write(reg_write_decode),
    .mem_write(mem_write_decode),
    .val_sec(val_sec_decode),
    .branch(branch_decode),
    .jump(jump_decode),
    .result_src(result_src_decode),
    .alu_op(alu_op_decode),
    .jalr(jalr_decode),
    .alu_a_src(alu_a_src_decode)
);

// instiantiate the immediate generator
immediate_gen immediate_generator (
    .instruction(instruction_decode),
    .immediate(immediate_decode)
);


/*****************************************
             REGISTER FILE
NOTE: This is where the writeback is done
*****************************************/
// Instiantiate the register file
reg_file register_file (
    .clk(clk),
    .rs1(rs1_decode),
    .rs2(rs2_decode),
    .rd(rd_writeback),
    .write_enable(reg_write_writeback),
    .write_reg(writeback_value_writeback),
    .read_reg1(read_reg1_decode),
    .read_reg2(read_reg2_decode)
);


/*************************
  DECODE -> EXICUTE PIPELINE
*************************/

// instiante pipeline
decode_execute_reg decode_execute_pipeline_reg (
    .clk(clk),
    .reset(reset),
    .pc_in(pc_decode),
    .read_reg1_in(read_reg1_decode),
    .read_reg2_in(read_reg2_decode),
    .immediate_in(immediate_decode),
    .funct3_in(funct3_decode),
    .rs1_in(rs1_decode),
    .rs2_in(rs2_decode),
    .rd_in(rd_decode),
    .alu_op_in(alu_op_decode),
    .val_sec_in(val_sec_decode),
    .reg_write_in(reg_write_decode),
    .mem_write_in(mem_write_decode),
    .result_src_in(result_src_decode),
    .branch_in(branch_decode),
    .jump_in(jump_decode),
    .jalr_in(jalr_decode),
    .pc_out(pc_execute),
    .read_reg1_out(read_reg1_execute),
    .read_reg2_out(read_reg2_execute),
    .immediate_out(immediate_execute),
    .funct3_out(funct3_execute),
    .rs1_out(rs1_execute),
    .rs2_out(rs2_execute),
    .rd_out(rd_execute),
    .alu_op_out(alu_op_execute),
    .val_sec_out(val_sec_execute),
    .reg_write_out(reg_write_execute),
    .mem_write_out(mem_write_execute),
    .result_src_out(result_src_execute),
    .branch_out(branch_execute),
    .jump_out(jump_execute),
    .jalr_out(jalr_execute),
    .flush(stall || flush),
    .alu_a_src_in(alu_a_src_decode),
    .alu_a_src_out(alu_a_src_execute)
);


/********
 EXICUTE
*********/

// Select first ALU value
always_comb begin

    if (alu_a_src_execute == 2'b01) begin
        // AUIPC uses PC
        alu_a_execute = pc_execute;
    end

    else if (alu_a_src_execute == 2'b10) begin
        // LUI uses zero
        alu_a_execute = 32'b0;
    end

    else begin
        // Normal instructions use rs1
        alu_a_execute = forwarded_a_execute;
    end

end

// Select second ALU value
always_comb begin

    if (val_sec_execute)
        alu_b_execute = immediate_execute;
    else
        alu_b_execute = forwarded_b_execute;

end




//instiantiate alu
alu alu_unit (
    .a(alu_a_execute),
    .b(alu_b_execute),
    .alu_opp(alu_op_execute),
    .result(alu_result_execute),
    .zero(zero_execute)
);

// Instiantiate branch comparitor
comp branch_comparator (
    .a(forwarded_a_execute),
    .b(forwarded_b_execute),
    .funct3(funct3_execute),
    .branch(branch_execute),
    .branch_successful(branch_successful_execute)
);


// Values calculated in Execute
assign branch_target_execute = pc_execute + immediate_execute;
assign pc_add4_execute       = pc_execute + 32'd4;


/********
 NEXT PC
*********/
always_comb begin
    // Normal
    pc_next_fetch = pc_fetch + 32'd4;

    // Taken branch
    if (branch_successful_execute)
        pc_next_fetch = branch_target_execute;


    // Jump
    if (jump_execute) begin
        // JALR
        if (jalr_execute) begin
            pc_next_fetch = (alu_result_execute & 32'hFFFF_FFFE);
        end
        // JAL
        else begin
            pc_next_fetch = branch_target_execute;
        end

    end        
end

/***************************
  EXICUTE -> MEMORY PIPELINE
****************************/


//instiantiate pipeline

execute_memory_reg execute_memory_pipeline_reg (
    .alu_result_in(alu_result_execute),
    .read_reg2_in(forwarded_b_execute),
    .pc_add4_in(pc_add4_execute),
    .rd_in(rd_execute),
    .mem_write_in(mem_write_execute),
    .reg_write_in(reg_write_execute),
    .result_src_in(result_src_execute),
    .alu_result_out(alu_result_memory),
    .read_reg2_out(read_reg2_memory),
    .pc_add4_out(pc_add4_memory),
    .rd_out(rd_memory),
    .mem_write_out(mem_write_memory),
    .reg_write_out(reg_write_memory),
    .result_src_out(result_src_memory),
    .clk(clk),
    .reset(reset)
);

/********
  MEMORY 
*********/

// Data memory

assign data_address = alu_result_memory;
assign data_write_data = read_reg2_memory;
assign data_write_enable = mem_write_memory;
assign data_read_address = alu_result_execute;



// Select what value should be written to rd
always_comb begin

    if (result_src_memory == 2'b00)
        writeback_value_memory = alu_result_memory;
    else if (result_src_memory == 2'b01)
        writeback_value_memory = data_read_data;
    else if (result_src_memory == 2'b10)
        writeback_value_memory = pc_add4_memory;
    else
        writeback_value_memory = 32'b0;

end

/*****************************
  MEMORY -> WRITEBACK PIPELINE
******************************/
// instiantiate pipeline
memory_writeback_reg memory_writeback_pipeline_reg (
    .clk(clk),
    .reset(reset),
    .writeback_value_in(writeback_value_memory),
    .rd_in(rd_memory),
    .reg_write_in(reg_write_memory),
    .writeback_value_out(writeback_value_writeback),
    .rd_out(rd_writeback),
    .reg_write_out(reg_write_writeback)
);


/**********************
 HAZARD DETECTION UNIT
**********************/

hazard_detection_unit hazard_unit (
    .rs1_decode(rs1_decode),
    .rs2_decode(rs2_decode),
    .rd_execute(rd_execute),
    .result_src_execute(result_src_execute),
    .stall(stall)
);



/*****************
  FORWARDING_UNIT
******************/

forwarding_unit forward_unit (
    .rs1_execute(rs1_execute),
    .rs2_execute(rs2_execute),
    .rd_memory(rd_memory),
    .result_src_memory(result_src_memory),
    .reg_write_memory(reg_write_memory),
    .rd_writeback(rd_writeback),
    .reg_write_writeback(reg_write_writeback),
    .forward_a(forward_a),
    .forward_b(forward_b)
);



/***************************
 EXTRA MUX'S FOR FORWARDING
***************************/

always_comb begin
    if(forward_a == 2'b10) begin
        forwarded_a_execute = writeback_value_memory;
    end
    else if (forward_a == 2'b01) begin
        forwarded_a_execute = writeback_value_writeback;
    end
    else begin
        forwarded_a_execute = read_reg1_execute;
    end
end

always_comb begin
    if(forward_b == 2'b10) begin
        forwarded_b_execute = writeback_value_memory;
    end
    else if (forward_b == 2'b01) begin
        forwarded_b_execute = writeback_value_writeback;
    end
    else begin
        forwarded_b_execute = read_reg2_execute;
    end
end


/***************************
 BRANCH/ JUMP FLUSH CONTROL
***************************/

always_comb begin
    if (branch_successful_execute || jump_execute) begin
        flush = 1'b1;
    end
    else begin
        flush = 1'b0;
    end
end



endmodule

