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
	
	
	int cnt = 0;
	int MAXCNT = 13;
	
	//sending flits
	bit [15:0] 	packets[25];
	bit		packet_last[25];
	event flit_trigger;
	event flit_done_trigger;
	
	event 		transfer_done_trigger;

	
	
	//sending a flit
	initial
	begin
		forever begin
			@(flit_trigger);
			
			if (cnt < MAXCNT) begin
				debug_in.valid = 0;
			#2	debug_in.data = packets[cnt];
				debug_in.last = packet_last[cnt];
				debug_in.valid = 1;
			end else begin
				debug_in.valid = 0;
				-> transfer_done_trigger;
			end
			cnt = cnt + 1;
			-> flit_done_trigger;
		end //forever
	end //sending flits
	
	
	//whenever there is valid data and the system is ready, send the next flit
	always @(posedge clk)
	begin
		if(debug_in.valid == 1 && debug_in_ready) begin
			-> flit_trigger;
		end
	end
	
	//Test run for burst write of two packets
	//data is incremented and output should be x0000...x0006
	event 		writetwo_trigger;
	bit [15:0] 	writetwo_data[13] = {16'h0000, 16'h4000, 16'hc006, 16'h0000, 16'h0000, 16'h0001, 16'h0002, 16'h0003,
						16'h0000, 16'h4000, 16'h0004, 16'h0005, 16'h0006};
	bit		writetwo_last[13] = {0, 0, 0, 0, 0, 0, 0, 1,
						 0, 0, 0, 0, 1};
	
	initial
	begin: WRITETWO
		forever begin
			@(writetwo_trigger);
			cnt = 0;
			MAXCNT = 13;
			packets[0:12] = writetwo_data;
			packet_last[0:12] = writetwo_last;
			-> flit_trigger;
		end
	end //writetwo
	
	
	//Test run for burst write of three packets with the first packet being the address only
	//data is incremented and output should be x0001...x0010
	event writeaddr_trigger;
	bit [15:0] 	writeaddr_data[25] = {16'h0000, 16'h4000, 16'hc010, 16'h0000, 16'h0000,
						 16'h0000, 16'h4000, 16'h0001, 16'h0002, 16'h0003, 16'h0004, 16'h0005, 16'h0006, 16'h0007, 16'h0008,
					 	16'h0000, 16'h4000, 16'h0009, 16'h000a, 16'h000b, 16'h000c, 16'h000d, 16'h000e, 16'h000f, 16'h0010};
	bit		writeaddr_last[25] = {0, 0, 0, 0, 1,
						0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
						0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
	initial
	begin: WRITEADDR
		forever begin
			@(writeaddr_trigger);
			cnt = 0;
			MAXCNT = 25;
			packets = writeaddr_data;
			packet_last = writeaddr_last;
			-> flit_trigger;
		end
	end //writeaddr
	
	
	//Test run for writing a single data word
	//write data should be xF
	event writesingle_trigger;
	bit [15:0]	writesingle_data[6] = {16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000f};
	bit		writesingle_last[6] = {0, 0, 0, 0, 0, 1};
	
	initial
	begin: WRITESINGLE
		forever begin
			@(writesingle_trigger);
			cnt = 0;
			MAXCNT = 6;
			packets[0:5] = writesingle_data;
			packet_last[0:5] = writesingle_last;
			-> flit_trigger;
		end
	end //writesingle
	
	//Test run for "write ready" input functioning properly.
	//Write a single word twice, MAM has to wait for write_ready for first word
	event writeready_trigger;
	bit [15:0]	writeready_data[12] = {16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000f,
						16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000c};
	bit		writeready_last[12] = {0, 0, 0, 0, 0, 1,
						0, 0, 0, 0, 0, 1};
	
	initial
	begin: WRITEREADY
		forever begin
			@(writeready_trigger);
			write_ready = 0;
			cnt = 0;
			MAXCNT = 12;
			packets[0:11] = writeready_data;
			packet_last[0:11] = writeready_last;
			-> flit_trigger;
			
		#500	 write_ready = 1;
		end
	end //writeready
	
		
	//build test run from blocks
	initial
	begin: TEST_RUN
		#10 	-> reset_trigger;
		@(reset_done_trigger)
		while(!debug_in_ready) begin
			#1;
		end
			-> writeready_trigger;
		@(transfer_done_trigger);
		while(!debug_in_ready) begin
			#1;
		end
			-> writetwo_trigger;
		@(transfer_done_trigger);
	end

endmodule
