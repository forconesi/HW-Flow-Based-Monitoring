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
 -- *        Top module
-- ******************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

entity flow_capture_qdrii is
generic (
	SIM_ONLY : integer := 0
	); 
port (
	--clks & dcm_locked
	clk180  : in  std_logic;
	clk270  : in  std_logic;
	dcm_locked  : in  std_logic;
	--AXI-Stream slave interface
	ACLK  : in  std_logic;	--clk0 as well
	ARESETN  : in  std_logic;
	S_AXIS_TREADY  : out  std_logic;
	S_AXIS_TDATA  : in  std_logic_vector(64-1 downto 0);
	S_AXIS_TSTRB    : in    std_logic_vector (64/8-1 downto 0);
	S_AXIS_TLAST  : in  std_logic;
	S_AXIS_TVALID  : in  std_logic;
	M_AXIS_10GMAC_tdata       : out std_logic_vector (64-1 downto 0);
	M_AXIS_10GMAC_tstrb       : out std_logic_vector (64/8-1 downto 0);
	M_AXIS_10GMAC_tvalid      : out std_logic;
	M_AXIS_10GMAC_tready      : in  std_logic;
	M_AXIS_10GMAC_tlast       : out std_logic;
--Memory Interface C0
	c0_masterbank_sel_pin    : in    std_logic_vector((1-1) downto 0);
	c0_qdr_d                 : out   std_logic_vector((36-1) downto 0);
	c0_qdr_q                 : in    std_logic_vector((36-1) downto 0);
	c0_qdr_sa                : out   std_logic_vector((19-1) downto 0);
	c0_qdr_w_n               : out   std_logic;
	c0_qdr_r_n               : out   std_logic;
	c0_qdr_dll_off_n         : out   std_logic;
	c0_qdr_bw_n              : out   std_logic_vector((4-1) downto 0);
	c0_qdr_cq                : in    std_logic_vector((1-1) downto 0);
	c0_qdr_cq_n              : in    std_logic_vector((1-1) downto 0);
	c0_qdr_k                 : out   std_logic_vector((1-1) downto 0);
	c0_qdr_k_n               : out   std_logic_vector((1-1) downto 0);
	c0_qdr_c                 : out   std_logic_vector((1-1) downto 0);
	c0_qdr_c_n               : out   std_logic_vector((1-1) downto 0);
--Memory Interface C1
	c1_masterbank_sel_pin    : in    std_logic_vector((1-1) downto 0);
	c1_qdr_d                 : out   std_logic_vector((36-1) downto 0);
	c1_qdr_q                 : in    std_logic_vector((36-1) downto 0);
	c1_qdr_sa                : out   std_logic_vector((19-1) downto 0);
	c1_qdr_w_n               : out   std_logic;
	c1_qdr_r_n               : out   std_logic;
	c1_qdr_dll_off_n         : out   std_logic;
	c1_qdr_bw_n              : out   std_logic_vector((4-1) downto 0);
	c1_qdr_cq                : in    std_logic_vector((1-1) downto 0);
	c1_qdr_cq_n              : in    std_logic_vector((1-1) downto 0);
	c1_qdr_k                 : out   std_logic_vector((1-1) downto 0);
	c1_qdr_k_n               : out   std_logic_vector((1-1) downto 0);
	c1_qdr_c                 : out   std_logic_vector((1-1) downto 0);
	c1_qdr_c_n               : out   std_logic_vector((1-1) downto 0);
--Memory Interface C2
	c2_masterbank_sel_pin    : in    std_logic_vector((1-1) downto 0);
	c2_qdr_d                 : out   std_logic_vector((36-1) downto 0);
	c2_qdr_q                 : in    std_logic_vector((36-1) downto 0);
	c2_qdr_sa                : out   std_logic_vector((19-1) downto 0);
	c2_qdr_w_n               : out   std_logic;
	c2_qdr_r_n               : out   std_logic;
	c2_qdr_dll_off_n         : out   std_logic;
	c2_qdr_bw_n              : out   std_logic_vector((4-1) downto 0);
	c2_qdr_cq                : in    std_logic_vector((1-1) downto 0);
	c2_qdr_cq_n              : in    std_logic_vector((1-1) downto 0);
	c2_qdr_k                 : out   std_logic_vector((1-1) downto 0);
	c2_qdr_k_n               : out   std_logic_vector((1-1) downto 0);
	c2_qdr_c                 : out   std_logic_vector((1-1) downto 0);
	c2_qdr_c_n               : out   std_logic_vector((1-1) downto 0)
  );

