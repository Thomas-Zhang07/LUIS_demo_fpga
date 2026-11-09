library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_AllChannels is
end entity;

architecture sim of tb_AllChannels is

    component AllChannels is
        generic(NBLOCKS: integer := 256);
        port (
            clk8     : in  std_logic;
            clk      : in  std_logic;
            counter  : in  std_logic_vector(7 downto 0);
            swap     : in  std_logic := '0';
            phase    : in  std_logic_vector(7 downto 0);
            set      : in  std_logic := '0';
            address  : in  std_logic_vector(7 downto 0);
            data_out : out std_logic_vector(31 downto 0)
        );
    end component;

    signal clk8     : std_logic := '0';
    signal clk      : std_logic := '0';
    signal counter  : std_logic_vector(7 downto 0) := (others => '0');
    signal swap     : std_logic := '0';
    signal phase    : std_logic_vector(7 downto 0) := (others => '0');
    signal set      : std_logic := '0';
    signal address  : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out : std_logic_vector(31 downto 0);

    signal count    : unsigned(7 downto 0) := (others => '0');

    constant CLK8_PERIOD : time := 97.65625 us;  -- 10.24 kHz

begin

    dut : AllChannels
        generic map (
            NBLOCKS => 256
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

    -- clk8 = 10.24 kHz
    clk8_process : process
    begin
        while true loop
            clk8 <= '0';
            wait for CLK8_PERIOD / 2;
            clk8 <= '1';
            wait for CLK8_PERIOD / 2;
        end loop;
    end process;

    -- count increments on each rising edge of clk8
    count_process : process(clk8)
    begin
        if rising_edge(clk8) then
            count <= count + 1;
        end if;
    end process;

    -- counter = count
    counter <= std_logic_vector(count);

    -- clk = count(2)
    clk <= count(2);

    stim_proc : process
    begin
        -- initial values
        address <= (others => '0');
        phase   <= (others => '0');
        set     <= '0';
        swap    <= '0';

        -- wait a few clk cycles for stabilization
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        -- address = 0, phase = 16, set = 1
        address <= x"00";
        phase   <= x"10";
        set     <= '1';
        swap    <= '0';

        -- keep set high for one clk cycle
        wait until rising_edge(clk);
        set <= '0';

        -- wait one clk cycle
        wait until rising_edge(clk);

        -- swap = 1
        swap <= '1';

        -- keep swap high for one clk cycle
        wait until rising_edge(clk);
        swap <= '0';

        -- observe for several clk cycles
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        wait;
    end process;

end architecture;