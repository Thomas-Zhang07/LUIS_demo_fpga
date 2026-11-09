library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Filter_UARTReader is
end tb_Filter_UARTReader;

architecture sim of tb_Filter_UARTReader is

  ------------------------------------------------------------------
  -- 参数
  ------------------------------------------------------------------
  constant c_CLK_FREQ      : integer := 10_240_000;   -- 10.24 MHz
  constant c_BAUD_RATE     : integer := 230_400;      -- 230.4 kbaud
  constant c_CLKS_PER_BIT  : integer := 45;           -- UARTReader 使用
  constant c_TAPS          : integer := 7;            -- RSSFilter_1 使用

  -- 为兼容老版 ModelSim，time 常量不用 fs
  constant c_CLK_PERIOD    : time := 97656 ps;        -- 约 97.656 ns
  constant c_BIT_PERIOD    : time := 4340278 ps;      -- 约 4.340278 us

  ------------------------------------------------------------------
  -- 信号
  ------------------------------------------------------------------
  signal clk           : std_logic := '0';
  signal uart_raw_in   : std_logic := '1';   -- 原始 UART 串行输入
  signal uart_filt_out : std_logic;          -- Filter 输出
  signal rx_dv         : std_logic;
  signal rx_byte       : std_logic_vector(7 downto 0);

begin

  ------------------------------------------------------------------
  -- 10.24 MHz 时钟
  ------------------------------------------------------------------
  p_clk : process
  begin
    while true loop
      clk <= '0';
      wait for c_CLK_PERIOD / 2;
      clk <= '1';
      wait for c_CLK_PERIOD / 2;
    end loop;
  end process;

  ------------------------------------------------------------------
  -- 实例化 RSSFilter_1
  ------------------------------------------------------------------
  U_FILTER : entity work.RSSFilter_1
    generic map (
      TAPS => c_TAPS
    )
    port map (
      clk     => clk,
      bit_in  => uart_raw_in,
      bit_out => uart_filt_out
    );

  ------------------------------------------------------------------
  -- 实例化 UARTReader
  ------------------------------------------------------------------
  U_UART : entity work.UARTReader
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
      i_Clk       => clk,
      i_RX_Serial => uart_filt_out,
      o_RX_DV     => rx_dv,
      o_RX_Byte   => rx_byte
    );

  ------------------------------------------------------------------
  -- UART 发送过程
  -- 格式：1 起始位 + 8 数据位(LSB first) + 1 停止位
  ------------------------------------------------------------------
  p_stimulus : process
    procedure UART_SEND_BYTE(
      constant data_in : in std_logic_vector(7 downto 0)
    ) is
    begin
      -- 空闲保持高电平
      uart_raw_in <= '1';
      wait for c_BIT_PERIOD;

      -- 起始位
      uart_raw_in <= '0';
      wait for c_BIT_PERIOD;

      -- 8位数据，LSB first
      for i in 0 to 7 loop
        uart_raw_in <= data_in(i);
        wait for c_BIT_PERIOD;
      end loop;

      -- 停止位
      uart_raw_in <= '1';
      wait for c_BIT_PERIOD;

      -- 帧间隔
      wait for c_BIT_PERIOD;
    end procedure;
  begin
    uart_raw_in <= '1';
    wait for 20 * c_CLK_PERIOD;

    -- 发送 0 到 255
    for k in 0 to 255 loop
      UART_SEND_BYTE(std_logic_vector(to_unsigned(k, 8)));
    end loop;

    wait for 30 * c_BIT_PERIOD;
    report "Simulation finished." severity note;
    wait;
  end process;

  ------------------------------------------------------------------
  -- 接收监视
  ------------------------------------------------------------------
  p_monitor : process(clk)
    variable rx_count : integer := 0;
  begin
    if rising_edge(clk) then
      if rx_dv = '1' then
        report "RX[" & integer'image(rx_count) & "] = "
             & integer'image(to_integer(unsigned(rx_byte)))
             severity note;
        rx_count := rx_count + 1;
      end if;
    end if;
  end process;

end sim;