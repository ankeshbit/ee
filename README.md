# Power System Fault Analysis & Protection Coordination Simulator

## 1. Executive Summary

This repository contains a fully validated, production-grade MATLAB, Simulink, and Simscape Electrical simulation platform for power-system fault analysis, symmetrical-component verification, and protection coordination.

The platform couples:
1. **MATLAB Analytical Engine:** Symmetrical sequence-network calculations for 3PH, SLG, LL, and DLG faults, per-unit base transformations, transformer zero-sequence blocking rules, IEC 60255-151 inverse-time overcurrent curves, and protection selectivity/coordination analysis.
2. **Simscape Electrical Physical Engine:** Native time-domain dynamic solver (`radial_fault_study_network.slx`) modeling an illustrative 33/11 kV distribution system with source impedance, grounded-wye/grounded-wye transformer leakage inductance, distribution feeder sections, physical circuit breakers, and interactive relay trip logic.
3. **Single Authoritative Master Configuration:** Single-source configuration ([`matlab/config/getSystemMasterConfiguration.m`](matlab/config/getSystemMasterConfiguration.m)) providing strict parameter parity across analytical solvers, model builders, and validation reports.
4. **Comprehensive Test Suite:** 243 automated unit and integration tests (242 passed, 1 filtered by license assumption for non-Simscape headless environments), executing cleanly via `scripts/run_all_tests.m`.

---

## 2. System Architecture & Capabilities

```text
ee/
├── docs/                                   # Architectural specifications, validation plans, and derivations
│   ├── textbook_reference_derivations.md   # Independent hand-calculated sequence benchmarks
│   ├── reference_fault_study_report.md     # Reference validation report (MATLAB R2026b)
│   ├── how-to-reproduce.md                 # Exact commands to build, test, and study
│   ├── validation-plan.md                  # Acceptance criteria and tolerance rationale
│   └── assumptions.md                      # Engineering checklist and modeling boundaries
├── matlab/
│   ├── config/                             # Authoritative single-source system master configuration
│   ├── analysis/                           # Symmetrical components, dynamic simulation runners, phasors
│   ├── faults/                             # 3PH, SLG, LL, DLG sequence network solvers
│   ├── network/                            # Network builders, per-unit base conversions
│   ├── protection/                         # IEC inverse curves, CTI checks, breaker failure, CT screening
│   ├── plots/                              # Automated publication-grade waveform plotting
│   └── reports/                            # Dynamic report generation (HTML, CSV, MAT, TXT)
├── simulink/
│   └── models/                             # Dynamic physical models (radial_fault_study_network.slx)
├── tests/
│   ├── unit/                               # Unit test suites (textbook parity, conventions, protection)
│   └── integration/                        # Physical Simscape and end-to-end integration tests
└── scripts/                                # Batch runners, study automation, and test drivers
```

---

## 3. Real Validation Results (Copied from Reference Fault Study)

The following tables summarize the real validation metrics generated from [`scripts/run_complete_fault_study.m`](scripts/run_complete_fault_study.m) on MATLAB R2026b:

### A. Steady-State Fault Currents (Faulted Bus B, 11 kV, 100 MVA Base)

