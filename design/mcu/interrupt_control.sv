/************************************************************
Interrupt Controller

Memory-mapped interrupt controller for five MCU peripherals.
Interrupt requests are stored in sticky pending bits.

Priority is as follows:
Timer -> GPIO -> SPI -> I2C -> UART.
***********************************************************/

module interrupt_controller (
    input logic clk,
    input logic reset,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,

    // Interrupt requests from peripherals
    input logic timer_interrupt,
    input logic gpio_interrupt,
    input logic spi_interrupt,
    input logic i2c_interrupt,
    input logic uart_interrupt,


    // Interrupt request sent to CPU
    output logic cpu_interrupt,

    // ID of interrupt (highest priority)
    output logic [2:0] interrupt_id
);


// Interrupt regs
logic [4:0] interrupt_enable;
logic [4:0] interrupt_pending;

// Current periferals being requested 
logic [4:0] interrupt_requests;

// What CPU wants to clear
logic [4:0] interrupt_clear_mask;

// Which interrupts qualify to reach the CPU
logic [4:0] enabled_pending_interrupts;



always_comb begin
    // Combine the individual wires into one wire
    interrupt_requests = 5'b0;
    interrupt_requests[0] = timer_interrupt;
    interrupt_requests[1] = gpio_interrupt;
    interrupt_requests[2] = spi_interrupt;
    interrupt_requests[3] = i2c_interrupt;
    interrupt_requests[4] = uart_interrupt;
end



always_comb begin

    interrupt_clear_mask = 5'b0;

    if (write_enable && address[3:0] == 4'b1000) begin
    interrupt_clear_mask = write_data[4:0];
    end

end


always_ff @(posedge clk) begin

    if (reset) begin
        interrupt_pending <= 5'b0;
    end


    else begin
// Keep the old pending bits except the ones the CPU is clearing
        interrupt_pending <= ((interrupt_pending & ~interrupt_clear_mask) | interrupt_requests);

    end

end


always_ff @(posedge clk) begin

    if (reset) begin
        interrupt_enable <= 5'b0;
    end

    else begin
        // If we are writing to 0x0 = INTERRUPT_ENABLE
        // Then we set the write data to whatever interrupts are allowed through
        if (write_enable && address[3:0] == 4'b0000) begin 
            interrupt_enable <= write_data[4:0];
         end
    end

end


always_comb begin

    enabled_pending_interrupts = interrupt_pending & interrupt_enable;

end

always_comb begin


    cpu_interrupt = 1'b0;

    if (enabled_pending_interrupts != 5'b0) begin
        cpu_interrupt = 1'b1;
    end

end





always_comb begin

    interrupt_id = 3'b000;

    // Timer (Highest priority )
    if (enabled_pending_interrupts[0]) begin
        interrupt_id = 3'd0;
    end

    // GPIO (Second Highest)
    else if (enabled_pending_interrupts[1]) begin
        interrupt_id = 3'd1;
    end

    // SPI (Third Highest)
    else if (enabled_pending_interrupts[2]) begin
        interrupt_id = 3'd2;
    end

    // I2C (Forth Highest)
    else if (enabled_pending_interrupts[3]) begin
        interrupt_id = 3'd3;
    end

    // UART (Lowest priority)  
    else if (enabled_pending_interrupts[4]) begin
        interrupt_id = 3'd4;
    end

end



/***************
CPU Read Logic
**************/

always_comb begin

    read_data = 32'b0;

    // INTERRUPT_ENABLE
    if (address[3:0] == 4'b0000) begin
        read_data[4:0] = interrupt_enable;
    end


    // INTERRUPT_PENDING
    else if (address[3:0] == 4'b0100) begin
        read_data[4:0] = interrupt_pending;
    end

end


endmodule