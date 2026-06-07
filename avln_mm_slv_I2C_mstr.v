// avln_mm_slv_I2C_mstr.v : module to try to make a custom
// Platform-Designer component to implement an Avalon-MM slave interface
// hooked up to an I2C master. 
// 1.INTRODUCTION
// The plan is to hook this Avalon-MM slave up 
// to the JTAG (as we did successfully with the custom component
// avln_mm_slv_ram.v) and then wire up the I2C master to the off-chip
// 24xx02 EEPROM on the DE0-Nano board. The overall aim is to be able to
// write and read the 24XX02 EEPROM using system-console. If successful,
// this would be another step on the road to being able to store the
// compensation tables and user-defined reference mark for the MSP hardware
// in the 24XX02 EEPROM and to update this data using system-console.
//
// |<--------- on-chip -------------->|<- off-chip ->|
//   Altera IP            Custom IP        24xx02
//                                         EEPROM
//  ---------------      ------------      ---------
// | JTAG   Avalon |    |Avalon I2C  |    |I2C      |
// |        master |<-->|slave master|<-->|slave    |
// |               |    |            |    |         |
//  ---------------      ------------      ---------
// 2. INTERFACE SPEC
// Here follows the interface spec for the JTAG Avalon-MM master component 
// so that we can see what interface our Avalon-MM slave needs to provide.
//	input		clk_clk;
//	input		clk_reset_reset;
//	output	[31:0]	master_address;
//	input	[31:0]	master_readdata;
//	output		master_read;
//	output		master_write;
//	output	[31:0]	master_writedata;
//	input		master_waitrequest;
//	input		master_readdatavalid;
//	output	[3:0]	master_byteenable;
//	output		master_reset_reset;
// 3. I2C TRANSACTIONS
// We propose to implement two I2C transactions to implement write
// a single byte to a random address and read a single byte from a
// random address.
//
// The first transaction writes the address pointer of the EEPROM
// and then writes the byte.
// |STA|A7|A6|A5|A4|A3|A2|A1|W|ACK| write command 
//     |A7|A6|A5|A4|A3|A2|A1|A0|ACK| write addr to slave
//     |D7|D6|D5|D4|D3|D2|D1|D0|ACK|STP| write byte to slave
//
// The second transaction just writes the address pointer. The master
// then sends START and a read command which causes the EEPROM slave
// to respond with the byte addressed by the address pointer.
// |STA|A7|A6|A5|A4|A3|A2|A1|W|ACK| write command 
//     |A7|A6|A5|A4|A3|A2|A1|A0|ACK| write addr to slave
// |STA|A7|A6|A5|A4|A3|A2|A1|R|ACK| read command
//     |D7|D6|D5|D4|D3|D2|D1|D0|NACK|STP| read byte from slave
//
// All the ACKs in the first transaction are from the slave. If any
// of these is a NACK, then the master issues a STOP. The first two ACKs
// in the second transaction are from the slave and if either of these
// is a NACK, the master issues STOP.
// 4. REGISTERS
// It seems sensible to just have one register to interact with the
// I2C host. In other words, the Avalon-MM slave is just an single register
// so we don't need to decode the address.
//
// The outputs from the I2C state machine could be just wired to the 
// Avalon-MM master readdata signals and read from the Avalon-MM master 
// could be ignored because the state machine outputs only change after 
// posedge(clk). This would implement read from the Avalon-MM master.
//
// On a write from the Avalon-MM master, we could just implement a
// general register with a synchronous load hooked up the the 
// Avalon-MM master's write signal. The general register has a 
// synchronous reset which is used to clear the contents of the 
// register because the data in the register will form inputs to
// the I2C host state machine. The waitrequest signal is not needed.
//
// So, in the case of the I2C master, the Avalon-MM slave interface is
// very simple, nothing like the avln_mm_slv_ram.v custom IP that was
// written as the preceding step to this I2C master.
// ---------------------------------------------------------------------
// |Bit  |                      Description
// |--------------------------------------------------------------------
// |0    |  Read/not_write bit. Writing a 0 defines the write transaction
// |     |  whilst writing a 1 defines the read transaction. We've already
// |     |  said that there are only two transactions.
// |-----|----------------------------------------------------------------
// |7:1  | 7-bit slave address. For the 24XX02 EEPROM this should be
// |     | 7'b1010XXX
// |-----|----------------------------------------------------------------
// |15:8 | 8-bit address to be written into the address pointer of the
// |     | I2C slave.
// |-----|----------------------------------------------------------------
// |23:16| 8-bit data to be written to the I2C slave. The slave stores
// |     | this byte at the address pointed to be the address pointer
// |     | of the I2C slave.
// |-----|----------------------------------------------------------------
// |24   | A 0 keeps the state machine in the idle state, a 1 allows
// |     | the state machine to run.
// |-----|----------------------------------------------------------------
// |25   | Write a 0 to clear the ACK/NACK bit in the read register.
// |-----|----------------------------------------------------------------
// |31:26| Not used.
// |----------------------------------------------------------------------
// On a read, the register appears as follows.
// ---------------------------------------------------------------------
// |Bit  |                      Description
// |--------------------------------------------------------------------
// |15:0 | Not used.
// |-----|----------------------------------------------------------------
// |23:16| 8-bit data read from the I2C slave. 
// |-----|----------------------------------------------------------------
// |24   | A 0 means the state machine is in the idle state, a 1 means
// |     | the state machine is running.
// |----------------------------------------------------------------------
// |25   | The last ACK/NACK seen by the state machine. A 1 means NACK,
// |     | and a 0 means ACK. If the state machine sees a NACK from the
// |     | slave, the I2C master sends a STOP which terminates the 
// |     | transaction. So, the Avalon-MM master can read this bit
// |     | to check that the transaction worked. If, upon reading
// |     | bit 25, the result is a 0, it means the previous transaction
// |     | worked.
// |-----|----------------------------------------------------------------
// |31:26| Not used.
// |----------------------------------------------------------------------
//
// 
// References
// [1] "Embedded Peripherals IP User Guide", Altera.
// [2] https://www.analog.com/en/resources/technical-articles/
//                            i2c-primer-what-is-i2c-part-1.html
// [3] "I2C-bus specification and user manual", UM10204, Rev7.0 -
//     1 October 2021, NXP Semiconductors.
// [4] "Notes on the I2C comms protocol", 17th May 2026, Works Vol. XLIV.
// [5] "Verilog Digital System Design", Zainalabedin Navabi, 
//     Second Edition, McGraw-Hill, 2006.
//
`timescale 1ns/100ps
module avln_mm_slv_I2C_mstr(clk,reset,read,readdata,write,writedata,sda,scl);
   input clk,reset;
   input       read,write;
   output [31:0] readdata;
   input [31:0]	 writedata;
   inout	 sda,scl;// I2C bus wires

   wire		 clk,reset;
   wire		 read,write;
   wire [31:0]	 readdata;
   wire [31:0]	 writedata;
   wire		 sda,scl;

   // Write the command register
   wire [31:0] cmd;
   general_register cmdreg(.clk(clk),.sync_rst(reset),.sync_ld(write),
		       .data_in(writedata),.data_out(cmd));
   defparam cmdreg.W=32;//Width of the register

   // The output=g(state) of the high-level state m/c has to
   // connect various bits of the command register (e.g. slave address
   // bits, memory address bits, bits of the byte to be written to 
   // memory) to the tx_bit input of the low-level state m/c. Since
   // both state machines are Moore machines (because their outputs
   // are synchronous) we must not have output=g(state,input) so the
   // input (bits of the command register) cannot appear in the
   // sensitivity list of the combinatorial always block used for
   // output=g(state). The fix is to have the sel input of the
   // 26-to-1 mux as an output of the high-level state m/c.
   wire [25:0] bit_array;
   assign bit_array = {2'b10,cmd[23:0]};
   wire tx_bit;
   mux_26_to_1 tx_bit_mux(.bit_array(bit_array),.sel(tx_bit_sel),.y(tx_bit));

   wire [2:0] bit_level_cmd;
   assign bit_level_cmd = {tx_bit,bit_type};   
   
   wire done,rx_bit;
   bit_level_state_mc blsmc(.clk(clk),.reset(reset),
			    .cmd_in(bit_level_cmd),
			    .ld_cmd(ld_bit_level_cmd),
			    .rx_bit(rx_bit),.pulsed_done(done),
			    .sda(sda),.scl(scl));
   
   wire [7:0] rx_byte;
   shift_left_reg slr(.clk(clk),.rst(reset),.sl(sl),.d(rx_bit),.q(rx_byte));
   defparam slr.W=8;//Width of register
   
   assign readdata = {6'b000000,ack_bit,running,rx_byte,16'hdead};

   // The state machine is started by cmd[24]. The problem is,
   // the Avalon-MM master writes the command word so that 
   // cmd[24]=1'b1, but this bit is persistent and so the state
   // machine completes a cycle and restarts. To prevent this,
   // the bit cmd[24] needs to be non-persistent. The following
   // code delays the Avalon-MM master's write signal by one clk
   // cycle so that it is synchronized with changes in the command
   // register cmd. Then the start bit cmd[24] is ANDed with the
   // delayed write to produce a non-persistent start bit.
   reg delayed_write;
   wire	startbit;
   always @(posedge clk) begin
      delayed_write <= write;
   end
   assign startbit = delayed_write & cmd[24];

   // Some useful defines for the I2C bus timing.
   // These defines are the 2-bit select values that
   // are uses to select the 8-bit timing delays that
   // get synchronously loaded in to I2C_timer module.
   // These defines have to be tied up with the sel
   // input of module select_delay.
   `define t_SU_DAT 3'b000
   `define t_HIGH_BY_2 3'b001
   `define t_HD_DAT 3'b010
   `define t_SU_STA 3'b011
   `define t_HD_STA 3'b100
   `define t_SU_STO 3'b101
   `define t_BUF 3'b110

   // Some usefule defines for the bit types used in the
   // low-level state m/c.
   `define STA 2'b00
   `define rSTA 2'b01
   `define STO 2'b10
   `define DAT 2'b11

   // Some useful defines for bits in the command reg
   // used in the output of the high-level state m/c
   // and the 26-to-1 mux.
   `define sel_SA7 5'd7
   `define sel_SA6 5'd6
   `define sel_SA5 5'd5
   `define sel_SA4 5'd4
   `define sel_SA3 5'd3
   `define sel_SA2 5'd2
   `define sel_SA1 5'd1
   `define sel_RnW 5'd0
   `define sel_A7 5'd15
   `define sel_A6 5'd14
   `define sel_A5 5'd13
   `define sel_A4 5'd12
   `define sel_A3 5'd11
   `define sel_A2 5'd10
   `define sel_A1 5'd9
   `define sel_A0 5'd8
   `define sel_D7 5'd23
   `define sel_D6 5'd22
   `define sel_D5 5'd21
   `define sel_D4 5'd20
   `define sel_D3 5'd19
   `define sel_D2 5'd18
   `define sel_D1 5'd17
   `define sel_D0 5'd16
   `define sel_LO 5'd24
   `define sel_HI 5'd25

   //Mnemonics for bits in the command register
   `define RnW cmd[0]
   
   // I2C host state machine
   localparam
	     m0_idle=8'd0,
	     m1_STA=8'd1,
	     m2_STA_wait=8'd2,
	     m3_SA7=8'd3,
	     m4_SA7_wait=8'd4,
	     m5_SA6=8'd5,
	     m6_SA6_wait=8'd6,
	     m7_SA5=8'd7,
	     m8_SA5_wait=8'd8,
	     m9_SA4=8'd9,
	     m10_SA4_wait=8'd10,
	     m11_SA3=8'd11,
	     m12_SA3_wait=8'd12,
	     m13_SA2=8'd13,
	     m14_SA2_wait=8'd14,
	     m15_SA1=8'd15,
	     m16_SA1_wait=8'd16,
	     m17_nW=8'd17,
	     m18_nW_wait=8'd18,
	     m19_ACK=8'd19,
	     m20_ACK_wait=8'd20,
	     m21_ACK_check=8'd21,
	     m22_STO=8'd22,
	     m23_STO_wait=8'd23,
	     m24_A7=8'd24,
	     m25_A7_wait=8'd25,
	     m26_A6=8'd26,
	     m27_A6_wait=8'd27,
	     m28_A5=8'd28,
	     m29_A5_wait=8'd29,
	     m30_A4=8'd30,
	     m31_A4_wait=8'd31,
	     m32_A3=8'd32,
	     m33_A3_wait=8'd33,
	     m34_A2=8'd34,
	     m35_A2_wait=8'd35,
	     m36_A1=8'd36,
	     m37_A1_wait=8'd37,
	     m38_A0=8'd38,
	     m39_A0_wait=8'd39,
	     m40_ACK=8'd40,
	     m41_ACK_wait=8'd41,
	     m42_ACK_check=8'd42,
	     m43_D7=8'd43,
	     m44_D7_wait=8'd44,
	     m45_D6=8'd45,
	     m46_D6_wait=8'd46,
	     m47_D5=8'd47,
	     m48_D5_wait=8'd48,
	     m49_D4=8'd49,
	     m50_D4_wait=8'd50,
	     m51_D3=8'd51,
	     m52_D3_wait=8'd52,
	     m53_D2=8'd53,
	     m54_D2_wait=8'd54,
	     m55_D1=8'd55,
	     m56_D1_wait=8'd56,
	     m57_D0=8'd57,
	     m58_D0_wait=8'd58,
	     m59_ACK=8'd59,
	     m60_ACK_wait=8'd60,
	     m61_ACK_check=8'd61,
	     m62_STA=8'd62,
	     m63_STA_wait=8'd63,
	     m64_SA7=8'd64,
	     m65_SA7_wait=8'd65,
	     m66_SA6=8'd66,
	     m67_SA6_wait=8'd67,
	     m68_SA5=8'd68,
	     m69_SA5_wait=8'd69,
	     m70_SA4=8'd70,
	     m71_SA4_wait=8'd71,
	     m72_SA3=8'd72,
	     m73_SA3_wait=8'd73,
	     m74_SA2=8'd74,
	     m75_SA2_wait=8'd75,
	     m76_SA1=8'd76,
	     m77_SA1_wait=8'd77,
	     m78_nW=8'd78,
	     m79_nW_wait=8'd79,
	     m80_ACK=8'd80,
	     m81_ACK_wait=8'd81,
	     m82_ACK_check=8'd82,
	     m83_A7=8'd83,
	     m84_A7_wait=8'd84,
	     m85_A6=8'd85,
	     m86_A6_wait=8'd86,
	     m87_A5=8'd87,
	     m88_A5_wait=8'd88,
	     m89_A4=8'd89,
	     m90_A4_wait=8'd90,
	     m91_A3=8'd91,
	     m92_A3_wait=8'd92,
	     m93_A2=8'd93,
	     m94_A2_wait=8'd94,
	     m95_A1=8'd95,
	     m96_A1_wait=8'd96,
	     m97_A0=8'd97,
	     m98_A0_wait=8'd98,
	     m99_ACK=8'd99,
	     m100_ACK_wait=8'd100,
	     m101_ACK_check=8'd101,
	     m102_rSTA=8'd102,
	     m103_rSTA_wait=8'd103,
	     m104_SA7=8'd104,
	     m105_SA7_wait=8'd105,
	     m106_SA6=8'd106,
	     m107_SA6_wait=8'd107,
	     m108_SA5=8'd108,
	     m109_SA5_wait=8'd109,
	     m110_SA4=8'd110,
	     m111_SA4_wait=8'd111,
	     m112_SA3=8'd112,
	     m113_SA3_wait=8'd113,
	     m114_SA2=8'd114,
	     m115_SA2_wait=8'd115,
	     m116_SA1=8'd116,
	     m117_SA1_wait=8'd117,
	     m118_R=8'd118,
	     m119_R_wait=8'd119,
	     m120_ACK=8'd120,
	     m121_ACK_wait=8'd121,
	     m122_ACK_check=8'd122,
	     m123_D7=8'd123,
	     m124_D7_wait=8'd124,
	     m125_D6=8'd125,
	     m126_D6_wait=8'd126,
	     m127_D5=8'd127,
	     m128_D5_wait=8'd128,
	     m129_D4=8'd129,
	     m130_D4_wait=8'd130,
	     m131_D3=8'd131,
	     m132_D3_wait=8'd132,
	     m133_D2=8'd133,
	     m134_D2_wait=8'd134,
	     m135_D1=8'd135,
	     m136_D1_wait=8'd136,
	     m137_D0=8'd137,
	     m138_D0_wait=8'd138,
	     m139_ACK=8'd139,
	     m140_ACK_wait=8'd140,
	     m141_ACK_check=8'd141;
            
   reg [7:0] state,next_state;

   // This is the sequential block of the state machine
   always @(posedge clk) begin
      if (reset) begin
	 state <= m0_idle;
      end
      else begin
	 state <= next_state;
      end
   end

   // Combinatorial block of the state machine implementing
   // next_state = f(state, input)
   always @(state,cmd,startbit,done,rx_bit) begin
      case (state)
	m0_idle: begin
	   if (startbit) begin
	      if (`RnW) begin
		 next_state = m62_STA;//Send STA for read transaction
	      end
	      else begin
		 next_state = m1_STA;//Send STA for write transaction
	      end
	   end
	   else begin
	      next_state = m0_idle;
	   end
	end // case: m0_idle
	m1_STA: begin
	   next_state = m2_STA_wait;	   
	end
	m2_STA_wait: begin
	   if (done) begin
	      next_state = m3_SA7;//Send slave address
	   end
	   else begin
	      next_state = m2_STA_wait;
	   end
	end
	m3_SA7: begin
	   next_state = m4_SA7_wait;
	end
	m4_SA7_wait: begin
	   if (done) begin
	      next_state = m5_SA6;
	   end
	   else begin
	      next_state = m4_SA7_wait;
	   end
	end
	m5_SA6: begin
	   next_state = m6_SA6_wait;
	end
	m6_SA6_wait: begin
	   if (done) begin
	      next_state = m7_SA5;
	   end
	   else begin
	      next_state = m6_SA6_wait;
	   end
	end
	m7_SA5: begin
	   next_state = m8_SA5_wait;
	end
	m8_SA5_wait: begin
	   if (done) begin
	      next_state = m9_SA4;
	   end
	   else begin
	      next_state = m8_SA5_wait;
	   end
	end
	m9_SA4: begin
	   next_state = m10_SA4_wait;
	end
	m10_SA4_wait: begin
	   if (done) begin
	      next_state = m11_SA3;
	   end
	   else begin
	      next_state = m10_SA4_wait;
	   end
	end
	m11_SA3: begin
	   next_state = m12_SA3_wait;
	end
	m12_SA3_wait: begin
	   if (done) begin
	      next_state = m13_SA2;
	   end
	   else begin
	      next_state = m12_SA3_wait;
	   end
	end
	m13_SA2: begin
	   next_state = m14_SA2_wait;
	end
	m14_SA2_wait: begin
	   if (done) begin
	      next_state = m15_SA1;
	   end
	   else begin
	      next_state = m14_SA2_wait;
	   end
	end
	m15_SA1: begin
	   next_state = m16_SA1_wait;
	end
	m16_SA1_wait: begin
	   if (done) begin
	      next_state = m17_nW;
	   end
	   else begin
	      next_state = m16_SA1_wait;
	   end
	end
	m17_nW: begin
	   next_state = m18_nW_wait;
	end
	m18_nW_wait: begin
	   if (done) begin
	      next_state = m19_ACK;
	   end
	   else begin
	      next_state = m18_nW_wait;
	   end
	end
	m19_ACK: begin
	   next_state = m20_ACK_wait;
	end
	m20_ACK_wait: begin
	   if (done) begin
	      next_state = m21_ACK_check;
	   end
	   else begin
	      next_state = m20_ACK_wait;
	   end
	end
	m21_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m24_A7;// ACK received, send Address
	   end
	end
	m22_STO: begin
	   next_state = m23_STO_wait;
	end
	m23_STO_wait: begin
	   if (done) begin
	      next_state = m0_idle;
	   end
	   else begin
	      next_state = m23_STO_wait;
	   end
	end
	m24_A7: begin
	   next_state = m25_A7_wait;
	end
	m25_A7_wait: begin
	   if (done) begin
	      next_state = m26_A6;
	   end
	   else begin
	      next_state = m25_A7_wait;
	   end
	end
	m26_A6: begin
	   next_state = m27_A6_wait;
	end
	m27_A6_wait: begin
	   if (done) begin
	      next_state = m28_A5;
	   end
	   else begin
	      next_state = m27_A6_wait;
	   end
	end
	m28_A5: begin
	   next_state = m29_A5_wait;
	end
	m29_A5_wait: begin
	   if (done) begin
	      next_state = m30_A4;
	   end
	   else begin
	      next_state = m29_A5_wait;
	   end
	end
	m30_A4: begin
	   next_state = m31_A4_wait;
	end
	m31_A4_wait: begin
	   if (done) begin
	      next_state = m32_A3;
	   end
	   else begin
	      next_state = m31_A4_wait;
	   end
	end
	m32_A3: begin
	   next_state = m33_A3_wait;
	end
	m33_A3_wait: begin
	   if (done) begin
	      next_state = m34_A2;
	   end
	   else begin
	      next_state = m33_A3_wait;
	   end
	end
	m34_A2: begin
	   next_state = m35_A2_wait;
	end
	m35_A2_wait: begin
	   if (done) begin
	      next_state = m36_A1;
	   end
	   else begin
	      next_state = m35_A2_wait;
	   end
	end
	m36_A1: begin
	   next_state = m37_A1_wait;
	end
	m37_A1_wait: begin
	   if (done) begin
	      next_state = m38_A0;
	   end
	   else begin
	      next_state = m37_A1_wait;
	   end
	end
	m38_A0: begin
	   next_state = m39_A0_wait;
	end
	m39_A0_wait: begin
	   if (done) begin
	      next_state = m40_ACK;
	   end
	   else begin
	      next_state = m39_A0_wait;
	   end
	end
	m40_ACK: begin
	   next_state = m41_ACK_wait;
	end
	m41_ACK_wait: begin
	   if (done) begin
	      next_state = m42_ACK_check;
	   end
	   else begin
	      next_state = m41_ACK_wait;
	   end
	end
	m42_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m43_D7;// ACK received, send Data
	   end
	end
	m43_D7: begin
	   next_state = m44_D7_wait;
	end
	m44_D7_wait: begin
	   if (done) begin
	      next_state = m45_D6;
	   end
	   else begin
	      next_state = m44_D7_wait;
	   end
	end
	m45_D6: begin
	   next_state = m46_D6_wait;
	end
	m46_D6_wait: begin
	   if (done) begin
	      next_state = m47_D5;
	   end
	   else begin
	      next_state = m46_D6_wait;
	   end
	end
	m47_D5: begin
	   next_state = m48_D5_wait;
	end
	m48_D5_wait: begin
	   if (done) begin
	      next_state = m49_D4;
	   end
	   else begin
	      next_state = m48_D5_wait;
	   end
	end
	m49_D4: begin
	   next_state = m50_D4_wait;
	end
	m50_D4_wait: begin
	   if (done) begin
	      next_state = m51_D3;
	   end
	   else begin
	      next_state = m50_D4_wait;
	   end
	end
	m51_D3: begin
	   next_state = m52_D3_wait;
	end
	m52_D3_wait: begin
	   if (done) begin
	      next_state = m53_D2;
	   end
	   else begin
	      next_state = m52_D3_wait;
	   end
	end
	m53_D2: begin
	   next_state = m54_D2_wait;
	end
	m54_D2_wait: begin
	   if (done) begin
	      next_state = m55_D1;
	   end
	   else begin
	      next_state = m54_D2_wait;
	   end
	end
	m55_D1: begin
	   next_state = m56_D1_wait;
	end
	m56_D1_wait: begin
	   if (done) begin
	      next_state = m57_D0;
	   end
	   else begin
	      next_state = m56_D1_wait;
	   end
	end
	m57_D0: begin
	   next_state = m58_D0_wait;
	end
	m58_D0_wait: begin
	   if (done) begin
	      next_state = m59_ACK;
	   end
	   else begin
	      next_state = m58_D0_wait;
	   end
	end
	m59_ACK: begin
	   next_state = m60_ACK_wait;
	end
	m60_ACK_wait: begin
	   if (done) begin
	      next_state = m61_ACK_check;
	   end
	   else begin
	      next_state = m60_ACK_wait;
	   end
	end
	m61_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m22_STO;// ACK received, transaction over, send STOP
	   end
	end
	m62_STA: begin
	   next_state = m63_STA_wait;	   
	end
	m63_STA_wait: begin
	   if (done) begin
	      next_state = m64_SA7;//Send slave address
	   end
	   else begin
	      next_state = m63_STA_wait;
	   end
	end
	m64_SA7: begin
	   next_state = m65_SA7_wait;
	end
	m65_SA7_wait: begin
	   if (done) begin
	      next_state = m66_SA6;
	   end
	   else begin
	      next_state = m65_SA7_wait;
	   end
	end
	m66_SA6: begin
	   next_state = m67_SA6_wait;
	end
	m67_SA6_wait: begin
	   if (done) begin
	      next_state = m68_SA5;
	   end
	   else begin
	      next_state = m67_SA6_wait;
	   end
	end
	m68_SA5: begin
	   next_state = m69_SA5_wait;
	end
	m69_SA5_wait: begin
	   if (done) begin
	      next_state = m70_SA4;
	   end
	   else begin
	      next_state = m69_SA5_wait;
	   end
	end
	m70_SA4: begin
	   next_state = m71_SA4_wait;
	end
	m71_SA4_wait: begin
	   if (done) begin
	      next_state = m72_SA3;
	   end
	   else begin
	      next_state = m71_SA4_wait;
	   end
	end
	m72_SA3: begin
	   next_state = m73_SA3_wait;
	end
	m73_SA3_wait: begin
	   if (done) begin
	      next_state = m74_SA2;
	   end
	   else begin
	      next_state = m73_SA3_wait;
	   end
	end
	m74_SA2: begin
	   next_state = m75_SA2_wait;
	end
	m75_SA2_wait: begin
	   if (done) begin
	      next_state = m76_SA1;
	   end
	   else begin
	      next_state = m75_SA2_wait;
	   end
	end
	m76_SA1: begin
	   next_state = m77_SA1_wait;
	end
	m77_SA1_wait: begin
	   if (done) begin
	      next_state = m78_nW;
	   end
	   else begin
	      next_state = m77_SA1_wait;
	   end
	end
	m78_nW: begin
	   next_state = m79_nW_wait;
	end
	m79_nW_wait: begin
	   if (done) begin
	      next_state = m80_ACK;
	   end
	   else begin
	      next_state = m79_nW_wait;
	   end
	end
	m80_ACK: begin
	   next_state = m81_ACK_wait;
	end
	m81_ACK_wait: begin
	   if (done) begin
	      next_state = m82_ACK_check;
	   end
	   else begin
	      next_state = m81_ACK_wait;
	   end
	end
	m82_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m83_A7;// ACK received, send Address
	   end
	end
	m83_A7: begin
	   next_state = m84_A7_wait;
	end
	m84_A7_wait: begin
	   if (done) begin
	      next_state = m85_A6;
	   end
	   else begin
	      next_state = m84_A7_wait;
	   end
	end
	m85_A6: begin
	   next_state = m86_A6_wait;
	end
	m86_A6_wait: begin
	   if (done) begin
	      next_state = m87_A5;
	   end
	   else begin
	      next_state = m86_A6_wait;
	   end
	end
	m87_A5: begin
	   next_state = m88_A5_wait;
	end
	m88_A5_wait: begin
	   if (done) begin
	      next_state = m89_A4;
	   end
	   else begin
	      next_state = m88_A5_wait;
	   end
	end
	m89_A4: begin
	   next_state = m90_A4_wait;
	end
	m90_A4_wait: begin
	   if (done) begin
	      next_state = m91_A3;
	   end
	   else begin
	      next_state = m90_A4_wait;
	   end
	end
	m91_A3: begin
	   next_state = m92_A3_wait;
	end
	m92_A3_wait: begin
	   if (done) begin
	      next_state = m93_A2;
	   end
	   else begin
	      next_state = m92_A3_wait;
	   end
	end
	m93_A2: begin
	   next_state = m94_A2_wait;
	end
	m94_A2_wait: begin
	   if (done) begin
	      next_state = m95_A1;
	   end
	   else begin
	      next_state = m94_A2_wait;
	   end
	end
	m95_A1: begin
	   next_state = m96_A1_wait;
	end
	m96_A1_wait: begin
	   if (done) begin
	      next_state = m97_A0;
	   end
	   else begin
	      next_state = m96_A1_wait;
	   end
	end
	m97_A0: begin
	   next_state = m98_A0_wait;
	end
	m98_A0_wait: begin
	   if (done) begin
	      next_state = m99_ACK;
	   end
	   else begin
	      next_state = m98_A0_wait;
	   end
	end
	m99_ACK: begin
	   next_state = m100_ACK_wait;
	end
	m100_ACK_wait: begin
	   if (done) begin
	      next_state = m101_ACK_check;
	   end
	   else begin
	      next_state = m100_ACK_wait;
	   end
	end
	m101_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m102_rSTA;// ACK received, send rSTA
	   end
	end
	m102_rSTA: begin
	   next_state = m103_rSTA_wait;
	end
	m103_rSTA_wait: begin
	   if (done) begin
	      next_state = m104_SA7;//Send slave address
	   end
	   else begin
	      next_state = m103_rSTA_wait;
	   end
	end
	m104_SA7: begin
	   next_state = m105_SA7_wait;
	end
	m105_SA7_wait: begin
	   if (done) begin
	      next_state = m106_SA6;
	   end
	   else begin
	      next_state = m105_SA7_wait;
	   end
	end
	m106_SA6: begin
	   next_state = m107_SA6_wait;
	end
	m107_SA6_wait: begin
	   if (done) begin
	      next_state = m108_SA5;
	   end
	   else begin
	      next_state = m107_SA6_wait;
	   end
	end
	m108_SA5: begin
	   next_state = m109_SA5_wait;
	end
	m109_SA5_wait: begin
	   if (done) begin
	      next_state = m110_SA4;
	   end
	   else begin
	      next_state = m109_SA5_wait;
	   end
	end
	m110_SA4: begin
	   next_state = m111_SA4_wait;
	end
	m111_SA4_wait: begin
	   if (done) begin
	      next_state = m112_SA3;
	   end
	   else begin
	      next_state = m111_SA4_wait;
	   end
	end
	m112_SA3: begin
	   next_state = m113_SA3_wait;
	end
	m113_SA3_wait: begin
	   if (done) begin
	      next_state = m114_SA2;
	   end
	   else begin
	      next_state = m113_SA3_wait;
	   end
	end
	m114_SA2: begin
	   next_state = m115_SA2_wait;
	end
	m115_SA2_wait: begin
	   if (done) begin
	      next_state = m116_SA1;
	   end
	   else begin
	      next_state = m115_SA2_wait;
	   end
	end
	m116_SA1: begin
	   next_state = m117_SA1_wait;
	end
	m117_SA1_wait: begin
	   if (done) begin
	      next_state = m118_R;
	   end
	   else begin
	      next_state = m117_SA1_wait;
	   end
	end
	m118_R: begin
	   next_state = m119_R_wait;
	end
	m119_R_wait: begin
	   if (done) begin
	      next_state = m120_ACK;
	   end
	   else begin
	      next_state = m119_R_wait;
	   end
	end
	m120_ACK: begin
	   next_state = m121_ACK_wait;
	end
	m121_ACK_wait: begin
	   if (done) begin
	      next_state = m122_ACK_check;
	   end
	   else begin
	      next_state = m121_ACK_wait;
	   end
	end
	m122_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m123_D7;// ACK received, read data
	   end
	end
	m123_D7: begin
	   next_state = m124_D7_wait;
	end
	m124_D7_wait: begin
	   if (done) begin
	      next_state = m125_D6;
	   end
	   else begin
	      next_state = m124_D7_wait;
	   end
	end
	m125_D6: begin
	   next_state = m126_D6_wait;
	end
	m126_D6_wait: begin
	   if (done) begin
	      next_state = m127_D5;
	   end
	   else begin
	      next_state = m126_D6_wait;
	   end
	end
	m127_D5: begin
	   next_state = m128_D5_wait;
	end
	m128_D5_wait: begin
	   if (done) begin
	      next_state = m129_D4;
	   end
	   else begin
	      next_state = m128_D5_wait;
	   end
	end
	m129_D4: begin
	   next_state = m130_D4_wait;
	end
	m130_D4_wait: begin
	   if (done) begin
	      next_state = m131_D3;
	   end
	   else begin
	      next_state = m130_D4_wait;
	   end
	end
	m131_D3: begin
	   next_state = m132_D3_wait;
	end
	m132_D3_wait: begin
	   if (done) begin
	      next_state = m133_D2;
	   end
	   else begin
	      next_state = m132_D3_wait;
	   end
	end
	m133_D2: begin
	   next_state = m134_D2_wait;
	end
	m134_D2_wait: begin
	   if (done) begin
	      next_state = m135_D1;
	   end
	   else begin
	      next_state = m134_D2_wait;
	   end
	end
	m135_D1: begin
	   next_state = m136_D1_wait;
	end
	m136_D1_wait: begin
	   if (done) begin
	      next_state = m137_D0;
	   end
	   else begin
	      next_state = m136_D1_wait;
	   end
	end
	m137_D0: begin
	   next_state = m138_D0_wait;
	end
	m138_D0_wait: begin
	   if (done) begin
	      next_state = m139_ACK;
	   end
	   else begin
	      next_state = m138_D0_wait;
	   end
	end
	m139_ACK: begin
	   next_state = m140_ACK_wait;
	end
	m140_ACK_wait: begin
	   if (done) begin
	      next_state = m141_ACK_check;
	   end
	   else begin
	      next_state = m140_ACK_wait;
	   end
	end
	m141_ACK_check: begin
	   if (rx_bit) begin
	      next_state = m22_STO;// NACK received, send STOP
	   end
	   else begin
	      next_state=m22_STO;// ACK received, transaction over, send STOP
	   end
	end
	default: begin
	   next_state = m0_idle;
	end
      endcase // case (state)
   end // always @ (state,cmd,startbit,done,rx_bit)
   
   // Combinatorial block implementing output=g(state)
   reg [1:0] bit_type;
   reg [4:0] tx_bit_sel;//Selects a bit of the command register
   reg	     ld_bit_level_cmd;
   reg	     sl;//shift left to put each rx_bit into shift reg. 
   
   always @(state) begin
      case (state)
	m0_idle: begin
	   bit_type = `STA;//Not used until ld_bit_level_cmd=1'b1
	   tx_bit_sel = `sel_HI;//The tx_bit is only needed for a DAT bit
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m1_STA: begin
	   bit_type = `STA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m2_STA_wait: begin
	   bit_type = `STA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m3_SA7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m4_SA7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m5_SA6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m6_SA6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m7_SA5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m8_SA5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m9_SA4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m10_SA4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m11_SA3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m12_SA3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m13_SA2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m14_SA2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m15_SA1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m16_SA1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m17_nW: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_RnW;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m18_nW_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_RnW;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m19_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m20_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m21_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m22_STO: begin
	   bit_type = `STO;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m23_STO_wait: begin
	   bit_type = `STO;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m24_A7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m25_A7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m26_A6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m27_A6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m28_A5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m29_A5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m30_A4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m31_A4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m32_A3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m33_A3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m34_A2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m35_A2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m36_A1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m37_A1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m38_A0: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A0;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m39_A0_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A0;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m40_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m41_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m42_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m43_D7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m44_D7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m45_D6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m46_D6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m47_D5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m48_D5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m49_D4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m50_D4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m51_D3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m52_D3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m53_D2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m54_D2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m55_D1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m56_D1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m57_D0: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D0;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m58_D0_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_D0;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m59_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m60_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m61_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m62_STA: begin
	   bit_type = `STA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m63_STA_wait: begin
	   bit_type = `STA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m64_SA7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m65_SA7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m66_SA6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m67_SA6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m68_SA5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m69_SA5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m70_SA4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m71_SA4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m72_SA3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m73_SA3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m74_SA2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m75_SA2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m76_SA1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m77_SA1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	// This output is a little tricky. The bit RnW=1 in the
	// command register in order to cause the I2C master to 
	// perform a read transaction. However, the read is from
	// a random address in 24XX02 memory, so we have to set
	// the 24XX02's address pointer. So, this command byte
	// is a write with bit 0 of the command, the RnW=0 bit,
	// set to 0. So, although the RnW bit in the command 
	// register is 1 to cause a read transaction, at this
	// stage of the transaction we are doing a write to set
	// the 24XX02's address pointer.
	m78_nW: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_LO;//See essay above!
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m79_nW_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_LO;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m80_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m81_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m82_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m83_A7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m84_A7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m85_A6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m86_A6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m87_A5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m88_A5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m89_A4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m90_A4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m91_A3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m92_A3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m93_A2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m94_A2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m95_A1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m96_A1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m97_A0: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A0;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m98_A0_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_A0;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m99_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m100_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m101_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m102_rSTA: begin
	   bit_type = `rSTA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m103_rSTA_wait: begin
	   bit_type = `rSTA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m104_SA7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m105_SA7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA7;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m106_SA6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m107_SA6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA6;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m108_SA5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m109_SA5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA5;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m110_SA4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m111_SA4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA4;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m112_SA3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m113_SA3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA3;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m114_SA2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m115_SA2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA2;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m116_SA1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m117_SA1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_SA1;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m118_R: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_RnW;//This is a read, the bit RnW=1
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m119_R_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_RnW;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m120_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire so slave can ACK
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m121_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m122_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m123_D7: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b0;
	end
	m124_D7_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m125_D6: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={7'b0,D7}
	end
	m126_D6_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m127_D5: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={6'b0,D7,D6}
	end
	m128_D5_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m129_D4: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={5'b0,D7,D6,D5}
	end
	m130_D4_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m131_D3: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={4'b0,D7,D6,D5,D4}
	end
	m132_D3_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m133_D2: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={3'b0,D7,D6,D5,D4,D3}
	end
	m134_D2_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m135_D1: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={2'b0,D7,D6,D5,D4,D3,D2}
	end
	m136_D1_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m137_D0: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={1'b0,D7,D6,D5,D4,D3,D2,D1}
	end
	m138_D0_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m139_ACK: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;//Release SDA bus wire (master sends NACK)
	   ld_bit_level_cmd = 1'b1;
	   sl = 1'b1;//shift reg q={D7,D6,D5,D4,D3,D2,D1,D0}
	end
	m140_ACK_wait: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	m141_ACK_check: begin
	   bit_type = `DAT;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
	default: begin
	   bit_type = `STA;
	   tx_bit_sel = `sel_HI;
	   ld_bit_level_cmd = 1'b0;
	   sl = 1'b0;
	end
      endcase // case (state)
   end // always @ (state) (Moore m/c)

   // Combinatorial output=g(state) implemented with assign.
   wire running;
   assign running = (state == m0_idle) ? 1'b0 : 1'b1;

   // We return the last ACK received in a transaction. 
   wire ld_ack_bit;//Output signal to gate clk to load ACK.
   assign ld_ack_bit = (state == m22_STO) ? 1'b1 : 1'b0;

   // 1-bit register to store the DAT bit.
   wire [0:0] ack_bit;
   general_register ack_bit_reg(.clk(clk),.sync_rst(reset),
				 .sync_ld(ld_ack_bit),
				 .data_in(rx_bit),.data_out(ack_bit));
   defparam ack_bit_reg.W=1;//Width of the register


endmodule // avln_mm_slv_I2C_mstr


// This module comes from lin_interp.v 
module general_register(clk,sync_rst,sync_ld,data_in,data_out);
   parameter W=28;//Width of the register

   input clk,sync_rst,sync_ld;
   input [(W-1):0] data_in;
   output [(W-1):0] data_out;
   wire	clk,sync_rst,sync_ld;
   wire [(W-1):0] data_in;
   reg [(W-1):0]  data_out;
   
   // The register has been rewritten with a separate combinatorial block 
   // and a sequential clock along the lines of the shifter described 
   // in section 5.3.1.3 on page 160 of Navabi [1]. This is good Verilog
   // style.
   
   //Sequential block of the register
   always @(posedge clk) begin
      if (sync_rst) begin
	 data_out <= {W{1'b0}};
      end
      else begin
	 data_out <= next_data_out;
      end
   end

   //Combinatorial block for the register
   reg [(W-1):0] next_data_out;
   always @(data_in,data_out,sync_ld) begin
      if (sync_ld) begin
	 next_data_out = data_in;
      end
      else begin
	 next_data_out = data_out;
      end
   end

endmodule // general_register
   

// This is a hack of down_counter from lin_interp.v .
// It is intended to time the transitions on the I2C
// bus. The I2C state machine enters a state, changes
// the I2C bus signals scl or sda and loads a suitable
// delay for the transition to the next state. The
// state machine then waits for the alarm to go off
// before transitioning to the next state. The delays
// could be given meaningful mnemonics like,
// `define t_HD_STA 8'd200
// for the hold time that sda=1'b0 before scl goes low.
// The clk input is the 50MHz clock with a period of 20ns.
// The I2C spec says t_HD:STA > 4000ns which is 4000/20
// = 200 clk cycles. 
module alarm_clock(clk,sync_ld,delay,alarm);
   parameter
	    W=8;//No. of bits needed for the counter
   
   input clk,sync_ld;
   input [(W-1):0] delay;
   output	   alarm;
   wire		   clk,sync_ld,alarm;
   wire [(W-1):0] delay;

   reg [(W-1):0] k; // counter

   // The counter has been rewritten with a separate combinatorial block 
   // and a sequential clock along the lines of the shifter described 
   // in section 5.3.1.3 on page 160 of Navabi [1]. This is good Verilog
   // style.  

   // Sequential block of the counter
   // A synchrous reset is not needed because the counter always
   // counts down to zero and stay there.
   always @(posedge clk) begin
      k <= next_k;
   end
   
   //Combinatorial block for the counter
   reg [(W-1):0] next_k;
   always @(k,sync_ld,delay) begin
      if (sync_ld) begin
	 next_k = delay;//Synchronous load
      end
      else begin
	 if (k==0) begin
	    next_k = 0;//Saturation
	 end
	 else begin
	    next_k = k - 1;
	 end
      end // else: !if(sync_ld)
   end // always @ (k,sync_ld)

   assign alarm = (k == 0) ? 1'b1 : 1'b0;
   
   
endmodule // alarm_clock

// This module is a 3 bit to 8 bit decoder that outputs the
// bus timing as chosen on pages 15 and 16 of reference [4].
// They assume a 50MHz clk so the timings are either 2500ns
// or 5000ns. 
module select_delay(sel,t);
   input [2:0] sel;
   output [7:0]	t;
   wire [2:0]	sel;
   reg [7:0]	t;
   
   always @(sel) begin
      case (sel)
	`t_SU_DAT : t = 8'd125;
        `t_HIGH_BY_2 : t = 8'd125;
	`t_HD_DAT : t = 8'd125;
	`t_SU_STA : t = 8'd250;
	`t_HD_STA : t = 8'd250;
	`t_SU_STO : t = 8'd250;
	`t_BUF : t = 8'd250;
	default: t = 8'd250;
      endcase // case (sel)
   end
   
endmodule // select_delay

// This 3-to-1 mux is needed because in the combinatorial
// output block of bit_level_state_mc, the sda_oe signal
// is an output. Now, when the state m/c is driving a data
// bit, the writer wrote,
// sda_oe = ~ `tx_bit;
// in the procedural always block implementing output=g(state).
// Here `tx_bit is a mnemonic for a bit in the command register.
// This means that the command register cmd has to be included
// in the sensitivity list of the always block. Now, the writer
// has standardized on implementing state machines as Moore machines
// in which the output=g(state) because this means the outputs are
// synchronous because they only change on the posedge of clk.
// In order to fix this and implement a Moore m/c we don't drive
// sda_oe directly, but get the output of the state m/c to drive
// the sel input of the 3-to-1 mux. The mux can be hooked up to
// a 1'b0, a 1'b1 and `tx_bit and sel selects one of these three
// channels to be routed to the output which is sda_oe as follows.
// mux_3_to_1 U0(.a(1'b0),.b(1'b1),.c(~ `tx_bit),.sel(sel),.y(sda_oe));
// Now, the combinatorial output block of the Moore machine is,
// always @(state) begin
//   case (state)
//     ...
//     some_state : sel = 2'b10; //drives sda_oe = ~ `tx_bit
//     ...
//   endcase
// end
// The reason for this long explanation was that the writer thought
// he had internalised how to implement a synchronous state machine,
// yet this error was not spotted initially.
module mux_3_to_1(a,b,c,sel,y);
   input a,b,c;
   input [1:0] sel;
   output      y;
   wire	       a,b,c;
   wire [1:0]  sel;
   reg	       y;
   
   always @(sel,a,b,c) begin
      case (sel)
	2'b00 : y = a;
	2'b01 : y = b;
	2'b10 : y = c;
	default: y = a;
      endcase // case (sel)
   end
   
endmodule // mux_3_to_1

// The purpose of this 26-to-1 mux is to select a bit in the 
// command word to be connected to the tx_bit input of the 
// low-level state m/c. There are useful mnenomics for
// the selection signal sel so that it is easy to see which
// bit of the slave address, memory address or byte to be
// written is selected and appears at the y output. 
module mux_26_to_1(bit_array,sel,y);
   input [25:0] bit_array;
   input [4:0] sel;
   output      y;
   wire [25:0] bit_array;
   wire [4:0]  sel;
   reg	       y;
   
   always @(sel,bit_array) begin
      case (sel)
	`sel_RnW : y = bit_array[0];
	`sel_SA1 : y = bit_array[1];
	`sel_SA2 : y = bit_array[2];
	`sel_SA3 : y = bit_array[3];
	`sel_SA4 : y = bit_array[4];
	`sel_SA5 : y = bit_array[5];
	`sel_SA6 : y = bit_array[6];
	`sel_SA7 : y = bit_array[7];
	`sel_A0 : y = bit_array[8];
	`sel_A1 : y = bit_array[9];
	`sel_A2 : y = bit_array[10];
	`sel_A3 : y = bit_array[11];
	`sel_A4 : y = bit_array[12];
	`sel_A5 : y = bit_array[13];
	`sel_A6 : y = bit_array[14];
	`sel_A7 : y = bit_array[15];
	`sel_D0 : y = bit_array[16];
	`sel_D1 : y = bit_array[17];
	`sel_D2 : y = bit_array[18];
	`sel_D3 : y = bit_array[19];
	`sel_D4 : y = bit_array[20];
	`sel_D5 : y = bit_array[21];
	`sel_D6 : y = bit_array[22];
	`sel_D7 : y = bit_array[23];
	`sel_LO : y = bit_array[24];
	`sel_HI : y = bit_array[25];
	default: y = 1'b0;
      endcase // case (sel)
   end
   
endmodule // mux_26_to_1

module shift_left_reg(clk,rst,sl,d,q);
   parameter W=8;//Width of register

   input     clk,rst,sl,d;
   output [(W-1):0] q;

   wire		    clk,rst,sl,d;
   reg [(W-1):0]    q;

   // The register has been written with a separate combinatorial block 
   // and a sequential clock along the lines of the shifter described 
   // in section 5.3.1.3 on page 160 of Navabi [5]. This is good Verilog
   // style.

   // Sequential block of the shift register.
   always @(posedge clk) begin
      if (rst) begin
	 q <= {W{1'b0}};
      end
      else begin
	 q <= next_q;
      end
   end

   // Combinatorial block of the shift register.
   reg [(W-1):0] next_q;
   always @(sl,d,q) begin
      if (sl) begin
	 next_q[(W-1):1] = q[(W-2):0];
	 next_q[0] = d;
      end
      else begin
	 next_q = q;
      end
   end
   
endmodule // shift_left_reg

   


// This state m/c drives bit-level signals onto the I2C bus.
// ---------------------------------------------------------------------
// |Bit  |    Description of three-bit command 
// |--------------------------------------------------------------------
// |1:0  |  The bit_type[1:0] to transmit. The four bit-types are,
// |     |  STA 2'b00 START
// |     | rSTA 2'b01 reSTART
// |     | STO 2'b10  STOP
// |     | DAT 2'b11  DATA
// |-----|----------------------------------------------------------------
// |2    | tx_bit. The level driven onto the SDA bus wire by
// |     | the bit level state m/c during the DAT bit.
// |-----|----------------------------------------------------------------
// The command is synchronously loaded into the module's internal
// command register by ld_cmd. Notice there is no start bit in the 
// three-bit command; the state m/c starts when it sees the synchronous
// ld_cmd. When the state m/c has finished driving
// the bit onto the I2C, it raises the done wire and rx_bit is the level
// of the SDA bus wire sampled at the midpoint of the SCL pulse during
// the DAT bit. Note that if the tx_bit=1'b1, the I2C slave can pull
// the SDA bus wire down so that rx_bit=1'b0. 
module bit_level_state_mc(clk,reset,cmd_in,ld_cmd,rx_bit,pulsed_done,
			  sda,scl);
   input clk,reset;
   input [2:0] cmd_in;
   input       ld_cmd;
   output [0:0]	rx_bit;
   output pulsed_done;
   inout  sda,scl;
   
   wire	       clk,reset;
   wire [2:0]  cmd_in;
   wire	       ld_cmd;

   // The following Verilog is how the I2C bus signals sda,scl are
   // sampled in signals sda_in, scl_in and how signals are driven
   // onto the I2C bus using on open drain buffer. This construct
   // is suggested in reference [1] in the section on the Avalon I2C
   // (Host) core.
   wire		 sda,scl;
   wire		 sda_in,scl_in;
   assign scl_in = scl;
   assign scl = scl_oe ? 1'b0 : 1'bz;
   assign sda_in = sda;
   assign sda = sda_oe ? 1'b0 : 1'bz;
   
   wire [2:0] cmd;
   general_register cmdreg(.clk(clk),.sync_rst(reset),.sync_ld(ld_cmd),
		       .data_in(cmd_in),.data_out(cmd));
   defparam cmdreg.W=3;//Width of the register

   // The delayed load command is used as the start pulse
   // for the low-level statte m/c. The delayed_ld_cmd is
   // synchronous with a new cmd out of the cmdreg.
   reg delayed_ld_cmd;
   always @(posedge clk) begin
      delayed_ld_cmd <= ld_cmd;
   end
   
   wire [7:0] t;// 8-bit timing values
   select_delay I2C_timing_selector(.sel(sel),.t(t));
   wire alarm;
   alarm_clock  I2C_timer(.clk(clk),.sync_ld(ld_timer),
			  .delay(t),.alarm(alarm));
   defparam I2C_timer.W=8;//Width of the timer counter

   // Some useful mnemonics for bits in the command reg.
   `define bit_type cmd[1:0]
   `define tx_bit cmd[2]

   // Some mnemonics for driving sda_oe in a procedural
   // combinatorial output block that implements a Moore
   // machine. See the documentation on module mux_3_to_1.
   `define sda_released_hi 2'b00
   `define sda_pulled_lo 2'b01
   `define sda_is_tx_bit 2'b10

   localparam
	     m0_idle=5'd0,
	     m1_STA=5'd1,
	     m2_delay_to_SCL_LO=5'd2,
	     m3_SCL_LO=5'd3,
	     m4_delay_to_STA_end=5'd4,
	     m5_STA_end=5'd5,
	     m6_DAT=5'd6,
	     m7_delay_to_SCL_HI=5'd7,
	     m8_SCL_HI=5'd8,
	     m9_delay_to_DAT=5'd9,
	     m10_DAT=5'd10,
	     m11_delay_to_SCL_LO=5'd11,
	     m12_SCL_LO=5'd12,
	     m13_delay_to_DAT_end=5'd13,
	     m14_DAT_end=5'd14,
	     m15_rSTA=5'd15,
	     m16_delay_to_SCL_HI=5'd16,
	     m17_SCL_HI=5'd17,
	     m18_delay_to_SDA_LO=5'd18,
	     m19_SDA_LO=5'd19,
	     m20_delay_to_SCL_LO=5'd20,
	     m21_SCL_LO=5'd21,
	     m22_delay_to_rSTA_end=5'd22,
	     m23_rSTA_end=5'd23,
	     m24_STO=5'd24,
	     m25_delay_to_SCL_HI=5'd25,
	     m26_SCL_HI=5'd26,
	     m27_delay_to_SDA_HI=5'd27,
	     m28_SDA_HI=5'd28,
	     m29_delay_to_STO_end=5'd29;
   
   reg [4:0] state,next_state;

   // This is the sequential block of the state machine
   always @(posedge clk) begin
      if (reset) begin
	 state <= m0_idle;
      end
      else begin
	 state <= next_state;
      end
   end

   // Combinatorial block of the state machine implementing
   // next_state = f(state, input)
   always @(state,delayed_ld_cmd,alarm,`bit_type) begin
      case (state)
	m0_idle: begin
	   if (delayed_ld_cmd) begin
	      case (`bit_type)
		`STA : next_state = m1_STA;
		`rSTA : next_state = m15_rSTA;
		`STO : next_state = m24_STO;
		`DAT : next_state = m6_DAT;
		default : next_state = m0_idle;
	      endcase // case (`bit_type)
	   end
	   else begin
	      next_state = m0_idle;
	   end // else: !if(one_shot_start)
	end // case: m0_idle
	m1_STA: begin
	   next_state = m2_delay_to_SCL_LO;
	end
	m2_delay_to_SCL_LO: begin
	   if (alarm) begin
	      next_state = m3_SCL_LO;
	   end
	   else begin
	      next_state = m2_delay_to_SCL_LO;
	   end
	end
	m3_SCL_LO: begin
	   next_state = m4_delay_to_STA_end;
	end
	m4_delay_to_STA_end: begin
	   if (alarm) begin
	      next_state = m5_STA_end;
	   end
	   else begin
	      next_state = m4_delay_to_STA_end;
	   end
	end
	m5_STA_end: begin
	   if (delayed_ld_cmd) begin
	      case (`bit_type)
		`STA : next_state = m1_STA;
		`rSTA : next_state = m15_rSTA;
		`STO : next_state = m24_STO;
		`DAT : next_state = m6_DAT;
		default : next_state = m5_STA_end;
	      endcase // case (`bit_type)
	   end
	   else begin
	      next_state = m5_STA_end;
	   end // else: !if(one_shot_start)
	end // case: m5_STA_end
	m6_DAT: begin
	   next_state = m7_delay_to_SCL_HI;
	end
	m7_delay_to_SCL_HI: begin
	   if (alarm) begin
	      next_state = m8_SCL_HI;
	   end
	   else begin
	      next_state = m7_delay_to_SCL_HI;
	   end
	end
	m8_SCL_HI: begin
	   next_state = m9_delay_to_DAT;
	end
	m9_delay_to_DAT: begin
	   if (alarm) begin
	      next_state = m10_DAT;
	   end
	   else begin
	      next_state = m9_delay_to_DAT;
	   end
	end
	m10_DAT: begin
	   next_state = m11_delay_to_SCL_LO;
	end
	m11_delay_to_SCL_LO: begin
	   if (alarm) begin
	      next_state = m12_SCL_LO;
	   end
	   else begin
	      next_state = m11_delay_to_SCL_LO;
	   end
	end
	m12_SCL_LO: begin
	   next_state = m13_delay_to_DAT_end;
	end
	m13_delay_to_DAT_end: begin
	   if (alarm) begin
	      next_state = m14_DAT_end;
	   end
	   else begin
	      next_state = m13_delay_to_DAT_end;
	   end
	end
	m14_DAT_end: begin
	   if (delayed_ld_cmd) begin
	      case (`bit_type)
		`STA : next_state = m1_STA;
		`rSTA : next_state = m15_rSTA;
		`STO : next_state = m24_STO;
		`DAT : next_state = m6_DAT;
		default : next_state = m14_DAT_end;
	      endcase // case (`bit_type)
	   end
	   else begin
	      next_state = m14_DAT_end;
	   end // else: !if(delayed_ld_cmd)
	end // case: m14_STA_end
	m15_rSTA: begin
	   next_state = m16_delay_to_SCL_HI;
	end
	m16_delay_to_SCL_HI: begin
	   if (alarm) begin
	      next_state = m17_SCL_HI;
	   end
	   else begin
	      next_state = m16_delay_to_SCL_HI;
	   end
	end
	m17_SCL_HI: begin
	   next_state = m18_delay_to_SDA_LO;
	end
	m18_delay_to_SDA_LO: begin
	   if (alarm) begin
	      next_state = m19_SDA_LO;
	   end
	   else begin
	      next_state = m18_delay_to_SDA_LO;
	   end
	end
	m19_SDA_LO: begin
	   next_state = m20_delay_to_SCL_LO;
	end
	m20_delay_to_SCL_LO: begin
	   if (alarm) begin
	      next_state = m21_SCL_LO;
	   end
	   else begin
	      next_state = m20_delay_to_SCL_LO;
	   end
	end
	m21_SCL_LO: begin
	   next_state = m22_delay_to_rSTA_end;
	end
	m22_delay_to_rSTA_end: begin
	   if (alarm) begin
	      next_state = m23_rSTA_end;
	   end
	   else begin
	      next_state = m22_delay_to_rSTA_end;
	   end
	end
	m23_rSTA_end: begin
	   if (delayed_ld_cmd) begin
	      case (`bit_type)
		`STA : next_state = m1_STA;
		`rSTA : next_state = m15_rSTA;
		`STO : next_state = m24_STO;
		`DAT : next_state = m6_DAT;
		default : next_state = m23_rSTA_end;
	      endcase // case (`bit_type)
	   end
	   else begin
	      next_state = m23_rSTA_end;
	   end // else: !if(delayed_ld_cmd)
	end // case: m23_rSTA_end
	m24_STO: begin
	   next_state = m25_delay_to_SCL_HI;
	end
	m25_delay_to_SCL_HI: begin
	   if (alarm) begin
	      next_state = m26_SCL_HI;
	   end
	   else begin
	      next_state = m25_delay_to_SCL_HI;
	   end
	end
	m26_SCL_HI: begin
	   next_state = m27_delay_to_SDA_HI;
	end
	m27_delay_to_SDA_HI: begin
	   if (alarm) begin
	      next_state = m28_SDA_HI;
	   end
	   else begin
	      next_state = m27_delay_to_SDA_HI;
	   end
	end
	m28_SDA_HI: begin
	   next_state = m29_delay_to_STO_end;
	end
	m29_delay_to_STO_end: begin
	   if (alarm) begin
	      next_state = m0_idle;
	   end
	   else begin
	      next_state = m29_delay_to_STO_end;
	   end
	end
	default: begin
	   next_state = m0_idle;
	end
      endcase // case (state)
   end // always @ (state,...)

   // Combinatorial block implementing output=g(state)
   reg [1:0] sel_sda_oe;
   reg scl_oe;
   reg [2:0] sel;
   reg	     ld_timer;
   
   always @(state) begin
      case (state)
	m0_idle: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_HD_STA;
	   ld_timer = 1'b0;
	end
	m1_STA: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;
	   sel = `t_HD_STA;
	   ld_timer = 1'b1;
	end
	m2_delay_to_SCL_LO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;
	   sel =`t_HD_DAT;
	   ld_timer = 1'b0;
	end
	m3_SCL_LO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_HD_DAT;
	   ld_timer = 1'b1;
	end
	m4_delay_to_STA_end: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m5_STA_end: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m6_DAT: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b1;
	end
	m7_delay_to_SCL_HI: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b1;
	   sel = `t_HIGH_BY_2;
	   ld_timer = 1'b0;
	end
	m8_SCL_HI: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b0;
	   sel = `t_HIGH_BY_2;
	   ld_timer = 1'b1;
	end
	m9_delay_to_DAT: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b0;
	   sel = `t_HIGH_BY_2;
	   ld_timer = 1'b0;
	end
	m10_DAT: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b0;
	   sel = `t_HIGH_BY_2;
	   ld_timer = 1'b1;
	end
	m11_delay_to_SCL_LO: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b0;
	   sel = `t_HD_DAT;
	   ld_timer = 1'b0;
	end
	m12_SCL_LO: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b1;
	   sel = `t_HD_DAT;
	   ld_timer = 1'b1;
	end
	m13_delay_to_DAT_end: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m14_DAT_end: begin
	   sel_sda_oe = `sda_is_tx_bit;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m15_rSTA: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b1;
	end
	m16_delay_to_SCL_HI: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b1;
	   sel = `t_SU_STA;
	   ld_timer = 1'b0;
	end
	m17_SCL_HI: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_SU_STA;
	   ld_timer = 1'b1;
	end
	m18_delay_to_SDA_LO: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_HD_STA;
	   ld_timer = 1'b0;
	end
	m19_SDA_LO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;
	   sel = `t_HD_STA;
	   ld_timer = 1'b1;
	end
	m20_delay_to_SCL_LO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;	
	   sel = `t_HD_DAT;
	   ld_timer = 1'b0;
	end
	m21_SCL_LO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_HD_DAT;
	   ld_timer = 1'b1;
	end
	m22_delay_to_rSTA_end: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m23_rSTA_end: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	m24_STO: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b1;
	end
	m25_delay_to_SCL_HI: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b1;
	   sel = `t_SU_STO;
	   ld_timer = 1'b0;
	end
	m26_SCL_HI: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;
	   sel = `t_SU_STO;
	   ld_timer = 1'b1;
	end
	m27_delay_to_SDA_HI: begin
	   sel_sda_oe = `sda_pulled_lo;
	   scl_oe = 1'b0;
	   sel = `t_BUF;
	   ld_timer = 1'b0;
	end
	m28_SDA_HI: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_BUF;
	   ld_timer = 1'b1;
	end
	m29_delay_to_STO_end: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_SU_DAT;
	   ld_timer = 1'b0;
	end
	default: begin
	   sel_sda_oe = `sda_released_hi;
	   scl_oe = 1'b0;
	   sel = `t_HD_STA;
	   ld_timer = 1'b0;
	end
      endcase // case (state)
   end // always @ (state) (Moore m/c)

   // Combinatorial block implementing output=g(state)
   reg done;
   always @(state) begin
      case (state)
	m0_idle,m5_STA_end,m14_DAT_end,m23_rSTA_end: begin
	   done =1'b1;
	end
	default: begin
	   done = 1'b0;
	end
      endcase // case (state)
   end

   // This is a messy fix. The low-level state m/c registers
   // cmd_in[2:0] as cmd[2:0]. This causes a delay before the
   // state m/c gets going and sets done=0. Unfortunately, the
   // high level state m/c begins waiting for done=1 before the
   // low-level machine has set done=0. One fix would have been
   // to add states to the high-level state machine so that it
   // checked that done=0 so it could be sure that the low-level
   // m/c was going. However, this would have added many states.
   // The easy fix is just to differentiate the done signal so
   // that it is a pulse lasting for one clk cycle. The
   // high-level m/c should catch these pulses.
   reg delayed_done;
   always @(posedge clk) begin
      delayed_done <= done;
   end

   wire pulsed_done;
   assign pulsed_done = done & (~ delayed_done);
   
   // Combinatorial block implementing output=g(state).
   // This is for the combinatorial block that can be
   // implemented by assign instead of a combinatorial
   // always block.
   wire ld_rx_bit;//Output signal to gate clk to load DAT state.
   assign ld_rx_bit = (state == m10_DAT) ? 1'b1 : 1'b0;

   // 1-bit register to store the DAT bit.
   wire [0:0] rx_bit;
   general_register rx_bit_reg(.clk(clk),.sync_rst(reset),
				 .sync_ld(ld_rx_bit),
				 .data_in(sda_in),.data_out(rx_bit));
   defparam rx_bit_reg.W=1;//Width of the register

   // 3-to-1 mux to select the output driven onto the sda wire.
   wire sda_oe;
   mux_3_to_1 sda_oe_mux(.a(1'b0),.b(1'b1),.c(~ `tx_bit),
		      .sel(sel_sda_oe),.y(sda_oe));
	     
endmodule // bit_level_state_mc
