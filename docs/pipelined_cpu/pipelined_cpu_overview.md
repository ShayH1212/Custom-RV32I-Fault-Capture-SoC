# Simple CPU Design Overview

The second stage of the RISC-V MCU project is a pipelined multi cycle processor implemented in SystemVerilog.

This pipelined CPU is an extension to the single cycle CPU. The pipelined CPU adds "pipelines" or registers inbetween the stages that store the data to be used while allowing the CPU to overwrite the date for other uses. This allows the CPU to process multiple cucles in one clock cycle.

## Architecture

The main components of the pipelined CPU are:

- Program Counter
- Instruction Memory
- Decoder / Control Unit
- Register File
- Immediate Generator
- ALU
- Branch Comparator
- Data Memory
- Next-PC Logic
- Writeback Selection Logic
- Pipeline registers

### ALU

   The ALU preforms the arithmetic, logical, comparison, and shift operations required by the processor
   The ALU has two 32-bit inputs: "a" and "b", it receives a 4-bit "alu_op" control value from the decoder. 
   This control value determines which operation the ALU performs.
   The different values of alu_op are as follows:
      
   ALU_ADD
   OppCode: 0000
   result = a + b
   
   ALU_SUB
   Opp_Code: 0001
   result = a - b
   
   ALU_AND
   Opp_Code: 0010
   result = a & b
   
   ALU_OR
   Opp_Code: 0011
   result = a | b
   
   ALU_XOR
   Opp_Code: 0100
   result = a ^ b
   
   ALU_SLL
   Opp_Code: 0101
   the bits are moved to the left and new bits are replaced with 0's
   
   ALU_SRL
   Opp_Code: 0110
   the bits are moved to the right and new bits are filled with 0
   
   ALU_SRA
   Opp_Code: 0111
   the bits are moved to the right and the sign of the left most bit is preserved
   
   ALU_SLT
   Opp_Code: 1000
   result = 1 if a < b signed
   
   ALU_SLTU
   Opp_Code: 1001
   result = 1 if a < b unsigned
   
   The ALU also contains a "zero" flag which becomes "1" when the output is zero
   
### Register File
   
   The register file stores the processor’s general purpose registers. In the RV32I architecture, there are 32 registers,    each 32 bits wide : identified as x0 through x31.
   
   The register file supports two simultaneous read operations and one write operation. 
   
   The rs1 and rs2 fields from the instruction select the two registers to be read, while rd selects the destination         register for a write.
   
   Register x0 is permanently fixed to a value of zero. Any attempt to write to x0 is ignored, and any read from x0          returns zero.
   
   Writes occur on the rising edge of the clock when reg_write is enabled and rd is not zero. The two read outputs are       combinational, meaning the selected register values are available immediately when rs1 or rs2 changes.

### Program Counter

   The program counter stores the address of the instruction the CPU is currently executing.
   On every rising edge of the clock it loads the value of the next pc value
   In a normal operation the value of the next pc will be pc + 4 however in some special cases this changes
   These special cases are handeled by the pc_next module

### Program Counter -> next

   The program counter -> next or pc_next module is used to determine what instruction the program will read next
   The program counter will normally be updated by 4
   However, there are some special cases that need to be handeled
   The program uses two flags, branch_successful and jump, if either of these are 1 then we have a special case and must    change the program counter accordingly
   if branch_successful : pc = pc + imm
   if jump  : pc = pc + imm
   
### Instruction Memory

The instruction memory stores the machine code to be executed by the CPU.
It contains 256 words of 32 bit memory (may be altered to meet requirements when being put into silicone) 
The program counter provides the address of which code is to be read within the instruction memory

### Immediate Generator

The immediate generator extracts and reconstructs immediate values from within the instruction.
Different types of instructions store memory in different places and so the instruction memory determines the type of instruction, where the immediate values are stores and then combines them into one immediate.
This immediate is then used in ALU operations, memory addressing, branches, and jumps.

### Decoder

The decoder interoperates the instruction using "opcode", "func3" and "func7"
It generates the control signals used by the rest of the processor, including:
- reg_write
- mem_write
- val_sec
- branch
- jump
- result_src
- alu_op
  
  These signals control how the instructions move through the datapath

### Branch Comparator

This compares reg_read 1 and reg_read2 for conditional branche instructions and then it uses "func3"

This allows for the following commands:
- BEQ
- BNE
- BLT
- BGE
- BLTU
- BGEU

### Data Memory
The data memory stores values used by load and store instructions.
It contains 512 words of 32-bit memory.
Reads are combinational and writes occur on the rising clock edge when mem_write is enabled

### Pipeline Registerd
The pipeline registers are registers that are placed between the stages of the CPU to facilitate multi cycle processing.

Previously we had:
FETCH -> DECODE -> EXECUTE -> MEMORY -> WRITEBACK

We nad to add a register between all of these components to store necessary data that would be overwritten.

The design is now:
FETCH -> REG -> DECODE -> REG -> EXECUTE -> REG -> MEMORY -> REG -> WRITEBACK

### CPU Core

The cpu_core module connects all of the processor modules into the complete single-cycle datapath.


### Other Notable Additions

In add tion to the pipeline registers in this upgraded CPU also adds in 3 new instructions.

JAL(Jump and Link)
ALU

