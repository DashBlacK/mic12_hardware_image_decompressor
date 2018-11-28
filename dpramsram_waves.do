add wave -divider {S Addr Ctr}
add wave uut/dpram_sram_inst0/Clock_50
add wave uut/dpram_sram_inst0/ws_en
add wave -unsigned uut/dpram_sram_inst0/DP_RAM_Address
add wave -unsigned uut/dpram_sram_inst0/DP_RAM_Read_Data
add wave -unsigned uut/dpram_sram_inst0/ws_state

add wave -unsigned uut/dpram_sram_inst0/s_addr_ctr
add wave -unsigned uut/dpram_sram_inst0/s_element_ctr
add wave -unsigned uut/dpram_sram_inst0/column_addr
add wave uut/dpram_sram_inst0/s_addr_ctr_en

add wave -divider {TOP FSM}
add wave uut/m2_state
add wave uut/write_enable_a
add wave uut/read_data_a
add wave uut/address_a