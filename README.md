# Fault Data Capture SoC with Custom RV32I CPU and MCU

## Overview

This project creates a custom fault data capture SoC designed from the ground up using SystemVerilog.
The project aims to create a specialised fault data recorder that prioritizes low power and low area.
The project began with a custom RV32I CPU, which was expanded into a complete MCU with memory and memory-mapped peripherals.
The MCU is now being integrated into a fault data capture SoC designed for embedded diagnostics.
The SoC sits next to an MCU on a PCB and passively records data while waiting for a fault to occur.
The SoC detects this fault and wakes up the CPU to process the recorded behaviour of the PCB in the time surrounding the fault.

<img width="3789" height="4383" alt="Fault Capture SoC High Level Block Diagram" src="https://github.com/user-attachments/assets/d248d160-2101-424d-858b-250924a150fe" />


## Current Status

### RV32I CPU and MCU

The CPU and MCU RTL are complete and have been verified through simulation.

- Custom 32-bit RV32I processor
- 5-stage pipelined architecture
- Data forwarding
- Load-use hazard detection
- Pipeline stalling and flushing
- Memory-mapped peripherals
- 153 CPU / 55 MCU peripheral and 15 overall system integration tests passed
- Synthesized, placed, and routed for an Intel Cyclone V FPGA
- 50 MHz timing target met with +4.446 ns worst-case setup slack
- Physical FPGA validation is the remaining step

### Fault Data Capture SoC

The main fault detection and capture modules have been designed.

Current functionality includes:

- Three configurable 16-bit ADC threshold comparators
- Configurable digital fault-pattern detectors
- Two configurable serial fault-pattern detectors
- 32-bit timestamp counter
- 64x64-bit circular capture buffer
- Pre-fault and post-fault data capture
- Firmware-accessible configuration and status registers
- Configurable ADC thresholds
- Configurable digital and serial fault patterns

Top-level SoC integration and overall system verification are currently in development.

## Project Goals

The goals of this project are to:

- Design a functional RISC-V CPU from the ground up.
- Develop and verify the processor using SystemVerilog.
- Progress from a simple single-cycle processor to a more advanced pipelined CPU architecture.
- Integrate memory and peripherals to create a complete microcontroller.
- Use the MCU as the processing foundation for the fault capture SoC.
- Detect analog, digital and serial faults in hardware.
- Allow firmware to configure fault conditions and process captured data.
- Implement and test the design on FPGA hardware.
- Present the RTL and verification results to the IEEE ASIC team for ASIC implementation.

## Architecture

The MCU is built around a custom 32-bit RV32I processor that uses a 5-stage pipelined architecture.

The processor is divided into the following pipeline stages:

1. Instruction Fetch
2. Instruction Decode
3. Execute
4. Memory
5. Writeback

The CPU includes data forwarding, hazard detection, pipeline stalling, and pipeline flushing.

<img width="1024" height="768" alt="image" src="https://github.com/user-attachments/assets/3d43c7b9-b1e5-485b-891b-c4d4a13fdf5a" />


### MCU Components

- 5-stage pipelined RV32I CPU
- Instruction memory
- 2 KB data memory
- GPIO
- UART
- SPI
- I2C
- Timer
- Interrupt controller

The peripherals are accessed through memory-mapped addresses.
The CPU can control each peripheral using load and store instructions.

<img width="4575" height="3313" alt="MCU High Level Block Diagram" src="https://github.com/user-attachments/assets/fdce3c38-ddd4-4bc9-a7c5-b901369e758e" />


## Fault Capture Architecture

The fault capture subsystem continuously monitors the connected ADC, digital, and serial signals.

When a fault occurs:

1. The fault is detected in hardware.
2. The timestamp of the fault is recorded.
3. 32 pre-fault samples, the fault sample, and 31 post-fault samples are recorded.
4. The CPU is woken up and exposed to the captured data.
5. Firmware can analyze, display or transmit the captured data.

Each captured sample contains ADC measurements, digital and serial inputs, and information about each fault state.

## Firmware Interface

Firmware can configure:

- ADC upper and lower thresholds
- ADC comparator enables
- Digital fault patterns
- Digital fault enable masks
- Serial fault patterns
- Serial fault enable masks
- Fault clear and control

Firmware can read:

- Fault status
- Capture completion status
- Fault timestamp
- Captured fault data


## Development Stages

The project was developed in four main stages:

1. Single-cycle RV32I CPU.
2. Advanced pipelined CPU architecture.
3. Memory-mapped MCU.
4. Fault data capture SoC.

## Tools

- SystemVerilog
- Icarus Verilog
- QuestaSim / ModelSim
- Intel Quartus Prime
- TimeQuest
- Git / GitHub
  
## Future Work

- Perform full CPU fault capture verification.
- Validate the complete system on FPGA hardware.
