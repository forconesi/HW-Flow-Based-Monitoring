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
--  /   /         Filename           : qdrii_phy_en.vhd
-- /___/   /\     Timestamp          : 15 May 2006
-- \   \  /  \    Date Last Modified : $Date: 2010/06/29 12:03:50 $
--  \___\/\___\
--
--Device: Virtex-5
--Design: QDRII
--
--Purpose:
--    This module is used to align all the read data signals from the different
--    banks so that they are all aligned to each other and the valid signal when
--    presented to the backend
--
--Revision History:
--
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity qdrii_phy_en is
  generic(
    -- Following parameters are for 72-bit design (for ML561 Reference board
    -- design). Actual values may be different. Actual parameters values are
    -- passed from design top module mem1 module. Please refer to the
    -- mem1 module for actual values.
    CQ_WIDTH     : integer := 2;
    DATA_WIDTH   : integer := 72;
    Q_PER_CQ     : integer := 18;
    STROBE_WIDTH : integer := 4
    );
  port(
    clk0             : in  std_logic;
    user_rst_0       : in  std_logic;
    we_cal_done      : in  std_logic;
    rd_data_rise     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_data_fall     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    we_in            : in  std_logic_vector(STROBE_WIDTH-1 downto 0);
    srl_count        : in  std_logic_vector((STROBE_WIDTH*4)-1 downto 0);
    rd_data_rise_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
    rd_data_fall_out : out std_logic_vector(DATA_WIDTH-1 downto 0);
    data_valid_out   : out std_logic
    );
end qdrii_phy_en;

architecture arch_qdrii_phy_en of qdrii_phy_en is

  constant EN_CAL_IDLE     : std_logic_vector(4 downto 0) := "00001"; --01
  constant EN_CAL_CHECK    : std_logic_vector(4 downto 0) := "00010"; --02
  constant EN_FLAG_SEL     : std_logic_vector(4 downto 0) := "00100"; --02
  constant EN_CAL_MUX_SEL  : std_logic_vector(4 downto 0) := "01000"; --04
  constant EN_CAL_DONE     : std_logic_vector(4 downto 0) := "10000"; --16

  constant ZEROS           : std_logic_vector(STROBE_WIDTH-1 downto 0) := (others => '0');

  signal rd_data_rise_r        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rd_data_fall_r        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal data_valid_r          : std_logic;
  signal en_cal_state          : std_logic_vector(4 downto 0);
  signal rden_inc              : std_logic_vector(STROBE_WIDTH-1 downto 0);
  signal rden_dec              : std_logic_vector(STROBE_WIDTH-1 downto 0);
  signal check_count           : std_logic_vector(3 downto 0);
  signal mux_sel               : std_logic_vector(STROBE_WIDTH-1 downto 0);
  signal mux_sel_done          : std_logic;
  signal we_cal_done_r         : std_logic;
  signal we_cal_done_2r        : std_logic;
  signal we_cal_done_3r        : std_logic;
  signal mux_sel_align         : std_logic;
  signal srl_count_r           : std_logic_vector((STROBE_WIDTH*4)-1 downto 0);
  signal srl_count_2r          : std_logic_vector((STROBE_WIDTH*4)-1 downto 0);
  signal inc_flag              : std_logic;
  signal dec_flag              : std_logic;
  signal inc_srl_val           : std_logic_vector(3 downto 0);
  signal dec_srl_val           : std_logic_vector(3 downto 0);

begin

  check_count <= srl_count_2r(3 downto 0);

  process(clk0)
  begin
    if(rising_edge(clk0)) then
      if(user_rst_0 = '1') then
        rd_data_rise_r <= (others => '0');
        rd_data_fall_r <= (others => '0');
        data_valid_r   <= '0';
        we_cal_done_r  <= '0';
        we_cal_done_2r <= '0';
        we_cal_done_3r <= '0';
        srl_count_r    <= (others => '0');
        srl_count_2r   <= (others => '0');
      else
        rd_data_rise_r <= rd_data_rise;
        rd_data_fall_r <= rd_data_fall;
        data_valid_r   <= we_in(0);
        we_cal_done_r  <= we_cal_done;
        we_cal_done_2r <= we_cal_done_r;
        we_cal_done_3r <= we_cal_done_2r;
        srl_count_r    <= srl_count;
        srl_count_2r   <= srl_count_r;
      end if;
    end if;
  end process;

