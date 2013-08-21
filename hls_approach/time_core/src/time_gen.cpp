// ------------------------------------------------------------------------------
// MASTER I2-TIC - 2013
// ------------------------------------------------------------------------------

#include "time_gen.h"
#include <stdint.h>

using namespace std;

uint32_t _time_ns = 0;
uint32_t _time_ms = 0;

void time_gen (uint32_t *time_ms) {

//Register interfaces to be connected to the core that talks to ublaze
#pragma HLS INTERFACE register port=time_ms
//#pragma HLS INTERFACE register port=pross_pkts
//#pragma HLS INTERFACE ap_none port=time_ms

	*time_ms = _time_ms;
	_time_ns = _time_ns +5;
	if (_time_ns == 1000000) {
		_time_ns = 0;
		_time_ms++;
	}
} //
