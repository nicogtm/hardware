# Introduction

This document specifies the implementation of the core debug module
for cores with an advanced debug system interface.

## License

This work is licensed under the Creative Commons
Attribution-ShareAlike 4.0 International License. To view a copy of
this license, visit
[http://creativecommons.org/licenses/by-sa/4.0/](http://creativecommons.org/licenses/by-sa/4.0/)
or send a letter to Creative Commons, PO Box 1866, Mountain View, CA
94042, USA.

You are free to share and adapt this work for any purpose as long as
you follow the following terms: (i) Attribution: You must give
appropriate credit and indicate if changes were made, (ii) ShareAlike:
If you modify or derive from this work, you must distribute it under
the same license as the original.

## Authors

Stefan Wallentowitz

Fill in your name here!

# Core Interface

The core is connected as a slave on this interface:

 Signal | Driver | Width | Description
 ------ | ------ | ----- | -----------
 `stall` | Module | 1 | Stall the core
 `breakpoint` | Core | 1 | Indicates breakpoint
 `strobe` | Module | 1 | Access to the core debug interface
 `ack` | Core | 1 | Complete access to the core
 `adr` | Module | ? | Address of CPU register to access
 `write` | Module | 1 | Write access
 `data_in` | Module | `DATA_WIDTH` | Write data
 `data_out` | Core | `DATA_WIDTH` | Read data

# Memory Map

The following map applies to the interface.
A leading `1` is used to address the slave module/CPU core.

Address Range       | Description
-------------       | -----------
`0x0000` - `0x01ff` | Control and Status
`0x0200`            | Interrupt Cause
`0x0201` - `0x7fff` | Reserved
`0x8000` - `0xffff` | Slave module address space, mapped to `0x0000` - `0x7fff` 

Through this, registers can be read/written that would otherwise
 be accessed by the Advanced Debug System, giving access 
to a variety of run control debug features and system status information.

## General Purpose Registers
## Control- and Status Registers
## Interrupt Cause Register


## OpenRISC 1000 Register Set
The following section describes the OpenRISC 1000 architecture's register set. It contains sixteen or thirty-two 32/64-bit General Purpose Registers (GPR) as well as a range of Special Purpose Registers (SPR).
 
SPRs are 16-bit addressed, with the five most significant bits specifying the register "group". Due to address masking, only groups `0` to `15` are addressable through Open SoC Debug.

Bits       | Content
-------------       | -----------
`15:11` | Group Index
`10:0` | Register Index 

The groups are defined as follows:

Group  #     | Description
-------------       | -----------
`0` | System Control and Status registers
`1` | Data MMU
`2` | Instruction MMU
`3` | Data Cache
`4` | Instruction Cache
`5` | MAC Unit
`6` | Debug Unit
`7` | Performance Counters
`8` | Power Management
`9` | Programmable Interrupt Controller
`10` | Tick Timer
`11` | Floating Point Unit
`12`-`23` | Reserved for future use
`24`-`31` | Custom Units

Out of these, only group `0` is mandatorily implemented. Accesses to unimplemented registers will read as `0`. For further details refer to the [OR1000 Architecture Manual](http://opencores.org/websvn,filedetails?repname=openrisc&path=%2Fopenrisc%2Ftrunk%2Fdocs%2Fopenrisc-arch-1.1-rev0.pdf)

### Debug Unit registers
Of particular interest for Open SoC Debug implementations is the Debug Unit register group, containing the following registers:

Register  #     | Reg Name     |  Description
-------------   | -----------  | -----------
`0`-`7` | `DVR0` - `DVR7` |  Debug Value registers
`8`-`15` | `DCR0` - `DCR7` | Debug Control registers 
`16` | `DMR1` | Debug Mode register 1 
`17` | `DMR2` | Debug Mode register 2
`18`-`19` | `DCWR0`-`DCWR1` | Debug Watchpoint Counter registers
`20` | `DSR` | Debug Stop register
`21` | `DRR` | Debug Reason register

DVR/DCR   pairs   are   used   to   compare   instruction   fetch   or   load/store   EA and
load/store data to the value stored in DVRs. Matches can be combined into more complex
matches   and   used   for   generation   of   watchpoints.   Watchpoints   can   be   counted   and
reported as breakpoint.

In case of the CPU halting and turning over control to the debugger, the DSR contains information on what kind of exception caused the core to halt.

For further details refer to the [OR1000 Architecture Manual](http://opencores.org/websvn,filedetails?repname=openrisc&path=%2Fopenrisc%2Ftrunk%2Fdocs%2Fopenrisc-arch-1.1-rev0.pdf)

# Breakpoint Indication

The core setting the `breakpoint` signal to `1` indicates that a breakpoint has been encountered.

TODO: Handle this signal properly, write the `Interrupt Cause` register, notify the host and
turn over control.