attribute SIGIS : string; 
attribute SIGIS of ACLK : signal is "Clk"; 

end flow_capture_qdrii;


architecture flow_capture_qdrii_arch of flow_capture_qdrii is
	constant zeros : std_logic_vector(200-1 downto 0) := (others => '0');
	constant fifty_nine : std_logic_vector(8-1 downto 0) := x"3B";
	
	-- output counters from pkt_classf
	signal output_counters	:  std_logic_vector(96-1 downto 0);
	signal collision_counter :  std_logic_vector(32-1 downto 0);
	signal time_stamp_counter :  std_logic_vector(32-1 downto 0);
	
		
	--Output signals from hash_function
	signal frame_information	:  std_logic_vector(104+8+32+16-1 downto 0);
	signal hash_code_rd : std_logic_vector(18-1 downto 0);
	signal hash_ready_hash : std_logic;
	signal hash_seen_hash : std_logic;
	
-- FIFO 5tuple and hash's signals
	type fifo_inout_type is array (0 to 2) of std_logic_vector(72-1 downto 0);
	signal fifo_out_int : fifo_inout_type;
	signal fifo_in_int : fifo_inout_type;
	signal fifo_out : std_logic_vector(159 downto 0);
	signal fifo_in : std_logic_vector(159 downto 0);
	type fifo_signals is array (0 to 2) of std_logic;
	signal fifo_full_int : fifo_signals;
	signal fifo_full : std_logic;
	signal fifo_empty_int : fifo_signals;
	signal fifo_empty : std_logic;
	signal fifo_rd_en : std_logic;
	signal fifo_rst : std_logic;
	signal fifo_w_en : std_logic;
	type fifo_rd_wr_count_type is array (0 to 2) of std_logic_vector(9-1 downto 0);
	signal RDCOUNT, WRCOUNT : fifo_rd_wr_count_type;

	-- ExpotFIFO's signals
	type fifo_inout_type_exp is array (0 to 3) of std_logic_vector(72-1 downto 0);
	signal fifo_out_exp_int : fifo_inout_type_exp;
	signal fifo_in_exp_int : fifo_inout_type_exp;
	signal fifo_out_exp : std_logic_vector(258-1 downto 0);
	signal fifo_in_exp : std_logic_vector(258-1 downto 0);
	type fifo_signals_exp is array (0 to 3) of std_logic;
	signal fifo_full_exp_int : fifo_signals_exp;
	signal fifo_full_exp : std_logic;
	signal fifo_empty_exp_int : fifo_signals_exp;
	signal fifo_empty_exp : std_logic;
	signal fifo_rd_exp_en : std_logic;
	signal fifo_exp_rst : std_logic;
	signal fifo_w_exp_en : std_logic;
	type fifo_rd_wr_count_type_exp is array (0 to 3) of std_logic_vector(9-1 downto 0);
	signal RDCOUNT_exp, WRCOUNT_exp : fifo_rd_wr_count_type_exp;
	
   -- Mem A's signals
	signal cal_done_qdr_A              :    std_logic;
	signal user_rst_0_tb_qdr_A         :  std_logic;
	signal user_ad_w_n_qdr_A           :   std_logic;
	signal user_d_w_n_qdr_A            :   std_logic;
	signal user_r_n_qdr_A              :   std_logic;
	signal user_wr_full_qdr_A          :    std_logic;
	signal user_rd_full_qdr_A        :    std_logic;
	signal user_qr_valid_qdr_A         :    std_logic;
	signal user_dwl_qdr_A              :   std_logic_vector((36-1) downto 0);
	signal user_dwh_qdr_A              :   std_logic_vector((36-1) downto 0);
	signal user_qrl_qdr_A, qrl0_qdr_A, qrl1_qdr_A, qrh0_qdr_A, qrh1_qdr_A   :    std_logic_vector((36-1) downto 0);
	signal user_qrh_qdr_A             :    std_logic_vector((36-1) downto 0);
	signal user_bwl_n_qdr_A            :   std_logic_vector((4-1) downto 0);
	signal user_bwh_n_qdr_A            :   std_logic_vector((4-1) downto 0);
	signal user_ad_wr_qdr_A            :   std_logic_vector((19-1) downto 0);
	signal user_ad_rd_qdr_A            :   std_logic_vector((19-1) downto 0);	
	
  -- Mem B's signals
	signal cal_done_qdr_B              :    std_logic;
	signal user_rst_0_tb_qdr_B         :  std_logic;
	signal user_ad_w_n_qdr_B           :   std_logic;
	signal user_d_w_n_qdr_B            :   std_logic;
	signal user_r_n_qdr_B              :   std_logic;
	signal user_wr_full_qdr_B          :    std_logic;
	signal user_rd_full_qdr_B        :    std_logic;
	signal user_qr_valid_qdr_B         :    std_logic;
	signal user_dwl_qdr_B              :   std_logic_vector((36-1) downto 0);
	signal user_dwh_qdr_B              :   std_logic_vector((36-1) downto 0);
	signal user_qrl_qdr_B, qrl0_qdr_B, qrl1_qdr_B, qrh0_qdr_B, qrh1_qdr_B   :    std_logic_vector((36-1) downto 0);
	signal user_qrh_qdr_B             :    std_logic_vector((36-1) downto 0);
	signal user_bwl_n_qdr_B            :   std_logic_vector((4-1) downto 0);
	signal user_bwh_n_qdr_B            :   std_logic_vector((4-1) downto 0);
	signal user_ad_wr_qdr_B            :   std_logic_vector((19-1) downto 0);
	signal user_ad_rd_qdr_B            :   std_logic_vector((19-1) downto 0);	
	
  -- Mem C's signals
	signal cal_done_qdr_C              :    std_logic;
	signal user_rst_0_tb_qdr_C         :  std_logic;
	signal user_ad_w_n_qdr_C           :   std_logic;
	signal user_d_w_n_qdr_C            :   std_logic;
	signal user_r_n_qdr_C              :   std_logic;
	signal user_wr_full_qdr_C          :    std_logic;
	signal user_rd_full_qdr_C        :    std_logic;
	signal user_qr_valid_qdr_C         :    std_logic;
	signal user_dwl_qdr_C              :   std_logic_vector((36-1) downto 0);
	signal user_dwh_qdr_C              :   std_logic_vector((36-1) downto 0);
	signal user_qrl_qdr_C, qrl0_qdr_C, qrl1_qdr_C, qrh0_qdr_C, qrh1_qdr_C   :    std_logic_vector((36-1) downto 0);
	signal user_qrh_qdr_C             :    std_logic_vector((36-1) downto 0);
	signal user_bwl_n_qdr_C            :   std_logic_vector((4-1) downto 0);
	signal user_bwh_n_qdr_C            :   std_logic_vector((4-1) downto 0);
	signal user_ad_wr_qdr_C            :   std_logic_vector((19-1) downto 0);
	signal user_ad_rd_qdr_C            :   std_logic_vector((19-1) downto 0);	
	
	--common write signals
	signal mem_addr_w : std_logic_vector(18-1 downto 0);
	signal write_information : std_logic_vector(240-1 downto 0);
	signal write_5tuple_and_flow_data : std_logic;
	signal memory_initialization_ready : std_logic;
	
	--qdr A write signals
	signal memory_initialization_ready_qdr_A : std_logic;
	signal write_mem_busy_qdr_A : std_logic;
	signal write_flow_qdr_A : std_logic;
	signal erase_flow_qdr_A  : std_logic;

	--qdr B write signals
	signal memory_initialization_ready_qdr_B : std_logic;
	signal write_mem_busy_qdr_B : std_logic;
	signal write_flow_qdr_B : std_logic;
	signal erase_flow_qdr_B  : std_logic;
	
	--qdr C write signals
	signal memory_initialization_ready_qdr_C : std_logic;
	signal write_mem_busy_qdr_C : std_logic;
	signal write_flow_qdr_C : std_logic;
	signal erase_flow_qdr_C  : std_logic;
	
