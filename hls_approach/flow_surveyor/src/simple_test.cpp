//*****************************************************************************
//
//*****************************************************************************
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include "flow_surveyor.h"

using namespace std;

#define Lenght_PRU 4500


int main(void) {

	int i, j, error_cnt = 0;

	mac_user_interface_type *A, *C;
	flow_out_interface_type *B;
	A = (mac_user_interface_type*) malloc (Lenght_PRU*sizeof(mac_user_interface_type));
	B = (flow_out_interface_type*) malloc (Lenght_PRU*sizeof(flow_out_interface_type));
	C = (mac_user_interface_type*) malloc (Lenght_PRU*sizeof(mac_user_interface_type));

	FILE *pFile;
	//pFile = fopen ("2flujos", "r");
	//pFile = fopen ("50_pkts", "r");
	pFile = fopen ("input_file", "r");

	char num_str[17];

	cout << "Test started..." << endl;

	if (!pFile) {
		printf("oops, file can't be read\n");
		exit(-1);
	}

	for(j=0;j<Lenght_PRU;j++){	//Init to zeros
		A[j].data = 0;
		B[j].data = 0;
		C[j].data = 0;
		A[j].strb = 0;
		B[j].strb = 0;
		C[j].strb = 0;
		A[j].last = 0;
		B[j].last = 0;
		C[j].last = 0;
	}

	j=0;
	uint32_t time_ms = 15;
	while (fscanf(pFile, "%s", num_str) == 1) {
		A[j].data = strtoul(num_str,NULL,16);
		//cout << hex << strtoul(num_str,NULL,16) << endl;
		fscanf(pFile, "%s", num_str);
		A[j].strb = strtoul(num_str,NULL,16);
		//cout << hex << strtoul(num_str,NULL,16) << endl;
		fscanf(pFile, "%s", num_str);
		uint8_t aux_last;
		aux_last = 0x01 & strtoul(num_str,NULL,16);
		A[j].last = aux_last;
		//cout << hex << (0x01 & strtoul(num_str,NULL,16)) << endl;
		j++;

		if (aux_last) {
			cout << "Packets sent to input AXI" << endl;

			uint32_t pross_pkts;
			uint32_t coll_cntr;
			time_ms += 10;
			flow_surveyor (A, B, &pross_pkts, &coll_cntr, &time_ms);

			i=0;
			if (B[i].data) {
				cout << "pkt from B int: " << endl;
				do {
					cout << hex << i*8 << "\t";
					cout << hex << setfill('0') << setw(16) << B[i].data;
					cout << "\tstr:" << B[i].strb << "\tlast:" << B[i].last << endl;
				} while(!B[i++].last);
			} else if (C[i].data) {
				cout << "pkt from C int: " << endl;
				do {
					cout << hex << i*8 << "\t";
					cout << hex << C[i].data << "\tstr:" << C[i].strb << "\tlast:" << C[i].last << endl;
				} while(!C[i++].last);
			}

			cout << dec << "proccesed_pkts: " << pross_pkts << "\tcoll_cntr: " << coll_cntr << endl;

			for(j=0;j<Lenght_PRU;j++){
				A[j].data = 0;
				B[j].data = 0;
				C[j].data = 0;
				A[j].strb = 0;
				B[j].strb = 0;
				C[j].strb = 0;
				A[j].last = 0;
				B[j].last = 0;
				C[j].last = 0;
			}
			j=0;
		}

	}

	fclose(pFile);  /* close the file prior to exiting the routine */

	cout << "Test finishes" << endl;

	return error_cnt;
}
