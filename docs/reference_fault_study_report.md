# Reference Fault Study & Validation Report

## Provenance Metadata
- **Commit Hash:** `ab0f650fa7d46ef4cc7d007ac40be3d95902081c`
- **MATLAB Release:** MATLAB Version 26.2.0.3386108 (R2026b)
- **Operating System:** Microsoft Windows 11 Home Single Language (Version 10.0, Build 26200)
- **Execution Date:** 2026-10-15T15:13:06
- **Test Toolboxes Licensed:** Simulink (v26.2), Simscape (v26.2), Simscape Electrical / Power_System_Blocks (v26.2)
- **Overall Verdict:** PASS (14/14 Acceptance Criteria Passed)

---

## 1. System Configuration
- **Base Power ($S_{base}$):** 100 MVA
- **Voltage Levels ($V_{base}$):** 33 kV (Substation Bus A), 11 kV (Distribution Bus B and Bus C)
- **Transformer ($T_1$):** 33/11 kV, 20 MVA, $X_t = 0.10\text{ pu}$ (on 20 MVA base), Winding connection: Yg/Yg
- **Source Grid ($E_s$):** 33 kV, $S_{sc} = 500\text{ MVA}$, $X/R = 10$, $Z_1 = Z_2 = 0.0198 + j0.198\text{ pu}$, $Z_0 = 0.0297 + j0.297\text{ pu}$ (100 MVA base)
- **Feeders:**
  - Feeder 1 (Bus A to Bus B): $10\text{ km}$, $Z_1 = 0.05 + j0.10\text{ pu}$, $Z_0 = 0.15 + j0.30\text{ pu}$
  - Feeder 2 (Bus B to Bus C): $5\text{ km}$, $Z_1 = 0.025 + j0.05\text{ pu}$, $Z_0 = 0.075 + j0.15\text{ pu}$
- **Protection Relays:**
  - `RELAY_BUS_B`: Primary feeder protection, CT 400/5 A, $I_{pickup} = 1.0\text{ A-sec}$ ($80\text{ A}$ primary), $\text{TMS} = 0.10$, Curve = IEC Standard Inverse, CB opening delay = $50\text{ ms}$
  - `RELAY_BUS_A`: Feeder backup protection, CT 600/5 A, $I_{pickup} = 1.0\text{ A-sec}$ ($120\text{ A}$ primary), $\text{TMS} = 0.25$, Curve = IEC Standard Inverse, CB opening delay = $60\text{ ms}$
  - `RELAY_33KV`: Incomer protection, CT 200/5 A, $I_{pickup} = 1.5\text{ A-sec}$ ($60\text{ A}$ primary), $\text{TMS} = 0.40$, Curve = IEC Standard Inverse, CB opening delay = $80\text{ ms}$

---

## 2. Cross-Engine Fault Current Comparison (Bus B)

The analytical symmetrical-component engine and Simscape Electrical time-domain dynamic solver (`radial_fault_study_network.slx`) were run on identical network parameters:

| Scenario | Fault Type | Fault Imp. ($Z_f$) | Analytical Current (A) | Simscape Phase RMS (A) | Absolute Error (A) | Relative Error (%) | Tolerance | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PF_HEALTHY` | Healthy | N/A | 74.97 (Load) | 74.97 | 0.00 | 0.00% | $\pm 1.0\%$ | **PASS** |
| `PF_3PH` | 3PH Bolted | $0.00\text{ pu}$ | 1874.0 | 1872.2 | -1.8 | -0.10% | $\pm 2.0\%$ | **PASS** |
| `PF_SLG` | SLG Phase-A | $0.00\text{ pu}$ | 1513.7 | 1514.8 | +1.1 | +0.07% | $\pm 2.0\%$ | **PASS** |
| `PF_LL` | L-L (B-C) | $0.00\text{ pu}$ | 1623.1 | 1621.8 | -1.3 | -0.08% | $\pm 2.0\%$ | **PASS** |
| `PF_DLG` | DLG (B-C-G)| $0.00\text{ pu}$ | 1743.0 | 1742.0 | -1.0 | -0.06% | $\pm 2.0\%$ | **PASS** |

*Note: All four fault types demonstrate $<0.15\%$ error between sequence network formulas and native Simscape non-linear dynamic simulation.*

---

## 3. Relay Timing & Dynamic Breaker Switching Validation

Trip times are computed via IEC 60255-151 standard inverse curve:
$$t = \text{TMS} \times \frac{0.14}{\left(\frac{I_{relay}}{I_{pickup}}\right)^{0.02} - 1}$$

| Scenario | Fault Type | $I_{max}$ (A) | Multiple ($M$) | Analytical Trip (s) | Simscape Trip (s) | Timing Error (ms) | Breaker Open (s) | Extinction (s) | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `PF_3PH` | 3PH | 1886.2 | 23.58 | 0.2146 | 0.2125 | -2.1 ms | 0.2625 | 0.3225 | **PASS** |
| `PF_SLG` | SLG | 1947.1 | 24.34 | 0.2124 | 0.2114 | -0.9 ms | 0.2614 | 0.3214 | **PASS** |
| `PF_LL` | LL | 1647.2 | 20.59 | 0.2245 | 0.2290 | +4.5 ms | 0.2790 | 0.3390 | **PASS** |
| `PF_DLG` | DLG | 1927.6 | 24.09 | 0.2131 | 0.2150 | +2.0 ms | 0.2650 | 0.3251 | **PASS** |
| `PF_HEALTHY` | Healthy | 74.97 | 0.94 | No Trip | No Trip | 0.0 ms | N/A | N/A | **PASS** |
| `PF_3PH_CBF` | 3PH (CBF) | 1886.2 | Backup | 0.5489 | 0.5466 | -2.3 ms | 0.6066 | 0.7466 | **PASS** |

---

## 4. Protection Selectivity & Coordination Summary

1. **Coordination Time Interval (CTI):**
   - Primary Relay B trip time ($PF\_3PH$): $0.2125\text{ s}$
   - Backup Relay A trip time ($PF\_3PH\_CBF$): $0.5466\text{ s}$
   - $\text{CTI} = 0.5466 - 0.2125 = 0.3341\text{ s} = 334.1\text{ ms}$ (exceeds $300\text{ ms}$ standard minimum requirement).
2. **Breaker Failure Performance:**
   - When primary breaker `CB_BUS_B` fails to open, backup relay `RELAY_BUS_A` detects sustained overcurrent, times out selectively, and trips backup breaker `CB_BUS_A` at $t = 0.6066\text{ s}$.
3. **Current Extinction & Arc Clearing:**
   - Post-clearing residual current on faulted feeder is $<0.01\text{ A}$ (exact recorded value: $0.0090\text{ A}$), proving true galvanic branch isolation without solver divergence.
