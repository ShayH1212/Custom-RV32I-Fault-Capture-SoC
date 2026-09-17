/*********************************************************************
I2C Master

Single master, 7-bit I2C controller.
Supports single byte read and write transactions.
An FSM controls START, address, data, ACK/NACK, and STOP sequencing.

*********************************************************************/
module i2c_master #(

    parameter integer CLOCK_FREQUENCY = 50_000_000,
    parameter integer I2C_FREQUENCY = 100_000

)
(
    input logic clk,
    input logic reset,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,

    // I2C signals
    inout wire i2c_scl,
    inout wire i2c_sda,
    output logic i2c_interrupt
);

// Number of MCU clock cycles for half of one I2C clock period
localparam integer HALF_PERIOD_COUNT = CLOCK_FREQUENCY / (I2C_FREQUENCY * 2);

// I2C states
localparam logic [3:0] I2C_IDLE = 4'b0000;
localparam logic [3:0] I2C_START = 4'b0001;
localparam logic [3:0] I2C_ADDRESS = 4'b0010;
localparam logic [3:0] I2C_ADDRESS_ACK = 4'b0011;
localparam logic [3:0] I2C_WRITE_DATA = 4'b0100;
localparam logic [3:0] I2C_WRITE_ACK = 4'b0101;
localparam logic [3:0] I2C_READ_DATA = 4'b0110;
localparam logic [3:0] I2C_READ_NACK = 4'b0111;
localparam logic [3:0] I2C_STOP = 4'b1000;

// Internal registers
logic [3:0] i2c_state;
logic [6:0] device_address;
logic [7:0] tx_data_register;
logic [7:0] rx_data_register;
logic [7:0] rx_shift_register;
logic [7:0] address_byte_register;
logic read_operation;
logic [2:0] bit_counter;
integer clock_counter;
logic clock_phase;
logic i2c_busy;
logic transfer_complete;
logic ack_error;

// Open drain control signals
logic scl_drive_low;
logic sda_drive_low;

// Indicates that half of one I2C clock period has passed
logic half_period_done;

logic scl_output;
logic sda_output;

assign half_period_done =
    (clock_counter == HALF_PERIOD_COUNT - 1);


