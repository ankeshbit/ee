# Phase 6 Known Limitations & Engineering Boundaries

**Project:** Power System Fault Analysis & Protection Coordination Simulator  
**Repository:** [https://github.com/ankeshbit/ee](https://github.com/ankeshbit/ee)  
**Date:** November 1, 2026  
**Status:** Educational & Engineering Analysis Tool  

---

## 1. Project Purpose & Scope Disclaimer

This simulator is designed, developed, and maintained as an **educational and engineering research simulator** for power system fault analysis and protection coordination. It is **not** certified as industrial-grade relay configuration software (such as CAPE, ASPEN OneLiner, or ETAP) and must not be used for live utility commissioning or safety-critical protection setting deployment without independent physical field verification.

---

## 2. Licensing and Environment Boundaries

1. **Simscape Electrical License Dependency:**
   - Physical time-domain simulations rely on MathWorks Simscape and Simscape Electrical library blocks (`ee_lib`).
   - If the `Simscape_Electrical` license token is absent from the host runner (`license('test', 'Simscape_Electrical') == 0`), physical time-domain simulations are marked as `BLOCKED`.
   - The simulator maintains strict data integrity: when blocked, it halts safely, records actionable diagnostic advice, and never synthesizes or fabricates simulated waveforms.
   - Pure analytical sequence calculations, Symmetrical Components fault solving, and relay operating curve calculations are fully decoupled from Simulink licenses and execute independently on all platforms.

---

## 3. Physical Model Topological Boundaries

1. **Supported Physical Fault Locations:**
   - The compiled Simscape network model (`simulink/models/radial_fault_study_network.slx`) models a 33/11 kV radial system with two fault block terminals:
     - **Bus B** (`BUS_B`): The downstream radial feeder terminal bus.
     - **Bus A** (`BUS_A`): The intermediate switching bus between Feeder BRA and Feeder BRB.
   - Requesting a physical fault at any other bus (e.g. `SOURCE_33KV`, `BUS_C`) is explicitly rejected with status `UNSUPPORTED`. It is not silently substituted with Bus B.
2. **Transformer Configuration:**
   - The authoritative master network and physical Simulink model implement **Grounded-Wye / Grounded-Wye (Ynyn0)** with both primary and secondary neutrals solidly grounded (0° phase displacement).
   - Alternative Delta-Grounded-Wye (Dyn11) transformers are fully supported in the analytical sequence engine (blocking zero sequence and modeling the 30° positive-sequence phase displacement), but are not implemented in the default physical Simscape model.
3. **Breaker Pole Operation:**
   - Circuit breakers (`CB_33KV`, `CB_BUS_A`, `CB_BUS_B`) operate as three-phase gang-operated mechanisms. Single-phase auto-reclosing or independent pole tripping is not currently modeled.
4. **Feeder Mutual Coupling:**
   - Zero-sequence mutual inductive coupling between adjacent parallel circuits is neglected; feeders are represented as uncoupled series R-L elements.

