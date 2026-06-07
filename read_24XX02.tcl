# read_24XX02.tcl : TCL script to read the bytes in the 24XX02 I2C
# EEPROM on the DE0-Nano FPGA development board.
set x [lindex [get_service_paths master] 0]
if { [is_service_open master $x]} {
    puts "service is already open"
} else {
    open_service master $x
}
set fileId [open rd24XX02.hex w]
set byte_addr 0
while {$byte_addr < 256} {
    master_write_8 $x 0x00 [list 0xa1 [format "%#02x" $byte_addr] 0xee 0x01]
    set y [master_read_8 $x 0x00 4]
    #puts [format "%#02x" $byte_addr]
    puts $fileId [string range $y 10 13]
    incr byte_addr
}
close $fileId
close_service master $x
