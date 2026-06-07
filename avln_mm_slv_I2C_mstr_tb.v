// avln_mm_slv_I2C_mstr_tb.v : testbench to study the operation of module
// avln_mm_slv_I2C_mstr.v which is designed to implement an Avalon-MM slave
// I2C master.
// USEAGE
// > iverilog -o avln_mm_slv_I2C_mstr_tb.vvp avln_mm_slv_I2C_mstr_tb.v
//                                      avln_mm_slv_I2C_mstr.v
// > vvp avln_mm_slv_I2C_mstr_tb.vvp
// gtkwave test.vcd
//
`timescale 1ns/100ps
module avln_mm_slv_I2C_mstr_tb;
   
   initial begin
      $dumpfile("test.vcd");
      $dumpvars(0);
   end

   
   // Initial block for the signals from the Avalon-MM master
   reg reset=1'b0;
   wire [31:0] readdata;
   reg	      read=1'b0;
   reg	      write=1'b0;
   reg [31:0] writedata=32'hXXXXXXXX;
   
   initial begin
      #22;
      reset = 1'b1;//22
      #20;
      reset = 1'b0;//42
      #40;
      write=1'b1;//82 write goes high
      writedata=32'h01BE61A0;
      #20;
      write=1'b0;//102 write goes low
      writedata=32'hXXXXXXXX;
      #800000;
      $finish;     
   end // initial begin

   initial begin
      #310002;
      write=1'b1;//Read transaction
      writedata=32'h0100ABA1;
      #20;
      write=1'b0;
      writedata=32'hXXXXXXXX;
   end
   

   
   // Clock period 20ns, so clk flips every 10ns
   reg clk=1'b1;
   always #10 clk =~clk;

   //These are the I2B bus wires which are weakly pulled up.
   wire EEPROM_scl;
   wire	EEPROM_sda;
   pullup( EEPROM_scl);
   pullup( EEPROM_sda);
   
   avln_mm_slv_I2C_mstr U0(.clk(clk),.reset(reset),.read(read),
			   .readdata(readdata),.write(write),
		       .writedata(writedata),
			   .sda(EEPROM_sda),.scl(EEPROM_scl));

   I2C_slave_sim U1(.sda(EEPROM_sda),.scl(EEPROM_scl));
   
   
endmodule // avln_mm_slv_I2C_mstr_tb

// This is a simulation of an I2C slave which is needed to
// do stuff like pulling down the sda line to signify an ACK.
module I2C_slave_sim(sda,scl);
   inout sda,scl;
   
   wire	 sda,scl;
   wire		 sda_in,scl_in;
   
   assign scl_in = scl;
   assign scl = scl_oe ? 1'b0 : 1'bz;
   
   assign sda_in = sda;
   assign sda = sda_oe ? 1'b0 : 1'bz;

   // Initial block to pull down the SDA wire at the 9th SCL pulse
   // to signify an ACK from the I2C slave. The timing for this was
   // read from the gtkwave plot.
   reg sda_oe,scl_oe;
   initial begin
      sda_oe = 1'b0;
      scl_oe = 1'b0;
      #90000;
      sda_oe = 1'b1;//ACK on command byte for write transaction
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

   initial begin
      #180000;
      sda_oe = 1'b1;//ACK on write transaction address
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

   initial begin
      #273000;
      sda_oe = 1'b1;//ACK on write transaction data
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

   // ACK on the read transaction.
   initial begin
      #400000;
      sda_oe = 1'b1;//ACK on read transaction write command
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

   initial begin
      #492000;
      sda_oe = 1'b1;//ACK on read transaction write address pointer
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

      initial begin
      #598000;
      sda_oe = 1'b1;//ACK on read transaction read command
      #10000;
      sda_oe = 1'b0;//Release ACK      
   end

   
endmodule // I2C_slave_sim

   
