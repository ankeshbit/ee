# Engineering Assumptions & Modeling Boundaries

This document records the approved engineering assumptions, mathematical conventions, and modeling boundaries governing the power-system fault analysis and protection coordination simulator. All parameters are traceable to [`matlab/config/getSystemMasterConfiguration.m`](../matlab/config/getSystemMasterConfiguration.m).

---

## 1. Network and Per-Unit System

- [x] **Confirm system frequency and nominal phase-to-phase voltage levels:**
  - System nominal frequency is $f_n = 50.0\,\text{Hz}$ ($\omega = 314.159\,\text{rad/s}$).
  - High-voltage (HV) transmission/substation bus: $V_{\text{nominal,HV}} = 33.0\,\text{kV}$ (Line-to-Line RMS).
  - Medium-voltage (LV) distribution feeder buses: $V_{\text{nominal,LV}} = 11.0\,\text{kV}$ (Line-to-Line RMS).
- [x] **Define and approve the system MVA base and voltage bases by voltage level:**
  - System base power: $S_{\text{base}} = 10.0\,\text{MVA}$ ($10^7\,\text{VA}$), common across all voltage zones.
  - HV voltage base: $V_{\text{base,HV}} = 33.0\,\text{kV}$.
  - LV voltage base: $V_{\text{base,LV}} = 11.0\,\text{kV}$.
- [x] **Define how current and impedance bases are derived and converted:**
  - Base current:
    $$I_{\text{base}} = \frac{S_{\text{base}}}{\sqrt{3} \times V_{\text{base}}}$$
    - At 33 kV: $I_{\text{base,HV}} = \frac{10^7}{\sqrt{3} \times 33\,000} \approx 174.9546\,\text{A}$.
    - At 11 kV: $I_{\text{base,LV}} = \frac{10^7}{\sqrt{3} \times 11\,000} \approx 524.8638\,\text{A}$.
  - Base impedance:
    $$Z_{\text{base}} = \frac{V_{\text{base}}^2}{S_{\text{base}}}$$
    - At 33 kV: $Z_{\text{base,HV}} = \frac{33\,000^2}{10^7} = 108.9\,\Omega$.
    - At 11 kV: $Z_{\text{base,LV}} = \frac{11\,000^2}{10^7} = 12.1\,\Omega$.
  - Conversions across bases follow standard per-unit formulas in [`convertPuImpedanceBase.m`](../matlab/network/convertPuImpedanceBase.m).
- [x] **Define the reference bus, phase sequence, and angle convention:**
  - Phase sequence is standard positive A-B-C with $120^\circ$ counterclockwise rotation:
    $$a = e^{j 2\pi / 3} = -\frac{1}{2} + j \frac{\sqrt{3}}{2}$$
  - The source bus (`SOURCE_33KV` or `BUS_A`) serves as the slack/thevenin reference with pre-fault internal phase-to-neutral EMF $E_a = 1.0\angle 0^\circ\,\text{pu}$.
- [x] **Confirm whether network data is entered in physical units, per-unit values, or both:**
  - Both: Single master configuration struct ([`matlab/config/getSystemMasterConfiguration.m`](../matlab/config/getSystemMasterConfiguration.m)) stores authoritative per-unit parameters alongside exact physical SI values (ohms, henries, amperes, volts) and explicit `provenance` metadata.
- [x] **Define data precision, rounding, and significant-figure conventions:**
  - All numerical calculations use double-precision IEEE 754 floating-point format.
  - Zero-impedance singularity protections enforce magnitude check $> \text{eps} \approx 2.22 \times 10^{-16}$.
  - Analytical unit tests enforce relative tolerance $\le 10^{-4}$ against independent textbook derivations.
  - Dynamic Simscape time-domain comparisons enforce $\le 2.0\%$ relative error on currents and $\pm 10.0\,\text{ms}$ on relay timing.

---

## 2. Sequence Networks and Fault Studies

