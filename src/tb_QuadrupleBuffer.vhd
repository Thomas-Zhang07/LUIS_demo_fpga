library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_QuadrupleBuffer is
end entity;

architecture sim of tb_QuadrupleBuffer is

    component QuadrupleBuffer is
        port (
            CLK           : in  std_logic;
            MISC_B        : in  std_logic;
            SHIFT_CLOCK_1 : out std_logic;
            SHIFT_CLOCK_2 : out std_logic;
            LATCH_CLOCK_1 : out std_logic;
            LATCH_CLOCK_2 : out std_logic;
            MISC_E        : out std_logic;
            MISC_D        : out std_logic;
            DATA          : out std_logic_vector(31 downto 0);
            LED           : out std_logic_vector(3 downto 0)
        );
    end component;

    signal CLK           : std_logic := '0';
    signal MISC_B        : std_logic := '1';  -- UART idle = high
    signal SHIFT_CLOCK_1 : std_logic;
    signal SHIFT_CLOCK_2 : std_logic;
    signal LATCH_CLOCK_1 : std_logic;
    signal LATCH_CLOCK_2 : std_logic;
    signal MISC_E        : std_logic;
    signal MISC_D        : std_logic;
    signal DATA          : std_logic_vector(31 downto 0);
    signal LED           : std_logic_vector(3 downto 0);

    constant BAUD_RATE  : integer := 230400;
	 constant BIT_PERIOD : time := 4340 ns;

    procedure uart_send_byte(
        signal tx : out std_logic;
        constant b : in std_logic_vector(7 downto 0)
    ) is
    begin
        -- start bit
        tx <= '0';
        wait for BIT_PERIOD;

        -- 8 data bits, LSB first
        for i in 0 to 7 loop
            tx <= b(i);
            wait for BIT_PERIOD;
        end loop;

        -- stop bit
        tx <= '1';
        wait for BIT_PERIOD;
    end procedure;

begin

    dut : QuadrupleBuffer
        port map (
            CLK           => CLK,
            MISC_B        => MISC_B,
            SHIFT_CLOCK_1 => SHIFT_CLOCK_1,
            SHIFT_CLOCK_2 => SHIFT_CLOCK_2,
            LATCH_CLOCK_1 => LATCH_CLOCK_1,
            LATCH_CLOCK_2 => LATCH_CLOCK_2,
            MISC_E        => MISC_E,
            MISC_D        => MISC_D,
            DATA          => DATA,
            LED           => LED
        );

    -- 50 MHz clock
    clk_process : process
    begin
        while true loop
            CLK <= '0';
            wait for CLK_PERIOD / 2;
            CLK <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- stimulus
    stim_proc : process
    begin
        -- UART idle
        MISC_B <= '1';

        -- wait for PLL / internal logic to settle
        wait for 100 us;

        -- FE : Start receiving phases
        uart_send_byte(MISC_B, x"FE");

        -- 10 : phase of channel 0 = 16
        uart_send_byte(MISC_B, x"10");

        -- FD : Swap buffer
        uart_send_byte(MISC_B, x"FD");

        -- keep line idle and observe
        MISC_B <= '1';
        wait;

        assert false report "Simulation finished." severity failure;
    end process;

end architecture;