## Milestone 1
# add waves to waveform
#add wave Clock_50
#add wave uut/top_state
#add wave -divider {SRAM Control}
#add wave uut/SRAM_we_n
#add wave -hexadecimal uut/SRAM_write_data
#add wave -hexadecimal uut/SRAM_read_data
#add wave -unsigned uut/SRAM_address
#add wave uut/do_read_uv
#add wave -unsigned uut/yAddress
#add wave -unsigned uut/uAddress
#add wave -unsigned uut/vAddress
#add wave -unsigned uut/rgbAddress
#add wave -unsigned uut/rgbMax
#add wave -divider {Multiplier 1}
#add wave -decimal uut/mult1_op_1
#add wave -decimal uut/mult1_op_2
#add wave -decimal uut/mult1_result
#add wave -divider {Multiplier 2}
#add wave -decimal uut/mult2_op_1
#add wave -decimal uut/mult2_op_2
#add wave -decimal uut/mult2_result
#add wave -divider {Multiplier 3}
#add wave -decimal uut/mult3_op_1
#add wave -decimal uut/mult3_op_2
#add wave -decimal uut/mult3_result
#add wave -divider {U Prime}
#add wave -hexadecimal uut/U_even
#add wave -hexadecimal uut/U_odd
#add wave -divider {V Prime}
#add wave -hexadecimal uut/V_even
#add wave -hexadecimal uut/V_odd
#add wave -divider {Y}
#add wave -hexadecimal uut/Y0
#add wave -hexadecimal uut/Y1
#add wave -divider {U Shift Registers}
#add wave -hexadecimal uut/U_plus_5
#add wave -hexadecimal uut/U_plus_3
#add wave -hexadecimal uut/U_plus_1
#add wave -hexadecimal uut/U_minus_1
#add wave -hexadecimal uut/U_minus_3
#add wave -hexadecimal uut/U_minus_5
#add wave -divider {V Shift Registers}
#add wave -hexadecimal uut/V_plus_5
#add wave -hexadecimal uut/V_plus_3
#add wave -hexadecimal uut/V_plus_1
#add wave -hexadecimal uut/V_minus_1
#add wave -hexadecimal uut/V_minus_3
#add wave -hexadecimal uut/V_minus_5
#add wave -divider {some label for my divider}
#add wave -unsigned uut/SRAM_address_use
#add wave -decimal uut/yoloCounter
#add wave -decimal uut/offsetCount

## Milestone 2
#add wave -unsigned uut/m1start
#add wave -unsigned uut/m2start
#add wave -unsigned uut/m3start
add wave Clock_50
#add wave uut/top_state
add wave uut/m2_state
add wave -divider {SRAM Control}
add wave uut/SRAM_we_n
add wave -hexadecimal uut/SRAM_write_data
add wave -hexadecimal uut/SRAM_read_data
add wave -unsigned uut/SRAM_address

#add wave -divider {SRAM IDCT Addressing}
#add wave -unsigned uut/idctAddress
#add wave -unsigned uut/m2CountEnable
#add wave -unsigned uut/block_element_counter
#add wave -unsigned uut/S_prime_buffer
#add wave -unsigned uut/RowAddr
#add wave -unsigned uut/RowBase
#add wave -unsigned uut/RowIndex
#add wave -unsigned uut/ColAddr
#add wave -unsigned uut/ColBase
#add wave -unsigned uut/ColIndex

#add wave -divider {S Addr Ctr}
#add wave -unsigned uut/s_addr_ctr
#add wave -unsigned uut/s_element_ctr
#add wave -unsigned uut/column_addr
#add wave uut/s_addr_ctr_en


add wave -divider {DP-RAM}
add wave -hexadecimal uut/write_enable_a
add wave -hexadecimal uut/write_enable_b
add wave -hexadecimal uut/address_a
add wave -hexadecimal uut/address_b
add wave -hexadecimal uut/read_data_a
add wave -hexadecimal uut/read_data_b
add wave -hexadecimal uut/write_data_a
add wave -hexadecimal uut/write_data_b
add wave -decimal uut/sCounter
add wave -decimal uut/wsCounter
add wave -hexadecimal uut/sram_s_write_buf
add wave -divider {}

#add wave uut/SRAM_we_n
#add wave -hexadecimal uut/SRAM_write_data
#add wave -hexadecimal uut/SRAM_read_data
#add wave -divider
#add wave -unsigned uut/write_enable_a
#add wave -unsigned uut/address_a
#add wave -hexadecimal uut/S_prime_buffer
#add wave -hexadecimal uut/SRAM_read_data

add wave -divider {MAC Operations}
add wave -decimal uut/mac_o1
add wave -decimal uut/mac_o2
add wave -decimal uut/mac_mult
add wave -decimal uut/mac_acc
add wave -hexadecimal uut/macTest
add wave -decimal uut/mac_clear
add wave -hexadecimal uut/bufferY
#add wave -decimal uut/Tbuffer1
#add wave -decimal uut/Tbuffer2