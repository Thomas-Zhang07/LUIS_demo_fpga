library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity testPhaseLine is
end testPhaseLine;

architecture behavior of testPhaseLine is


signal clk     : std_logic := '0';
signal set     : std_logic := '0';
signal swap    : std_logic := '0';
signal phase   : std_logic_vector(5 downto 0) := (others => '0');
signal counter : std_logic_vector(4 downto 0) := (others => '0');
signal pulse   : std_logic;


begin


-- DUT
uut: entity work.PhaseLine
    port map (
        clk => clk,
        set => set,
        swap => swap,
        phase => phase,
        counter => counter,
        pulse => pulse
    );

-- clock generation (10ns period)
clk_process : process
begin
    while true loop
        clk <= '0';
        wait for 5 ns;
        clk <= '1';
        wait for 5 ns;
    end loop;
end process;

-- counter generation (0~63循环)
counter_process : process(clk)
    variable cnt : integer := 0;
begin
    if rising_edge(clk) then
        counter <= std_logic_vector(to_unsigned(cnt, 6)(5 downto 1));
        if cnt = 63 then
            cnt := 0;
        else
            cnt := cnt + 1;
        end if;
    end if;
end process;

-- stimulus
stim_proc: process
begin
    wait for 20 ns;

    -- 设置相位 = 10
    phase <= std_logic_vector(to_unsigned(16, 6));
    

    set <= '1';
    wait for 10 ns;
    set <= '0';

    -- swap 使其生效
    wait for 20 ns;
    swap <= '1';
    wait for 10 ns;
    swap <= '0';

    wait for 200 ns;
    

    wait;
end process;


end behavior;
