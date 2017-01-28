// Copyright 2016 by the authors
//
// Copyright and related rights are licensed under the Solderpad
// Hardware License, Version 0.51 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a
// copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing,
// software, hardware and materials distributed under this License is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the
// License.
//
// Authors:
//    Stefan Wallentowitz <stefan@wallentowitz.de>
//    Nicolai Gutmann     <nico.gutmann@tum.de>
import dii_package::dii_flit;
 
module osd_cdm_ads
    #(
     parameter DATA_WIDTH  = 16,
     parameter ADDR_WIDTH  = 32,
     parameter MAX_PKT_LEN = 'x
    )
    (
     input                      clk, rst,
     
     input dii_flit             debug_in, output debug_in_ready,
     output dii_flit            debug_out, input debug_out_ready,   
    
     input [9:0]                id,
     
     output reg                 stall, strobe, write,
     output reg [31:0]          data_in,
     output reg [15:0]              adr,
     
     input                      breakpoint, ack,
     input [31:0]               data_out
    );
    
    reg [15:0] mask;
    logic        reg_err; 
    logic [1:0]  reg_size;
    logic [15:0] reg_addr;
    logic reg_strobe; //intermediate strobe before address masking
    logic strobe_masked;
    logic reg_write;
    logic [15:0] wdata;
    logic [15:0] rdata;
    reg [31:0] data_in_reg;
    logic [31:0] nxt_data_in_reg;
    logic [15:0] nxt_adr;
    reg [15:0] rdata_reg;
    logic [15:0] nxt_rdata_reg;
    reg reg_ack;
    logic nxt_write;
    
    reg bp_encountered;
    
    
   osd_regaccess_layer
     #(.MODID(16'h6), .MODVERSION(16'h0),
       .MAX_REG_SIZE(16), .CAN_STALL(0))
   u_regaccess(.*,
               .reg_request(reg_strobe),
               .reg_write(reg_write),
               .reg_addr(reg_addr),
               .reg_wdata(wdata),
               .reg_rdata(rdata),
               .reg_ack(reg_ack),
               .reg_err(0),
               .stall(stall),
               .module_in (0),
               .module_in_ready (),
               .module_out (),
               .module_out_ready (0));
    
    
    assign mask = ~16'h8000;
    
    enum {
         STATE_IDLE, STATE_RECEIVE, STATE_WRITE, STATE_READ,
         STATE_TRANSMIT, STATE_FINISH_READ
         } state, nxt_state;
    
    always_ff @(posedge clk) begin
      if (rst) begin
         state <= STATE_IDLE;
      end else begin
         state <= nxt_state;     
      end
      
      data_in_reg <= nxt_data_in_reg;
      rdata_reg <= nxt_rdata_reg;
      adr <= nxt_adr; 
      write <= nxt_write;
    end
    
    

    
    always_comb begin
        nxt_state = state;
        
        nxt_adr = adr;
        nxt_data_in_reg = data_in_reg;
        nxt_rdata_reg = rdata_reg;
        nxt_write = write;
        strobe = 0;
        reg_ack = 0;
        
        data_in = data_in_reg;
        rdata = rdata_reg;
        
        //only core access if addr >= 0x8000
        if (reg_addr < 16'h8000) begin
            strobe_masked = 0;
        end else begin
            strobe_masked = reg_strobe;
        end
        
        reg_err = 0;

        if (reg_addr[15:7] == 9'h4) begin // 0x200
            reg_ack = 1;
            case (reg_addr)
            16'h200: rdata = 16'(DATA_WIDTH);
            16'h201: rdata = 16'(ADDR_WIDTH);
            default: reg_err = 1;
            endcase
        end
        
        if(breakpoint) begin
           bp_encountered = 1;
        end
        
        case (state)
           STATE_IDLE: begin
                    if (strobe_masked) begin
                        nxt_adr = reg_addr & mask;
                        if (reg_write) begin
                            nxt_state = STATE_RECEIVE;
                            nxt_data_in_reg[31:16] = wdata;
                            reg_ack = 1;
                            nxt_write = 1;
                        end else begin
                            nxt_state = STATE_READ;
                            nxt_write = 0;
                        end
                    end
            end
            STATE_RECEIVE: begin
                    if (strobe_masked) begin
                        nxt_state = STATE_WRITE;
                        nxt_data_in_reg[15:0] = wdata;
                        reg_ack = 1;
                    end
            end
            STATE_WRITE: begin
                    strobe = 1;
                    if (ack) begin
                        nxt_state = STATE_IDLE;
                    end
            end
            STATE_READ: begin
                    strobe = 1;
                    if (ack) begin
                        nxt_rdata_reg = data_out[31:16];
                        nxt_state = STATE_TRANSMIT;
                    end
            end
            STATE_TRANSMIT: begin
                    if (strobe_masked) begin
                        reg_ack = 1;
                        nxt_rdata_reg = data_out[15:0];
                        nxt_state = STATE_FINISH_READ;
                    end
            end
            STATE_FINISH_READ: begin
                    if (strobe_masked) begin
                        reg_ack = 1;
                        nxt_state = STATE_IDLE;
                    end
            end
        endcase //case (state)
                
    end    
endmodule
