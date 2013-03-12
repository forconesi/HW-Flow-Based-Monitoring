-- ******************************************************************************
 -- *  Design:
 -- *        NF_QDR
 -- *  
 -- *  File:
 -- *        pkt_classification.vhd
 -- *
 -- *  Pcore:
  -- *        flow_capture_qdrii
 -- *
 -- *  Authors:
 -- *        Marco Forconesi, Gustavo Sutter, Sergio Lopez-Buedo
 -- *
 -- *  Description:
 -- *        This module extracts the 5-tuple of each Ethernet frame and time stamps
 -- *        the frame. Additional information is extracted from the frame:
 -- *         - Number of bytes in the IP Total Length field of IPv4 packet
 -- *         - TCP flags, if protocol is TCP
 -- *        Assumes a 64-bits AXI4-Stream connection.
 -- *        If the Ethernet frame that interface is receiving is not valid
 -- *        (refer to the documentation to see the valid frames) the frame is
 -- *        discarded.
 -- *        The composition of the 5-tuple:
 -- *         - SOURCE-IP, DEST-IP,
 -- *         - SOURCE_TCP/UDP_PORT, DEST_TCP/UDP_PORT,
 -- *         - PROTOCOL_OF_TRANSPORT_LAYER
-- ******************************************************************************


library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;


entity pkt_classification is
generic (
	SIM_ONLY : integer := 0
	); 
port(
		-- AXI-Stream slave interface
		ACLK  : in  std_logic;	
		ARESETN  : in  std_logic;
		S_AXIS_TREADY  : out  std_logic;
		S_AXIS_TDATA  : in  std_logic_vector(64-1 downto 0);
		S_AXIS_TSTRB    : in    std_logic_vector (64/8-1 downto 0);
		S_AXIS_TLAST  : in  std_logic;
		S_AXIS_TVALID  : in  std_logic;
		--Output counters
		output_counters	: out  std_logic_vector(96-1 downto 0);
		time_stamp_counter_out : out std_logic_vector(32-1 downto 0);
		--Fifo's signals
		fifo_in		: out  std_logic_vector(160-1 downto 0);
		fifo_rst		: out std_logic;
		fifo_w_en		: out  std_logic;
		fifo_full	: in std_logic
	
	);

end entity pkt_classification;

architecture  pkt_classification_arch of pkt_classification is

-- Extractor 5 Tuple's signals
	-- Elements
	type extract_fsm_type is (IDLE_STATE, DONT_TRANSMIT_STATE, TRANSMIT_STATE, RCV_1, RCV_ipv4_no_vlan_0, RCV_ipv4_no_vlan_1,
	RCV_ipv4_no_vlan_2, RCV_ipv4_no_vlan_3, RCV_ipv4_vlan1_0, RCV_ipv4_vlan1_1, RCV_ipv4_vlan1_2, RCV_ipv4_vlan1_3, RCV_ipv4_vlan1_4,
	RCV_ipv4_vlan2_0, RCV_ipv4_vlan2_1, RCV_ipv4_vlan2_2, RCV_ipv4_vlan2_3);
	signal extract_fsm : extract_fsm_type;
	signal S_AXIS_TDATA_rev : std_logic_vector(64-1 downto 0);
	signal time_stamp_counter : std_logic_vector(32-1 downto 0);
	signal divisor_for_miliseconds : integer;
	signal reg_5tuple    : std_logic_vector(104-1 downto 0);
	-- Some flags
	signal new_packet  : std_logic;
	-- Frame Information
	signal  frame_ip_total_length : std_logic_vector(15 downto 0);
	signal frame_tcp_flags : std_logic_vector(7 downto 0);
	signal frame_time_stamp : std_logic_vector(32-1 downto 0);
	-- output counters
	signal accepted_packets : std_logic_vector(32-1 downto 0);
	signal processed_packets : std_logic_vector(32-1 downto 0);
	signal lost_pkts_fifo_full : std_logic_vector(32-1 downto 0);
	signal max_count : integer;

begin

time_stamp_counter_out <= time_stamp_counter;
output_counters <= processed_packets & accepted_packets & lost_pkts_fifo_full;

-- Reverse the byte order
S_AXIS_TDATA_rev(64-1 downto 56) 	<= S_AXIS_TDATA(8-1 downto 0);
S_AXIS_TDATA_rev(56-1 downto 48) 	<= S_AXIS_TDATA(16-1 downto 8);
S_AXIS_TDATA_rev(48-1 downto 40) 	<= S_AXIS_TDATA(24-1 downto 16);
S_AXIS_TDATA_rev(40-1 downto 32) 	<= S_AXIS_TDATA(32-1 downto 24);
S_AXIS_TDATA_rev(32-1 downto 24) 	<= S_AXIS_TDATA(40-1 downto 32);
S_AXIS_TDATA_rev(24-1 downto 16) 	<= S_AXIS_TDATA(48-1 downto 40);
S_AXIS_TDATA_rev(16-1 downto 8)  	 	<= S_AXIS_TDATA(56-1 downto 48);
S_AXIS_TDATA_rev(8-1 downto 0)     		<= S_AXIS_TDATA(64-1 downto 56);



