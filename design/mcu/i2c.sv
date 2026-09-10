/*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
I2C Master

This module allows the MCU to communicate with external devices using
I2C (Inter-Integrated Circuit).

I2C uses two main signals:

    SCL = Serial Clock: Controls the timing of I2C communication.

    SDA = Serial Data: Bidirectional line used to transmit and receive data.

Unlike SPI, multiple I2C devices can share the same SCL and SDA lines.
Each device is identified using an address.

This module operates as the I2C master. The MCU controls when a transaction
begins and the I2C module generates the required clock and data signals.


Design Choices:

1. 7 Bit Device Addressing
   External I2C devices are selected using a 7 bit device address.
   The read/write bit is added to the address when a transaction begins.

2. Single Byte Transactions
   Each transaction transfers one 8 bit data byte.
   Multi byte transfers are not supported in this version.

3. Single I2C Master
   The MCU is the only master allowed to control the I2C bus.
   Multi master arbitration is not implemented.

4. Open Drain SCL and SDA
   The MCU only pulls SCL and SDA LOW or releases them.
   External pull up resistors make the lines HIGH when they are released.

5. Parameterized I2C Clock
   I2C_FREQUENCY determines the target I2C clock frequency and defaults to 100 kHz.
   The timing is generated using the faster MCU clock.

6. MSB First Transmission
   Address and data bytes are transmitted starting with bit 7 and ending with bit 0.
   This follows standard I2C transmission ordering.

7. Hardware Generated START and STOP
   The FSM generates the required START condition before communication and
   the STOP condition when the transaction is complete.

8. ACK and NACK Detection
   The external device must pull SDA LOW to acknowledge an address or written byte.
   If SDA remains HIGH, the ack_error flag is set.

9. Separate Read and Write Paths
   The read/write bit determines whether the FSM sends a data byte or receives one.
   Both operations use the same address and control interface.

10. Single Byte TX and RX Storage
    tx_data_register stores one byte for transmission and rx_data_register stores
    the most recently received byte. No TX or RX FIFO is used.

11. FSM Controlled Transactions
    The controller uses separate states for START, address transfer, acknowledgment,
    data transfer, NACK, STOP, and IDLE operation.

12. Single Byte Reads End With NACK
    After receiving one byte, the MCU sends a NACK to indicate that no additional
    bytes are required before generating the STOP condition.

13. No Clock Stretching
    The master does not wait if an external device holds SCL LOW.
    Clock stretching is not supported in this version.

14. CPU Starts Transactions Through I2C_CONTROL
    Writing a 1 to bit 0 of I2C_CONTROL begins a transaction.
    Bit 1 selects whether the transaction is a read or write.

15. Transfer Complete and ACK Error Flags
    transfer_complete records that the transaction finished and ack_error records
    that an expected acknowledgment was not received.

16. Write 1 to Clear Status Flags
    Writing a 1 to bit 1 or bit 2 of I2C_STATUS clears transfer_complete or
    ack_error respectively.

17. Transfer Complete Interrupt
    i2c_interrupt is connected to transfer_complete and becomes active when
    an I2C transaction has finished.


Register Map:

    0x0 = I2C_DATA

          Writing: Stores the byte that will be transmitted.

          Reading: Returns the most recently received byte.


    0x4 = I2C_ADDRESS

          Bits [6:0] = 7 bit external device address


    0x8 = I2C_CONTROL

          Bit 0 = Start transaction
          Bit 1 = Read operation

                  0 = Write
                  1 = Read


    0xC = I2C_STATUS

          Bit 0 = Ready
          Bit 1 = Transfer complete
          Bit 2 = ACK error

          Writing a 1 to bit 1 clears transfer complete.
          Writing a 1 to bit 2 clears ACK error.

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/


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
localparam integer HALF_PERIOD_COUNT =
    CLOCK_FREQUENCY / (I2C_FREQUENCY * 2);


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

assign half_period_done =
    (clock_counter == HALF_PERIOD_COUNT - 1);


/*************************************************************
Open Drain I2C Signals

The MCU can pull each line LOW or release it.

External pull up resistors make the lines HIGH when released.
**************************************************************/

assign i2c_scl = scl_drive_low ? 1'b0 : 1'bz;

assign i2c_sda = sda_drive_low ? 1'b0 : 1'bz;



