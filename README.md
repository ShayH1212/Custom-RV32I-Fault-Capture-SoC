# RISC-V MCU

## Overview

This project creates a custom RISC-V MCU designed from the ground up using SystemVerilog.
The goal is to create a reusable MCU that can serve as the foundation for future projects.

<img width="4575" height="3313" alt="MCU High Level Block Diagram" src="https://github.com/user-attachments/assets/fdce3c38-ddd4-4bc9-a7c5-b901369e758e" />

## Current Status

The RTL design is complete and has been verified through simulation.

- Synthesized, placed, and routed for an Intel Cyclone V FPGA.
- 50 MHz timing target met with +4.446 ns worst-case setup slack.
- Physical FPGA validation is the remaining step.


## Project Goals

The goals of this project are to:

- Design a functional RISC-V CPU from the ground up.
- Develop and verify the processor using SystemVerilog.
- Progress from a simple single-cycle processor to a more advanced pipelined CPU architecture.
- Integrate memory and peripherals to create a complete microcontroller.
- Implement and test the design on FPGA hardware.
- Develop the MCU as a reusable platform for future projects.

## Architecture

The MCU is built around a custom 32-bit RV32I processor that uses a 5-stage pipelined architecture.

The processor is divided into the following pipeline stages:

1. Instruction Fetch
2. Instruction Decode
3. Execute
4. Memory
5. Writeback

The CPU includes data forwarding, hazard detection, pipeline stalling, and pipeline flushing.


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


## Development Stages

The project was developed in three main stages:

1. Design and verify a simple single-cycle RV32I CPU.
2. Develop a more advanced pipelined CPU architecture.
3. Integrate memory and peripherals to turn the CPU into a complete microcontroller.

## Tools

- SystemVerilog
- Icarus Verilog
- QuestaSim / ModelSim
- Intel Quartus Prime
- TimeQuest
- Git / GitHub
  
## Future Work

- Validate the MCU on FPGA hardware.
- Reuse and adapt the MCU for future projects.
