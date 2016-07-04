module mam_wb_if
    #(parameter                 DATA_WIDTH  = 16, // in bits, must be multiple of 16
    parameter                   ADDR_WIDTH  = 32)
    (input                      CLK_I, RST_I,

    input                       req_valid, // Start a new memory access request
    output reg                  req_ready, // Acknowledge the new memory access request
    input                       req_rw, // 0: Read, 1: Write
    input [ADDR_WIDTH-1:0]      req_addr, // Request base address
    input                       req_burst, // 0 for single beat access, 1 for incremental burst
    input [13:0]                req_beats, // Burst length in number of words

    input                       write_valid, // Next write data is valid
    input [DATA_WIDTH-1:0]      write_data, // Write data
    input [DATA_WIDTH/8-1:0]    write_strb, // Byte strobe if req_burst==0
    output reg                  write_ready, // Acknowledge this data item

    output reg                  read_valid, // Next read data is valid
    output reg [DATA_WIDTH-1:0] read_data, // Read data
    input                       read_ready, // Acknowledge this data item

    output reg                  STB_O,
    output reg                  CYC_O,
    input                       ACK_I,
    output reg                  WE_O,
    output reg [ADDR_WIDTH-1:0] ADDR_O,
    output reg [DATA_WIDTH-1:0] DAT_O,
    input [DATA_WIDTH-1:0]      DAT_I,
    output reg [2:0]            CTI_O,
    output reg [1:0]            BTE_O,
    output reg                     SEL_O
    );
    
    enum {
        STATE_IDLE, STATE_WRITE_LAST, STATE_WRITE_LAST_WAIT,
        STATE_WRITE, STATE_WRITE_WAIT,
        STATE_READ_LAST, STATE_READ_LAST_BURST, STATE_READ_LAST_WAIT,
        STATE_READ_START, STATE_READ, STATE_READ_WAIT
        } state, nxt_state;
    
    logic                   nxt_STB_O;
    logic                   nxt_CYC_O;
    logic                   nxt_WE_O;
    logic [2:0]             nxt_CTI_O;
    logic [1:0]             nxt_BTE_O;
    
    reg [DATA_WIDTH-1:0]    read_data_reg;
    logic [DATA_WIDTH-1:0]  nxt_read_data_reg;
    
    reg [DATA_WIDTH-1:0]    DAT_O_reg;
    logic [DATA_WIDTH-1:0]  nxt_DAT_O_reg;
    
    logic [ADDR_WIDTH-1:0]  nxt_ADDR_O;
    
    reg [13:0]              beats;
    logic [13:0]            nxt_beats;
    
    
    //registers
    always_ff @(posedge CLK_I) begin
        if (RST_I) begin
            state <= STATE_IDLE;
        end else begin
            state <= nxt_state;
        end
        

        STB_O <= nxt_STB_O;
        CYC_O <= nxt_CYC_O;
        WE_O <= nxt_WE_O;
        CTI_O <= nxt_CTI_O;
        BTE_O <= nxt_BTE_O;
        read_data_reg <= nxt_read_data_reg;
        DAT_O_reg <= nxt_DAT_O_reg;
        ADDR_O <= nxt_ADDR_O;
        beats <= nxt_beats;
    end
        
    //state & output logic
    always_comb begin
        nxt_state = state;
        nxt_STB_O = STB_O;
        nxt_CYC_O = CYC_O;
        nxt_WE_O = WE_O;
        nxt_CTI_O = CTI_O;
        nxt_BTE_O = 2'b0;
        nxt_read_data_reg = read_data_reg;
        nxt_DAT_O_reg = DAT_O_reg;
        nxt_ADDR_O = ADDR_O;
        nxt_beats = beats;
        SEL_O = 0;
        
        req_ready = 0;
        write_ready = 0;
        read_valid = 0;
        
        DAT_O = DAT_O_reg;
        read_data = read_data_reg;
        
        
        case (state)
            STATE_IDLE: begin
                req_ready = 1;
                if (req_valid) begin
                    nxt_beats = req_beats;
                    nxt_CYC_O = 1;
                    nxt_ADDR_O = req_addr;
                    if (req_rw) begin
                        nxt_WE_O = 1;
                        if (req_burst) begin
                            if (nxt_beats == 1) begin
                                nxt_CTI_O = 3'b111;
                                if (write_valid) begin
                                    nxt_state = STATE_WRITE_LAST;
                                    nxt_DAT_O_reg = write_data;
                                    nxt_STB_O = 1;
                                end else begin
                                    nxt_state = STATE_WRITE_LAST_WAIT;
                                    nxt_STB_O = 0;
                                end
                            end else begin
                                nxt_CTI_O = 3'b010;
                                nxt_BTE_O = 2'b00;
                                if (write_valid) begin
                                    nxt_state = STATE_WRITE;
                                    nxt_DAT_O_reg = write_data;
                                    nxt_STB_O = 1;
                                end else begin
                                    nxt_state = STATE_WRITE_WAIT;
                                    nxt_STB_O = 0;
                                end
                            end
                        end else begin // !req_burst
                            nxt_CTI_O = 3'b111;
                            if (write_valid) begin
                                nxt_state = STATE_WRITE_LAST;
                                    nxt_DAT_O_reg = write_data;
                                nxt_STB_O = 1;
                            end else begin
                                nxt_state = STATE_WRITE_LAST_WAIT;
                                nxt_STB_O = 0;
                            end                            
                        end // if (req_burst)
                    end else begin // req_rw == 0
                        nxt_WE_O = 0;
                        if (req_burst) begin
                            if (nxt_beats == 1) begin
                                nxt_CTI_O = 3'b111;
                                nxt_state = STATE_READ_LAST;
                                nxt_STB_O = 1;
                            end else begin
                                nxt_CTI_O = 3'b010;
                                nxt_state = STATE_READ_START;
                                nxt_STB_O = 1;
                            end
                        end else begin // !req_burst
                            nxt_CTI_O = 3'b111;
                            nxt_state = STATE_READ_LAST;
                            nxt_STB_O = 1;
                        end // if (req_burst)
                    end // if (req_rw)
                end // if (req_valid)
            end //STATE_IDLE
            STATE_WRITE_LAST_WAIT: begin
                write_ready = 1;
                nxt_STB_O = 0;
                if (write_valid) begin
                    nxt_state = STATE_WRITE_LAST;
                    nxt_STB_O = 1;
                    nxt_DAT_O_reg = write_data;
                end
            end //STATE_WRITE_LAST_WAIT
            STATE_WRITE_LAST: begin
                nxt_STB_O = 1;
                if (ACK_I) begin
                    nxt_state = STATE_IDLE;
                    nxt_CYC_O = 0;
                    nxt_STB_O = 0;
                    nxt_CTI_O = 3'b000;
                end
            end //STATE_WRITE_LAST
            STATE_WRITE_WAIT: begin
                write_ready = 1;
                nxt_STB_O = 0;
                if (write_valid) begin
                    nxt_state = STATE_WRITE;
                    nxt_STB_O = 1;
                    nxt_DAT_O_reg = write_data;
                    nxt_beats = beats - 1;
                end
            end //STATE_WRITE_WAIT
            STATE_WRITE: begin
                nxt_STB_O = 1;
                if (ACK_I) begin
                    write_ready = 1;
                    nxt_ADDR_O = ADDR_O + DATA_WIDTH/8;
                    if (beats == 1) begin
                        nxt_CTI_O=3'b111;
                        if (write_valid) begin
                            nxt_state = STATE_WRITE_LAST;
                            nxt_DAT_O_reg = write_data;
                        end else begin
                            nxt_state = STATE_WRITE_LAST_WAIT;
                            nxt_STB_O = 0;
                        end
                    end else begin // beats != 1
                        if (write_valid) begin
                            nxt_state = STATE_WRITE;
                            nxt_DAT_O_reg = write_data;
                            nxt_beats = beats - 1;
                        end else begin
                            nxt_state = STATE_WRITE_WAIT;
                            nxt_STB_O = 0;
                        end
                    end // if (beats == 1)
                end // if (ACK_I)
            end // STATE_WRITE
            STATE_READ_LAST: begin
                nxt_STB_O = 1;
                if (ACK_I) begin
                    nxt_STB_O = 0;
                    nxt_read_data_reg = DAT_I;
                    nxt_state = STATE_READ_LAST_WAIT;
                end
            end //STATE_READ_LAST
            STATE_READ_LAST_WAIT: begin
                nxt_STB_O = 0;
                read_valid = 1;
                if (read_ready) begin
                    nxt_state = STATE_IDLE;
                    nxt_CYC_O = 0;
                    nxt_CTI_O = 3'b000;
                end
            end // STATE_READ_LAST_WAIT
            STATE_READ_START: begin
                nxt_STB_O = 1;
                if (ACK_I) begin
                    nxt_read_data_reg = DAT_I;                    
                    nxt_beats = beats - 1;
                    nxt_ADDR_O = ADDR_O + DATA_WIDTH/8;
                    if (nxt_beats == 1) begin
                        nxt_state = STATE_READ_LAST_BURST;
                        nxt_CTI_O = 3'b111;
                    end else begin
                        if (read_ready) begin
                            nxt_state = STATE_READ;
                        end else begin
                            nxt_STB_O = 0;
                            nxt_state = STATE_READ_WAIT;
                        end
                    end
                end
			end
            STATE_READ: begin
                nxt_STB_O = 1;
                read_valid = 1;
                if (ACK_I) begin
                    nxt_read_data_reg = DAT_I;
                    nxt_beats = beats - 1;
                    nxt_ADDR_O = ADDR_O + DATA_WIDTH/8;
                    if (nxt_beats == 1) begin
                        nxt_state = STATE_READ_LAST_BURST;
                        nxt_CTI_O = 3'b111;
                    end else begin
                        if (read_ready) begin
                            nxt_state = STATE_READ;
                        end else begin
                            nxt_STB_O = 0;
                            nxt_state = STATE_READ_WAIT;
                        end
                    end
                end else begin
                    nxt_state = STATE_READ_START;
                end
            end //STATE_READ
            STATE_READ_WAIT: begin
                nxt_STB_O = 0;
                read_valid = 1;
                if (read_ready) begin
                    nxt_STB_O = 1;
                    nxt_state = STATE_READ_START;
                end
            end //STATE_READ_WAIT
            STATE_READ_LAST_BURST: begin
                read_valid = 1;
                nxt_STB_O = 1;
                if (ACK_I) begin
                    nxt_STB_O = 0;
                    nxt_read_data_reg = DAT_I;
                    nxt_state = STATE_READ_LAST_WAIT;
                end else begin
                    nxt_state = STATE_READ_LAST;
                end
            end //STATE_READ_LAST_BURST
        endcase// Case (state)
    end // always_comb

endmodule
