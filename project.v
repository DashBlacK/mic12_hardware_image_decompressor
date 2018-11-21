/*
Copyright by Shahbaaz Shakil and Mushfiqur Rahman
COMP ENG 3DQ5 - Dr. Nicola Nicolici
Department of Electrical and Computer Engineering
McMaster University
Ontario, Canada
*/

`timescale 1ns/100ps
`default_nettype none

`include "define_state.h"

// This is the top module
// It connects the UART, SRAM and VGA together.
// It gives access to the SRAM for UART and VGA
module project (
		/////// board clocks                      ////////////
		input logic CLOCK_50_I,                   // 50 MHz clock

		/////// pushbuttons/switches              ////////////
		input logic[3:0] PUSH_BUTTON_I,           // pushbuttons
		input logic[17:0] SWITCH_I,               // toggle switches

		/////// 7 segment displays/LEDs           ////////////
		output logic[6:0] SEVEN_SEGMENT_N_O[7:0], // 8 seven segment displays
		output logic[8:0] LED_GREEN_O,            // 9 green LEDs

		/////// VGA interface                     ////////////
		output logic VGA_CLOCK_O,                 // VGA clock
		output logic VGA_HSYNC_O,                 // VGA H_SYNC
		output logic VGA_VSYNC_O,                 // VGA V_SYNC
		output logic VGA_BLANK_O,                 // VGA BLANK
		output logic VGA_SYNC_O,                  // VGA SYNC
		output logic[9:0] VGA_RED_O,              // VGA red
		output logic[9:0] VGA_GREEN_O,            // VGA green
		output logic[9:0] VGA_BLUE_O,             // VGA blue
		
		/////// SRAM Interface                    ////////////
		inout wire[15:0] SRAM_DATA_IO,            // SRAM data bus 16 bits
		output logic[17:0] SRAM_ADDRESS_O,        // SRAM address bus 18 bits
		output logic SRAM_UB_N_O,                 // SRAM high-byte data mask 
		output logic SRAM_LB_N_O,                 // SRAM low-byte data mask 
		output logic SRAM_WE_N_O,                 // SRAM write enable
		output logic SRAM_CE_N_O,                 // SRAM chip enable
		output logic SRAM_OE_N_O,                 // SRAM output logic enable
		
		/////// UART                              ////////////
		input logic UART_RX_I,                    // UART receive signal
		output logic UART_TX_O                    // UART transmit signal
);

logic resetn;

top_state_type top_state;

// For Push button
logic [3:0] PB_pushed;

// For VGA SRAM interface
logic VGA_enable;
logic [17:0] VGA_base_address;
logic [17:0] VGA_SRAM_address;

// For SRAM
logic [17:0] SRAM_address;
logic [17:0] SRAM_address_use; // custom address
logic SRAM_use; // custom flag
logic [15:0] SRAM_write_data;
logic [15:0] SRAM_write_data_use; // custom register
logic SRAM_we_n;
logic [15:0] SRAM_read_data;
logic SRAM_ready;

// For UART SRAM interface
logic UART_rx_enable;
logic UART_rx_initialize;
logic [17:0] UART_SRAM_address;
logic [15:0] UART_SRAM_write_data;
logic UART_SRAM_we_n;
logic [25:0] UART_timer;

logic [6:0] value_7_segment [7:0];

// For error detection in UART
logic [3:0] Frame_error;

// Stuff
logic [7:0] U_minus_5; // Value exits here
logic [7:0] U_minus_3;
logic [7:0] U_minus_1;
logic [7:0] U_plus_1;
logic [7:0] U_plus_3;
logic [7:0] U_plus_5; // New value goes here

// V
logic [7:0] V_minus_5;
logic [7:0] V_minus_3;
logic [7:0] V_minus_1;
logic [7:0] V_plus_1;
logic [7:0] V_plus_3;
logic [7:0] V_plus_5;

logic [7:0] Y0;
logic [7:0] Y1;

logic [7:0] U_odd;
logic [7:0] U_even;

logic [7:0] V_odd;
logic [7:0] V_even;

logic [31:0] mult1_op_1;
logic [31:0] mult1_op_2;
logic [31:0] mult1_result;

logic [31:0] mult2_op_1;
logic [31:0] mult2_op_2;
logic [31:0] mult2_result;

logic [31:0] mult3_op_1;
logic [31:0] mult3_op_2;
logic [31:0] mult3_result;

logic [17:0] yAddress;
logic [17:0] uAddress;
logic [17:0] vAddress;
logic [17:0] rgbAddress;

logic do_read_uv;

// RGB
logic [7:0] R_even;
logic [7:0] R_odd;
logic [7:0] G_even;
logic [7:0] G_odd;
logic [7:0] B_even;
logic [7:0] B_odd;
logic [31:0] Rcomp;
logic [31:0] Gcomp;
logic [31:0] Bcomp;
logic [31:0] UVcomp;

// For disabling UART transmit
assign UART_TX_O = 1'b1;

assign resetn = ~SWITCH_I[17] && SRAM_ready;

// Push Button unit
PB_Controller PB_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(resetn),
	.PB_signal(PUSH_BUTTON_I),	
	.PB_pushed(PB_pushed)
);

// VGA SRAM interface
VGA_SRAM_interface VGA_unit (
	.Clock(CLOCK_50_I),
	.Resetn(resetn),
	.VGA_enable(VGA_enable),
   
	// For accessing SRAM
	.SRAM_base_address(VGA_base_address),
	.SRAM_address(VGA_SRAM_address),
	.SRAM_read_data(SRAM_read_data),
   
	// To VGA pins
	.VGA_CLOCK_O(VGA_CLOCK_O),
	.VGA_HSYNC_O(VGA_HSYNC_O),
	.VGA_VSYNC_O(VGA_VSYNC_O),
	.VGA_BLANK_O(VGA_BLANK_O),
	.VGA_SYNC_O(VGA_SYNC_O),
	.VGA_RED_O(VGA_RED_O),
	.VGA_GREEN_O(VGA_GREEN_O),
	.VGA_BLUE_O(VGA_BLUE_O)
);

// UART SRAM interface
UART_SRAM_interface UART_unit(
	.Clock(CLOCK_50_I),
	.Resetn(resetn), 
   
	.UART_RX_I(UART_RX_I),
	.Initialize(UART_rx_initialize),
	.Enable(UART_rx_enable),
   
	// For accessing SRAM
	.SRAM_address(UART_SRAM_address),
	.SRAM_write_data(UART_SRAM_write_data),
	.SRAM_we_n(UART_SRAM_we_n),
	.Frame_error(Frame_error)
);

// SRAM unit
SRAM_Controller SRAM_unit (
	.Clock_50(CLOCK_50_I),
	.Resetn(~SWITCH_I[17]),
	.SRAM_address(SRAM_address),
	.SRAM_write_data(SRAM_write_data),
	.SRAM_we_n(SRAM_we_n),
	.SRAM_read_data(SRAM_read_data),		
	.SRAM_ready(SRAM_ready),
		
	// To the SRAM pins
	.SRAM_DATA_IO(SRAM_DATA_IO),
	.SRAM_ADDRESS_O(SRAM_ADDRESS_O),
	.SRAM_UB_N_O(SRAM_UB_N_O),
	.SRAM_LB_N_O(SRAM_LB_N_O),
	.SRAM_WE_N_O(SRAM_WE_N_O),
	.SRAM_CE_N_O(SRAM_CE_N_O),
	.SRAM_OE_N_O(SRAM_OE_N_O)
);

assign mult1_result = mult1_op_1*mult1_op_2;
assign mult2_result = mult2_op_1*mult2_op_2;
assign mult3_result = mult3_op_1*mult3_op_2;

assign Rcomp = (mult1_result + mult3_result);
assign Gcomp = (mult1_result - mult2_result - mult3_result);
assign Bcomp = (mult1_result + mult2_result);
assign UVcomp = (mult1_result + mult3_result + 128 - mult2_result);

logic [17:0] rgbAddress_max_commoncase;
logic exit_commoncase;
logic [1:0] leadout_counter;

always_comb begin
	if(rgbAddress >= rgbAddress_max_commoncase) begin
		exit_commoncase = 1'b1;
	end else begin
		exit_commoncase = 1'b0;
	end
end

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		
		rgbAddress_max_commoncase <= 18'd146944 + 18'd468;
		leadout_counter <= 2'd0;

		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		UART_timer <= 26'd0;
		SRAM_address_use <= 18'd0;
		SRAM_use <= 1'b0;
		U_minus_5 <= 8'd0;
		U_minus_3 <= 8'd0;
		U_minus_1 <= 8'd0;
		U_plus_1 <= 8'd0;
		U_plus_3 <= 8'd0;
		U_plus_5 <= 8'd0;
		V_minus_5 <= 8'd0;
		V_minus_3 <= 8'd0;
		V_minus_1 <= 8'd0;
		V_plus_1 <= 8'd0;
		V_plus_3 <= 8'd0;
		V_plus_5 <= 8'd0;
		VGA_enable <= 1'b1;
		R_odd <= 8'd0;
		B_odd <= 8'd0;
		V_odd <= 8'd0;
		G_odd <= 8'd0;
		do_read_uv <= 1'b1;
		
		yAddress <= 18'd0;
		uAddress <= 18'd38400;
		vAddress <= 18'd57600;
		rgbAddress <= 18'd146944;

	end else begin
		UART_rx_initialize <= 1'b0;
		UART_rx_enable <= 1'b0;
		
		// Timer for timeout on UART
		// This counter reset itself every time a new data is received on UART
		if (UART_rx_initialize | ~UART_SRAM_we_n) UART_timer <= 26'd0;
		else UART_timer <= UART_timer + 26'd1;

		case (top_state)
		S_IDLE: begin
			VGA_enable <= 1'b1;   
			if (~UART_RX_I | PB_pushed[0]) begin
				// UART detected a signal, or PB0 is pressed
				UART_rx_initialize <= 1'b1;
				
				VGA_enable <= 1'b0;
								
				top_state <= S_ENABLE_UART_RX;
			end
		end
		S_ENABLE_UART_RX: begin
			// Enable the UART receiver
			UART_rx_enable <= 1'b1;
			top_state <= S_WAIT_UART_RX;
		end
		S_WAIT_UART_RX: begin
`ifdef SIMULATION
			if (UART_timer == 26'd10) begin
`else
			if ((UART_timer == 26'd49999999) && (UART_SRAM_address != 18'h00000)) begin
`endif
				// Timeout for 1 sec on UART for detecting if file transmission is finished
				UART_rx_initialize <= 1'b1;
				 				
				VGA_enable <= 1'b1;
				
				top_state <= S_IDLE_1;
			end
			SRAM_use <= 1'b0;
			//SRAM_we_n <= 1'b1; // Read mode
			//SRAM_use <= 1'b1; // THIS IS THE WRITE MODE ENALBEL FLAG
			SRAM_address_use <= uAddress; // Starting point for U: U[0:1]
		end
		default: top_state <= S_IDLE;
		S_IDLE_1: begin
			SRAM_address_use <= SRAM_address_use + 1; // U[2:3]
			uAddress <= uAddress + 2;
			top_state <= S_IDLE_2;
		end
		S_IDLE_2: begin
			SRAM_address_use <= vAddress; // Starting point for V
			vAddress <= vAddress + 1;
			top_state <= S_1;
		end
		S_1: begin
			SRAM_address_use <= vAddress;
			vAddress <= vAddress + 1;
			U_plus_5 <= SRAM_read_data[7:0]; // Receive U[0:1]
			U_plus_3 <= SRAM_read_data[15:8];
			U_plus_1 <= SRAM_read_data[15:8];
			U_minus_1 <= SRAM_read_data[15:8];
			U_minus_3 <= SRAM_read_data[15:8];
			U_minus_5 <= SRAM_read_data[15:8];
			top_state <= S_2;
		end
		S_2: begin
			SRAM_address_use <= yAddress; // Starting point for Y
			yAddress <= yAddress + 1;
			U_plus_5 <= SRAM_read_data[7:0]; // Receive U[2:3]
			U_plus_3 <= SRAM_read_data[15:8];
			U_plus_1 <= U_plus_5;
			U_minus_1 <= U_plus_3;
			U_minus_3 <= U_plus_1;
			U_minus_5 <= U_minus_1;
			top_state <= S_3;
		end
		S_3: begin
			V_plus_5 <= SRAM_read_data[7:0];
			V_plus_3 <= SRAM_read_data[15:8];
			V_plus_1 <= SRAM_read_data[15:8];
			V_minus_1 <= SRAM_read_data[15:8];
			V_minus_3 <= SRAM_read_data[15:8];
			V_minus_5 <= SRAM_read_data[15:8];
			top_state <= S_4;
		end
		S_4: begin
			V_plus_5 <= SRAM_read_data[7:0];
			V_plus_3 <= SRAM_read_data[15:8];
			V_plus_1 <= V_plus_5;
			V_minus_1 <= V_plus_3;
			V_minus_3 <= V_plus_1;
			V_minus_5 <= V_minus_1;

			mult1_op_1 <= U_plus_5 + U_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= U_plus_3 + U_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= U_plus_1 + U_minus_1;
			mult3_op_2 <= 159;
			top_state <= S_5;
		end
		S_5: begin
			SRAM_address_use <= uAddress;
			Y0 <= SRAM_read_data[15:8];
			Y1 <= SRAM_read_data[7:0];
			if (UVcomp[31] == 1) begin
				U_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				U_odd <= 255;
			end else begin
				U_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			mult1_op_1 <= V_plus_5 + V_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= V_plus_3 + V_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= V_plus_1 + V_minus_1;
			mult3_op_2 <= 159;
			V_even <= V_minus_1;
			U_even <= U_minus_1;
			top_state <= S_6; // wait for V to finish updating register from S_4
		end
		S_6: begin
			SRAM_address_use <= vAddress; // Starting point for V
			mult1_op_1 <= Y0 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_even - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_even - 128;
			mult3_op_2 <= 104595;
			if (UVcomp[31] == 1) begin
				V_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				V_odd <= 255;
			end else begin
				V_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			top_state <= S_7; // loop here forever
		end
		S_7: begin
			SRAM_address_use <= yAddress;
			do_read_uv <= ~do_read_uv;
			yAddress <= yAddress + 1;
			mult2_op_1 <= V_even - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_even - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= (mult1_result + mult2_result) >> 16;
			end
			top_state <= S_8;
		end
		S_8: begin
			mult1_op_1 <= Y1 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_odd - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_odd - 128;
			mult3_op_2 <= 104595;
			U_plus_5 <= SRAM_read_data[15:8]; // Receive U[2:3]
			U_plus_3 <= U_plus_5;
			U_plus_1 <= U_plus_3;
			U_minus_1 <= U_plus_1;
			U_minus_3 <= U_minus_1;
			U_minus_5 <= U_minus_3;
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
			top_state <= S_9;
		end
		S_9: begin
			mult2_op_1 <= V_odd - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_odd - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= (mult1_result + mult2_result) >> 16;
			end
			SRAM_use <= 1'b1; // Get ready to write to SRAM
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			SRAM_write_data_use[15:8] <= R_even;
			SRAM_write_data_use[7:0] <= G_even;
			V_plus_5 <= SRAM_read_data[15:8]; // Receive U[2:3]
			V_plus_3 <= V_plus_5;
			V_plus_1 <= V_plus_3;
			V_minus_1 <= V_plus_1;
			V_minus_3 <= V_minus_1;
			V_minus_5 <= V_minus_3;
			top_state <= S_10;
		end
		S_10: begin
			SRAM_write_data_use[15:8] <= B_even;
			SRAM_write_data_use[7:0] <= R_odd;
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			top_state <= S_11;
			mult1_op_1 <= U_plus_5 + U_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= U_plus_3 + U_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= U_plus_1 + U_minus_1;
			mult3_op_2 <= 159;
			U_even <= U_minus_1;
			V_even <= V_minus_1;
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
		end
		S_11: begin
			SRAM_write_data_use <= {{G_odd},{B_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			mult1_op_1 <= V_plus_5 + V_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= V_plus_3 + V_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= V_plus_1 + V_minus_1;
			mult3_op_2 <= 159;
			if (UVcomp[31] == 1) begin
				U_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				U_odd <= 255;
			end else begin
				U_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			Y0 <= SRAM_read_data[15:8];
			Y1 <= SRAM_read_data[7:0];
			top_state <= S_12;
		end
		S_12: begin
			SRAM_use <= 1'b0;
			if(!exit_commoncase) begin
				SRAM_address_use <= uAddress;
			end else begin
				SRAM_address_use <= uAddress - 1;
				uAddress <= uAddress - 1;
			end

			if (do_read_uv == 1'b0) begin
				uAddress <= uAddress + 1;
			end
				

			mult1_op_1 <= Y0 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_even - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_even - 128;
			mult3_op_2 <= 104595;
			if (UVcomp[31] == 1) begin
				V_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				V_odd <= 255;
			end else begin
				V_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			top_state <= S_13;
		end
		S_13: begin
			SRAM_use <= 1'b0;
			if(!exit_commoncase) begin
				SRAM_address_use <= vAddress;
			end else begin
				SRAM_address_use <= vAddress - 1;
				vAddress <= vAddress - 1;
			end

			if (do_read_uv == 1'b0) begin
				vAddress <= vAddress + 1;
			end

			mult2_op_1 <= V_even - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_even - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= (mult1_result + mult2_result) >> 16;
			end
			top_state <= S_14;
		end
		S_14: begin
			SRAM_address_use <= yAddress;
			yAddress <= yAddress + 1;
			mult1_op_1 <= Y1 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_odd - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_odd - 128;
			mult3_op_2 <= 104595;
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
			top_state <= S_15;
		end
		S_15: begin
			SRAM_use <= 1'b1;
			SRAM_write_data_use <= {{R_even},{G_even}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;

			if(!exit_commoncase) begin
				if (do_read_uv == 1'b0) begin
					U_plus_5 <= SRAM_read_data[7:0]; // Receive U[2:3]
				end else begin
					U_plus_5 <= SRAM_read_data[15:8];
				end
			end else begin
				U_plus_5 <= SRAM_read_data[7:0];
			end
			
			U_plus_3 <= U_plus_5;
			U_plus_1 <= U_plus_3;
			U_minus_1 <= U_plus_1;
			U_minus_3 <= U_minus_1;
			U_minus_5 <= U_minus_3;
			mult2_op_1 <= V_odd - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_odd - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= (mult1_result + mult2_result) >> 16;
			end
			top_state <= S_16;
		end
		S_16: begin
			SRAM_write_data_use <= {{B_even},{R_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;

			if(!exit_commoncase) begin
				if (do_read_uv == 1'b0) begin
					V_plus_5 <= SRAM_read_data[7:0]; // Receive U[2:3]
				end else begin
					V_plus_5 <= SRAM_read_data[15:8];
				end
			end else begin
				V_plus_5 <= SRAM_read_data[7:0];
			end
			
			do_read_uv <= ~do_read_uv;
			V_plus_3 <= V_plus_5;
			V_plus_1 <= V_plus_3;
			V_minus_1 <= V_plus_1;
			V_minus_3 <= V_minus_1;
			V_minus_5 <= V_minus_3;
			mult1_op_1 <= U_plus_5 + U_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= U_plus_3 + U_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= U_plus_1 + U_minus_1;
			mult3_op_2 <= 159;
			U_even <= U_minus_1;
			V_even <= V_plus_1;
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
			if(exit_commoncase) begin
				rgbAddress_max_commoncase <= rgbAddress_max_commoncase + 18'd480;
				top_state <= S_LEADOUT_1;
			end else begin
				top_state <= S_11;
			end

		end
		S_LEADOUT_1: begin
			SRAM_write_data_use <= {{G_odd},{B_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			mult1_op_1 <= V_plus_5 + V_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= V_plus_3 + V_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= V_plus_1 + V_minus_1;
			mult3_op_2 <= 159;
			if (UVcomp[31] == 1) begin
				U_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				U_odd <= 255;
			end else begin
				U_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			Y0 <= SRAM_read_data[15:8];
			Y1 <= SRAM_read_data[7:0];
			top_state <= S_LEADOUT_2;
		end
		S_LEADOUT_2: begin
			SRAM_use <= 1'b0;
			SRAM_address_use <= uAddress;
			mult1_op_1 <= Y0 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_even - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_even - 128;
			mult3_op_2 <= 104595;
			if (UVcomp[31] == 1) begin
				V_odd <= 0;
			end else if (|UVcomp[30:24]) begin
				V_odd <= 255;
			end else begin
				V_odd <= (mult1_result - mult2_result + mult3_result + 128) >> 8;
			end
			top_state <= S_LEADOUT_3;
		end
		S_LEADOUT_3: begin
			SRAM_address_use <= vAddress;
			mult2_op_1 <= V_even - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_even - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= (mult1_result + mult2_result) >> 16;
			end
			top_state <= S_LEADOUT_4;
		end
		S_LEADOUT_4: begin
			SRAM_address_use <= yAddress;
			if(leadout_counter == 0) begin
				yAddress <= yAddress + 1;
			end
			mult1_op_1 <= Y1 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_odd - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_odd - 128;
			mult3_op_2 <= 104595;
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
			top_state <= S_LEADOUT_5;
		end
		S_LEADOUT_5: begin
			SRAM_use <= 1'b1;
			SRAM_write_data_use <= {{R_even},{G_even}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;

			U_plus_5 <= SRAM_read_data[7:0]; // Receive U[2:3]
			U_plus_3 <= U_plus_5;
			U_plus_1 <= U_plus_3;
			U_minus_1 <= U_plus_1;
			U_minus_3 <= U_minus_1;
			U_minus_5 <= U_minus_3;

			mult2_op_1 <= V_odd - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_odd - 128;
			mult3_op_2 <= 25624;
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= (mult1_result + mult3_result) >> 16;
			end
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= (mult1_result + mult2_result) >> 16;
			end
			leadout_counter <= leadout_counter + 2'd1;

			top_state <= S_LEADOUT_6;
		end
		S_LEADOUT_6: begin
			SRAM_write_data_use <= {{B_even},{R_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			V_plus_5 <= SRAM_read_data[7:0]; // Receive U[2:3]
			V_plus_3 <= V_plus_5;
			V_plus_1 <= V_plus_3;
			V_minus_1 <= V_plus_1;
			V_minus_3 <= V_minus_1;
			V_minus_5 <= V_minus_3;
			mult1_op_1 <= U_plus_5 + U_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= U_plus_3 + U_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= U_plus_1 + U_minus_1;
			mult3_op_2 <= 159;
			U_even <= U_minus_1;
			V_even <= V_plus_1;
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= (mult1_result - mult2_result - mult3_result) >> 16;
			end
			if(leadout_counter == 2'd3) begin
				top_state <= S_DELAY_1;
			end else begin
				top_state <= S_LEADOUT_1;
			end
		end
		S_DELAY_1: begin
			top_state <= S_DELAY_2;
			SRAM_write_data_use <= {{G_odd},{B_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			uAddress <= uAddress + 1;
			vAddress <= vAddress + 1;
		end
		S_DELAY_2: begin
			SRAM_use <= 1'b0;
			SRAM_address_use <= uAddress;
			do_read_uv <= 1'b1;
			leadout_counter <= 2'd0;
			if(SRAM_address != 'h3FFFF) begin
				top_state <= S_IDLE_1;
			end else begin
				top_state <= S_IDLE;
			end
			yAddress <= yAddress + 1;
		end

		endcase
	end
end

assign VGA_base_address = 18'd146944;

// Give access to SRAM for UART and VGA at appropriate time
//assign SRAM_address = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
//						? UART_SRAM_address 
//						: VGA_SRAM_address;

always_comb begin
	// TODO: FIX THIS SRAM ADDRESS SWITCHING LOGIC
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_address = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
						? UART_SRAM_address 
						: VGA_SRAM_address;
	end else begin
		SRAM_address = SRAM_address_use; 
	end
	
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_we_n = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
						? UART_SRAM_we_n 
						: 1'b1;
	end else if (SRAM_use == 1'b1) begin
		SRAM_we_n = 1'b0;
	end else begin
		SRAM_we_n = 1'b1;
	end
	
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_write_data = UART_SRAM_write_data;
	end else begin
		SRAM_write_data = SRAM_write_data_use;
	end
end

//assign SRAM_write_data = UART_SRAM_write_data;

//assign SRAM_we_n = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX)) 
//						? UART_SRAM_we_n 
//						: 1'b1;

// 7 segment displays
convert_hex_to_seven_segment unit7 (
	.hex_value(SRAM_read_data[15:12]), 
	.converted_value(value_7_segment[7])
);

convert_hex_to_seven_segment unit6 (
	.hex_value(SRAM_read_data[11:8]), 
	.converted_value(value_7_segment[6])
);

convert_hex_to_seven_segment unit5 (
	.hex_value(SRAM_read_data[7:4]), 
	.converted_value(value_7_segment[5])
);

convert_hex_to_seven_segment unit4 (
	.hex_value(SRAM_read_data[3:0]), 
	.converted_value(value_7_segment[4])
);

convert_hex_to_seven_segment unit3 (
	.hex_value({2'b00, SRAM_address[17:16]}), 
	.converted_value(value_7_segment[3])
);

convert_hex_to_seven_segment unit2 (
	.hex_value(SRAM_address[15:12]), 
	.converted_value(value_7_segment[2])
);

convert_hex_to_seven_segment unit1 (
	.hex_value(SRAM_address[11:8]), 
	.converted_value(value_7_segment[1])
);

convert_hex_to_seven_segment unit0 (
	.hex_value(SRAM_address[7:4]), 
	.converted_value(value_7_segment[0])
);

assign   
   SEVEN_SEGMENT_N_O[0] = value_7_segment[0],
   SEVEN_SEGMENT_N_O[1] = value_7_segment[1],
   SEVEN_SEGMENT_N_O[2] = value_7_segment[2],
   SEVEN_SEGMENT_N_O[3] = value_7_segment[3],
   SEVEN_SEGMENT_N_O[4] = value_7_segment[4],
   SEVEN_SEGMENT_N_O[5] = value_7_segment[5],
   SEVEN_SEGMENT_N_O[6] = value_7_segment[6],
   SEVEN_SEGMENT_N_O[7] = value_7_segment[7];

assign LED_GREEN_O = {resetn, VGA_enable, ~SRAM_we_n, Frame_error, top_state};

endmodule
