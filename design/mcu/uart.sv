/*|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

UART (Universal Asynchronous Receiver Transmitter)

This module allows the MCU to send and receive serial data using two signals:

    TX = Transmit
    RX = Receive

UART works by converting data from the CPU into a stream of individual bits
that are sent out through the TX line.

It also receives serial bits through the RX line and converts them back into
data that the CPU can read.

UART provides a simple communication link between the MCU and external devices.


Design Choices:

1. Fixed Baud Rate
   The baud rate is set using the BAUD_RATE parameter and defaults to 115200.
   The baud rate cannot be changed by the CPU while the MCU is running.

2. Clock Based Baud Timing
   BAUD_DIVIDER determines how many MCU clock cycles make up one UART bit.
   This allows the MCU clock to control the timing of each transmitted bit.

3. Separate TX and RX FSMs
   Transmission and reception use separate finite state machines.
   This allows transmitting and receiving to operate independently.

4. LSB First Transmission
   Data bit 0 is transmitted first followed by bits 1 through 7.
   This follows standard UART transmission 

5. TX Writes Only Accepted While Idle
   The CPU can start a new transmission only while the TX FSM is in TX_IDLE.

6. Mid Bit START Confirmation
    After RX first goes LOW, the receiver waits approximately half of one
    baud period and checks that the START bit is still LOW.

7. RX Valid Flag
    rx_valid becomes HIGH when a complete valid byte has been received.
    It remains HIGH until the CPU clears it.




Register Map:

    0x0 = UART_DATA

          Writing: Stores the byte that will be transmitted.

          Reading: Returns the most recently received byte.


    0x4 = UART_STATUS

          Bit 0 = TX ready
          Bit 1 = RX data valid

|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||*/


module uart #(
    parameter integer CLOCK_FREQUENCY = 50_000_000,
    parameter integer BAUD_RATE = 115200
)
(
    input logic clk,
    input logic reset,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic write_enable,
    output logic [31:0] read_data,

    // UART signals
    input logic uart_rx,
    output logic uart_tx
);


// Number of MCU clock cycles for one UART bit
localparam integer BAUD_DIVIDER = CLOCK_FREQUENCY / BAUD_RATE;

// TX & RX states
localparam logic [1:0] TX_IDLE = 2'b00;
localparam logic [1:0] TX_START = 2'b01;
localparam logic [1:0] TX_DATA = 2'b10;
localparam logic [1:0] TX_STOP = 2'b11;
localparam logic [1:0] RX_IDLE = 2'b00;
localparam logic [1:0] RX_START = 2'b01;
localparam logic [1:0] RX_DATA = 2'b10;
localparam logic [1:0] RX_STOP = 2'b11;

logic [1:0] tx_state;
logic [7:0] tx_data_register;
logic [2:0] tx_bit_counter;
integer tx_baud_counter;
logic tx_busy;
logic [1:0] rx_state;
logic [7:0] rx_shift_register;
logic [7:0] rx_data_register;
logic [2:0] rx_bit_counter;
integer rx_baud_counter;
logic rx_valid;

// Make the external rx pin safe for UART clock
logic rx_unstable;
logic rx_synced;


// Signal added for ease of code as it is typed alot
logic tx_baud_done;

assign tx_baud_done = (tx_baud_counter == BAUD_DIVIDER - 1);


always_ff @(posedge clk) begin

    if (reset) begin
        rx_unstable <= 1'b1;
        rx_synced <= 1'b1;
    end

    else begin
        rx_unstable <= uart_rx;
        rx_synced <= rx_unstable;
    end

end



/*
UART Tranamitter
This uses an FSM as defined below

It moves through four states:

    TX_IDLE
    Waits for the CPU to write a new byte to UART_DATA.

    TX_START
    Sends the start bit, which is logic 0, for one baud period.

    TX_DATA
    Sends the 8 data bits one at a time. The FSM stays in this state until
    all 8 bits have been transmitted.

    TX_STOP
    Sends the stop bit, which is logic 1, for one baud period.

    IDLE  -> START : CPU writes a byte to UART_DATA
    START -> DATA  : one start-bit period has passed
    DATA  -> STOP  : all 8 data bits have been sent
    STOP  -> IDLE  : one stop-bit period has passed
*/

