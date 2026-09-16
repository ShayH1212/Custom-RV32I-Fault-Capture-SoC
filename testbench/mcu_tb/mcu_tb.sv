module mcu_tb;


// MCU clock
localparam integer CLOCK_FREQUENCY = 50_000_000;


// UART
localparam integer UART_BAUD_RATE = 115200;
localparam integer UART_BAUD_DIVIDER = CLOCK_FREQUENCY / UART_BAUD_RATE;


// Memory Map
localparam logic [31:0] RAM_BASE = 32'h0000_0000;
localparam logic [31:0] GPIO_BASE = 32'h1000_0000;
localparam logic [31:0] UART_BASE = 32'h1000_1000;
localparam logic [31:0] SPI_BASE = 32'h1000_2000;
localparam logic [31:0] I2C_BASE = 32'h1000_3000;
localparam logic [31:0] TIMER_BASE = 32'h1000_4000;
localparam logic [31:0] INTERRUPT_BASE = 32'h1000_5000;


// GPIO Registers
localparam logic [31:0] GPIO_OUT = GPIO_BASE + 32'h0;
localparam logic [31:0] GPIO_IN = GPIO_BASE + 32'h4;
localparam logic [31:0] GPIO_DIR = GPIO_BASE + 32'h8;


// UART Registers
localparam logic [31:0] UART_DATA = UART_BASE + 32'h0;
localparam logic [31:0] UART_STATUS = UART_BASE + 32'h4;


// SPI Registers
localparam logic [31:0] SPI_DATA = SPI_BASE + 32'h0;
localparam logic [31:0] SPI_STATUS = SPI_BASE + 32'h4;


// I2C Registers
localparam logic [31:0] I2C_DATA = I2C_BASE + 32'h0;
localparam logic [31:0] I2C_ADDRESS = I2C_BASE + 32'h4;
localparam logic [31:0] I2C_CONTROL = I2C_BASE + 32'h8;
localparam logic [31:0] I2C_STATUS = I2C_BASE + 32'hC;


// Timer Registers
localparam logic [31:0] TIMER_COUNT = TIMER_BASE + 32'h0;
localparam logic [31:0] TIMER_COMPARE = TIMER_BASE + 32'h4;
localparam logic [31:0] TIMER_CONTROL = TIMER_BASE + 32'h8;
localparam logic [31:0] TIMER_STATUS = TIMER_BASE + 32'hC;


// Interrupt Controller Registers
localparam logic [31:0] INTERRUPT_ENABLE = INTERRUPT_BASE + 32'h0;
localparam logic [31:0] INTERRUPT_PENDING = INTERRUPT_BASE + 32'h4;
localparam logic [31:0] INTERRUPT_CLEAR = INTERRUPT_BASE + 32'h8;


// Clock and reset
logic clk;
logic reset;


// GPIO
logic [7:0] gpio_in;
logic [7:0] gpio_out;
logic [7:0] gpio_dir;


// UART
logic uart_rx;
logic uart_tx;


// SPI
logic spi_sclk;
logic spi_mosi;
wire spi_miso;
logic spi_cs;


// SPI loopback
assign spi_miso = spi_mosi;


// I2C
tri1 i2c_scl;
tri1 i2c_sda;


// Simple I2C slave
logic i2c_slave_sda_drive_low;
logic i2c_slave_ack_enable;
logic [7:0] i2c_slave_read_byte;

assign i2c_sda = i2c_slave_sda_drive_low ? 1'b0 : 1'bz;


// Values used by direct bus access
logic [31:0] forced_address;
logic [31:0] forced_write_data;


// Test information
integer pass_count;
integer fail_count;
integer i;

logic [31:0] read_value;



/*<><<><><><><><><>
        MCU
<<><<><><><><><><>*/

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



// 50 MHz clock
always #10 clk = ~clk;