--##################################################################################
component pkt_classification 
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
end component pkt_classification;	
--##################################################################################
component hash_function
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
end component hash_function;
--##################################################################################
component write_to_mem
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
end component write_to_mem;
--##################################################################################
component export_flows is
port(
	ACLK  : in  std_logic;	
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
end component export_flows;
--##################################################################################
component create_update_erase_flows is
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
end component create_update_erase_flows;
--##################################################################################
component mig_top
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
	port (
		qdr_d                 : out   std_logic_vector((DATA_WIDTH-1) downto 0);
		qdr_q                 : in    std_logic_vector((DATA_WIDTH-1) downto 0);
		qdr_sa                : out   std_logic_vector((ADDR_WIDTH-1) downto 0);
		qdr_w_n               : out   std_logic;
		qdr_r_n               : out   std_logic;
		qdr_dll_off_n         : out   std_logic;
		qdr_bw_n              : out   std_logic_vector((BW_WIDTH-1) downto 0);
		clk0                      : in    std_logic;
		clk180              : in    std_logic;
		clk270              : in    std_logic;
		locked              : in std_logic;
		idly_clk_200          : in    std_logic;
		masterbank_sel_pin    : in    std_logic_vector((MASTERBANK_PIN_WIDTH-1) downto 0);
		sys_rst_n             : in    std_logic;
		cal_done              : out   std_logic;
		user_rst_0_tb               : out   std_logic;
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
end component;
--##################################################################################

	
begin

	
-- fifo between pkt_classf and hash_fucntion
fifo_empty 	<= fifo_empty_int(2) or fifo_empty_int(1) or fifo_empty_int(0);
fifo_full 	<= fifo_full_int(2) or fifo_full_int(1) or fifo_full_int(0);
fifo_out	<=fifo_out_int(2)(15 downto 0) & fifo_out_int(1) & fifo_out_int(0);
fifo_in_int(0) <= fifo_in(72-1 downto 0);
fifo_in_int(1) <= fifo_in(144-1 downto 72);
fifo_in_int(2) <= zeros(56-1 downto 0) & fifo_in(160-1 downto 144);


-- Export fifo
fifo_empty_exp <= fifo_empty_exp_int(3) or fifo_empty_exp_int(2) or fifo_empty_exp_int(1) or fifo_empty_exp_int(0);
fifo_full_exp 	<= fifo_full_exp_int(3) or fifo_full_exp_int(2) or fifo_full_exp_int(1) or fifo_full_exp_int(0);
fifo_out_exp	<=	fifo_out_exp_int(3)(42-1 downto 0) & fifo_out_exp_int(2) & fifo_out_exp_int(1) & fifo_out_exp_int(0);
fifo_in_exp_int(0) <= fifo_in_exp(72-1 downto 0);
fifo_in_exp_int(1) <= fifo_in_exp(144-1 downto 72);
fifo_in_exp_int(2) <= fifo_in_exp(216-1 downto 144);
fifo_in_exp_int(3) <= zeros(30-1 downto 0) & fifo_in_exp(258-1 downto 216);
	

memory_initialization_ready <= memory_initialization_ready_qdr_A and memory_initialization_ready_qdr_B and memory_initialization_ready_qdr_C;


--COMPONENT INSTANTIATIONS
create_update_erase_flows_inst: create_update_erase_flows
port map(
	ACLK => ACLK,
	ARESETN => ARESETN,
	frame_information => frame_information,
	hash_code_rd => hash_code_rd,
	hash_ready => hash_ready_hash,
	hash_seen => hash_seen_hash,
	memory_initialization_ready => memory_initialization_ready,
	time_stamp_counter => time_stamp_counter,
	collision_counter => collision_counter,
	mem_addr_w => mem_addr_w,
	write_information => write_information,
	write_5tuple_and_flow_data => write_5tuple_and_flow_data,
	erase_flow_qdr_A => erase_flow_qdr_A,
	write_flow_qdr_A => write_flow_qdr_A,
	write_mem_busy_qdr_A => write_mem_busy_qdr_A,
	erase_flow_qdr_B => erase_flow_qdr_B,
	write_flow_qdr_B => write_flow_qdr_B,
	write_mem_busy_qdr_B => write_mem_busy_qdr_B,
	erase_flow_qdr_C => erase_flow_qdr_C,
	write_flow_qdr_C => write_flow_qdr_C,
	write_mem_busy_qdr_C => write_mem_busy_qdr_C,
	user_ad_rd_qdr_A => user_ad_rd_qdr_A,
	user_r_n_qdr_A => user_r_n_qdr_A,
	user_qrh_qdr_A => user_qrh_qdr_A,
	user_qrl_qdr_A => user_qrl_qdr_A,
	user_rd_full_qdr_A => user_rd_full_qdr_A,
	user_qr_valid_qdr_A => user_qr_valid_qdr_A,
	user_ad_rd_qdr_B => user_ad_rd_qdr_B,
	user_r_n_qdr_B => user_r_n_qdr_B,
	user_qrh_qdr_B => user_qrh_qdr_B,
	user_qrl_qdr_B => user_qrl_qdr_B,
	user_rd_full_qdr_B => user_rd_full_qdr_B,
	user_qr_valid_qdr_B => user_qr_valid_qdr_B,
	user_ad_rd_qdr_C => user_ad_rd_qdr_C,
	user_r_n_qdr_C => user_r_n_qdr_C,
	user_qrh_qdr_C => user_qrh_qdr_C,
	user_qrl_qdr_C => user_qrl_qdr_C,
	user_rd_full_qdr_C => user_rd_full_qdr_C,
	user_qr_valid_qdr_C => user_qr_valid_qdr_C,
	fifo_exp_rst => fifo_exp_rst,
	fifo_w_exp_en => fifo_w_exp_en,
	fifo_in_exp => fifo_in_exp,
	fifo_full_exp => fifo_full_exp);
--##################################################################################
pkt_clasff_inst: pkt_classification 
generic map(
	SIM_ONLY => SIM_ONLY)
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	S_AXIS_TREADY => S_AXIS_TREADY,
	S_AXIS_TDATA => S_AXIS_TDATA,
	S_AXIS_TSTRB => S_AXIS_TSTRB,
	S_AXIS_TLAST => S_AXIS_TLAST,
	S_AXIS_TVALID => S_AXIS_TVALID,
	output_counters => output_counters,
	time_stamp_counter_out => time_stamp_counter,
	fifo_in	=> fifo_in,
	fifo_rst	=> fifo_rst,
	fifo_w_en	=> fifo_w_en,
	fifo_full	=> fifo_full);
--##################################################################################
hash_fn_inst: hash_function
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	fifo_empty => fifo_empty,
	fifo_out => fifo_out,
	fifo_rd_en => fifo_rd_en,
	frame_information => frame_information,
	hash_code_rd => hash_code_rd,
	hash_ready => hash_ready_hash,
	hash_seen => hash_seen_hash);
