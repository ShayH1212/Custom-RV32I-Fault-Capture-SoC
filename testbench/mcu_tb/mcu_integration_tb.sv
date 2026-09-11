module cpu_mcu_integration_tb;


/****************************************************************
Clock Parameters
****************************************************************/

localparam integer CLOCK_FREQUENCY = 50_000_000;


/****************************************************************
UART Parameters
****************************************************************/

localparam integer UART_BAUD_RATE = 115200;

localparam integer UART_BAUD_DIVIDER =
    CLOCK_FREQUENCY / UART_BAUD_RATE;


/****************************************************************
Clock and Reset
****************************************************************/

logic clk;
logic reset;


/****************************************************************
GPIO
****************************************************************/

logic [7:0] gpio_in;
logic [7:0] gpio_out;
logic [7:0] gpio_dir;


/****************************************************************
UART
****************************************************************/

logic uart_rx;
logic uart_tx;


/****************************************************************
SPI
****************************************************************/

logic spi_sclk;
logic spi_mosi;
wire spi_miso;
logic spi_cs;


// SPI loopback
assign spi_miso = spi_mosi;


/****************************************************************
I2C
****************************************************************/

tri1 i2c_scl;
tri1 i2c_sda;


/****************************************************************
Simple I2C Slave Signals
****************************************************************/

logic i2c_slave_sda_drive_low;
logic i2c_slave_ack_enable;
logic [7:0] i2c_slave_read_byte;


assign i2c_sda =
    i2c_slave_sda_drive_low ? 1'b0 : 1'bz;


/****************************************************************
Test Values
****************************************************************/

logic [7:0] captured_uart_byte;

integer pass_count;
integer fail_count;
integer i;


/****************************************************************
MCU
****************************************************************/

mcu_top dut (

    .clk(clk),

    .reset(reset),


    // GPIO
    .gpio_in(gpio_in),

    .gpio_out(gpio_out),

    .gpio_dir(gpio_dir),


    // UART
    .uart_rx(uart_rx),

    .uart_tx(uart_tx),


    // SPI
    .spi_sclk(spi_sclk),

    .spi_mosi(spi_mosi),

    .spi_miso(spi_miso),

    .spi_cs(spi_cs),


    // I2C
    .i2c_scl(i2c_scl),

    .i2c_sda(i2c_sda)

);


/****************************************************************
50 MHz Clock
****************************************************************/

always #10 clk = ~clk;


/****************************************************************
Simple I2C Slave

This is only the external device used by the MCU during the
simulation.

It:

    ACKs addresses
    ACKs write data
    Returns 0x5A during a read

The CPU still controls the actual I2C master.
****************************************************************/

