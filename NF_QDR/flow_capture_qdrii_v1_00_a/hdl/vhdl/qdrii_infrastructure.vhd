--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor             : Xilinx
-- \   \   \/     Version            : 3.6
--  \   \         Application        : MIG
--  /   /         Filename           : qdrii_infrastructure.vhd
-- /___/   /\     Timestamp          : 15 May 2006
-- \   \  /  \    Date Last Modified : $Date: 2010/06/29 12:03:50 $
--  \___\/\___\
--
--Device: Virtex-5
--Design: QDRII
--
--Purpose:
--    This module generates and distributes
--        1. Various phases of the system clock using PLL/DCM.
--        2. Reset from the input clock.
--
--Revision History:
--   Rev 1.1 - Parameter CLK_TYPE added and logic for  DIFFERENTIAL and
--             SINGLE_ENDED added. SR. 6/20/08
--   Rev 1.2 - Constant CLK_GENERATOR added and logic for clocks generation
--             using PLL or DCM added as generic code. PK. 10/14/08
--   Rev 1.3 - Added parameter NOCLK200 with default value '0'. Used for
--             controlling the instantiation of IBUFG for clk200. jul/03/09
--*****************************************************************************

library ieee;
library unisim;
use ieee.std_logic_1164.all;
use unisim.vcomponents.all;

entity qdrii_infrastructure is
  generic(
    -- Following parameters are for 72-bit design (for ML561 Reference board
    -- design). Actual values may be different. Actual parameters values are
    -- passed from design top module mem1 module. Please refer to the
    -- mem1 module for actual values.
    DLL_FREQ_MODE : string  := "HIGH";
    CLK_TYPE      : string  := "DIFFERENTIAL";
    RST_ACT_LOW   : integer := 1;
    NOCLK200      : boolean := false;
    CLK_PERIOD    : integer := 3333
    );
  port(
    sys_clk_n       : in  std_logic;
    sys_clk_p       : in  std_logic;
    --sys_clk         : in  std_logic;
    dly_clk_200_n   : in  std_logic;
    dly_clk_200_p   : in  std_logic;
    --idly_clk_200    : in  std_logic;
    sys_rst_n       : in  std_logic;
    idelay_ctrl_rdy : in  std_logic;
    clk0            : in std_logic;
    clk180          : in std_logic;
    clk270          : in std_logic;
	locked			 : in std_logic;
    --clk200          : out std_logic;
    user_rst_0      : out std_logic;
    user_rst_180    : out std_logic;
    user_rst_270    : out std_logic;
    user_rst_200    : out std_logic
    );
end qdrii_infrastructure;

architecture arch_qdrii_infrastructure of qdrii_infrastructure is

  -- # of clock cycles to delay deassertion of reset. Needs to be a fairly
  -- high number not so much for metastability protection, but to give time
  -- for reset (i.e. stable clock cycles) to propagate through all state
  -- machines and to all control signals (i.e. not all control signals have
  -- resets, instead they rely on base state logic being reset, and the effect
  -- of that reset propagating through the logic). Need this because we may not
  -- be getting stable clock cycles while reset asserted (i.e. since reset
  -- depends on PLL/DCM lock status)
  constant RST_SYNC_NUM : integer range 10 to 30 := 25;

  constant CLK_PERIOD_NS : real := real(CLK_PERIOD)/1000.0;
  constant CLK_PERIOD_INT : integer := CLK_PERIOD/1000;

  -- By default this Parameter (CLK_GENERATOR) value is "PLL". If this
  -- Parameter is set to "PLL", PLL is used to generate the design clocks.
  -- If this Parameter is set to "DCM",
  -- DCM is used to generate the design clocks.
  constant CLK_GENERATOR : string := "PLL";

  signal rst0_sync_r      : std_logic_vector(RST_SYNC_NUM-1 downto 0);
  signal rst180_sync_r    : std_logic_vector(RST_SYNC_NUM-1 downto 0);
  signal rst270_sync_r    : std_logic_vector(RST_SYNC_NUM-1 downto 0);
  signal rst200_sync_r    : std_logic_vector(RST_SYNC_NUM-1 downto 0);
  signal user_reset_in    : std_logic;
  signal rst_tmp          : std_logic;
  signal clk0_i           : std_logic;
  signal clk180_i         : std_logic;
  signal clk270_i         : std_logic;
  signal clk200_i         : std_logic;
  signal clkfbout_clkfbin : std_logic;
  --signal locked           : std_logic;
  signal sysclk_in        : std_logic;
  signal clk200_in        : std_logic;
  signal sysclk0_i        : std_logic;
  signal sysclk270_i      : std_logic;

  attribute syn_maxfan : integer;
  attribute max_fanout : integer;
  attribute buffer_type : string;
  attribute syn_maxfan of rst0_sync_r : signal is 10;
  attribute max_fanout of rst0_sync_r : signal is 10;
  attribute buffer_type of rst0_sync_r : signal is "none";
  attribute syn_maxfan of rst180_sync_r : signal is 10;
  attribute max_fanout of rst180_sync_r : signal is 10;
  attribute syn_maxfan of rst270_sync_r : signal is 10;
  attribute max_fanout of rst270_sync_r : signal is 10;
  attribute syn_maxfan of rst200_sync_r : signal is 10;
  attribute max_fanout of rst200_sync_r : signal is 10;

  begin

