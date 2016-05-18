import dii_package::dii_flit;


//Testbench for MAM connected to a Debug Interconnect Ring
//Data is inserted into port 0 of the Interconnect and expected to show up as written data in the MAM
module mam_intcon_tb;
	localparam DATA_WIDTH = 16;
	localparam ADDR_WIDTH = 32;
	
	localparam PORTS = 2; //Number of ports in Debug Ring
	localparam PORTIDMAP = {10'h1, 10'h0}; //IDs of Modules: [19:10]:MAM, [9:0]:Host
	
	/////////////////
	//Parameters to define Test Runs
	////////////////
	localparam MAX_TEST_LENGTH = 25; //maximum number of flits transferred in any of the test runs
	//lengths have to match lengths of data and last arrays corresponding to the run
	localparam WRTWO_LENGTH = 13;
	localparam WRADDR_LENGTH = 25;
	localparam WRSINGLE_LENGTH = 6;
	localparam WRREADY_LENGTH = 12;
	
	//In case of burst writes, make sure burst length in third flit (MAM header flit) matches the number of words to be written
	bit [15:0] 	wrtwo_data[WRTWO_LENGTH] = {{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'hc006, 16'h0000, 16'h0000, 16'h0001, 16'h0002, 16'h0003,
							{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h0004, 16'h0005, 16'h0006};
	bit			wrtwo_last[WRTWO_LENGTH] = {0, 0, 0, 0, 0, 0, 0, 1,
							 0, 0, 0, 0, 1};
						 
	bit [15:0] 	wraddr_data[WRADDR_LENGTH] = {{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'hc010, 16'h0000, 16'h0000,
						 	{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h0001, 16'h0002, 16'h0003, 16'h0004, 16'h0005, 16'h0006, 16'h0007, 16'h0008,
					 		{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h0009, 16'h000a, 16'h000b, 16'h000c, 16'h000d, 16'h000e, 16'h000f, 16'h0010};
	bit			wraddr_last[WRADDR_LENGTH] = {0, 0, 0, 0, 1,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
							0, 0, 0, 0, 0, 0, 0, 0, 0, 1};
							
	bit [15:0]	wrsingle_data[WRSINGLE_LENGTH] = {{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h8000, 16'h0000, 16'h0000, 16'h000f};
	bit			wrsingle_last[WRSINGLE_LENGTH] = {0, 0, 0, 0, 0, 1};
	

	bit [15:0]	wrready_data[WRREADY_LENGTH] = {{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h8000, 16'h0000, 16'h0000, 16'h000f,
							{6'h0, PORTIDMAP[19:10]}, {6'h10, PORTIDMAP[9:0]}, 16'h8000, 16'h0000, 16'h0000, 16'h000c};
	bit			wrready_last[WRREADY_LENGTH] = {0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1};
	
	////////////////
	// End of Parameters for Test Runs
	////////////////
	
	reg 			clk, rst;
	
	//Arrays of In- and Outputs to from the debug interconnect for setup of the ring
	dii_flit[1:0]		debug_in;
//				debug_in[1] = mam2dbg;
//				debug_in[0] = host2dbg;
	dii_flit[1:0]		debug_out;
//				debug_out[1] = dbg2mam;
//				debug_out[0] = dbg2host;
	reg[1:0]		debug_out_ready;
//				debug_out_ready[1] = mam2dbg_ready;
//				debug_out_ready[0] = host2dbg_ready;
	wire[1:0]		debug_in_ready;
//				debug_in_ready[1] = dbg2mam_ready;
//				debug_in_ready[0] = dbg2host_ready;
	
	
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
	
	//MAM Module
	osd_mam #(
		.DATA_WIDTH(DATA_WIDTH),
		.ADDR_WIDTH(ADDR_WIDTH),
		.MAX_PKT_LEN(8),
		.BASE_ADDR0(0),
		.MEM_SIZE0(1024*1024*1024))
	mam_ut(.id(PORTIDMAP[19:10]),
		.debug_in(debug_out[1]),
		.debug_in_ready(debug_out_ready[1]),
		.debug_out(debug_in[1]),
		.debug_out_ready(debug_in_ready[1]),
		.*);
	
	//Debug Ring
	debug_ring #(
			.PORTS(PORTS),
			.PORTIDMAP(PORTIDMAP))
	dbg_ring_ut(.dii_in(debug_in), .dii_in_ready(debug_in_ready),
			.dii_out(debug_out), .dii_out_ready(debug_out_ready),
			.*);
	
	
	//initialize inputs
	initial
	begin
		clk = 0;
		rst = 0;
		
		debug_in[0].data = '0;
		debug_in[0].valid = 0;
		debug_in[0].last = 0;
		
		debug_out_ready[0] = 1;
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
	bit [15:0] 	packets[MAX_TEST_LENGTH];
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
				debug_in[0].valid = 0;
			#2	debug_in[0].data = packets[cnt];
				debug_in[0].last = packet_last[cnt];
				debug_in[0].valid = 1;
			end else begin
				debug_in[0].valid = 0;
				-> transfer_done_trigger;
			end
			cnt = cnt + 1;
			-> flit_done_trigger;
		end
	end //sending flits
	
	
	//whenever there is valid data and the system is ready, send the next flit
	always @(posedge clk)
	begin
		if(debug_in[0].valid == 1 && debug_in_ready[0]) begin
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
			MAXCNT = WRTWO_LENGTH;
			packets[0:WRTWO_LENGTH-1] = wrtwo_data;
			packet_last[0:WRTWO_LENGTH-1] = wrtwo_last;
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
			MAXCNT = WRADDR_LENGTH;
			packets[0:WRADDR_LENGTH-1] = wraddr_data;
			packet_last[0:WRADDR_LENGTH-1] = wraddr_last;
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
			MAXCNT = WRSINGLE_LENGTH;
			packets[0:WRSINGLE_LENGTH-1] = wrsingle_data;
			packet_last[0:WRSINGLE_LENGTH-1] = wrsingle_last;
			-> flit_trigger;
		end
	end //wrsingle
	
	//Test run for "write ready" input functioning properly.
	//Write two single words, MAM has to wait for write_ready for first word
	event wrready_trigger;
	
	initial
	begin: WRREADY
		forever begin
			@(wrready_trigger);
			write_ready = 0;
			cnt = 0;
			MAXCNT = WRREADY_LENGTH;
			packets[0:WRREADY_LENGTH-1] = wrready_data;
			packet_last[0:WRREADY_LENGTH-1] = wrready_last;
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
		while(!debug_out_ready[0]) begin
			#1;
		end
			-> wrready_trigger;
		@(transfer_done_trigger);
		while(!debug_in_ready) begin
			#1;
		end
			-> wrtwo_trigger;
		@(transfer_done_trigger);
		while(!debug_out_ready[0]) begin
			#1;
		end
			-> wraddr_trigger;
		@(transfer_done_trigger);
		while(!debug_out_ready[0]) begin
			#1;
		end
			-> wrsingle_trigger;
		@(transfer_done_trigger);
	end

endmodule