--------------------------------------------------------------------------------
-- This state machine is used to check for conditions to determine whether the
-- registered or the un-registered read data needs to be sent out
--
-- The following steps are followed:
-- 1. The srl_count value of the first read bank is stored in check_count.
-- 2. This check count is compared against all the srl_counts from other banks.
--    a). If they are the same, the registered data is used inorder to provide
--        the user with a predictable latency.
--    b). If the check count is less than a compared value, the registered data
--        for that bank needs to be used
--    c)  Similarly, if the check count is greater than srl_count of bank 0, the
--        registered data for bank 0 needs to be used.
--------------------------------------------------------------------------------
  process (clk0)
  begin
    if(rising_edge(clk0)) then
      if (user_rst_0 = '1')  then
        rden_inc          <= (others => '0');
        rden_dec          <= (others => '0');
        mux_sel           <= (others => '0');
        mux_sel_done      <= '0';
        en_cal_state      <= EN_CAL_IDLE;
        inc_srl_val       <= (others => '0');
        dec_srl_val       <= (others => '0');
        inc_flag          <= '0';
        dec_flag          <= '0';
      else
        case(en_cal_state) is
          when EN_CAL_IDLE  =>
            if (we_cal_done_3r = '1') then
              en_cal_state <= EN_CAL_CHECK;
            else
              en_cal_state <= EN_CAL_IDLE;
            end if;

          when EN_CAL_CHECK =>
            for i in 1 to (STROBE_WIDTH-1) loop
              if (srl_count_2r(3 downto 0) /= srl_count_2r(((i+1)*4 -1) downto (i*4))) then
                if (srl_count_2r(3 downto 0) < srl_count_2r(((i+1)*4 -1) downto (i*4))) then
                  inc_flag <= '1';
                  inc_srl_val <= srl_count_2r(((i+1)*4 -1) downto (i*4));
                else
                  dec_flag <= '1';
                  dec_srl_val <= srl_count_2r(((i+1)*4 -1) downto (i*4));
                end if;
              end if;
            end loop;
          en_cal_state <= EN_FLAG_SEL;

          when EN_FLAG_SEL =>
            if (inc_flag = '1') then
              for i in 0 to (STROBE_WIDTH-1) loop
                if (srl_count_2r(((i+1)*4 -1) downto (i*4)) /= inc_srl_val) then
                  rden_inc(i) <= '1';
                end if;
              end loop;
            elsif (dec_flag = '1') then
              for i in 0 to (STROBE_WIDTH-1) loop
                if (srl_count_2r(((i+1)*4 -1) downto (i*4)) = dec_srl_val) then
                  rden_dec(i) <= '1';
                end if;
              end loop;
            end if;
          en_cal_state <= EN_CAL_MUX_SEL;

          when EN_CAL_MUX_SEL  =>
            -- This is the condition where all the srl counts are the same.
            if (inc_flag = '0' and dec_flag = '0') then
              mux_sel <= (others => '0');
            elsif (inc_flag = '1') then
              -- This is the condition where one of the srl counts is higher
              -- than that of srl_count_0.
              for i in 0 to (STROBE_WIDTH-1) loop
                if (rden_inc(i) = '1') then
                  mux_sel(i) <= '1';
                end if;
              end loop;
            elsif (dec_flag = '1') then
              -- This is the condition where one of the srl counts is lower
              -- than that of srl_count_0.
              for i in 0 to (STROBE_WIDTH -1) loop
                if (rden_dec(i)= '1') then
                  mux_sel(i) <= '1';
                end if;
              end loop;
            end if;
          en_cal_state <= EN_CAL_DONE;

          when  EN_CAL_DONE  =>
            mux_sel_done <= '1';
            en_cal_state <= EN_CAL_DONE;

          when others =>
            en_cal_state <= EN_CAL_IDLE;

        end case;
      end if;
    end if;
  end process;

  -- Check to see if all the srl counts match. If this is true, the registered
  -- version of the read data is provided to the user backend.

  process (clk0)
  begin
    if(rising_edge(clk0)) then
      if (user_rst_0 = '1')  then
        mux_sel_align <= '0';
      elsif ( (mux_sel_done = '1') and (mux_sel = ZEROS)) then
        mux_sel_align <= '1';
      end if;
    end if;
  end process;

  rd_data_out : for rd_i in 0 to STROBE_WIDTH-1 generate
    rd_data_rise_out(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ)) <=
      rd_data_rise_r(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ)) when
      ((mux_sel(rd_i) = '1') or (mux_sel_align = '1'))else
      rd_data_rise(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ));

    rd_data_fall_out(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ)) <=
      rd_data_fall_r(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ)) when
      ((mux_sel(rd_i) = '1') or (mux_sel_align = '1'))else
      rd_data_fall(((rd_i+1)*Q_PER_CQ)-1 downto (rd_i*Q_PER_CQ));

  end generate rd_data_out;

  data_valid_out <= we_in(0) when (dec_flag = '1') else data_valid_r;

end architecture arch_qdrii_phy_en;