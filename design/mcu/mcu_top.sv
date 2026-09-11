module mcu_top (
    input logic clk,
    input logic reset,

    // GPIO
    input logic [7:0] gpio_in,
    output logic [7:0] gpio_out,
    output logic [7:0] gpio_dir,

    // UART
    input logic uart_rx,
    output logic uart_tx,

    // SPI
    output logic spi_sclk,
    output logic spi_mosi,
    input logic spi_miso,
    output logic spi_cs,

    // I2C
    inout wire i2c_scl,
    inout wire i2c_sda
    
);

wire data_write_enable;
wire [31:0] data_address;
wire [31:0] data_read_address;
wire [31:0] data_write_data;
logic [31:0] data_read_data;
logic [31:0] instruction_address;
logic [31:0] instruction_data;

// Memory Interconnect signals
logic [31:0] memory_address;
logic [31:0] memory_write_data;
logic memory_write_enable;
logic [31:0] memory_read_data;
logic gpio_write_enable;
logic [31:0] gpio_read_data;
logic uart_write_enable;
logic [31:0] uart_read_data;
logic spi_write_enable;
logic [31:0] spi_read_data;
logic i2c_write_enable;
logic [31:0] i2c_read_data;
logic timer_write_enable;
logic [31:0] timer_read_data;
logic interrupt_write_enable;
logic [31:0] interrupt_read_data;
logic timer_interrupt;
logic cpu_interrupt;
logic [2:0] interrupt_id;
logic gpio_interrupt;
logic uart_interrupt;
logic spi_interrupt;
logic i2c_interrupt;

assign gpio_interrupt = 1'b0;
assign uart_interrupt = 1'b0;


/*<><<><><><><><><>
      CPU CORE
<<><<><><><><><><>*/
pipelined_cpu_core cpu (
    .clk(clk),
    .reset(reset),
    .data_write_enable(data_write_enable),
    .data_address(data_address),
    .data_read_address(data_read_address),
    .data_write_data(data_write_data),
    .data_read_data(data_read_data),
    .instruction_address(instruction_address),
    .instruction_data(instruction_data)
);


/*<><<><><><><><><>
    DATA MEMORY
<<><<><><><><><><>*/
data_mem data_memory (
    .clk(clk),
    .mem_write(memory_write_enable),
    .read_address(data_read_address),
    .write_address(memory_address),
    .write_data(memory_write_data),
    .read_data(memory_read_data)
);

/*<><<><><><><><><><><>
    INSTRUCTION MEMORY
<<><<><><><><><><><><>*/
instruction_mem instruction_memory (
    .address(instruction_address),
    .instruction(instruction_data)
);


/*<><<><><><><><><><><><>
    MEMORY INTERCONNECT
<<><<><><><><><><><><><>*/
memory_interconnect memory_interconnect_unit (
    // CPU
    .cpu_address(data_address),
    .cpu_write_data(data_write_data),
    .cpu_write_enable(data_write_enable),
    .cpu_read_data(data_read_data),
    .memory_address(memory_address),
    .memory_write_data(memory_write_data),
    .memory_write_enable(memory_write_enable),
    .memory_read_data(memory_read_data),

    // GPIO
    .gpio_write_enable(gpio_write_enable),
    .gpio_read_data(gpio_read_data),

    // UART
    .uart_write_enable(uart_write_enable),
    .uart_read_data(uart_read_data),

    // SPI
    .spi_write_enable(spi_write_enable),
    .spi_read_data(spi_read_data),

    // I2C
    .i2c_write_enable(i2c_write_enable),
    .i2c_read_data(i2c_read_data),

    // Timer
    .timer_write_enable(timer_write_enable),
    .timer_read_data(timer_read_data),

    // Interrupt Controller
    .interrupt_write_enable(interrupt_write_enable),
    .interrupt_read_data(interrupt_read_data)
);

/*<><<><><><><><><>
        GPIO
<<><<><><><><><><>*/
gpio gpio_module (
    .clk(clk),
    .reset(reset),
    .address(data_address),
    .write_data(data_write_data),
    .write_enable(gpio_write_enable),
    .read_data(gpio_read_data),

    .gpio_in(gpio_in),
    .gpio_out(gpio_out),
    .gpio_dir(gpio_dir)
);

/*<><<><><><><><><>
        UART
<<><<><><><><><><>*/
uart uart_module (
    .clk(clk),
    .reset(reset),
    .address(data_address),
    .write_data(data_write_data),
    .write_enable(uart_write_enable),
    .read_data(uart_read_data),

    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
);


/*<><<><><><><><><>
        SPI
<<><<><><><><><><>*/
spi_master spi_module (
    .clk(clk),
    .reset(reset),

    .address(data_address),
    .write_data(data_write_data),
    .write_enable(spi_write_enable),
    .read_data(spi_read_data),
    .spi_sclk(spi_sclk),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_cs(spi_cs),
    .spi_interrupt(spi_interrupt)
);


/*<><<><><><><><><>
        I2C
<<><<><><><><><><>*/
i2c_master i2c_module (
    .clk(clk),
    .reset(reset),

    .address(data_address),
    .write_data(data_write_data),
    .write_enable(i2c_write_enable),
    .read_data(i2c_read_data),

    .i2c_scl(i2c_scl),
    .i2c_sda(i2c_sda),

    .i2c_interrupt(i2c_interrupt)
);

/*<><<><><><><><><>
        TIMER
<<><<><><><><><><>*/
timer timer_module (
    .clk(clk),
    .reset(reset),

    .address(data_address),
    .write_data(data_write_data),
    .write_enable(timer_write_enable),
    .read_data(timer_read_data),

    .timer_interrupt(timer_interrupt)
);


/*<><<><><><><><><><><><><>
    INTERRUPT CONTROLLER
<<><<><><><><><><><><><><>*/
interrupt_controller interrupt_module (
    .clk(clk),
    .reset(reset),

    .address(data_address),
    .write_data(data_write_data),
    .write_enable(interrupt_write_enable),
    .read_data(interrupt_read_data),
    .timer_interrupt(timer_interrupt),
    .gpio_interrupt(gpio_interrupt),
    .spi_interrupt(spi_interrupt),
    .i2c_interrupt(i2c_interrupt),
    .uart_interrupt(uart_interrupt),
    .cpu_interrupt(cpu_interrupt),
    .interrupt_id(interrupt_id)
);


endmodule