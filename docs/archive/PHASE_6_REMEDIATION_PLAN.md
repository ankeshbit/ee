# Phase 6 Remediation Plan: Complete Engineering Corrections & Validation

**Date:** November 1, 2026  
**Repository:** [https://github.com/ankeshbit/ee](https://github.com/ankeshbit/ee)  
**Project:** Power System Fault Analysis & Protection Coordination Simulator  
**Baseline Commit:** `8d7b209db1e37d50b91fb8e7c76f1075ea4398ad`  
**Execution Environment:** MATLAB R2026b, Simulink 26.2, Simscape 26.2  

---

## 1. Objectives & Engineering Principles

The objective of Phase 6 is to perform a rigorous, evidence-driven remediation across the analytical engine, physical Simulink/Simscape model, ANSI protection modules, test suite, and engineering documentation.

### Core Engineering Principles
1. **Zero Fabrication:** Never synthesize or fabricate physical waveforms or simulation outputs. If execution cannot proceed due to missing licenses or missing blocks, report `BLOCKED` or `UNSUPPORTED`.
2. **Explicit Validation & Rejection:** Never silently fall back to default values or alternate fault locations. Reject invalid inputs with clear error identifiers.
3. **Model & Documentation Parity:** The single authoritative transformer configuration is **Ynyn0** (grounded-wye / grounded-wye with solidly grounded neutrals). Analytical models, physical Simulink models, and documentation must agree completely.
4. **License-Blocked Integrity:** Missing Simscape Electrical licenses must be clearly identified and reported as incomplete, never as a passed simulation.
5. **No Regression:** Preserve all 349 existing passing tests while adding comprehensive new regression tests for all resolved defects.

---

## 2. Phase-by-Phase Remediation Roadmap

### Phase 1: Dynamic Simulation Backend Corrections
- **Target Files:**
  - [`matlab/analysis/runDynamicFaultSimulation.m`](../../matlab/analysis/runDynamicFaultSimulation.m)
  - [`scripts/build_radial_fault_model.m`](../../scripts/build_radial_fault_model.m)
  - [`matlab/analysis/runDynamicBreakerSwitchingSimulation.m`](../../matlab/analysis/runDynamicBreakerSwitchingSimulation.m)
- **Remediation Actions:**
  1. **Dual-Location Fault Support:** In `scripts/build_radial_fault_model.m`, instantiate both `Fault_BusB` and `Fault_BusA`. Connect `Fault_BusA` to the 11 kV Bus A terminal. By default, both fault blocks are disabled (fault start time = 999.0 s).
  2. **Scenario Fault-Location Dispatch:** In `runDynamicFaultSimulation.m`:
     - Inspect `scenario.faultedBus`.
     - Validate that `scenario.faultedBus` exists in `network.buses`.
     - Check physical model capability:
       - If `scenario.faultedBus == 'BUS_B'`, activate `Fault_BusB` with scenario parameters, ensure `Fault_BusA` is disabled.
       - If `scenario.faultedBus == 'BUS_A'`, activate `Fault_BusA` with scenario parameters, ensure `Fault_BusB` is disabled.
       - If any other bus is requested (e.g. `SOURCE_33KV`, `BUS_C`), return `simResult.status = 'UNSUPPORTED'` and `simResult.error = 'Requested fault bus is not modeled in physical Simulink network'`. **Never silently simulate Bus B.**
  3. **Network Parameter Compatibility Validation:**
     - In `p_validatePhysicalModelCompatibility()`, verify nominal voltages (33 kV source, 11 kV bus), transformer vector group (`wye-wye` or `grounded-wye-grounded-wye`), and base MVA (100 MVA). If mismatched, return `status = 'UNSUPPORTED'`.
  4. **Measurement Extraction Rigor:**
     - In `p_extractMeasurements()`, apply linear interpolation for continuous analog signals ($V_{abc}$, $I_{abc}$) and zero-order hold (`zoh`) for discrete binary status signals (relay trip, breaker state).
     - Invalidate results if required output ports are absent or corrupted.

---

### Phase 2: Transformer Topology & Zero-Sequence Network Corrections
- **Target Files:**
  - [`matlab/network/traceRadialPath.m`](../../matlab/network/traceRadialPath.m)
  - [`matlab/config/getSystemMasterConfiguration.m`](../../matlab/config/getSystemMasterConfiguration.m)
  - [`matlab/network/createIllustrativeTransformerRadialNetwork.m`](../../matlab/network/createIllustrativeTransformerRadialNetwork.m)
  - [`docs/ENGINEERING_VALIDATION_REPORT.md`](../../docs/ENGINEERING_VALIDATION_REPORT.md)
  - [`docs/assumptions.md`](../../docs/assumptions.md)
- **Remediation Actions:**
  1. **Authoritative Configuration:** Establish **Ynyn0** (grounded-wye / grounded-wye, solidly grounded neutrals, 0° phase displacement) as the single authoritative transformer configuration.
  2. **Zero-Sequence Path Derivation:**
     - For solidly grounded Ynyn0:
       $$Z_{0,\text{total}} = Z_{0,\text{source}} (0.10) + Z_{0,\text{T1}} (0.08) + Z_{0,\text{LineA}} (0.15) + Z_{0,\text{LineB}} (0.15) = \mathbf{0.480\text{ pu}}$$
     - Fix arithmetic derivation text in documentation where $Z_{0,\text{source}} = 0.10$ was inadvertently omitted from the addition formula.
  3. **Ungrounded Neutral Path Logic:**
     - In `matlab/network/traceRadialPath.m`, inspect transformer grounding. If a Wye-Wye transformer has either primary or secondary ungrounded (`'ungrounded'`), zero-sequence circulation is blocked across the transformer; set the upstream zero-sequence contribution to $\infty$.

---

### Phase 3: ANSI Protection Module Corrections
- **Target Files:**
  - [`matlab/protection/evaluateEarthFaultProtection.m`](../../matlab/protection/evaluateEarthFaultProtection.m)
  - [`matlab/protection/evaluateNegativeSequenceProtection.m`](../../matlab/protection/evaluateNegativeSequenceProtection.m)
  - [`matlab/protection/evaluateInstantaneousOvercurrent.m`](../../matlab/protection/evaluateInstantaneousOvercurrent.m)
- **Remediation Actions:**
  1. **ANSI 50N/51N (Earth-Fault Protection):**
     - Validate `settings.enabled` as scalar logical.
     - Validate `settings.pickup_A` and `settings.tms` as positive finite scalars.
     - Validate `settings.instPickup_A`: If present, must be positive finite or `Inf`. If negative, non-numeric, or invalid, throw error `'protection:InvalidSetting'` rather than silently defaulting to `Inf`.
     - Validate `settings.curveType` against allowed IEC curves (`standard inverse`, `very inverse`, `extremely inverse`, `definite`, `long time inverse`); throw error `'protection:InvalidSetting'` for unsupported curve names.
  2. **ANSI 46 (Negative-Sequence Protection):**
     - Validate `settings.mode` in `{'thermal', 'definite'}`; throw error `'protection:InvalidSetting'` if invalid.
     - Validate `settings.thermalK` and `settings.definiteDelay_s` as positive finite scalars; throw error if invalid.
     - **Fix Zero Positive-Sequence Edge Case:** When $I_1 \approx 0$ and $I_2 > 0$, set `unbalanceRatio_pct = Inf` (or documented infinite unbalance). Never report `0.0%` when negative-sequence current is present.
  3. **ANSI 50 (Instantaneous Overcurrent):**
     - Validate `settings.enabled` as scalar logical.
     - Validate `settings.pickup_A` as positive finite scalar.

---

### Phase 4: Analytical Engine & Network Validation
- **Target Files:**
  - [`matlab/faults/calculateThreePhaseFault.m`](../../matlab/faults/calculateThreePhaseFault.m)
  - [`matlab/faults/calculateSLGFault.m`](../../matlab/faults/calculateSLGFault.m)
  - [`matlab/faults/calculateLLFault.m`](../../matlab/faults/calculateLLFault.m)
  - [`matlab/faults/calculateDLGFault.m`](../../matlab/faults/calculateDLGFault.m)
  - [`matlab/network/validateRadialNetwork.m`](../../matlab/network/validateRadialNetwork.m)
- **Remediation Actions:**
  1. Verify base value conversions and per-unit calculations across all fault types.
  2. Verify that radial path tracing correctly isolates upstream Thevenin impedance without including downstream shunt branches or lateral spurs.
  3. Confirm that transformer winding boundary transformations correctly handle secondary-to-primary current reflections.

---

### Phase 5: CI & Workflow Alignment
- **Target Files:**
  - [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml)
  - [`docs/TEST_COVERAGE_REPORT.md`](../../docs/TEST_COVERAGE_REPORT.md)
  - [`docs/ENGINEERING_VALIDATION_REPORT.md`](../../docs/ENGINEERING_VALIDATION_REPORT.md)
- **Remediation Actions:**
  1. Verify `.github/workflows/tests.yml` maintains strict separation between analytical test suite (runs on every PR/push) and Simulink integration tests (conditionally checks licensing).
  2. Reconcile documentation to accurately reflect the workflow job dependency (`needs: analytical-unit-tests`).

---

### Phase 6: Test Suite Expansion & Regression Testing
- **Target Files:**
  - [`tests/unit/TestDynamicSimulationEntryPoint.m`](../../tests/unit/TestDynamicSimulationEntryPoint.m)
  - [`tests/unit/TestAnsiProtectionElements.m`](../../tests/unit/TestAnsiProtectionElements.m)
  - `tests/unit/TestNegativeSequenceProtection.m` (planned)
  - `tests/unit/TestRadialPathTracing.m` (planned)
  - `tests/unit/TestSequenceFaults.m` (planned)
- **Remediation Actions:**
  1. Add tests for Bus A fault simulation dispatch, Bus B dispatch, and unsupported bus rejection.
  2. Add tests for ungrounded wye-wye transformer zero-sequence isolation.
  3. Add tests for invalid ANSI 50N/51N settings throwing `'protection:InvalidSetting'`.
  4. Add tests for pure negative-sequence current ($I_1 = 0, I_2 > 0$) asserting `unbalanceRatio_pct == Inf`.
  5. Add tests for invalid ANSI 46 mode, thermal constant, and delay settings.

---

### Phase 7: Engineering Documentation Corrections
- **Target Files:**
  - [`README.md`](../../README.md)
  - [`docs/ENGINEERING_VALIDATION_REPORT.md`](../../docs/ENGINEERING_VALIDATION_REPORT.md)
  - [`docs/assumptions.md`](../../docs/assumptions.md)
  - [`docs/simulation-model-specification.md`](../../docs/simulation-model-specification.md)
  - [`docs/KNOWN_LIMITATIONS.md`](../../docs/KNOWN_LIMITATIONS.md)
- **Remediation Actions:**
  1. Replace any remaining references claiming "Dyn11" in the baseline model with the authoritative "Ynyn0".
  2. Document exact zero-sequence derivation with source impedance included ($0.10 + 0.08 + 0.15 + 0.15 = 0.480\text{ pu}$).
  3. State project scope accurately as an educational and engineering analysis tool, explicitly noting license prerequisites.

---

### Phase 8 & 9: Verification & Final Deliverables
- Execute full test suite via `scripts/run_all_tests.m`.
- Verify zero regressions and 100% analytical pass rate.
- Generate Phase 6 completion reports:
  - `docs/PHASE_6_BUG_FIX_REPORT.md`
  - `docs/PHASE_6_ENGINEERING_VALIDATION.md`
  - `docs/PHASE_6_TEST_REPORT.md`
  - `docs/PHASE_6_KNOWN_LIMITATIONS.md`

