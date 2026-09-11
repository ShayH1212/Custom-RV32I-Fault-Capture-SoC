module instruction_mem (
    input logic [31:0] address,
    output logic [31:0] instruction
);


/****************************************************************
Instruction Memory

256 Words
32 Bits Per Word
****************************************************************/

logic [31:0] memory [0:255];

integer i;


/****************************************************************
CPU Driven MCU Integration Program

Register Usage:

    x1 = GPIO Base
    x2 = UART Base
    x3 = SPI Base
    x4 = I2C Base
    x5 = Timer Base
    x6 = Interrupt Controller Base

    x7 = Write Data
    x8 = Status / Polling
    x9 = Read Data

Memory Map:

    GPIO      0x1000_0000
    UART      0x1000_1000
    SPI       0x1000_2000
    I2C       0x1000_3000
    Timer     0x1000_4000
    Interrupt 0x1000_5000

RAM Results:

    0x20 = RAM test value
    0x24 = UART received byte
    0x28 = SPI received byte
    0x2C = I2C write complete
    0x30 = I2C received byte
    0x34 = Interrupt pending
    0x38 = Program complete
****************************************************************/

initial begin


    /****************************************************************
    Fill Instruction Memory With NOPs
    ****************************************************************/

    for (i = 0; i < 256; i = i + 1) begin

        memory[i] = 32'h00000013;

    end


    /****************************************************************
    Load Peripheral Base Addresses
    ****************************************************************/

    memory[0] = 32'h100000B7; // lui x1, 0x10000
    memory[1] = 32'h10001137; // lui x2, 0x10001
    memory[2] = 32'h100021B7; // lui x3, 0x10002
    memory[3] = 32'h10003237; // lui x4, 0x10003
    memory[4] = 32'h100042B7; // lui x5, 0x10004
    memory[5] = 32'h10005337; // lui x6, 0x10005


    /****************************************************************
    GPIO
    ****************************************************************/

    memory[6] = 32'h0FF00393; // addi x7, x0, 255
    memory[7] = 32'h0070A423; // sw x7, 8(x1)

    // GPIO_DIR = 0xFF

    memory[8] = 32'h0A500393; // addi x7, x0, 165
    memory[9] = 32'h0070A023; // sw x7, 0(x1)

    // GPIO_OUT = 0xA5


    /****************************************************************
    RAM
    ****************************************************************/

    memory[10] = 32'h05500393; // addi x7, x0, 0x55
    memory[11] = 32'h02702023; // sw x7, 32(x0)

    // RAM[0x20] = 0x55


    /****************************************************************
    UART Transmit
    ****************************************************************/

    memory[12] = 32'h03C00393; // addi x7, x0, 0x3C
    memory[13] = 32'h00712023; // sw x7, 0(x2)

    // UART sends 0x3C


    /****************************************************************
    UART Receive
    ****************************************************************/

    memory[14] = 32'h00412403; // lw x8, 4(x2)
    memory[15] = 32'h00247413; // andi x8, x8, 2
    memory[16] = 32'hFE040CE3; // beq x8, x0, -8

    // Poll UART_STATUS until RX_VALID

    memory[17] = 32'h00012483; // lw x9, 0(x2)
    memory[18] = 32'h02902223; // sw x9, 36(x0)

    // Store received UART byte at RAM[0x24]


    /****************************************************************
    SPI
    ****************************************************************/

    memory[19] = 32'h0A600393; // addi x7, x0, 0xA6
    memory[20] = 32'h0071A023; // sw x7, 0(x3)

    // Start SPI transfer

    memory[21] = 32'h0041A403; // lw x8, 4(x3)
    memory[22] = 32'h00247413; // andi x8, x8, 2
    memory[23] = 32'hFE040CE3; // beq x8, x0, -8

    // Poll SPI_STATUS until transfer complete

    memory[24] = 32'h0001A483; // lw x9, 0(x3)
    memory[25] = 32'h02902423; // sw x9, 40(x0)

    // Store received SPI byte at RAM[0x28]

    memory[26] = 32'h00200393; // addi x7, x0, 2
    memory[27] = 32'h0071A223; // sw x7, 4(x3)

    // Clear SPI transfer complete

    memory[28] = 32'h00400393; // addi x7, x0, 4
    memory[29] = 32'h00732423; // sw x7, 8(x6)

    // Clear SPI interrupt pending


    /****************************************************************
    I2C Write
    ****************************************************************/

    memory[30] = 32'h05000393; // addi x7, x0, 0x50
    memory[31] = 32'h00722223; // sw x7, 4(x4)

    // I2C address = 0x50

    memory[32] = 32'h03C00393; // addi x7, x0, 0x3C
    memory[33] = 32'h00722023; // sw x7, 0(x4)

    // I2C data = 0x3C

    memory[34] = 32'h00100393; // addi x7, x0, 1
    memory[35] = 32'h00722423; // sw x7, 8(x4)

    // Start I2C write

    memory[36] = 32'h00C22403; // lw x8, 12(x4)
    memory[37] = 32'h00247413; // andi x8, x8, 2
    memory[38] = 32'hFE040CE3; // beq x8, x0, -8

    // Poll I2C_STATUS until transfer complete

    memory[39] = 32'h02802623; // sw x8, 44(x0)

    // Store complete bit at RAM[0x2C]

    memory[40] = 32'h00200393; // addi x7, x0, 2
    memory[41] = 32'h00722623; // sw x7, 12(x4)

    // Clear I2C transfer complete


    /****************************************************************
    I2C Read
    ****************************************************************/

    memory[42] = 32'h00300393; // addi x7, x0, 3
    memory[43] = 32'h00722423; // sw x7, 8(x4)

    // Start I2C read

    memory[44] = 32'h00C22403; // lw x8, 12(x4)
    memory[45] = 32'h00247413; // andi x8, x8, 2
    memory[46] = 32'hFE040CE3; // beq x8, x0, -8

    // Poll I2C_STATUS until transfer complete

    memory[47] = 32'h00022483; // lw x9, 0(x4)
    memory[48] = 32'h02902823; // sw x9, 48(x0)

    // Store received I2C byte at RAM[0x30]

    memory[49] = 32'h00200393; // addi x7, x0, 2
    memory[50] = 32'h00722623; // sw x7, 12(x4)

    // Clear I2C source

    memory[51] = 32'h00800393; // addi x7, x0, 8
    memory[52] = 32'h00732423; // sw x7, 8(x6)

    // Clear I2C interrupt pending


    /****************************************************************
    Timer
    ****************************************************************/

    memory[53] = 32'h00500393; // addi x7, x0, 5
    memory[54] = 32'h0072A223; // sw x7, 4(x5)

    // Timer compare = 5

    memory[55] = 32'h00100393; // addi x7, x0, 1
    memory[56] = 32'h00732023; // sw x7, 0(x6)

    // Enable Timer interrupt in interrupt controller

    memory[57] = 32'h00300393; // addi x7, x0, 3
    memory[58] = 32'h0072A423; // sw x7, 8(x5)

    // Enable Timer and Timer interrupt

    memory[59] = 32'h00C2A403; // lw x8, 12(x5)
    memory[60] = 32'h00147413; // andi x8, x8, 1
    memory[61] = 32'hFE040CE3; // beq x8, x0, -8

    // Poll Timer event

    memory[62] = 32'h00432483; // lw x9, 4(x6)
    memory[63] = 32'h02902A23; // sw x9, 52(x0)

    // Store interrupt pending at RAM[0x34]


    /****************************************************************
    Program Complete
    ****************************************************************/

    memory[64] = 32'h00100393; // addi x7, x0, 1
    memory[65] = 32'h02702C23; // sw x7, 56(x0)

    // RAM[0x38] = 1

    memory[66] = 32'h0000006F; // jal x0, 0

    // Infinite loop

end


/****************************************************************
Instruction Read

The CPU supplies a byte address.

Bits [9:2] select one of the 256 32-bit instructions.
****************************************************************/

assign instruction = memory[address[9:2]];


endmodule