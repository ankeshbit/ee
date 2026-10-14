# Phase G — Automated Fault Study, Visualization, Validation & Reporting Methodology

## 1. Overview & Architecture

Phase G integrates the analytical sequence-network fault calculation engine, the native Simscape Electrical radial distribution model (`radial_fault_study_network.slx`), dynamic inverse-time protective relays, and physical circuit-breaker switching into a single reproducible, automated study workflow:

```
+-------------------------------------------------------------------------------+
|                       run_complete_fault_study.m                              |
+-------------------------------------------------------------------------------+
         |                                           |
         v                                           v
[Analytical Engine]                         [Simscape Electrical Model]
• Symmetrical Sequence Components           • 33 kV Thevenin Grid (10 MVA, 50 Hz)
• 3PH, SLG, LL, DLG Faults                  • Yg/Yg 10 MVA 33/11 kV Transformer
• Bus B (11 kV) Fault Impedance             • Physical Feeders BRA & BRB
• Per-Unit & Physical Currents              • Dynamic Overcurrent Relays A & B
                                            • Three-Phase Physical Circuit Breakers
         |                                           |
         +--------------------+----------------------+
                              |
                              v
                  [collectFaultStudyResults.m]
                  • Structured comparison tables
                  • Dynamic timing cross-validation
                  • Acceptance criteria evaluation (14 checks)
                              |
              +---------------+---------------+
              |                               |
              v                               v
    [Automated Visualizations]      [Consolidated Reports]
    • results/plots/*.png, *.fig    • results/reports/fault_study_report.html
    • Waveforms (Current & Voltage) • results/reports/fault_study_summary.csv
    • Relay sigma & Breaker state   • results/reports/fault_study_summary.mat
    • Bar charts with error %       • results/reports/fault_study_report.txt
```

---

## 2. Measurement & Extraction Methodology

### 2.1 Waveform Sampling & Extraction
Simulations are executed in Simulink/Simscape Electrical using variable-step solvers (e.g. `daessc`) with strict numerical tolerances (`RelTol = 1e-4`, `MaxStep = 5e-5 s`). All electrical measurements are logged via physical Simscape Phase Voltage Sensors and Current Sensors connected to Root-Level Outport blocks:
- `Port 1`: $V_{\text{BusA}}$ (Three-phase voltage at Bus A, $V$)
- `Port 2`: $I_{\text{BusA}}$ (Three-phase line current entering Feeder BRB, $A$)
- `Port 3`: $V_{\text{BusB}}$ (Three-phase voltage at Bus B, $V$)
- `Port 4`: $I_{\text{BusB}}$ (Three-phase line current entering the faulted section, $A$)
- `Port 5-6`: Trip command and breaker contact state for Relay B / CB_BUS_B
- `Port 7-8`: Trip command and breaker contact state for Relay A / CB_BUS_A
- `Port 9-10`: Operating time accumulator integrals $\sigma_B$ and $\sigma_A$ ($\int \frac{1}{t(I)} dt$)

### 2.2 Fundamental & Phase RMS Computation
- **Continuous Phase RMS:** Evaluated dynamically using a moving-window RMS over one fundamental period ($T = 0.02\,\text{s}$ at $50\,\text{Hz}$).
- **Maximum Phase RMS ($I_{\max}$):** Extracted across all three phases ($a, b, c$) in steady state during the fault interval prior to breaker contact separation:
  $$I_{\max} = \max_{t \in [t_{\text{fault}} + T, t_{\text{trip}}]} \left( \max(I_{a,\text{RMS}}(t), I_{b,\text{RMS}}(t), I_{c,\text{RMS}}(t)) \right)$$

---

## 3. Analytical vs. Simulated Comparison Conventions

### 3.1 Basis Distinctions
Protective relays in substations utilize current transformers (CTs) installed on individual physical phases. Consequently, an inverse-time overcurrent element trips according to the maximum current sensed in any single phase ($I_{\max}$).
- **Balanced Fault (3PH):** $I_a = I_b = I_c = I_1$. The analytical positive-sequence fault current matches the physical phase current exactly ($< 0.7\%$ difference due to load and transformer resistance).
- **Single-Line-to-Ground (SLG):** Analytical fault current through the fault is $I_f = 3 I_1$. The faulted phase line current is much higher than positive sequence component $I_1$. The relay timing calculation uses $I_{\max}$ (the physical phase current sensed by the CT).
- **Line-to-Line (LL):** Line-to-line current is $I_{bc} = \sqrt{3} I_1$. Sensed phase current is $\sqrt{3} \times$ larger than $I_1$.
- **Double-Line-to-Ground (DLG):** Ground return current produces unequal phase currents where $I_{\max} > I_1$.

