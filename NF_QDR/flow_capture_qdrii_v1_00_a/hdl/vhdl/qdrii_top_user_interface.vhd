--*****************************************************************************
-- DISCLAIMER OF LIABILITY
--
-- This file contains proprietary and confidential information of
-- Xilinx, Inc. ("Xilinx"), that is distributed under a license
-- from Xilinx, and may be used, copied and/or disclosed only
-- pursuant to the terms of a valid license agreement with Xilinx.
--
-- XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION
-- ("MATERIALS") "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
-- EXPRESSED, IMPLIED, OR STATUTORY, INCLUDING WITHOUT
-- LIMITATION, ANY WARRANTY WITH RESPECT TO NONINFRINGEMENT,
-- MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR PURPOSE. Xilinx
-- does not warrant that functions included in the Materials will
-- meet the requirements of Licensee, or that the operation of the
-- Materials will be uninterrupted or error-free, or that defects
-- in the Materials will be corrected. Furthermore, Xilinx does
-- not warrant or make any representations regarding use, or the
-- results of the use, of the Materials in terms of correctness,
-- accuracy, reliability or otherwise.
--
-- Xilinx products are not designed or intended to be fail-safe,
-- or for use in any application requiring fail-safe performance,
-- such as life-support or safety devices or systems, Class III
-- medical devices, nuclear facilities, applications related to
-- the deployment of airbags, or any other applications that could
-- lead to death, personal injury or severe property or
-- environmental damage (individually and collectively, "critical
-- applications"). Customer assumes the sole risk and liability
-- of any use of Xilinx products in critical applications,
-- subject only to applicable laws and regulations governing
-- limitations on product liability.
--
-- Copyright 2006, 2007, 2008 Xilinx, Inc.
-- All rights reserved.
--
-- This disclaimer and copyright notice must be retained as part
-- of this file at all times.
--*****************************************************************************
--   ____  ____
--  /   /\/   /
-- /___/  \  /    Vendor             : Xilinx
-- \   \   \/     Version            : 3.6
--  \   \         Application        : MIG
--  /   /         Filename           : qdrii_top_user_interface.vhd
-- /___/   /\     Timestamp          : 15 May 2006
-- \   \  /  \    Date Last Modified : $Date: 2010/06/29 12:03:50 $
--  \___\/\___\
--
--Device: Virtex-5
--Design: QDRII
--
--Purpose:
--    This module
--       1. serves as the interface between the user backend and the phy layer,
--          to store user write address, write data, read address and read data.
--       2. Instantiates the write interface and read interface modules.
--
--Revision History:
--
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;

entity qdrii_top_user_interface is
  generic(
    -- Following parameters are for 72-bit design (for ML561 Reference board
    -- design). Actual values may be different. Actual parameters values are
    -- passed from design top module mem1 module. Please refer to the
    -- mem1 module for actual values.
    ADDR_WIDTH   : integer := 19;
    BURST_LENGTH : integer := 4;
    BW_WIDTH     : integer := 8;
    DATA_WIDTH   : integer := 72
    );
  port(
    clk0          : in std_logic;
    user_rst_0    : in std_logic;
    clk270        : in std_logic;
    user_rst_270  : in std_logic;
    cal_done      : in std_logic;
    user_ad_w_n   : in std_logic;
    user_d_w_n    : in std_logic;
    user_ad_wr    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    user_bw_h     : in std_logic_vector(BW_WIDTH-1 downto 0);
    user_bw_l     : in std_logic_vector(BW_WIDTH-1 downto 0);
    user_dwl      : in std_logic_vector(DATA_WIDTH-1 downto 0);
    user_dwh      : in std_logic_vector(DATA_WIDTH-1 downto 0);
    wr_init_n     : in std_logic;
    wr_init2_n    : in std_logic;
    user_r_n      : in std_logic;
    user_ad_rd    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    rd_init_n     : in std_logic;
    dummy_wrl     : in std_logic_vector(DATA_WIDTH-1 downto 0);
    dummy_wrh     : in std_logic_vector(DATA_WIDTH-1 downto 0);
    dummy_wren    : in std_logic;
    user_wr_full  : out std_logic;
    fifo_ad_wr    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    fifo_bw_h     : out std_logic_vector(BW_WIDTH-1 downto 0);
    fifo_bw_l     : out std_logic_vector(BW_WIDTH-1 downto 0);
    fifo_dwl      : out std_logic_vector(DATA_WIDTH-1 downto 0);
    fifo_dwh      : out std_logic_vector(DATA_WIDTH-1 downto 0);
    fifo_wr_empty : out std_logic;
    user_rd_full  : out std_logic;
    fifo_ad_rd    : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    fifo_rd_empty : out std_logic
    );
end entity qdrii_top_user_interface;

architecture arch_qdrii_top_user_interface of qdrii_top_user_interface is

  component qdrii_top_rd_interface
    generic(
       ADDR_WIDTH   : integer := ADDR_WIDTH
       );
    port(
       clk0           : in  std_logic;
       user_rst_0     : in  std_logic;
       user_r_n       : in  std_logic;
       user_ad_rd     : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
       rd_init_n      : in  std_logic;
       user_rd_full   : out std_logic;
       fifo_ad_rd     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
       fifo_rd_empty  : out std_logic
       );
  end component qdrii_top_rd_interface;

  component qdrii_top_wr_interface
    generic(
      ADDR_WIDTH   : integer := ADDR_WIDTH;
      BURST_LENGTH : integer := BURST_LENGTH;
      BW_WIDTH     : integer := BW_WIDTH;
      DATA_WIDTH   : integer := DATA_WIDTH
      );
    port(
      clk0           : in  std_logic;
      user_rst_0     : in  std_logic;
      clk270         : in  std_logic;
      user_rst_270   : in  std_logic;
      cal_done       : in  std_logic;
      dummy_wrl      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      dummy_wrh      : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      dummy_wren     : in  std_logic;
      user_ad_w_n    : in  std_logic;
      user_d_w_n     : in  std_logic;
      user_ad_wr     : in  std_logic_vector(ADDR_WIDTH - 1 downto 0);
      user_bw_h      : in  std_logic_vector(BW_WIDTH - 1 downto 0);
      user_bw_l      : in  std_logic_vector(BW_WIDTH - 1 downto 0);
      user_dwl       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      user_dwh       : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
      wr_init_n      : in  std_logic;
      wr_init2_n     : in  std_logic;
      user_wr_full   : out std_logic;
      fifo_ad_wr     : out std_logic_vector(ADDR_WIDTH - 1 downto 0);
      fifo_bw_h      : out std_logic_vector(BW_WIDTH - 1 downto 0);
      fifo_bw_l      : out std_logic_vector(BW_WIDTH - 1 downto 0);
      fifo_dwl       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      fifo_dwh       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      fifo_wr_empty  : out std_logic
      );
  end component qdrii_top_wr_interface;

begin

  U_QDRII_TOP_RD_INTERFACE : qdrii_top_rd_interface
    generic map(
      ADDR_WIDTH   => ADDR_WIDTH
      )
    port map(
      clk0          => clk0,
      user_rst_0    => user_rst_0,
      user_r_n      => user_r_n,
      user_ad_rd    => user_ad_rd,
      rd_init_n     => rd_init_n,
      user_rd_full  => user_rd_full,
      fifo_ad_rd    => fifo_ad_rd,
      fifo_rd_empty => fifo_rd_empty
      );

  U_QDRII_TOP_WR_INTERFACE : qdrii_top_wr_interface
    generic map(
      ADDR_WIDTH   => ADDR_WIDTH,
      BURST_LENGTH => BURST_LENGTH,
      BW_WIDTH     => BW_WIDTH,
      DATA_WIDTH   => DATA_WIDTH
      )
    port map(
      clk0          => clk0,
      user_rst_0    => user_rst_0,
      clk270        => clk270,
      user_rst_270  => user_rst_270,
      cal_done      => cal_done,
      dummy_wrl     => dummy_wrl,
      dummy_wrh     => dummy_wrh,
      dummy_wren    => dummy_wren,
      user_ad_w_n   => user_ad_w_n,
      user_d_w_n    => user_d_w_n,
      user_ad_wr    => user_ad_wr,
      user_bw_h     => user_bw_h,
      user_bw_l     => user_bw_l,
      user_dwl      => user_dwl,
      user_dwh      => user_dwh,
      wr_init_n     => wr_init_n,
      wr_init2_n    => wr_init2_n,
      user_wr_full  => user_wr_full,
      fifo_ad_wr    => fifo_ad_wr,
      fifo_bw_h     => fifo_bw_h,
      fifo_bw_l     => fifo_bw_l,
      fifo_dwl      => fifo_dwl,
      fifo_dwh      => fifo_dwh,
      fifo_wr_empty => fifo_wr_empty
      );

end architecture arch_qdrii_top_user_interface;