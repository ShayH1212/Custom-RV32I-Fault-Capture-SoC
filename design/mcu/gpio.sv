/******************************************************
GPIO

8-bit memory-mapped general-purpose I/O.

Each pin can be configured as an input or output.
The direction register uses:
    1 = Output
    0 = Input
******************************************************/
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


// GPIO outputs
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