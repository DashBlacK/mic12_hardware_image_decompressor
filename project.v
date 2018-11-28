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
		output logic UART_TX_O,                   // UART transmit signal

		output logic [31:0] READ_DATA_A_O [2:0],
		output logic [31:0] READ_DATA_B_O [2:0]
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
logic [15:0] SRAM_write_data_use; // custom write data register
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

// U shift register
logic [7:0] U_minus_5; // Value exits here
logic [7:0] U_minus_3;
logic [7:0] U_minus_1;
logic [7:0] U_plus_1;
logic [7:0] U_plus_3;
logic [7:0] U_plus_5; // New value goes here

// V shift register
logic [7:0] V_minus_5; // Value exits here
logic [7:0] V_minus_3;
logic [7:0] V_minus_1;
logic [7:0] V_plus_1;
logic [7:0] V_plus_3;
logic [7:0] V_plus_5; // New value goes here

// Y value registers
logic [7:0] Y0;
logic [7:0] Y1;

logic [7:0] U_odd;
logic [7:0] U_even;

logic [7:0] V_odd;
logic [7:0] V_even;

// Multiplier stuff
logic [31:0] mult1_op_1;
logic [31:0] mult1_op_2;
logic [31:0] mult1_result;
logic [31:0] mult2_op_1;
logic [31:0] mult2_op_2;
logic [31:0] mult2_result;
logic [31:0] mult3_op_1;
logic [31:0] mult3_op_2;
logic [31:0] mult3_result;

// Address registers
logic [17:0] yAddress;
logic [17:0] uAddress;
logic [17:0] vAddress;
logic [17:0] rgbAddress;

// common case toggle flag
logic do_read_uv;

// RGB calculation stuff
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

// Multipliers
assign mult1_result = mult1_op_1*mult1_op_2;
assign mult2_result = mult2_op_1*mult2_op_2;
assign mult3_result = mult3_op_1*mult3_op_2;

// Adders
assign Rcomp = (mult1_result + mult3_result);
assign Gcomp = (mult1_result - mult2_result - mult3_result);
assign Bcomp = (mult1_result + mult2_result);
assign UVcomp = (mult1_result + mult3_result + 128 - mult2_result);

logic [17:0] rgbMax;
logic exit_commoncase;
logic [1:0] leadout_counter;

// milestone control logic
logic m1start;
logic m1done;
logic m2start;
logic m2done;
logic m3start;
logic m3done;

always_comb begin
	if(rgbAddress >= rgbMax) begin
		exit_commoncase = 1'b1;
	end else begin
		exit_commoncase = 1'b0;
	end
end

