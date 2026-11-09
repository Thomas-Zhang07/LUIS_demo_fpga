library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_UARTReader is
end tb_UARTReader;

architecture sim of tb_UARTReader is

  --============================================================
  -- 参数设置
  --============================================================
  constant c_CLK_FREQ      : integer := 10_240_000;  -- 10.24 MHz
  constant c_BAUD_RATE     : integer := 230_400;     -- 230.4 kbaud
  constant c_CLKS_PER_BIT  : integer := 45;          -- 取整后给 DUT

-- 10.24 MHz 时钟周期 = 97.65625 ns
constant c_CLK_PERIOD : time := 97656 ps;

-- UART 单比特时间 = 1 / 230400 ≈ 4.340278 us
constant c_BIT_PERIOD : time := 4340278 ps;

  --============================================================
  -- 信号定义
  --============================================================
  signal i_Clk       : std_logic := '0';
  signal i_RX_Serial : std_logic := '1';  -- UART 空闲为高
  signal o_RX_DV     : std_logic;
  signal o_RX_Byte   : std_logic_vector(7 downto 0);

  -- 用于比对结果
  type t_byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

begin

  --============================================================
  -- 实例化被测模块 DUT
  --============================================================
  DUT : entity work.UARTReader
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
    )
    port map (
      i_Clk       => i_Clk,
      i_RX_Serial => i_RX_Serial,
      o_RX_DV     => o_RX_DV,
      o_RX_Byte   => o_RX_Byte
    );

  --============================================================
  -- 10.24 MHz 时钟
  --============================================================
  p_CLK : process
  begin
    while true loop
      i_Clk <= '0';
      wait for c_CLK_PERIOD / 2;
      i_Clk <= '1';
      wait for c_CLK_PERIOD / 2;
    end loop;
  end process;

  --============================================================
  -- UART 发送过程
  -- 1起始位(0) + 8数据位(LSB first) + 1停止位(1)
  --============================================================
  p_STIMULUS : process
    procedure UART_SEND_BYTE (
      constant data_in : in std_logic_vector(7 downto 0)
    ) is
    begin
      -- Start bit
      i_RX_Serial <= '0';
      wait for c_BIT_PERIOD;

      -- 8 data bits, LSB first
      for i in 0 to 7 loop
        i_RX_Serial <= data_in(i);
        wait for c_BIT_PERIOD;
      end loop;

      -- Stop bit
      i_RX_Serial <= '1';
      wait for c_BIT_PERIOD;

      -- 帧间留一点空闲时间
      wait for c_BIT_PERIOD;
    end procedure;
  begin
    -- 初始空闲
    i_RX_Serial <= '1';
    wait for 20 * c_CLK_PERIOD;

    -- 1) 发送 8位1 = 0xFF
    UART_SEND_BYTE(x"FF");

    -- 2) 发送 8位0 = 0x00
    UART_SEND_BYTE(x"00");

    -- 3) 发送从0递增的8位二进制数：0x00 ~ 0xFF
    for k in 0 to 255 loop
      UART_SEND_BYTE(std_logic_vector(to_unsigned(k, 8)));
    end loop;

    wait for 20 * c_BIT_PERIOD;
    report "Simulation finished." severity note;
    wait;
  end process;

  --============================================================
  -- 接收结果监视与校验
  --============================================================
  p_CHECK : process
    variable expected_val : integer := -2;
  begin
    wait until rising_edge(i_Clk);

    if o_RX_DV = '1' then
      expected_val := expected_val + 1;

      case expected_val is
        when -1 =>
          assert o_RX_Byte = x"FF"
            report "ERROR: first byte should be FF, actual = "
                   & integer'image(to_integer(unsigned(o_RX_Byte)))
            severity error;

          report "RX byte OK: FF" severity note;

        when 0 =>
          assert o_RX_Byte = x"00"
            report "ERROR: second byte should be 00, actual = "
                   & integer'image(to_integer(unsigned(o_RX_Byte)))
            severity error;

          report "RX byte OK: 00" severity note;

        when 1 to 256 =>
          assert o_RX_Byte = std_logic_vector(to_unsigned(expected_val - 1, 8))
            report "ERROR: expected = "
                   & integer'image(expected_val - 1)
                   & ", actual = "
                   & integer'image(to_integer(unsigned(o_RX_Byte)))
            severity error;

          report "RX byte OK: "
                 & integer'image(to_integer(unsigned(o_RX_Byte)))
            severity note;

        when others =>
          report "Unexpected extra received byte: "
                 & integer'image(to_integer(unsigned(o_RX_Byte)))
            severity warning;
      end case;
    end if;
  end process;

end sim;