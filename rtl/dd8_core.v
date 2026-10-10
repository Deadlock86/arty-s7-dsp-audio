`timescale 1ns / 1ps
// dd8_core.v - BOSS DD-8 inspired multi-mode delay
//
// Inspired by the BOSS DD-8 feature set: multiple delay types such as
// Standard, Analog, Tape, Warm, Reverse, +RV, Shimmer, Mod, Warp, GLT,
// and Loop are part of the real pedal's public mode list.
// This RTL implements a practical subset suitable for Verilator simulation:
//   mode_sel[2:0]
//     0 = Standard  (clean digital)
//     1 = Analog    (dark repeats)
//     2 = Tape      (dark + slight modulation)
//     3 = Warm      (soft digital)
//     4 = Reverse   (reverse-style short block playback)
//     5 = +RV       (delay + simple ambience)
//     6 = Shimmer   (delay + octave-up style blend)
//     7 = Mod       (delay + modulation)
//
// Controls map to the DD-8 style front panel:
//   dtime    [2:0] : delay time
//   feedback [2:0] : repeats / regeneration
//   elevel   [2:0] : effect level (wet amount)
//   enable         : bypass
//
// Notes:
// - This is an approximation, not a full recreation of every DD-8 mode.
// - Reverse mode uses block-wise reverse playback for a practical simulation.
// - +RV uses a short ambience diffuser instead of a full reverb engine.
// - Shimmer uses a simple octave-like absolute-value blend on repeats.

module dd8_core(
    input  wire                clk,
    input  wire                new_sample,
    input  wire signed [23:0] sample_in,
    input  wire [2:0]          mode_sel,
    input  wire [2:0]          dtime,
    input  wire [2:0]          feedback,
    input  wire [2:0]          elevel,
    input  wire                enable,
    output reg  signed [23:0] sample_out
);

    localparam integer BUF_LEN = 65536;

    // BRAM attribútum + Memória tömb
    (* ram_style = "block" *) reg signed [23:0] delay_mem [0:BUF_LEN-1];
    reg [15:0] wr_ptr = 16'd0;

    // -------------------------------------------------------------------------
    // 1. Parameter Look-Up Tables
    // -------------------------------------------------------------------------
    reg [15:0] delay_samps;
    always @(*) begin
        case (dtime)
            3'd0: delay_samps = 16'd4410;   // ~100 ms 
            3'd1: delay_samps = 16'd8820;   // ~200 ms 
            3'd2: delay_samps = 16'd17640;  // ~400 ms 
            3'd3: delay_samps = 16'd26460;  // ~600 ms 
            3'd4: delay_samps = 16'd35280;  // ~800 ms 
            3'd5: delay_samps = 16'd44100;  // ~1000 ms
            3'd6: delay_samps = 16'd52920;  // ~1200 ms 
            default: delay_samps = 16'd64400; // ~1460 ms 
               
  /*      
            3'd0: delay_samps = 16'd1103;
            3'd1: delay_samps = 16'd2205;
            3'd2: delay_samps = 16'd4410;
            3'd3: delay_samps = 16'd6615;
            3'd4: delay_samps = 16'd8820;
            3'd5: delay_samps = 16'd13230;
            3'd6: delay_samps = 16'd17640;
            default: delay_samps = 16'd26460;
*/
        endcase
    end

    reg [3:0] fb_w;
    always @(*) begin
        case (feedback)
            3'd0: fb_w = 4'd0;
            3'd1: fb_w = 4'd2;
            3'd2: fb_w = 4'd3;
            3'd3: fb_w = 4'd4;
            3'd4: fb_w = 4'd5;
            3'd5: fb_w = 4'd6;
            3'd6: fb_w = 4'd7;
            default: fb_w = 4'd7;
        endcase
    end

    reg [3:0] wet_w;
    always @(*) begin
        case (elevel)
            3'd0: wet_w = 4'd1;
            3'd1: wet_w = 4'd2;
            3'd2: wet_w = 4'd3;
            3'd3: wet_w = 4'd4;
            3'd4: wet_w = 4'd5;
            3'd5: wet_w = 4'd6;
            3'd6: wet_w = 4'd7;
            default: wet_w = 4'd8;
        endcase
    end

    // -------------------------------------------------------------------------
    // 2. Olvasási mutatók kiszámítása
    // -------------------------------------------------------------------------
    wire [15:0] rd_ptr = wr_ptr - delay_samps;

    // Reverse mutató számítása
    reg [15:0] rev_count = 16'd0;
    reg [15:0] rev_base = 16'd0;
    
    wire [15:0] rev_ptr  = rev_base + (delay_samps - 16'd1 - rev_count);

    // LFO / Moduláció mutató számítása
    reg [17:0] lfo_phase = 18'd0;
    wire [16:0] lfo_tri = lfo_phase[17] ? ~lfo_phase[16:0] : lfo_phase[16:0];
    wire [7:0] mod_ofs = lfo_tri[16:9];
    wire [15:0] mod_ptr = rd_ptr + {8'd0, mod_ofs};

    // -------------------------------------------------------------------------
    // 3. EGYETLEN AKTÍV CÍM KIVÁLASZTÁSA (Cím MUX)
    // -------------------------------------------------------------------------
    reg [15:0] active_rd_ptr;
    always @(*) begin
        case (mode_sel)
            3'd2, 3'd7: active_rd_ptr = mod_ptr; // Tape & Modulate mód
            3'd4:       active_rd_ptr = rev_ptr; // Reverse mód
            default:    active_rd_ptr = rd_ptr;  // Standard, Analog, Warm, +RV, Shimmer
        endcase
    end

    // -------------------------------------------------------------------------
    // 4. BRAM ÍRÁS ÉS TISZTA SZINKRON OLVASÁS (Dual-Port BRAM minta)
    // -------------------------------------------------------------------------
    reg signed [23:0] delayed_now;

    always @(posedge clk) begin
        if (new_sample) begin
            // BRAM read/write
            delay_mem[wr_ptr] <= write_samp;
            delayed_now <= delay_mem[active_rd_ptr];

            // Mutatók és számlálók léptetése
            wr_ptr <= wr_ptr + 16'd1;
            lfo_phase <= lfo_phase + 18'd113;

            if (rev_count >= delay_samps - 16'd1) begin
                rev_count <= 16'd0;
                rev_base <= wr_ptr - delay_samps;
            end else
                rev_count <= rev_count + 16'd1;
        end
    end

    // -------------------------------------------------------------------------
    // 5. Effektus feldolgozás a BRAM-ból kiolvasott adaton
    // -------------------------------------------------------------------------
    reg signed [23:0] write_rep;
    reg signed [23:0] wet_rep;
    reg signed [23:0] shimmer_rep;

    always @(*) begin
        shimmer_rep = delayed_now[23] ? (~delayed_now + 24'sd1) : delayed_now;
        
        case (mode_sel)
            3'd0: begin // Standard
                write_rep = delayed_now;
                wet_rep   = delayed_now;
            end
            3'd1: begin // Analog 
                write_rep = (delayed_now >>> 1) + (delayed_now >>> 2);
                wet_rep   = write_rep;
            end
            3'd2: begin // Tape
                write_rep = (delayed_now >>> 1) + (delayed_now >>> 2);
                wet_rep   = write_rep;
            end
            3'd3: begin // Warm
                write_rep = (delayed_now >>> 1) + (delayed_now >>> 3);
                wet_rep   = write_rep;
            end
            3'd4: begin // Reverse
                write_rep = delayed_now;
                wet_rep   = delayed_now;
            end
            3'd5: begin // +RV (Egyszerûsített csengés)
                write_rep = delayed_now;
                wet_rep   = delayed_now + (delayed_now >>> 2);
            end
            3'd6: begin // Shimmer
                write_rep = delayed_now;
                wet_rep   = (delayed_now >>> 1) + (shimmer_rep >>> 1);
            end
            default: begin // Mod
                write_rep = delayed_now;
                wet_rep   = delayed_now;
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // 6. Visszacsatolás és Kimeneti Keverés (Fixpontos Telítõdés)
    // -------------------------------------------------------------------------
    wire signed [28:0] in_ext = {{5{sample_in[23]}}, sample_in};
    wire signed [28:0] rep_ext = {{5{write_rep[23]}}, write_rep};
    
    (* use_dsp = "yes" *) wire signed [32:0] fb_mult = rep_ext * $signed({1'b0, fb_w});
    wire signed [28:0] fb_term = fb_mult >>> 3;
    wire signed [28:0] write_sum = in_ext + fb_term;

    reg signed [23:0] write_samp;
    always @(*) begin
        if (write_sum > 29'sd8388607)
            write_samp = 24'sd8388607;
        else if (write_sum < -29'sd8388608)
            write_samp = -24'sd8388608;
        else
            write_samp = write_sum[23:0];
    end

    wire signed [28:0] wet_ext = {{5{wet_rep[23]}}, wet_rep};
    
    (* use_dsp = "yes" *) wire signed [32:0] wet_mult = wet_ext * $signed({1'b0, wet_w});
    wire signed [28:0] wet_term = wet_mult >>> 3;
    wire signed [28:0] out_sum = in_ext + wet_term;

    reg signed [23:0] dd8_out;
    always @(*) begin
        if (out_sum > 29'sd8388607)
            dd8_out = 24'sd8388607;
        else if (out_sum < -29'sd8388608)
            dd8_out = -24'sd8388608;
        else
            dd8_out = out_sum[23:0];
    end

    always @(*) begin
        sample_out = enable ? dd8_out : sample_in;
    end

endmodule

