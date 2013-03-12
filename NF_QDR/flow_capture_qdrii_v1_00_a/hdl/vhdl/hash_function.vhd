library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity hash_function is
port(
		ACLK  : in  std_logic;	--clk0 as well
		ARESETN  : in  std_logic;
		--Input 5 tuple & frame info
		fifo_empty : in std_logic;
		fifo_out		: in  std_logic_vector(160-1 downto 0);
		fifo_rd_en : out std_logic;
		frame_information	: out  std_logic_vector(104+8+32+16-1 downto 0);
		hash_code_rd	: out  std_logic_vector(18-1 downto 0);
		hash_ready : out std_logic;
		hash_seen : in std_logic
	);

end entity hash_function;

architecture hash_function_arch of hash_function is
	
	constant fifty_nine : std_logic_vector(8-1 downto 0) := x"3B";

-- Mini buffer's signals
	type fsm_mini_buff_type is (s0,s1);
	signal fsm_mini_buff : fsm_mini_buff_type;
	signal hash_seen_int : std_logic;
	signal hash_ready_int : std_logic;
	signal hash_code_int : std_logic_vector(18-1 downto 0);

--hash's signals
	type fsm_hash_type is (s0,s1,s2,s3,s4,s5,s6);
	signal fsm_hash : fsm_hash_type;
	signal frame_ip_total_length : std_logic_vector(16-1 downto 0);
	signal frame_time_stamp : std_logic_vector(32-1 downto 0);
	signal frame_tcp_flags : std_logic_vector(8-1 downto 0);
	signal frame_5tuple : std_logic_vector(104-1 downto 0);

begin

frame_information <= frame_5tuple & frame_tcp_flags & frame_time_stamp & frame_ip_total_length;

Hash: process(ACLK)
variable aux : std_logic_vector(32-1 downto 0);
variable aux1 : std_logic_vector(40-1 downto 0);
variable src_ip, src_ip1 : std_logic_vector(32-1 downto 0);
variable dest_ip, dest_ip1 : std_logic_vector(32-1 downto 0);
variable src_port, src_port1 : std_logic_vector(16-1 downto 0);
variable dest_port, dest_port1 : std_logic_vector(16-1 downto 0);
variable protocol, protocol1 : std_logic_vector(8-1 downto 0);
begin
if (ACLK'event and ACLK = '1') then
	if (ARESETN = '0') then 
		hash_code_int <= (others => '0');
		hash_ready_int <= '0';
		fifo_rd_en <= '0';
		fsm_hash <= s0;
	else
		case fsm_hash is
			when s0 =>
				if (fifo_empty = '0') then
					fifo_rd_en <= '1';
					fsm_hash <= s1;
				end if;
			when s1 =>
				fsm_hash <= s2;
				fifo_rd_en <= '0';
			when s2 =>
				src_ip := fifo_out(159 downto 128);
				dest_ip := fifo_out(127 downto 96);
				src_port := fifo_out(95 downto 80);
				dest_port := fifo_out(79 downto 64);
				protocol := fifo_out(63 downto 56);
				fsm_hash <= s3;
			when s3 =>
				aux1 := src_ip * fifty_nine;
				src_ip1 := aux1(39 downto 8);
				dest_ip1 := dest_ip xor (src_port & dest_port);
				fsm_hash <= s4;
			when s4 =>
				aux := dest_ip1 xor src_ip1 xor (protocol & protocol & protocol & protocol);
				fsm_hash <= s5;
			when s5 =>
				hash_code_int <= aux(17 downto 0) xor aux(31 downto 14);
				hash_ready_int <= '1';
				fsm_hash <= s6;
			when s6 =>
				if (hash_seen_int = '1') then
					hash_ready_int <= '0';
					fsm_hash <= s0;
				end if;
		end case;
	end if;
end if;
end process;

mini_buffer: process(ACLK)
begin
if (ACLK'event and ACLK = '1') then
	if (ARESETN = '0') then 
		hash_seen_int <= '0';
		hash_ready <= '0';
		hash_code_rd <= (others => '0');
		fsm_mini_buff <= s0;
	else
		case fsm_mini_buff is
			when s0 =>
				frame_tcp_flags <= fifo_out(55 downto 48);
				frame_time_stamp <= fifo_out(47 downto 16);
				frame_ip_total_length <= fifo_out(15 downto 0);
				frame_5tuple <= fifo_out(159 downto 56);
				hash_code_rd <= hash_code_int;
				if (hash_ready_int = '1') then
					hash_seen_int <= '1';
					hash_ready <= '1';
					fsm_mini_buff <= s1;
				end if;
			when s1 =>
				hash_seen_int <= '0';
				if (hash_seen = '1') then
					hash_ready <= '0';
					fsm_mini_buff <= s0;
				end if;
		end case;
	end if;
end if;
end process;

end architecture hash_function_arch;