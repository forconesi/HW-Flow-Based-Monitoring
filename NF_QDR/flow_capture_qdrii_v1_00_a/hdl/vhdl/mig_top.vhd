-- ******************************************************************************
 -- *  Design:
 -- *        NF_QDR
 -- *  
 -- *  File:
 -- *        mig_top.vhd
 -- *
 -- *  Pcore:
  -- *        flow_capture_qdrii
 -- *
 -- *  Authors:
 -- *        Xilinx
 -- *
 -- *  Description:
 -- *        Top module of Xilinx MIG
-- ******************************************************************************

library ieee;
library unisim;
use ieee.std_logic_1164.all;
use unisim.vcomponents.all;
use work.qdrii_chipscope.all;

entity mig_top is
  generic(
   ADDR_WIDTH               : integer := 19; 
                              -- # of memory component address bits.
   BURST_LENGTH             : integer := 4; 
                              -- # = 2 -> Burst Length 2 memory part,
                              -- # = 4 -> Burst Length 4 memory part.
   BW_WIDTH                 : integer := 4; 
                              -- # of Byte Write Control bits.
   DLL_FREQ_MODE            : string  := "HIGH"; 
                              -- DCM's DLL Frequency mode.
   CLK_PERIOD               : integer := 5000; 
                              -- Core/Memory clock period (in ps).
   CLK_TYPE                 : string := "SINGLE_ENDED"; 
                              -- # = "DIFFERENTIAL " -> Differential input clocks,
                               -- # = "SINGLE_ENDED" -> Single ended input clocks.
   CLK_WIDTH                : integer := 1; 
                              -- # of memory clock outputs. Represents the
                              -- number of K, K_n, C, and C_n clocks.
   CQ_WIDTH                 : integer := 1; 
                              -- # of CQ bits.
   DATA_WIDTH               : integer := 36; 
                              -- Design Data Width.
   DEBUG_EN                 : integer := 0; 
                              -- Enable debug signals/controls. When this
                              -- parameter is changed from 0 to 1, make sure to
                              -- uncomment the coregen commands in ise_flow.bat
                              -- or create_ise.bat files in par folder.
   HIGH_PERFORMANCE_MODE    : boolean := TRUE; 
                                     -- # = TRUE, the IODELAY performance mode
                                     -- is set to high.
                                     -- # = FALSE, the IODELAY performance mode
                                     -- is set to low.
   MASTERBANK_PIN_WIDTH     : integer := 1; 
                              -- # of dummy inuput pins for the Master Banks.
                              -- This dummy input pin will appear in the Master
                              -- bank only when it does not have alteast one
                              -- input\inout pins with the IO_STANDARD same as
                              -- the slave banks.
   MEMORY_WIDTH             : integer := 36; 
                              -- # of memory part's data width.
   NOCLK200                 : boolean  := FALSE; 
                              -- clk200 enable and disable.
   RST_ACT_LOW              : integer := 1; 
                              -- # = 1 for active low reset, # = 0 for active high.
   SIM_ONLY                 : integer := 0  
                              -- # = 1 to skip SRAM power up delay.
   );
  port(
   qdr_d                 : out   std_logic_vector((DATA_WIDTH-1) downto 0);
   qdr_q                 : in    std_logic_vector((DATA_WIDTH-1) downto 0);
   qdr_sa                : out   std_logic_vector((ADDR_WIDTH-1) downto 0);
   qdr_w_n               : out   std_logic;
   qdr_r_n               : out   std_logic;
   qdr_dll_off_n         : out   std_logic;
   qdr_bw_n              : out   std_logic_vector((BW_WIDTH-1) downto 0);
--   sys_clk               : in    std_logic;
clk0  : in    std_logic;
clk180  : in    std_logic;
clk270  : in    std_logic;
locked : in std_logic;
   idly_clk_200          : in    std_logic;
   masterbank_sel_pin    : in    std_logic_vector((MASTERBANK_PIN_WIDTH-1) downto 0);
   sys_rst_n             : in    std_logic;
   cal_done              : out   std_logic;
   user_rst_0_tb               : out   std_logic;
   --clk0_tb               : out   std_logic;
   user_ad_w_n           : in    std_logic;
   user_d_w_n            : in    std_logic;
   user_r_n              : in    std_logic;
   user_wr_full          : out   std_logic;
   user_rd_full          : out   std_logic;
   user_qr_valid         : out   std_logic;
   user_dwl              : in    std_logic_vector((DATA_WIDTH-1) downto 0);
   user_dwh              : in    std_logic_vector((DATA_WIDTH-1) downto 0);
   user_qrl              : out   std_logic_vector((DATA_WIDTH-1) downto 0);
   user_qrh              : out   std_logic_vector((DATA_WIDTH-1) downto 0);
   user_bwl_n            : in    std_logic_vector((BW_WIDTH-1) downto 0);
   user_bwh_n            : in    std_logic_vector((BW_WIDTH-1) downto 0);
   user_ad_wr            : in    std_logic_vector((ADDR_WIDTH-1) downto 0);
   user_ad_rd            : in    std_logic_vector((ADDR_WIDTH-1) downto 0);
   qdr_cq                : in    std_logic_vector((CQ_WIDTH-1) downto 0);
   qdr_cq_n              : in    std_logic_vector((CQ_WIDTH-1) downto 0);
   qdr_k                 : out   std_logic_vector((CLK_WIDTH-1) downto 0);
   qdr_k_n               : out   std_logic_vector((CLK_WIDTH-1) downto 0);
   qdr_c                 : out   std_logic_vector((CLK_WIDTH-1) downto 0);
   qdr_c_n               : out   std_logic_vector((CLK_WIDTH-1) downto 0)
   );
