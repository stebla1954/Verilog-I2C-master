# Verilog-I2C-master
A Quartus project which allows stand-alone system-console to write to and read from the 24XX02 I2C EEPROM on Terasic's DE0-Nano FPGA development board.
1. Background
This project came about because the writer had made a small FPGA hardware project that included some parameters which
might, occasionally, need to be changed. Since I used Terasic's DE0-Nano FPGA board for prototyping, I decided to store  the
parameters in the 24XX02 256 x 8 bit I2C EEPROM that is on the board.

My initial plan was to add the Intel FPGA Avalon I2C (Host) core which is described in section 14 of reference [1]. This 
IP enables an FPGA to act as an I2C master controller on an I2C bus. My intention was to hook up this IP to the external 
EEPROM I2C slave. The IP has an Avalon-MM agent interface so that it can be driven by a host processor which reads and 
writes to registers in the I2C master IP component. However, I had earlier made a decision to not use a soft-core processor 
in my FPGA hardware. It seemed very difficult to drive the Intel IP without having a processor; for example, reference [14] 
includes a sample device driver in C. So, I decided to write an I2C master in Verilog which would have a simple single 
register interface to perform just two operations;  read a byte from a random address in the 
EEPROM, and write a byte to a random address in the EEPROM.

In the absence of a processor, I still needed a way of reading a file of bytes and writing them to the EEPROM and
also reading the bytes in the EEPROM and writing them to a file. Intel provides a rather neat system-console which 
communicates with hardware in the FPGA using the JTAG interface. Furthermore, system-console is a stand-alone application
which can be launched independently of the Quartus GUI. So, this project makes the simple I2C master into a custom IP
component and wires it up to the JTAG interface using the Platform Designer tool in Quartus. Then, one can launch
stand-alone system-console and use TCL commands to write and read to and from the EEPROM. 

In summary, the usefulness of this project is, in my view, that it is a way of editing parameters in FPGA hardware
which does not include a soft-core processor. 
2. Usage
2.1 Compile and program the FPGA hardware
Download the files into a cloned repo on your local PC.
> git clone https://github.com/stebla1954/Verilog-I2C-master.git
This makes a repo ~/Verilog-I2C-master. The next stage is to make a Quartus project. Since Quartus makes lots of
new files, I just copied all the files in the cloned repo to a directory for my Quartus project. The PATH
environmental variable needs to point the Quartus executables. On my system, 
project-dir> export PATH=$PATH:~/intelFPGA_lite/24.1std/quartus/bin
Now make the Quartus project.
project-dir> quartus_sh -t inst_sys_con_to_24XX02.tcl
This makes the Quartus project file and the Quartus settings file which contains the pin planner assignments.
Now launch the Quartus GUI and open the project that has just been created. Open Platform Designer
(Tools-> Platform Designer) and open the file sys_con_I2C_mstr.qsys . The System Contents tab of Platform
Designer will show how Intel JTAG IP is hooked up to the custom IP avln_mm_I2C_mstr which is the I2C master.
Click the "Generate HDL" button. When Platform Designer finishes creating the component, close Platform Designer.
Now compile the design in Quartus (Processing -> Start Compilation). When the design has been compiled there
will be some warnings, but these are nothing to worry about. Now with the DE0-Nano FPGA dev board hooked up
to a USB port on the PC, configure the FPGA with the .sof file (Tools -> Programmer). The Programmer and
Quartus can be closed.
2.2 System Console
The next step is to get system-console to talk to the FPGA hardware over the JTAG port.
Make sure the PATH environmental variable points to the system-console executable. On my system,
> export PATH=$PATH:~/intelFPGA_lite/24.1std/qprogrammer/sopc_builder/bin
Launch system-console.
> system-console
The system-console GUI starts up. There is a panel with a TCL prompt %.
Type the following commands. They are from reference [2]. I will denote a response from system-console
by => response
% set x [lindex [get_service_paths master] 0]
% open_service master $x
% is_service_open
=> 1 means the service is open.
Now let's read a byte from address 0xbc in the 24XX02 memory.
% master_write_8 $x 0x00 [list 0xa1 0xbc 0xee 0x01]
This writes four bytes into the memory-mapped 32-bit register of the I2C master. The register is described
in the documentation of the Verilog module avln_mm_slv_I2C_mstr.v . The 24XX02 slave's address is 0xa1 for a
read command and 0xa0 for a write command. Since we are doing a read operation the first byte is 0xa1. The
next byte is the 24XX02's memory address, which in this example is 0xbc. The third byte is the byte to be
written. Since we are reading from the 24XX02, this byte can be anything. The fourth byte is 0x01 to start
the state machine running in the I2C master. In order to read the byte read from the 24XX02, send the command,
% master_read_8 $x 0x00 4
=> 0xad 0xde 0x27 0x02
This reads the four bytes of the single 32-bit register in the I2C master. The register is described in the
documentation to module avln_mm_slv_I2C_mstr.v . The third byte 0x27 is the data byte. The first two are
meaningless and the fourth byte says the state machine has stopped and the last ACK/NACK bit was a NACK.
This is because the master tells the I2C slave to stop sending bytes by replying to a byte from the slave
with a NACK.
Now let's write a byte 0x34 to memory address 0xbc.
% master_write_8 $x 0x00 [list 0xa0 0xbc 0x34 0x01]
The first byte 0xa0 is the write command. We can check that the byte 0x34 has been written by executing
another read.
% master_write_8 $x 0x00 [list 0xa1 0xbc 0xee 0x01]
% master_read_8 $x 0x00 4
=> 0xad 0xde 0x34 0x02
and the thirs byte 0x34 is the byte read from memory address 0xbc.
The TCL scripts read24XX02.tcl and write24XX02.tcl automate these commands. The TCL script rea24XX02.tcl
reads the bytes in the memory of the 24XX02 and writes them to a file named rd24XX02.hex . Similarly,
TCLscript write24XX02.tcl loads a file named wr24XX02.hex and writes the contents to the memory
of the 24XX02 EEPROM. These scripts are run from the TCL prompt by,
% source read24XX02.tcl
etc.
Having demonstrated reading and writing, we can now close the service,
% close_service master $x
% is_service_open master $x
 => 0
The system-console GUI may now be closed.  
3. References
[1] "Embedded Peripherals IP User Guide", UG-01085, Altera Design Hub.
[2] "System Console User Guide", Altera
