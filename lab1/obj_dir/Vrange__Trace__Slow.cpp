// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vrange__Syms.h"


//======================

void Vrange::trace(VerilatedVcdC* tfp, int, int) {
    tfp->spTrace()->addCallback(&Vrange::traceInit, &Vrange::traceFull, &Vrange::traceChg, this);
}
void Vrange::traceInit(VerilatedVcd* vcdp, void* userthis, uint32_t code) {
    // Callback from vcd->open()
    Vrange* t = (Vrange*)userthis;
    Vrange__Syms* __restrict vlSymsp = t->__VlSymsp;  // Setup global symbol table
    if (!Verilated::calcUnusedSigs()) {
        VL_FATAL_MT(__FILE__, __LINE__, __FILE__,
                        "Turning on wave traces requires Verilated::traceEverOn(true) call before time 0.");
    }
    vcdp->scopeEscape(' ');
    t->traceInitThis(vlSymsp, vcdp, code);
    vcdp->scopeEscape('.');
}
void Vrange::traceFull(VerilatedVcd* vcdp, void* userthis, uint32_t code) {
    // Callback from vcd->dump()
    Vrange* t = (Vrange*)userthis;
    Vrange__Syms* __restrict vlSymsp = t->__VlSymsp;  // Setup global symbol table
    t->traceFullThis(vlSymsp, vcdp, code);
}

//======================


void Vrange::traceInitThis(Vrange__Syms* __restrict vlSymsp, VerilatedVcd* vcdp, uint32_t code) {
    Vrange* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    int c = code;
    if (0 && vcdp && c) {}  // Prevent unused
    vcdp->module(vlSymsp->name());  // Setup signal names
    // Body
    {
        vlTOPp->traceInitThis__1(vlSymsp, vcdp, code);
    }
}

void Vrange::traceFullThis(Vrange__Syms* __restrict vlSymsp, VerilatedVcd* vcdp, uint32_t code) {
    Vrange* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    int c = code;
    if (0 && vcdp && c) {}  // Prevent unused
    // Body
    {
        vlTOPp->traceFullThis__1(vlSymsp, vcdp, code);
    }
    // Final
    vlTOPp->__Vm_traceActivity = 0U;
}

void Vrange::traceInitThis__1(Vrange__Syms* __restrict vlSymsp, VerilatedVcd* vcdp, uint32_t code) {
    Vrange* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    int c = code;
    if (0 && vcdp && c) {}  // Prevent unused
    // Body
    {
        vcdp->declBit(c+209,"clk", false,-1);
        vcdp->declBit(c+217,"go", false,-1);
        vcdp->declBus(c+225,"start", false,-1, 31,0);
        vcdp->declBit(c+233,"done", false,-1);
        vcdp->declBus(c+241,"count", false,-1, 15,0);
        vcdp->declBus(c+249,"range RAM_WORDS", false,-1, 31,0);
        vcdp->declBus(c+257,"range RAM_ADDR_BITS", false,-1, 31,0);
        vcdp->declBit(c+209,"range clk", false,-1);
        vcdp->declBit(c+217,"range go", false,-1);
        vcdp->declBus(c+225,"range start", false,-1, 31,0);
        vcdp->declBit(c+233,"range done", false,-1);
        vcdp->declBus(c+241,"range count", false,-1, 15,0);
        vcdp->declBit(c+25,"range cgo", false,-1);
        vcdp->declBit(c+33,"range cdone", false,-1);
        vcdp->declBus(c+41,"range n", false,-1, 31,0);
        vcdp->declBus(c+49,"range num", false,-1, 3,0);
        vcdp->declBit(c+1,"range running", false,-1);
        vcdp->declBit(c+57,"range we", false,-1);
        vcdp->declBus(c+65,"range din", false,-1, 15,0);
        {int i; for (i=0; i<16; i++) {
                vcdp->declBus(c+73+i*1,"range mem", true,(i+0), 15,0);}}
        vcdp->declBus(c+17,"range addr", false,-1, 3,0);
        vcdp->declBit(c+209,"range c1 clk", false,-1);
        vcdp->declBit(c+25,"range c1 go", false,-1);
        vcdp->declBus(c+41,"range c1 n", false,-1, 31,0);
        vcdp->declBus(c+201,"range c1 dout", false,-1, 31,0);
        vcdp->declBit(c+33,"range c1 done", false,-1);
        vcdp->declBus(c+9,"range c1 dout_next", false,-1, 31,0);
    }
}

void Vrange::traceFullThis__1(Vrange__Syms* __restrict vlSymsp, VerilatedVcd* vcdp, uint32_t code) {
    Vrange* __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    int c = code;
    if (0 && vcdp && c) {}  // Prevent unused
    // Body
    {
        vcdp->fullBit(c+1,(vlTOPp->range__DOT__running));
        vcdp->fullBus(c+9,(vlTOPp->range__DOT__c1__DOT__dout_next),32);
        vcdp->fullBus(c+17,(vlTOPp->range__DOT__addr),4);
        vcdp->fullBit(c+25,(vlTOPp->range__DOT__cgo));
        vcdp->fullBit(c+33,(vlTOPp->range__DOT__cdone));
        vcdp->fullBus(c+41,(vlTOPp->range__DOT__n),32);
        vcdp->fullBus(c+49,(vlTOPp->range__DOT__num),4);
        vcdp->fullBit(c+57,(vlTOPp->range__DOT__we));
        vcdp->fullBus(c+65,(vlTOPp->range__DOT__din),16);
        vcdp->fullBus(c+73,(vlTOPp->range__DOT__mem[0]),16);
        vcdp->fullBus(c+74,(vlTOPp->range__DOT__mem[1]),16);
        vcdp->fullBus(c+75,(vlTOPp->range__DOT__mem[2]),16);
        vcdp->fullBus(c+76,(vlTOPp->range__DOT__mem[3]),16);
        vcdp->fullBus(c+77,(vlTOPp->range__DOT__mem[4]),16);
        vcdp->fullBus(c+78,(vlTOPp->range__DOT__mem[5]),16);
        vcdp->fullBus(c+79,(vlTOPp->range__DOT__mem[6]),16);
        vcdp->fullBus(c+80,(vlTOPp->range__DOT__mem[7]),16);
        vcdp->fullBus(c+81,(vlTOPp->range__DOT__mem[8]),16);
        vcdp->fullBus(c+82,(vlTOPp->range__DOT__mem[9]),16);
        vcdp->fullBus(c+83,(vlTOPp->range__DOT__mem[10]),16);
        vcdp->fullBus(c+84,(vlTOPp->range__DOT__mem[11]),16);
        vcdp->fullBus(c+85,(vlTOPp->range__DOT__mem[12]),16);
        vcdp->fullBus(c+86,(vlTOPp->range__DOT__mem[13]),16);
        vcdp->fullBus(c+87,(vlTOPp->range__DOT__mem[14]),16);
        vcdp->fullBus(c+88,(vlTOPp->range__DOT__mem[15]),16);
        vcdp->fullBus(c+201,(vlTOPp->range__DOT__c1__DOT__dout),32);
        vcdp->fullBit(c+209,(vlTOPp->clk));
        vcdp->fullBit(c+217,(vlTOPp->go));
        vcdp->fullBus(c+225,(vlTOPp->start),32);
        vcdp->fullBit(c+233,(vlTOPp->done));
        vcdp->fullBus(c+241,(vlTOPp->count),16);
        vcdp->fullBus(c+249,(0x10U),32);
        vcdp->fullBus(c+257,(4U),32);
    }
}
