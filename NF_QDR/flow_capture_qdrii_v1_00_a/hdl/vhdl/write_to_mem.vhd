-- ******************************************************************************
 -- *  Design:
 -- *        NF_QDR
 -- *  
 -- *  File:
 -- *        write_to_mem.vhd
 -- *
 -- *  Pcore:
  -- *        flow_capture_qdrii
 -- *
 -- *  Authors:
 -- *        Marco Forconesi, Gustavo Sutter, Sergio Lopez-Buedo
 -- *
 -- *  Description:
 -- *        This module writes & erase the flows from external QDR memory.
-- ******************************************************************************
library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity write_to_mem is
port(
		ACLK  : in  std_logic;
		ARESETN  : in  std_logic;
		memory_initialization_ready : out std_logic;
		write_mem_busy : out std_logic;
		write_flow : in std_logic;
		write_5tuple_and_flow_data : in std_logic;
		write_information : in std_logic_vector(240-1 downto 0);
		mem_addr_w : in std_logic_vector(18-1 downto 0);
		erase_flow : in std_logic;
		user_bwl_n : out std_logic_vector((4-1) downto 0);
		user_bwh_n : out std_logic_vector((4-1) downto 0);
		user_rst_0_tb : in std_logic;
		cal_done : in std_logic;
		user_ad_w_n : out std_logic;
		user_d_w_n : out std_logic;
		user_dwl : out std_logic_vector((36-1) downto 0);
		user_dwh : out  std_logic_vector((36-1) downto 0);
		user_ad_wr : out std_logic_vector((19-1) downto 0);
		user_wr_full : in std_logic

);

end entity write_to_mem;

architecture write_to_mem_arch of write_to_mem is

--qdrii_write_memory's signals
	type fsm_w_type is (init_mem_s0, init_mem_s1, init_mem_s2, s0, s1, s2, s3,erase1);
	signal fsm_w : fsm_w_type;
	signal user_ad_wr_int : std_logic_vector((19-1) downto 0);
begin


user_bwl_n <= (others => '0');
user_bwh_n <= (others => '0');
user_ad_wr <= user_ad_wr_int;

qdrii_write_memory: process(ACLK)
variable ip_total_length : std_logic_vector(32-1 downto 0);
variable frame_counter : std_logic_vector(32-1 downto 0);
variable last_time_stamp : std_logic_vector(32-1 downto 0);
variable initial_time_stamp : std_logic_vector(32-1 downto 0);
variable tcp_flags : std_logic_vector(8-1 downto 0);
variable reg_5tuple : std_logic_vector(104-1 downto 0);
begin
if (ACLK'event and ACLK = '1') then
	if (user_rst_0_tb = '1' or cal_done = '0') then
		user_ad_w_n <= '1';
		user_d_w_n <= '1';
		user_dwl <= (others => '0');
		user_dwh <= (others => '0');
		user_ad_wr_int <= (others => '0');
		memory_initialization_ready <= '0';
		write_mem_busy <= '0';
		fsm_w <= init_mem_s0;
	else
		case fsm_w is
			when init_mem_s0 =>
				user_dwl <= (others => '0');
				user_dwh <= (others => '0');
				if (user_wr_full = '0') then
					user_ad_w_n <= '0';
					user_d_w_n <= '0';
					fsm_w <= init_mem_s1;
				end if;
			when init_mem_s1 =>
				user_ad_w_n <= '1';
				user_d_w_n <= '1';
				fsm_w <= init_mem_s2;
			when init_mem_s2 =>
				if (user_ad_wr_int = "1111111111111111111") then
					memory_initialization_ready <= '1';
					fsm_w <= s0;
				else
					user_ad_wr_int <= user_ad_wr_int +1;
					fsm_w <= init_mem_s0;
				end if;
			when s0 =>
				ip_total_length := write_information(32-1 downto 0);
				frame_counter := write_information(64-1 downto 32);
				last_time_stamp := write_information(96-1 downto 64);
				initial_time_stamp := write_information(128-1 downto 96);
				tcp_flags := write_information(136-1 downto 128);
				reg_5tuple := write_information(240-1 downto 136);					
				if (user_wr_full = '0') then
					write_mem_busy <= '0';
					if (erase_flow = '1') then
						write_mem_busy <= '1';
						user_ad_w_n <= '0';
						user_d_w_n <= '0';
						user_ad_wr_int <= mem_addr_w & '0';
						user_dwl <= (others => '0');																								--status bit -> empty entry
						user_dwh <= (others => '0');
						fsm_w <= erase1;
					elsif(write_flow = '1' and write_5tuple_and_flow_data = '1') then						-- if it has to write the 5-tuple & the data-flow as well
						write_mem_busy <= '1';
						user_ad_w_n <= '0';
						user_d_w_n <= '0';
						user_ad_wr_int <= mem_addr_w & '0';																				
						user_dwl <= x"000000001";																									--status bit -> busy entry
						user_dwh <= reg_5tuple(31 downto 0) & x"0";
						fsm_w <= s1;
					elsif(write_flow = '1' and write_5tuple_and_flow_data = '0') then						-- if it's to write the data-flow only
						write_mem_busy <= '1';
						fsm_w <= s2;
					end if;
				else
					write_mem_busy <= '1';
				end if;
			when s1 =>																																		-- finishing writing the 5-tuple & the status flag
				user_ad_w_n <= '1';
				user_d_w_n <= '1';
				user_dwl <= reg_5tuple(67 downto 32);
				user_dwh <= reg_5tuple(103 downto 68);
				fsm_w <= s2;
			when s2 =>																																		--start writing the data-flow in the 2nd entry
				if (user_wr_full = '0') then
					user_ad_w_n <= '0';
					user_d_w_n <= '0';
					user_ad_wr_int <= mem_addr_w & '1';				
					user_dwl <= frame_counter(3 downto 0) & ip_total_length;
					user_dwh <= last_time_stamp(7 downto 0) & frame_counter(31 downto 4);
					fsm_w <= s3;
				end if;
			when s3 =>
				user_ad_w_n <= '1';
				user_d_w_n <= '1';
				user_dwl <= initial_time_stamp(11 downto 0) & last_time_stamp(31 downto 8);
				user_dwh <= x"00" & tcp_flags & initial_time_stamp(31 downto 12);
				write_mem_busy <= '0';
				fsm_w <= s0;
			when erase1 =>
				user_ad_w_n <= '1';
				user_d_w_n <= '1';
				write_mem_busy <= '0';
				fsm_w <= s0;
			when others =>
		end case;
	end if;
end if;
end process;

end architecture write_to_mem_arch;