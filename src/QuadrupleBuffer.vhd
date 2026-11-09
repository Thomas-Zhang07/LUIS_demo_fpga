-- Copyright (C) 1991-2013 Altera Corporation
-- Your use of Altera Corporation's design tools, logic functions 
-- and other software and tools, and its AMPP partner logic 
-- functions, and any output files from any of the foregoing 
-- (including device programming or simulation files), and any 
-- associated documentation or information are expressly subject 
-- to the terms and conditions of the Altera Program License 
-- Subscription Agreement, Altera MegaCore Function License 
-- Agreement, or other applicable license agreement, including, 
-- without limitation, that your use is for the sole purpose of 
-- programming logic devices manufactured by Altera and sold by 
-- Altera or its authorized distributors.  Please refer to the 
-- applicable agreement for further details.

-- PROGRAM		"Quartus II 64-Bit"
-- VERSION		"Version 13.0.1 Build 232 06/12/2013 Service Pack 1 SJ Web Edition"
-- CREATED		"Wed May 13 15:53:12 2026"

LIBRARY ieee;
USE ieee.std_logic_1164.all; 

LIBRARY work;

ENTITY QuadrupleBuffer IS 
	PORT
	(
		CLK :  IN  STD_LOGIC;
		MISC_B :  IN  STD_LOGIC;
		SHIFT_CLOCK_1 :  OUT  STD_LOGIC;
		SHIFT_CLOCK_2 :  OUT  STD_LOGIC;
		LATCH_CLOCK_1 :  OUT  STD_LOGIC;
		LATCH_CLOCK_2 :  OUT  STD_LOGIC;
		MISC_E :  OUT  STD_LOGIC;
		MISC_D :  OUT  STD_LOGIC;
		DATA :  OUT  STD_LOGIC_VECTOR(31 DOWNTO 0);
		LED :  OUT  STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
END QuadrupleBuffer;

ARCHITECTURE bdf_type OF QuadrupleBuffer IS 

COMPONENT pulseexpander
GENERIC (OUTPUT_LENGTH_CYCLES : INTEGER
			);
	PORT(clk_in : IN STD_LOGIC;
		 pulse_in : IN STD_LOGIC;
		 pulse_out : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT masterclock
	PORT(inclk0 : IN STD_LOGIC;
		 c0 : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT latchbuffer
	PORT(clk_in : IN STD_LOGIC;
		 signal_in : IN STD_LOGIC;
		 signal_out : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT divider
GENERIC (MAX_COUNTER : INTEGER
			);
	PORT(clk_in : IN STD_LOGIC;
		 clk_out : OUT STD_LOGIC
	);
END COMPONENT;

COMPONENT uartreader
GENERIC (g_CLKS_PER_BIT : INTEGER
			);
	PORT(i_Clk : IN STD_LOGIC;
		 i_RX_Serial : IN STD_LOGIC;
		 o_RX_DV : OUT STD_LOGIC;
		 o_RX_Byte : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END COMPONENT;

COMPONENT distribute
	PORT(CLK : IN STD_LOGIC;
		 byte_in : IN STD_LOGIC;
		 q_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 swap_out : OUT STD_LOGIC;
		 set_out : OUT STD_LOGIC;
		 multiplex_out : OUT STD_LOGIC;
		 debug_swap : OUT STD_LOGIC;
		 debug_reset : OUT STD_LOGIC;
		 debug_onShiftClocks : OUT STD_LOGIC;
		 address : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
		 data_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END COMPONENT;

COMPONENT allchannels
GENERIC (NBLOCKS : INTEGER
			);
	PORT(clk8 : IN STD_LOGIC;
		 clk : IN STD_LOGIC;
		 swap : IN STD_LOGIC;
		 set : IN STD_LOGIC;
		 address : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 counter : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 phase : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		 data_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
	);
END COMPONENT;

COMPONENT counter
GENERIC (COUNTER_BITS : INTEGER
			);
	PORT(clk_in : IN STD_LOGIC;
		 sync_reset : IN STD_LOGIC;
		 clk_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
	);
END COMPONENT;

COMPONENT rssfilter_1
GENERIC (TAPS : INTEGER
			);
	PORT(clk : IN STD_LOGIC;
		 bit_in : IN STD_LOGIC;
		 bit_out : OUT STD_LOGIC
	);
END COMPONENT;

SIGNAL	CLK_8 :  STD_LOGIC;
SIGNAL	COUNT :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	enableShiftClocks :  STD_LOGIC;
SIGNAL	RST :  STD_LOGIC;
SIGNAL	set_out :  STD_LOGIC;
SIGNAL	set_out_e :  STD_LOGIC;
SIGNAL	swap_out :  STD_LOGIC;
SIGNAL	swap_out_e :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_0 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_1 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_2 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_3 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_4 :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_5 :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_6 :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	SYNTHESIZED_WIRE_7 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_8 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_9 :  STD_LOGIC;
SIGNAL	SYNTHESIZED_WIRE_10 :  STD_LOGIC;
-- ===== FAKE UART ON MISC_B BEGIN =====

SIGNAL fake_uart_tx       : STD_LOGIC := '1';
SIGNAL fake_uart_busy     : STD_LOGIC := '0';

SIGNAL fake_uart_counter  : INTEGER := 0;
SIGNAL fake_uart_bit_idx  : INTEGER RANGE 0 TO 9 := 0;
SIGNAL fake_uart_byte_idx : INTEGER RANGE 0 TO 257 := 0;

SIGNAL fake_uart_shift    : STD_LOGIC_VECTOR(9 DOWNTO 0);

TYPE uart_frame_array IS ARRAY (0 TO 257) OF STD_LOGIC_VECTOR(7 DOWNTO 0);

CONSTANT test_frame : uart_frame_array := (

	 0   => x"FE",

    1  to 128 => x"00",

    129 to 256 => x"20",

    257 => x"FD"

);

-- ===== FAKE UART ON MISC_B END =====

BEGIN 
-- ===== FAKE UART TRANSMITTER BEGIN =====

process(CLK_8)
begin
    if rising_edge(CLK_8) then

        fake_uart_counter <= fake_uart_counter + 1;

        if fake_uart_busy = '0' then

            if fake_uart_counter = 500000 then

                fake_uart_counter <= 0;

                fake_uart_busy <= '1';
                fake_uart_bit_idx <= 0;

                fake_uart_shift <=
                    '1' &                       -- stop
                    test_frame(fake_uart_byte_idx) &
                    '0';                        -- start

            end if;

        else

            if fake_uart_counter = 45 then     -- g_CLKS_PER_BIT = 45

                fake_uart_counter <= 0;

                fake_uart_tx <= fake_uart_shift(fake_uart_bit_idx);

                if fake_uart_bit_idx = 9 then

                    fake_uart_busy <= '0';
                    fake_uart_tx <= '1';

                    if fake_uart_byte_idx < 257 then
                        fake_uart_byte_idx <= fake_uart_byte_idx + 1;
                    end if;

                else

                    fake_uart_bit_idx <= fake_uart_bit_idx + 1;

                end if;

            end if;

        end if;

    end if;
end process;

-- ===== FAKE UART TRANSMITTER END =====
MISC_E <= MISC_B;
SHIFT_CLOCK_1 <= SYNTHESIZED_WIRE_9;
SHIFT_CLOCK_2 <= SYNTHESIZED_WIRE_9;
LATCH_CLOCK_1 <= SYNTHESIZED_WIRE_10;
LATCH_CLOCK_2 <= SYNTHESIZED_WIRE_10;



b2v_inst : pulseexpander
GENERIC MAP(OUTPUT_LENGTH_CYCLES => 16
			)
PORT MAP(clk_in => CLK_8,
		 pulse_in => swap_out,
		 pulse_out => SYNTHESIZED_WIRE_2);


b2v_inst1 : masterclock
PORT MAP(inclk0 => CLK,
		 c0 => CLK_8);


b2v_inst10 : latchbuffer
PORT MAP(clk_in => COUNT(2),
		 signal_in => SYNTHESIZED_WIRE_0,
		 signal_out => set_out_e);


SYNTHESIZED_WIRE_8 <= NOT(CLK_8);



b2v_inst13 : divider
GENERIC MAP(MAX_COUNTER => 20000
			)
PORT MAP(clk_in => COUNT(7),
		 clk_out => LED(0));



b2v_inst3 : uartreader
GENERIC MAP(g_CLKS_PER_BIT => 45
			)
PORT MAP(i_Clk => CLK_8,
		 i_RX_Serial => SYNTHESIZED_WIRE_1,
		 o_RX_DV => SYNTHESIZED_WIRE_3,
		 o_RX_Byte => SYNTHESIZED_WIRE_4);


SYNTHESIZED_WIRE_10 <= COUNT(2) AND enableShiftClocks;


b2v_inst5 : latchbuffer
PORT MAP(clk_in => COUNT(2),
		 signal_in => SYNTHESIZED_WIRE_2,
		 signal_out => swap_out_e);


b2v_inst6 : distribute
PORT MAP(CLK => CLK_8,
		 byte_in => SYNTHESIZED_WIRE_3,
		 q_in => SYNTHESIZED_WIRE_4,
		 swap_out => swap_out,
		 set_out => set_out,
		 debug_swap => LED(1),
		 debug_reset => LED(2),
		 debug_onShiftClocks => enableShiftClocks,
		 address => SYNTHESIZED_WIRE_5,
		 data_out => SYNTHESIZED_WIRE_6);


b2v_inst7 : pulseexpander
GENERIC MAP(OUTPUT_LENGTH_CYCLES => 16
			)
PORT MAP(clk_in => CLK_8,
		 pulse_in => set_out,
		 pulse_out => SYNTHESIZED_WIRE_0);


b2v_inst8 : allchannels
GENERIC MAP(NBLOCKS => 256
			)
PORT MAP(clk8 => CLK_8,
		 clk => COUNT(2),
		 swap => swap_out_e,
		 set => set_out_e,
		 address => SYNTHESIZED_WIRE_5,
		 counter => COUNT,
		 phase => SYNTHESIZED_WIRE_6,
		 data_out => DATA);


b2v_inst9 : counter
GENERIC MAP(COUNTER_BITS => 8
			)
PORT MAP(clk_in => CLK_8,
		 sync_reset => SYNTHESIZED_WIRE_7,
		 clk_out => COUNT);


b2v_inst_rss1 : rssfilter_1
GENERIC MAP(TAPS => 8
			)
PORT MAP(clk => CLK_8,
		 bit_in => RST,
		 bit_out => SYNTHESIZED_WIRE_7);

--
--b2v_inst_rss2 : rssfilter_1
--GENERIC MAP(TAPS => 8
--			)
--PORT MAP(clk => CLK_8,
--		 bit_in => MISC_B,
--		 bit_out => SYNTHESIZED_WIRE_1);

-- ===== FAKE UART SOURCE BEGIN =====

b2v_inst_rss2 : rssfilter_1
GENERIC MAP(TAPS => 8)
PORT MAP(
    clk => CLK_8,
    bit_in => fake_uart_tx,
    bit_out => SYNTHESIZED_WIRE_1
);

-- ===== FAKE UART SOURCE END =====

SYNTHESIZED_WIRE_9 <= SYNTHESIZED_WIRE_8 AND enableShiftClocks;

MISC_D <= COUNT(7);
LED(3) <= enableShiftClocks;

RST <= '0';
END bdf_type;