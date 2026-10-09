`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Digilent Inc
// Engineer: Arthur Brown
// 
// Create Date: 03/23/2018 11:53:54 AM
// Design Name: Arty-A7-100-Pmod-I2S2
// Module Name: top
// Project Name: 
// Target Devices: Arty A7 100
// Tool Versions: Vivado 2017.4
// Description: Implements a volume control stream from Line In to Line Out of a Pmod I2S2 on port JA
// 
// Revision:
// Revision 0.01 - File Created
// 
//////////////////////////////////////////////////////////////////////////////////

module top #(
	parameter NUMBER_OF_SWITCHES = 4,
	parameter RESET_POLARITY = 0
) (
    input wire       clk,
    input wire [NUMBER_OF_SWITCHES-1:0] sw,
    input wire [3:0] btn,
    input wire       reset,
    
    output wire [3:0] led,
    
    // Pmod SSD ports (JB)
    output wire [6:0] pmod_jb_seg,
    output wire       pmod_jb_cat,
    
    output wire     tx_mclk,
    output wire     tx_lrck,
    output wire     tx_sclk,
    output wire     tx_data,
    output wire     rx_mclk,
    output wire     rx_lrck,
    output wire     rx_sclk,
    input  wire     rx_data
);
    wire axis_clk;
    
    wire [23:0] axis_tx_data;
    wire axis_tx_valid;
    wire axis_tx_ready;
    wire axis_tx_last;
    
    wire [23:0] axis_rx_data;
    wire axis_rx_valid;
    wire axis_rx_ready;
    wire axis_rx_last;

    wire [3:0] param_select; // 0: Mode, 1: Dtime, 2: Feedback, 3: Elevel
    wire [2:0] active_value; // 0-7 érték az adott paraméterhez

	wire resetn = (reset == RESET_POLARITY) ? 1'b0 : 1'b1;
	
	//clk IP instant
    clk_wiz_0 m_clk (
        .clk_in1(clk),
        .axis_clk(axis_clk)
    );

    //I2S AXIS IF instant
    axis_i2s2 m_i2s2 (
        .axis_clk(axis_clk),
        .axis_resetn(resetn),
    
        .tx_axis_s_data(axis_tx_data),
        .tx_axis_s_valid(axis_tx_valid),
        .tx_axis_s_ready(axis_tx_ready),
        .tx_axis_s_last(axis_tx_last),
    
        .rx_axis_m_data(axis_rx_data),
        .rx_axis_m_valid(axis_rx_valid),
        .rx_axis_m_ready(axis_rx_ready),
        .rx_axis_m_last(axis_rx_last),
        
        .tx_mclk(tx_mclk),
        .tx_lrck(tx_lrck),
        .tx_sclk(tx_sclk),
        .tx_sdout(tx_data),
        .rx_mclk(rx_mclk),
        .rx_lrck(rx_lrck),
        .rx_sclk(rx_sclk),
        .rx_sdin(rx_data)
    );
    
    //DD-8 Parameter mapping
        wire [2:0] dd8_mode_sel;
        wire [2:0] dd8_dtime;
        wire [2:0] dd8_feedback;
        wire [2:0] dd8_elevel;
        wire       dd8_enable = sw[0];
    
    // Button ctrl instant
        btn_ctrl #(
            .CLK_FREQ_HZ(100_000_000)
        ) u_btn_ctrl (
            .clk       (axis_clk),
            .resetn    (resetn),
            
            .btn0_sel  (btn[0]), // Parameter stepping (LED0 -> LED1 -> LED2 -> LED3)
            .btn1_up   (btn[2]), // Value +1
            .btn2_down (btn[1]), // Value -1
            
            .mode_sel  (dd8_mode_sel),
            .dtime     (dd8_dtime),
            .feedback  (dd8_feedback),
            .elevel    (dd8_elevel),
            
            .led       (led)      // Feedback LEDs
        );
    
    // SSD MUX
    reg [3:0] ssd_digit_left;  // Parameter identifier (0: Mode, 1: DTime, 2: Feedback, 3: ELevel)
    reg [3:0] ssd_digit_right; // Value of the selected parameter (0-7)

    always @(*) begin
        case (led)
            4'b0001: begin // LED0  -> MODE 
                ssd_digit_left  = 4'h0;
                ssd_digit_right = {1'b0, dd8_mode_sel};
            end
            4'b0010: begin // LED1 ég -> DTIME 
                ssd_digit_left  = 4'hD;
                ssd_digit_right = {1'b0, dd8_dtime};
            end
            4'b0100: begin // LED2 ég -> FEEDBACK 
                ssd_digit_left  = 4'hF;
                ssd_digit_right = {1'b0, dd8_feedback};
            end
            4'b1000: begin // LED3 ég -> E.LEVEL 
                ssd_digit_left  = 4'hE;
                ssd_digit_right = {1'b0, dd8_elevel};
            end
            default: begin
                ssd_digit_left  = 4'h0;
                ssd_digit_right = {1'b0, dd8_mode_sel};
            end
        endcase
    end

    //PMOD SSD CTRL instant
    pmod_ssd_ctrl u_pmod_ssd(
            .clk        (axis_clk),
            .rst        (~resetn),
            .digit_left (ssd_digit_left),
            .digit_right(ssd_digit_right),
            .ssd_seg     (pmod_jb_seg),
            .ssd_cat     (pmod_jb_cat)
    );
    
    
    //DD-8 Axi-stram wrapper instant
    axis_dd8_wrapper #(
            .DATA_WIDTH(24)
        ) m_dd8_effect (
            .clk           (axis_clk),
            .resetn        (resetn),
    
            // ctrl 
            .mode_sel      (dd8_mode_sel),
            .dtime         (dd8_dtime),
            .feedback      (dd8_feedback),
            .elevel        (dd8_elevel),
            .enable        (dd8_enable),
    
            // AXI-Stream RX (Input Audio)
            .s_axis_data   (axis_rx_data),
            .s_axis_valid  (axis_rx_valid),
            .s_axis_ready  (axis_rx_ready),
            .s_axis_last   (axis_rx_last),
    
            // AXI-Stream TX (Output Audio)
            .m_axis_data   (axis_tx_data),
            .m_axis_valid  (axis_tx_valid),
            .m_axis_ready  (axis_tx_ready),
            .m_axis_last   (axis_tx_last)
        );
    
    
endmodule
