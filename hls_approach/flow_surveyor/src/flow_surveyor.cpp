// ------------------------------------------------------------------------------
// MASTER I2-TIC - 2013
// ------------------------------------------------------------------------------

#include "flow_surveyor.h"
#include <stdint.h>

using namespace std;

uint32_t _pross_pkts = 0;
uint32_t _collision_counter = 0;
bool _init_hw = true;
flow_info_t flow_table[1024];
ap_uint<10> _linear_address_counter = 0;


void flow_surveyor (mac_user_interface_type pkt_input[240], flow_out_interface_type flow_output[240], uint32_t *pross_pkts, uint32_t *coll_cntr, uint32_t *time_ms) {
#pragma HLS DEPENDENCE intra false
#pragma HLS DEPENDENCE inter false
#pragma HLS RESOURCE variable=flow_table core=RAM_T2P_BRAM


//Register interfaces to be connected to the core that talks to ublaze
#pragma HLS INTERFACE register port=coll_cntr
#pragma HLS INTERFACE register port=pross_pkts
#pragma HLS INTERFACE ap_none port=time_ms

//Tell the compiler this interfaces talk to FIFOs
#pragma HLS INTERFACE ap_fifo port=pkt_input
#pragma HLS INTERFACE ap_fifo port=flow_output

//Map HLS ports to AXI interfaces. Tell the compiler this interfaces are AXI4-Stream
#pragma HLS RESOURCE variable=pkt_input	core=AXIS metadata="-bus_bundle MAC_INPUT"
#pragma HLS RESOURCE variable=flow_output	core=AXIS metadata="-bus_bundle FLOW_OUTPUT"

	if (_init_hw) {
		for (int i=0;i<1024;i++)
			flow_table[i].location_busy = 0;
		_init_hw = false;
	}

	flow_info_t flow_from_pross_A, flow_from_pross_B;

	flow_expiration_checker(flow_table, &flow_from_pross_B, time_ms);
	flow_creation_and_updates(flow_table, pkt_input, &flow_from_pross_A, pross_pkts, coll_cntr, time_ms);

	export_engine(&flow_from_pross_A, &flow_from_pross_B, flow_output);

} //

void export_flow(flow_out_interface_type flow_output[240], flow_info_t *flow2store) {
	flow_out_interface_type output_data;
	for (int i=0;i<4;i++) {
		output_data.strb = 0xff;
		output_data.last = 0;
		if (i == 0)
			output_data.data = (((uint64_t)flow2store->byte_coutner) << 32) | flow2store->pkt_coutner;
		if (i == 1)
			output_data.data = (((uint64_t)flow2store->last_timestamp) << 32) | flow2store->initial_timestamp;
		if (i == 2)
			output_data.data = (((uint64_t)flow2store->xtuple.src_ip) << 32) | flow2store->xtuple.des_ip;
		if (i == 3) {
			output_data.data = (((uint64_t)flow2store->tcp_flags) << 40) | (((uint64_t)flow2store->xtuple.layer3protocol) << 32) | (((uint64_t)flow2store->xtuple.src_port) << 16) | flow2store->xtuple.des_port;
			output_data.strb = 0x7f;
			output_data.last = 1;
		}
		*flow_output = output_data;
		flow_output++;
	}
}