max_count <= 200000 when (SIM_ONLY = 0) else 20;


timestamp_counter: process(ACLK)
	variable start_time_counter : std_logic;
begin
	if (ACLK'event and ACLK = '1') then
		if (ARESETN = '0') then                    
			time_stamp_counter <= (others => '0');
			divisor_for_miliseconds <= 0;
			start_time_counter := '0';
		else
			if (S_AXIS_TVALID = '1') then
				start_time_counter := '1';
			end if;
			if (start_time_counter = '1' ) then
				if (divisor_for_miliseconds = max_count) then
					divisor_for_miliseconds <= 0;
					time_stamp_counter <= time_stamp_counter +1;
				else
					divisor_for_miliseconds <= divisor_for_miliseconds +1;
				end if;
			end if;
		end if;	
	end if;	
end process timestamp_counter; 


extractor_5_tuple_process: process(ACLK)
variable accepted_packets_plusplus : std_logic;
variable lost_pkts_fifo_full_plusplus : std_logic;
begin
	if (ACLK'event and ACLK = '1') then
		if (ARESETN = '0') then                    
			fifo_rst <= '1';
			new_packet <= '1';
			S_AXIS_TREADY <= '0';
			processed_packets <= (others => '0');
			accepted_packets <= (others => '0');
			lost_pkts_fifo_full <= (others => '0');
			fifo_w_en <= '0';
			accepted_packets_plusplus := '0';
			lost_pkts_fifo_full_plusplus := '0';
			extract_fsm <= IDLE_STATE;
		else
			fifo_rst <= '0';
			fifo_w_en <= '0';
			fifo_in <= reg_5tuple & frame_tcp_flags & frame_time_stamp & frame_ip_total_length;
			S_AXIS_TREADY <= '1';                                --the slave must always be ready according to the 10G-MAC core specification
			if (S_AXIS_TVALID = '1' and new_packet = '1') then
				new_packet <= '0';
				frame_time_stamp <= time_stamp_counter;              --Time stamp is aligned to the start of the ethernet frame.
			end if;
			if accepted_packets_plusplus = '1' then
				accepted_packets_plusplus := '0';
				accepted_packets <= accepted_packets +1;
			end if;
			if lost_pkts_fifo_full_plusplus = '1' then
				lost_pkts_fifo_full_plusplus := '0';
				lost_pkts_fifo_full <= lost_pkts_fifo_full +1;					
			end if;
			case extract_fsm is
				when IDLE_STATE =>
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_1;														--do nothing for the first AXIS transaction
					end if;
				when RCV_1 =>
					processed_packets <= processed_packets +1;
					if (S_AXIS_TVALID = '1') then
						if (S_AXIS_TDATA_rev(31 downto 16) = x"0800" and S_AXIS_TDATA_rev(15 downto 12) = x"4") then --if  IPv4
							extract_fsm <= RCV_ipv4_no_vlan_0;
						elsif (S_AXIS_TDATA_rev(31 downto 16) = x"8100") then
							extract_fsm <= RCV_ipv4_vlan1_0;
						else                                                           													  --if it isn't one of the others above
							extract_fsm <= DONT_TRANSMIT_STATE;                            --machine goes to wait the end of the current useless packet
						end if;
					end if;
				when RCV_ipv4_no_vlan_0 =>
					frame_ip_total_length <= S_AXIS_TDATA_rev(63 downto 48);      --save the ip total lengt
					reg_5tuple(7 downto 0) <= S_AXIS_TDATA_rev(7 downto 0);         --save the PROTOCOL
					if (S_AXIS_TVALID = '1') then
						if (S_AXIS_TDATA_rev(7 downto 0) = x"06" or S_AXIS_TDATA_rev(7 downto 0) = x"11") then      --if TCP or UDP
							extract_fsm <= RCV_ipv4_no_vlan_1;
						else
							extract_fsm <= DONT_TRANSMIT_STATE;                          --machine goes to wait the end of the current useless packet
						end if;
					end if;	
				when RCV_ipv4_no_vlan_1 =>
					reg_5tuple(103 downto 72) <= S_AXIS_TDATA_rev(47 downto 16);       --source IP
					reg_5tuple(71 downto 56) <= S_AXIS_TDATA_rev(15 downto 0);         --half destination IP
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_no_vlan_2;
					end if;
				when RCV_ipv4_no_vlan_2 =>
					reg_5tuple(55 downto 40) <= S_AXIS_TDATA_rev(63 downto 48);         --2nd half destination IP
					reg_5tuple(39 downto 24) <= S_AXIS_TDATA_rev(47 downto 32);         --source port
					reg_5tuple(23 downto 8) <= S_AXIS_TDATA_rev(31 downto 16);           --destination port
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_no_vlan_3;
					end if;
				when RCV_ipv4_no_vlan_3 =>
					frame_tcp_flags <= S_AXIS_TDATA_rev(7 downto 0);                      					--save this information even if not TCP. The next unit will manage this information
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= TRANSMIT_STATE;
					end if;
				--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				when RCV_ipv4_vlan1_0 =>
					frame_ip_total_length <= S_AXIS_TDATA_rev(31 downto 16);      --save the ip total lengt
					if (S_AXIS_TVALID = '1') then
						if (S_AXIS_TDATA_rev(63 downto 48) = x"8100" and S_AXIS_TDATA_rev(31 downto 16) = x"0800" and S_AXIS_TDATA_rev(15 downto 12) = x"4") then -- if 2 vlan and ipv4
							extract_fsm <= RCV_ipv4_vlan2_0;
						elsif (S_AXIS_TDATA_rev(63 downto 48) = x"0800" and S_AXIS_TDATA_rev(47 downto 44) = x"4") then			--if  IPv4
							extract_fsm <= RCV_ipv4_vlan1_1;
						else
							extract_fsm <= DONT_TRANSMIT_STATE;                          --machine goes to wait the end of the current useless packet
						end if;
					end if;
				when RCV_ipv4_vlan1_1 =>
					reg_5tuple(7 downto 0) <= S_AXIS_TDATA_rev(39 downto 32);         --save the PROTOCOL
					reg_5tuple(103 downto 88) <= S_AXIS_TDATA_rev(15 downto 0);       --half source IP
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan1_2;
					end if;
				when RCV_ipv4_vlan1_2 =>
					reg_5tuple(87 downto 72) <= S_AXIS_TDATA_rev(63 downto 48);       --2nd half source IP
					reg_5tuple(71 downto 40) <= S_AXIS_TDATA_rev(47 downto 16);         --destination IP
					reg_5tuple(39 downto 24) <= S_AXIS_TDATA_rev(15 downto 0);         --source port
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan1_3;
					end if;
				when RCV_ipv4_vlan1_3 =>
					reg_5tuple(23 downto 8) <= S_AXIS_TDATA_rev(63 downto 48);           --destination port
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan1_4;
					end if;
				when RCV_ipv4_vlan1_4 =>
					frame_tcp_flags <= S_AXIS_TDATA_rev(39 downto 32);                      					--save this information even if not TCP. The next unit will manage this information
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= TRANSMIT_STATE;
					end if;
				--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				when RCV_ipv4_vlan2_0 =>
					frame_ip_total_length <= S_AXIS_TDATA_rev(63 downto 48);      --save the ip total lengt
					reg_5tuple(7 downto 0) <= S_AXIS_TDATA_rev(7 downto 0);         --save the PROTOCOL
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan2_1;
					end if;
				when RCV_ipv4_vlan2_1 =>
					reg_5tuple(103 downto 72) <= S_AXIS_TDATA_rev(47 downto 16);       --source IP
					reg_5tuple(71 downto 56) <= S_AXIS_TDATA_rev(15 downto 0);         --half destination IP
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan2_2;
					end if;
				when RCV_ipv4_vlan2_2 =>
					reg_5tuple(55 downto 40) <= S_AXIS_TDATA_rev(63 downto 48);         --2nd half destination IP
					reg_5tuple(39 downto 24) <= S_AXIS_TDATA_rev(47 downto 32);         --source port
					reg_5tuple(23 downto 8) <= S_AXIS_TDATA_rev(31 downto 16);           --destination port
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= RCV_ipv4_vlan2_3;			
					end if;
				when RCV_ipv4_vlan2_3 =>
					frame_tcp_flags <= S_AXIS_TDATA_rev(7 downto 0);                      					--save this information even if not TCP. The next unit will manage this information
					if (S_AXIS_TVALID = '1') then
						extract_fsm <= TRANSMIT_STATE;					
					end if;
				--//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
				when DONT_TRANSMIT_STATE =>                                  --wait for the current ethernet frame to finish. do not transmit de 5-tuple
					if (S_AXIS_TVALID = '1' and S_AXIS_TLAST = '1') then
						extract_fsm <= IDLE_STATE;                          --when last AXIS transaction, drive the machine to wait the next ethernet frame
						new_packet <= '1';
					end if;
				when TRANSMIT_STATE =>                                  --wait for the current ethernet frame to finish. transmit de 5-tuple and the timestap+frame_tcp_flags+numofbytes
					if (S_AXIS_TVALID = '1' and S_AXIS_TLAST = '1') then		-- we've to implement the crc verification line provided by the 10gmac
						new_packet <= '1';
						extract_fsm <= IDLE_STATE;
						if (fifo_full = '0') then
							fifo_w_en <= '1';
							accepted_packets_plusplus := '1'; 
						else
							lost_pkts_fifo_full_plusplus := '1';				--if fifo's full, then discard the packet
						end if;
					end if;
				when others =>
					extract_fsm <= DONT_TRANSMIT_STATE;
			end case;
		end if;
	end if;
end process;

end architecture pkt_classification_arch;