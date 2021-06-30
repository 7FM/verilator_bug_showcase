#include <bitset>
#include <csignal>
#include <cstdint>
#include <getopt.h>
#include <iostream>
#include <verilated.h> // Defines common routines
#include <verilated_vcd_c.h>

#define TOP_MODULE Vtop

#include "Vtop.h"       // basic Top header
#include "Vtop__Syms.h" // all headers to access exposed internal signals

#ifndef PHASE_LENGTH
#define PHASE_LENGTH 5
#endif

static TOP_MODULE *ptop = nullptr; // Instantiation of module
static VerilatedVcdC *tfp = nullptr;

static vluint64_t main_time = 0; // Current simulation time

static volatile bool runSim = true;

static void signal_handler(int signum) {
    if (signum == SIGINT) {
        std::cout << "Trying to exit..." << std::endl;
        runSim = false;
    }
}

static bool stopCondition();
static void sanityChecks();
static void onRisingEdge();
static void onFallingEdge();

/**
* Called by $time in Verilog
****************************************************************************/
double sc_time_stamp() {
    return main_time; // converts to double, to match what SystemC does
}

/******************************************************************************/
static void tick(int count, bool dump) {
    do {
        //if (tfp)
        //tfp->dump(main_time); // dump traces (inputs stable before outputs change)
        ptop->eval(); // Evaluate model
        main_time++;  // Time passes...
        if (tfp && dump)
            tfp->dump(main_time); // inputs and outputs all updated at same time
    } while (--count);
}

/******************************************************************************/

static void run(uint64_t limit, bool dump, bool checkStopCondition = true) {
    bool stop;
    do {
        stop = checkStopCondition && stopCondition();
        ptop->clk = 1;
        onRisingEdge();
        tick(PHASE_LENGTH, dump);

        ptop->clk = 0;
        onFallingEdge();
        tick(PHASE_LENGTH, dump);
        sanityChecks();
    } while (--limit && !stop);
}

/******************************************************************************/
static void reset() {
    ptop->rst_n = 0;
    run(100, true, false);
    ptop->rst_n = 1;
}

/******************************************************************************/

static void sanityChecks() {
}

static bool stopCondition() {
    // Finish when $finish() was called
    return !runSim || Verilated::gotFinish();
}

static void onRisingEdge() {
}

static void onFallingEdge() {
}

/******************************************************************************/
int main(int argc, char **argv) {
    // Register signal handler in order to properly terminate the simulation
    std::signal(SIGINT, signal_handler);

    Verilated::commandArgs(argc, argv);
    ptop = new TOP_MODULE; // Create instance

    int verbose = 0;
    int start = 0;
    int pre_cycle_count = 0;

    int opt;
    while ((opt = getopt(argc, argv, ":s:t:v:n:")) != -1) {
        switch (opt) {
            case 'v':
                verbose = std::atoi(optarg);
                break;
            case 't':
                // init trace dump
                Verilated::traceEverOn(true);
                tfp = new VerilatedVcdC;
                ptop->trace(tfp, 200);
                tfp->open(optarg);
                break;
            case 's':
                start = std::atoi(optarg);
                break;
            case ':':
                std::cout << "option needs a value" << std::endl;
                goto exitAndCleanup;
                break;
            case 'n':
                pre_cycle_count = std::atoi(optarg);
                break;
            case '?': //used for some unknown options
                std::cout << "unknown option: " << optopt << std::endl;
                goto exitAndCleanup;
                break;
        }
    }

    // start things going
    reset();

    if (start) {
        run(start, false);
    }

    if (pre_cycle_count) {
        std::cout << "Executing " << pre_cycle_count << " pre cycles!" << std::endl;
        run(pre_cycle_count, true, false);
        std::cout << "Done!" << std::endl;
    }

    // Execute till stop condition
    run(100, true);

    std::cout << "rdata_o: 0x" << std::hex << ptop->data_o << std::endl;

exitAndCleanup:

    if (tfp)
        tfp->close();

    ptop->final(); // Done simulating

    if (tfp)
        delete tfp;

    delete ptop;

    return 0;
}