/*************************************************************
I2C Interrupt

The interrupt becomes active when a transaction has completed.
**************************************************************/

assign i2c_interrupt = transfer_complete;



/********************************************************************************
I2C Master FSM

The I2C controller moves through the following states:

    I2C_IDLE

    Waits for the CPU to request an I2C transaction.


    I2C_START

    Generates the START condition by pulling SDA LOW while SCL is HIGH.


    I2C_ADDRESS

    Sends the 7 bit device address followed by the read/write bit.


    I2C_ADDRESS_ACK

    Releases SDA and checks whether the external device acknowledged
    the address.


    I2C_WRITE_DATA

    Sends one 8 bit data byte to the external device.


    I2C_WRITE_ACK

    Checks whether the external device acknowledged the transmitted byte.


    I2C_READ_DATA

    Receives one 8 bit data byte from the external device.


    I2C_READ_NACK

    Sends a NACK after receiving the byte to indicate that no additional
    bytes are required.


    I2C_STOP

    Generates the STOP condition and completes the transaction.


State transitions:

    IDLE -> START : CPU requests a transaction

    START -> ADDRESS : START condition has been generated

    ADDRESS -> ADDRESS_ACK : Address and read/write bit have been sent

    ADDRESS_ACK -> WRITE_DATA : Address acknowledged and write operation selected

    ADDRESS_ACK -> READ_DATA : Address acknowledged and read operation selected

    ADDRESS_ACK -> STOP : Address was not acknowledged

    WRITE_DATA -> WRITE_ACK : All 8 data bits have been sent

    WRITE_ACK -> STOP : Data acknowledgment has been checked

    READ_DATA -> READ_NACK : All 8 data bits have been received

    READ_NACK -> STOP : NACK has been sent

    STOP -> IDLE : Transaction is complete

********************************************************************************/


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


        /*************************************************************
        CPU stores the byte that will be transmitted.

        Data can only be changed while the I2C controller is idle.
        **************************************************************/

        if (write_enable &&
            address[3:0] == 4'b0000 &&
            i2c_state == I2C_IDLE) begin

            tx_data_register <= write_data[7:0];

        end



        /*************************************************************
        CPU stores the 7 bit address of the external I2C device.
        **************************************************************/

        if (write_enable &&
            address[3:0] == 4'b0100 &&
            i2c_state == I2C_IDLE) begin

            device_address <= write_data[6:0];

        end



        /*************************************************************
        CPU clears status flags by writing a 1 to the corresponding bit.
        **************************************************************/

        if (write_enable &&
            address[3:0] == 4'b1100) begin

            if (write_data[1] == 1'b1) begin

                transfer_complete <= 1'b0;

            end


            if (write_data[2] == 1'b1) begin

                ack_error <= 1'b0;

            end

        end



        /*****************************************************************
        I2C IDLE

        Both I2C lines are released.

        Wait for the CPU to request a transaction.
        ******************************************************************/

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



        /*****************************************************************
        I2C START

        Generate a START condition by pulling SDA LOW while SCL is HIGH.
        ******************************************************************/

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



        /*****************************************************************
        I2C ADDRESS

        Send the 7 bit address followed by the read/write bit.

        The address byte is transmitted MSB first.
        ******************************************************************/

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



        /*****************************************************************
        I2C ADDRESS ACK

        Release SDA and check whether the selected device acknowledged
        the address.
        ******************************************************************/

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



        /*****************************************************************
        I2C WRITE DATA

        Send the byte stored in tx_data_register.

        Data is transmitted MSB first.
        ******************************************************************/

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



        /*****************************************************************
        I2C WRITE ACK

        Release SDA and check whether the external device acknowledged
        the transmitted data byte.
        ******************************************************************/

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



        /*****************************************************************
        I2C READ DATA

        Release SDA so that the external device can transmit the data byte.

        SDA is sampled while SCL is HIGH.
        ******************************************************************/

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



        /*****************************************************************
        I2C READ NACK

        Release SDA during the ninth clock to send a NACK.

        This tells the external device that no additional bytes are required.
        ******************************************************************/

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



        /*****************************************************************
        I2C STOP

        Generate a STOP condition.

        SDA begins LOW.

        SCL is released HIGH and SDA is then released HIGH while SCL
        remains HIGH.
        ******************************************************************/

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