// <------------------------- BEGIN MILESTONE 1
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		top_state <= S_IDLE;
		rgbMax <= 18'd146944 + 18'd468;
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
		do_read_uv <= 1'b1;
		yAddress <= 18'd0;
		uAddress <= 18'd38400;
		vAddress <= 18'd57600;
		rgbAddress <= 18'd146944;
		m1start <= 1'b0;
		m2start <= 1'b0;
		m3start <= 1'b0;
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

				top_state <= S_MILESTONE_3;
			end
			m3start <= 1'b1;
		end
		S_MILESTONE_3: begin
			if (m3done == 1'b1) begin
				top_state <=S_MILESTONE_2;
				m3start <= 1'b0;
				m2start <= 1'b1;
			end
		end
		S_MILESTONE_2: begin
			if (m2done == 1'b1) begin
				SRAM_use <= 1'b0;
				SRAM_address_use <= uAddress;
				top_state <=S_IDLE_1;
				m2start <= 1'b0;
				m1start <= 1'b1;
			end
		end
		S_IDLE_1: begin
			SRAM_address_use <= SRAM_address_use + 1;
			uAddress <= uAddress + 2;
			top_state <= S_IDLE_2;
		end
		S_IDLE_2: begin
			SRAM_address_use <= vAddress;
			vAddress <= vAddress + 1;
			top_state <= S_1;
		end
		S_1: begin
			SRAM_address_use <= vAddress;
			vAddress <= vAddress + 1;
			U_plus_5 <= SRAM_read_data[7:0];
			U_plus_3 <= SRAM_read_data[15:8];
			U_plus_1 <= SRAM_read_data[15:8];
			U_minus_1 <= SRAM_read_data[15:8];
			U_minus_3 <= SRAM_read_data[15:8];
			U_minus_5 <= SRAM_read_data[15:8];
			top_state <= S_2;
		end
		S_2: begin
			SRAM_address_use <= yAddress;
			yAddress <= yAddress + 1;
			U_plus_5 <= SRAM_read_data[7:0];
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
			U_odd <= UVcomp[15:8];
			mult1_op_1 <= V_plus_5 + V_minus_5;
			mult1_op_2 <= 21;
			mult2_op_1 <= V_plus_3 + V_minus_3;
			mult2_op_2 <= 52;
			mult3_op_1 <= V_plus_1 + V_minus_1;
			mult3_op_2 <= 159;
			V_even <= V_minus_1;
			U_even <= U_minus_1;
			top_state <= S_6;
		end
		S_6: begin
			SRAM_address_use <= vAddress;
			mult1_op_1 <= Y0 - 16;
			mult1_op_2 <= 76284;
			mult2_op_1 <= U_even - 128;
			mult2_op_2 <= 132251;
			mult3_op_1 <= V_even - 128;
			mult3_op_2 <= 104595;
			V_odd <= UVcomp[15:8];
			top_state <= S_7;
		end
		S_7: begin
			SRAM_address_use <= yAddress;
			do_read_uv <= ~do_read_uv;
			yAddress <= yAddress + 1;
			mult2_op_1 <= V_even - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_even - 128;
			mult3_op_2 <= 25624;
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= Bcomp[23:16];
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
			U_plus_5 <= SRAM_read_data[15:8];
			U_plus_3 <= U_plus_5;
			U_plus_1 <= U_plus_3;
			U_minus_1 <= U_plus_1;
			U_minus_3 <= U_minus_1;
			U_minus_5 <= U_minus_3;
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= Gcomp[23:16];
			end
			top_state <= S_9;
		end
		S_9: begin
			mult2_op_1 <= V_odd - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_odd - 128;
			mult3_op_2 <= 25624;
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= Bcomp[23:16];
			end
			SRAM_use <= 1'b1;
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			SRAM_write_data_use <= {{R_even},{G_even}};
			V_plus_5 <= SRAM_read_data[15:8];
			V_plus_3 <= V_plus_5;
			V_plus_1 <= V_plus_3;
			V_minus_1 <= V_plus_1;
			V_minus_3 <= V_minus_1;
			V_minus_5 <= V_minus_3;
			top_state <= S_10;
		end
		S_10: begin
			SRAM_write_data_use <= {{B_even},{R_odd}};
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
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= Gcomp[23:16];
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
			U_odd <= UVcomp[15:8];
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
			V_odd <= UVcomp[15:8];
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
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= Bcomp[23:16];
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
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= Gcomp[23:16];
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
					U_plus_5 <= SRAM_read_data[7:0];
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
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= Bcomp[23:16];
			end
			top_state <= S_16;
		end
		S_16: begin
			SRAM_write_data_use <= {{B_even},{R_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			if(!exit_commoncase) begin
				if (do_read_uv == 1'b0) begin
					V_plus_5 <= SRAM_read_data[7:0];
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
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= Gcomp[23:16];
			end
			if(exit_commoncase) begin
				rgbMax <= rgbMax + 18'd480;
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
			U_odd <= UVcomp[15:8];
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
			V_odd <= UVcomp[15:8];
			top_state <= S_LEADOUT_3;
		end
		S_LEADOUT_3: begin
			SRAM_address_use <= vAddress;
			mult2_op_1 <= V_even - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_even - 128;
			mult3_op_2 <= 25624;
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_even <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_even <= 8'd255;
			end else begin
				R_even <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_even <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_even <= 8'd255;
			end else begin
				B_even <= Bcomp[23:16];
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
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_even <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_even <= 8'd255;
			end else begin
				G_even <= Gcomp[23:16];
			end
			top_state <= S_LEADOUT_5;
		end
		S_LEADOUT_5: begin
			SRAM_use <= 1'b1;
			SRAM_write_data_use <= {{R_even},{G_even}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			U_plus_5 <= SRAM_read_data[7:0];
			U_plus_3 <= U_plus_5;
			U_plus_1 <= U_plus_3;
			U_minus_1 <= U_plus_1;
			U_minus_3 <= U_minus_1;
			U_minus_5 <= U_minus_3;
			mult2_op_1 <= V_odd - 128;
			mult2_op_2 <= 53281;
			mult3_op_1 <= U_odd - 128;
			mult3_op_2 <= 25624;
			// Bounds checking for red
			if (Rcomp[31] == 1) begin
				R_odd <= 8'd0;
			end else if (|Rcomp[30:24]) begin
				R_odd <= 8'd255;
			end else begin
				R_odd <= Rcomp[23:16];
			end
			// Bounds checking for blue
			if (Bcomp[31] == 1) begin
				B_odd <= 8'd0;
			end else if (|Bcomp[30:24]) begin
				B_odd <= 8'd255;
			end else begin
				B_odd <= Bcomp[23:16];
			end
			leadout_counter <= leadout_counter + 2'd1;
			top_state <= S_LEADOUT_6;
		end
		S_LEADOUT_6: begin
			SRAM_write_data_use <= {{B_even},{R_odd}};
			SRAM_address_use <= rgbAddress;
			rgbAddress <= rgbAddress + 1;
			V_plus_5 <= SRAM_read_data[7:0];
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
			// Bounds checking for green
			if (Gcomp[31] == 1) begin
				G_odd <= 8'd0;
			end else if (|Gcomp[30:24]) begin
				G_odd <= 8'd255;
			end else begin
				G_odd <= Gcomp[23:16];
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
		default: top_state <= S_IDLE;
		endcase
	end
end

// <------------------------- END OF MILESTONE 1
// <------------------------- BEGIN MILESTONE 2
m2_state_type m2_state;
logic [17:0] SRAM_address_use_m2;
logic SRAM_use_m2;
logic [17:0] idctAddress;
logic [15:0] S_prime_buffer;

logic [6:0] address_a[2:0];
logic [6:0] address_b[2:0];
logic [31:0] write_data_a [2:0];
logic [31:0] write_data_b [2:0];
logic write_enable_a [2:0];
logic write_enable_b [2:0];
logic [31:0] read_data_a [2:0];
logic [31:0] read_data_b [2:0];


// Instantiate RAM2
dual_port_RAM2 dual_port_RAM_inst2 (
	.address_a ( address_a[2] ),
	.address_b ( address_b[2] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[2] ),
	.data_b ( write_data_b[2] ),
	.wren_a ( write_enable_a[2] ),
	.wren_b ( write_enable_b[2] ),
	.q_a ( read_data_a[2] ),
	.q_b ( read_data_b[2] )
);

// Instantiate RAM1
dual_port_RAM1 dual_port_RAM_inst1 (
	.address_a ( address_a[1] ),
	.address_b ( address_b[1] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[1] ),
	.data_b ( write_data_b[1] ),
	.wren_a ( write_enable_a[1] ),
	.wren_b ( write_enable_b[1] ),
	.q_a ( read_data_a[1] ),
	.q_b ( read_data_b[1] )
);

// Instantiate RAM0
dual_port_RAM0 dual_port_RAM_inst0 (
	.address_a ( address_a[0] ),
	.address_b ( address_b[0] ),
	.clock ( CLOCK_50_I ),
	.data_a ( write_data_a[0] ),
	.data_b ( write_data_b[0] ),
	.wren_a ( write_enable_a[0] ),
	.wren_b ( write_enable_b[0] ),
	.q_a ( read_data_a[0] ),
	.q_b ( read_data_b[0] )
);

logic [15:0] RowAddr;
logic [4:0] RowBase;

logic [8:0] ColAddr;
logic [5:0] ColBase;

logic [2:0] RowIndex;
logic [2:0] ColIndex;

logic [5:0] block_element_counter;

assign RowAddr = {RowBase, RowIndex};
assign ColAddr = {ColBase, ColIndex};

logic idctAddrEn;
logic fetch_IDCT_Y;
logic m2CountEnable;

assign idctAddress = 18'd76800 + (RowAddr << 8) + (RowAddr << 6) + ColAddr;

// Addressing Pre-IDCT Block circuitry
always_ff@(posedge CLOCK_50_I or negedge resetn) begin
	if(~resetn) begin
		ColBase <= 6'd0;
		RowBase <= 5'd0;
		RowIndex <= 8'd0;
		ColIndex <= 8'd0;
		block_element_counter <= 0;
	end else if (m2CountEnable == 1'b1) begin
		block_element_counter <= block_element_counter + 1;
		ColIndex <= ColIndex + 1;

		if(ColIndex == 'd7) begin
			ColIndex <= 0;
			RowIndex <= RowIndex + 1;

			if(RowIndex == 'd7) begin
				RowIndex <= 0;
				ColBase <= ColBase + 1;
			end
		end


		// For Y there's 40 blocks per row. For U/V There's 20 so 
		// this constant needs to be changeable
		if(fetch_IDCT_Y) begin
			if(ColBase == 'd39 && ColIndex == 'd7 && RowIndex == 'd7) begin
				RowBase <= RowBase + 1;
				RowIndex <= 0;
				ColBase <= 0;
			end
		end else begin
			if(ColBase == 'd19 && RowIndex == 'd7) begin
				RowBase <= RowBase + 1;
				ColBase <= 0;
			end else begin
				RowBase <= 'd0;
			end
		end


	end
end

assign fetch_IDCT_Y = 1'b1;

//logic [17:0] SRAM_S_write_address;
logic [17:0] s_addr_ctr;
logic s_addr_ctr_en;
logic [2:0] s_element_ctr;
logic [16:0] max_addr_for_row;
logic [16:0] column_addr;

always_ff @(posedge CLOCK_50_I or negedge resetn) begin
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

logic [15:0] sram_write_data_m2;

always_comb begin
	if( (m2_state == m2_IDLE_1) ||
		(m2_state == m2_IDLE_2) ||
		(m2_state == m2_FETCH_S_PRIME_1) ||
		(m2_state == m2_FETCH_S_PRIME_2) ||
		(m2_state == m2_FETCH_S_PRIME_DELAY_1) ||
		(m2_state == m2_FETCH_S_PRIME_DELAY_2) ||
		(m2_state == m2_REQ_S_PRIME) ||
		(m2_state == m2_CALC_T_1) ||
		(m2_state == m2_CALC_S_1) ||
		(m2_state == m2_CALC_S_2) ||
		(m2_state == m2_CALC_S_3) ||
		(m2_state == m2_CALC_S_4) ||
		(m2_state == m2_CALC_S_5) ||
		(m2_state == m2_CALC_S_6) ||
		(m2_state == m2_CALC_S_7) ||
		(m2_state == m2_CALC_S_8)) 
		begin
			SRAM_address_use_m2 = idctAddress;
		end else if((m2_state == m2_WS_1) || 
					(m2_state == m2_WS_2) || 
					(m2_state == m2_WS_3) || 
					(m2_state == m2_WS_4) || 
					(m2_state == m2_WS_5) ||
					(m2_state == m2_CALC_TW_1) ||
					(m2_state == m2_CALC_TW_2) ||
					(m2_state == m2_CALC_TW_3) ||
					(m2_state == m2_CALC_TW_4) ||
					(m2_state == m2_CALC_TW_5) ||
					(m2_state == m2_CALC_TW_6) ||
					(m2_state == m2_CALC_TW_7) ||
					(m2_state == m2_CALC_TW_8)) 
			begin
				SRAM_address_use_m2 = s_addr_ctr;
		end
end

// MAC Units
logic [31:0] mac_o1[3:0];
logic [31:0] mac_o2[3:0];
logic [63:0] mac_mult[3:0];
logic [63:0] mac_acc[3:0];
logic mac_clear[3:0];
assign mac_mult[0] = $signed(mac_o1[0]) *$signed(mac_o2[0]);
assign mac_mult[1] = $signed(mac_o1[1]) *$signed(mac_o2[1]);
assign mac_mult[2] = $signed(mac_o1[2]) *$signed(mac_o2[2]);
assign mac_mult[3] = $signed(mac_o1[3]) *$signed(mac_o2[3]);

always_ff@(posedge CLOCK_50_I or negedge resetn) begin
	if ((~resetn)) begin
		mac_acc[0] <= 64'd0;
		mac_acc[1] <= 64'd0;
		mac_acc[2] <= 64'd0;
		mac_acc[3] <= 64'd0;
	end else begin
		if (mac_clear[0] == 1'b0) begin
			mac_acc[0] <= $signed(mac_acc[0] + mac_mult[0]);
		end else begin
			mac_acc[0] <= $signed(mac_mult[0]);
		end
		if (mac_clear[1] == 1'b0) begin
			mac_acc[1] <= $signed(mac_acc[1] + mac_mult[1]);
		end else begin
			mac_acc[1] <= $signed(mac_mult[1]);
		end
		if (mac_clear[2] == 1'b0) begin
			mac_acc[2] <= $signed(mac_acc[2] + mac_mult[2]);
		end else begin
			mac_acc[2] <= $signed(mac_mult[2]);
		end
		if (mac_clear[3] == 1'b0) begin
			mac_acc[3] <= $signed(mac_acc[3] + mac_mult[3]);
		end else begin
			mac_acc[3] <= $signed(mac_mult[3]);
		end
	end
end

logic [3:0] TcolCounter;
logic [3:0] TrowCounter;
logic [31:0] Tbuffer1;
logic [31:0] Tbuffer2;

logic [7:0] macTest[3:0];

logic [7:0] sCounter;
logic [7:0] wsCounter;

logic firstRun;
logic secondRun;
logic rowTicker;
logic colTicker;
logic sDelay;

logic [8:0] bufferY[3:0];

always_comb begin
	if (|mac_acc[0][63:48]) begin
		macTest[0] = 8'd0;
	end else if (mac_acc[0][31:16] > 255) begin
		macTest[0] = 8'd255;
	end else begin
		macTest[0] = mac_acc[0] >>> 16;
	end
	if (|mac_acc[1][63:48]) begin
		macTest[1] = 8'd0;
	end else if (mac_acc[1][31:16] > 255) begin
		macTest[1] = 8'd255;
	end else begin
		macTest[1] = mac_acc[1] >>> 16;
	end
	if (|mac_acc[2][63:48]) begin
		macTest[2] = 8'd0;
	end else if (mac_acc[2][31:16] > 255) begin
		macTest[2] = 8'd255;
	end else begin
		macTest[2] = mac_acc[2] >>> 16;
	end
	if (|mac_acc[3][63:48]) begin
		macTest[3] = 8'd0;
	end else if (mac_acc[3][31:16] > 255) begin
		macTest[3] = 8'd255;
	end else begin
		macTest[3] = mac_acc[3] >>> 16;
	end
end

logic fetchSComp;
logic [4:0] DEBUG_CsCounter;
logic [31:0] sram_s_write_buf;
logic updateBuff;
logic TWfirstRun;
logic switchState;
logic nov26647am;

// Writing S' to DP-RAM
always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		address_a[2] <= 7'd127;
		write_enable_a[2] <= 1'b0;
		write_enable_b[2] <= 1'b0;
		s_addr_ctr_en <= 1'b0;
		S_prime_buffer <= 16'd0;
		SRAM_use_m2 <= 1'b0;
		sram_write_data_m2 <= 'd0;
		m2CountEnable <= 1'b0;
		firstRun <= 1'b0;
		mac_clear[0] <= 1'b0;
		mac_clear[1] <= 1'b0;
		mac_clear[2] <= 1'b0;
		mac_clear[3] <= 1'b0;
		mac_o1[0] <= 'd0;
		mac_o1[1] <= 'd0;
		mac_o1[2] <= 'd0;
		mac_o1[3] <= 'd0;
		mac_o2[0] <= 'd0;
		mac_o2[1] <= 'd0;
		mac_o2[2] <= 'd0; 
		mac_o2[3] <= 'd0;
		sram_s_write_buf <= 'd0;
		TcolCounter <= 'd0;
		TrowCounter <= 'd0;
		Tbuffer1 <= 'd0;
		Tbuffer2 <= 'd0;
		secondRun <= 1'b0;
		rowTicker <= 1'b0;
		colTicker <= 1'b0;
		sCounter <= 'd0;
		sDelay <= 1'b0;
		fetchSComp <= 1'b0;
		DEBUG_CsCounter <= 'd0;
		updateBuff <= 1'b0;
		TWfirstRun <= 1'b0;
		wsCounter <= 1'b0;
		switchState <= 1'b0;
	end else if (m2start == 1'b1) begin
		case(m2_state)
		m2_IDLE: begin
			m2CountEnable <= 1'b1;
			m2_state <= m2_IDLE_1;
		end
		m2_IDLE_1: begin
			m2_state <= m2_IDLE_2;
		end
		m2_IDLE_2: begin
			//m2CountEnable <= 1'b1;
			m2_state <= m2_FETCH_S_PRIME_1;
		end
		m2_FETCH_S_PRIME_1: begin
			write_enable_a[2] <= 1'b1;
			S_prime_buffer <= SRAM_read_data;
			m2_state <= m2_FETCH_S_PRIME_2;
			/* if(block_element_counter == 'd63) begin
				m2CountEnable <= 1'b0;
			end */
		end
		m2_FETCH_S_PRIME_2: begin
			write_enable_a[2] <= 1'b0;
			address_a[2] <= address_a[2] + 1;
			//S_prime_buffer <= SRAM_read_data;
			write_data_a[2] = {S_prime_buffer, SRAM_read_data};
			if(block_element_counter < 'd63) begin
				m2_state <= m2_FETCH_S_PRIME_1;
			end else begin
				m2_state <= m2_FETCH_S_PRIME_DELAY_1;
				m2CountEnable <= 1'b0;
			end
		end
		m2_FETCH_S_PRIME_DELAY_1: begin
			S_prime_buffer <= SRAM_read_data;
			address_a[2] <= address_a[2] + 1;
			m2_state <= m2_FETCH_S_PRIME_DELAY_2;
		end
		m2_FETCH_S_PRIME_DELAY_2: begin
			write_enable_a[2] <= 1'b0;
			write_enable_b[2] <= 1'b0;
			write_enable_a[1] <= 1'b0;
			write_enable_b[1] <= 1'b0;
			write_enable_a[0] <= 1'b0;
			write_enable_b[0] <= 1'b0;

			address_a[2] <= 'd0; // S0-1
			address_b[2] <= 'd1; // S2-3

			address_a[1] <= 'd0; // C0-1
			address_b[1] <= 'd1; // C2-3

			address_a[0] <= 'd126; // T0
			address_b[0] <= 'd127; // T1

			m2_state <= m2_REQ_S_PRIME;			// Set up for T calculations
		end
		m2_REQ_S_PRIME: begin
			m2_state <= m2_CALC_T_1;
			address_a[1] <= address_a[1] + 'd4; // C8-9
			address_b[1] <= address_b[1] + 'd4; // C10-11
			wsCounter <= 1'b0;
		end
		m2_CALC_T_1: begin
			write_data_a[0] <= $signed(Tbuffer1);
			write_data_b[0] <= $signed(Tbuffer2);
			address_a[0] <= address_a[0] + 'd2;
			address_b[0] <= address_b[0] + 'd2;
			mac_clear[0] <= 1'b0;
			mac_clear[1] <= 1'b0;
			mac_clear[2] <= 1'b0;
			mac_clear[3] <= 1'b0;
			mac_o1[0] <= $signed(read_data_a[2][31:16]); // S0
			mac_o1[1] <= $signed(read_data_a[2][31:16]); // S0
			mac_o1[2] <= $signed(read_data_a[2][31:16]); // S0
			mac_o1[3] <= $signed(read_data_a[2][31:16]); // S0

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C0
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C1
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C2
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C3
			address_a[1] <= address_a[1] + 'd4; // C16-17
			address_b[1] <= address_b[1] + 'd4; // C18-19
			m2_state <= m2_CALC_T_2;
			end
		m2_CALC_T_2: begin
			if (sCounter == 'd32) begin
				address_a[0] <= 'd0; // T0
				// address_b[0] <= 'd8; // T8
				address_a[1] <= 'd0; // C0-1
				address_b[1] <= 'd1; // C2-3
				address_a[2] <= 'd127; // FOR S PRIME FETCH
				address_b[2] <= 'd111;
				/*mac_clear[0] <= 1'b1;
				mac_clear[1] <= 1'b1;
				mac_clear[2] <= 1'b1;
				mac_clear[3] <= 1'b1;*/
				sCounter <= 'd0;
				firstRun <= 1'b0;
				rowTicker <= 1'b0;
				colTicker <= 1'b0;
				m2_state <= m2_CALC_S_1;
				m2CountEnable <= 1'b0;
				fetchSComp <= 1'b0;
			end else begin
				
				mac_o1[0] <= $signed(read_data_a[2][15:0]); // S1
				mac_o1[1] <= $signed(read_data_a[2][15:0]); // S1
				mac_o1[2] <= $signed(read_data_a[2][15:0]); // S1
				mac_o1[3] <= $signed(read_data_a[2][15:0]); // S1

				mac_o2[0] <= $signed(read_data_a[1][31:16]); // C8
				mac_o2[1] <= $signed(read_data_a[1][15:0]); // C9
				mac_o2[2] <= $signed(read_data_b[1][31:16]); // C10
				mac_o2[3] <= $signed(read_data_b[1][15:0]); // C11

				address_a[1] <= address_a[1] + 'd4; // C24-25
				address_b[1] <= address_b[1] + 'd4; // C26-27

				m2_state <= m2_CALC_T_3;
			end
			write_enable_a[0] <= 1'b0;
			write_enable_b[0] <= 1'b0;
			
		end
		m2_CALC_T_3: begin
			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S2

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C16
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C17
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C18
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C19

			address_a[1] <= address_a[1] + 'd4; // C32-33
			address_b[1] <= address_b[1] + 'd4; // C34-35

			address_a[2] <= address_a[2] + 'd2; // S01 -> S45
			address_b[2] <= address_b[2] + 'd2; // S23 -> S67

			m2_state <= m2_CALC_T_4;
		end
		m2_CALC_T_4: begin

			mac_o1[0] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[1] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[2] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[3] <= $signed(read_data_b[2][15:0]); // S3

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C24
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C25
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C26
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C27

			address_a[1] <= address_a[1] + 'd4; // C40-41
			address_b[1] <= address_b[1] + 'd4; // C42-43

			m2_state <= m2_CALC_T_5;
		end
		m2_CALC_T_5: begin
			mac_o1[0] <= $signed(read_data_a[2][31:16]); // S4
			mac_o1[1] <= $signed(read_data_a[2][31:16]); // S4
			mac_o1[2] <= $signed(read_data_a[2][31:16]); // S4
			mac_o1[3] <= $signed(read_data_a[2][31:16]); // S4

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C32
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C33
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C34
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C35

			address_a[1] <= address_a[1] + 'd4; // C48-49
			address_b[1] <= address_b[1] + 'd4; // C50-51

			m2_state <= m2_CALC_T_6;
		end
		m2_CALC_T_6: begin
			mac_o1[0] <= $signed(read_data_a[2][15:0]); // S5
			mac_o1[1] <= $signed(read_data_a[2][15:0]); // S5
			mac_o1[2] <= $signed(read_data_a[2][15:0]); // S5
			mac_o1[3] <= $signed(read_data_a[2][15:0]); // S5

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C40
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C41
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C42
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C43

			address_a[1] <= address_a[1] + 'd4; // C56-57
			address_b[1] <= address_b[1] + 'd4; // C58-59

			m2_state <= m2_CALC_T_7;
		end
		m2_CALC_T_7: begin
			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S6

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C48
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C49
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C50
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C51
			if (rowTicker == 1'b0) begin
				address_a[1] <= 'd2; // C4-5
				address_b[1] <= 'd3; // C6-7
				rowTicker <= 1'b1;
			end else begin
				address_a[1] <= 'd0;
				address_b[1] <= 'd1;
				rowTicker <= 1'b0;
			end
			if (colTicker == 1'b0) begin
				colTicker <= 1'b1;
				address_a[2] <= address_a[2] - 'd2;
				address_b[2] <= address_b[2] - 'd2;
			end else begin
				colTicker <= 1'b0;
				address_a[2] <= address_a[2] + 'd2;
				address_b[2] <= address_b[2] + 'd2;
			end
			m2_state <= m2_CALC_T_8;
		end
		m2_CALC_T_8: begin
			mac_o1[0] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[1] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[2] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[3] <= $signed(read_data_b[2][15:0]); // S7

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C56
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C57
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C58
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C59

			address_a[1] <= address_a[1] + 'd4; // C12-13
			address_b[1] <= address_b[1] + 'd4; // C14-15
			write_enable_a[0] <= 1'b1;
			write_enable_b[0] <= 1'b1;
			write_data_a[0] <= $signed(mac_acc[0]) >>> 8;
			write_data_b[0] <= $signed(mac_acc[1]) >>> 8;
			Tbuffer1 <= $signed(mac_acc[2]) >>> 8;
			Tbuffer2 <= $signed(mac_acc[3]) >>> 8;
			mac_clear[0] <= 1'b1;
			mac_clear[1] <= 1'b1;
			mac_clear[2] <= 1'b1;
			mac_clear[3] <= 1'b1;
			sCounter <= sCounter + 'd2;
			if (firstRun == 1'b0) begin
				firstRun <= 1'b1;
			end else begin
				address_a[0] <= address_a[0] + 'd2;
				address_b[0] <= address_b[0] + 'd2;
			end
			m2_state <= m2_CALC_T_1;
		end
		m2_CALC_S_1: begin
			
			write_enable_b[2] <= 1'b0;
			if (nov26647am == 1'b0) begin
				mac_clear[0] <= 1'b0;
				mac_clear[1] <= 1'b0;
				mac_clear[2] <= 1'b0;
				mac_clear[3] <= 1'b0;
			end
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C0
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C1
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C2
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C3
			mac_o2[0] <= $signed(read_data_a[0]); // T0
			mac_o2[1] <= $signed(read_data_a[0]); // T0
			mac_o2[2] <= $signed(read_data_a[0]); // T0
			mac_o2[3] <= $signed(read_data_a[0]); // T0
			address_a[0] <= address_a[0] + 'd8; // T8
			address_a[1] <= address_a[1] + 'd4; // C8-9
			address_b[1] <= address_b[1] + 'd4; // C10-11
			if (sCounter == 'd32) begin
				m2_state <= m2_REQ_S_PRIME_2;
				
				// SRAM WRITE STUFF
				address_a[2] <= 'h70;
				// END SRAM WRITE STUFF
				
				//address_a[2] <= 'd0;
				address_b[2] <= 'd0;
				address_a[1] <= 'd0;
				address_b[1] <= 'd1;
				DEBUG_CsCounter <= DEBUG_CsCounter + 'd1;
			end else begin
				m2_state <= m2_CALC_S_2;
				// S' fetch
				if (fetchSComp == 1'b0) begin
					m2CountEnable <= 1'b1;
				end

			end

			
		end
		m2_CALC_S_2: begin			
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C8
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C9
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C10
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C11
			mac_o2[0] <= $signed(read_data_a[0]); // T8
			mac_o2[1] <= $signed(read_data_a[0]); // T8
			mac_o2[2] <= $signed(read_data_a[0]); // T8
			mac_o2[3] <= $signed(read_data_a[0]); // T8
			address_a[0] <= address_a[0] + 'd8; // T16
			address_a[1] <= address_a[1] + 'd4; // C16-17
			address_b[1] <= address_b[1] + 'd4; // C18-19
			write_enable_a[2] <= 1'b0;
			write_enable_b[2] <= 1'b0;
			mac_clear[0] <= 1'b1;
			mac_clear[1] <= 1'b1;
			mac_clear[2] <= 1'b1;
			mac_clear[3] <= 1'b1;
			write_enable_b[2] <= 1'b1;
			write_data_b[2] <= {{macTest[0]},{macTest[1]},{macTest[2]},{macTest[3]}};
			sCounter <= sCounter + 'd2;

			m2_state <= m2_CALC_S_3;
		end
		m2_CALC_S_3: begin
			write_enable_b[2] <= 1'b0;
			address_b[2] <= address_b[2] + 'd1;
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C16
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C17
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C18
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C19
			mac_o2[0] <= $signed(read_data_a[0]); // T16
			mac_o2[1] <= $signed(read_data_a[0]); // T16
			mac_o2[2] <= $signed(read_data_a[0]); // T16
			mac_o2[3] <= $signed(read_data_a[0]); // T16
			address_a[0] <= address_a[0] + 'd8; // T24
			address_a[1] <= address_a[1] + 'd4; // C24-25
			address_b[1] <= address_b[1] + 'd4; // C26-27
			mac_clear[0] <= 1'b0;
			mac_clear[1] <= 1'b0;
			mac_clear[2] <= 1'b0;
			mac_clear[3] <= 1'b0;
			m2_state <= m2_CALC_S_4;
		end
		m2_CALC_S_4: begin

			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C24
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C25
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C26
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C27

			mac_o2[0] <= $signed(read_data_a[0]); // T24
			mac_o2[1] <= $signed(read_data_a[0]); // T24
			mac_o2[2] <= $signed(read_data_a[0]); // T24
			mac_o2[3] <= $signed(read_data_a[0]); // T24
			
			address_a[0] <= address_a[0] + 'd8; // T32
			address_a[1] <= address_a[1] + 'd4; // C32-33
			address_b[1] <= address_b[1] + 'd4; // C34-35

			// S' fetch
			S_prime_buffer <= SRAM_read_data;

			m2_state <= m2_CALC_S_5;
		end
		m2_CALC_S_5: begin
			address_a[2] <= address_a[2] + 1;
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C32
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C33
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C34
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C35
			mac_o2[0] <= $signed(read_data_a[0]); // T32
			mac_o2[1] <= $signed(read_data_a[0]); // T32
			mac_o2[2] <= $signed(read_data_a[0]); // T32
			mac_o2[3] <= $signed(read_data_a[0]); // T32
			address_a[0] <= address_a[0] + 'd8; // T40
			address_a[1] <= address_a[1] + 'd4; // C40-41
			address_b[1] <= address_b[1] + 'd4; // C42-43

			// S' fetch
			write_enable_a[2] <= 1'b1;
			write_data_a[2] <= {S_prime_buffer, SRAM_read_data};
			address_a[2] <= address_a[2] + 1;
			m2CountEnable <= 1'b0;

			m2_state <= m2_CALC_S_6;
		end
		m2_CALC_S_6: begin
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C40
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C41
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C42
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C43
			mac_o2[0] <= $signed(read_data_a[0]); // T40
			mac_o2[1] <= $signed(read_data_a[0]); // T40
			mac_o2[2] <= $signed(read_data_a[0]); // T40
			mac_o2[3] <= $signed(read_data_a[0]); // T40
			address_a[0] <= address_a[0] + 'd8; // T48
			address_a[1] <= address_a[1] + 'd4; // C48-49
			address_b[1] <= address_b[1] + 'd4; // C50-51

			// S' fetch
			S_prime_buffer <= SRAM_read_data;
			write_enable_a[2] <= 1'b0;

			m2_state <= m2_CALC_S_7;
		end
		m2_CALC_S_7: begin
			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C48
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C49
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C50
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C51

			mac_o2[0] <= $signed(read_data_a[0]); // T48
			mac_o2[1] <= $signed(read_data_a[0]); // T48
			mac_o2[2] <= $signed(read_data_a[0]); // T48
			mac_o2[3] <= $signed(read_data_a[0]); // T48
			
			address_a[0] <= address_a[0] + 'd8; // T56
			address_a[1] <= address_a[1] + 'd4; // C56-57
			address_b[1] <= address_b[1] + 'd4; // C58-59

			// S' fetch
			write_data_a[2] <= {S_prime_buffer, SRAM_read_data};
			address_a[2] <= address_a[2] + 1;
			write_enable_a[2] <= 1'b1;

			m2_state <= m2_CALC_S_8;
		end
		m2_CALC_S_8: begin
			// S' fetch
			write_enable_a[2] <= 1'b0;

			mac_o1[0] <= $signed(read_data_a[1][31:16]); // C56
			mac_o1[1] <= $signed(read_data_a[1][15:0]); // C57
			mac_o1[2] <= $signed(read_data_b[1][31:16]); // C58
			mac_o1[3] <= $signed(read_data_b[1][15:0]); // C59

			mac_o2[0] <= $signed(read_data_a[0]); // T56
			mac_o2[1] <= $signed(read_data_a[0]); // T56
			mac_o2[2] <= $signed(read_data_a[0]); // T56
			mac_o2[3] <= $signed(read_data_a[0]); // T56
			
			if (rowTicker == 1'b0) begin
				address_a[1] <= 'd2; // C0-1
				address_b[1] <= 'd3; // C2-3
				rowTicker <= 1'b1;
			end else begin
				address_a[1] <= 'd0; // C4-5
				address_b[1] <= 'd1; // C6-7
				rowTicker <= 1'b0;
			end
			if (colTicker == 1'b0) begin
				colTicker <= 1'b1;
				address_a[0] <= address_a[0] - 'd56;
			end else begin
				colTicker <= 1'b0;
				address_a[0] <= address_a[0] - 'd55;
			end

			m2_state <= m2_CALC_S_1;
		end
		m2_REQ_S_PRIME_2: begin
			mac_clear[0] <= 1'b1;
			mac_clear[1] <= 1'b1;
			mac_clear[2] <= 1'b1;
			mac_clear[3] <= 1'b1;
			m2_state <= m2_CALC_TW_1;
			TWfirstRun <= 1'b0;
			address_a[1] <= address_a[1] + 'd4; // C8-9
			address_b[1] <= address_b[1] + 'd4; // C10-11
			//address_b[2] <= address_b[2] + 'd1;
			address_a[0] <= 'd126; // T0
			address_b[0] <= 'd127; // T1
			sCounter <= 'd0;

			// SRAM WRITE STUFF
			address_a[2] <= address_a[2] + 'd2; // 72
			

		end
		m2_CALC_TW_1: begin

			// SRAM WRITE STUFF
			if (TWfirstRun == 1'b0) begin
				sram_s_write_buf <= read_data_a[2]; // 70 data
				TWfirstRun <= 1'b1;
			end
			// END SRAM STUFF

			write_data_a[0] <= $signed(Tbuffer1);
			write_data_b[0] <= $signed(Tbuffer2);
			
			address_a[0] <= address_a[0] + 'd2;
			address_b[0] <= address_b[0] + 'd2;
			mac_clear[0] <= 1'b0;
			mac_clear[1] <= 1'b0;
			mac_clear[2] <= 1'b0;
			mac_clear[3] <= 1'b0;
			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S0
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S0
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S0
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S0

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C0ws
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C1
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C2
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C3

			address_b[2] <= address_b[2] + 'd1;

			if(sCounter == 'd32) begin 
				address_a[2] <= 'h70; // Request first 4 S values (stored in 1 mem location)
			end
			address_a[1] <= address_a[1] + 'd4; // C16-17
			address_b[1] <= address_b[1] + 'd4; // C18-19
			m2_state <= m2_CALC_TW_2;
			end
		m2_CALC_TW_2: begin
			// SRAM WRITE STUFF
			if (wsCounter < 32) begin
				s_addr_ctr_en <= 1'b1;
				SRAM_use_m2 <= 1'b1;
			end
			sram_write_data_m2 <= {sram_s_write_buf[31:24], read_data_a[2][31:24]};
			wsCounter <= wsCounter + 'd1;
			
			// END SRAM WRITE STUFF

			if (sCounter == 'd32) begin
				address_a[0] <= 'd0; // T0
				// address_b[0] <= 'd8; // T8
				address_a[1] <= 'd0; // C0-1
				address_b[1] <= 'd1; // C2-3
				//address_a[2] <= address_a[2] + 'd2; // Request first 4 S values (stored in 1 mem location)
				address_b[2] <= 'd111;
				sCounter <= 'd0;
				firstRun <= 1'b0;
				rowTicker <= 1'b0;
				colTicker <= 1'b0;
				m2_state <= m2_CALC_S_1;
				m2CountEnable <= 1'b0;
				fetchSComp <= 1'b0;
				mac_clear[0] <= 1'b1;
				mac_clear[1] <= 1'b1;
				mac_clear[2] <= 1'b1;
				mac_clear[3] <= 1'b1;

				//address_a[2] <= 'd127; // FOR S PRIME FETCH
				address_b[2] <= 'd111;
				
				address_a[2] <= 'd127;
				wsCounter <= 'd0;
				m2_state <= m2_CALC_S_1;
			end else begin			
				
				mac_o1[0] <= $signed(read_data_b[2][15:0]); // S1
				mac_o1[1] <= $signed(read_data_b[2][15:0]); // S1
				mac_o1[2] <= $signed(read_data_b[2][15:0]); // S1
				mac_o1[3] <= $signed(read_data_b[2][15:0]); // S1

				mac_o2[0] <= $signed(read_data_a[1][31:16]); // C8
				mac_o2[1] <= $signed(read_data_a[1][15:0]); // C9
				mac_o2[2] <= $signed(read_data_b[1][31:16]); // C10
				mac_o2[3] <= $signed(read_data_b[1][15:0]); // C11

				address_a[1] <= address_a[1] + 'd4; // C24-25
				address_b[1] <= address_b[1] + 'd4; // C26-27

				//address_b[2] <= address_b[2] + 'd1;

				m2_state <= m2_CALC_TW_3;
			end
			write_enable_a[0] <= 1'b0;
			write_enable_b[0] <= 1'b0;
			
		end
		m2_CALC_TW_3: begin
			// SRAM WRITE STUFF
			sram_write_data_m2 <= {sram_s_write_buf[23:16], read_data_a[2][23:16]};
			wsCounter <= wsCounter + 'd1;
			// END SRAM WRITE STUFF

			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S2
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S2

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C16
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C17
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C18
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C19

			address_a[1] <= address_a[1] + 'd4; // C32-33
			address_b[1] <= address_b[1] + 'd4; // C34-35

			address_b[2] <= address_b[2] + 'd1;


			m2_state <= m2_CALC_TW_4;
		end
		m2_CALC_TW_4: begin
			// SRAM WRITE STUFF
			if (secondRun == 1'b0) begin
				address_a[2] <= address_a[2] - 'd1;
				secondRun <= 1'b1;
				updateBuff <= 1'b1;
			end else begin
				address_a[2] <= address_a[2] + 'd1;
				secondRun <= 1'b0;
				
			end
			sram_write_data_m2 <= {sram_s_write_buf[15:8], read_data_a[2][15:8]};
			wsCounter <= wsCounter + 'd1;
			
			// END SRAM WRITE STUFF

			mac_o1[0] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[1] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[2] <= $signed(read_data_b[2][15:0]); // S3
			mac_o1[3] <= $signed(read_data_b[2][15:0]); // S3

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C24
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C25
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C26
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C27

			address_a[1] <= address_a[1] + 'd4; // C40-41
			address_b[1] <= address_b[1] + 'd4; // C42-43

			m2_state <= m2_CALC_TW_5;
		end
		m2_CALC_TW_5: begin
			// SRAM WRITE STUFF
			address_a[2] <= address_a[2] + 'd2;
			
			sram_write_data_m2 <= {sram_s_write_buf[7:0], read_data_a[2][7:0]};
			wsCounter <= wsCounter + 'd1;
			// END SRAM WRITE STUFF

			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S4
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S4
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S4
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S4

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C32
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C33
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C34
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C35

			address_a[1] <= address_a[1] + 'd4; // C48-49
			address_b[1] <= address_b[1] + 'd4; // C50-51

			address_b[2] <= address_b[2] + 'd1;

			m2_state <= m2_CALC_TW_6;
		end
		m2_CALC_TW_6: begin
			// SRAM WRITE STUFF
			sram_s_write_buf <= read_data_a[2];
			SRAM_use_m2 <= 1'b0;
			s_addr_ctr_en <= 1'b0;
			// END SRAM WRITE STUFF

			mac_o1[0] <= $signed(read_data_b[2][15:0]); // S5
			mac_o1[1] <= $signed(read_data_b[2][15:0]); // S5
			mac_o1[2] <= $signed(read_data_b[2][15:0]); // S5
			mac_o1[3] <= $signed(read_data_b[2][15:0]); // S5

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C40
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C41
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C42
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C43

			address_a[1] <= address_a[1] + 'd4; // C56-57
			address_b[1] <= address_b[1] + 'd4; // C58-59

			m2_state <= m2_CALC_TW_7;
		end
		m2_CALC_TW_7: begin
			mac_o1[0] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[1] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[2] <= $signed(read_data_b[2][31:16]); // S6
			mac_o1[3] <= $signed(read_data_b[2][31:16]); // S6

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C48
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C49
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C50
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C51
			if (rowTicker == 1'b0) begin
				address_a[1] <= 'd2; // C4-5
				address_b[1] <= 'd3; // C6-7
				rowTicker <= 1'b1;
			end else begin
				address_a[1] <= 'd0;
				address_b[1] <= 'd1;
				rowTicker <= 1'b0;
			end
			if (colTicker == 1'b0) begin
				colTicker <= 1'b1;
				address_b[2] <= address_b[2] - 'd3;
			end else begin
				colTicker <= 1'b0;
				address_b[2] <= address_b[2] + 'd1;
			end
			m2_state <= m2_CALC_TW_8;
		end
		m2_CALC_TW_8: begin
			mac_o1[0] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[1] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[2] <= $signed(read_data_b[2][15:0]); // S7
			mac_o1[3] <= $signed(read_data_b[2][15:0]); // S7

			mac_o2[0] <= $signed(read_data_a[1][31:16]); // C56
			mac_o2[1] <= $signed(read_data_a[1][15:0]); // C57
			mac_o2[2] <= $signed(read_data_b[1][31:16]); // C58
			mac_o2[3] <= $signed(read_data_b[1][15:0]); // C59

			address_a[1] <= address_a[1] + 'd4; // C12-13
			address_b[1] <= address_b[1] + 'd4; // C14-15
			write_enable_a[0] <= 1'b1;
			write_enable_b[0] <= 1'b1;
			write_data_a[0] <= $signed(mac_acc[0]) >>> 8;
			write_data_b[0] <= $signed(mac_acc[1]) >>> 8;
			Tbuffer1 <= $signed(mac_acc[2]) >>> 8;
			Tbuffer2 <= $signed(mac_acc[3]) >>> 8;
			mac_clear[0] <= 1'b1;
			mac_clear[1] <= 1'b1;
			mac_clear[2] <= 1'b1;
			mac_clear[3] <= 1'b1;
			sCounter <= sCounter + 'd2;
			if (firstRun == 1'b0) begin
				firstRun <= 1'b1;
			end else begin
				address_a[0] <= address_a[0] + 'd2;
				address_b[0] <= address_b[0] + 'd2;
			end
			m2_state <= m2_CALC_TW_1;
		end
		m2_WS_DELAY_1: begin
			sram_s_write_buf <= read_data_a[2];
			m2_state <= m2_WS_1;
		end
		m2_WS_1: begin
			s_addr_ctr_en <= 1'b1;
			sram_write_data_m2 <= {sram_s_write_buf[31:24], read_data_a[2][31:24]};
			sCounter <= sCounter + 'd1;
			SRAM_use_m2 <= 1'b1;
			m2_state <= m2_WS_2;
		end
		m2_WS_2: begin
			sram_write_data_m2 <= {sram_s_write_buf[23:16], read_data_a[2][23:16]};
			sCounter <= sCounter + 'd1;
			m2_state <= m2_WS_3;
		end
		m2_WS_3: begin
			if (secondRun == 1'b0) begin
				address_a[2] <= address_a[2] - 'd1;
				secondRun <= 1'b1;
			end else begin
				address_a[2] <= address_a[2] + 'd1;
				secondRun <= 1'b0;
			end
			sram_write_data_m2 <= {sram_s_write_buf[15:8], read_data_a[2][15:8]};
			sCounter <= sCounter + 'd1;
			m2_state <= m2_WS_4;
		end
		m2_WS_4: begin
			address_a[2] <= address_a[2] + 'd2;
			sram_write_data_m2 <= {sram_s_write_buf[7:0], read_data_a[2][7:0]};
			sCounter <= sCounter + 'd1;
			m2_state <= m2_WS_5;
		end
		m2_WS_5: begin
			sram_s_write_buf <= read_data_a[2];
			SRAM_use_m2 <= 1'b0;
			s_addr_ctr_en <= 1'b0;
			if(sCounter != 'd64) begin
				m2_state <= m2_WS_1;
			end else begin
				m2_state <= m2_IDLE;
			end
		end
		default: m2_state <= m2_IDLE;
		endcase
	end
end

// <------------------------- END OF MILESTONE 2
// <------------------------- BEGIN MILESTONE 3
m3_state_type m3_state;
logic SRAM_address_use_m3;
logic SRAM_use_m3;

always @(posedge CLOCK_50_I or negedge resetn) begin
	if (~resetn) begin
		m3done <= 1'b0;
		SRAM_use_m3 <= 1'b0;
	end else begin
		case (m3_state)
		m3_IDLE: begin
			m3done <= 1'b1;
		end
		default: m3_state <= m3_IDLE;
		endcase
	end
end

// <------------------------- END OF MILESTONE 3

assign VGA_base_address = 18'd146944;

always_comb begin
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_address = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX))
						? UART_SRAM_address
						: VGA_SRAM_address;
	end else if (m1start == 1'b1) begin
		SRAM_address = SRAM_address_use;
	end else if (top_state == S_MILESTONE_2) begin
		SRAM_address = SRAM_address_use_m2;
	end else if (m3start == 1'b1) begin
		SRAM_address = SRAM_address_use_m3;
	end
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_we_n = ((top_state == S_ENABLE_UART_RX) | (top_state == S_WAIT_UART_RX))
						? UART_SRAM_we_n
						: 1'b1;
	end else if ((SRAM_use == 1'b1) || (SRAM_use_m2 == 1'b1) || (SRAM_use_m3 == 1'b1)) begin
		SRAM_we_n = 1'b0;
	end else begin
		SRAM_we_n = 1'b1;
	end
	if ((top_state == S_ENABLE_UART_RX) || (top_state == S_WAIT_UART_RX) || (top_state == S_IDLE)) begin
		SRAM_write_data = UART_SRAM_write_data;
	end else begin
		if((m2_state == m2_WS_1) || (m2_state == m2_WS_2) || (m2_state == m2_WS_3) || (m2_state == m2_WS_4) || (m2_state == m2_WS_5) ||
					(m2_state == m2_CALC_TW_1) ||
					(m2_state == m2_CALC_TW_2) ||
					(m2_state == m2_CALC_TW_3) ||
					(m2_state == m2_CALC_TW_4) ||
					(m2_state == m2_CALC_TW_5) ||
					(m2_state == m2_CALC_TW_6) ||
					(m2_state == m2_CALC_TW_7) ||
					(m2_state == m2_CALC_TW_8)) begin
			SRAM_write_data = sram_write_data_m2;
		end else begin
			SRAM_write_data = SRAM_write_data_use;
		end
	end
end

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
