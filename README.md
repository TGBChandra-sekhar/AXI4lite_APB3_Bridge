# AXI4-Lite to APB3 Bridge (Timing-Optimized, Pipelined)

## Overview
This project implements a **timing-optimized AXI4-Lite to APB3 bridge** intended for **FPGA-based SoC integration**.

AXI4-Lite is a high-speed, low-latency protocol commonly used by processors and interconnects, while APB3 is a simpler, low-power protocol used for peripheral access. Since these two protocols operate at different speeds and timing characteristics, a robust bridge is required to safely and reliably connect them.

The primary focus of this design is **timing closure and protocol correctness**, not maximum throughput.

---

## Key Features
- AXI4-Lite to APB3 protocol conversion  
- Four-stage pipelined architecture for improved timing  
- Designed for FPGA timing robustness  
- Supports **one outstanding transaction**  
- Proper backpressure handling on AXI interface  
- Fully compliant with AXI4-Lite and APB3 protocol rules  
- Written entirely in **Verilog**  
- Verified using **directed testbenches**  
- Achieves **250 MHz post-synthesis timing** on FPGA  

---

## Architecture Overview

The bridge uses a **four-stage pipeline**, carefully designed to break long combinational paths and improve timing closure.

### Stage 0 – AXI Transaction Capture
- Captures AXI4-Lite read and write transactions
- Uses **valid–ready handshaking**
- Accepts new transactions only when the bridge is ready
- Applies backpressure when APB is busy

### Stage 1 & Stage 2 – Pipeline Registers
- Pure pipeline stages
- Break long combinational paths between AXI and APB logic
- Significantly improve timing margin
- No protocol logic, only registered signal forwarding

### Stage 3 – APB Control Logic
- Implements the **APB3 state machine**
- Generates `PSEL`, `PENABLE`, `PWRITE`, `PADDR`, `PWDATA`
- Samples `PRDATA` and `PREADY`
- Completes APB transactions safely

---

## Key Contribution: Request Latch Mechanism

The **request latch** is the most important design element of this bridge.

### Why it is needed:
- APB transactions are multi-cycle and slower
- AXI can present new requests before APB completes
- Without protection, this can cause:
  - Race conditions  
  - Data corruption  
  - Protocol violations  

### How it works:
- Once an AXI request reaches Stage-3, it is **latched**
- The latched request is held stable until APB completes
- New AXI requests are stalled using backpressure
- Ensures **safe, deterministic protocol conversion**

This guarantees reliability even under aggressive AXI timing.

---

## Transaction Handling
- Supports **one outstanding AXI transaction**
- Enforces strict ordering
- AXI responses are generated only after APB completion
- Read and write channels handled correctly as per AXI4-Lite specification

---

## Verification
- Verified using **directed Verilog testbenches**
- Tested for:
  - Read transactions
  - Write transactions
  - Back-to-back requests
  - Backpressure scenarios
  - APB wait-state handling
- Focused on functional correctness and corner cases

---

## Performance
- Target: FPGA-based SoC designs
- Achieves **250 MHz post-synthesis timing**
- Timing optimization achieved through:
  - Deep pipelining
  - Controlled fanout
  - Elimination of long combinational paths

---

## Design Goals
- Reliable protocol conversion
- Strong timing robustness
- Clean, maintainable RTL
- FPGA-friendly architecture
- Simple and deterministic behavior

---

## Technologies Used
- **Language:** Verilog HDL  
- **Protocols:** AXI4-Lite, APB3  
- **Target:** FPGA  
- **Verification:** Directed testbenches  

---

## Use Cases
- Processor to peripheral interconnect
- FPGA-based SoCs
- Control/status register access
- Low-power peripheral integration

---

## Notes
This bridge prioritizes **correctness and timing closure** over raw throughput, making it well-suited for real-world FPGA designs where meeting timing is critical.

---

## Author
Designed and implemented as part of an FPGA protocol-integration and timing-optimization project.
