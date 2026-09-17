/***********************************************************************************
Timer

32-bit memory-mapped hardware timer.

The counter increments while enabled and resets when it reaches the compare value.
A timer event can generate an interrupt when enabled.
************************************************************************************/

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


// Timer interrupt
assign timer_interrupt = timer_event && interrupt_enable;




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



        // Timer counter
        if (timer_enable) begin


            if (compare_register != 32'b0) begin

                // One full timer period passes
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