always_comb begin

    i2c_slave_sda_drive_low = 1'b0;


    // ADDRESS_ACK
    if (dut.i2c_module.i2c_state == 4'b0011) begin

        if (i2c_slave_ack_enable == 1'b1) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end


    // WRITE_ACK
    else if (dut.i2c_module.i2c_state == 4'b0101) begin

        if (i2c_slave_ack_enable == 1'b1) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end


    // READ_DATA
    else if (dut.i2c_module.i2c_state == 4'b0110) begin

        if (i2c_slave_read_byte[dut.i2c_module.bit_counter] == 1'b0) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end

end


/****************************************************************
Check 32 Bit Value
****************************************************************/

task check_32;

    input [31:0] actual;
    input [31:0] expected;
    input [8*80-1:0] test_name;

begin

    if (actual === expected) begin

        $display("PASS: %0s", test_name);

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: %0s Expected = %h Actual = %h",
            test_name,
            expected,
            actual
        );

        fail_count = fail_count + 1;

    end

end

endtask


/****************************************************************
Check 8 Bit Value
****************************************************************/

task check_8;

    input [7:0] actual;
    input [7:0] expected;
    input [8*80-1:0] test_name;

begin

    if (actual === expected) begin

        $display("PASS: %0s", test_name);

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: %0s Expected = %h Actual = %h",
            test_name,
            expected,
            actual
        );

        fail_count = fail_count + 1;

    end

end

endtask


/****************************************************************
Check 1 Bit Value
****************************************************************/

task check_1;

    input actual;
    input expected;
    input [8*80-1:0] test_name;

begin

    if (actual === expected) begin

        $display("PASS: %0s", test_name);

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: %0s Expected = %b Actual = %b",
            test_name,
            expected,
            actual
        );

        fail_count = fail_count + 1;

    end

end

endtask


/****************************************************************
UART Receiver

This task observes uart_tx.

It does NOT control the CPU bus.

It waits for the CPU to transmit a byte and reconstructs that
byte from the physical UART output.
****************************************************************/

task capture_uart_transmit;

    output [7:0] uart_byte;

integer j;
integer timeout;

begin

    uart_byte = 8'b0;

    timeout = 0;


    // Wait for START bit
    while ((uart_tx !== 1'b0) &&
           (timeout < 5000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (uart_tx !== 1'b0) begin

        $display("FAIL: CPU UART transmission did not start");

        fail_count = fail_count + 1;

    end


    else begin

        // Move to middle of START bit
        repeat (UART_BAUD_DIVIDER / 2) @(posedge clk);


        // Move to middle of first data bit
        repeat (UART_BAUD_DIVIDER) @(posedge clk);


        for (j = 0; j < 8; j = j + 1) begin

            uart_byte[j] = uart_tx;


            if (j < 7) begin

                repeat (UART_BAUD_DIVIDER) @(posedge clk);

            end

        end


        // Move to STOP bit
        repeat (UART_BAUD_DIVIDER) @(posedge clk);


        if (uart_tx === 1'b1) begin

            $display("PASS: CPU UART STOP bit");

            pass_count = pass_count + 1;

        end

        else begin

            $display("FAIL: CPU UART STOP bit");

            fail_count = fail_count + 1;

        end

    end

end

endtask


/****************************************************************
Send UART Byte To MCU

This represents an external UART device sending data to the MCU.

The CPU must poll UART_STATUS and then read UART_DATA itself.
****************************************************************/

task uart_send_byte;

    input [7:0] uart_byte;

integer j;

begin

    // Idle
    uart_rx = 1'b1;

    repeat (5) @(negedge clk);


    // START
    uart_rx = 1'b0;

    repeat (UART_BAUD_DIVIDER) @(negedge clk);


    // 8 data bits
    for (j = 0; j < 8; j = j + 1) begin

        uart_rx = uart_byte[j];

        repeat (UART_BAUD_DIVIDER) @(negedge clk);

    end


    // STOP
    uart_rx = 1'b1;

    repeat (UART_BAUD_DIVIDER) @(negedge clk);


    repeat (10) @(posedge clk);

end

endtask


/****************************************************************
Wait For CPU Program Completion

The RISC-V program writes:

    RAM[0x38] = 1

when the entire program has completed.

0x38 / 4 = RAM word 14
****************************************************************/

task wait_for_program_done;

integer timeout;

begin

    timeout = 0;


    while ((dut.data_memory.memory[14] !== 32'h00000001) &&
           (timeout < 120000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (dut.data_memory.memory[14] === 32'h00000001) begin

        $display("PASS: CPU reached program completion");

        pass_count = pass_count + 1;

    end

    else begin

        $display("FAIL: CPU program timed out");

        fail_count = fail_count + 1;

    end

end

endtask


/****************************************************************
Main Test
****************************************************************/

initial begin

    clk = 1'b0;

    reset = 1'b1;


    gpio_in = 8'h00;


    uart_rx = 1'b1;


    i2c_slave_ack_enable = 1'b1;

    i2c_slave_read_byte = 8'h5A;


    captured_uart_byte = 8'h00;


    pass_count = 0;

    fail_count = 0;


    /****************************************************************
    Allow instruction_mem's own initial block to run first
    ****************************************************************/

    #1;


    /****************************************************************
    Clear Instruction Memory

    NOP:

        addi x0, x0, 0
    ****************************************************************/

    for (i = 0; i < 256; i = i + 1) begin

        dut.instruction_memory.memory[i] = 32'h00000013;

    end


    /****************************************************************
    CPU Driven MCU Program

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
        0x38 = Program done
    ****************************************************************/


    /****************************************************************
    Load Peripheral Base Addresses
    ****************************************************************/

    dut.instruction_memory.memory[0] =
        32'h100000B7; // lui x1, 0x10000

    dut.instruction_memory.memory[1] =
        32'h10001137; // lui x2, 0x10001

    dut.instruction_memory.memory[2] =
        32'h100021B7; // lui x3, 0x10002

    dut.instruction_memory.memory[3] =
        32'h10003237; // lui x4, 0x10003

    dut.instruction_memory.memory[4] =
        32'h100042B7; // lui x5, 0x10004

    dut.instruction_memory.memory[5] =
        32'h10005337; // lui x6, 0x10005


    /****************************************************************
    GPIO
    ****************************************************************/

    dut.instruction_memory.memory[6] =
        32'h0FF00393; // addi x7, x0, 255

    dut.instruction_memory.memory[7] =
        32'h0070A423; // sw x7, 8(x1)


    // GPIO_DIR = FF


    dut.instruction_memory.memory[8] =
        32'h0A500393; // addi x7, x0, 165

    dut.instruction_memory.memory[9] =
        32'h0070A023; // sw x7, 0(x1)


    // GPIO_OUT = A5


    /****************************************************************
    RAM
    ****************************************************************/

    dut.instruction_memory.memory[10] =
        32'h05500393; // addi x7, x0, 0x55

    dut.instruction_memory.memory[11] =
        32'h02702023; // sw x7, 32(x0)


    // RAM[0x20] = 55


    /****************************************************************
    UART Transmit
    ****************************************************************/

    dut.instruction_memory.memory[12] =
        32'h03C00393; // addi x7, x0, 0x3C

    dut.instruction_memory.memory[13] =
        32'h00712023; // sw x7, 0(x2)


    // UART sends 0x3C


    /****************************************************************
    UART Receive Polling
    ****************************************************************/

    dut.instruction_memory.memory[14] =
        32'h00412403; // lw x8, 4(x2)

    dut.instruction_memory.memory[15] =
        32'h00247413; // andi x8, x8, 2

    dut.instruction_memory.memory[16] =
        32'hFE040CE3; // beq x8, x0, -8


    /****************************************************************
    Loop until UART_STATUS bit 1 = RX_VALID
    ****************************************************************/

    dut.instruction_memory.memory[17] =
        32'h00012483; // lw x9, 0(x2)

    dut.instruction_memory.memory[18] =
        32'h02902223; // sw x9, 36(x0)


    // Store received UART byte at RAM[0x24]


    /****************************************************************
    SPI
    ****************************************************************/

    dut.instruction_memory.memory[19] =
        32'h0A600393; // addi x7, x0, 0xA6

    dut.instruction_memory.memory[20] =
        32'h0071A023; // sw x7, 0(x3)


    // Start SPI transfer


    dut.instruction_memory.memory[21] =
        32'h0041A403; // lw x8, 4(x3)

    dut.instruction_memory.memory[22] =
        32'h00247413; // andi x8, x8, 2

    dut.instruction_memory.memory[23] =
        32'hFE040CE3; // beq x8, x0, -8


    /****************************************************************
    Poll SPI_STATUS bit 1 until transfer complete
    ****************************************************************/

    dut.instruction_memory.memory[24] =
        32'h0001A483; // lw x9, 0(x3)

    dut.instruction_memory.memory[25] =
        32'h02902423; // sw x9, 40(x0)


    // Store SPI received byte at RAM[0x28]


    dut.instruction_memory.memory[26] =
        32'h00200393; // addi x7, x0, 2

    dut.instruction_memory.memory[27] =
        32'h0071A223; // sw x7, 4(x3)


    // Clear SPI complete


    dut.instruction_memory.memory[28] =
        32'h00400393; // addi x7, x0, 4

    dut.instruction_memory.memory[29] =
        32'h00732423; // sw x7, 8(x6)


    // Clear SPI pending interrupt


    /****************************************************************
    I2C Write
    ****************************************************************/

    dut.instruction_memory.memory[30] =
        32'h05000393; // addi x7, x0, 0x50

    dut.instruction_memory.memory[31] =
        32'h00722223; // sw x7, 4(x4)


    // I2C address = 0x50


    dut.instruction_memory.memory[32] =
        32'h03C00393; // addi x7, x0, 0x3C

    dut.instruction_memory.memory[33] =
        32'h00722023; // sw x7, 0(x4)


    // I2C data = 0x3C


    dut.instruction_memory.memory[34] =
        32'h00100393; // addi x7, x0, 1

    dut.instruction_memory.memory[35] =
        32'h00722423; // sw x7, 8(x4)


    // Start I2C write


    dut.instruction_memory.memory[36] =
        32'h00C22403; // lw x8, 12(x4)

    dut.instruction_memory.memory[37] =
        32'h00247413; // andi x8, x8, 2

    dut.instruction_memory.memory[38] =
        32'hFE040CE3; // beq x8, x0, -8


    // Poll transfer_complete


    dut.instruction_memory.memory[39] =
        32'h02802623; // sw x8, 44(x0)


    // RAM[0x2C] = I2C complete bit


    dut.instruction_memory.memory[40] =
        32'h00200393; // addi x7, x0, 2

    dut.instruction_memory.memory[41] =
        32'h00722623; // sw x7, 12(x4)


    // Clear I2C complete


    /****************************************************************
    I2C Read
    ****************************************************************/

    dut.instruction_memory.memory[42] =
        32'h00300393; // addi x7, x0, 3

    dut.instruction_memory.memory[43] =
        32'h00722423; // sw x7, 8(x4)


    // START + READ


    dut.instruction_memory.memory[44] =
        32'h00C22403; // lw x8, 12(x4)

    dut.instruction_memory.memory[45] =
        32'h00247413; // andi x8, x8, 2

    dut.instruction_memory.memory[46] =
        32'hFE040CE3; // beq x8, x0, -8


    // Poll transfer_complete


    dut.instruction_memory.memory[47] =
        32'h00022483; // lw x9, 0(x4)

    dut.instruction_memory.memory[48] =
        32'h02902823; // sw x9, 48(x0)


    // Store I2C received byte at RAM[0x30]


    dut.instruction_memory.memory[49] =
        32'h00200393; // addi x7, x0, 2

    dut.instruction_memory.memory[50] =
        32'h00722623; // sw x7, 12(x4)


    // Clear I2C source


    dut.instruction_memory.memory[51] =
        32'h00800393; // addi x7, x0, 8

    dut.instruction_memory.memory[52] =
        32'h00732423; // sw x7, 8(x6)


    // Clear I2C pending interrupt


    /****************************************************************
    Timer
    ****************************************************************/

    dut.instruction_memory.memory[53] =
        32'h00500393; // addi x7, x0, 5

    dut.instruction_memory.memory[54] =
        32'h0072A223; // sw x7, 4(x5)


    // Timer compare = 5


    dut.instruction_memory.memory[55] =
        32'h00100393; // addi x7, x0, 1

    dut.instruction_memory.memory[56] =
        32'h00732023; // sw x7, 0(x6)


    // Enable Timer interrupt


    dut.instruction_memory.memory[57] =
        32'h00300393; // addi x7, x0, 3

    dut.instruction_memory.memory[58] =
        32'h0072A423; // sw x7, 8(x5)


    // Timer enable + Timer interrupt enable


    dut.instruction_memory.memory[59] =
        32'h00C2A403; // lw x8, 12(x5)

    dut.instruction_memory.memory[60] =
        32'h00147413; // andi x8, x8, 1

    dut.instruction_memory.memory[61] =
        32'hFE040CE3; // beq x8, x0, -8


    // Poll Timer event


    dut.instruction_memory.memory[62] =
        32'h00432483; // lw x9, 4(x6)

    dut.instruction_memory.memory[63] =
        32'h02902A23; // sw x9, 52(x0)


    // Store Interrupt Pending at RAM[0x34]


/****************************************************************
Data RAM Load Test
****************************************************************/

dut.instruction_memory.memory[64] =
    32'h02002483; // lw x9, 32(x0)

// Load the 0x55 previously stored at RAM[0x20]


dut.instruction_memory.memory[65] =
    32'h02902E23; // sw x9, 60(x0)

// Store loaded value at RAM[0x3C]


/****************************************************************
Program Complete
****************************************************************/

dut.instruction_memory.memory[66] =
    32'h00100393; // addi x7, x0, 1

dut.instruction_memory.memory[67] =
    32'h02702C23; // sw x7, 56(x0)

// RAM[0x38] = 1


dut.instruction_memory.memory[68] =
    32'h0000006F; // jal x0, 0

// Infinite loop


    // Infinite loop


    /****************************************************************
    Start CPU
    ****************************************************************/

    repeat (4) @(posedge clk);


    @(negedge clk);

    reset = 1'b0;


    /****************************************************************
    Observe UART Transmission

    CPU should send 0x3C.
    ****************************************************************/

    capture_uart_transmit(
        captured_uart_byte
    );


    check_8(
        captured_uart_byte,
        8'h3C,
        "CPU-driven UART transmit"
    );


    /****************************************************************
    Send UART Data To CPU

    At this point the CPU is polling UART_STATUS waiting for
    external data.

    Send 0x69.
    ****************************************************************/

    uart_send_byte(
        8'h69
    );


    /****************************************************************
    Wait For Entire CPU Program
    ****************************************************************/

    wait_for_program_done();


    /****************************************************************
    Verify CPU Generated Results
    ****************************************************************/

    $display("");
    $display("========================================");
    $display("CPU DRIVEN MCU VERIFICATION");
    $display("========================================");


    /****************************************************************
    GPIO Results
    ****************************************************************/

    check_8(
        gpio_dir,
        8'hFF,
        "CPU configured GPIO_DIR"
    );


    check_8(
        gpio_out,
        8'hA5,
        "CPU configured GPIO_OUT"
    );


/****************************************************************
RAM Test

Address 0x20 / 4 = word 8
****************************************************************/

check_32(
    dut.data_memory.memory[8],
    32'h00000055,
    "CPU RAM store"
);


/****************************************************************
RAM Load Test

Address 0x3C / 4 = word 15
****************************************************************/

check_32(
    dut.data_memory.memory[15],
    32'h00000055,
    "CPU RAM load"
);


    /****************************************************************
    UART RX

    Address 0x24 / 4 = word 9
    ****************************************************************/

    check_32(
        dut.data_memory.memory[9],
        32'h00000069,
        "CPU UART receive and readback"
    );


    /****************************************************************
    SPI Loopback

    Address 0x28 / 4 = word 10
    ****************************************************************/

    check_32(
        dut.data_memory.memory[10],
        32'h000000A6,
        "CPU SPI loopback readback"
    );


    /****************************************************************
    I2C Write Complete

    Address 0x2C / 4 = word 11
    ****************************************************************/

    check_32(
        dut.data_memory.memory[11],
        32'h00000002,
        "CPU detected I2C write completion"
    );


    /****************************************************************
    I2C Read

    Address 0x30 / 4 = word 12
    ****************************************************************/

    check_32(
        dut.data_memory.memory[12],
        32'h0000005A,
        "CPU I2C readback"
    );


    /****************************************************************
    Interrupt Pending

    Address 0x34 / 4 = word 13
    ****************************************************************/

    check_1(
        dut.data_memory.memory[13][0],
        1'b1,
        "CPU detected Timer interrupt pending"
    );


    /****************************************************************
    Timer CPU Interrupt
    ****************************************************************/

    check_1(
        dut.cpu_interrupt,
        1'b1,
        "Timer interrupt reaches CPU interface"
    );


    if (dut.interrupt_id === 3'd0) begin

        $display("PASS: CPU sees Timer interrupt ID");

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: CPU sees Timer interrupt ID Expected = 0 Actual = %0d",
            dut.interrupt_id
        );

        fail_count = fail_count + 1;

    end


    /****************************************************************
    Program Completion Marker
    ****************************************************************/

    check_32(
        dut.data_memory.memory[14],
        32'h00000001,
        "CPU program completion marker"
    );


    /****************************************************************
    Final Results
    ****************************************************************/

    $display("");
    $display("========================================");
    $display("CPU DRIVEN MCU TEST RESULTS");
    $display("========================================");
    $display("PASSED: %0d", pass_count);
    $display("FAILED: %0d", fail_count);
    $display("========================================");


    if (fail_count == 0) begin

        $display("ALL CPU DRIVEN MCU TESTS PASSED");

    end

    else begin

        $display("CPU DRIVEN MCU TESTS FAILED");

    end


    $finish;

end


endmodule