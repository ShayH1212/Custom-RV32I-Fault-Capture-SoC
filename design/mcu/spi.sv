/*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
SPI Master

This module allows the MCU to communicate with external devices using
SPI (Serial Peripheral Interface).

SPI uses four main signals:

    SCLK = Serial Clock
    MOSI = Master Out Slave In: Data sent from the MCU to the external device.

    MISO = Master In Slave Out: Data sent from the external device back to the MCU.

    CS   = Chip Select: Selects which external SPI device the MCU is communicating with.

This module operates as the SPI master. The MCU controls when a transfer
begins and the SPI module generates the serial clock and transfers the data.


Design Choices:

1. 8 Bit Transfers
   Each SPI transaction transfers one 8 bit byte.
   The transfer finishes after all 8 bits have been sent and received.

2. Single SPI Device
   The module uses one spi_cs output and therefore directly supports one
   external SPI device.

3. SPI Mode 0
   SCLK remains LOW while idle and MISO is sampled when SCLK moves HIGH.
   This implements SPI Mode 0 operation.

4. MSB First Transmission
   Transmission begins with bit 7 and continues down to bit 0.
   The most significant bit is therefore transferred first.

5. Full Duplex Communication
   MOSI transmits a bit while MISO is sampled during the same transaction.
   This allows data to be sent and received at the same time.

6. Parameterized SPI Clock Divider
   CLOCK_DIVIDER determines how many MCU clock cycles occur before SCLK changes.
   This allows the SPI clock to run slower than the MCU clock.

7. Three State FSM
   The SPI controller uses IDLE, TRANSFER, and FINISH states.
   These states control when a transaction starts, transfers data, and completes.

8. Single Byte TX Storage
   One byte is stored in tx_data_register for the current transaction.
   There is no transmit FIFO in this design.

9. Single Byte RX Storage
   Received bits are collected in rx_shift_register and then copied into
   rx_data_register after the complete byte has been received.

10. Transfers Only Start While Idle
    A CPU write to SPI_DATA starts a transaction only while the FSM is in SPI_IDLE.
    Writes during an active transfer do not start another transaction.

11. Active LOW Chip Select
    spi_cs is pulled LOW when a transfer begins and remains LOW throughout
    the transaction before returning HIGH when the transfer finishes.

12. Transfer Complete Flag
    transfer_complete becomes HIGH after a complete SPI transaction finishes.
    The flag remains HIGH until the CPU clears it or begins another transfer.

13. Write 1 to Clear Transfer Complete
    Writing a 1 to bit 1 of SPI_STATUS clears the transfer_complete flag.
    This allows the CPU to acknowledge that the completed transfer was handled.

14. Transfer Complete Interrupt
    spi_interrupt is directly connected to transfer_complete.
    The interrupt therefore remains active while the transfer complete flag is HIGH.

15. CPU Write Starts Transfer
    Writing a byte to SPI_DATA while the SPI controller is idle immediately
    stores the byte and begins an SPI transaction.


Register Map:

    0x0 = SPI_DATA

          Writing: Starts an SPI transfer using write_data[7:0].

          Reading: Returns the most recently received SPI byte.


    0x4 = SPI_STATUS

          Bit 0 = Ready
          Bit 1 = Transfer complete

          Writing a 1 to bit 1 clears the transfer complete flag.

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/


module spi_master #(

    parameter integer CLOCK_DIVIDER = 4

)
(

    input logic clk,
    input logic reset,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,

    // SPI signals
    output logic spi_sclk,
    output logic spi_mosi,
    input logic spi_miso,
    output logic spi_cs,
    output logic spi_interrupt

);


// SPI states
localparam logic [1:0] SPI_IDLE     = 2'b00;
localparam logic [1:0] SPI_TRANSFER = 2'b01;
localparam logic [1:0] SPI_FINISH   = 2'b10;


// Internal registers
logic [1:0] spi_state;
logic [7:0] tx_data_register;
logic [7:0] rx_data_register;
logic [7:0] rx_shift_register;
logic [2:0] bit_counter;
integer clock_counter;
logic spi_busy;
logic transfer_complete;

/*************************************************************
SPI Interrupt

The interrupt becomes active when a transfer has completed.
****************************************************************/

