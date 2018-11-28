`include "define_state.h"

module dpram_sram_controller(
    input logic Clock_50,
    input logic resetn,
    input logic ws_en,

    output logic [6:0] DP_RAM_Address,
    input logic [31:0] DP_RAM_Read_Data,
    
    output logic [15:0] SRAM_write_data,
    output logic [17:0] SRAM_address,
    output logic SRAM_we
);

// Signals needed for generating address
logic [17:0] s_addr_ctr;
logic s_addr_ctr_en;
logic [2:0] s_element_ctr;
logic [16:0] max_addr_for_row;
logic [16:0] column_addr;

// 2 Buffer registers to store two values read from DP-RAM
logic [31:0] sram_s_write_buf[1:0];

// Keeps track of the number of elements written to SRAM
logic [4:0] elements_written;

ws_state_type ws_state;

// Address generator
always_ff @(posedge Clock_50 or negedge resetn) begin
	if(~resetn) begin
		s_addr_ctr <= 'd0;
		s_element_ctr <= 'd0;
		column_addr <= 'd0;
		max_addr_for_row <= 'd1279;
	end else if(s_addr_ctr_en) begin
		
		if(s_addr_ctr == max_addr_for_row) begin
			max_addr_for_row <= max_addr_for_row + 'd1280;
			column_addr <= max_addr_for_row + 'd1;
			s_addr_ctr <= max_addr_for_row + 'd1;
		end else begin
			s_addr_ctr <= s_addr_ctr + 'd160;

			if(s_element_ctr == 'd7) begin
				column_addr <= column_addr + 'd1;
				s_addr_ctr <= column_addr + 'd1;
				s_element_ctr <= 'd0;
			end
		end
		s_element_ctr <= s_element_ctr + 'd1;
	end
end

// Main FSM
always_ff @(posedge Clock_50 or negedge resetn) begin
    if(~resetn) begin
        DP_RAM_Address <= 'h70;
		sram_s_write_buf[0] <= 'd0;
		sram_s_write_buf[1] <= 'd0;
        elements_written <= 'd0;
    end else if(ws_en) begin
        case(ws_state)
		S_WS_DELAY_1: begin	
			sram_s_write_buf[0] <= DP_RAM_Read_Data;
			ws_state <= S_WS_1;
		end
		S_WS_1: begin
			s_addr_ctr_en <= 1'b1;
			sram_s_write_buf[1] <= DP_RAM_Read_Data;
			SRAM_write_data <= {sram_s_write_buf[0][31:24], DP_RAM_Read_Data[31:24]};
			elements_written <= elements_written + 'd1;
			SRAM_we <= 1'b1;
			ws_state <= S_WS_2;
		end
		S_WS_2: begin
			SRAM_write_data <= {sram_s_write_buf[0][23:16], sram_s_write_buf[1][23:16]};
			elements_written <= elements_written + 'd1;
			ws_state <= S_WS_3;
		end
		S_WS_3: begin
			DP_RAM_Address <= DP_RAM_Address - 'd1;
			SRAM_write_data <= {sram_s_write_buf[0][15:8], sram_s_write_buf[1][15:8]};
			elements_written <= elements_written + 'd1;
			ws_state <= S_WS_4;
		end
		S_WS_4: begin
			DP_RAM_Address <= DP_RAM_Address + 'd2;
			SRAM_write_data <= {sram_s_write_buf[0][7:0], sram_s_write_buf[1][7:0]};
			elements_written <= elements_written + 'd1;
			ws_state <= S_WS_5;
		end
		S_WS_5: begin
			sram_s_write_buf[0] <= DP_RAM_Read_Data;
			SRAM_we <= 1'b0;
			s_addr_ctr_en <= 1'b0;
			if(elements_written != 'd64) begin
				ws_state <= S_WS_1;
			end else begin
				ws_state <= S_WS_DELAY_1;
			end
		end
		default: ws_state <= S_WS_DELAY_1;
		endcase
    end
end

endmodule