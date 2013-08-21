// ------------------------------------------------------------------------------
// MASTER I2-TIC - 2013
// ------------------------------------------------------------------------------
#ifndef _TOP_HEADER_H_
#define _TOP_HEADER_H_

using namespace std;

#include "ap_int.h"
#include <stdint.h>
//#include "ap_axi_sdata.h"

#define MAC_INTERFACE_WIDTH 8
#define InActive_timeout 15000
#define Active_timeout 240000
#define TCP 0x06
#define UDP 0x11

template<int D>
  struct my_axis{
    ap_uint<D>   data;
    ap_uint<D/8> strb;
    ap_uint<1>   last;
  };

typedef my_axis<MAC_INTERFACE_WIDTH*8> mac_user_interface_type;
typedef my_axis<64> flow_out_interface_type;

typedef struct xtuple_t {
	ap_uint<32> src_ip;
	ap_uint<32> des_ip;
	ap_uint<16> src_port;
	ap_uint<16> des_port;
	ap_uint<8> layer3protocol;
}xtuple_t;

typedef struct flow_info_t {
	xtuple_t xtuple;
	ap_uint<32> last_timestamp;
	ap_uint<32> initial_timestamp;
	ap_uint<8> tcp_flags;
	ap_uint<32> byte_coutner;
	ap_uint<32> pkt_coutner;
	ap_uint<1> location_busy;
}flow_info_t;

typedef struct pkt_info_t {
	xtuple_t xtuple;
	ap_uint<32> timestamp;
	ap_uint<8> tcp_flags;
	ap_uint<32> byte_coutner;
}pkt_info_t;

bool pkt_parser(mac_user_interface_type pkt_input[240], pkt_info_t *pkt_info, uint32_t *time_ms);
ap_uint<10> hash_function(pkt_info_t *pkt_info);
void export_flow(flow_out_interface_type flow_output[240], flow_info_t *flow2store);
bool match_xtuples(pkt_info_t *pkt_info, flow_info_t *stored_flow);
void flow_creation_and_updates(flow_info_t flow_table[1024], mac_user_interface_type pkt_input[240], flow_info_t *flow_from_pross_A, uint32_t *pross_pkts, uint32_t *coll_cntr, uint32_t *time_ms);
void flow_expiration_checker(flow_info_t flow_table[1024], flow_info_t *flow_from_pross_B,  uint32_t *time_ms);
void export_engine(flow_info_t *flow_from_pross_A, flow_info_t *flow_from_pross_B, flow_out_interface_type flow_output[240]);
void flow_surveyor (mac_user_interface_type pkt_input[240], flow_out_interface_type flow_output[240], uint32_t *pross_pkts, uint32_t *coll_cntr, uint32_t *time_ms);
#endif
