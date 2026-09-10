/*
Timer

This module provides a hardware timer for the MCU.

The timer uses the MCU clock to increment a counter independently of the CPU.
The CPU can read the current timer value and configure a compare value that
determines when a timer event should occur.

When the counter reaches the programmed compare value, the timer sets an
event flag and resets the counter so that another timing period can begin.

The CPU can enable or disable the timer and can enable or disable timer
interrupts.

Register Map:

    0x0 = TIMER_COUNT
          Current value of the timer counter.
          The CPU can also write to this register to change or reset the count.

    0x4 = TIMER_COMPARE
          The value that the timer counts up to.

    0x8 = TIMER_CONTROL
          Bit 0 = Timer enable
          Bit 1 = Interrupt enable

    0xC = TIMER_STATUS
          Bit 0 = Timer event occurred

          Writing a 1 to bit 0 clears the event flag.
*/


module timer (
    input logic clk,
    input logic reset,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,
    output logic timer_interrupt
);


// Timer registers

logic [31:0] count_register;
logic [31:0] compare_register;

logic timer_enable;
logic interrupt_enable;

logic timer_event;


// Interrupt is active when an event has occurred and interrupts are enabled

assign timer_interrupt = timer_event && interrupt_enable;



/*
Timer Counter

When the timer is enabled, the counter increases by one every MCU clock cycle.

When the counter reaches the compare value, the timer:

    1. Resets the counter to 0
    2. Sets the timer event flag

The timer then begins counting again.
*/

always_ff @(posedge clk) begin

    if (reset) begin
        count_register <= 32'b0;
        compare_register <= 32'b0;
        timer_enable <= 1'b0;
        interrupt_enable <= 1'b0;
        timer_event <= 1'b0;
    end


    else begin


        // CPU writes to timer registers

        if (write_enable) begin


            // TIMER_COUNT
            if (address[3:0] == 4'b0000) begin

                count_register <= write_data;

            end


            // TIMER_COMPARE
            else if (address[3:0] == 4'b0100) begin

                compare_register <= write_data;

            end


            // TIMER_CONTROL
            else if (address[3:0] == 4'b1000) begin

                timer_enable <= write_data[0];
                interrupt_enable <= write_data[1];

            end


            // TIMER_STATUS
            // Writing a 1 to bit 0 clears the timer event

            else if (address[3:0] == 4'b1100) begin

                if (write_data[0] == 1'b1) begin

                    timer_event <= 1'b0;

                end

            end

        end



        // Increase the timer counter while the timer is enabled

        if (timer_enable) begin


            // Make sure the compare value is not 0

            if (compare_register != 32'b0) begin


                // Check whether one full timer period has passed

                if (count_register == compare_register - 1) begin

                    count_register <= 32'b0;
                    timer_event <= 1'b1;

                end


                else begin

                    count_register <= count_register + 1'b1;

                end

            end

        end

    end

end



// CPU reads timer registers

always_comb begin

    read_data = 32'b0;


    // TIMER_COUNT
    if (address[3:0] == 4'b0000) begin

        read_data = count_register;

    end


    // TIMER_COMPARE
    else if (address[3:0] == 4'b0100) begin

        read_data = compare_register;

    end


    // TIMER_CONTROL
    else if (address[3:0] == 4'b1000) begin

        read_data[0] = timer_enable;
        read_data[1] = interrupt_enable;

    end


    // TIMER_STATUS
    else if (address[3:0] == 4'b1100) begin

        read_data[0] = timer_event;

    end

end


endmodule