end entity mig_top;

architecture arc_mem_interface_top of mig_top is

  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of arc_mem_interface_top : ARCHITECTURE IS
    "mig_v3_6_qdrii_v5, Coregen 12.3";

  attribute CORE_GENERATION_INFO : string;
  attribute CORE_GENERATION_INFO of arc_mem_interface_top : ARCHITECTURE IS "qdrii_v5,mig_v3_6,{component_name=mig_top, ADDR_WIDTH=19, BURST_LENGTH=4, BW_WIDTH=4, CLK_FREQ=200, CLK_PERIOD=5000, CLK_WIDTH=1, CQ_WIDTH=1, DATA_WIDTH=36, MEMORY_WIDTH=36, RST_ACT_LOW=1, INTERFACE_TYPE=QDRII_SRAM, LANGUAGE=VHDL, SYNTHESIS_TOOL=ISE, NO_OF_CONTROLLERS=1}";

  --***************************************************************************
  -- IODELAY Group Name: Replication and placement of IDELAYCTRLs will be
  -- handled automatically by software tools if IDELAYCTRLs have same refclk,
  -- reset and rdy nets. Designs with a unique RESET will commonly create a
  -- unique RDY. Constraint IODELAY_GROUP is associated to a set of IODELAYs
  -- with an IDELAYCTRL. The parameter IODELAY_GRP value can be any string.
  --***************************************************************************
  constant IODELAY_GRP : string := "IODELAY_MIG";



  component qdrii_idelay_ctrl
    generic (
      IODELAY_GRP       : string
      );
    port (
      user_rst_200         : in    std_logic;
      idelay_ctrl_rdy      : out   std_logic;
      clk200               : in    std_logic
      );
  end component;

