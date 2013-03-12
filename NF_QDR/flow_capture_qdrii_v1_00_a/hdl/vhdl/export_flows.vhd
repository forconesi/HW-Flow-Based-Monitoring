-- ******************************************************************************
 -- *  Design:
 -- *        NF_QDR
 -- *  
 -- *  File:
 -- *        export_flows.vhd
 -- *
 -- *  Pcore:
  -- *        flow_capture_qdrii
 -- *
 -- *  Authors:
 -- *        Marco Forconesi, Gustavo Sutter, Sergio Lopez-Buedo
 -- *
 -- *  Description:
 -- *        This module exports the flows via a 10G interface in a non-standard 
 -- *        Ethernet format.
-- ******************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity export_flows is
port(
	ACLK  : in  std_logic;	--clk0 as well
	ARESETN  : in  std_logic;
	M_AXIS_10GMAC_tdata       : out std_logic_vector (64-1 downto 0);
	M_AXIS_10GMAC_tstrb       : out std_logic_vector (64/8-1 downto 0);
	M_AXIS_10GMAC_tvalid      : out std_logic;
	M_AXIS_10GMAC_tready      : in  std_logic;
	M_AXIS_10GMAC_tlast       : out std_logic;
	--counters
	counters	: in  std_logic_vector(96-1 downto 0);
	collision_counter : in std_logic_vector(32-1 downto 0);
	--Fifo's signals
	fifo_rd_exp_en : out std_logic;
	fifo_out_exp : in std_logic_vector(258-1 downto 0);
	fifo_empty_exp : in std_logic
	);
end entity export_flows;

architecture export_flows_arch of export_flows is

	type fsm_exp_type is (s0,s1,s2,s3,s4,s5,s6,s7,s8);
	signal fsm_exp : fsm_exp_type;
	
	signal M_AXIS_10GMAC_tdata_rev : std_logic_vector(64-1 downto 0);
	
	signal flow_to_export : std_logic_vector(258-1 downto 0);
	signal ip_total_length : std_logic_vector(32-1 downto 0);
	signal frame_counter : std_logic_vector(32-1 downto 0);
	signal last_time_stamp : std_logic_vector(32-1 downto 0);
	signal initial_time_stamp : std_logic_vector(32-1 downto 0);
	signal tcp_flags : std_logic_vector(8-1 downto 0);
	signal reg_5tuple : std_logic_vector(104-1 downto 0);
	signal hash_code : std_logic_vector(18-1 downto 0);
	
	signal lost_pkts_fifo_full : std_logic_vector(32-1 downto 0);
	signal accepted_packets : std_logic_vector(32-1 downto 0);
	signal processed_packets  : std_logic_vector(32-1 downto 0);
	
begin

lost_pkts_fifo_full <= counters(32-1 downto 0);
accepted_packets <= counters(64-1 downto 32);
processed_packets <= counters(96-1 downto 64);

ip_total_length	<= flow_to_export(32-1 downto 0);
frame_counter <= flow_to_export(64-1 downto 32);
last_time_stamp <= flow_to_export(96-1 downto 64);
initial_time_stamp <= flow_to_export(128-1 downto 96);
tcp_flags <= flow_to_export(136-1 downto 128);
reg_5tuple <= flow_to_export (240-1 downto 136);
hash_code <= flow_to_export (258-1 downto 240);



-- Reverse the byte order
M_AXIS_10GMAC_tdata(64-1 downto 56) 	<= M_AXIS_10GMAC_tdata_rev(8-1 downto 0);
M_AXIS_10GMAC_tdata(56-1 downto 48) 	<= M_AXIS_10GMAC_tdata_rev(16-1 downto 8);
M_AXIS_10GMAC_tdata(48-1 downto 40) 	<= M_AXIS_10GMAC_tdata_rev(24-1 downto 16);
M_AXIS_10GMAC_tdata(40-1 downto 32) 	<= M_AXIS_10GMAC_tdata_rev(32-1 downto 24);
M_AXIS_10GMAC_tdata(32-1 downto 24) 	<= M_AXIS_10GMAC_tdata_rev(40-1 downto 32);
M_AXIS_10GMAC_tdata(24-1 downto 16) 	<= M_AXIS_10GMAC_tdata_rev(48-1 downto 40);
M_AXIS_10GMAC_tdata(16-1 downto 8)  	<= M_AXIS_10GMAC_tdata_rev(56-1 downto 48);
M_AXIS_10GMAC_tdata(8-1 downto 0)     	<= M_AXIS_10GMAC_tdata_rev(64-1 downto 56);

Export_Flows: process(ACLK)
begin
if (ACLK'event and ACLK = '1') then
	if (ARESETN = '0') then	
		M_AXIS_10GMAC_tdata_rev <= (others => '0');
		M_AXIS_10GMAC_tstrb <= (others => '0');
		M_AXIS_10GMAC_tvalid <= '0';
		M_AXIS_10GMAC_tlast <= '0';
		fifo_rd_exp_en <= '0';
		fsm_exp <= s0;
	else
		case fsm_exp is
			when s0 =>
				M_AXIS_10GMAC_tvalid <= '0';
				M_AXIS_10GMAC_tlast <= '0';
				if (fifo_empty_exp = '0') then
					fifo_rd_exp_en <= '1';
					fsm_exp <= s1;
				end if;
			when s1 =>
				fifo_rd_exp_en <= '0';
				fsm_exp <= s2;
			when s2 =>
					flow_to_export <= fifo_out_exp;
					fsm_exp <= s3;
			when s3 =>
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tstrb <= (others => '1');
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= reg_5tuple(104-1 downto 40);
					fsm_exp <= s4;
				end if;
			when s4 =>
				M_AXIS_10GMAC_tvalid <= '0';
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= reg_5tuple(40-1 downto 0) & "000000" & hash_code;
					fsm_exp <= s5;
				end if;
			when s5 =>
				M_AXIS_10GMAC_tvalid <= '0';
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= frame_counter & ip_total_length;
					fsm_exp <= s6;
				end if;
			when s6 =>
				M_AXIS_10GMAC_tvalid <= '0';
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= initial_time_stamp & last_time_stamp;
					fsm_exp <= s7;
				end if;
			when s7 =>
				M_AXIS_10GMAC_tvalid <= '0';
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= tcp_flags & lost_pkts_fifo_full(24-1 downto 0) & collision_counter;
					fsm_exp <= s8;
				end if;
			when s8 =>
				M_AXIS_10GMAC_tvalid <= '0';
				if (M_AXIS_10GMAC_tready = '1') then
					M_AXIS_10GMAC_tvalid <= '1';
					M_AXIS_10GMAC_tdata_rev <= processed_packets & accepted_packets;
					M_AXIS_10GMAC_tlast <= '1';
					fsm_exp <= s0;
				end if;
			when others =>
		end case;
	end if;
end if;
end process;

end architecture export_flows_arch;