--##################################################################################
write_2_qdr_A:  write_to_mem
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	memory_initialization_ready => memory_initialization_ready_qdr_A,
	write_mem_busy => write_mem_busy_qdr_A,
	write_flow => write_flow_qdr_A,
	write_5tuple_and_flow_data => write_5tuple_and_flow_data,
	write_information => write_information,
	mem_addr_w => mem_addr_w,
	erase_flow => erase_flow_qdr_A,
	user_bwl_n => user_bwl_n_qdr_A,
	user_bwh_n => user_bwh_n_qdr_A,
	user_rst_0_tb => user_rst_0_tb_qdr_A,
	cal_done => cal_done_qdr_A,
	user_ad_w_n => user_ad_w_n_qdr_A,
	user_d_w_n => user_d_w_n_qdr_A,
	user_dwl => user_dwl_qdr_A,
	user_dwh => user_dwh_qdr_A,
	user_ad_wr => user_ad_wr_qdr_A,
	user_wr_full => user_wr_full_qdr_A);
--##################################################################################
write_2_qdr_B:  write_to_mem
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	memory_initialization_ready => memory_initialization_ready_qdr_B,
	write_mem_busy => write_mem_busy_qdr_B,
	write_flow => write_flow_qdr_B,
	write_5tuple_and_flow_data => write_5tuple_and_flow_data,
	write_information => write_information,
	mem_addr_w => mem_addr_w,
	erase_flow => erase_flow_qdr_B,
	user_bwl_n => user_bwl_n_qdr_B,
	user_bwh_n => user_bwh_n_qdr_B,
	user_rst_0_tb => user_rst_0_tb_qdr_B,
	cal_done => cal_done_qdr_B,
	user_ad_w_n => user_ad_w_n_qdr_B,
	user_d_w_n => user_d_w_n_qdr_B,
	user_dwl => user_dwl_qdr_B,
	user_dwh => user_dwh_qdr_B,
	user_ad_wr => user_ad_wr_qdr_B,
	user_wr_full => user_wr_full_qdr_B);
