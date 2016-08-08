//Testbench for the MAM-Wishbone interface
module wb_if_tb;
    localparam DATA_WIDTH = 16;
    localparam ADDR_WIDTH = 32;


    /////////////////
    //Parameters to define Test Runs
    ////////////////
    localparam MAX_TEST_LENGTH = 6; //maximum number of flits transferred in any of the test runs
    //lengths have to match lengths of data and last arrays corresponding to the run
    localparam WRBURST_LENGTH = 6;
    localparam WRSINGLE_LENGTH = 1;
    localparam RDBURST_LENGTH = 4;

    //In case of burst writes, make sure burst length in third flit (MAM header flit) matches the number of words to be written
    bit [15:0]  wrburst_data[WRBURST_LENGTH] = {16'h0001, 16'h0002, 16'h0003, 16'h0004, 16'h0005, 16'h0006};
    bit [15:0]  wrsingle_data[WRSINGLE_LENGTH] = {16'h000f};
    bit [15:0]  rdburst_data[RDBURST_LENGTH] = {16'h0001, 16'h0002, 16'h0003, 16'h0004};
    

    ////////////////
    // End of Parameters for Test Runs
    ////////////////

    reg                 clk, rst;

    reg                req_valid;
    wire                 req_ready;

    reg                req_rw;
    reg [ADDR_WIDTH-1:0]   req_addr;
    reg                req_burst;
    reg [13:0]         req_beats;

    reg                write_valid;
    reg [DATA_WIDTH-1:0]   write_data;
    reg [DATA_WIDTH/8-1:0] write_strb;
    wire                write_ready;

    wire                read_valid;
    wire [DATA_WIDTH-1:0]    read_data;
    reg               read_ready;

    reg                     STB_O;
    reg                     CYC_O;
    reg                    ACK_I;
    reg                     WE_O;
    reg [ADDR_WIDTH-1:0]    ADDR_O;
    reg [DATA_WIDTH-1:0]    DAT_O;
    reg [DATA_WIDTH-1:0]   DAT_I;
    reg [2:0]               CTI_O;
    reg [1:0]               BTE_O;
    reg                       SEL_O;

    //Wishbone IF
    mam_wb_if #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH))
    wb_if_ut(.CLK_I(clk), .RST_I(rst), .*);

    //initialize inputs
    initial
    begin
        clk = 0;
        rst = 0;

        req_valid = 0;
        req_rw = 0;
        req_addr = '0;
        req_burst = 0;
        req_beats = '0;

        write_valid = 0;
        write_data = '0;
        write_strb = '0;

        read_ready = 1;

        DAT_I = '0;
    end //initialize

    //clock gen
    always
        #10     clk = !clk;

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
    int MAXCNT = 6;

    //sending flits
    bit [15:0]  packets[MAX_TEST_LENGTH];

    event write_trigger;
    event write_done_trigger;

    event       transfer_done_trigger;



    //sending a flit
    initial
    begin: WRITE
        forever begin
            @(write_trigger);
            if (cnt < MAXCNT) begin
                write_valid = 0;
            #2  write_data = packets[cnt];
                write_valid = 1;
            end else begin
                write_valid = 0;
                -> transfer_done_trigger;
            end
            cnt = cnt + 1;
            
            -> write_done_trigger;
        end
    end //sending flits
    
    event read_trigger;
    event read_done_trigger;
    
    initial
    begin: READ
        forever begin
            @(read_trigger);
            if(ACK_I) begin
                DAT_I = packets[cnt];
                cnt = cnt +1;
                ->read_done_trigger;
            end
            if(cnt == MAXCNT) begin
                ->transfer_done_trigger;
            end
        end
    end

    //whenever there is valid data and the system is ready, send the next flit
    always @(posedge clk)
    begin
        if(write_valid && write_ready) begin
            -> write_trigger;
        end
        if(CYC_O && STB_O && !WE_O) begin
            -> read_trigger;
        end
        if(req_ready) begin
            req_addr = 16'h0000;
            req_rw = 0;
            req_burst = 0;
            req_beats = 0;
            req_valid = 0;
        end
        if (CYC_O && STB_O && CTI_O != 3'b111) begin
            ACK_I = 1;
        end else begin
            ACK_I = 0;
        end
    end

    //Test run for burst write
    //data is incremented and output should be x0000...x0006
    event       wrburst_trigger;

    initial
    begin: WRBURST
        forever begin
            @(wrburst_trigger);
            cnt = 0;
            MAXCNT = WRBURST_LENGTH;
            packets[0:WRBURST_LENGTH-1] = wrburst_data;
            req_addr = 16'h0000;
            req_rw = 1;
            req_burst = 1;
            req_beats =WRBURST_LENGTH;
            req_valid = 1;
            while(!req_ready || !req_valid) begin
                #1;
            end
            -> write_trigger;
        end
    end //wrtwo

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
            req_addr = 16'h0000;
            req_rw = 1;
            req_burst = 0;
            req_beats = 0;
            req_valid = 1;
            while(!req_ready || !req_valid) begin
                #1;
            end
            -> write_trigger;
        end
    end //wrsingle
    
    event rdburst_trigger;
    
    initial
    begin: RDBURST
        forever begin
            @(rdburst_trigger);
            cnt = 0;
            MAXCNT = RDBURST_LENGTH;
            packets[0:RDBURST_LENGTH-1] = rdburst_data;
            req_addr = 16'h0000;
            req_rw = 0;
            req_burst = 1;
            req_beats = RDBURST_LENGTH;
            req_valid = 1;
            while(!req_ready || !req_valid) begin
                #1;
             end
             -> read_trigger;
         end
     end


    //build test run from blocks
    //use wrsingle_trigger, wrtwo_trigger and wraddr_trigger for corresponding test run.
    initial
    begin: TEST_RUN
        #10     -> reset_trigger;
        @(reset_done_trigger)
            -> wrburst_trigger;
        @(transfer_done_trigger);
            -> wrsingle_trigger;
        @(transfer_done_trigger);
    end

endmodule