/****************************************************
Simple I2C Slave

Provides ACK responses and read data for I2C testing.
*****************************************************/
always_comb begin

    i2c_slave_sda_drive_low = 1'b0;


    // Address ACK
    if (dut.i2c_module.i2c_state == 4'b0011) begin

        if (i2c_slave_ack_enable == 1'b1) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end


    // Write data ACK
    else if (dut.i2c_module.i2c_state == 4'b0101) begin

        if (i2c_slave_ack_enable == 1'b1) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end


    // Read data
    else if (dut.i2c_module.i2c_state == 4'b0110) begin

        if (i2c_slave_read_byte[dut.i2c_module.bit_counter] == 1'b0) begin

            i2c_slave_sda_drive_low = 1'b1;

        end

    end

end



/********************
Check 32 Bit Value
************************/

task check_32;

    input [31:0] actual;
    input [31:0] expected;
    input string test_name;

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



/*********************
Check 8 Bit Value
**********************/

task check_8;

    input [7:0] actual;
    input [7:0] expected;
    input string test_name;

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



/******************
Check 1 Bit Value
********************/

task check_1;

    input actual;
    input expected;
    input string test_name;

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



/***********
Reset MCU
*************/

task reset_mcu;

begin

    reset = 1'b1;

    repeat (4) @(posedge clk);

    @(negedge clk);

    reset = 1'b0;

    repeat (2) @(posedge clk);

end

endtask



/*******************************
Fill Instruction Memory With NOPs
********************************/

task load_nops;

integer j;

begin

    for (j = 0; j < 256; j = j + 1) begin

        dut.instruction_memory.memory[j] = 32'h00000013;

    end

end

endtask



/******************************************************
Direct MCU Bus Write

The testbench temporarily overrides the CPU data bus.

The transaction still travels through:

    Memory Interconnect -> Selected MCU Device
********************************************************/

task bus_write;

    input [31:0] bus_address;
    input [31:0] bus_data;

begin

    forced_address = bus_address;
    forced_write_data = bus_data;


    @(negedge clk);


    force dut.data_address = forced_address;

    force dut.data_write_data = forced_write_data;

    force dut.data_write_enable = 1'b1;


    @(posedge clk);

    #1;


    @(negedge clk);


    release dut.data_address;

    release dut.data_write_data;

    release dut.data_write_enable;


    #1;

end

endtask



/*********************
Direct MCU Bus Read
***********************/

task bus_read;

    input [31:0] bus_address;

    output [31:0] bus_data;

begin

    forced_address = bus_address;


    @(negedge clk);


    force dut.data_address = forced_address;

    force dut.data_write_enable = 1'b0;


    #1;


    bus_data = dut.data_read_data;


    release dut.data_address;

    release dut.data_write_enable;


    #1;

end

endtask



/*********************
Wait For SPI Transfer
***********************/

task wait_for_spi;

integer timeout;

begin

    timeout = 0;


    while ((dut.spi_interrupt !== 1'b1) &&
           (timeout < 2000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (dut.spi_interrupt === 1'b1) begin

        $display("PASS: SPI transfer completed");

        pass_count = pass_count + 1;

    end

    else begin

        $display("FAIL: SPI transfer timed out");

        fail_count = fail_count + 1;

    end

end

endtask



/**********************
Wait For I2C Transfer
*************************/

task wait_for_i2c;

integer timeout;

begin

    timeout = 0;


    while ((dut.i2c_interrupt !== 1'b1) &&
           (timeout < 30000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (dut.i2c_interrupt === 1'b1) begin

        $display("PASS: I2C transaction completed");

        pass_count = pass_count + 1;

    end

    else begin

        $display("FAIL: I2C transaction timed out");

        fail_count = fail_count + 1;

    end

end

endtask



/*************************
Wait For Timer Interrupt
****************************/

task wait_for_timer;

integer timeout;

begin

    timeout = 0;


    while ((dut.timer_interrupt !== 1'b1) &&
           (timeout < 1000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (dut.timer_interrupt === 1'b1) begin

        $display("PASS: Timer interrupt generated");

        pass_count = pass_count + 1;

    end

    else begin

        $display("FAIL: Timer interrupt timed out");

        fail_count = fail_count + 1;

    end

end

endtask



/***************************
Send UART Byte Into MCU

UART Format:

    START
    8 data bits LSB first
    STOP
****************************/

task uart_send_byte;

    input [7:0] uart_byte;

integer j;

begin

    uart_rx = 1'b1;

    repeat (5) @(negedge clk);


    // START
    uart_rx = 1'b0;

    repeat (UART_BAUD_DIVIDER) @(negedge clk);


    // Data
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



/*************************
Check UART Transmission
***************************/

task uart_check_transmit;

    input [7:0] uart_byte;

integer j;
integer timeout;

begin

    bus_write(
        UART_DATA,
        {24'b0, uart_byte}
    );


    timeout = 0;


    // Wait for START bit
    while ((uart_tx !== 1'b0) &&
           (timeout < 1000)) begin

        @(posedge clk);

        timeout = timeout + 1;

    end


    if (uart_tx !== 1'b0) begin

        $display("FAIL: UART START bit not detected");

        fail_count = fail_count + 1;

    end


    else begin

        repeat (UART_BAUD_DIVIDER / 2) @(posedge clk);


        check_1(
            uart_tx,
            1'b0,
            "UART START bit"
        );


        // Sample data bits
        for (j = 0; j < 8; j = j + 1) begin

            repeat (UART_BAUD_DIVIDER) @(posedge clk);


            if (uart_tx === uart_byte[j]) begin

                pass_count = pass_count + 1;

            end

            else begin

                $display(
                    "FAIL: UART TX bit %0d Expected = %b Actual = %b",
                    j,
                    uart_byte[j],
                    uart_tx
                );

                fail_count = fail_count + 1;

            end

        end


        // STOP
        repeat (UART_BAUD_DIVIDER) @(posedge clk);


        check_1(
            uart_tx,
            1'b1,
            "UART STOP bit"
        );

    end

end

endtask



/***************************
MAIN MCU TEST
*****************************/

initial begin

    clk = 1'b0;

    reset = 1'b1;

    gpio_in = 8'b0;

    uart_rx = 1'b1;

    i2c_slave_ack_enable = 1'b1;

    i2c_slave_read_byte = 8'h5A;

    forced_address = 32'b0;

    forced_write_data = 32'b0;

    pass_count = 0;

    fail_count = 0;


    #1;



    /****************************
    TEST 1
    CPU -> INTERCONNECT -> GPIO
    *******************************/

    $display("");
    $display("TEST 1: CPU GPIO INTEGRATION");


    load_nops();


    // lui x1, 0x10000
    // x1 = 0x1000_0000
    dut.instruction_memory.memory[0] = 32'h100000B7;
    dut.instruction_memory.memory[1] = 32'h00000013;
    dut.instruction_memory.memory[2] = 32'h00000013;

    // addi x2, x0, 255
    dut.instruction_memory.memory[3] = 32'h0FF00113;
    dut.instruction_memory.memory[4] = 32'h00000013;
    dut.instruction_memory.memory[5] = 32'h00000013;

    // sw x2, 8(x1)
    // GPIO_DIR = FF
    dut.instruction_memory.memory[6] = 32'h0020A423;


    // addi x3, x0, 165
    dut.instruction_memory.memory[7] = 32'h0A500193;


    dut.instruction_memory.memory[8] = 32'h00000013;


    dut.instruction_memory.memory[9] = 32'h00000013;


    // sw x3, 0(x1)
    // GPIO_OUT = A5
    dut.instruction_memory.memory[10] = 32'h0030A023;


    reset_mcu();


    repeat (50) @(posedge clk);


    check_8(
        gpio_dir,
        8'hFF,
        "CPU writes GPIO_DIR"
    );


    check_8(
        gpio_out,
        8'hA5,
        "CPU writes GPIO_OUT"
    );



    /*********************************
            Prepare For Tests
    ***********************************/

    load_nops();

    reset_mcu();



    /********************
    TEST 2: RESET VALUES
    ********************/

    $display("");
    $display("TEST 2: RESET VALUES");


    check_8(
        gpio_out,
        8'h00,
        "GPIO output reset"
    );


    check_8(
        gpio_dir,
        8'h00,
        "GPIO direction reset"
    );


    check_1(
        uart_tx,
        1'b1,
        "UART idle HIGH"
    );


    check_1(
        spi_cs,
        1'b1,
        "SPI CS inactive"
    );


    check_1(
        spi_sclk,
        1'b0,
        "SPI clock idle LOW"
    );


    check_1(
        i2c_scl,
        1'b1,
        "I2C SCL released HIGH"
    );


    check_1(
        i2c_sda,
        1'b1,
        "I2C SDA released HIGH"
    );



    /******************
    TEST 3: DATA MEMORY
    ******************/

    $display("");
    $display("TEST 3: DATA MEMORY");


    bus_write(
        RAM_BASE + 32'h20,
        32'hDEADBEEF
    );


    bus_read(
        RAM_BASE + 32'h20,
        read_value
    );


    check_32(
        read_value,
        32'hDEADBEEF,
        "RAM write and read"
    );



    /*********
    TEST 4: GPIO
    ***********/

    $display("");
    $display("TEST 4: GPIO");


    gpio_in = 8'h5A;


    bus_write(
        GPIO_DIR,
        32'h000000FF
    );


    bus_write(
        GPIO_OUT,
        32'h0000003C
    );


    bus_read(
        GPIO_DIR,
        read_value
    );


    check_32(
        read_value,
        32'h000000FF,
        "GPIO_DIR read"
    );


    bus_read(
        GPIO_OUT,
        read_value
    );


    check_32(
        read_value,
        32'h0000003C,
        "GPIO_OUT read"
    );


    bus_read(
        GPIO_IN,
        read_value
    );


    check_32(
        read_value,
        32'h0000005A,
        "GPIO_IN read"
    );



    /****************
    TEST 5
    UNMAPPED ADDRESS
    *****************/

    $display("");
    $display("TEST 5: UNMAPPED ADDRESS");


    bus_read(
        32'h2000_0000,
        read_value
    );


    check_32(
        read_value,
        32'h00000000,
        "Unmapped address returns zero"
    );



    /*******************
    TEST 6: UART TRANSMIT
    ********************/

    $display("");
    $display("TEST 6: UART TRANSMIT");


    uart_check_transmit(
        8'hA5
    );



    /*******************
    TEST 7: UART RECEIVE
    ********************/

    $display("");
    $display("TEST 7: UART RECEIVE");


    uart_send_byte(
        8'h3C
    );


    bus_read(
        UART_STATUS,
        read_value
    );


    check_1(
        read_value[1],
        1'b1,
        "UART RX valid"
    );


    bus_read(
        UART_DATA,
        read_value
    );


    check_8(
        read_value[7:0],
        8'h3C,
        "UART received byte"
    );


    // Clear RX valid
    bus_write(
        UART_STATUS,
        32'h00000002
    );


    bus_read(
        UART_STATUS,
        read_value
    );


    check_1(
        read_value[1],
        1'b0,
        "UART RX valid clear"
    );



    /*******************
    TEST 8: SPI LOOPBACK
    ********************/

    $display("");
    $display("TEST 8: SPI LOOPBACK");


    bus_write(
        SPI_DATA,
        32'h000000A6
    );


    wait_for_spi();


    bus_read(
        SPI_DATA,
        read_value
    );


    check_8(
        read_value[7:0],
        8'hA6,
        "SPI loopback byte"
    );


    bus_read(
        SPI_STATUS,
        read_value
    );


    check_1(
        read_value[1],
        1'b1,
        "SPI transfer complete flag"
    );


    // SPI interrupt is disabled but should still become pending.

    repeat (2) @(posedge clk);


    bus_read(
        INTERRUPT_PENDING,
        read_value
    );

    check_1(
        read_value[2],
        1'b1,
        "Disabled SPI interrupt becomes pending"
    );


    check_1(
        dut.cpu_interrupt,
        1'b0,
        "Disabled SPI interrupt does not reach CPU"
    );


    // Clear SPI source
    bus_write(
        SPI_STATUS,
        32'h00000002
    );


    repeat (2) @(posedge clk);


    // Clear controller pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000004
    );


    repeat (2) @(posedge clk);



    /*****************
    TEST 9: I2C WRITE
    ****************/

    $display("");
    $display("TEST 9: I2C WRITE");


    i2c_slave_ack_enable = 1'b1;


    bus_write(
        I2C_ADDRESS,
        32'h00000050
    );


    bus_write(
        I2C_DATA,
        32'h0000003C
    );


    // Bit 0 = START
    // Bit 1 = 0 for WRITE
    bus_write(
        I2C_CONTROL,
        32'h00000001
    );


    wait_for_i2c();


    bus_read(
        I2C_STATUS,
        read_value
    );


    check_1(
        read_value[1],
        1'b1,
        "I2C write complete"
    );


    check_1(
        read_value[2],
        1'b0,
        "I2C write ACK"
    );


    // Clear I2C complete
    bus_write(
        I2C_STATUS,
        32'h00000002
    );


    repeat (2) @(posedge clk);


    // Clear I2C pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000008
    );


    repeat (2) @(posedge clk);



    /*****************
    TEST 10: I2C READ
    *******************/

    $display("");
    $display("TEST 10: I2C READ");


    i2c_slave_read_byte = 8'h5A;

    i2c_slave_ack_enable = 1'b1;


    bus_write(
        I2C_ADDRESS,
        32'h00000050
    );


    // Bit 0 = START
    // Bit 1 = READ
    bus_write(
        I2C_CONTROL,
        32'h00000003
    );


    wait_for_i2c();

    bus_read(
        I2C_DATA,
        read_value
    );


    check_8(
        read_value[7:0],
        8'h5A,
        "I2C received byte"
    );


    bus_read(
        I2C_STATUS,
        read_value
    );


    check_1(
        read_value[2],
        1'b0,
        "I2C read ACK"
    );


    // Clear source
    bus_write(
        I2C_STATUS,
        32'h00000002
    );


    repeat (2) @(posedge clk);


    // Clear controller pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000008
    );


    repeat (2) @(posedge clk);



    /********************
    TEST 11: I2C ACK ERROR
    *********************/

    $display("");
    $display("TEST 11: I2C ACK ERROR");


    i2c_slave_ack_enable = 1'b0;


    bus_write(
        I2C_ADDRESS,
        32'h00000050
    );


    bus_write(
        I2C_CONTROL,
        32'h00000001
    );


    wait_for_i2c();


    bus_read(
        I2C_STATUS,
        read_value
    );


    check_1(
        read_value[2],
        1'b1,
        "I2C ACK error detected"
    );


    // Clear complete and ACK error
    bus_write(
        I2C_STATUS,
        32'h00000006
    );


    repeat (2) @(posedge clk);


    // Clear interrupt pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000008
    );


    repeat (2) @(posedge clk);


    i2c_slave_ack_enable = 1'b1;



    /***************
    TEST 12: TIMER
    *****************/

    $display("");
    $display("TEST 12: TIMER");


    // Clear controller pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h0000001F
    );


    // Enable Timer interrupt in controller
    bus_write(
        INTERRUPT_ENABLE,
        32'h00000001
    );


    // Timer Compare = 5
    bus_write(
        TIMER_COMPARE,
        32'h00000005
    );


    // Bit 0 = Timer Enable
    // Bit 1 = Interrupt Enable
    bus_write(
        TIMER_CONTROL,
        32'h00000003
    );


    wait_for_timer();


    repeat (2) @(posedge clk);


    bus_read(
        TIMER_STATUS,
        read_value
    );


    check_1(
        read_value[0],
        1'b1,
        "Timer event flag"
    );


    check_1(
        dut.cpu_interrupt,
        1'b1,
        "Timer reaches CPU interrupt"
    );


    if (dut.interrupt_id === 3'd0) begin

        $display("PASS: Timer interrupt ID");

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: Timer interrupt ID Expected = 0 Actual = %0d",
            dut.interrupt_id
        );

        fail_count = fail_count + 1;

    end


    bus_read(
        INTERRUPT_PENDING,
        read_value
    );


    check_1(
        read_value[0],
        1'b1,
        "Timer pending bit"
    );


    // Disable Timer
    bus_write(
        TIMER_CONTROL,
        32'h00000000
    );


    // Clear Timer source
    bus_write(
        TIMER_STATUS,
        32'h00000001
    );


    repeat (2) @(posedge clk);


    // Clear controller pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000001
    );


    repeat (2) @(posedge clk);


    check_1(
        dut.cpu_interrupt,
        1'b0,
        "Timer interrupt clears"
    );



    /*************************************************************
    TEST 13
    INTERRUPT PRIORITY

    SPI and I2C are both enabled and both generate interrupts
    **************************************************************/

    $display("");
    $display("TEST 13: INTERRUPT PRIORITY");


    // Enable SPI and I2C
    // Bit 2 = SPI
    // Bit 3 = I2C
    bus_write(
        INTERRUPT_ENABLE,
        32'h0000000C
    );


    // Start SPI Transfer
    bus_write(
        SPI_DATA,
        32'h00000055
    );


    wait_for_spi();


    // Start I2C Transfer
    bus_write(
        I2C_ADDRESS,
        32'h00000050
    );


    bus_write(
        I2C_DATA,
        32'h000000AA
    );


    bus_write(
        I2C_CONTROL,
        32'h00000001
    );


    wait_for_i2c();


    repeat (2) @(posedge clk);


    check_1(
        dut.cpu_interrupt,
        1'b1,
        "SPI and I2C request CPU"
    );


    if (dut.interrupt_id === 3'd2) begin

        $display("PASS: SPI has priority over I2C");

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: Interrupt priority Expected ID = 2 Actual = %0d",
            dut.interrupt_id
        );

        fail_count = fail_count + 1;

    end



    /*****************************************
    TEST 14
    NEW INTERRUPT WINS OVER CLEAR

    SPI transfer_complete is still HIGH.
    *****************************************/

    $display("");
    $display("TEST 14: NEW INTERRUPT WINS OVER CLEAR");


    bus_write(
        INTERRUPT_CLEAR,
        32'h00000004
    );


    repeat (2) @(posedge clk);


    bus_read(
        INTERRUPT_PENDING,
        read_value
    );


    check_1(
        read_value[2],
        1'b1,
        "Active SPI interrupt wins over clear"
    );



    bus_write(
        SPI_STATUS,
        32'h00000002
    );


    repeat (2) @(posedge clk);


    bus_write(
        INTERRUPT_CLEAR,
        32'h00000004
    );


    repeat (2) @(posedge clk);


    bus_read(
        INTERRUPT_PENDING,
        read_value
    );


    check_1(
        read_value[2],
        1'b0,
        "SPI pending clears after source LOW"
    );



    check_1(
        dut.cpu_interrupt,
        1'b1,
        "I2C remains active after SPI clears"
    );


    if (dut.interrupt_id === 3'd3) begin

        $display("PASS: I2C selected after SPI clears");

        pass_count = pass_count + 1;

    end

    else begin

        $display(
            "FAIL: I2C interrupt ID Expected = 3 Actual = %0d",
            dut.interrupt_id
        );

        fail_count = fail_count + 1;

    end


    // Clear I2C source
    bus_write(
        I2C_STATUS,
        32'h00000002
    );


    repeat (2) @(posedge clk);


    // Clear I2C controller pending
    bus_write(
        INTERRUPT_CLEAR,
        32'h00000008
    );


    repeat (2) @(posedge clk);


    check_1(
        dut.cpu_interrupt,
        1'b0,
        "All enabled interrupts cleared"
    );



    /*****************
    FINAL RESULTS
    ******************/

    $display("");
    $display("========================================");
    $display("MCU TEST RESULTS");
    $display("========================================");
    $display("PASSED: %0d", pass_count);
    $display("FAILED: %0d", fail_count);
    $display("========================================");


    if (fail_count == 0) begin

        $display("ALL MCU TESTS PASSED");

    end

    else begin

        $display("MCU TESTS FAILED");

    end


    $finish;

end


endmodule