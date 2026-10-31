# Known Engineering & Implementation Limitations

**Project:** Power System Fault Analysis & Protection Coordination Simulator  
**Repository:** [https://github.com/ankeshbit/ee](https://github.com/ankeshbit/ee)  
**Author:** Senior MATLAB/Simulink Engineer, Power Systems Protection Specialist & QA Architect  
**Date:** October 31, 2026  

---

## 1. Network Topology Scope
- **Radial Networks Only:** The analytical fault calculation engine ([`matlab/analysis/runIntegratedFaultStudy.m`](file:///c:/Users/ankes/OneDrive/Desktop/ee/matlab/analysis/runIntegratedFaultStudy.m) and [`matlab/network/traceRadialPath.m`](file:///c:/Users/ankes/OneDrive/Desktop/ee/matlab/network/traceRadialPath.m)) is specifically formulated for single-source radial distribution networks. Meshed networks, ring networks, and multi-source systems with bi-directional fault current contributions require full bus admittance matrix inversion ($Y_{\text{bus}}^{-1} = Z_{\text{bus}}$), which is beyond the current design scope.
- **Single Source Configuration:** All radial paths must originate from a designated unique `sourceBus`. Distributed generation (DG) integration along feeders is not currently modeled in the analytical engine.

## 2. Signal Processing & Phasor Estimation
- **Fixed Nominal Frequency Assumption:** Fundamental phasor estimation ([`estimateFundamentalPhasor.m`](file:///c:/Users/ankes/OneDrive/Desktop/ee/matlab/analysis/estimateFundamentalPhasor.m)) uses Fourier integral projection based on a nominal rated frequency (50 Hz or 60 Hz). If substantial frequency excursions occur during large disturbances, spectral leakage may introduce slight phasor estimation errors.
- **Constant Transient Exclusion Interval:** [`validateMeasurementWindow.m`](file:///c:/Users/ankes/OneDrive/Desktop/ee/matlab/analysis/validateMeasurementWindow.m) uses a configurable cycle count (`cyclesToSkipTransient`, default 1.0 cycle) to skip decaying DC offset. Highly inductive circuits with extremely large $X/R$ ratios ($X/R > 30$) may have DC time constants exceeding 40 ms; studies on such circuits should configure `cyclesToSkipTransient = 2.0` or higher.

## 3. Physical Simulation & Toolbox Dependencies
- **Toolbox License Tokens:** Full time-domain physical Simscape Electrical simulation requires either the `Simscape_Electrical` license token or the `Power_System_Blocks` token. When neither token is present, the simulator cleanly reports `BLOCKED` with explicit diagnostics rather than crashing or providing falsified data.
- **Sliding RMS Memory Overhead:** Very high sample rates ($f_s > 100\text{ kHz}$) combined with long simulation durations ($t > 10\text{ s}$) produce large memory allocations during sliding RMS vector computation.

## 4. Protection Modeling Assumptions
- **Linear CT Characteristics:** Secondary current calculations assume ideal linear current transformers without deep magnetic core saturation or hysteresis loops. Severe asymmetrical fault currents with prolonged DC offset may experience saturation in physical substations.
- **Zero-Order Switching Dynamics:** Dynamic breaker opening is modeled as an instantaneous impedance transition to an open circuit with arc extinction represented by an empirical threshold ($I_{\text{extinct}} \le 0.01\text{ A}$), rather than complex Cassie-Mayr dynamic electric arc physics.

