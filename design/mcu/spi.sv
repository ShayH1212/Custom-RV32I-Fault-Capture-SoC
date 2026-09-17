/*****************************************************************
SPI Master

8-bit memory-mapped SPI master.
Uses MSB first transfers to a single device.

An FSM controls IDLE, TRANSFER, and FINISH sequencing.
********************************************************************/
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

assign spi_interrupt = transfer_complete;


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


        if (write_enable && address[3:0] == 4'b0100 && write_data[1] == 1'b1) begin
            transfer_complete <= 1'b0;

        end


        // SPI IDLE

        if (spi_state == SPI_IDLE) begin

            spi_sclk <= 1'b0;
            spi_cs <= 1'b1;
            spi_busy <= 1'b0;


            if (write_enable && address[3:0] == 4'b0000) begin

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




        // SPI TRANSFER

        else if (spi_state == SPI_TRANSFER) begin


            // Drive transmit bit on MOSI
            spi_mosi <= tx_data_register[bit_counter];


            // SPI clock divider
            if (clock_counter == CLOCK_DIVIDER - 1) begin

                clock_counter <= 0;

                if (spi_sclk == 1'b0) begin

                    spi_sclk <= 1'b1;

                    rx_shift_register[bit_counter] <= spi_miso;

                end

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




        // SPI FINISH


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