// Open drain control for the I2C clock and data
always_comb begin

    if (scl_drive_low == 1'b1) begin
        scl_output = 1'b0;
    end
    else begin
        scl_output = 1'bz;
    end

    if (sda_drive_low == 1'b1) begin
        sda_output = 1'b0;
    end
    else begin
        sda_output = 1'bz;
    end

end

assign i2c_scl = scl_output;
assign i2c_sda = sda_output;

assign i2c_interrupt = transfer_complete;





always_ff @(posedge clk) begin

    if (reset) begin

        i2c_state <= I2C_IDLE;

        device_address <= 7'b0;
        tx_data_register <= 8'b0;
        rx_data_register <= 8'b0;
        rx_shift_register <= 8'b0;
        address_byte_register <= 8'b0;
        read_operation <= 1'b0;
        bit_counter <= 3'b0;
        clock_counter <= 0;
        clock_phase <= 1'b0;
        i2c_busy <= 1'b0;
        transfer_complete <= 1'b0;
        ack_error <= 1'b0;

        scl_drive_low <= 1'b0;
        sda_drive_low <= 1'b0;

    end


    else begin


        // TX data register
        if (write_enable && address[3:0] == 4'b0000 && i2c_state == I2C_IDLE) begin

            tx_data_register <= write_data[7:0];

        end



        // Device address register
        if (write_enable && address[3:0] == 4'b0100 && i2c_state == I2C_IDLE) begin

            device_address <= write_data[6:0];

        end



        // Write 1 to clear status flags
        if (write_enable && address[3:0] == 4'b1100) begin

            if (write_data[1] == 1'b1) begin

                transfer_complete <= 1'b0;

            end


            if (write_data[2] == 1'b1) begin

                ack_error <= 1'b0;

            end

        end



        // I2C IDLE

        if (i2c_state == I2C_IDLE) begin

            scl_drive_low <= 1'b0;

            sda_drive_low <= 1'b0;

            i2c_busy <= 1'b0;

            clock_counter <= 0;

            clock_phase <= 1'b0;


            // CPU writes a 1 to bit 0 of I2C_CONTROL to start

            if (write_enable &&
                address[3:0] == 4'b1000 &&
                write_data[0] == 1'b1) begin

                read_operation <= write_data[1];

                address_byte_register <=
                    {device_address, write_data[1]};

                i2c_busy <= 1'b1;

                transfer_complete <= 1'b0;

                ack_error <= 1'b0;

                clock_counter <= 0;

                clock_phase <= 1'b0;

                i2c_state <= I2C_START;

            end

        end



       // I2C START

        else if (i2c_state == I2C_START) begin

            scl_drive_low <= 1'b0;

            sda_drive_low <= 1'b1;


            if (half_period_done) begin

                clock_counter <= 0;

                scl_drive_low <= 1'b1;

                bit_counter <= 3'b111;

                clock_phase <= 1'b0;

                i2c_state <= I2C_ADDRESS;

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end




        // I2C ADDRESS

        else if (i2c_state == I2C_ADDRESS) begin


            if (address_byte_register[bit_counter] == 1'b0) begin

                sda_drive_low <= 1'b1;

            end


            else begin

                sda_drive_low <= 1'b0;

            end


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    // Release SCL so that it moves HIGH

                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    // Pull SCL LOW again

                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;


                    if (bit_counter == 3'b000) begin

                        // Release SDA so the external device can ACK

                        sda_drive_low <= 1'b0;

                        i2c_state <= I2C_ADDRESS_ACK;

                    end


                    else begin

                        bit_counter <= bit_counter - 1'b1;

                    end

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end




        // I2C ADDRESS ACK

        else if (i2c_state == I2C_ADDRESS_ACK) begin

            sda_drive_low <= 1'b0;


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    // Raise SCL
                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    // Check ACK while SCL is HIGH
                    if (i2c_sda != 1'b0) begin

                        ack_error <= 1'b1;

                    end


                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;


                    // Address was not acknowledged
                    if (i2c_sda != 1'b0) begin

                        i2c_state <= I2C_STOP;

                    end


                    // Address was acknowledged
                    else begin

                        bit_counter <= 3'b111;


                        if (read_operation == 1'b1) begin

                            rx_shift_register <= 8'b0;

                            i2c_state <= I2C_READ_DATA;

                        end


                        else begin

                            i2c_state <= I2C_WRITE_DATA;

                        end

                    end

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end



        // I2C WRITE DATA

        else if (i2c_state == I2C_WRITE_DATA) begin


            if (tx_data_register[bit_counter] == 1'b0) begin

                sda_drive_low <= 1'b1;

            end


            else begin

                sda_drive_low <= 1'b0;

            end



            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;


                    if (bit_counter == 3'b000) begin

                        sda_drive_low <= 1'b0;

                        i2c_state <= I2C_WRITE_ACK;

                    end


                    else begin

                        bit_counter <= bit_counter - 1'b1;

                    end

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end




        // I2C WRITE ACK

        else if (i2c_state == I2C_WRITE_ACK) begin

            sda_drive_low <= 1'b0;


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    if (i2c_sda != 1'b0) begin

                        ack_error <= 1'b1;

                    end


                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;

                    i2c_state <= I2C_STOP;

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end



        // I2C READ DATA

        else if (i2c_state == I2C_READ_DATA) begin

            sda_drive_low <= 1'b0;


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    // Save the received bit

                    rx_shift_register[bit_counter] <= i2c_sda;

                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;


                    if (bit_counter == 3'b000) begin

                        i2c_state <= I2C_READ_NACK;

                    end


                    else begin

                        bit_counter <= bit_counter - 1'b1;

                    end

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end




        // I2C READ NACK


        else if (i2c_state == I2C_READ_NACK) begin

            sda_drive_low <= 1'b0;


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    scl_drive_low <= 1'b0;

                    clock_phase <= 1'b1;

                end


                else begin

                    scl_drive_low <= 1'b1;

                    clock_phase <= 1'b0;

                    rx_data_register <= rx_shift_register;

                    i2c_state <= I2C_STOP;

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end



        // I2C STOP

        else if (i2c_state == I2C_STOP) begin

            sda_drive_low <= 1'b1;


            if (half_period_done) begin

                clock_counter <= 0;


                if (clock_phase == 1'b0) begin

                    // Raise SCL while SDA remains LOW
                    scl_drive_low <= 1'b0;
                    clock_phase <= 1'b1;

                end


                else begin

                    // Release SDA while SCL is HIGH
                    sda_drive_low <= 1'b0;
                    scl_drive_low <= 1'b0;
                    clock_phase <= 1'b0;
                    i2c_busy <= 1'b0;
                    transfer_complete <= 1'b1;
                    i2c_state <= I2C_IDLE;

                end

            end


            else begin

                clock_counter <= clock_counter + 1;

            end

        end

    end

end



// CPU reads I2C registers

always_comb begin

    read_data = 32'b0;


    // I2C_DATA
    if (address[3:0] == 4'b0000) begin

        read_data = {24'b0, rx_data_register};

    end


    // I2C_ADDRESS
    else if (address[3:0] == 4'b0100) begin

        read_data[6:0] = device_address;

    end


    // I2C_CONTROL
    else if (address[3:0] == 4'b1000) begin

        read_data[1] = read_operation;

    end


    // I2C_STATUS
    else if (address[3:0] == 4'b1100) begin

        read_data[0] = ~i2c_busy;

        read_data[1] = transfer_complete;

        read_data[2] = ack_error;

    end

end


endmodule