--##################################################################################
write_2_qdr_C:  write_to_mem
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	memory_initialization_ready => memory_initialization_ready_qdr_C,
	write_mem_busy => write_mem_busy_qdr_C,
	write_flow => write_flow_qdr_C,
	write_5tuple_and_flow_data => write_5tuple_and_flow_data,
	write_information => write_information,
	mem_addr_w => mem_addr_w,
	erase_flow => erase_flow_qdr_C,
	user_bwl_n => user_bwl_n_qdr_C,
	user_bwh_n => user_bwh_n_qdr_C,
	user_rst_0_tb => user_rst_0_tb_qdr_C,
	cal_done => cal_done_qdr_C,
	user_ad_w_n => user_ad_w_n_qdr_C,
	user_d_w_n => user_d_w_n_qdr_C,
	user_dwl => user_dwl_qdr_C,
	user_dwh => user_dwh_qdr_C,
	user_ad_wr => user_ad_wr_qdr_C,
	user_wr_full => user_wr_full_qdr_C);
--##################################################################################
export_flows_inst: export_flows
port map(
	ACLK  => ACLK,
	ARESETN => ARESETN,
	M_AXIS_10GMAC_tdata => M_AXIS_10GMAC_tdata,
	M_AXIS_10GMAC_tstrb => M_AXIS_10GMAC_tstrb,
	M_AXIS_10GMAC_tvalid => M_AXIS_10GMAC_tvalid,
	M_AXIS_10GMAC_tready => M_AXIS_10GMAC_tready,
	M_AXIS_10GMAC_tlast => M_AXIS_10GMAC_tlast,
	counters => output_counters,
	collision_counter => collision_counter,
	fifo_rd_exp_en => fifo_rd_exp_en,
	fifo_out_exp => fifo_out_exp,
	fifo_empty_exp => fifo_empty_exp);
