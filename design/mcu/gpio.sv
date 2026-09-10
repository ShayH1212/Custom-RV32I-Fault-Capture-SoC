/*

GPIO (Genaral Purpose Input Output)

This module provides a "general purpose" digital input and output pins for the MCU.

It allows the CPU to configure pins as either inputs or outputs, write values
to output pins, and read the current values present on input pins.

The GPIO is controlled through memory mapped regs.

GPIO is used for simple digital signals that do not require a dedicated
communication protocol such as SPI, I2C, or UART. These pins can be used for
things such as LEDs, buttons, reset signals, enable signals, fault signals, or
other basic digital inputs and outputs.

The direction reg description

For this design:

    1 = Output
    0 = Input

For example:

    direction_register = 8'b00000101

    GPIO 0 = Output
    GPIO 1 = Input
    GPIO 2 = Output
    GPIO 3 = Input
    GPIO 4 = Input
    GPIO 5 = Input
    GPIO 6 = Input
    GPIO 7 = Input


The CPU can change the direction of the GPIO pins by writing a new value to
the GPIO_DIR reg.

The direction register is necessary because a GPIO pin can either drive a
digital value out of the MCU or receive a digital value from an external
device. The hardware therefore needs to know which direction the signal is
supposed to travel.

*/

module gpio (

    input logic clk,
    input logic reset,

    // CPU interconnect 
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,
    // Physical GPIO signals
    input logic [7:0] gpio_in,
    output logic [7:0] gpio_out,
    output logic [7:0] gpio_dir

);

logic [7:0] output_register;
logic [7:0] direction_register;


// Connect internal registers to GPIO outputs
assign gpio_out = output_register;
assign gpio_dir = direction_register;


// Write registers
always_ff @(posedge clk) begin

    if (reset) begin
        output_register <= 8'b0;
        direction_register <= 8'b0;
    end

    else if (write_enable) begin

        // GPIO_OUT
        if (address[3:0] == 4'b0) begin
            output_register <= write_data[7:0];
        end

        // GPIO_DIR
        else if (address[3:0] == 4'b1000) begin
            direction_register <= write_data[7:0];
        end

    end

end


// Read registers
always_comb begin

    read_data = 32'b0;

    // GPIO_OUT
    if (address[3:0] == 4'b0) begin
        read_data = {24'b0, output_register};
    end

    // GPIO_IN
    else if (address[3:0] == 4'b0100) begin
        read_data = {24'b0, gpio_in};
    end

    // GPIO_DIR
    else if (address[3:0] == 4'b1000) begin
        read_data = {24'b0, direction_register};
    end

end

endmodule