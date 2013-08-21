//*****************************************************************************
//
//*****************************************************************************
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include "time_gen.h"

using namespace std;

int main(void) {

	cout << "Test started..." << endl;

	uint32_t time_ms = 0;
	for (int i=0;i<50;i++) {

		time_gen(&time_ms);
		cout << "time is: " << time_ms << endl;
	}

	cout << "Test finishes" << endl;

	return 0;
}
