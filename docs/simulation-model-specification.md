# Simscape Electrical Simulation Model Specification

## 1. Overview and Engineering Objectives

This document defines the physical modeling specification for the time-domain dynamic simulation engine of the **Power System Fault Analysis & Protection Coordination Simulator**.

The purpose of this specification is to establish a rigorous, reproducible mapping between the MATLAB analytical engine (symmetrical-component, sequence-network, and per-unit calculations) and a time-domain physical model built in **Simscape Electrical** (Simscape physical modeling domain).

> **Current Environment Status & Licensing Resolution:**
> - Installed release: **MATLAB R2026b**
> - Simulink: Installed and Licensed (`license('test','Simulink') == 1`)
> - Simscape: Installed and Licensed (`license('test','Simscape') == 1`)
> - Simscape Electrical: Library `ee_lib.slx` installed with 170+ physical blocks.
> - **Licensing Verification:** While `license('test','Simscape_Electrical')` returns `0` (error -5.2), `license('test','Power_System_Blocks')` returns `1`. Simulink successfully checks out `power_system_blocks` during model compilation and time-domain simulation, allowing native Simscape Electrical models to compile and execute physically without error.

---

## 2. Component Inventory & Verified Block Library Paths

All 15 component selections have been verified by `verifySimscapeComponents` against the installed **MATLAB R2026b** Simscape Electrical library (`ee_lib.slx`) and physical modeling utilities (`nesl_utility.slx`):

| Physical Component | Library Block Path | Parameter Interface / Domain | Instantiation Status |
| :--- | :--- | :--- | :--- |
| **Three-Phase Source** | `ee_lib/Sources/Voltage Source (Three-Phase)` | Three-phase sinusoidal AC source (`V_param = '11000'`, `f_param = '50'`) | **VERIFIED** |
| **Source / Line Impedance** | `ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)` | Series R-L branch (`component_structure = ee.enum.rlc.structure.SeriesRL`, `R_param = '10'`, `L_param = '0.01'`) | **VERIFIED** |
| **Busbars & Terminals** | `ee_lib/Connectors & References/Busbar` | Conserving electrical nodes for three-phase line conductors | **VERIFIED** |
| **33/11 kV Transformer** | `ee_lib/Passive/Transformers/Two-Winding Transformer (Three-Phase)` | Two-winding 3-phase transformer (`P_nom = '10e6'`, `f_nom = '50'`) | **VERIFIED** |
| **Radial Feeder Sections** | `ee_lib/Passive/RLC Assemblies/RLC (Three-Phase)` | Three-phase series branch impedance representing distribution feeder segments | **VERIFIED** |
| **Three-Phase VI Sensors** | `ee_lib/Sensors & Transducers/Current and Voltage Sensor (Three-Phase)` | Non-intrusive voltage and line current measurement | **VERIFIED** |
| **Configurable Fault Element**| `ee_lib/Utilities/Fault (Three-Phase)` | Programmable timed switching for 3PH, SLG, LL, and DLG faults | **VERIFIED** |
| **Circuit Breakers** | `ee_lib/Switches & Breakers/Circuit Breaker (Three-Phase)` | Timed or signal-controlled three-phase breaker | **VERIFIED** |
| **Ground Reference** | `ee_lib/Connectors & References/Electrical Reference` | Electrical zero-potential reference node | **VERIFIED** |
| **Grounded Neutral** | `ee_lib/Connectors & References/Grounded Neutral (Three-Phase)` | Solid or impedance-grounded neutral point for composite three-phase star points | **VERIFIED** |
| **Simscape Solver Config** | `nesl_utility/Solver Configuration` | Simscape physical-network solver configuration block | **VERIFIED** |
| **PS-Simulink Converter** | `nesl_utility/PS-Simulink Converter` | Converts Simscape physical signals to Simulink signals | **VERIFIED** |
| **Simulink-PS Converter** | `nesl_utility/Simulink-PS Converter` | Converts Simulink signals to Simscape physical signals | **VERIFIED** |

*Note: Specialized Power Systems (`powerlib`) is legacy and explicitly excluded in favor of modern Simscape physical conserving networks (`ee_lib`).*
*Port Connection Rule: In Simscape Electrical, three-phase ports are composite conserving ports. They cannot be wired directly to single-phase physical conserving ports; neutral grounding must use `Grounded Neutral (Three-Phase)`.*

