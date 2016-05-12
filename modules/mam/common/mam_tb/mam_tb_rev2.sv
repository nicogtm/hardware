import dii_package::dii_flit;

module mam_tb;
	localparam DATA_WIDTH = 16;
	localparam ADDR_WIDTH = 32;
	
	/////////////////
	//Parameters to define Test Runs
	////////////////
	localparam MAX_TEST_LENGTH = 25; //maximum number of flits transferred in any of the test runs
	//lengths have to match lengths of data and last arrays corresponding to the run
	localparam WRTWO_LENGTH = 13;
	localparam WRADDR_LENGTH = 25;
	localparam WRSINGLE_LENGTH = 6;
	localparam WRREADY_LENGTH = 12;
	
	bit [DATA_WIDTH-1:0] 	wrtwo_data[WRTWO_LENGTH] = {16'h0000, 16'h4000, 16'hc006, 16'h0000, 16'h0000, 16'h0001, 16'h0002, 16'h0003,
							16'h0000, 16'h4000, 16'h0004, 16'h0005, 16'h0006};
	bit			wrtwo_last[WRTWO_LENGTH] = {0, 0, 0, 0, 0, 0, 0, 1,
							 0, 0, 0, 0, 1};
						 
	bit [DATA_WIDTH-1:0] 	wraddr_data[WRADDR_LENGTH] = {16'h0000, 16'h4000, 16'hc010, 16'h0000, 16'h0000,
						 	16'h0000, 16'h4000, 16'h0001, 16'h0002, 16'h0003, 16'h0004, 16'h0005, 16'h0006, 16'h0007, 16'h0008,
					 		16'h0000, 16'h4000, 16'h0009, 16'h000a, 16'h000b, 16'h000c, 16'h000d, 16'h000e, 16'h000f, 16'h0010};
	bit			wraddr_last[WRADDR_LENGTH] = {0, 0, 0, 0, 1,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
							
	bit [DATA_WIDTH-1:0]	wrsingle_data[WRSINGLE_LENGTH] = {16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000f};
	bit			wrsingle_last[WRSINGLE_LENGTH] = {0, 0, 0, 0, 0, 1};
	

	bit [DATA_WIDTH-1:0]	wrready_data[WRREADY_LENGTH] = {16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000f, 16'h0000, 16'h4000, 16'h8000, 16'h0000, 16'h0000, 16'h000c};
	bit			wrready_last[WRREADY_LENGTH] = {0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1};
	
	////////////////
	// End of Parameters for Test Runs
	////////////////
	
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
	bit [DATA_WIDTH-1:0] 	packets[MAX_TEST_LENGTH];
	bit		packet_last[MAX_TEST_LENGTH];
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
	event 		wrtwo_trigger;
	
	initial
	begin: WRTWO
		forever begin
			@(wrtwo_trigger);
			cnt = 0;
			MAXCNT = 13;
			packets[0:12] = wrtwo_data;
			packet_last[0:12] = wrtwo_last;
			-> flit_trigger;
		end
	end //wrtwo
	
	
	//Test run for burst write of three packets with the first packet being the address only
	//data is incremented and output should be x0001...x0010
	event wraddr_trigger;
	initial
	begin: WRADDR
		forever begin
			@(wraddr_trigger);
			cnt = 0;
			MAXCNT = 25;
			packets = wraddr_data;
			packet_last = wraddr_last;
			-> flit_trigger;
		end
	end //wraddr
	
	
	//Test run for writing a single data word
	//write data should be xF
	event wrsingle_trigger;
	
	initial
	begin: WRSINGLE
		forever begin
			@(wrsingle_trigger);
			cnt = 0;
			MAXCNT = 6;
			packets[0:5] = wrsingle_data;
			packet_last[0:5] = wrsingle_last;
			-> flit_trigger;
		end
	end //wrsingle
	
	//Test run for "write ready" input functioning properly.
	//Write a single word twice, MAM has to wait for write_ready for first word
	event wrready_trigger;
	
	initial
	begin: WRREADY
		forever begin
			@(wrready_trigger);
			write_ready = 0;
			cnt = 0;
			MAXCNT = 12;
			packets[0:11] = wrready_data;
			packet_last[0:11] = wrready_last;
			-> flit_trigger;
			
		#500	 write_ready = 1;
		end
	end //wrready
	
		
	//build test run from blocks
	//use wrready_trigger, wrsingle_trigger, wrtwo_trigger and wraddr_trigger for corresponding test run.
	initial
	begin: TEST_RUN
		#10 	-> reset_trigger;
		@(reset_done_trigger)
		while(!debug_in_ready) begin
			#1;
		end
			-> wrready_trigger;
		@(transfer_done_trigger);
		while(!debug_in_ready) begin
			#1;
		end
			-> wrtwo_trigger;
		@(transfer_done_trigger);
		while(!debug_in_ready) begin
			#1;
		end
			-> wraddr_trigger;
		@(transfer_done_trigger);
		while(!debug_in_ready) begin
			#1;
		end
			-> wrsingle_trigger;
		@(transfer_done_trigger);
	end

endmodule
