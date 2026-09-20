/*********************************************
This is the configurable REGISTERS module

This is a module where all of the registeres 
that firware will read/ write into live
*********************************************/

module config_registers #(
    parameter BUFFER_ADDRESS_WIDTH = 6
)(
    input logic clk,
    input logic reset,

    // CPU inputs
    input logic [6:0] address,
    input logic write_enable,
    input logic read_enable,
    input logic [31:0] write_data,

    // Status Inputs
    input logic fault_triggered,
    input logic capture_complete,
    input logic [31:0] fault_timestamp,
    input logic [63:0] capture_read_data,

    // Configurable Outputs
    output logic signed [15:0] adc_0_upper_threshold,
    output logic signed [15:0] adc_0_lower_threshold,
    output logic signed [15:0] adc_1_upper_threshold,
    output logic signed [15:0] adc_1_lower_threshold,
    output logic signed [15:0] adc_2_upper_threshold,
    output logic signed [15:0] adc_2_lower_threshold,
    output logic [59:0] digital_fault_codes,
    output logic [63:0] serial_0_fault_codes,
    output logic [63:0] serial_1_fault_codes,
    output logic [14:0] digital_fault_enable,
    output logic [7:0] serial_0_fault_enable,
    output logic [7:0] serial_1_fault_enable,
    output logic adc_0_enable,
    output logic adc_1_enable,
    output logic adc_2_enable,
    output logic digital_enable,
    output logic serial_0_enable,
    output logic serial_1_enable,
    output logic clear_fault,


    output logic [BUFFER_ADDRESS_WIDTH-1:0] capture_read_address,
    output logic [31:0] read_data
);


// REGISTER Addresses
localparam CONTROL_REGISTER = 7'h00;
localparam STATUS_REGISTER = 7'h04;
localparam FAULT_TIMESTAMP_REGISTER = 7'h08;
localparam ADC_0_UPPER_REGISTER = 7'h0C;
localparam ADC_0_LOWER_REGISTER = 7'h10;
localparam ADC_1_UPPER_REGISTER = 7'h14;
localparam ADC_1_LOWER_REGISTER = 7'h18;
localparam ADC_2_UPPER_REGISTER = 7'h1C;
localparam ADC_2_LOWER_REGISTER = 7'h20;
localparam BUFFER_ADDRESS_REGISTER = 7'h24;
localparam BUFFER_DATA_LOW_REGISTER = 7'h28;
localparam BUFFER_DATA_HIGH_REGISTER = 7'h2C;
localparam DIGITAL_CODES_0_REGISTER = 7'h30;
localparam DIGITAL_CODES_1_REGISTER = 7'h34;
localparam SERIAL_0_CODES_0_REGISTER = 7'h3C;
localparam SERIAL_0_CODES_1_REGISTER = 7'h40;
localparam SERIAL_1_CODES_0_REGISTER = 7'h48;
localparam SERIAL_1_CODES_1_REGISTER = 7'h4C;
localparam DIGITAL_ENABLE_REGISTER = 7'h38;
localparam SERIAL_0_ENABLE_REGISTER = 7'h44;
localparam SERIAL_1_ENABLE_REGISTER = 7'h50;

