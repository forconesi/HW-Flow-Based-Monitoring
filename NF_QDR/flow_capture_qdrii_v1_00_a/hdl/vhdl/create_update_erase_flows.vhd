-- ******************************************************************************
 -- *  Design:
 -- *        NF_QDR
 -- *  
 -- *  File:
 -- *        create_or_update_flows.vhd
 -- *
 -- *  Pcore:
  -- *        flow_capture_qdrii
 -- *
 -- *  Authors:
 -- *        Marco Forconesi, Gustavo Sutter, Sergio Lopez-Buedo
 -- *
 -- *  Description:
 -- *        This module checks if the flow exists. In that case it updates the flow-entry.
 -- *        Otherwise it creates a new flow-entry.
 -- *        If a TCP connection finishes (FIN or RST flag = '1') it indicates
 -- *        the export module to remove the flow-entry
-- ******************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity create_update_erase_flows is
port(
		ACLK  : in  std_logic;	--clk0 as well
		ARESETN  : in  std_logic;
		--Input 5 tuple & frame info & read address
		frame_information	: in  std_logic_vector(104+8+32+16-1 downto 0);
		hash_code_rd	: in  std_logic_vector(18-1 downto 0);
		hash_ready : in std_logic;
		hash_seen : out std_logic;
		memory_initialization_ready : in std_logic;
		time_stamp_counter : in std_logic_vector(32-1 downto 0);
		-- output counters
		collision_counter : out std_logic_vector(32-1 downto 0);
		-- signals to write_mem
		mem_addr_w : out std_logic_vector(18-1 downto 0);
		write_information : out std_logic_vector(240-1 downto 0);
		write_5tuple_and_flow_data : out std_logic;
		erase_flow_qdr_A : out std_logic;
		write_flow_qdr_A : out std_logic;
		write_mem_busy_qdr_A : in std_logic;
		erase_flow_qdr_B : out std_logic;
		write_flow_qdr_B : out std_logic;
		write_mem_busy_qdr_B : in std_logic;
		erase_flow_qdr_C : out std_logic;
		write_flow_qdr_C : out std_logic;
		write_mem_busy_qdr_C : in std_logic;
		--memory's signals
		-- qdr A
		user_ad_rd_qdr_A : out std_logic_vector(19-1 downto 0);
		user_r_n_qdr_A : out std_logic;
		user_qrh_qdr_A : in std_logic_vector(36-1 downto 0);
		user_qrl_qdr_A : in std_logic_vector(36-1 downto 0);
		user_rd_full_qdr_A : in std_logic;
		user_qr_valid_qdr_A : in std_logic;
		-- qdr B
		user_ad_rd_qdr_B : out std_logic_vector(19-1 downto 0);
		user_r_n_qdr_B : out std_logic;
		user_qrh_qdr_B : in std_logic_vector(36-1 downto 0);
		user_qrl_qdr_B : in std_logic_vector(36-1 downto 0);
		user_rd_full_qdr_B : in std_logic;
		user_qr_valid_qdr_B : in std_logic;
		-- qdr C
		user_ad_rd_qdr_C : out std_logic_vector(19-1 downto 0);
		user_r_n_qdr_C : out std_logic;
		user_qrh_qdr_C : in std_logic_vector(36-1 downto 0);
		user_qrl_qdr_C : in std_logic_vector(36-1 downto 0);
		user_rd_full_qdr_C : in std_logic;
		user_qr_valid_qdr_C : in std_logic;
		-- flow output fifo
		fifo_exp_rst : out std_logic;
		fifo_w_exp_en : out std_logic;
		fifo_in_exp : out std_logic_vector(258-1 downto 0);
		fifo_full_exp : in std_logic
	);

end entity create_update_erase_flows;