--  DIFF_ENDED_CLKS_INST : if(CLK_TYPE = "DIFFERENTIAL") generate
--  begin
--    SYS_CLK_INST : IBUFGDS
--      port map(
--        I  => sys_clk_p,
--        IB => sys_clk_n,
--        O  => sysclk_in
--        );
--
--    IDL_CLK_INST : IBUFGDS
--      port map(
--        I  => dly_clk_200_p,
--        IB => dly_clk_200_n,
--        O  => clk200_in
--        );
--
--  end generate;
--
--  SINGLE_ENDED_CLKS_INST : if(CLK_TYPE = "SINGLE_ENDED") generate
--  begin
--    SYS_CLK_INST : IBUFG
--      port map(
--        I  => sys_clk,
--        O  => sysclk_in
--        );
--    NOCLK200_CHECK : if ( NOCLK200 = false ) generate
--    begin
--        IDL_CLK_INST : IBUFG
--          port map(
--            I  => idly_clk_200,
--            O  => clk200_in
--            );
--    end generate;
--
--  end generate;
--
--  NOCLK200_CHECK_BUFG: if ( ((NOCLK200 = false) and (CLK_TYPE = "SINGLE_ENDED")) or (CLK_TYPE = "DIFFERENTIAL") ) generate
--    CLK_200_BUFG : BUFG
--      port map(
--        I => clk200_in,
--        O => clk200_i
--        );
--  end generate;
--
--  NOCLK200_CHECK_GND: if ( (NOCLK200 = true) and (CLK_TYPE = "SINGLE_ENDED")) generate
--     clk200_i <= '0';
--  end generate;

  --***************************************************************************
  -- Global clock generation and distribution
  --***************************************************************************

  -- gen_pll_adv: if (CLK_GENERATOR = "PLL") generate
  -- begin
    -- u_pll_adv: PLL_ADV
      -- generic map (
        -- BANDWIDTH          => "OPTIMIZED",
        -- CLKIN1_PERIOD      => CLK_PERIOD_NS,
        -- CLKIN2_PERIOD      => 10.000,
        -- CLKOUT0_DIVIDE     => CLK_PERIOD_INT,
        -- CLKOUT1_DIVIDE     => CLK_PERIOD_INT,
        -- CLKOUT2_DIVIDE     => 1,
        -- CLKOUT3_DIVIDE     => 1,
        -- CLKOUT4_DIVIDE     => 1,
        -- CLKOUT5_DIVIDE     => 1,
        -- CLKOUT0_PHASE      => 0.000,
        -- CLKOUT1_PHASE      => 270.000,
        -- CLKOUT2_PHASE      => 0.000,
        -- CLKOUT3_PHASE      => 0.000,
        -- CLKOUT4_PHASE      => 0.000,
        -- CLKOUT5_PHASE      => 0.000,
        -- CLKOUT0_DUTY_CYCLE => 0.500,
        -- CLKOUT1_DUTY_CYCLE => 0.500,
        -- CLKOUT2_DUTY_CYCLE => 0.500,
        -- CLKOUT3_DUTY_CYCLE => 0.500,
        -- CLKOUT4_DUTY_CYCLE => 0.500,
        -- CLKOUT5_DUTY_CYCLE => 0.500,
        -- COMPENSATION       => "SYSTEM_SYNCHRONOUS",
        -- DIVCLK_DIVIDE      => 1,
        -- CLKFBOUT_MULT      => CLK_PERIOD_INT,
        -- CLKFBOUT_PHASE     => 0.0,
        -- REF_JITTER         => 0.005000
        -- )
      -- port map (
        -- CLKFBIN     => clkfbout_clkfbin,
        -- CLKINSEL    => '1',
        -- CLKIN1      => sys_clk,
        -- CLKIN2      => '0',
        -- DADDR       => (others => '0'),
        -- DCLK        => '0',
        -- DEN         => '0',
        -- DI          => (others => '0'),
        -- DWE         => '0',
        -- REL         => '0',
        -- RST         => user_reset_in,
        -- CLKFBDCM    => open,
        -- CLKFBOUT    => clkfbout_clkfbin,
        -- CLKOUTDCM0  => open,
        -- CLKOUTDCM1  => open,
        -- CLKOUTDCM2  => open,
        -- CLKOUTDCM3  => open,
        -- CLKOUTDCM4  => open,
        -- CLKOUTDCM5  => open,
        -- CLKOUT0     => sysclk0_i,
        -- CLKOUT1     => sysclk270_i,
        -- CLKOUT2     => open,
        -- CLKOUT3     => open,
        -- CLKOUT4     => open,
        -- CLKOUT5     => open,
        -- DO          => open,
        -- DRDY        => open,
        -- LOCKED      => locked
        -- );
  -- end generate;

  -- gen_dcm_adv: if (CLK_GENERATOR = "DCM") generate
  -- begin
    -- U_DCM_ADV : DCM_ADV
      -- generic map (
        -- DLL_FREQUENCY_MODE    => DLL_FREQ_MODE,
        -- SIM_DEVICE            => "VIRTEX5"
        -- )
      -- port map (
        -- CLK0                  => sysclk0_i,
        -- CLK180                => open,
        -- CLK270                => sysclk270_i,
        -- CLK2X                 => open,
        -- CLK2X180              => open,
        -- CLK90                 => open,
        -- CLKDV                 => open,
        -- CLKFX                 => open,
        -- CLKFX180              => open,
        -- DO                    => open,
        -- DRDY                  => open,
        -- LOCKED                => locked,
        -- PSDONE                => open,
        -- CLKFB                 => clk0_i,
        -- CLKIN                 => sys_clk,
        -- DADDR                 => open,
        -- DCLK                  => open,
        -- DEN                   => open,
        -- DI                    => open,
        -- DWE                   => open,
        -- PSCLK                 => open,
        -- PSEN                  => open,
        -- PSINCDEC              => open,
        -- RST                   => user_reset_in
        -- );
  -- end generate;

   -- Global Buffers to drive clock outputs from PLL/DCM
  -- CLK0_BUFG_INST :BUFG
    -- port map(
      -- I => sysclk0_i,
      -- O => clk0_i
      -- );

  -- CLK270_BUFG_INST : BUFG
    -- port map(
      -- I => sysclk270_i,
      -- O => clk270_i
      -- );

  -- clk0     <= clk0_i;
  -- clk180_i <= not(clk0_i);
  -- clk180   <= not(clk0_i);
  -- clk270   <= clk270_i;
  --clk200   <= idly_clk_200;
  --clk200   <= clk0;

  user_reset_in <= not(sys_rst_n) when (RST_ACT_LOW = 1) else sys_rst_n;

  rst_tmp <= (not(locked)) or (not(idelay_ctrl_rdy)) or user_reset_in;

  process(clk0, rst_tmp)
  begin
    if(rst_tmp = '1') then
      rst0_sync_r <= (others => '1');
    elsif(rising_edge(clk0)) then
      rst0_sync_r <= (rst0_sync_r(RST_SYNC_NUM-2 downto 0) & '0');
    end if;
  end process;

  process(clk180, rst_tmp)
  begin
    if(rst_tmp = '1') then
      rst180_sync_r <= (others => '1');
    elsif(rising_edge(clk180)) then
      rst180_sync_r <= (rst180_sync_r(RST_SYNC_NUM-2 downto 0) & '0');
    end if;
  end process;

  process(clk270, rst_tmp)
  begin
    if(rst_tmp = '1') then
      rst270_sync_r <= (others => '1');
    elsif(rising_edge(clk270)) then
      rst270_sync_r <= (rst270_sync_r(RST_SYNC_NUM-2 downto 0) & '0');
    end if;
  end process;

  process(clk0, locked)
  begin
    if(locked = '0') then
      rst200_sync_r <= (others => '1');
    elsif(rising_edge(clk0)) then
      rst200_sync_r <= (rst200_sync_r(RST_SYNC_NUM-2 downto 0) & '0');
    end if;
  end process;

  user_rst_0   <= rst0_sync_r(RST_SYNC_NUM-1);
  user_rst_180 <= rst180_sync_r(RST_SYNC_NUM-1);
  user_rst_270 <= rst270_sync_r(RST_SYNC_NUM-1);
  user_rst_200 <= rst200_sync_r(RST_SYNC_NUM-1);

end architecture arch_qdrii_infrastructure;