always_ff @(posedge clk) begin

    if (reset) begin

        tx_state <= TX_IDLE; // reset state will be IDLE
        tx_data_register <= 8'b0;
        tx_bit_counter <= 3'b0;
        tx_baud_counter <= 0;
        uart_tx <= 1'b1;
        tx_busy <= 1'b0;

    end

    else begin

        if (tx_state == TX_IDLE) begin // If current state is idle

            uart_tx <= 1'b1; // tx stays high
            tx_busy <= 1'b0;

            if (write_enable && address[3:0] == 4'b0) begin // if write enable is on

                tx_data_register <= write_data[7:0]; // transmit a BYTE
                tx_busy <= 1'b1; // set tx to be busy 
                tx_state <= TX_START; // move to TX start
                tx_baud_counter <= 0;

            end

        end


        else if (tx_state == TX_START) begin // if in START

            uart_tx <= 1'b0; // tx bit becomes low

            if (tx_baud_done) begin // checks if a full preiod has passed

                tx_baud_counter <= 0;
                tx_bit_counter <= 0;
                tx_state <= TX_DATA;

            end

            else begin
                tx_baud_counter <= tx_baud_counter + 1; 
            end

        end


        else if (tx_state == TX_DATA) begin // if in DATA state

            uart_tx <= tx_data_register[tx_bit_counter]; // place selected bit into TX pin

            if (tx_baud_done) begin // wait until bit has been transmitted for a full period of UART
                tx_baud_counter <= 0; // reset counter

                if (tx_bit_counter == 3'b111) begin // check if it is the 8th bit
                    tx_state <= TX_STOP; // move to STOP state
                end

                else begin
                    tx_bit_counter <= tx_bit_counter + 1'b1; //move to next data bit
                end
            end

            else begin
                tx_baud_counter <= tx_baud_counter + 1;
            end

        end


        else if (tx_state == TX_STOP) begin //STOP state

            // Stop bit is always 1
            uart_tx <= 1'b1;

            if (tx_baud_done) begin // wait one period
                tx_baud_counter <= 0;
                tx_busy <= 1'b0;
                tx_state <= TX_IDLE;
            end

            else begin
                tx_baud_counter <= tx_baud_counter + 1;
            end

        end

    end

end



/*

UART RECEIVER

The reciever also uses an FSM as defined below 

    RX_IDLE
    Waits for the RX line to go low, which may indicating the beginning of a start bit.

    RX_START
    Waits until the middle of the start bit and checks that the RX line is still low.

    RX_DATA
    Samples the RX line once per baud period and stores each of the 8 received data bits.

    RX_STOP
    Checks for a valid stop bit, which should be a 1.
    If valid, the received byte is stored and marked as ready for the CPU.

State transitions:

    IDLE -> START : RX line goes low
    START -> DATA  : valid start bit is confirmed
    START -> IDLE  : start bit is not valid
    DATA -> STOP  : all 8 data bits have been received
    STOP -> IDLE  : stop-bit period has completed
*/

always_ff @(posedge clk) begin

    if (reset) begin
        rx_state <= RX_IDLE;
        rx_shift_register <= 8'b0;
        rx_data_register <= 8'b0;
        rx_bit_counter <= 3'b0;
        rx_baud_counter <= 0;
        rx_valid <= 1'b0;
    end

    else begin

        // Writing bit 1 of UART_STATUS clears RX valid
        if (write_enable &&
            address[3:0] == 4'b100 &&
            write_data[1] == 1'b1) begin

            rx_valid <= 1'b0;

        end


        if (rx_state == RX_IDLE) begin

            // UART normally sits at 1
            // A 0 indicates the beginning of the start bit

            if (rx_synced == 1'b0) begin

                rx_baud_counter <= 0;
                rx_state <= RX_START;

            end

        end

        else if (rx_state == RX_START) begin

            // Wait until approximately the middle of the start bit
            if (rx_baud_counter == (BAUD_DIVIDER / 2)) begin

                rx_baud_counter <= 0;

                // Check that the line is still low
                if (rx_synced == 1'b0) begin

                    rx_bit_counter <= 0;
                    rx_state <= RX_DATA;

                end

                else begin
                    rx_state <= RX_IDLE;
                end

            end

            else begin
                rx_baud_counter <= rx_baud_counter + 1;
            end

        end


        else if (rx_state == RX_DATA) begin

            if (rx_baud_counter == BAUD_DIVIDER - 1) begin

                rx_baud_counter <= 0;

                // Save the received bit
                rx_shift_register[rx_bit_counter] <= rx_synced;

                if (rx_bit_counter == 3'b111) begin
                    rx_state <= RX_STOP;
                end

                else begin
                    rx_bit_counter <= rx_bit_counter + 1'b1;
                end

            end

            else begin
                rx_baud_counter <= rx_baud_counter + 1;
            end

        end


        else if (rx_state == RX_STOP) begin

            if (rx_baud_counter == BAUD_DIVIDER - 1) begin

                rx_baud_counter <= 0;

                // Valid UART stop bit should be high
                if (rx_synced == 1'b1) begin

                    rx_data_register <= rx_shift_register;
                    rx_valid <= 1'b1;

                end

                rx_state <= RX_IDLE;

            end

            else begin
                rx_baud_counter <= rx_baud_counter + 1;
            end

        end

    end

end



// CPU reads UART registers
always_comb begin

    read_data = 32'b0;


    // UART_DATA
    if (address[3:0] == 4'b0000) begin

        read_data = {24'b0, rx_data_register};

    end


    // UART_STATUS
    else if (address[3:0] == 4'b0100) begin

        read_data[0] = ~tx_busy;
        read_data[1] = rx_valid;

    end

end


endmodule