architecture  create_update_erase_flows_arch of create_update_erase_flows is
--ACTIVE_TIME_OUT & INACTIVE_TIME_OUT	
	constant ACTIVE_TIME_OUT : std_logic_vector(32-1 downto 0)     := x"000493E0";
	constant INACTIVE_TIME_OUT : std_logic_vector(32-1 downto 0) := x"00003A98";
	
	type fsm_r_type is (s0,s1,s2,new_flow_qdr_A,new_flow_qdr_B,new_flow_qdr_C,found_5tuple_qdr_A,found_5tuple_qdr_B,found_5tuple_qdr_C,write_flow_on_qdr_A,write_flow_on_qdr_B,write_flow_on_qdr_C,exp0,exp1,exp2,expA,expB,expC);
	signal fsm_r : fsm_r_type;
	
	signal frame_information_reg : std_logic_vector(160-1 downto 0);
	signal frame_ip_total_length : std_logic_vector(16-1 downto 0);
	signal frame_time_stamp : std_logic_vector(32-1 downto 0);
	signal frame_tcp_flags : std_logic_vector(8-1 downto 0);
	signal frame_reg_5tuple : std_logic_vector(104-1 downto 0);
	signal hash_code_int : std_logic_vector(18-1 downto 0);
	signal hash_code_exp : std_logic_vector(18-1 downto 0);
	
	signal flow_ip_total_length : std_logic_vector(32-1 downto 0);
	signal flow_frame_counter : std_logic_vector(32-1 downto 0);
	signal flow_last_time_stamp : std_logic_vector(32-1 downto 0);
	signal flow_initial_time_stamp : std_logic_vector(32-1 downto 0);
	signal flow_tcp_flags : std_logic_vector(8-1 downto 0);
	
	signal user_rd_full : std_logic;
	
	signal linear_counter : std_logic_vector(18-1 downto 0);
	signal collision_counter_int : std_logic_vector(32-1 downto 0);
	
	type fsm_rcv_data_qdr_type is (s0,s1);
	signal fsm_rcv_data_qdr_A, fsm_rcv_data_qdr_B, fsm_rcv_data_qdr_C : fsm_rcv_data_qdr_type;
	signal data_read_qdr_A : std_logic_vector(144-1 downto 0);
	signal read_ready_qdr_A : std_logic;
	signal data_read_qdr_B : std_logic_vector(144-1 downto 0);
	signal read_ready_qdr_B : std_logic;
	signal data_read_qdr_C : std_logic_vector(144-1 downto 0);
	signal read_ready_qdr_C : std_logic;	
	
	signal flow_entry_5tuple_qdr_A : std_logic_vector(104-1 downto 0);
	signal flow_entry_5tuple_qdr_B : std_logic_vector(104-1 downto 0);
	signal flow_entry_5tuple_qdr_C : std_logic_vector(104-1 downto 0);
	signal flow_entry_data_flow : std_logic_vector(136-1 downto 0);

	signal flow_reg_5tuple : std_logic_vector(104-1 downto 0);
	signal flow_entry_5tuple_exp_qdr_A : std_logic_vector(104-1 downto 0);
	signal flow_entry_5tuple_exp_qdr_B : std_logic_vector(104-1 downto 0);
	signal flow_entry_5tuple_exp_qdr_C : std_logic_vector(104-1 downto 0);
	signal flow_entry_data_flow_exp_qdr_A : std_logic_vector(136-1 downto 0);
	signal flow_entry_data_flow_exp_qdr_B : std_logic_vector(136-1 downto 0);
	signal flow_entry_data_flow_exp_qdr_C : std_logic_vector(136-1 downto 0);
	
	
	
begin
collision_counter <= collision_counter_int;

frame_ip_total_length <= frame_information_reg(16-1 downto 0);
frame_time_stamp <= frame_information_reg(48-1 downto 16);
frame_tcp_flags <= frame_information_reg(56-1 downto 48);
frame_reg_5tuple <= frame_information_reg(160-1 downto 56);

user_rd_full <= user_rd_full_qdr_A or user_rd_full_qdr_B or user_rd_full_qdr_C;

fifo_in_exp <= hash_code_exp & flow_reg_5tuple & flow_tcp_flags & flow_initial_time_stamp & flow_last_time_stamp & flow_frame_counter & flow_ip_total_length;

write_information <= frame_reg_5tuple & flow_tcp_flags & flow_initial_time_stamp & flow_last_time_stamp & flow_frame_counter & flow_ip_total_length;