---

## 3. Network Architecture & Connection Topology

The target dynamic model implements the illustrative two-voltage-level radial network:

```
[33 kV Grid Source]
       │
   (Source R-L)
       │
  [BUS_33KV (Source Bus)]
       │
 [33/11 kV Step-Down Transformer T1]
       │
  [BUS_11KV (Distribution Bus)]
       │
   (Feeder Section BR_A)
       │
  [BUS_A (Intermediate Bus)]
       │
   (Feeder Section BR_B)
       │
  [BUS_B (Faulted / Terminal Bus)]
       │
 [Three-Phase Timed Fault Block]
```

### Node and Port Mapping
1. **Source Node:** Three-phase sinusoidal AC source configured at $33\,\text{kV}$ line-to-line RMS, $50\,\text{Hz}$.
2. **Transformer Primary:** High-voltage terminals ($A, B, C$) connect to `BUS_33KV`. Neutral node $N$ connects to `Electrical Reference`.
3. **Transformer Secondary:** Low-voltage terminals ($a, b, c$) connect to `BUS_11KV`. Neutral node $n$ connects to `Electrical Reference` (for grounded-wye secondary).
4. **Feeder BR_A:** Three-phase series R-L branch connecting `BUS_11KV` to `BUS_A`.
5. **Feeder BR_B:** Three-phase series R-L branch connecting `BUS_A` to `BUS_B`.
6. **Fault Block:** Terminals connect across phases $A, B, C$ at the faulted bus, with the ground terminal tied to `Electrical Reference`.
7. **Measurement Tap Points:** Installed at `BUS_33KV`, transformer primary, transformer secondary, `BUS_11KV`, `BUS_A`, and `BUS_B`.

---

## 4. Parameter Mapping & Physical Unit Derivations

### Base Values
- System Base Power: $S_{\text{base}} = 10\,\text{MVA} = 10 \times 10^6\,\text{VA}$
- System Fundamental Frequency: $f_0 = 50\,\text{Hz}$, $\omega_0 = 2\pi f_0 = 314.1593\,\text{rad/s}$

#### 33 kV Network Section
- Voltage Base: $V_{\text{base,33}} = 33\,\text{kV} = 33,000\,\text{V}$ (line-to-line RMS)
- Base Current:
  $$I_{\text{base,33}} = \frac{S_{\text{base}}}{\sqrt{3} \cdot V_{\text{base,33}}} = \frac{10 \times 10^6}{\sqrt{3} \times 33,000} \approx 174.9546\,\text{A}$$
- Base Impedance:
  $$Z_{\text{base,33}} = \frac{V_{\text{base,33}}^2}{S_{\text{base}}} = \frac{(33,000)^2}{10 \times 10^6} = 108.90\,\Omega$$

#### 11 kV Network Section
- Voltage Base: $V_{\text{base,11}} = 11\,\text{kV} = 11,000\,\text{V}$ (line-to-line RMS)
- Base Current:
  $$I_{\text{base,11}} = \frac{S_{\text{base}}}{\sqrt{3} \cdot V_{\text{base,11}}} = \frac{10 \times 10^6}{\sqrt{3} \times 11,000} \approx 524.8638\,\text{A}$$
- Base Impedance:
  $$Z_{\text{base,11}} = \frac{V_{\text{base,11}}^2}{S_{\text{base}}} = \frac{(11,000)^2}{10 \times 10^6} = 12.10\,\Omega$$

### Impedance to Physical R and L Conversions

The analytical engine specifies branch impedances in per-unit on the $10\,\text{MVA}$ base:
$$R = R_{\text{pu}} \cdot Z_{\text{base}}, \quad X = X_{\text{pu}} \cdot Z_{\text{base}}, \quad L = \frac{X}{2\pi f_0}$$

