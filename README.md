# fft-processor-rtl-to-gates
FFT processor implemented in Verilog and synthesized using Yosys (Sky130). Implements an 8-point Radix-2 FFT using 16-bit fixed-point arithmetic, with ~9.6K cells and ~68K µm² area. Explores how signal processing algorithms map to hardware and related design trade-offs.

# FFT Processor (Verilog + Yosys Synthesis)

## 📌 Overview
This project implements an 8-point FFT (Fast Fourier Transform) processor in Verilog and explores how a signal processing algorithm maps to real hardware.

The design was implemented on the Basys 3 FPGA board and further analyzed using logic synthesis (Yosys + Sky130), providing insights into hardware complexity, area, and design trade-offs.


## 🏗️ Architecture and Design Flow

<img width="1200" height="765" alt="ChatGPT Image Apr 22, 2026, 11_30_10 PM" src="https://github.com/user-attachments/assets/ca61fad1-a808-4ef0-8029-45feb721ae3b" />

The system consists of:

- FFT Core (Radix-2 DIT, 3 stages)
- Memory for intermediate data storage
- FSM-based control logic
- UART interface for MATLAB–FPGA communication
- Implemented and tested on Basys 3 FPGA (Artix-7)

The brief design flow is as follows:
1. Generate input samples in MATLAB  
2. Send data via UART  
3. FPGA computes FFT  
4. Output transmitted back  
5. MATLAB visualizes results  

## 🔧 Features

- 8-point Radix-2 DIT FFT  
- 16-bit fixed-point arithmetic  
- Butterfly-based architecture  
- Twiddle factor multiplication  
- FSM-controlled data flow  
- UART integration for real-time testing  

## 📊 Synthesis Results

- Total Cells: **9661**  
- Flip-Flops: **306**  
- Area: **~68,311 µm²**

### 🔍 Key Insight
Multipliers are implemented using logic gates, which significantly increases hardware area.

## 📈 Output Results

- FPGA output matches MATLAB FFT (with minor quantization error)

## ▶️ How to Run

### FPGA (Basys 3)
- Synthesize and implement using Xilinx Vivado  
- Program the design onto Basys 3 FPGA  
- Connect UART via USB (115200 baud)  

### MATLAB
Run:
```matlab
fft_project_controller
```

### 📂 Project Structure
- rtl/          → Verilog design
- matlab/       → MATLAB script
- synthesis/    → Yosys script + netlist
- constraints/  → BitStream File for BASYS 3 Board
- results/      → Output images
- docs/         → Diagrams

### 🚀 Future Work
1. Static Timing Analysis (OpenSTA)
2. UVM-based verification (SystemVerilog)
3. Area optimization (multiplier reduction)

### 🛠 Tools Used
1. MATLAB
2. Yosys
3. Xilinx Vivado (Basys 3 FPGA - Artix-7)
4. Sky130
5. Verilog HDL