Read_QDR: process(ACLK)
variable no_flow_match_on_qdr_A : std_logic;
variable no_flow_match_on_qdr_B : std_logic;
variable no_flow_match_on_qdr_C : std_logic;
variable read_ready_qdr_A_i : std_logic;
variable read_ready_qdr_B_i : std_logic;
variable read_ready_qdr_C_i : std_logic;
variable status_mem_entry_qdr_A : std_logic;
variable status_mem_entry_qdr_B : std_logic;
variable status_mem_entry_qdr_C : std_logic;
variable status_mem_entry_exp_qdr_A : std_logic;
variable status_mem_entry_exp_qdr_B : std_logic;
variable status_mem_entry_exp_qdr_C : std_logic;
variable flow_protocol_qdr_A : std_logic_vector(8-1 downto 0);
variable flow_protocol_qdr_B : std_logic_vector(8-1 downto 0);
variable flow_protocol_qdr_C : std_logic_vector(8-1 downto 0);
variable frame_protocol : std_logic_vector(8-1 downto 0);
variable frame_fin_rst_flags : std_logic;
variable flow_fin_rst_flags_qdr_A : std_logic;
variable flow_fin_rst_flags_qdr_B : std_logic;
variable flow_fin_rst_flags_qdr_C : std_logic;
variable current_active_time_qdr_A : std_logic_vector(32-1 downto 0);
variable current_INactive_time_qdr_A : std_logic_vector(32-1 downto 0);
variable current_active_time_qdr_B : std_logic_vector(32-1 downto 0);
variable current_INactive_time_qdr_B : std_logic_vector(32-1 downto 0);
variable current_active_time_qdr_C : std_logic_vector(32-1 downto 0);
variable current_INactive_time_qdr_C : std_logic_vector(32-1 downto 0);
variable second_read_on : std_logic;
begin
if (ACLK'event and ACLK = '1') then
	if (memory_initialization_ready = '0') then
		user_ad_rd_qdr_A <= (others => '0');
		user_ad_rd_qdr_B <= (others => '0');
		user_ad_rd_qdr_C <= (others => '0');
		user_r_n_qdr_A <= '1';
		user_r_n_qdr_B <= '1';
		user_r_n_qdr_C <= '1';
		write_flow_qdr_A <= '0';
		write_flow_qdr_B <= '0';
		write_flow_qdr_C <= '0';
		erase_flow_qdr_A <= '0';
		erase_flow_qdr_B <= '0';
		erase_flow_qdr_C <= '0';
		linear_counter <= (others => '0');
		hash_seen <= '0';
		collision_counter_int <= (others => '0');
		second_read_on := '0';
		fifo_exp_rst <= '1';
		fifo_w_exp_en <= '0';
		fsm_r <= s0;
	else
		fifo_exp_rst <= '0';
		fifo_w_exp_en <= '0';
		write_flow_qdr_A <= '0';
		write_flow_qdr_B <= '0';
		write_flow_qdr_C <= '0';
		erase_flow_qdr_A <= '0';
		erase_flow_qdr_B <= '0';
		erase_flow_qdr_C <= '0';
		case fsm_r is
			when s0 =>
				read_ready_qdr_A_i := '0';
				read_ready_qdr_B_i := '0';
				read_ready_qdr_C_i := '0';
				no_flow_match_on_qdr_A := '0';
				no_flow_match_on_qdr_B := '0';
				no_flow_match_on_qdr_C := '0';
				if (second_read_on = '1') then
					fsm_r <= exp1;
				elsif (user_rd_full = '0') then
					if (hash_ready = '1') then
						hash_seen <= '1';
						frame_information_reg <= frame_information;
						hash_code_int <= hash_code_rd;
						user_ad_rd_qdr_A <= hash_code_rd & '0';
						user_r_n_qdr_A <= '0';
						user_ad_rd_qdr_B <= hash_code_rd & '0';
						user_r_n_qdr_B <= '0';
						user_ad_rd_qdr_C <= hash_code_rd & '0';
						user_r_n_qdr_C <= '0';
						fsm_r <= s1;
					else
						user_ad_rd_qdr_A <= linear_counter & '0';
						user_r_n_qdr_A <= '0';
						user_ad_rd_qdr_B <= linear_counter & '0';
						user_r_n_qdr_B <= '0';
						user_ad_rd_qdr_C <= linear_counter & '0';
						user_r_n_qdr_C <= '0';
						fsm_r <= exp0;
					end if;
				end if;
				second_read_on := '0';
			when s1 =>
				hash_seen <= '0';
				user_r_n_qdr_A <= '1';
				user_r_n_qdr_B <= '1';
				user_r_n_qdr_C <= '1';
				frame_protocol := frame_reg_5tuple(8-1 downto 0);
				frame_fin_rst_flags := frame_tcp_flags(0) or frame_tcp_flags(2);
				flow_reg_5tuple <= frame_reg_5tuple;
				hash_code_exp <= hash_code_int;
				if (read_ready_qdr_A  = '1') then
					read_ready_qdr_A_i := '1';
					flow_entry_5tuple_qdr_A <= data_read_qdr_A(144-1 downto 40);
					status_mem_entry_qdr_A := data_read_qdr_A(0);
				end if;
				if (read_ready_qdr_B  = '1') then
					read_ready_qdr_B_i := '1';
					flow_entry_5tuple_qdr_B <= data_read_qdr_B(144-1 downto 40);
					status_mem_entry_qdr_B := data_read_qdr_B(0);
				end if;
				if (read_ready_qdr_C  = '1') then
					read_ready_qdr_C_i := '1';
					flow_entry_5tuple_qdr_C <= data_read_qdr_C(144-1 downto 40);
					status_mem_entry_qdr_C := data_read_qdr_C(0);
				end if;
				if (read_ready_qdr_A_i = '1' and read_ready_qdr_B_i = '1' and read_ready_qdr_C_i = '1') then
					read_ready_qdr_A_i := '0';
					read_ready_qdr_B_i := '0';
					read_ready_qdr_C_i := '0';
					fsm_r <= s2;
				end if;
			when s2 =>	
				mem_addr_w <= hash_code_int;
				if (status_mem_entry_qdr_A = '1') then
					if (flow_entry_5tuple_qdr_A = frame_reg_5tuple) then
						user_ad_rd_qdr_A <= hash_code_int & '1';
						user_r_n_qdr_A <= '0';
						fsm_r <= found_5tuple_qdr_A;
					else
						no_flow_match_on_qdr_A := '1';
					end if;
				end if;
				if (status_mem_entry_qdr_B = '1') then
					if (flow_entry_5tuple_qdr_B = frame_reg_5tuple) then
						user_ad_rd_qdr_B <= hash_code_int & '1';
						user_r_n_qdr_B <= '0';
						fsm_r <= found_5tuple_qdr_B;
					else
						no_flow_match_on_qdr_B := '1';
					end if;
				end if;
				if (status_mem_entry_qdr_C = '1') then
					if (flow_entry_5tuple_qdr_C = frame_reg_5tuple) then
						user_ad_rd_qdr_C <= hash_code_int & '1';
						user_r_n_qdr_C <= '0';
						fsm_r <= found_5tuple_qdr_C;
					else
						no_flow_match_on_qdr_C := '1';
					end if;
				end if;
				if (no_flow_match_on_qdr_A = '1' and no_flow_match_on_qdr_B = '1' and no_flow_match_on_qdr_C = '1' ) then
					collision_counter_int <= collision_counter_int +1;
					fsm_r <= s0;
				end if;
				if (status_mem_entry_qdr_A = '0' and status_mem_entry_qdr_B = '0' and status_mem_entry_qdr_C = '0') then
					fsm_r <= new_flow_qdr_A;
				end if;
				if (no_flow_match_on_qdr_A = '1' and status_mem_entry_qdr_B = '0'  and status_mem_entry_qdr_C = '0') then
					fsm_r <= new_flow_qdr_B;
				end if;
				if (no_flow_match_on_qdr_B = '1' and status_mem_entry_qdr_A = '0'  and status_mem_entry_qdr_C = '0') then
					fsm_r <= new_flow_qdr_A;
				end if;
				if (no_flow_match_on_qdr_C = '1' and status_mem_entry_qdr_A = '0'  and status_mem_entry_qdr_B = '0') then
					fsm_r <= new_flow_qdr_A;
				end if;
				if (no_flow_match_on_qdr_B = '1' and no_flow_match_on_qdr_C = '1' and status_mem_entry_qdr_A = '0') then
					fsm_r <= new_flow_qdr_A;
				end if;			
				if (no_flow_match_on_qdr_A = '1' and no_flow_match_on_qdr_C = '1' and status_mem_entry_qdr_B = '0') then
					fsm_r <= new_flow_qdr_B;
				end if;
				if (no_flow_match_on_qdr_A = '1' and no_flow_match_on_qdr_B = '1' and status_mem_entry_qdr_C = '0') then
					fsm_r <= new_flow_qdr_C;
				end if;
			when new_flow_qdr_A =>
				flow_ip_total_length <= x"0000" & frame_ip_total_length;
				flow_frame_counter <= x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= frame_time_stamp;
				flow_tcp_flags <= frame_tcp_flags;
				write_5tuple_and_flow_data <= '1';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write the new (expired) flow to mem
					if (fifo_full_exp = '0') then
						fifo_w_exp_en <= '1';
					end if;
					fsm_r <= s0;
				else
					if (write_mem_busy_qdr_A = '0') then
						write_flow_qdr_A <= '1';
						fsm_r <= s0;
					end if;
				end if;
			when new_flow_qdr_B =>
				flow_ip_total_length <= x"0000" & frame_ip_total_length;
				flow_frame_counter <= x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= frame_time_stamp;
				flow_tcp_flags <= frame_tcp_flags;
				write_5tuple_and_flow_data <= '1';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write the new (expired) flow to mem
					if (fifo_full_exp = '0') then
						fifo_w_exp_en <= '1';
					end if;
					fsm_r <= s0;
				else
					if (write_mem_busy_qdr_B = '0') then
						write_flow_qdr_B <= '1';
						fsm_r <= s0;
					end if;
				end if;
			when new_flow_qdr_C =>
				flow_ip_total_length <= x"0000" & frame_ip_total_length;
				flow_frame_counter <= x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= frame_time_stamp;
				flow_tcp_flags <= frame_tcp_flags;
				write_5tuple_and_flow_data <= '1';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write the new (expired) flow to mem
					if (fifo_full_exp = '0') then
						fifo_w_exp_en <= '1';
					end if;
					fsm_r <= s0;
				else
					if (write_mem_busy_qdr_C = '0') then
						write_flow_qdr_C <= '1';
						fsm_r <= s0;
					end if;
				end if;
			when found_5tuple_qdr_A =>
				user_r_n_qdr_A <= '1';
				flow_entry_data_flow <= data_read_qdr_A(136-1 downto 0);
				if (read_ready_qdr_A  = '1') then
					fsm_r <= write_flow_on_qdr_A;
				end if;
			when write_flow_on_qdr_A =>
				flow_ip_total_length <= flow_entry_data_flow(32-1 downto 0) + (x"0000" & frame_ip_total_length);
				flow_frame_counter <= flow_entry_data_flow(64-1 downto 32) + x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= flow_entry_data_flow(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow(136-1 downto 128) or frame_tcp_flags;
				write_5tuple_and_flow_data <= '0';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write write back the flow to mem
					if (fifo_full_exp = '0' and write_mem_busy_qdr_A = '0') then
						erase_flow_qdr_A <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= s0;
					end if;
				elsif (write_mem_busy_qdr_A = '0') then
					write_flow_qdr_A <= '1';
					fsm_r <= s0;
				end if;
			when found_5tuple_qdr_B =>
				user_r_n_qdr_B <= '1';
				flow_entry_data_flow <= data_read_qdr_B(136-1 downto 0);
				if (read_ready_qdr_B  = '1') then
					fsm_r <= write_flow_on_qdr_B;
				end if;
			when write_flow_on_qdr_B =>
				flow_ip_total_length <= flow_entry_data_flow(32-1 downto 0) + (x"0000" & frame_ip_total_length);
				flow_frame_counter <= flow_entry_data_flow(64-1 downto 32) + x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= flow_entry_data_flow(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow(136-1 downto 128) or frame_tcp_flags;
				write_5tuple_and_flow_data <= '0';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write write back the flow to mem
					if (fifo_full_exp = '0' and write_mem_busy_qdr_B = '0') then
						erase_flow_qdr_B <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= s0;
					end if;
				elsif (write_mem_busy_qdr_B = '0') then
					write_flow_qdr_B <= '1';
					fsm_r <= s0;
				end if;
			when found_5tuple_qdr_C =>
				user_r_n_qdr_C <= '1';
				flow_entry_data_flow <= data_read_qdr_C(136-1 downto 0);
				if (read_ready_qdr_C  = '1') then
					fsm_r <= write_flow_on_qdr_C;
				end if;
			when write_flow_on_qdr_C =>
				flow_ip_total_length <= flow_entry_data_flow(32-1 downto 0) + (x"0000" & frame_ip_total_length);
				flow_frame_counter <= flow_entry_data_flow(64-1 downto 32) + x"00000001";
				flow_last_time_stamp <= frame_time_stamp;
				flow_initial_time_stamp <= flow_entry_data_flow(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow(136-1 downto 128) or frame_tcp_flags;
				write_5tuple_and_flow_data <= '0';
				if (frame_protocol = x"06" and frame_fin_rst_flags = '1') then -- don't write write back the flow to mem
					if (fifo_full_exp = '0' and write_mem_busy_qdr_C = '0') then
						erase_flow_qdr_C <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= s0;
					end if;
				elsif (write_mem_busy_qdr_C = '0') then
					write_flow_qdr_C <= '1';
					fsm_r <= s0;
				end if;
			-- Lookup for expired flows
			when exp0 =>
				user_r_n_qdr_A <= '1';
				user_r_n_qdr_B <= '1';
				user_r_n_qdr_C <= '1';
				if (read_ready_qdr_A  = '1') then
					read_ready_qdr_A_i := '1';
					flow_entry_5tuple_exp_qdr_A <= data_read_qdr_A(144-1 downto 40);
					status_mem_entry_exp_qdr_A := data_read_qdr_A(0);
				end if;
				if (read_ready_qdr_B  = '1') then
					read_ready_qdr_B_i := '1';
					flow_entry_5tuple_exp_qdr_B <= data_read_qdr_B(144-1 downto 40);
					status_mem_entry_exp_qdr_B := data_read_qdr_B(0);
				end if;
				if (read_ready_qdr_C  = '1') then
					read_ready_qdr_C_i := '1';
					flow_entry_5tuple_exp_qdr_C <= data_read_qdr_C(144-1 downto 40);
					status_mem_entry_exp_qdr_C := data_read_qdr_C(0);
				end if;
				hash_seen <= '0';
				if (read_ready_qdr_A_i = '1' and read_ready_qdr_B_i = '1' and read_ready_qdr_C_i = '1') then
					read_ready_qdr_A_i := '0';
					read_ready_qdr_B_i := '0';
					read_ready_qdr_C_i := '0';
					fsm_r <= exp1;
				elsif (user_rd_full = '0' and hash_ready = '1' and second_read_on = '0') then
					hash_seen <= '1';
					frame_information_reg <= frame_information;
					hash_code_int <= hash_code_rd;
					user_ad_rd_qdr_A <= hash_code_rd & '0';
					user_r_n_qdr_A <= '0';
					user_ad_rd_qdr_B <= hash_code_rd & '0';
					user_r_n_qdr_B <= '0';
					user_ad_rd_qdr_C <= hash_code_rd & '0';
					user_r_n_qdr_C <= '0';
					second_read_on := '1';
				end if;
			when exp1 =>
				if (second_read_on = '1') then
					if (read_ready_qdr_A  = '1') then
						flow_entry_5tuple_qdr_A <= data_read_qdr_A(104-1 downto 0);
						status_mem_entry_qdr_A := data_read_qdr_A(0);
						read_ready_qdr_A_i := '1';
					end if;
					if (read_ready_qdr_B  = '1') then
						flow_entry_5tuple_qdr_B <= data_read_qdr_B(104-1 downto 0);
						status_mem_entry_qdr_B := data_read_qdr_B(0);
						read_ready_qdr_B_i := '1';
					end if;
					if (read_ready_qdr_C  = '1') then
						flow_entry_5tuple_qdr_C <= data_read_qdr_C(104-1 downto 0);
						status_mem_entry_qdr_C := data_read_qdr_C(0);
						read_ready_qdr_C_i := '1';
					end if;
					fsm_r <= s1;
				else
					if (status_mem_entry_exp_qdr_A = '1') then
						user_ad_rd_qdr_A <= linear_counter & '1';
						user_r_n_qdr_A <= '0';
					end if;
					if (status_mem_entry_exp_qdr_B = '1') then
						user_ad_rd_qdr_B <= linear_counter & '1';
						user_r_n_qdr_B <= '0';
					end if;
					if (status_mem_entry_exp_qdr_C = '1') then
						user_ad_rd_qdr_C <= linear_counter & '1';
						user_r_n_qdr_C <= '0';
					end if;
					if (status_mem_entry_exp_qdr_A = '0' and status_mem_entry_exp_qdr_B = '0' and status_mem_entry_exp_qdr_C = '0') then
						linear_counter <= linear_counter + 1;
						fsm_r <= s0;
					else
						fsm_r <= exp2;
					end if;
				end if;
			when exp2 =>
				user_r_n_qdr_A <= '1';
				user_r_n_qdr_B <= '1';
				user_r_n_qdr_C <= '1';
				flow_entry_data_flow_exp_qdr_A <= data_read_qdr_A(136-1 downto 0);
				flow_fin_rst_flags_qdr_A := data_read_qdr_A(128) or data_read_qdr_A(130);
				flow_protocol_qdr_A := flow_entry_5tuple_exp_qdr_A(8-1 downto 0);
				current_active_time_qdr_A := time_stamp_counter - data_read_qdr_A(127 downto 96);
				current_INactive_time_qdr_A := time_stamp_counter - data_read_qdr_A(95 downto 64);
				if (read_ready_qdr_A  = '1') then
					read_ready_qdr_A_i := '1';
				end if;
				flow_entry_data_flow_exp_qdr_B <= data_read_qdr_B(136-1 downto 0);
				flow_fin_rst_flags_qdr_B := data_read_qdr_B(128) or data_read_qdr_B(130);
				flow_protocol_qdr_B := flow_entry_5tuple_exp_qdr_B(8-1 downto 0);
				current_active_time_qdr_B := time_stamp_counter - data_read_qdr_B(127 downto 96);
				current_INactive_time_qdr_B := time_stamp_counter - data_read_qdr_B(95 downto 64);
				if (read_ready_qdr_B  = '1') then
					read_ready_qdr_B_i := '1';
				end if;
				flow_entry_data_flow_exp_qdr_C <= data_read_qdr_C(136-1 downto 0);
				flow_fin_rst_flags_qdr_C := data_read_qdr_C(128) or data_read_qdr_C(130);
				flow_protocol_qdr_C := flow_entry_5tuple_exp_qdr_B(8-1 downto 0);
				current_active_time_qdr_C := time_stamp_counter - data_read_qdr_C(127 downto 96);
				current_INactive_time_qdr_C := time_stamp_counter - data_read_qdr_C(95 downto 64);
				if (read_ready_qdr_C  = '1') then
					read_ready_qdr_C_i := '1';
				end if;
				if ((read_ready_qdr_A_i = '1' or status_mem_entry_exp_qdr_A = '0') and (read_ready_qdr_B_i = '1' or status_mem_entry_exp_qdr_B = '0') and (read_ready_qdr_C_i = '1' or status_mem_entry_exp_qdr_C = '0')) then
					read_ready_qdr_A_i := '0';
					read_ready_qdr_B_i := '0';
					read_ready_qdr_C_i := '0';
					fsm_r <= expA;
				end if;
			when expA =>
				mem_addr_w <= linear_counter;
				flow_ip_total_length <= flow_entry_data_flow_exp_qdr_A(32-1 downto 0);
				flow_reg_5tuple <= flow_entry_5tuple_exp_qdr_A;
				flow_frame_counter <= flow_entry_data_flow_exp_qdr_A(64-1 downto 32);
				flow_last_time_stamp <= flow_entry_data_flow_exp_qdr_A(96-1 downto 64);
				flow_initial_time_stamp <= flow_entry_data_flow_exp_qdr_A(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow_exp_qdr_A(136-1 downto 128);
				hash_code_exp <= linear_counter;
				if ((current_active_time_qdr_A >= ACTIVE_TIME_OUT or current_INactive_time_qdr_A >= INACTIVE_TIME_OUT or (flow_fin_rst_flags_qdr_A = '1' and flow_protocol_qdr_A = x"06")) and status_mem_entry_exp_qdr_A = '1') then
					if (write_mem_busy_qdr_A = '0' and fifo_full_exp = '0') then
						erase_flow_qdr_A <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= expB;
					end if;
				else
					fsm_r <= expB;
				end if;
			when expB =>
				flow_ip_total_length <= flow_entry_data_flow_exp_qdr_B(32-1 downto 0);
				flow_reg_5tuple <= flow_entry_5tuple_exp_qdr_B;
				flow_frame_counter <= flow_entry_data_flow_exp_qdr_B(64-1 downto 32);
				flow_last_time_stamp <= flow_entry_data_flow_exp_qdr_B(96-1 downto 64);
				flow_initial_time_stamp <= flow_entry_data_flow_exp_qdr_B(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow_exp_qdr_B(136-1 downto 128);
				if ((current_active_time_qdr_B >= ACTIVE_TIME_OUT or current_INactive_time_qdr_B >= INACTIVE_TIME_OUT or (flow_fin_rst_flags_qdr_B = '1' and flow_protocol_qdr_B = x"06")) and status_mem_entry_exp_qdr_B = '1') then
					if (write_mem_busy_qdr_B = '0' and fifo_full_exp = '0') then
						erase_flow_qdr_B <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= expC;
					end if;
				else
					fsm_r <= expC;
				end if;
			when expC =>
				flow_ip_total_length <= flow_entry_data_flow_exp_qdr_C(32-1 downto 0);
				flow_reg_5tuple <= flow_entry_5tuple_exp_qdr_C;
				flow_frame_counter <= flow_entry_data_flow_exp_qdr_C(64-1 downto 32);
				flow_last_time_stamp <= flow_entry_data_flow_exp_qdr_C(96-1 downto 64);
				flow_initial_time_stamp <= flow_entry_data_flow_exp_qdr_C(128-1 downto 96);
				flow_tcp_flags <= flow_entry_data_flow_exp_qdr_C(136-1 downto 128);
				if ((current_active_time_qdr_C >= ACTIVE_TIME_OUT or current_INactive_time_qdr_C >= INACTIVE_TIME_OUT or (flow_fin_rst_flags_qdr_C = '1' and flow_protocol_qdr_C = x"06")) and status_mem_entry_exp_qdr_C = '1') then
					if (write_mem_busy_qdr_C = '0' and fifo_full_exp = '0') then
						erase_flow_qdr_C <= '1';
						fifo_w_exp_en <= '1';
						fsm_r <= s0;
					end if;
				else
					fsm_r <= s0;
				end if;
			when others =>
		end case;
	end if;
end if;
end process;


receive_qdr_A: process(ACLK)
begin
if (ACLK'event and ACLK = '1') then
	if (memory_initialization_ready = '0') then
		data_read_qdr_A <= (others => '0');
		read_ready_qdr_A <= '0';
		fsm_rcv_data_qdr_A <= s0;
	else
		case fsm_rcv_data_qdr_A is
			when s0 =>
				read_ready_qdr_A <= '0';
				if (user_qr_valid_qdr_A = '1') then
					data_read_qdr_A(71 downto 0) <= user_qrh_qdr_A & user_qrl_qdr_A;
					fsm_rcv_data_qdr_A <= s1;
				end if;
			when s1 =>
				if (user_qr_valid_qdr_A = '1') then
					data_read_qdr_A(143 downto 72) <= user_qrh_qdr_A & user_qrl_qdr_A;
					read_ready_qdr_A <= '1';
					fsm_rcv_data_qdr_A <= s0;
				end if;
		end case;
	end if;
end if;
end process;

receive_qdr_B: process(ACLK)
begin
if (ACLK'event and ACLK = '1') then
	if (memory_initialization_ready = '0') then
		data_read_qdr_B <= (others => '0');
		read_ready_qdr_B <= '0';
		fsm_rcv_data_qdr_B <= s0;
	else
		case fsm_rcv_data_qdr_B is
			when s0 =>
				read_ready_qdr_B <= '0';
				if (user_qr_valid_qdr_B = '1') then
					data_read_qdr_B(71 downto 0) <= user_qrh_qdr_B & user_qrl_qdr_B;
					fsm_rcv_data_qdr_B <= s1;
				end if;
			when s1 =>
				if (user_qr_valid_qdr_B = '1') then
					data_read_qdr_B(143 downto 72) <= user_qrh_qdr_B & user_qrl_qdr_B;
					read_ready_qdr_B <= '1';
					fsm_rcv_data_qdr_B <= s0;
				end if;
		end case;
	end if;
end if;
end process;

receive_qdr_C: process(ACLK)
begin
if (ACLK'event and ACLK = '1') then
	if (memory_initialization_ready = '0') then
		data_read_qdr_C <= (others => '0');
		read_ready_qdr_C <= '0';
		fsm_rcv_data_qdr_C <= s0;
	else
		case fsm_rcv_data_qdr_C is
			when s0 =>
				read_ready_qdr_C <= '0';
				if (user_qr_valid_qdr_C = '1') then
					data_read_qdr_C(71 downto 0) <= user_qrh_qdr_C & user_qrl_qdr_C;
					fsm_rcv_data_qdr_C <= s1;
				end if;
			when s1 =>
				if (user_qr_valid_qdr_C = '1') then
					data_read_qdr_C(143 downto 72) <= user_qrh_qdr_C & user_qrl_qdr_C;
					read_ready_qdr_C <= '1';
					fsm_rcv_data_qdr_C <= s0;
				end if;
		end case;
	end if;
end if;
end process;


end architecture create_update_erase_flows_arch;