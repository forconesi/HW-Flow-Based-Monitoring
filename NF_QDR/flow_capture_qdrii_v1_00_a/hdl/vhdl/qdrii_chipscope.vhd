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
--  /   /         Filename           : qdrii_chipscope.v
-- /___/   /\     Timestamp          : 15 May 2006
-- \   \  /  \    Date Last Modified : $Date: 2010/06/29 12:03:50 $
--  \___\/\___\
--
--Device: Virtex-5
--Design: QDRII
--
--Purpose:
--   This module has the declaration of chipscope modules. It has the module
--   declaration of VIO and ICON
--
--Revision History:
--
--*****************************************************************************

library ieee;
use ieee.std_logic_1164.all;

package qdrii_chipscope is
  component icon
    port(
      control0 : out std_logic_vector(35 downto 0)
      );
  end component;

--------------------------------------------------------------------------------
--  VIO core module declaration
--------------------------------------------------------------------------------
  component vio
    port (
      CLK      : in    std_logic;
      CONTROL  : inout std_logic_vector ( 35 downto 0 );
      SYNC_OUT : out   std_logic_vector ( 35 downto 0 );
      ASYNC_IN : in    std_logic_vector ( 66 downto 0 )
      );
  end component;

  attribute syn_black_box : boolean;
  attribute syn_noprune : boolean;
  attribute syn_black_box of icon : component is TRUE;
  attribute syn_noprune of icon : component is TRUE;
  attribute syn_black_box of vio  : component is TRUE;
  attribute syn_noprune of vio  : component is TRUE;

end qdrii_chipscope;
