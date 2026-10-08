
`timescale 1ns / 1ps

module tb_dd8_core;

    // ---------------------------------------------------------
    // 1. Tesztjelek
    // ---------------------------------------------------------

    reg clk;
    reg new_sample;
    reg signed [23:0] sample_in;

    reg [2:0] mode_sel;
    reg [2:0] dtime;
    reg [2:0] feedback;
    reg [2:0] elevel;
    reg enable;

    wire signed [23:0] sample_out;

    integer pass_count;
    integer fail_count;

    // A vizsgalt modul peldanyositasa
    dd8_core dut (
        .clk        (clk),
        .new_sample (new_sample),
        .sample_in  (sample_in),
        .mode_sel   (mode_sel),
        .dtime      (dtime),
        .feedback   (feedback),
        .elevel     (elevel),
        .enable     (enable),
        .sample_out (sample_out)
    );

    // ---------------------------------------------------------
    // 2. Orajel eloallitasa
    // 10 ns-os periodus = 100 MHz
    // ---------------------------------------------------------

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // 3. Ellenorzo feladat
    //
    // Osszehasonlitja a tenyleges es vart kimenetet.
    // Eltérés esetén FAIL üzenetet ír ki.
    // ---------------------------------------------------------

    task automatic check_output(
        input string test_name,
        input logic signed [23:0] expected
    );
        begin
            if (sample_out !== expected) begin
                $display(
                    "FAIL: %s | vart=%0d, kapott=%0d",
                    test_name, expected, sample_out
                );
                fail_count = fail_count + 1;
            end
            else begin
                $display(
                    "PASS: %s | kimenet=%0d",
                    test_name, sample_out
                );
                pass_count = pass_count + 1;
            end
        end
    endtask

    // ---------------------------------------------------------
    // 4. Tesztvektorok
    // ---------------------------------------------------------

    initial begin
        pass_count = 0;
        fail_count = 0;

        // Kezdeti allapot
        new_sample = 1'b0;
        sample_in  = 24'sd0;
        mode_sel   = 3'd0;
        dtime      = 3'd0;
        feedback   = 3'd0;
        elevel     = 3'd7;
        enable     = 1'b0;

        $display("");
        $display("======================================");
        $display(" dd8_core SystemVerilog testbench");
        $display("======================================");

        // -----------------------------------------------------
        // TEST 1: Bypass pozitiv minta
        // Kikapcsolt effekt mellett a kimenet = bemenet.
        // -----------------------------------------------------

        sample_in = 24'sd1234567;
        #1;
        check_output("Bypass pozitiv minta", 24'sd1234567);

        // -----------------------------------------------------
        // TEST 2: Bypass negativ minta
        // Az elojelet is helyesen meg kell tartani.
        // -----------------------------------------------------

        sample_in = -24'sd1234567;
        #1;
        check_output("Bypass negativ minta", -24'sd1234567);

        // -----------------------------------------------------
        // TEST 3: Bypass nulla
        // -----------------------------------------------------

        sample_in = 24'sd0;
        #1;
        check_output("Bypass nulla", 24'sd0);

        // -----------------------------------------------------
        // TEST 4: Bypass maximum pozitiv ertek
        // -----------------------------------------------------

        sample_in = 24'sd8388607;
        #1;
        check_output("Bypass pozitiv hatar", 24'sd8388607);

        // -----------------------------------------------------
        // TEST 5: Bypass minimum negativ ertek
        // -----------------------------------------------------

        sample_in = -24'sd8388608;
        #1;
        check_output("Bypass negativ hatar", -24'sd8388608);

        // -----------------------------------------------------
        // A kovetkezo tesztek a kombinacios feldolgozast
        // vizsgaljak, kontrollalt kesleltetett mintaval.
        //
        // A force ideiglenesen rogzit egy belso jelet,
        // igy nem kell valos ido alatt kivarnunk a delay-t.
        // Ez szimulacios ellenorzes, nem hardveres muvelet.
        // -----------------------------------------------------

        enable = 1'b1;
        sample_in = 24'sd100;
        mode_sel = 3'd0;  // Standard
        elevel = 3'd7;    // wet_w = 8
        force dut.delayed_now = 24'sd1000000;
        #1;

        // Standard: wet_term = 1000000 * 8 / 8
        // Kimenet = 100 + 1000000
        check_output("Standard, teljes wet szint", 24'sd1000100);

        // -----------------------------------------------------
        // TEST 6: Wet szint skálázása
        // elevel=0 -> wet_w=1, azaz a jel 1/8-a.
        // -----------------------------------------------------

        elevel = 3'd0;
        #1;
        check_output("Standard, minimalis wet szint", 24'sd125100);

        // -----------------------------------------------------
        // TEST 7: Analog mód
        // write_rep = delayed_now >>> 1
        //           + delayed_now >>> 2
        //           = 750000.
        // Teljes wet szint mellett ez adódik a kimenethez.
        // -----------------------------------------------------

        mode_sel = 3'd1;
        elevel = 3'd7;
        #1;
        check_output("Analog mod", 24'sd750100);

        // -----------------------------------------------------
        // TEST 8: Pozitiv telites
        // A bemenet + a wet jel meghaladja a maximumot.
        // -----------------------------------------------------

        mode_sel = 3'd0;
        sample_in = 24'sd8000000;
        #1;
        check_output("Pozitiv kimeneti telites", 24'sd8388607);

        // -----------------------------------------------------
        // TEST 9: Negativ telites
        // -----------------------------------------------------

        sample_in = -24'sd8000000;
        force dut.delayed_now = -24'sd1000000;
        #1;
        check_output("Negativ kimeneti telites", -24'sd8388608);

        // A kenyszeritett jel elengedese
        release dut.delayed_now;

        // -----------------------------------------------------
        // 5. Eredmenyek
        // -----------------------------------------------------

        $display("");
        $display("======================================");
        $display(" TESZTEK EREDMENYE");
        $display(" PASS: %0d", pass_count);
        $display(" FAIL: %0d", fail_count);
        $display("======================================");

        if (fail_count == 0)
            $display("MINDEN TESZT SIKERES.");
        else
            $display("HIBA: legalabb egy teszt sikertelen.");

        $finish;
    end

endmodule