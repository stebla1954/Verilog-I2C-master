# write_24XX02.tcl : TCL script to read a file of hex bytes
# and write them to the 24XX02 I2C EEPROM on the DE0-Nano FPGA development
# board.
set x [lindex [get_service_paths master] 0]
if { [is_service_open master $x]} {
    puts "service is already open"
} else {
    open_service master $x
}
set fileId [open wr24XX02.hex r]
set byte_addr 0
while {[gets $fileId line] >=0 } {
    puts $line
    master_write_8 $x 0x00 [list 0xa0 [format "%#02x" $byte_addr] $line 0x01]
    after 250
    set y [master_read_8 $x 0x00 4]
    set ack [string range $y 18 18]
    #if { $ack == "2" } {
    #	puts [format "write %10s failed at address %#02x" $line $byte_addr]
    #} else if ($ack == "0") {
#	puts [format "wrote %10s at address %#02x" $line $byte_addr]
 #   } else {
#	puts [format "Unexpected ack %10s" $ack]
 #   }
    incr byte_addr
}
close $fileId
close_service master $x