- [x] **Verify positive-, negative-, and zero-sequence impedances for each network element:**
  - Source Grid: $Z_1 = Z_2 = 0.10\,\text{pu}$, $Z_0 = 0.10\,\text{pu}$ (on 10 MVA, 33 kV base).
  - Transformer T1: $Z_1 = Z_2 = Z_0 = 0.08\,\text{pu}$ (on 10 MVA, 33/11 kV base).
  - Feeder BRA (11 kV): $Z_1 = Z_2 = 0.05\,\text{pu}$, $Z_0 = 0.15\,\text{pu}$ ($R = 0.0605\,\Omega, L = 1.926\,\text{mH}$).
  - Feeder BRB (11 kV): $Z_1 = Z_2 = 0.05\,\text{pu}$, $Z_0 = 0.15\,\text{pu}$ ($R = 0.0605\,\Omega, L = 1.926\,\text{mH}$).
- [x] **Confirm mutual coupling assumptions and whether they are neglected:**
  - Zero-sequence mutual inductive coupling between adjacent parallel three-phase feeders is neglected; feeders are treated as uncoupled single circuits.
- [x] **Confirm source grounding and zero-sequence return-path assumptions:**
  - 33 kV source grid neutral is solidly grounded with return path through earth impedance included in $Z_0$.
- [x] **Define the fault impedance model and any prefault voltage assumptions:**
  - Prefault voltage is $1.0\angle 0^\circ\,\text{pu}$ balanced positive sequence.
  - Fault impedance conventions:
    - **3PH:** $Z_f$ in series with positive sequence: $I_1 = V_{\text{th}} / (Z_1 + Z_f)$.
    - **SLG (Phase A):** $3 Z_f$ in series sequence loop: $I_a = 3 V_{\text{th}} / (Z_1 + Z_2 + Z_0 + 3Z_f)$.
    - **LL (Phases B-C):** $Z_f$ connected directly between phases B and C: $I_1 = V_{\text{th}} / (Z_1 + Z_2 + Z_f)$.
    - **DLG (Phases B-C-G):** $Z_f$ in each branch to ground, giving $Z_g = Z_0 + 3Z_f$ in parallel with $Z_2$.
- [x] **Define the fault types and fault-location representation to be supported:**
  - Supports 3PH, SLG, LL, DLG, and Healthy steady-state modes applied at any designated bus.

---

## 3. Transformers

- [x] **Verify transformer ratings, impedance bases, and tap settings:**
  - Rating: 10.0 MVA, 33/11 kV step-down, continuous rating. Fixed nominal tap ratio (1:1 per-unit transformation).
- [x] **Confirm winding configuration and grounding:**
  - Default network uses `grounded-wye-grounded-wye` with both neutrals solidly grounded.
  - Alternative `delta-grounded-wye` configuration is supported and tested for zero-sequence isolation.
- [x] **Confirm zero-sequence transfer behavior through each transformer:**
  - Grounded-wye / grounded-wye transfers zero-sequence current through transformer neutral paths.
  - Delta / grounded-wye transformer zero-sequence transfer and grounded-wye zero-sequence source behavior across boundaries are currently unsupported in the analytical solver; SLG/DLG studies across that boundary trigger `runIntegratedFaultStudy:BlockedZeroSequence`.
- [x] **Document phase-shift conventions and the reference used for vector groups:**
  - Yg/Yg produces $0^\circ$ phase displacement between HV and LV line voltages.
  - Delta-wye sequence phase shift ($\pm 30^\circ$) and resulting unbalanced fault line currents across the boundary (e.g., $2 I_1$ peak phase current during LL faults) are unmodeled; unbalanced fault studies across delta-wye boundaries with HV-side relays trigger `runIntegratedFaultStudy:UnsupportedTransformerPhaseShift`.
- [x] **Confirm treatment of off-nominal taps and phase-shifting transformers:**
  - Off-nominal tap changers and phase-shifting transformers are unsupported in this milestone.

---

## 4. Protection and Switching

- [x] **Verify relay input quantities, CT/VT ratios, polarity, and measurement locations:**
  - `RELAY_BUS_B`: Primary feeder protection, CT 400/5 A ($N = 80$), pickup $1.0\,\text{A-sec}$ ($80\,\text{A}$ primary), $\text{TMS} = 0.10$.
  - `RELAY_BUS_A`: Feeder backup protection, CT 600/5 A ($N = 120$), pickup $1.0\,\text{A-sec}$ ($120\,\text{A}$ primary), $\text{TMS} = 0.25$.
  - `RELAY_33KV`: Incomer protection, CT 200/5 A ($N = 40$), pickup $1.5\,\text{A-sec}$ ($60\,\text{A}$ primary), $\text{TMS} = 0.40$.
