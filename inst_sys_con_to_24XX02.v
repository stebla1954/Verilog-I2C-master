// inst_sys_con_to_24XX02.v : Toplevel Verilog for a Quartus project to
// try to persuade system-console to write and read the 24XX02 I2C
// EEPROM that is on the DE0-Nano FPGA development board.
//
// This project builds on the success of the Quartus project 
// with top-level module inst_tst_sys_con which used custom IP 
// module avln_mm_slv_ram.v which implemented an Avalon-MM slave
// interface to an on-chip RAM of size 64 words each of size 32 bits.
// The custom IP was hooked up to Altera IP that connects a JTAG
// interface to an Avalon-MM master. The Altera IP and the custom IP
// was put together into a component using Platform-Designer and the
// system demonstrated the ability to write and read the RAM using
// TCL commands from system-console.
//
// The current project will replace the custom IP avln_mm_slv_ram.v
// with the new custom IP module avln_mm_slv_I2C_mstr.v which has
// an Avalon-MM slave 32-bit command and status register which
// controls the operation of an I2C master. The I2C master is wired
// up to the I2C bus that connects to the 24XX02 EEPROM on the 
// DE0-Nano.
//
// The project is intended to run on the DE0-Nano daughter board.
// The idea is to gradually build up to a system that can be used
// to interact with the MSP hardware.
//
// 5th June 2026.
// The I2C master is working. This is how to write and read from
// the 24XX02 I2C EEPROM on the DE0-Nano board using system-console.
// In a terminal, set the PATH environmental variable to the
// location of the system console executable.
// > export PATH=$PATH:~/intelFPGA_lite/24.1std/qprogrammer/sopc_builder/bin
// Launch system console.
// > system-console
// The following TCL commands are typed into the TCL panel in 
// system-console. The TCL prompt is %. Responses from system-console
// are shown as => <some response>
// % set x [lindex [get_service_paths master] 0]
// open_service master $x
// is_service_open master $x
// => 1
// The next task will be to read the byte from the 24XX02 at memory
// address 0x04.
// % master_write_8 $x 0x00 [list 0xa1 0x04 0xff 0x01]
// This forms the 32-bit command cmd=0x01ff04a1. The 24XX02 slave
// is 0xa1 for a read and 0xa0 for a write. The problem persuading the
// system to work was that I was using master_write_32 but this doesn't
// work, but I don't understand why it fails. It should be noted that
// master_write_32 $x 0x00 [list 0xa1 0x04 0xff 0x01] seems to write
// the 32-bit command as 0xa104ff01 which is not what is wanted.
// However, writing the four bytes in the reverse order did not seem
// to make the system work. So, I'm just going to stick to using the
// master_write_8 and master_read_8 commands.
// To see the byte read from the 24XX02, type,
// % master_read_8 $x 0x00 4
// => 0xad 0xde 0x00 0x02
// The first two bytes read from the I2C master's register are 0xdead.
// The third byte 0x00 is the byte read from the 24XX02 memory. The
// fourth byte 0x02 shows that the last ACK/NACK was a NACK. This is 
// sensible, because the I2C master terminates the reads from the 
// slave with a NACK.
// Now let's write byte 0x27 to address 0x04.
// % master_write_8 $x 0x00 [list 0xa0 0x04 0x27 0x01]
// We can check if this command was successful by looking at the last ACK.
// The last ACK is from the slave, so if the write transaction was a
// success, the last ACK/NACK should be ACK.
// % master_read_8 $x 0x00 4
// => 0xad 0xde 0x00 0x00
// The fourth byte 0x00 shows that the last ACK/NACK was an ACK.
// The third byte 0x00 is not the byte read from the 24XX02. To actually
// read the byte at address 0x04 type,
// % master_write_8 $x 0x00 [list 0xa1 0x04 0xff 0x01]
// Now read the I2C register,
// % master_read_8 $x 0x00 4
// => 0xad 0xde 0x27 0x02
// The third byte 0x27 is the byte read from the 24XX02 at address 0x04.
// This demonstrates how to interact with the 24XX02. We now close
// the service.
// % close_service master $x
// % is_service_open master $x
// => 0
// Now exit the system-console GUI.
// I think the IC master was working at commit 
// 38ecdd5b20efe17c579430e27bbca27766f4473b
// but I then hacked the way the component connected to the I2C
// bus by moving the tri-state buffers from the IP component
// avln_mm_slv_I2C_mstr.v into the toplevel module (this file)
// inst_sys_con_to_24XX02.v . So, I'm going to commit the current
// code on 5th June 2026 so that I've got a record of the working
// I2C master and then try to get back to the more sensible version
// with the tri-state buffers inside the IP avln_mm_slv_I2C_mstr.v .
//
`timescale 1ns/100ps
module inst_sys_con_to_24XX02(CLOCK_50,KEY0,SDA_24XX02,SCL_24XX02);
   input CLOCK_50,KEY0;
   inout	SDA_24XX02,SCL_24XX02;
   wire		CLOCK_50,KEY0;
   wire		SDA_24XX02,SCL_24XX02;

   wire		clk,pll_locked;
   pll U0(.inclk0(CLOCK_50),.c0(clk),.locked(pll_locked));

   
   sys_con_I2C_mstr U1(.clk_clk(clk),.reset_reset_n(rst_n),
		       .avln_mm_slv_i2c_mstr_0_conduit_end_sda(SDA_24XX02),
		       .avln_mm_slv_i2c_mstr_0_conduit_end_scl(SCL_24XX02));	


   //Pushbutton KEY0 on the DE0-Nano board produces a debounced low
   //level when pressed. So, we invert KEY0 to reset the other modules.
   // On the DE0-Nano daughter board, KEY0 is connected to a reset
   // button at the output of a Schmidt trigger which produces a
   // debounced low pulse when pressed.
   wire rst;
   assign rst = ~KEY0 & pll_locked;

   wire rst_n;
   assign rst_n = ~rst;
   

endmodule // inst_sys_con_to_24XX02