| Element | Voltage Level | $Z_{\text{pu}}$ (Analytical) | Physical $R$ ($\Omega$) | Physical $X$ ($\Omega$) | Physical $L$ ($\text{H}$) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Source Thevenin** | $33\,\text{kV}$ | $Z_1 = 0.10\,\text{pu}$ ($X/R \gg 10$) | $0.1089\,\Omega$ | $10.890\,\Omega$ | $34.665\,\text{mH}$ |
| **Transformer T1** | $33/11\,\text{kV}$ | $Z_1 = 0.08\,\text{pu}$ | $0.0968\,\Omega$ (HV side) | $8.712\,\Omega$ (HV side) | $27.732\,\text{mH}$ |
| **Feeder BR_A** | $11\,\text{kV}$ | $Z_1 = 0.05\,\text{pu}$ | $0.0605\,\Omega$ | $0.6050\,\Omega$ | $1.9258\,\text{mH}$ |
| **Feeder BR_B** | $11\,\text{kV}$ | $Z_1 = 0.05\,\text{pu}$ | $0.0605\,\Omega$ | $0.6050\,\Omega$ | $1.9258\,\text{mH}$ |
| **Fault Impedance $Z_f$** | $11\,\text{kV}$ | $0.05\,\text{pu}$ | $0.6050\,\Omega$ | — | — |

---

## 5. Grounding, Winding Configurations, & Phase Displacement

1. **Source Grounding:** Solidly grounded neutral at the $33\,\text{kV}$ generation/grid source.
2. **Transformer Vector Group:**
   - **Baseline Case (Ynyn0):** Grounded-Wye / Grounded-Wye with both neutral terminals grounded directly. Phase displacement is $0^\circ$, directly matching the analytical sequence-component formulation without additional phase rotation.
   - **Alternative Case (Dyn11):** Delta primary ($33\,\text{kV}$) with Grounded-Wye secondary ($11\,\text{kV}$). Winding connection causes a $-30^\circ$ phase shift in positive-sequence voltages/currents and blocks zero-sequence current transfer from the $11\,\text{kV}$ side to the $33\,\text{kV}$ side.
3. **Sequence Impedance Consistency:**
   - Positive sequence: $Z_1 = R_1 + j\omega L_1$
   - Negative sequence: $Z_2 = Z_1$ (for static network elements and transformers)
   - Zero sequence: $Z_0$ as configured in network definition. For Ynyn0 transformers, $Z_0 \approx Z_1$. For feeders, $Z_{0,\text{branch}} = 3 \cdot Z_{1,\text{branch}}$ as specified in analytical models ($Z_{0,\text{pu}} = 0.15$).

---

## 6. Fault Inception & Simulation Solver Settings

1. **Fault Switching Dynamics:**
   - Prefault Steady-State Duration: $0.00\,\text{s}$ to $0.05\,\text{s}$ (2.5 fundamental cycles).
   - Fault Inception Timestamp: $t_{\text{fault}} = 0.05\,\text{s}$.
   - Post-Fault Duration: $0.05\,\text{s}$ to $0.20\,\text{s}$ (7.5 fundamental cycles).
   - Transient interval: $0.05\,\text{s}$ to $0.07\,\text{s}$ (1 cycle skipped to avoid subtransient DC offset when computing steady-state RMS).
   - Steady-state measurement window: $0.07\,\text{s}$ to $0.19\,\text{s}$ (6 integer cycles).
2. **Solver Configuration:**
   - Solver: `ode23t` (trapezoidal rule with free interpolation, stiff/moderately stiff, standard for power network transients).
   - Maximum Step Size: $\Delta t_{\text{max}} = 50\,\mu\text{s} = 5 \times 10^{-5}\,\text{s}$ (400 samples/cycle at 50 Hz).
   - Relative Tolerance: $1 \times 10^{-4}$
   - Absolute Tolerance: $1 \times 10^{-5}$

---

## 7. Known Model Limitations & Boundary Conditions
 
1. **Linear Magnetic Circuit:** Transformer saturation, hysteresis, and inrush current dynamics are not modeled in the baseline.
2. **Lumped Transmission Parameter:** Short radial distribution feeders are represented as lumped series R-L impedances; line shunt capacitance and traveling-wave phenomena are omitted.
3. **Idealized Switch Resistance:** Fault blocks use finite transition resistances rather than dynamic electric arc physics.
4. **License Capability:** Models require the `Power_System_Blocks` license feature, which is verified and confirmed active in this release.

---

## 8. Minimal Circuit Prototype (`minimal_circuit_prototype.slx`)

A reproducible, fully functional three-phase prototype model has been implemented and compiled at `simulink/models/minimal_circuit_prototype.slx`.