| Scenario | Fault Type | Quantity Basis | Analytical Current | Simscape Current | Absolute Error | True Percent Error | Acceptance Limit | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PF_HEALTHY` | Healthy | Load Phase RMS | 74.97 A | 74.97 A | 0.00 A | 0.00% | $\pm 1.0\%$ | **PASS** |
| `PF_3PH` | 3PH Bolted | $I_1$ (Positive Seq) | 1874.0 A | 1872.2 A | -1.8 A | -0.10% | $\pm 2.0\%$ | **PASS** |
| `PF_3PH` | 3PH Bolted | $I_{\text{max}}$ (Phase RMS) | 1886.2 A | 1884.5 A | -1.7 A | -0.09% | $\pm 2.0\%$ | **PASS** |
| `PF_SLG` | SLG Phase A | $I_1$ (Positive Seq) | 504.6 A | 504.9 A | +0.3 A | +0.06% | $\pm 2.0\%$ | **PASS** |
| `PF_SLG` | SLG Phase A | $I_{\text{max}}$ (Phase RMS) | 1947.1 A | 1946.0 A | -1.1 A | -0.06% | $\pm 2.0\%$ | **PASS** |
| `PF_LL` | LL (B-C) | $I_1$ (Positive Seq) | 937.0 A | 936.4 A | -0.6 A | -0.06% | $\pm 2.0\%$ | **PASS** |
| `PF_LL` | LL (B-C) | $I_{\text{max}}$ (Phase RMS) | 1647.2 A | 1646.1 A | -1.1 A | -0.07% | $\pm 2.0\%$ | **PASS** |
| `PF_DLG` | DLG (B-C-G)| $I_1$ (Positive Seq) | 1249.3 A | 1248.5 A | -0.8 A | -0.06% | $\pm 2.0\%$ | **PASS** |
| `PF_DLG` | DLG (B-C-G)| $I_{\text{max}}$ (Phase RMS) | 1927.6 A | 1926.2 A | -1.4 A | -0.07% | $\pm 2.0\%$ | **PASS** |

*All four fault types demonstrate $<0.15\%$ error between sequence network formulas and native Simscape non-linear dynamic simulation.*

### B. Dynamic Relay Timing & Breaker Switching (IEC Standard Inverse, TMS = 0.10, Pickup = 80 A primary)

| Scenario | Fault Type | $I_{\text{max}}$ (A) | Analytical Trip ($t_{\text{ana}}$) | Simscape Trip ($t_{\text{sim}}$) | Timing Error ($\Delta t$) | Breaker Open Time | Extinction Time | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PF_3PH` | 3PH | 1886.2 A | 0.2146 s | 0.2125 s | -2.1 ms | 0.2625 s | 0.3225 s | **PASS** |
| `PF_SLG` | SLG | 1947.1 A | 0.2124 s | 0.2114 s | -0.9 ms | 0.2614 s | 0.3214 s | **PASS** |
| `PF_LL` | LL | 1647.2 A | 0.2245 s | 0.2290 s | +4.5 ms | 0.2790 s | 0.3390 s | **PASS** |
| `PF_DLG` | DLG | 1927.6 A | 0.2131 s | 0.2150 s | +2.0 ms | 0.2650 s | 0.3251 s | **PASS** |
| `PF_HEALTHY` | Healthy | 74.97 A | No Trip | No Trip | 0.0 ms | N/A | N/A | **PASS** |
| `PF_3PH_CBF` | 3PH (CBF) | 1886.2 A | 0.5489 s | 0.5466 s | -2.3 ms | 0.6066 s | 0.7466 s | **PASS** |

*All measured timing errors fall strictly within $[-2.1\,\text{ms}, +4.5\,\text{ms}]$, meeting the tightened $\pm 10.0\,\text{ms}$ engineering tolerance band.*

### C. Protection Coordination & Backup Performance
- **Coordination Time Interval (CTI):** Primary relay trips at $0.2125\,\text{s}$; backup relay trips at $0.5466\,\text{s}$. $\text{CTI} = 0.3341\,\text{s}$ ($334.1\,\text{ms}$), comfortably exceeding the $250\,\text{ms}$ grading margin.
- **Breaker Failure Performance:** When primary breaker `CB_BUS_B` fails to open, backup relay `RELAY_BUS_A` detects sustained fault overcurrent and trips backup breaker `CB_BUS_A` at $t = 0.6066\,\text{s}$.
- **Galvanic Fault Isolation:** Post-clearing current extinction confirms peak current $<0.010\,\text{A}$ ($0.0090\,\text{A}$ observed).

---

## 4. How to Run & Reproduce

All operations are automated and executable directly from the shell or MATLAB command window:

```bash
# 1. Run complete automated regression test suite (243 tests)
matlab -batch "run('scripts/run_all_tests.m')"

# 2. Rebuild physical Simscape models from source configuration
matlab -batch "run('scripts/build_radial_fault_model.m')"

# 3. Execute complete fault study and generate HTML/CSV/TXT reports and plots
matlab -batch "run('scripts/run_complete_fault_study.m')"

# 4. Generate Phase F dynamic relay switching report
matlab -batch "run('scripts/phase_f_validation_report.m')"
```

For detailed options and reproducing reference outputs, see [docs/how-to-reproduce.md](docs/how-to-reproduce.md).

---

## 5. Explicit Engineering Limitations

This simulator is designed for engineering research, software verification, and protection education. The following physical limitations apply:

1. **Illustrative Radial Topology:** Network configurations are single-source radial topologies. Meshed transmission grids and distributed generation back-feeds are not modeled.
2. **Ideal Current Transformers:** CTs are modeled with ideal linear ratio scaling ($I_{\text{sec}} = I_{\text{pri}} / N_{\text{CT}}$). Core magnetic saturation, hysteresis, remanence, burden impedance, and secondary circuit winding resistances are screened analytically via thresholds but not simulated as non-linear differential equations.
3. **Balanced Infinite Source:** The grid Thevenin equivalent assumes constant balanced prefault source voltages without voltage unbalance or background harmonics.
4. **No Arc or TRV Physics:** Breakers interrupt at current zero crossings without modeling dynamic arc resistance, arc reignition, or Transient Recovery Voltage (TRV) oscillations.
5. **Zero Mutual Coupling:** Zero-sequence mutual coupling between adjacent parallel lines is neglected.
6. **No DC-Offset Saturation:** Asymmetrical DC decaying offset is evaluated via Fourier filtering; DC-offset saturation of magnetic cores is not modeled.
