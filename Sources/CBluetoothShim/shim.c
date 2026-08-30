#include "include/CBluetoothShim.h"

extern int IOBluetoothPreferenceGetControllerPowerState(void);
extern void IOBluetoothPreferenceSetControllerPowerState(int state);

int lgBluetoothPowerState(void) {
    return IOBluetoothPreferenceGetControllerPowerState();
}

void lgSetBluetoothPowerState(int on) {
    IOBluetoothPreferenceSetControllerPowerState(on);
}
