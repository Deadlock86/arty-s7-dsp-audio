`timescale 1ns / 1ps

module pmod_ssd_ctrl (
    input  wire       clk,         // 100 MHz rendszer órajel
    input  wire       rst,         // Aszinkron reset
    input  wire [3:0] digit_left,  // Bal oldali digit értéke (0-15 / 0-F)
    input  wire [3:0] digit_right, // Jobb oldali digit értéke (0-15 / 0-F)
    output reg  [6:0] ssd_seg,     // 7 szegmens kimenet {G, F, E, D, C, B, A}
    output reg        ssd_cat      // Digit választó (0 = Bal digit, 1 = Jobb digit)
);

    // =========================================================================
    // 1. Órajel-osztó a multiplexáláshoz (~763 Hz frissítési frekvencia)
    // 100 MHz / 2^17 = ~763 Hz (a két digit között ~1.3 ms-onként vált)
    // =========================================================================
    reg [16:0] refresh_counter = 0;

    always @(posedge clk or posedge rst) begin
        if (rst)
            refresh_counter <= 17'd0;
        else
            refresh_counter <= refresh_counter + 1'b1;
    end

    wire active_digit = refresh_counter[16]; // 0: Bal, 1: Jobb

    // =========================================================================
    // 2. Aktuális hexadecimális karakter kiválasztása
    // =========================================================================
    wire [3:0] current_hex = active_digit ? digit_left : digit_right;

    // =========================================================================
    // 3. Hex-to-7Segment dekóder (Aktív HIGH szegmensek)
    // Bit kiosztás: [6:0] -> {G, F, E, D, C, B, A}
    // =========================================================================
    function [6:0] decode_7seg(input [3:0] hex);
        case (hex)
            4'h0: decode_7seg = 7'b011_1111; // 0
            4'h1: decode_7seg = 7'b000_0110; // 1
            4'h2: decode_7seg = 7'b101_1011; // 2
            4'h3: decode_7seg = 7'b100_1111; // 3
            4'h4: decode_7seg = 7'b110_0110; // 4
            4'h5: decode_7seg = 7'b110_1101; // 5
            4'h6: decode_7seg = 7'b111_1101; // 6
            4'h7: decode_7seg = 7'b000_0111; // 7
            4'h8: decode_7seg = 7'b111_1111; // 8
            4'h9: decode_7seg = 7'b110_1111; // 9
            4'hA: decode_7seg = 7'b111_0111; // A
            4'hB: decode_7seg = 7'b111_1100; // b
            4'hC: decode_7seg = 7'b011_1001; // C
            4'hD: decode_7seg = 7'b101_1110; // d
            4'hE: decode_7seg = 7'b011_1001; // E (vagy 7'b111_1001)
            4'hF: decode_7seg = 7'b111_0001; // F
            default: decode_7seg = 7'b000_0000;
        endcase
    endfunction

    // =========================================================================
    // 4. Kimenetek frissítése regiszterezve (Glitch-mentes)
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ssd_cat <= 1'b0;
            ssd_seg <= 7'b000_0000;
        end else begin
            ssd_cat <= active_digit;
            ssd_seg <= decode_7seg(current_hex);
        end
    end

endmodule