Both comparison bases are formally reported in the structured study outputs:
- **Part A (Phase Element Basis):** Validates relay operating time using $I_{\max}$, achieving agreement within $\pm 4.5\,\text{ms}$ across all fault types.
- **Part B (Symmetrical Component Basis):** Validates positive-sequence sequence-network equations against fundamental phasor extraction.

---

## 4. Relay Operating Time & Coordination

### 4.1 IEC Standard Inverse Characteristic
Operating time is determined by the standard IEC 60255-151 curve:
$$t_{\text{op}} = \frac{0.14 \times \text{TMS}}{M^{0.02} - 1}$$
where:
$$M = \frac{I_{\text{secondary}}}{I_{\text{pickup}}} = \frac{I_{\text{primary}} \times (N_s / N_p)}{I_{\text{pickup}}}$$

### 4.2 Relay Settings
- **Relay B (Downstream Feeder / Bus B):** CT = 400/5 A (Ratio 80), $I_{\text{pickup}} = 1.0\,\text{A sec}$ ($80\,\text{A primary}$), $\text{TMS} = 0.10$. Breaker delay = $50\,\text{ms}$.
- **Relay A (Bus A Substation Backup):** CT = 600/5 A (Ratio 120), $I_{\text{pickup}} = 1.0\,\text{A sec}$ ($120\,\text{A primary}$), $\text{TMS} = 0.25$. Breaker delay = $60\,\text{ms}$.
- **Relay 33 kV (Remote Incomer Backup):** CT = 200/5 A (Ratio 40), $I_{\text{pickup}} = 1.5\,\text{A sec}$ ($60\,\text{A pri}$ at $33\,\text{kV} = 180\,\text{A}$ at $11\,\text{kV}$), $\text{TMS} = 0.40$. Breaker delay = $80\,\text{ms}$.

### 4.3 Coordination Margins
- **Coordination Time Interval (CTI):** Relay-to-relay operating time difference:
  $$\text{CTI} = t_{\text{op,backup}} - t_{\text{op,primary}}$$
  Criteria: $\text{CTI} \ge 0.250\,\text{s}$. Actual Bus B to Bus A CTI: $0.6194 - 0.2150 = 0.4044\,\text{s}$ (PASS).
- **Clearing-Time Margin:** Backup relay operating time minus primary total clearing time:
  $$\text{Margin} = t_{\text{op,backup}} - (t_{\text{op,primary}} + t_{\text{breaker,primary}})$$
  Actual Margin: $0.6194 - (0.2150 + 0.050) = 0.3544\,\text{s} \ge 0.200\,\text{s}$ (PASS).

---

## 5. Fault Clearing & Current Extinction

Current extinction is verified programmatically after breaker opening:
1. Contact separation begins at $t_{\text{open}} = t_{\text{trip}} + t_{\text{breaker delay}}$.
2. Extinction time $t_{\text{extinct}}$ is recorded when the post-clearing fundamental and instantaneous currents drop below the extinction threshold ($0.010\,\text{A}$).
3. In all physical simulations, post-clearing residual current drops to $0.0090\,\text{A}$, confirming successful clearing.

---

## 6. Known Limitations

1. **Directional Supervision:** Directional supervision logic is evaluated analytically via voltage/current phasor angles. Real-time dynamic directional supervision blocks are not included in the Simulink model.
2. **Arc Modeling:** Breakers are modeled with physical transition resistances ($R_{\text{closed}} = 10^{-4}\,\Omega$, $R_{\text{open}} = 10^6\,\Omega$) without high-frequency transient recovery voltage (TRV) or arc-reignition physics.
3. **Breaker-Failure Scenario Scope:** Dynamic breaker failure (CB_BUS_B stuck closed with backup trip of CB_BUS_A) is validated dynamically for the three-phase fault scenario (`PF_3PH_CBF`). Other fault types utilize analytical backup clearing estimates.
