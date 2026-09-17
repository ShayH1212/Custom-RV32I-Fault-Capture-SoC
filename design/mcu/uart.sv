/*************************************************
UART

8-bit memory-mapped UART transmitter and receiver.
Uses a fixed baud rate and LSB first transfer.
Separate TX and RX FSMs are used

**************************************************/

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

// Synchronize asynchronous RX input
logic rx_unstable;
logic rx_synced;


// Baud period complete
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





always_ff @(posedge clk) begin

    if (reset) begin

        tx_state <= TX_IDLE; 
        tx_data_register <= 8'b0;
        tx_bit_counter <= 3'b0;
        tx_baud_counter <= 0;
        uart_tx <= 1'b1;
        tx_busy <= 1'b0;

    end

    else begin

        // TX IDLE
        if (tx_state == TX_IDLE) begin 

            uart_tx <= 1'b1;
            tx_busy <= 1'b0;

            if (write_enable && address[3:0] == 4'b0) begin 

                tx_data_register <= write_data[7:0];
                tx_busy <= 1'b1; 
                tx_state <= TX_START; 
                tx_baud_counter <= 0;

            end

        end

        // Tx START
        else if (tx_state == TX_START) begin 

            uart_tx <= 1'b0;

            if (tx_baud_done) begin 

                tx_baud_counter <= 0;
                tx_bit_counter <= 0;
                tx_state <= TX_DATA;

            end

            else begin
                tx_baud_counter <= tx_baud_counter + 1; 
            end

        end

        // TX DATA
        else if (tx_state == TX_DATA) begin 

            uart_tx <= tx_data_register[tx_bit_counter];

            if (tx_baud_done) begin 
                tx_baud_counter <= 0; 

                if (tx_bit_counter == 3'b111) begin 
                    tx_state <= TX_STOP; 
                end

                else begin
                    tx_bit_counter <= tx_bit_counter + 1'b1; 
                end
            end

            else begin
                tx_baud_counter <= tx_baud_counter + 1;
            end

        end

        // TX STOP
        else if (tx_state == TX_STOP) begin 

            // Stop bit is always 1
            uart_tx <= 1'b1;

            if (tx_baud_done) begin 
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
        if (write_enable && address[3:0] == 4'b100 && write_data[1] == 1'b1) begin

            rx_valid <= 1'b0;

        end

        // RX IDLE
        if (rx_state == RX_IDLE) begin

            // UART normally sits at 1
            // A 0 indicates the beginning of the start bit

            if (rx_synced == 1'b0) begin

                rx_baud_counter <= 0;
                rx_state <= RX_START;

            end

        end
        // RX START
        else if (rx_state == RX_START) begin

            // Wait until approximately the middle of the start bit
            if (rx_baud_counter == (BAUD_DIVIDER / 2)) begin

                rx_baud_counter <= 0;

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

        // RX DATA
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

        // RX STOP
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