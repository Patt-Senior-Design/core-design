#include "mmio_plugin.h"
#include <iostream>

using namespace std;

class UART {
  public:
    UART(const string& args) {}

    bool load(reg_t addr, size_t len, uint8_t* bytes) {
        if (len > 4) { return false; }

        uint32_t value;
        switch (addr) {
        case 0: // Status flags
            value = getStatus();
            break;
        case 4: // Receive fifo
            // Return zeroes for now
            value = 0;
            break;
        default:
            return false;
        }

        while (len > 0) {
            *bytes = value;
            bytes++;
            value >>= 8;
            len--;
        }

        return true;
    }

    bool store(reg_t addr, size_t len, const uint8_t* bytes) {
        switch (addr) {
        case 8: // Transmit fifo
            cout.put(*bytes);
            break;
        default:
            return false;
        }

        return true;
    }

  private:
    uint8_t getStatus() {
        // Prevent reads
        bool rxempty = true;
        bool rxfull = false;
        // Allow writes
        bool txempty = true;
        bool txfull = false;

        return (rxempty ? 1 : 0) | (rxfull ? 2 : 0) |
            (txempty ? 4 : 0) | (txfull ? 8 : 0);
    }
};

static mmio_plugin_registration_t<UART> uart_plugin("uart");