assign spi_interrupt = transfer_complete;

/********************************************************************************
SPI Master FSM

The SPI controller moves through three main states:

    SPI_IDLE

    Waits for the CPU to write a byte to SPI_DATA.


    SPI_TRANSFER

    Selects the external device, generates the SPI clock, sends one bit
    at a time through MOSI, and receives one bit at a time through MISO.


    SPI_FINISH

    Finishes the transfer, stores the received byte, releases chip select,
    and marks the transfer as complete.


State transitions:

    IDLE -> TRANSFER : CPU writes a byte to SPI_DATA

    TRANSFER -> FINISH : All 8 bits have been transferred

    FINISH -> IDLE : Transfer is complete

********************************************************************************************/


always_ff @(posedge clk) begin

    if (reset) begin

        spi_state <= SPI_IDLE;

        tx_data_register <= 8'b0;
        rx_data_register <= 8'b0;
        rx_shift_register <= 8'b0;
        bit_counter <= 3'b0;
        clock_counter <= 0;
        spi_sclk <= 1'b0;
        spi_mosi <= 1'b0;
        spi_cs <= 1'b1;
        spi_busy <= 1'b0;
        transfer_complete <= 1'b0;

    end


    else begin


        /*****************************************************
        CPU clears transfer complete flag by writing a 1 to
        bit 1 of SPI_STATUS.
        ******************************************************/

        if (write_enable &&
            address[3:0] == 4'b0100 &&
            write_data[1] == 1'b1) begin
            transfer_complete <= 1'b0;

        end



        /*****************************************************************
        SPI IDLE

        Wait for the CPU to provide a byte that should be transmitted.
        ******************************************************************/

        if (spi_state == SPI_IDLE) begin

            spi_sclk <= 1'b0;
            spi_cs <= 1'b1;

            spi_busy <= 1'b0;


            if (write_enable &&
                address[3:0] == 4'b0000) begin

                tx_data_register <= write_data[7:0];

                rx_shift_register <= 8'b0;

                bit_counter <= 3'b111;

                clock_counter <= 0;

                spi_busy <= 1'b1;

                transfer_complete <= 1'b0;

                spi_cs <= 1'b0;

                spi_state <= SPI_TRANSFER;

            end

        end



        /*
        SPI TRANSFER

        Send and receive one bit at a time.

        This implementation sends the most significant bit first.
        */

        else if (spi_state == SPI_TRANSFER) begin


            // Place current transmit bit on MOSI

            spi_mosi <= tx_data_register[bit_counter];


            // Count MCU clock cycles used to create the slower SPI clock

            if (clock_counter == CLOCK_DIVIDER - 1) begin

                clock_counter <= 0;


                /*
                If SCLK is currently low, move it high.

                In SPI Mode 0, MISO is sampled on the rising edge.
                */

                if (spi_sclk == 1'b0) begin

                    spi_sclk <= 1'b1;

                    rx_shift_register[bit_counter] <= spi_miso;

                end


                /*
                If SCLK is currently high, move it low.

                After the falling edge, move to the next data bit.
                */

                else begin

                    spi_sclk <= 1'b0;


                    // Check if the final bit has been transferred

                    if (bit_counter == 3'b000) begin

                        spi_state <= SPI_FINISH;

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



        /*
        SPI FINISH

        The full byte has been transferred.
        */

        else if (spi_state == SPI_FINISH) begin

            spi_cs <= 1'b1;

            spi_sclk <= 1'b0;

            spi_busy <= 1'b0;

            rx_data_register <= rx_shift_register;

            transfer_complete <= 1'b1;

            spi_state <= SPI_IDLE;

        end

    end

end



// CPU reads SPI registers

always_comb begin

    read_data = 32'b0;


    // SPI_DATA

    if (address[3:0] == 4'b0000) begin

        read_data = {24'b0, rx_data_register};

    end


    // SPI_STATUS

    else if (address[3:0] == 4'b0100) begin

        read_data[0] = ~spi_busy;
        read_data[1] = transfer_complete;

    end

end


endmodule