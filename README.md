# Verilog-I2C-master
A Quartus project which allows stand-alone system-console to write to and read from the 24XX02 I2C EEPROM on Terasic's DE0-Nano FPGA development board.

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

References
[1] "Embedded Peripherals IP User Guide", UG-10085, Altera Design Hub.