- [x] **Define the ideal relay equations, characteristic curves, pickup settings, time-dial settings, and units:**
  - Standard IEC 60255-151 inverse-time equation:
    $$t = \text{TMS} \times \frac{k}{\left(\frac{I_{\text{relay}}}{I_{\text{pickup}}}\right)^\alpha - 1}$$
    - Standard Inverse (SI): $k = 0.14, \alpha = 0.02$.
    - Very Inverse (VI): $k = 13.5, \alpha = 1.0$.
    - Extremely Inverse (EI): $k = 80.0, \alpha = 2.0$.
- [x] **Define breaker logic, interrupting delay, failure behavior, and reclosing assumptions:**
  - Breaker contact opening delay is modeled as a deterministic post-trip delay:
    - Primary breaker `CB_BUS_B`: $50\,\text{ms}$.
    - Backup breaker `CB_BUS_A`: $60\,\text{ms}$.
    - Incomer breaker `CB_33KV`: $80\,\text{ms}$.
  - Current interruption occurs at the subsequent natural current zero-crossing.
  - Auto-reclosing is not modeled.
- [x] **Define coordination objectives, grading margins, and selectivity criteria:**
  - Coordination Time Interval (CTI) requirement: $\text{CTI} = t_{\text{backup}} - t_{\text{primary}} \ge 250\,\text{ms}$.
  - Actual modeled CTI under 3PH fault: $0.5466\,\text{s} - 0.2125\,\text{s} = 334.1\,\text{ms}$ (meets criteria).
- [x] **Identify any vendor-specific behavior that must not be approximated without evidence:**
  - Vendor-proprietary digital filtering, microprocessor dead-bands, and proprietary trip logic are excluded in favor of standard IEC 60255 open standards.
- [x] **Document Bus A protection coverage and breaker-failure behavior:**
  - Bus A is situated between Feeder BRA and Feeder BRB. Because `RELAY_BUS_A` measures outgoing current on `FEEDER_BRB` (from side towards Bus B), faults on Bus A produce no current in `FEEDER_BRB`.
  - Bus A faults (`ZONE_FEEDER_BRA`) are cleared exclusively by the upstream incomer relay `RELAY_33KV` (operating at approximately 1.07 s for 3PH bolted faults, tripping incomer breaker `CB_33KV` and de-energizing the whole transformer).
  - The breaker-failure scenario for `CB_33KV` during a Bus A fault has no further upstream modeled backup protection (`NO_BACKUP_PROTECTION`).

---

## 5. Software and Simulation Environment

- [x] **Record the MATLAB release used for each validation run:** MATLAB Version 26.2.0.3386108 (R2026b).
- [x] **Verify availability and license status for Simulink, Simscape, and Simscape Electrical:**
  - MATLAB: Licensed.
  - Simulink: Licensed.
  - Simscape: Licensed.
  - Simscape Electrical / Specialized Power Systems (`Power_System_Blocks`): Licensed and active.
- [x] **Confirm supported model configuration and solver choices:**
  - Dynamic simulation uses `radial_fault_study_network.slx`.
  - Integrator: variable-step stiff solver `ode23tb` (TR-BDF2) with max step $1.0\,\text{ms}$, relative tolerance $10^{-4}$.
- [x] **Define simulation stop time, fault insertion time, and steady-state window:**
  - Simulation stop time: $0.60\,\text{s}$ (extended to $0.85\,\text{s}$ for breaker failure backup clearing).
  - Fault inception time: $t = 0.05\,\text{s}$.
  - Fundamental phasor extraction window: $t = 0.07\,\text{s}$ to $0.15\,\text{s}$ (integer fundamental cycles).
- [x] **Define numerical comparison tolerances:**
  - Current magnitude relative error: $\le 2.0\%$ (actual measured $< 0.10\%$).
  - Relay trip timing error: $\pm 10.0\,\text{ms}$ (actual measured $[-2.1\,\text{ms}, +4.5\,\text{ms}]$).
  - Post-clearing current extinction peak: $< 0.010\,\text{A}$.
- [x] **Record all assumptions and deviations in version-controlled documentation:** Fully maintained under Git revision control.