### Circuit Topology and Connectivity
- **Source:** `Voltage Source (Three-Phase)`
  - Parameter `V_param`: `'11000'` (11 kV line-to-line RMS)
  - Parameter `f_param`: `'50'` (50 Hz fundamental)
- **Sensor:** `Current and Voltage Sensor (Three-Phase)`
  - Input port `LConn1` connected to Source port `RConn1`.
  - Through port `RConn3` connected to Load port `LConn1`.
  - Physical signal voltage port `RConn1` connected to `PS-Simulink Converter` -> Outport `V_abc`.
  - Physical signal current port `RConn2` connected to `PS-Simulink Converter` -> Outport `I_abc`.
- **Load:** `RLC (Three-Phase)`
  - Parameter `component_structure`: `ee.enum.rlc.structure.SeriesRL`
  - Parameter `R_param`: `'10'` (10 $\Omega$ per phase)
  - Parameter `L_param`: `'0.01'` (10 mH per phase, $X \approx 3.1416\,\Omega$ at 50 Hz)
  - Connection: Star configured.
- **Neutral Grounding:**
  - Neutral port `RConn1` connected to `Grounded Neutral (Three-Phase)`.
  - Ground node connected to `Electrical Reference`.
- **Solver Configuration:**
  - `nesl_utility/Solver Configuration` attached to the electrical network.
  - Solver: `ode23t`, $\Delta t_{\text{max}} = 50\,\mu\text{s}$, duration: $0.04\,\text{s}$ (2 cycles at 50 Hz).

### Validated Simulation Output (Audited & Corrected)
- Source internal impedance configured to ideal zero impedance (`impedance_option = '0'`).
- Sensor configured to line-to-ground measurement (`vMeasurementType = 'ee.enum.vmeasurement.lg'`).
- Measured Phase Voltage RMS: $[6353.66, 6349.44, 6349.46]\,\text{V}$ (Expected: $6350.85\,\text{V}$, error $< 0.05\%$).
- Measured Peak Voltage: $8981.46\,\text{V}$ (Expected: $8981.46\,\text{V}$, error **0.00%**).
- Measured Phase Current RMS: $[606.11, 605.91, 605.65]\,\text{A}$ (Expected: $605.89\,\text{A}$, error $< 0.04\%$).
- Measured Peak Current: $857.51\,\text{A}$ (Expected steady-state: $856.86\,\text{A}$, error $< 0.08\%$).

---

## 9. Real Fault-Study Network Implementation (`radial_fault_study_network.slx`)

The full two-voltage-level network is programmatically built and verified at `simulink/models/radial_fault_study_network.slx`.

### Verified Component Parameters
1. **Source:** `Voltage Source (Three-Phase)`
   - $V_{\text{line,rms}} = 33,000\,\text{V}$, $f = 50\,\text{Hz}$, `impedance_option = '0'`.
2. **Source Thevenin Impedance:** `RLC (Three-Phase)`
   - $Z_1 = 0.10\,\text{pu}$ on $33\,\text{kV}, 10\,\text{MVA}$ base $\implies R = 0.1089\,\Omega, L = 34.665\,\text{mH}$.
3. **Transformer T1:** `Two-Winding Transformer (Three-Phase)`
   - Rated Power: $10\,\text{MVA}$, $50\,\text{Hz}$.
   - Rated Voltages: $33\,\text{kV} / 11\,\text{kV}$.
   - Vector Group: Grounded-Wye / Grounded-Wye (`Winding1Connection = Yg`, `Winding2Connection = Yg`).
   - Leakage Reactance: `leakage_reactance_option = 'include'`, $pu\_Xl1 = 0.04, pu\_Xl2 = 0.04$ (Total $Z_1 = 0.08\,\text{pu}$).
   - Winding Resistance: $pu\_Rw1 = 0.002, pu\_Rw2 = 0.002$.
4. **Feeder Section BR_A:** `RLC (Three-Phase)`
   - $Z_1 = 0.05\,\text{pu}$ on $11\,\text{kV}, 10\,\text{MVA}$ base $\implies R = 0.0605\,\Omega, L = 1.9258\,\text{mH}$.
   - Parasitic conductance: `G_parasitic = 1e-6` ($1\,\mu\text{S}$, $1\,\text{M}\Omega$ damping) to break inductive cutsets.
