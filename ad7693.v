`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/09/04 13:14:40
// Design Name: 
// Module Name: ad7693
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ad7693(
          
          input fpga_clk,
          input reset_n,
          
          output adc_cnv,
          output adc_sck,
          input adc_sdo,
          
          output [15:0]data_out,
          output data_ready
   //       output [5:0]state,
   //       output [31:0]adc_tcycle_cnt,
   //       output [31:0]adc_tcnv_cnt
          
    );
    
    //------------------------------------------------------
    //ADC  States
    parameter IDLE=6'b000001;
    parameter CNV_START=6'b000010;
    parameter CNV_END=6'b000100;
    parameter READ_DATA=6'b001000;
    parameter READ_END=6'b010000;
    parameter WAIT_END=6'b100000;
    
    //------------------------------------------------------
    //ADC Timing
    parameter real SYS_CLK=100; //100MHz
    parameter real ADC_CYCLE_TIME=2;//2us
    parameter real ADC_CNV_TIME=1.6;//Convert time 1.6us
    parameter [31:0] ADC_CYCLE_CNT= SYS_CLK*ADC_CYCLE_TIME-2;
    parameter [31:0] ADC_CNV_CNT= SYS_CLK*ADC_CNV_TIME-2;
    
    //-------------------------------------------------------
    //ADC serial clock period
    parameter ADC_SCK_PERIOD=5'd15;
    //------------------------------------------------------
    
    reg [5:0]state;
    reg [5:0]next_state;
    
    reg [15:0]adc_data;    
    reg data_ready_r;
    reg adc_cnv_r;
    //reg adc_sck_r;
   
    //-----------------------------------------------------
    reg adc_sck_en;
    reg [4:0]adc_sck_cnt;
    reg [31:0]adc_tcnv_cnt;
    reg [31:0]adc_tcycle_cnt;

    //------------------------------------------------------    
    always @(posedge fpga_clk or negedge reset_n)
      if(!reset_n) state <= IDLE;
      else state <= next_state;
    
   //-------------------------------------------------------
    
    always @(adc_tcnv_cnt or adc_tcycle_cnt or state)
       begin
         next_state <= IDLE;
         case(state)
              IDLE: begin
                      next_state <= CNV_START;
                     end
         CNV_START: begin
                      if(adc_tcnv_cnt==ADC_CNV_CNT) next_state <= CNV_END;
                      else next_state <= CNV_START;
                      end
           CNV_END: begin
                      next_state <= READ_DATA;
                      end
         READ_DATA: begin
                      if(adc_sck_cnt==ADC_SCK_PERIOD) next_state <= READ_END;
                      else next_state <= READ_DATA;
                      end
         READ_END: begin
                       next_state <= WAIT_END;
                      end
         WAIT_END: begin
                      if(adc_tcycle_cnt == ADC_CYCLE_CNT) next_state <= IDLE;
                      else next_state <= WAIT_END;
                      end
         default: begin
                     next_state <= IDLE;
                     end
        endcase
       end
   //-----------------------------------------------------------------------
   always @(posedge fpga_clk or negedge reset_n)
       if(!reset_n) adc_sck_en <= 1'b0;
       else if(state==READ_DATA) adc_sck_en <= 1'b1;
       else adc_sck_en <= 1'b0;
    
    //-------------------------------------------------------
    reg sck_gen;
    
    always @(posedge fpga_clk or negedge reset_n)
       if(!reset_n) sck_gen <= 1'b1;
      // else if(adc_sck_cnt==ADC_SCK_PERIOD) sck_gen<= 1'b1;
       else if(adc_sck_en)
                begin
                   sck_gen <= ~sck_gen;
                   //adc_sck_cnt <= adc_sck_cnt+1'b1;
                  end
    
    assign adc_sck=sck_gen;
    //------------------------------------------------------
   always @(posedge fpga_clk or negedge reset_n)
     if(!reset_n) 
             begin
                    data_ready_r <= 1'b0;
                    adc_cnv_r <= 1'b0;
                    adc_tcycle_cnt <= 32'd0;
                    adc_tcnv_cnt <= 32'd0;
               end
     else begin
             case(next_state)
                  IDLE: begin
                          data_ready_r <= 1'b0;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= 32'd0;
                          adc_tcnv_cnt <= 32'd0;
                          end
             CNV_START: begin
                          data_ready_r <= 1'b0;
                          adc_cnv_r <= 1'b1;
                          adc_tcycle_cnt <= adc_tcycle_cnt + 1'b1;
                          adc_tcnv_cnt <= adc_tcnv_cnt + 1'b1;
                          end      
               CNV_END: begin
                          data_ready_r <= 1'b0;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= adc_tcycle_cnt + 1'b1;
                          end      
              READ_DATA: begin
                          data_ready_r <= 1'b0;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= adc_tcycle_cnt + 1'b1;
                          end    
              READ_END: begin
                          data_ready_r <= 1'b1;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= adc_tcycle_cnt + 1'b1;
                          end                          
              WAIT_END: begin
                          data_ready_r <= 1'b1;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= adc_tcycle_cnt + 1'b1;
                          end  
              default: begin
                          data_ready_r <= 1'b0;
                          adc_cnv_r <= 1'b0;
                          adc_tcycle_cnt <= 32'd0;
                          adc_tcnv_cnt <= 32'd0;
                          end
              endcase
           end
       
   assign adc_cnv = adc_cnv_r;
   assign data_ready = data_ready_r;
  
  //---------------------------------------------------------------------
  always @(negedge sck_gen or negedge reset_n)
    if(!reset_n) begin
            adc_data <= 16'd0;
            adc_sck_cnt <= 6'd0;
            end
    else if (adc_sck_cnt==ADC_SCK_PERIOD)
             begin
               adc_sck_cnt <= 6'd0;
             end
    else if (adc_sck_cnt<ADC_SCK_PERIOD)
          begin
            adc_data <= {adc_data[14:0],adc_sdo};
            adc_sck_cnt <= adc_sck_cnt+ 1'b1;
           end
 
 assign data_out=adc_data;   
               
    
endmodule