bool pkt_parser(mac_user_interface_type pkt_input[240], pkt_info_t *pkt_info, uint32_t *time_ms) {
#pragma HLS INLINE off
	mac_user_interface_type axi_transaction_rd;
	uint32_t transaction_coutner = 0;
	uint8_t temp_protocol;
	bool discard_pkt = false;
	bool capturing_done = false;
	ap_uint<64> data_read;

	pkt_parser_label0:do {
#pragma HLS LOOP_TRIPCOUNT min=10 max=100 avg=50

		axi_transaction_rd = *pkt_input;
		data_read = axi_transaction_rd.data;
		uint8_t *byte_pointer = (uint8_t *)&(data_read);

		if (transaction_coutner == 0) {
			pkt_info->timestamp = *time_ms;
		}

		if (transaction_coutner == 1) {
			byte_pointer = byte_pointer +0x04;
			if (*byte_pointer != 0x08)
				discard_pkt = true;
			byte_pointer = byte_pointer +0x01;
			if (*byte_pointer != 0x00)
				discard_pkt = true;
			byte_pointer = byte_pointer +0x01;
			if ((*byte_pointer & 0xf0) != 0x40)
				discard_pkt = true;
		}	//if not IPv4, get the hell out of here

		if (transaction_coutner == 2) {
			pkt_info->byte_coutner = 0;
			uint8_t *aux_pointer = ((uint8_t *)&(pkt_info->byte_coutner)) +0x01;
			for (int i=0;i<2;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			byte_pointer = byte_pointer +0x05;
			pkt_info->xtuple.layer3protocol = *byte_pointer;
			temp_protocol = *byte_pointer;
			if ( (temp_protocol != TCP) && (temp_protocol != UDP) )
				discard_pkt = true;
		}

		if (transaction_coutner == 3) {
			uint32_t temp_ip_addr;
			byte_pointer = byte_pointer +0x02;
			uint8_t *aux_pointer = ((uint8_t *)&(temp_ip_addr)) +0x03;
			for (int i=0;i<4;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			pkt_info->xtuple.src_ip = temp_ip_addr;
			aux_pointer = ((uint8_t *)&temp_ip_addr) +0x03;
			for (int i=0;i<2;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			pkt_info->xtuple.des_ip = temp_ip_addr & 0xffff0000;
		}

		if (transaction_coutner == 4) {
			uint32_t temp_ip_addr;
			uint16_t temp_ip_port;
			uint8_t *aux_pointer = ((uint8_t *)&temp_ip_addr) +0x01;
			for (int i=0;i<2;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			pkt_info->xtuple.des_ip = pkt_info->xtuple.des_ip | (temp_ip_addr & 0xffff);
			aux_pointer = ((uint8_t *)&temp_ip_port) +0x01;
			for (int i=0;i<2;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			pkt_info->xtuple.src_port = temp_ip_port;
			aux_pointer = ((uint8_t *)&temp_ip_port) +0x01;
			for (int i=0;i<2;i++) {
				*aux_pointer = *byte_pointer;
				aux_pointer--;
				byte_pointer++;
			}
			pkt_info->xtuple.des_port = temp_ip_port;
		}

		if (transaction_coutner == 5) {
			byte_pointer = byte_pointer +0x07;
			if (temp_protocol == TCP)
				pkt_info->tcp_flags = *byte_pointer;
			else
				pkt_info->tcp_flags = 0;
			capturing_done = true;
		}

		transaction_coutner++;
		pkt_input++;
	} while((!axi_transaction_rd.last) && (!discard_pkt) && (!capturing_done));

	if (!axi_transaction_rd.last) {
		pkt_parser_label1: do {
#pragma HLS LOOP_TRIPCOUNT min=10 max=100 avg=50
			axi_transaction_rd = *pkt_input;
			pkt_input++;
		} while(!axi_transaction_rd.last);
	}

	return capturing_done;
}


ap_uint<10> hash_function(pkt_info_t *pkt_info){
//	uint8_t *byte_pointer;
//	ap_uint<10> hash_code = 0;
//	byte_pointer = (uint8_t *)&(pkt_info->xtuple);
//	for (int i=0;i<13;i++) {
//		if (i%2){
//			hash_code = hash_code ^ (*byte_pointer);
//		} else {
//			hash_code = (hash_code ^ (*byte_pointer)) << 2;
//		}
//	}
//	return hash_code;
	return (3);
}

bool match_xtuples(pkt_info_t *pkt_info, flow_info_t *stored_flow) {
	bool match = true;
	if (pkt_info->xtuple.src_ip != stored_flow->xtuple.src_ip)
		match = false;
	if (pkt_info->xtuple.des_ip != stored_flow->xtuple.des_ip)
		match = false;
	if (pkt_info->xtuple.src_port != stored_flow->xtuple.src_port)
		match = false;
	if (pkt_info->xtuple.des_port != stored_flow->xtuple.des_port)
		match = false;
	if (pkt_info->xtuple.layer3protocol != stored_flow->xtuple.layer3protocol)
		match = false;
	return match;
}

void flow_creation_and_updates(flow_info_t flow_table[1024], mac_user_interface_type pkt_input[240], flow_info_t *flow_from_pross_A, uint32_t *pross_pkts, uint32_t *coll_cntr, uint32_t *time_ms) {
#pragma HLS DEPENDENCE inter false
#pragma HLS DEPENDENCE intra false

	pkt_info_t pkt_info;
	bool capturing_done;
	bool export_flow_flag = false;

	capturing_done = pkt_parser(pkt_input,&pkt_info,time_ms);
	_pross_pkts++;

	update_statistics: {
		*pross_pkts = _pross_pkts;
		*coll_cntr = _collision_counter;
	}

	if (capturing_done){
		ap_uint<10> hash_code;
		hash_code = hash_function(&pkt_info);

		tcp_fin_check: {
			if ( (pkt_info.tcp_flags & 0x01)  || (pkt_info.tcp_flags & 0x04) )
				export_flow_flag = true;
		}

		flow_info_t stored_flow;
		stored_flow = flow_table[hash_code];	//Read from memory

		flow_from_pross_A->xtuple = pkt_info.xtuple;
		flow_from_pross_A->last_timestamp = pkt_info.timestamp;
		flow_from_pross_A->location_busy = 1;

		if (stored_flow.location_busy) {	//location busy
			if (match_xtuples(&pkt_info, &stored_flow)) { //the flow has been previously created
				flow_from_pross_A->initial_timestamp = stored_flow.initial_timestamp;
				flow_from_pross_A->byte_coutner = stored_flow.byte_coutner + pkt_info.byte_coutner;
				flow_from_pross_A->pkt_coutner = stored_flow.pkt_coutner + 1;
				flow_from_pross_A->tcp_flags = stored_flow.tcp_flags | pkt_info.tcp_flags;
				if (!export_flow_flag)	//update flow record
					flow_table[hash_code] = *flow_from_pross_A;
				else
					flow_table[hash_code].location_busy = 0;
			} else {	//we've a collision
				_collision_counter++;
				export_flow_flag = false;
			}
		} else {	//location available
			flow_from_pross_A->initial_timestamp = pkt_info.timestamp;
			flow_from_pross_A->byte_coutner = pkt_info.byte_coutner;
			flow_from_pross_A->pkt_coutner = 1;
			flow_from_pross_A->tcp_flags = pkt_info.tcp_flags;
			if (!export_flow_flag)	//record a new flow
				flow_table[hash_code] = *flow_from_pross_A;
		}
	}

	if (!export_flow_flag) {
		flow_from_pross_A->location_busy = 0;	//this will mean to the export_engine module that the flow analyzed does not has to be exported
	}
}

void flow_expiration_checker(flow_info_t flow_table[1024], flow_info_t *flow_from_pross_B,  uint32_t *time_ms) {
#pragma HLS DEPENDENCE inter false
#pragma HLS DEPENDENCE intra false
#pragma HLS INLINE off

	bool export_flow_flag = false;

	*flow_from_pross_B = flow_table[_linear_address_counter];

	if (flow_from_pross_B->location_busy) {	//location busy
		if (*time_ms - flow_from_pross_B->last_timestamp >= InActive_timeout)
			export_flow_flag = true;
		else if (*time_ms - flow_from_pross_B->initial_timestamp >= Active_timeout)
			export_flow_flag = true;

		if (export_flow_flag)
			flow_table[_linear_address_counter].location_busy = 0;
	} //else no flow stored here
	_linear_address_counter++;

	if (!export_flow_flag) {
		flow_from_pross_B->location_busy = 0;	//this will mean to the export_engine module that the flow analyzed does not has to be exported
	}
}

void export_engine(flow_info_t *flow_from_pross_A, flow_info_t *flow_from_pross_B, flow_out_interface_type flow_output[240]) {
#pragma HLS DEPENDENCE intra false
	//the location_busy flag in this context means: "export this flow"
	if (flow_from_pross_A->location_busy)
		export_flow(flow_output,flow_from_pross_A);

	if (flow_from_pross_B->location_busy)
		export_flow(flow_output,flow_from_pross_B);
}
