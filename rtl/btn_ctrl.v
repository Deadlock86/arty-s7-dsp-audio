`timescale 1ns / 1ps

module btn_ctrl #(
    parameter CLK_FREQ_HZ = 100_000_000 // axis_clk frekvenciája (100 MHz)
)(
    input  wire       clk,
    input  wire       resetn,
    
    // Fizikai gombok az Arty S7 kártyáról
    input  wire       btn0_sel,   // Paraméter választó (Mode -> Dtime -> Feedback -> E.Level)
    input  wire       btn1_up,    // Érték +1
    input  wire       btn2_down,  // Érték -1
    
    // Regiszterezett DD-8 paraméterek
    output reg  [2:0] mode_sel,
    output reg  [2:0] dtime,
    output reg  [2:0] feedback,
    output reg  [2:0] elevel,
    
    // LED-es visszajelzés (melyik paramétert állítjuk éppen)
    output reg  [3:0] led
);

    // =========================================================================
    // 1. PRELLMENTESÍTÕ ÉS ÉL-DETEKTOR LOGIKA (~10ms idõzítéssel)
    // =========================================================================
    localparam integer DEBOUNCE_LIMIT = CLK_FREQ_HZ / 100; // 10ms-os számláló
    
    function [0:0] get_pulse;
        input wire btn_raw;
        input wire [19:0] cnt;
        input wire state;
        input wire state_d;
        begin
            get_pulse = state && !state_d;
        end
    endfunction

    // Gomb 0 szinkronizáció és prellmentesítés
    reg [2:0] sync0; reg [19:0] cnt0; reg state0, state0_d;
    // Gomb 1 szinkronizáció és prellmentesítés
    reg [2:0] sync1; reg [19:0] cnt1; reg state1, state1_d;
    // Gomb 2 szinkronizáció és prellmentesítés
    reg [2:0] sync2; reg [19:0] cnt2; reg state2, state2_d;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sync0 <= 0; cnt0 <= 0; state0 <= 0; state0_d <= 0;
            sync1 <= 0; cnt1 <= 0; state1 <= 0; state1_d <= 0;
            sync2 <= 0; cnt2 <= 0; state2 <= 0; state2_d <= 0;
        end else begin
            // 2-fokozatú metastabilitás elleni szinkronizáció
            sync0 <= {sync0[1:0], btn0_sel};
            sync1 <= {sync1[1:0], btn1_up};
            sync2 <= {sync2[1:0], btn2_down};

            // BTN0 prellmentesítõ
            if (sync0[2] != state0) begin
                cnt0 <= cnt0 + 1'b1;
                if (cnt0 >= DEBOUNCE_LIMIT) begin state0 <= sync0[2]; cnt0 <= 0; end
            end else cnt0 <= 0;

            // BTN1 prellmentesítõ
            if (sync1[2] != state1) begin
                cnt1 <= cnt1 + 1'b1;
                if (cnt1 >= DEBOUNCE_LIMIT) begin state1 <= sync1[2]; cnt1 <= 0; end
            end else cnt1 <= 0;

            // BTN2 prellmentesítõ
            if (sync2[2] != state2) begin
                cnt2 <= cnt2 + 1'b1;
                if (cnt2 >= DEBOUNCE_LIMIT) begin state2 <= sync2[2]; cnt2 <= 0; end
            end else cnt2 <= 0;

            // Él-detektálók frissítése
            state0_d <= state0;
            state1_d <= state1;
            state2_d <= state2;
        end
    end

    // 1-ciklus széles impulzusok a gombnyomások pillanatában
    wire pulse_sel  = state0 && !state0_d;
    wire pulse_up   = state1 && !state1_d;
    wire pulse_down = state2 && !state2_d;

    // =========================================================================
    // 2. PARAMÉTER VÁLASZTÓ ÉS NÖVELÕ/CSÖKKENTÕ LOGIKA
    // =========================================================================
    // 0: Mode, 1: Dtime, 2: Feedback, 3: Elevel
    reg [1:0] param_sel;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            param_sel <= 2'd0;
            mode_sel  <= 3'd0; // Standard mode
            dtime     <= 3'd3; // Alapértelmezett delay idõ
            feedback  <= 3'd4; // Alapértelmezett feedback
            elevel    <= 3'd4; // Alapértelmezett wet level
        end else begin
            // Paraméter váltás (BTN0)
            if (pulse_sel) begin
                param_sel <= param_sel + 1'b1;
            end

            // Érték módosítás (BTN1: +1, BTN2: -1)
            if (pulse_up) begin
                case (param_sel)
                    2'd0: if (mode_sel < 3'd7) mode_sel <= mode_sel + 1'b1;
                    2'd1: if (dtime    < 3'd7) dtime    <= dtime    + 1'b1;
                    2'd2: if (feedback < 3'd7) feedback <= feedback + 1'b1;
                    2'd3: if (elevel   < 3'd7) elevel   <= elevel   + 1'b1;
                endcase
            end else if (pulse_down) begin
                case (param_sel)
                    2'd0: if (mode_sel > 3'd0) mode_sel <= mode_sel - 1'b1;
                    2'd1: if (dtime    > 3'd0) dtime    <= dtime    - 1'b1;
                    2'd2: if (feedback > 3'd0) feedback <= feedback - 1'b1;
                    2'd3: if (elevel   > 3'd0) elevel   <= elevel   - 1'b1;
                endcase
            end
        end
    end

    // =========================================================================
    // 3. LED VISSZAJELZÉS (Melyik paramétert módosítjuk éppen)
    // =========================================================================
    always @(*) begin
        case (param_sel)
            2'd0: led = 4'b0001; // LED0 ég  -> MODE állítás
            2'd1: led = 4'b0010; // LED1 ég  -> DTIME állítás
            2'd2: led = 4'b0100; // LED2 ég  -> FEEDBACK állítás
            2'd3: led = 4'b1000; // LED3 ég  -> ELEVEL állítás
        endcase
    end

endmodule