component qdrii_infrastructure
    generic (
      DLL_FREQ_MODE         : string ;
      CLK_PERIOD            : integer;
      CLK_TYPE              : string;
      NOCLK200              : boolean ;
      RST_ACT_LOW           : integer

      );
    port (
      sys_clk_p            : in    std_logic;
      sys_clk_n            : in    std_logic;
      --sys_clk              : in    std_logic;
      dly_clk_200_p        : in    std_logic;
      dly_clk_200_n        : in    std_logic;
      --idly_clk_200         : in    std_logic;
      sys_rst_n            : in    std_logic;
      user_rst_0           : out   std_logic;
      user_rst_180         : out   std_logic;
      user_rst_270         : out   std_logic;
      user_rst_200         : out   std_logic;
      idelay_ctrl_rdy      : in    std_logic;
      clk0                 : in   std_logic;
      clk180               : in   std_logic;
      clk270               : in   std_logic;
	  locked : in std_logic
      --clk200               : out   std_logic

      );
  end component;


component qdrii_top
    generic (
      ADDR_WIDTH            : integer;
      BURST_LENGTH          : integer;
      BW_WIDTH              : integer;
      CLK_PERIOD            : integer;
      CLK_WIDTH             : integer;
      CQ_WIDTH              : integer;
      DATA_WIDTH            : integer;
      DEBUG_EN              : integer;
      HIGH_PERFORMANCE_MODE   : boolean;
      IODELAY_GRP           : string;
      MEMORY_WIDTH          : integer;
      SIM_ONLY              : integer
      );
    port (
      qdr_d                : out   std_logic_vector((DATA_WIDTH-1) downto 0);
      qdr_q                : in    std_logic_vector((DATA_WIDTH-1) downto 0);
      qdr_sa               : out   std_logic_vector((ADDR_WIDTH-1) downto 0);
      qdr_w_n              : out   std_logic;
      qdr_r_n              : out   std_logic;
      qdr_dll_off_n        : out   std_logic;
      qdr_bw_n             : out   std_logic_vector((BW_WIDTH-1) downto 0);
      cal_done             : out   std_logic;
      user_rst_0           : in    std_logic;
      user_rst_180         : in    std_logic;
      user_rst_270         : in    std_logic;
      idelay_ctrl_rdy      : in   std_logic;
      clk0                 : in    std_logic;
      clk180               : in    std_logic;
      clk270               : in    std_logic;
      user_ad_w_n          : in    std_logic;
      user_d_w_n           : in    std_logic;
      user_r_n             : in    std_logic;
      user_wr_full         : out   std_logic;
      user_rd_full         : out   std_logic;
      user_qr_valid        : out   std_logic;
      user_dwl             : in    std_logic_vector((DATA_WIDTH-1) downto 0);
      user_dwh             : in    std_logic_vector((DATA_WIDTH-1) downto 0);
      user_qrl             : out   std_logic_vector((DATA_WIDTH-1) downto 0);
      user_qrh             : out   std_logic_vector((DATA_WIDTH-1) downto 0);
      user_bwl_n           : in    std_logic_vector((BW_WIDTH-1) downto 0);
      user_bwh_n           : in    std_logic_vector((BW_WIDTH-1) downto 0);
      user_ad_wr           : in    std_logic_vector((ADDR_WIDTH-1) downto 0);
      user_ad_rd           : in    std_logic_vector((ADDR_WIDTH-1) downto 0);
      qdr_cq               : in    std_logic_vector((CQ_WIDTH-1) downto 0);
      qdr_cq_n             : in    std_logic_vector((CQ_WIDTH-1) downto 0);
      qdr_k                : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      qdr_k_n              : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      qdr_c                : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      qdr_c_n              : out   std_logic_vector((CLK_WIDTH-1) downto 0);
      dbg_init_count_done     : out  std_logic;
      dbg_q_cq_init_delay_done   : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_q_cq_n_init_delay_done   : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_q_cq_init_delay_done_tap_count   : out  std_logic_vector((6*CQ_WIDTH)-1 downto 0);
      dbg_q_cq_n_init_delay_done_tap_count   : out  std_logic_vector((6*CQ_WIDTH)-1 downto 0);
      dbg_cq_cal_done         : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_cq_n_cal_done       : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_cq_cal_tap_count    : out  std_logic_vector((6*CQ_WIDTH)-1 downto 0);
      dbg_cq_n_cal_tap_count   : out  std_logic_vector((6*CQ_WIDTH)-1 downto 0);
      dbg_we_cal_done_cq      : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_we_cal_done_cq_n    : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_cq_q_data_valid     : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_cq_n_q_data_valid   : out  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_cal_done            : out  std_logic;
      dbg_data_valid          : out  std_logic;
      dbg_idel_up_all         : in  std_logic;
      dbg_idel_down_all       : in  std_logic;
      dbg_idel_up_q_cq        : in  std_logic;
      dbg_idel_down_q_cq      : in  std_logic;
      dbg_idel_up_q_cq_n      : in  std_logic;
      dbg_idel_down_q_cq_n    : in  std_logic;
      dbg_idel_up_cq          : in  std_logic;
      dbg_idel_down_cq        : in  std_logic;
      dbg_idel_up_cq_n        : in  std_logic;
      dbg_idel_down_cq_n      : in  std_logic;
      dbg_sel_idel_q_cq       : in  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_sel_all_idel_q_cq   : in  std_logic;
      dbg_sel_idel_q_cq_n     : in  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_sel_all_idel_q_cq_n   : in  std_logic;
      dbg_sel_idel_cq         : in  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_sel_all_idel_cq     : in  std_logic;
      dbg_sel_idel_cq_n       : in  std_logic_vector(CQ_WIDTH-1 downto 0);
      dbg_sel_all_idel_cq_n   : in  std_logic

      );
  end component;




  signal  sys_clk_p              : std_logic;
  signal  sys_clk_n              : std_logic;
  signal  dly_clk_200_p          : std_logic;
  signal  dly_clk_200_n          : std_logic;
  signal  user_rst_0             : std_logic;
  signal  user_rst_180           : std_logic;
  signal  user_rst_270           : std_logic;
  signal  user_rst_200           : std_logic;
  signal  idelay_ctrl_rdy        : std_logic;


  signal  i_cal_done           : std_logic;


  --Debug signals


  signal  dbg_init_count_done        : std_logic;
  signal  dbg_q_cq_init_delay_done   : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_q_cq_n_init_delay_done  : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_q_cq_init_delay_done_tap_count  : std_logic_vector((6*CQ_WIDTH)-1 downto 0);
  signal  dbg_q_cq_n_init_delay_done_tap_count  : std_logic_vector((6*CQ_WIDTH)-1 downto 0);
  signal  dbg_cq_cal_done            : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_cq_n_cal_done          : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_cq_cal_tap_count       : std_logic_vector((6*CQ_WIDTH)-1 downto 0);
  signal  dbg_cq_n_cal_tap_count     : std_logic_vector((6*CQ_WIDTH)-1 downto 0);
  signal  dbg_we_cal_done_cq         : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_we_cal_done_cq_n       : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_cq_q_data_valid        : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_cq_n_q_data_valid      : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_cal_done               : std_logic;
  signal  dbg_data_valid             : std_logic;
  signal  dbg_idel_up_all            : std_logic;
  signal  dbg_idel_down_all          : std_logic;
  signal  dbg_idel_up_q_cq           : std_logic;
  signal  dbg_idel_down_q_cq         : std_logic;
  signal  dbg_idel_up_q_cq_n         : std_logic;
  signal  dbg_idel_down_q_cq_n       : std_logic;
  signal  dbg_idel_up_cq             : std_logic;
  signal  dbg_idel_down_cq           : std_logic;
  signal  dbg_idel_up_cq_n           : std_logic;
  signal  dbg_idel_down_cq_n         : std_logic;
  signal  dbg_sel_idel_q_cq          : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_sel_all_idel_q_cq      : std_logic;
  signal  dbg_sel_idel_q_cq_n        : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_sel_all_idel_q_cq_n    : std_logic;
  signal  dbg_sel_idel_cq            : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_sel_all_idel_cq        : std_logic;
  signal  dbg_sel_idel_cq_n          : std_logic_vector(CQ_WIDTH-1 downto 0);
  signal  dbg_sel_all_idel_cq_n      : std_logic;


  --Debug Signals

  signal control0     : std_logic_vector(35 downto 0);
  signal dbg_async_in : std_logic_vector(67 downto 0);
  signal dbg_sync_out : std_logic_vector(36 downto 0);

  signal  masterbank_sel_pin_out : std_logic_vector((MASTERBANK_PIN_WIDTH-1) downto 0);

  attribute syn_useioff : boolean;
  attribute IOB : string;
  attribute keep : string;
  attribute S : string;
  attribute syn_noprune : boolean;
  attribute syn_keep : boolean;

  attribute keep of masterbank_sel_pin_out : signal is "true";
  attribute S of masterbank_sel_pin : signal is "TRUE";
  attribute syn_keep of masterbank_sel_pin_out : signal is true;
  attribute syn_keep of masterbank_sel_pin : signal is true;