5. **Feeder Section BR_B:** `RLC (Three-Phase)`
   - $Z_1 = 0.05\,\text{pu}$ on $11\,\text{kV}, 10\,\text{MVA}$ base $\implies R = 0.0605\,\Omega, L = 1.9258\,\text{mH}$.
   - Parasitic conductance: `G_parasitic = 1e-6` ($1\,\mu\text{S}$, $1\,\text{M}\Omega$ damping).
6. **Bus A & Bus B Dedicated Sensors:**
   - Bus A: `Phase Voltage Sensor (Three-Phase)` (`V_Sensor_BusA`) tapped to `Grounded Neutral (Three-Phase)`, and `Current Sensor (Three-Phase)` (`I_Sensor_BusA`) in series between Feeder BR_A and Feeder BR_B.
   - Bus B: `Phase Voltage Sensor (Three-Phase)` (`V_Sensor_BusB`) tapped to `Grounded Neutral (Three-Phase)`, and `Current Sensor (Three-Phase)` (`I_Sensor_BusB`) in series into the Bus B load and fault.
7. **Configurable Fault Element:** `Fault (Three-Phase)`
   - Located at Bus B.
   - Configurable fault modes: 3PH (`abc`), SLG (`ag`), LL (`bc`), DLG (`bcg`), and Healthy (timed out at $t = 999.0\,\text{s}$).
   - Fault resistance parameters: phase-neutral $R_{\text{pn\_fault}}$ and neutral-ground $R_{\text{ng\_fault}}$.
   - Temporal switching: inception at $t = 0.05\,\text{s}$.
8. **Solver Configuration:** `nesl_utility/Solver Configuration`
   - Solver: `ode23t`, $\Delta t_{\text{max}} = 50\,\mu\text{s}$, duration: $0.15\,\text{s}$.

### Benchmark Fault Comparison
- **Analytical Fault Current ($Z_f = 0$):**
  $$I_{f,\text{analytical}} = \frac{V_{\text{th}}}{Z_1 + Z_t + Z_{\text{BRA}} + Z_{\text{BRB}}} = \frac{1.0}{0.10 + 0.08 + 0.05 + 0.05} \times 524.8638\,\text{A} = 1874.51\,\text{A}$$
- **Simscape Physical Simulation Result:**
  Fundamental sequence current $I_1 = 1872.22\,\text{A}$ RMS.
- **Agreement:** Absolute error $2.30\,\text{A}$, relative error **0.1225%** ($< 0.5\%$ threshold).

---

## 10. Phase D: Multi-Fault Type Parameterization & Solver DAE Stabilization

### A. Simscape Electrical Native Enum Mapping
The native `ee_lib/Utilities/Fault (Three-Phase)` block is parameterized using class `ee.enum.fault_type_option`:

| Simulation Fault Type | Native Simscape Enum | Physical Conductors Connected | Ground Return Path |
| :--- | :--- | :--- | :--- |
| **3PH** (Three-Phase) | `'ee.enum.fault_type_option.abc'` | A, B, and C tied to common star point | Ungrounded star point |
| **SLG** (Single-Line-Ground) | `'ee.enum.fault_type_option.ag'` | Phase A connected to ground | Direct ground return |
| **LL** (Line-to-Line) | `'ee.enum.fault_type_option.bc'` | Phases B and C tied together | Floating (no ground path) |
| **DLG** (Double-Line-Ground) | `'ee.enum.fault_type_option.bcg'` | Phases B and C tied together and to ground | Direct ground return |
| **HEALTHY** (No Fault) | Inactive temporal fault ($t > t_{\text{stop}}$) | No phase connections closed | Open circuit |

### B. Inductive Cutset DAE Stabilization
When modeling series transmission/distribution feeders in series with transformer leakage reactances, an all-inductor cutset creates an index-2 DAE constraint. In ungrounded-to-grounded transition states (SLG and DLG), Simscape's nonlinear solver iteration matrix becomes singular. Adding `G_parasitic = 1e-6` ($1\,\mu\text{S}$) across the series RL branches provides a high-frequency conductive path, reducing the DAE index to 1 and ensuring robust convergence across all four fault types.



