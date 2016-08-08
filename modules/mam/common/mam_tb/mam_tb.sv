import dii_package::dii_flit;

module mam_tb;
	localparam DATA_WIDTH = 16;
	localparam ADDR_WIDTH = 32;
	
	reg 			clk, rst;
	dii_flit 		debug_in, debug_out;
	reg 			debug_out_ready;
	wire 			debug_in_ready;
	
	reg [9:0] 		id;
	
	wire 			req_valid;
	reg 			req_ready;
	
	wire			req_rw;
	wire [ADDR_WIDTH-1:0]	req_addr;
	wire			req_burst;
	wire [13:0]		req_beats;
	
	wire			write_valid;
	wire [DATA_WIDTH-1:0]	write_data;
	wire [DATA_WIDTH/8-1:0]	write_strb;
	reg			write_ready;
	
	reg			read_valid;
	reg [DATA_WIDTH-1:0]	read_data;
	wire			read_ready;
	
	osd_mam #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.MAX_PKT_LEN(8),
		.BASE_ADDR0(0),
		.MEM_SIZE0(1024*1024*1024))
	mam_ut(.*);
	
	//initialize inputs
	initial
	begin
		clk = 0;
		rst = 0;
		
		debug_in.data = '0;
		debug_in.valid = 0;
		debug_in.last = 0;
		
		debug_out_ready = 1;
		id = 10'h5;
		req_ready = 1;
		write_ready = 1;
		read_valid = 0;
		read_data = '0;
	end //initialize
	
	//clock gen
	always
		#10 	clk = !clk;
	
	//reset logic
	event reset_trigger;
	event reset_done_trigger;
	initial
	begin
		forever begin
			@(reset_trigger);
			@(negedge clk);
			rst = 1;
			@(negedge clk);
			rst = 0;
			-> reset_done_trigger;
		end
	end //reset logic
	
	//sending flits
	event flit_trigger;
	event flit_done_trigger;
	initial
	begin
		forever begin
			@(flit_trigger);
			//while (!debug_in_ready) begin
			//end
		#50	debug_in.data = debug_in.data + 1;
			@(negedge clk)
				debug_in.valid = 1;
			 @(negedge clk)
				debug_in.valid = 0;
			-> flit_done_trigger;
		end //forever
	end //sending flits
	
	//Test run for burst write of two packets
	//data is incremented and output should be x0000...x0006
	event writetwo_trigger;
	event writetwo_done_trigger;
	bit [15:0] data_buf;
	initial
	begin: WRITETWO
		forever begin
			@(writetwo_trigger);
		#50 	debug_in.data = 16'h0000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = {1'b1, 1'b1, 14'h6}; //MAM header flit, W, Burst, Burst Size
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 1
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50 	-> flit_trigger;	//data flits with incrementing value
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50 	debug_in.data = debug_in.data + 1; //last flit pack 1
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0; //end packet 1
			
			data_buf = debug_in.data;
			
		#50 	debug_in.data = 16'h0000; //header flit pack 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit pack 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
			
			
			
		#50	debug_in.data = data_buf;
			-> flit_trigger;	//data flits pack 2
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50 	debug_in.data = debug_in.data + 1; 	 //last flit
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0;
			-> writetwo_done_trigger;
		end
	end //writetwo
	
	
	//Test run for burst write of three packets with the first packet being the address only
	//data is incremented and output should be x0001...x0010
	event writeaddr_trigger;
	event writeaddr_done_trigger;
	initial
	begin: WRITEADDR
		forever begin
			@(writeaddr_trigger);
		#50 	debug_in.data = 16'h0000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = {1'b1, 1'b1, 14'h10}; //MAM header flit, W, Burst, Burst Size
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 1
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 2
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
			debug_in.last = 0;
			
		#50 	debug_in.data = 16'h0000; //header flit pack 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit pack 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;			
		#50	debug_in.data = 0;
			-> flit_trigger;	//data flits
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50 	debug_in.data = debug_in.data + 1; 	 //last flit pack 2
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0;
			data_buf = debug_in.data;
			
		#50 	debug_in.data = 16'h0000; //header flit pack 3
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit pack 3
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;			
		#50	debug_in.data = data_buf;
			-> flit_trigger;	//data flits
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50	-> flit_trigger;
			@(flit_done_trigger);
		#50 	debug_in.data = debug_in.data + 1; 	 //last flit pack 3
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0;
			-> writeaddr_done_trigger;
		end
	end //writetwo
	
	
	//Test run for writing a single data word
	//write data should be xF
	event writesingle_trigger;
	event writesingle_done_trigger;
	
	initial
	begin: WRITESINGLE
		forever begin
			@(writesingle_trigger);
		#50 	debug_in.data = 16'h0000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = {1'b1, 1'b0, 14'h0}; //MAM header flit, W, Single, strobe
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 1
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50 	debug_in.data = 16'hf; //data flit
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0; //end packet
			
			-> writesingle_done_trigger;
		end
	end //writesingle
	
	//Test run for "write ready" input functioning properly.
	event writeready_trigger;
	event writeready_done_trigger;
	
	initial
	begin: WRITEREADY
		forever begin
			@(writeready_trigger);
		#50	write_ready = 0;
		 	debug_in.data = 16'h0000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h4000; //header flit
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = {1'b1, 1'b0, 14'h0}; //MAM header flit, W, Single, strobe
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 1
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50	debug_in.data = 16'h0; //Address x0000 flit 2
			@(negedge clk)
			debug_in.valid = 1;
			@(negedge clk);
			debug_in.valid = 0;
		#50 	debug_in.data = 16'hf; //data flit
			debug_in.last = 1;
			@(negedge clk)
			debug_in.valid = 1;
		#150	@(negedge clk)
			write_ready = 1;
			@(negedge clk)
			debug_in.valid = 0;
			debug_in.last = 0; //end packet
			-> writeready_done_trigger;
		end
	end
	
		
	//build test run from blocks
	initial
	begin: TEST_RUN
		#10 	-> reset_trigger;
		@(reset_done_trigger);
	//	#50	-> writetwo_trigger;
	//	@(writetwo_done_trigger);
	//	#50	-> writesingle_trigger;
	//	@(writesingle_done_trigger);
	//	#50	-> writeaddr_trigger;
	//	@(writeaddr_done_trigger);
		#50	-> writeready_trigger;
		@(writeready_done_trigger);
	end

endmodule