begin

  --***************************************************************************
  user_rst_0_tb <= user_rst_0;
  --clk0_tb <= clk0;
  cal_done   <= i_cal_done;

  sys_clk_p <= '1';
  sys_clk_n <= '0';
  dly_clk_200_p <= '1';
  dly_clk_200_n <= '0';

  DUMMY_INST1 : for dpw_i in 0 to MASTERBANK_PIN_WIDTH-1 generate
  attribute syn_noprune of DUMMY_INST : label is true;
  begin
    DUMMY_INST : MUXCY
      port map (
        O  => masterbank_sel_pin_out(dpw_i),
        CI => masterbank_sel_pin(dpw_i),
        DI => '0',
        S  => '1'
        );
  end generate;


  u_qdrii_idelay_ctrl : qdrii_idelay_ctrl
    generic map (
      IODELAY_GRP        => IODELAY_GRP
   )
    port map (
      user_rst_200          => user_rst_200,
      idelay_ctrl_rdy       => idelay_ctrl_rdy,
      clk200                => clk0
   );


u_qdrii_infrastructure :qdrii_infrastructure
    generic map (
      DLL_FREQ_MODE         => DLL_FREQ_MODE,
      CLK_PERIOD            => CLK_PERIOD,
      CLK_TYPE              => CLK_TYPE,
      NOCLK200              => NOCLK200,
      RST_ACT_LOW           => RST_ACT_LOW
   )
    port map (
      sys_clk_p             => sys_clk_p,
      sys_clk_n             => sys_clk_n,
     -- sys_clk               => sys_clk,
      dly_clk_200_p         => dly_clk_200_p,
      dly_clk_200_n         => dly_clk_200_n,

      sys_rst_n             => sys_rst_n,
      user_rst_0            => user_rst_0,
      user_rst_180          => user_rst_180,
      user_rst_270          => user_rst_270,
      user_rst_200          => user_rst_200,
      idelay_ctrl_rdy       => idelay_ctrl_rdy,
      clk0                  => clk0,
      clk180                => clk180,
      clk270                => clk270,
	  locked 				=> locked
   );


  u_qdrii_top_0 : qdrii_top
    generic map (
      ADDR_WIDTH            => ADDR_WIDTH,
      BURST_LENGTH          => BURST_LENGTH,
      BW_WIDTH              => BW_WIDTH,
      CLK_PERIOD            => CLK_PERIOD,
      CLK_WIDTH             => CLK_WIDTH,
      CQ_WIDTH              => CQ_WIDTH,
      DATA_WIDTH            => DATA_WIDTH,
      DEBUG_EN              => DEBUG_EN,
      HIGH_PERFORMANCE_MODE   => HIGH_PERFORMANCE_MODE,
      IODELAY_GRP           => IODELAY_GRP,
      MEMORY_WIDTH          => MEMORY_WIDTH,
      SIM_ONLY              => SIM_ONLY
      )
    port map (
      qdr_d                 => qdr_d,
      qdr_q                 => qdr_q,
      qdr_sa                => qdr_sa,
      qdr_w_n               => qdr_w_n,
      qdr_r_n               => qdr_r_n,
      qdr_dll_off_n         => qdr_dll_off_n,
      qdr_bw_n              => qdr_bw_n,
      cal_done              => i_cal_done,
      user_rst_0            => user_rst_0,
      user_rst_180          => user_rst_180,
      user_rst_270          => user_rst_270,
      idelay_ctrl_rdy       => idelay_ctrl_rdy,
      clk0                  => clk0,
      clk180                => clk180,
      clk270                => clk270,
      user_ad_w_n           => user_ad_w_n,
      user_d_w_n            => user_d_w_n,
      user_r_n              => user_r_n,
      user_wr_full          => user_wr_full,
      user_rd_full          => user_rd_full,
      user_qr_valid         => user_qr_valid,
      user_dwl              => user_dwl,
      user_dwh              => user_dwh,
      user_qrl              => user_qrl,
      user_qrh              => user_qrh,
      user_bwl_n            => user_bwl_n,
      user_bwh_n            => user_bwh_n,
      user_ad_wr            => user_ad_wr,
      user_ad_rd            => user_ad_rd,
      qdr_cq                => qdr_cq,
      qdr_cq_n              => qdr_cq_n,
      qdr_k                 => qdr_k,
      qdr_k_n               => qdr_k_n,
      qdr_c                 => qdr_c,
      qdr_c_n               => qdr_c_n,

      dbg_init_count_done     => dbg_init_count_done,
      dbg_q_cq_init_delay_done   => dbg_q_cq_init_delay_done,
      dbg_q_cq_n_init_delay_done   => dbg_q_cq_n_init_delay_done,
      dbg_q_cq_init_delay_done_tap_count   => dbg_q_cq_init_delay_done_tap_count,
      dbg_q_cq_n_init_delay_done_tap_count   => dbg_q_cq_n_init_delay_done_tap_count,
      dbg_cq_cal_done         => dbg_cq_cal_done,
      dbg_cq_n_cal_done       => dbg_cq_n_cal_done,
      dbg_cq_cal_tap_count    => dbg_cq_cal_tap_count,
      dbg_cq_n_cal_tap_count   => dbg_cq_n_cal_tap_count,
      dbg_we_cal_done_cq      => dbg_we_cal_done_cq,
      dbg_we_cal_done_cq_n    => dbg_we_cal_done_cq_n,
      dbg_cq_q_data_valid     => dbg_cq_q_data_valid,
      dbg_cq_n_q_data_valid   => dbg_cq_n_q_data_valid,
      dbg_cal_done            => dbg_cal_done,
      dbg_data_valid          => dbg_data_valid,
      dbg_idel_up_all         => dbg_idel_up_all,
      dbg_idel_down_all       => dbg_idel_down_all,
      dbg_idel_up_q_cq        => dbg_idel_up_q_cq,
      dbg_idel_down_q_cq      => dbg_idel_down_q_cq,
      dbg_idel_up_q_cq_n      => dbg_idel_up_q_cq_n,
      dbg_idel_down_q_cq_n    => dbg_idel_down_q_cq_n,
      dbg_idel_up_cq          => dbg_idel_up_cq,
      dbg_idel_down_cq        => dbg_idel_down_cq,
      dbg_idel_up_cq_n        => dbg_idel_up_cq_n,
      dbg_idel_down_cq_n      => dbg_idel_down_cq_n,
      dbg_sel_idel_q_cq       => dbg_sel_idel_q_cq,
      dbg_sel_all_idel_q_cq   => dbg_sel_all_idel_q_cq,
      dbg_sel_idel_q_cq_n     => dbg_sel_idel_q_cq_n,
      dbg_sel_all_idel_q_cq_n   => dbg_sel_all_idel_q_cq_n,
      dbg_sel_idel_cq         => dbg_sel_idel_cq,
      dbg_sel_all_idel_cq     => dbg_sel_all_idel_cq,
      dbg_sel_idel_cq_n       => dbg_sel_idel_cq_n,
      dbg_sel_all_idel_cq_n   => dbg_sel_all_idel_cq_n
      );




  ------------------------------------------------------------------------------
  -- PHY Debug Port example - see MIG User's Guide
  -- NOTES:
  --   1. PHY Debug Port demo connects to 1 VIO modules:
  --     - The asynchronous inputs
  --      * Monitor IDELAY taps for Q, CQ/CQ#
  --      * Calibration status
  --     - The synchronous outputs
  --      * Allow dynamic adjustment of IDELAY taps
  --   2. User may need to modify this code to incorporate other
  --      chipscope-related modules in their larger design (e.g.if they have
  --      other ILA/VIO modules, they will need to for example instantiate a
  --      larger ICON module).
  --   3. For X36 bit component designs, since 18 bits of data are calibrated
  --      using cq and other 18 bits of data are calibration using cq_n, there
  --      are debug signals for monitoring/modifying the IDELAY tap values of
  --      cq and cq_n and that of data bits related to cq and cq_n.
  --
  --      But for X18bit component designs, since the calibration is done w.r.t.,
  --      only cq, all the debug signal related to cq_n (all the debug signals
  --      appended with cq_n) must be ignored.
  ------------------------------------------------------------------------------
  DEBUG_SIGNALS_INST : if (DEBUG_EN = 1) generate
    X36_INST : if(MEMORY_WIDTH = 36) generate
      dbg_async_in(67 downto (32*CQ_WIDTH)+3) <= (others => '0');
      dbg_async_in((32*CQ_WIDTH)+2 downto 0) <= (dbg_init_count_done &
                                                 dbg_q_cq_init_delay_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_q_cq_n_init_delay_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_q_cq_init_delay_done_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_q_cq_n_init_delay_done_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_cq_cal_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_n_cal_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_cal_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_cq_n_cal_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_we_cal_done_cq(CQ_WIDTH-1 downto 0) &
                                                 dbg_we_cal_done_cq_n(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_q_data_valid(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_n_q_data_valid(CQ_WIDTH-1 downto 0) &
                                                 dbg_data_valid &
                                                 dbg_cal_done
                                                 );

      dbg_sel_idel_q_cq(CQ_WIDTH-1 downto 0)   <= dbg_sync_out(((4*CQ_WIDTH)+13) downto ((3*CQ_WIDTH)+14));
      dbg_sel_idel_q_cq_n(CQ_WIDTH-1 downto 0) <= dbg_sync_out(((3*CQ_WIDTH)+13) downto ((2*CQ_WIDTH)+14));
      dbg_sel_idel_cq(CQ_WIDTH-1 downto 0)     <= dbg_sync_out(((2*CQ_WIDTH)+13) downto (CQ_WIDTH+14));
      dbg_sel_idel_cq_n(CQ_WIDTH-1 downto 0)   <= dbg_sync_out(CQ_WIDTH+13 downto 14);
      dbg_sel_all_idel_q_cq                    <= dbg_sync_out(13);
      dbg_sel_all_idel_q_cq_n                  <= dbg_sync_out(12);
      dbg_sel_all_idel_cq                      <= dbg_sync_out(11);
      dbg_sel_all_idel_cq_n                    <= dbg_sync_out(10);
      dbg_idel_up_q_cq                         <= dbg_sync_out(9);
      dbg_idel_down_q_cq                       <= dbg_sync_out(8);
      dbg_idel_up_q_cq_n                       <= dbg_sync_out(7);
      dbg_idel_down_q_cq_n                     <= dbg_sync_out(6);
      dbg_idel_up_cq                           <= dbg_sync_out(5);
      dbg_idel_down_cq                         <= dbg_sync_out(4);
      dbg_idel_up_cq_n                         <= dbg_sync_out(3);
      dbg_idel_down_cq_n                       <= dbg_sync_out(2);
      dbg_idel_up_all                          <= dbg_sync_out(1);
      dbg_idel_down_all                        <= dbg_sync_out(0);
    end generate X36_INST;

    X18_INST : if(MEMORY_WIDTH /= 36) generate
      dbg_async_in(67 downto (16*CQ_WIDTH)+3) <= (others => '0');
      dbg_async_in((16*CQ_WIDTH)+2 downto 0) <= (dbg_init_count_done &
                                                 dbg_q_cq_init_delay_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_q_cq_init_delay_done_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_cq_cal_done(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_cal_tap_count((6*CQ_WIDTH)-1 downto 0) &
                                                 dbg_we_cal_done_cq(CQ_WIDTH-1 downto 0) &
                                                 dbg_cq_q_data_valid(CQ_WIDTH-1 downto 0) &
                                                 dbg_data_valid &
                                                 dbg_cal_done
                                                 );

      dbg_sel_idel_q_cq(CQ_WIDTH-1 downto 0) <= dbg_sync_out(((2*CQ_WIDTH)+7) downto (CQ_WIDTH+8));
      dbg_sel_idel_cq(CQ_WIDTH-1 downto 0)   <= dbg_sync_out(CQ_WIDTH+7 downto 8);
      dbg_sel_all_idel_q_cq                  <= dbg_sync_out(7);
      dbg_sel_all_idel_cq                    <= dbg_sync_out(6);
      dbg_idel_up_q_cq                       <= dbg_sync_out(5);
      dbg_idel_down_q_cq                     <= dbg_sync_out(4);
      dbg_idel_up_cq                         <= dbg_sync_out(3);
      dbg_idel_down_cq                       <= dbg_sync_out(2);
      dbg_idel_up_all                        <= dbg_sync_out(1);
      dbg_idel_down_all                      <= dbg_sync_out(0);
    end generate X18_INST;
    ----------------------------------------------------------------------------
    -- ICON core instance
    ----------------------------------------------------------------------------
    U_ICON : icon
      port map(
        CONTROL0 => control0
       );

    ----------------------------------------------------------------------------
    -- VIO core instance : Dynamically change IDELAY taps using Synchronous
    -- output port, and display current IDELAY setting for both CQ/CQ# and Q
    -- taps.
    ----------------------------------------------------------------------------
    U_VIO : vio
      port map(
        CLK      => clk0,
        CONTROL  => control0,
        ASYNC_IN => dbg_async_in(66 downto 0),
        SYNC_OUT => dbg_sync_out(35 downto 0)
        );
  end generate DEBUG_SIGNALS_INST;

  ------------------------------------------------------------------------------
  -- Hooks to prevent sim/syn compilation errors. When DEBUG_EN = 0, all the
  -- debug input signals are floating. To avoid this, they are connected to
  -- all zeros.
  ------------------------------------------------------------------------------
  WITHOUT_DEBUG_SIGNALS_INST : if(DEBUG_EN /= 1) generate
    dbg_idel_up_all         <= '0';
    dbg_idel_down_all       <= '0';
    dbg_idel_up_q_cq        <= '0';
    dbg_idel_down_q_cq      <= '0';
    dbg_idel_up_q_cq_n      <= '0';
    dbg_idel_down_q_cq_n    <= '0';
    dbg_idel_up_cq          <= '0';
    dbg_idel_down_cq        <= '0';
    dbg_idel_up_cq_n        <= '0';
    dbg_idel_down_cq_n      <= '0';
    dbg_sel_idel_q_cq       <= (others => '0');
    dbg_sel_all_idel_q_cq   <= '0';
    dbg_sel_idel_q_cq_n     <= (others => '0');
    dbg_sel_all_idel_q_cq_n <= '0';
    dbg_sel_idel_cq         <= (others => '0');
    dbg_sel_all_idel_cq     <= '0';
    dbg_sel_idel_cq_n       <= (others => '0');
    dbg_sel_all_idel_cq_n   <= '0';
  end generate WITHOUT_DEBUG_SIGNALS_INST;


end architecture arc_mem_interface_top;
