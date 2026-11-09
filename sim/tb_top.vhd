library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

-- Top-level test against the Quartus post-synthesis netlist
-- (simulation/questa/QuadrupleBuffer.vho), not the RTL sources.
--
-- It proves the schematic wiring and the PLL path end to end:
--   50 MHz CLK -> altpll (cycloneive_pll) -> 5.12 MHz CLK_8
--   MISC_B -> RSS filter -> UARTReader -> Distribute -> AllChannels -> DATA
--
-- A short frame turns channels 0..7 off; DATA(0) must then go quiet while
-- DATA(1) (channels 8..15) keeps running. LED(1) (debug_swap) must toggle.
--
-- The netlist is a build product: compile the project in Quartus first so
-- simulation/questa/QuadrupleBuffer.vho exists.
entity tb_top is
end entity;

architecture sim of tb_top is

    constant CLK_PERIOD : time := 20 ns;          -- 50 MHz PLL input
    constant BIT_PERIOD : time := 25976562 ps;    -- 133 x / 5.12 MHz

    signal clk     : std_logic := '0';
    signal uart_rx : std_logic := '1';
    signal tms     : std_logic := '0';
    signal tck     : std_logic := '0';
    signal tdi     : std_logic := '0';
    signal tdo     : std_logic;
    signal shift_clock_1 : std_logic;
    signal shift_clock_2 : std_logic;
    signal latch_clock_1 : std_logic;
    signal latch_clock_2 : std_logic;
    signal misc_e  : std_logic;
    signal misc_d  : std_logic;
    signal data    : std_logic_vector(31 downto 0);
    signal led     : std_logic_vector(3 downto 0);
    signal finished : boolean := false;

    signal d0_edges : integer := 0;
    signal d1_edges : integer := 0;
    signal md_edges : integer := 0;
    signal sc_edges : integer := 0;

    procedure check(cond : boolean; msg : string) is
    begin
        assert cond report "FAIL: " & msg severity failure;
    end procedure;

begin

    clk <= not clk after CLK_PERIOD / 2 when not finished else '0';

    dut : entity work.QuadrupleBuffer
        port map (
            altera_reserved_tms => tms,
            altera_reserved_tck => tck,
            altera_reserved_tdi => tdi,
            altera_reserved_tdo => tdo,
            CLK           => clk,
            MISC_B        => uart_rx,
            SHIFT_CLOCK_1 => shift_clock_1,
            SHIFT_CLOCK_2 => shift_clock_2,
            LATCH_CLOCK_1 => latch_clock_1,
            LATCH_CLOCK_2 => latch_clock_2,
            MISC_E        => misc_e,
            MISC_D        => misc_d,
            DATA          => data,
            LED           => led
        );

    -- Count activity on the DATA lines and on MISC_D / shift clock.
    activity : process (clk)
        variable p0, p1, pd, ps : std_logic := '0';
        variable c0, c1, cd, cs : integer := 0;
    begin
        if rising_edge(clk) then
            if data(0) /= p0 then c0 := c0 + 1; p0 := data(0); end if;
            if data(1) /= p1 then c1 := c1 + 1; p1 := data(1); end if;
            if misc_d  /= pd then cd := cd + 1; pd := misc_d;  end if;
            if shift_clock_1 /= ps then cs := cs + 1; ps := shift_clock_1; end if;
        end if;
        d0_edges <= c0;
        d1_edges <= c1;
        md_edges <= cd;
        sc_edges <= cs;
    end process;

    stimulus : process
        variable base0, base1 : integer;
        variable u : std_logic_vector(7 downto 0);
        type byte_array is array (natural range <>) of integer range 0 to 255;
        constant frame : byte_array := (
            254,                                    -- 0xFE
            16, 16, 16, 16, 16, 16, 16, 16,         -- channels 0..7 off
            253                                     -- 0xFD
        );
    begin
        -- Let the PLL start and the reset-less logic settle.
        wait for 100 us;

        check(led(3) = '1', "shift clocks enabled (LED3)");
        check(misc_e = uart_rx, "MISC_E mirrors MISC_B");

        base0 := d0_edges;
        base1 := d1_edges;
        wait for 200 us;
        report "pre-frame: DATA0=" & integer'image(d0_edges - base0) &
               " DATA1=" & integer'image(d1_edges - base1) &
               " MISC_D=" & integer'image(md_edges) &
               " SHIFT=" & integer'image(sc_edges) severity note;
        check(d0_edges - base0 > 10, "DATA(0) active before frame, edges=" &
              integer'image(d0_edges - base0));
        check(d1_edges - base1 > 10, "DATA(1) active before frame, edges=" &
              integer'image(d1_edges - base1));
        check(md_edges > 0, "MISC_D (COUNT(7)) toggling");
        check(sc_edges > 0, "SHIFT_CLOCK toggling");

        -- Stream the frame at 38.4 kBaud, 8N1 with an idle bit between bytes.
        wait for 100 us;
        for i in frame'range loop
            uart_rx <= '0';
            wait for BIT_PERIOD;

            u := std_logic_vector(to_unsigned(frame(i), 8));
            for b in 0 to 7 loop
                uart_rx <= u(b);
                wait for BIT_PERIOD;
            end loop;

            uart_rx <= '1';
            wait for BIT_PERIOD;
            wait for BIT_PERIOD;
        end loop;

        wait for 200 us;
        check(led(1) = '1', "0xFD toggled debug_swap (LED1)");

        base0 := d0_edges;
        base1 := d1_edges;
        wait for 200 us;
        report "post-frame: DATA0=" & integer'image(d0_edges - base0) &
               " DATA1=" & integer'image(d1_edges - base1) &
               " MISC_D=" & integer'image(md_edges) &
               " SHIFT=" & integer'image(sc_edges) severity note;

        -- The frame turns channels 0..7 off, so DATA(0) must go quiet while
        -- DATA(1) (channels 8..15, not written) keeps running.
        --
        -- This used to fail: PulseExpander glitched whenever its input was
        -- held high, which re-triggered the PhaseLine swap continuously.
        -- Fixed in src/PulseExpander.vhd; tb_glue covers the same path in
        -- RTL.
        check(d0_edges = base0,
              "DATA(0) quiet after channels 0..7 off, edges=" &
              integer'image(d0_edges - base0));
        check(d1_edges - base1 > 10, "DATA(1) still active, edges=" &
              integer'image(d1_edges - base1));

        finished <= true;
        report "TEST PASSED: tb_top" severity note;
        wait;
    end process;

end architecture;