always_ff @(posedge clk) begin

    if (reset) begin

        adc_0_upper_threshold <= '0;
        adc_0_lower_threshold <= '0;
        adc_1_upper_threshold <= '0;
        adc_1_lower_threshold <= '0;
        adc_2_upper_threshold <= '0;
        adc_2_lower_threshold <= '0;
        adc_0_enable <= 1'b0;
        adc_1_enable <= 1'b0;
        adc_2_enable <= 1'b0;
        digital_enable <= 1'b0;
        serial_0_enable <= 1'b0;
        serial_1_enable <= 1'b0;
        clear_fault <= 1'b0;
        capture_read_address <= '0;
        digital_fault_codes <= '0;
        serial_0_fault_codes <= '0;
        serial_1_fault_codes <= '0;
        digital_fault_enable <= '0;
        serial_0_fault_enable <= '0;
        serial_1_fault_enable <= '0;

    end

    else begin

        clear_fault <= 1'b0;
    
        if(write_enable)begin
            

            // Write into the REGISTERs
            case (address)

                CONTROL_REGISTER: begin
                    adc_0_enable <= write_data[0];
                    adc_1_enable <= write_data[1];
                    adc_2_enable <= write_data[2];
                    digital_enable <= write_data[3];
                    serial_0_enable <= write_data[4];
                    serial_1_enable <= write_data[5];
                    clear_fault <= write_data[8];
                end

                ADC_0_UPPER_REGISTER: begin
                    adc_0_upper_threshold <= write_data[15:0];
                end

                ADC_0_LOWER_REGISTER: begin
                    adc_0_lower_threshold <= write_data[15:0];
                end

                ADC_1_UPPER_REGISTER: begin
                    adc_1_upper_threshold <= write_data[15:0];
                end

                ADC_1_LOWER_REGISTER: begin
                    adc_1_lower_threshold <= write_data[15:0];
                end

                ADC_2_UPPER_REGISTER: begin
                    adc_2_upper_threshold <= write_data[15:0];
                end

                ADC_2_LOWER_REGISTER: begin
                    adc_2_lower_threshold <= write_data[15:0];
                end

                DIGITAL_CODES_0_REGISTER: begin
                    digital_fault_codes[31:0] <= write_data;
                end

                DIGITAL_CODES_1_REGISTER: begin
                    digital_fault_codes[59:32] <= write_data[27:0];
                end

                SERIAL_0_CODES_0_REGISTER: begin
                    serial_0_fault_codes[31:0] <= write_data;
                end

                SERIAL_0_CODES_1_REGISTER: begin
                    serial_0_fault_codes[63:32] <= write_data;
                end

                SERIAL_1_CODES_0_REGISTER: begin
                    serial_1_fault_codes[31:0] <= write_data;
                end

                SERIAL_1_CODES_1_REGISTER: begin
                    serial_1_fault_codes[63:32] <= write_data;
                end

                DIGITAL_ENABLE_REGISTER: begin
                    digital_fault_enable <= write_data[14:0];
                end

                SERIAL_0_ENABLE_REGISTER: begin
                    serial_0_fault_enable <= write_data[7:0];
                end

                SERIAL_1_ENABLE_REGISTER: begin
                    serial_1_fault_enable <= write_data[7:0];
                end

                BUFFER_ADDRESS_REGISTER: begin
                    capture_read_address <= write_data[BUFFER_ADDRESS_WIDTH-1:0];
                end

                default: begin
                end

            endcase
        end    
    end
end


always_comb begin
    
    read_data = '0;

    if(read_enable) begin
        
        case (address)

            CONTROL_REGISTER: begin
                read_data[0] = adc_0_enable;
                read_data[1] = adc_1_enable;
                read_data[2] = adc_2_enable;
                read_data[3] = digital_enable;
                read_data[4] = serial_0_enable;
                read_data[5] = serial_1_enable;                               
            end

            STATUS_REGISTER: begin
                read_data[0] = fault_triggered;
                read_data[1] = capture_complete;
            end

            FAULT_TIMESTAMP_REGISTER: begin
                read_data = fault_timestamp;            
            end

            ADC_0_UPPER_REGISTER: begin
               read_data[15:0] = adc_0_upper_threshold;
            end

            ADC_0_LOWER_REGISTER: begin
                read_data[15:0] = adc_0_lower_threshold;
            end

            ADC_1_LOWER_REGISTER: begin
                read_data[15:0] = adc_1_lower_threshold;
            end

            ADC_1_UPPER_REGISTER: begin
                read_data[15:0] = adc_1_upper_threshold;
            end     

            ADC_2_UPPER_REGISTER: begin
                read_data[15:0] = adc_2_upper_threshold;
            end

            ADC_2_LOWER_REGISTER: begin
                read_data[15:0] = adc_2_lower_threshold;
            end

            DIGITAL_CODES_0_REGISTER: begin
                read_data = digital_fault_codes[31:0];
            end

            DIGITAL_CODES_1_REGISTER: begin
                read_data[27:0] = digital_fault_codes[59:32];
            end

            SERIAL_0_CODES_0_REGISTER: begin
                read_data = serial_0_fault_codes[31:0];
            end

            SERIAL_0_CODES_1_REGISTER: begin
                read_data = serial_0_fault_codes[63:32];
            end

            SERIAL_1_CODES_0_REGISTER: begin
                read_data = serial_1_fault_codes[31:0];
            end

            SERIAL_1_CODES_1_REGISTER: begin
                read_data = serial_1_fault_codes[63:32];
            end

            
            DIGITAL_ENABLE_REGISTER: begin
                read_data[14:0] = digital_fault_enable;
            end

            
            SERIAL_0_ENABLE_REGISTER: begin
                read_data[7:0] = serial_0_fault_enable;
            end


            SERIAL_1_ENABLE_REGISTER: begin
                read_data[7:0] = serial_1_fault_enable;
            end   

            BUFFER_ADDRESS_REGISTER: begin
                read_data[BUFFER_ADDRESS_WIDTH-1:0] = capture_read_address;
            end

            BUFFER_DATA_LOW_REGISTER: begin
                read_data = capture_read_data[31:0];
            end

            BUFFER_DATA_HIGH_REGISTER: begin
                read_data = capture_read_data[63:32];
            end

            default: begin
                read_data = '0;
            end
        endcase
    end
end

endmodule



