`ifndef DEFINE_STATE

// This defines the milestone 1 states
typedef enum logic [5:0] {
	S_IDLE,
	S_ENABLE_UART_RX,
	S_WAIT_UART_RX,
	S_MILESTONE_3,
	S_MILESTONE_2,
	S_IDLE_1,
	S_IDLE_11,
	S_IDLE_2,
	S_1,
	S_2,
	S_3,
	S_4,
	S_5,
	S_6,
	S_7,
	S_8,
	S_9,
	S_10,
	S_11,
	S_12,
	S_13,
	S_14,
	S_15,
	S_16,
	S_LEADOUT_1,
	S_LEADOUT_2,
	S_LEADOUT_3,
	S_LEADOUT_4,
	S_LEADOUT_5,
	S_LEADOUT_6,
	S_DELAY_1,
	S_DELAY_2
} top_state_type;

// This defines the milestone 2 states
typedef enum logic [4:0] {
	m2_IDLE,
	m2_IDLE_1,
	m2_IDLE_2,
	m2_FETCH_S_prime_1,
	m2_FETCH_S_prime_2,
	m2_FETCH_S_prime_DELAY_1,
	m2_FETCH_S_prime_DELAY_2,
	m2_REQ_S_prime,
	m2_CALC_T_1
} m2_state_type;

// This defines the milestone 3 states
typedef enum logic [4:0] {
	m3_IDLE
} m3_state_type;

typedef enum logic [1:0] {
	S_RXC_IDLE,
	S_RXC_SYNC,
	S_RXC_ASSEMBLE_DATA,
	S_RXC_STOP_BIT
} RX_Controller_state_type;

typedef enum logic [2:0] {
	S_US_IDLE,
	S_US_STRIP_FILE_HEADER_1,
	S_US_STRIP_FILE_HEADER_2,
	S_US_START_FIRST_BYTE_RECEIVE,
	S_US_WRITE_FIRST_BYTE,
	S_US_START_SECOND_BYTE_RECEIVE,
	S_US_WRITE_SECOND_BYTE
} UART_SRAM_state_type;

typedef enum logic [3:0] {
	S_VS_WAIT_NEW_PIXEL_ROW,
	S_VS_NEW_PIXEL_ROW_DELAY_1,
	S_VS_NEW_PIXEL_ROW_DELAY_2,
	S_VS_NEW_PIXEL_ROW_DELAY_3,
	S_VS_NEW_PIXEL_ROW_DELAY_4,
	S_VS_NEW_PIXEL_ROW_DELAY_5,
	S_VS_FETCH_PIXEL_DATA_0,
	S_VS_FETCH_PIXEL_DATA_1,
	S_VS_FETCH_PIXEL_DATA_2,
	S_VS_FETCH_PIXEL_DATA_3
} VGA_SRAM_state_type;

`define DEFINE_STATE 1
`endif
