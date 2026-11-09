library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_AllChannels is
end tb_AllChannels;

architecture Behavioral of tb_AllChannels is

    constant NBLOCKS : integer := 256;
    constant CLK8_PERIOD : time := 10 ns;

    signal clk8    : std_logic := '0';
    signal clk     : std_logic := '0';

    signal counter : std_logic_vector(7 downto 0) := (others => '0');

    signal swap    : std_logic := '0';
    signal phase   : std_logic_vector(7 downto 0) := (others => '0');
    signal set     : std_logic := '0';
    signal address : std_logic_vector(7 downto 0) := (others => '0');

    signal data_out : std_logic_vector(31 downto 0);

begin

    uut: entity work.AllChannels
        generic map (
            NBLOCKS => NBLOCKS
        )
        port map (
            clk8     => clk8,
            clk      => clk,
            counter  => counter,
            swap     => swap,
            phase    => phase,
            set      => set,
            address  => address,
            data_out => data_out
        );

    --------------------------------------------------------------------
    -- clk8: base clock
    --------------------------------------------------------------------
    clk8_process : process
    begin
        while true loop
            clk8 <= '0';
            wait for CLK8_PERIOD / 2;
            clk8 <= '1';
            wait for CLK8_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------
    -- counter increments on rising edge of clk8
    --------------------------------------------------------------------
    counter_process : process(clk8)
    begin
        if rising_edge(clk8) then
            counter <= std_logic_vector(unsigned(counter) + 1);
        end if;
    end process;

    --------------------------------------------------------------------
    -- clk = counter(2)
    --------------------------------------------------------------------
    clk <= counter(2);

    --------------------------------------------------------------------
    -- stimulus
    --------------------------------------------------------------------
    stim_proc : process
    begin
        set     <= '0';
        swap    <= '0';
        address <= (others => '0');
        phase   <= (others => '0');

        wait for 50 ns;

        ----------------------------------------------------------------
        -- write phase values:
        -- every 8th address gets phase 0..31
        -- address = 0,8,16,...,248  -> phase = 0..31
        -- others -> phase = 0
        ----------------------------------------------------------------
        set  <= '1';
        swap <= '0';

        for i in 0 to 255 loop
            wait until falling_edge(clk);

            address <= std_logic_vector(to_unsigned(i, 8));

            if (i mod 8 = 0) then
                phase <= std_logic_vector(to_unsigned(i / 8, 8));
            else
                phase <= std_logic_vector(to_unsigned(0, 8));
            end if;

            wait until rising_edge(clk);
        end loop;

        ----------------------------------------------------------------
        -- swap pulse for one clk period
        ----------------------------------------------------------------
        wait until falling_edge(clk);
        set  <= '0';
        swap <= '1';

        wait until rising_edge(clk);
        wait until falling_edge(clk);
        swap <= '0';
        set  <= '0';

        wait;

        assert false report "Simulation finished." severity failure;
    end process;

end Behavioral;