--##################################################################################
 qdr_A : mig_top
    generic map (
     ADDR_WIDTH => 19,
     BURST_LENGTH => 4,
     BW_WIDTH => 4,
     DLL_FREQ_MODE => "HIGH",
     CLK_PERIOD => 5000,
     CLK_TYPE => "SINGLE_ENDED",
     CLK_WIDTH => 1,
     CQ_WIDTH => 1,
     DATA_WIDTH => 36,
     DEBUG_EN => 0,
     HIGH_PERFORMANCE_MODE => TRUE,
     MASTERBANK_PIN_WIDTH => 1,
     MEMORY_WIDTH => 36,
     NOCLK200 => FALSE,
     RST_ACT_LOW => 1,
     SIM_ONLY => 0
)
    port map (
		qdr_d                      => c0_qdr_d,
		qdr_q                      => c0_qdr_q,
		qdr_sa                     => c0_qdr_sa,
		qdr_w_n                    => c0_qdr_w_n,
		qdr_r_n                    => c0_qdr_r_n,
		qdr_dll_off_n              => c0_qdr_dll_off_n,
		qdr_bw_n                   => c0_qdr_bw_n,
		clk0 								=> ACLK,
		clk180 						=> clk180,
		clk270							 => clk270,
		locked 							=> dcm_locked,
		idly_clk_200               => ACLK,
		masterbank_sel_pin         => c0_masterbank_sel_pin,
		sys_rst_n                  => ARESETN,
		cal_done                   => cal_done_qdr_A,
		user_rst_0_tb              => user_rst_0_tb_qdr_A,
		user_ad_w_n                => user_ad_w_n_qdr_A,
		user_d_w_n                 => user_d_w_n_qdr_A,
		user_r_n                   => user_r_n_qdr_A,
		user_wr_full               => user_wr_full_qdr_A,
		user_rd_full               => user_rd_full_qdr_A,
		user_qr_valid              => user_qr_valid_qdr_A,
		user_dwl                   => user_dwl_qdr_A,
		user_dwh                   => user_dwh_qdr_A,
		user_qrl                   => user_qrl_qdr_A,
		user_qrh                   => user_qrh_qdr_A,
		user_bwl_n                 => user_bwl_n_qdr_A,
		user_bwh_n                 => user_bwh_n_qdr_A,
		user_ad_wr                 => user_ad_wr_qdr_A,
		user_ad_rd                 => user_ad_rd_qdr_A,
		qdr_cq                     => c0_qdr_cq,
		qdr_cq_n                   => c0_qdr_cq_n,
		qdr_k                      => c0_qdr_k,
		qdr_k_n                    => c0_qdr_k_n,
		qdr_c                      => c0_qdr_c,
		qdr_c_n                    => c0_qdr_c_n
);
 qdr_B : mig_top
    generic map (
     ADDR_WIDTH => 19,
     BURST_LENGTH => 4,
     BW_WIDTH => 4,
     DLL_FREQ_MODE => "HIGH",
     CLK_PERIOD => 5000,
     CLK_TYPE => "SINGLE_ENDED",
     CLK_WIDTH => 1,
     CQ_WIDTH => 1,
     DATA_WIDTH => 36,
     DEBUG_EN => 0,
     HIGH_PERFORMANCE_MODE => TRUE,
     MASTERBANK_PIN_WIDTH => 1,
     MEMORY_WIDTH => 36,
     NOCLK200 => FALSE,
     RST_ACT_LOW => 1,
     SIM_ONLY => 0
)
    port map (
		qdr_d                      => c1_qdr_d,
		qdr_q                      => c1_qdr_q,
		qdr_sa                     => c1_qdr_sa,
		qdr_w_n                    => c1_qdr_w_n,
		qdr_r_n                    => c1_qdr_r_n,
		qdr_dll_off_n              => c1_qdr_dll_off_n,
		qdr_bw_n                   => c1_qdr_bw_n,
		clk0 								=> ACLK,
		clk180 						=> clk180,
		clk270							 => clk270,
		locked 							=> dcm_locked,
		idly_clk_200               => ACLK,
		masterbank_sel_pin         => c1_masterbank_sel_pin,
		sys_rst_n                  => ARESETN,
		cal_done                   => cal_done_qdr_B,
		user_rst_0_tb              => user_rst_0_tb_qdr_B,
		user_ad_w_n                => user_ad_w_n_qdr_B,
		user_d_w_n                 => user_d_w_n_qdr_B,
		user_r_n                   => user_r_n_qdr_B,
		user_wr_full               => user_wr_full_qdr_B,
		user_rd_full               => user_rd_full_qdr_B,
		user_qr_valid              => user_qr_valid_qdr_B,
		user_dwl                   => user_dwl_qdr_B,
		user_dwh                   => user_dwh_qdr_B,
		user_qrl                   => user_qrl_qdr_B,
		user_qrh                   => user_qrh_qdr_B,
		user_bwl_n                 => user_bwl_n_qdr_B,
		user_bwh_n                 => user_bwh_n_qdr_B,
		user_ad_wr                 => user_ad_wr_qdr_B,
		user_ad_rd                 => user_ad_rd_qdr_B,
		qdr_cq                     => c1_qdr_cq,
		qdr_cq_n                   => c1_qdr_cq_n,
		qdr_k                      => c1_qdr_k,
		qdr_k_n                    => c1_qdr_k_n,
		qdr_c                      => c1_qdr_c,
		qdr_c_n                    => c1_qdr_c_n
);
--##################################################################################
 qdr_C : mig_top
    generic map (
     ADDR_WIDTH => 19,
     BURST_LENGTH => 4,
     BW_WIDTH => 4,
     DLL_FREQ_MODE => "HIGH",
     CLK_PERIOD => 5000,
     CLK_TYPE => "SINGLE_ENDED",
     CLK_WIDTH => 1,
     CQ_WIDTH => 1,
     DATA_WIDTH => 36,
     DEBUG_EN => 0,
     HIGH_PERFORMANCE_MODE => TRUE,
     MASTERBANK_PIN_WIDTH => 1,
     MEMORY_WIDTH => 36,
     NOCLK200 => FALSE,
     RST_ACT_LOW => 1,
     SIM_ONLY => 0
)
    port map (
		qdr_d                      => c2_qdr_d,
		qdr_q                      => c2_qdr_q,
		qdr_sa                     => c2_qdr_sa,
		qdr_w_n                    => c2_qdr_w_n,
		qdr_r_n                    => c2_qdr_r_n,
		qdr_dll_off_n              => c2_qdr_dll_off_n,
		qdr_bw_n                   => c2_qdr_bw_n,
		clk0 								=> ACLK,
		clk180 						=> clk180,
		clk270							 => clk270,
		locked 							=> dcm_locked,
		idly_clk_200               => ACLK,
		masterbank_sel_pin         => c2_masterbank_sel_pin,
		sys_rst_n                  => ARESETN,
		cal_done                   => cal_done_qdr_C,
		user_rst_0_tb              => user_rst_0_tb_qdr_C,
		user_ad_w_n                => user_ad_w_n_qdr_C,
		user_d_w_n                 => user_d_w_n_qdr_C,
		user_r_n                   => user_r_n_qdr_C,
		user_wr_full               => user_wr_full_qdr_C,
		user_rd_full               => user_rd_full_qdr_C,
		user_qr_valid              => user_qr_valid_qdr_C,
		user_dwl                   => user_dwl_qdr_C,
		user_dwh                   => user_dwh_qdr_C,
		user_qrl                   => user_qrl_qdr_C,
		user_qrh                   => user_qrh_qdr_C,
		user_bwl_n                 => user_bwl_n_qdr_C,
		user_bwh_n                 => user_bwh_n_qdr_C,
		user_ad_wr                 => user_ad_wr_qdr_C,
		user_ad_rd                 => user_ad_rd_qdr_C,
		qdr_cq                     => c2_qdr_cq,
		qdr_cq_n                   => c2_qdr_cq_n,
		qdr_k                      => c2_qdr_k,
		qdr_k_n                    => c2_qdr_k_n,
		qdr_c                      => c2_qdr_c,
		qdr_c_n                    => c2_qdr_c_n
);
--##################################################################################
ext_5tuple_and_hash_fifo: for L in 0 to 2 generate
   FIFO_SYNC_MACRO_inst : FIFO_SYNC_MACRO
   generic map (
      DEVICE => "VIRTEX5",            -- Target Device: "VIRTEX5, "VIRTEX6" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => 72,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      SIM_MODE => "SAFE") -- Simulation) "SAFE" vs "FAST", 
                          -- see "Synthesis and Simulation Design Guide" for details
   port map (
      ALMOSTEMPTY => open,   -- Output almost empty 
      ALMOSTFULL => fifo_full_int(L),     -- Output almost full
      DO => fifo_out_int(L),                     -- Output data
      EMPTY => fifo_empty_int(L),               -- Output empty
      FULL => open,                 -- Output full
      RDCOUNT => RDCOUNT(L),           -- Output read count
      RDERR => open,               -- Output read error
      WRCOUNT => WRCOUNT(L),           -- Output write count
      WRERR => open,               -- Output write error
      CLK => ACLK,                   -- Input clock
      DI => fifo_in_int(L),                     -- Input data
      RDEN => fifo_rd_en,                 -- Input read enable
      RST => fifo_rst,                   -- Input reset
      WREN => fifo_w_en                  -- Input write enable
   );
end generate ext_5tuple_and_hash_fifo;
--##################################################################################
export_fifo: for L in 0 to 3 generate
   FIFO_SYNC_MACRO_exp0 : FIFO_SYNC_MACRO
   generic map (
      DEVICE => "VIRTEX5",            -- Target Device: "VIRTEX5, "VIRTEX6" 
      ALMOST_FULL_OFFSET => X"0080",  -- Sets almost full threshold
      ALMOST_EMPTY_OFFSET => X"0080", -- Sets the almost empty threshold
      DATA_WIDTH => 72,   -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
      FIFO_SIZE => "36Kb",            -- Target BRAM, "18Kb" or "36Kb" 
      SIM_MODE => "SAFE") -- Simulation) "SAFE" vs "FAST", 
                          -- see "Synthesis and Simulation Design Guide" for details
   port map (
      ALMOSTEMPTY => open,   -- Output almost empty 
      ALMOSTFULL => fifo_full_exp_int(L),     -- Output almost full
      DO => fifo_out_exp_int(L),                     -- Output data
      EMPTY => fifo_empty_exp_int(L),               -- Output empty
      FULL => open,                 -- Output full
      RDCOUNT => RDCOUNT_exp(L),           -- Output read count
      RDERR => open,               -- Output read error
      WRCOUNT => WRCOUNT_exp(L),           -- Output write count
      WRERR => open,               -- Output write error
      CLK => ACLK,                   -- Input clock
      DI => fifo_in_exp_int(L),                     -- Input data
      RDEN => fifo_rd_exp_en,                 -- Input read enable
      RST => fifo_exp_rst,                   -- Input reset
      WREN => fifo_w_exp_en                 -- Input write enable
   );
end generate export_fifo;


end architecture flow_capture_qdrii_arch;
