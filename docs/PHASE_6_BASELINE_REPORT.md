# Phase 6 Baseline Report: Repository Baseline, Inventory & Defect Audit

**Date:** November 1, 2026  
**Repository:** [https://github.com/ankeshbit/ee](https://github.com/ankeshbit/ee)  
**Project:** Power System Fault Analysis & Protection Coordination Simulator  
**Starting Commit SHA:** `8d7b209db1e37d50b91fb8e7c76f1075ea4398ad`  
**Active Branch:** `main`  
**Execution Environment:** MATLAB R2026b (v26.2.0.3055416), Simulink 26.2, Simscape 26.2, Windows 11  
**Toolbox Feature State:** `Simscape_Electrical = 0` (License token unavailable in current runner environment)

---

## 1. Executive Summary

This report establishes the verified baseline for **Phase 6: Complete Engineering Corrections, Bug Fixes & Independent Validation**. All statements, file inspections, and defect reports documented herein are based on direct inspection of tracked repository files and empirical test suite execution on the clean working tree at commit `8d7b209db1e37d50b91fb8e7c76f1075ea4398ad`.

### Baseline Test Suite Execution Summary
- **Test Runner:** [`scripts/run_all_tests.m`](file:///c:/Users/ankes/OneDrive/Desktop/ee/scripts/run_all_tests.m)
- **Total Test Cases:** 350
- **Passed:** 349
- **Failed:** 0
- **Incomplete / Skipped:** 1 (`TestDynamicFaultSimulationIntegration/testPhysicalSimulationExecution`)
- **Reason for Incomplete Test:** Missing Simscape Electrical product/license token (`Simscape_Electrical=0`), cleanly filtered via `assumeTrue` without synthetic fabrication or false-positive pass.
- **Overall Suite Status:** SUCCESS (Exit Code: 0)

---

## 2. Repository Inventory

The repository is structured into modular analytical calculation packages, physical simulation backends, protection coordination elements, test suites, automation scripts, and engineering documentation.

```
c:\Users\ankes\OneDrive\Desktop\ee
├── .github/
│   └── workflows/
│       └── tests.yml                     # Two-stage CI workflow (analytical tests & Simulink integration)
├── data/
│   ├── reference/                        # Reference benchmark values and IEEE/textbook data
│   │   ├── ieee_radial_benchmark.json
│   │   ├── relay_coordination_benchmarks.json
│   │   ├── simscape_reference_results.json
│   │   └── textbook_fault_benchmarks.json
│   └── validation/                       # Acceptance and numerical tolerance profiles
│       ├── acceptance_criteria.json
│       ├── test_scenarios.json
│       └── tolerance_profiles.json
├── docs/                                 # Architectural, engineering, and audit documentation
│   ├── assumptions.md
│   ├── BUG_FIX_REPORT.md
│   ├── ENGINEERING_VALIDATION_REPORT.md
│   ├── FULL_REPOSITORY_AUDIT.md
│   ├── KNOWN_LIMITATIONS.md
│   ├── simulation-model-specification.md
│   ├── system-architecture.md
│   └── TEST_COVERAGE_REPORT.md
├── matlab/
│   ├── analysis/                         # Multi-bus study runners, dynamic simulation wrappers, sensitivity
│   │   ├── checkSimulationCapabilities.m
│   │   ├── compareAnalyticalAndSimulation.m
│   │   ├── runDynamicBreakerSwitchingSimulation.m
│   │   ├── runDynamicFaultSimulation.m
│   │   ├── runFaultSensitivityStudy.m
│   │   ├── runIntegratedFaultStudy.m
│   │   └── runRelayCoordinationStudy.m
│   ├── config/                           # Master network and study configuration generators
│   │   ├── createRadialRelayStudyConfiguration.m
│   │   └── getSystemMasterConfiguration.m
│   ├── faults/                           # Sequence-network symmetrical component fault solvers
│   │   ├── calculateDLGFault.m
│   │   ├── calculateLLFault.m
│   │   ├── calculateSequenceComponents.m
│   │   ├── calculateSLGFault.m
│   │   └── calculateThreePhaseFault.m
│   ├── network/                          # Network validation, per-unit base calculation, radial path tracing
│   │   ├── calculateBaseValues.m
│   │   ├── createIllustrativeTransformerRadialNetwork.m
│   │   ├── traceRadialPath.m
│   │   └── validateRadialNetwork.m
│   ├── protection/                       # ANSI/IEEE/IEC protection relay evaluation algorithms
│   │   ├── checkCoordinationMargin.m
│   │   ├── evaluateCoordinationChain.m
│   │   ├── evaluateDirectionalSupervision.m
│   │   ├── evaluateEarthFaultProtection.m
│   │   ├── evaluateInstantaneousOvercurrent.m
│   │   ├── evaluateNegativeSequenceProtection.m
│   │   ├── evaluateRelayOperatingTime.m
│   │   ├── evaluateTimeOvercurrent.m
│   │   └── plotRelayCoordinationCurves.m
│   └── validation/                       # Scenario, relay, and tolerance validation utilities
│       ├── validateRelays.m
│       ├── validateScenarios.m
│       └── validateTolerances.m
├── models/                               # Simulink and Simscape model storage
│   ├── radial_fault_study_network.slx    # Compiled/saved physical model
│   └── README.md
├── scripts/                              # CLI study runners and model generation builders
│   ├── build_radial_fault_model.m        # Programmatic builder for Simscape physical model
│   ├── run_all_tests.m                   # Authoritative automated test suite runner
│   ├── run_complete_fault_study.m        # Master simulation and analytical study pipeline
│   └── run_system_health_check.m         # Pre-flight environment diagnostics
└── tests/                                # MATLAB Unit Testing Framework test suites
    ├── integration/                      # Dynamic simulation, relay coordination, study integration
    │   ├── TestCompleteFaultStudyRunner.m
    │   ├── TestDynamicFaultSimulationIntegration.m
    │   ├── TestFullSystemWorkflow.m
    │   └── TestRelayCoordinationIntegration.m
    └── unit/                             # Symmetrical components, protection elements, contracts
        ├── TestANSIProtectionElements.m
        ├── TestCoordinationMargin.m
        ├── TestDirectionalSupervision.m
        ├── TestFaultSensitivityStudy.m
        ├── TestNegativeSequenceProtection.m
        ├── TestRadialPathTracing.m
        ├── TestRelayCoordinationChain.m
        ├── TestRunAllTestsRunner.m
        ├── TestRunCompleteFaultStudyAcceptance.m
        ├── TestSequenceFaults.m
        ├── TestSimulationContractsAndValidation.m
        ├── TestSystemMasterConfiguration.m
        └── TestValidationAndDiagnostics.m
```

---

## 3. Discovered Defects and Detailed Technical Audit

The table below records every confirmed defect, its affected module, reproduction method, severity, engineering impact, proposed correction, and required regression tests.

| Defect ID | Module & Function | Severity | Root Cause | Engineering Impact | Proposed Correction | Required Regression Test |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **DEF-P6-01** | `matlab/analysis/runDynamicFaultSimulation.m` (`p_applyFaultParameters`) & `scripts/build_radial_fault_model.m` | **CRITICAL** | Fixed physical model only contains `radial_fault_study_network/Fault_BusB`. Line 187 hardcodes `faultBlock = [modelName, '/Fault_BusB'];`. | If the user requests `scenario.faultedBus = 'BUS_A'`, the backend silently simulates a fault at Bus B. Analytical calculations for Bus A are compared against physical waveforms for Bus B, generating false validation or invalid results. | 1. Add `Fault_BusA` block to `build_radial_fault_model.m` at Bus A (disabled by default, start at 999.0s).<br>2. In `runDynamicFaultSimulation.m`, validate `scenario.faultedBus`: verify it exists in `network.buses`.<br>3. Check if physical model supports it: if `BUS_B`, configure `Fault_BusB` and disable `Fault_BusA`; if `BUS_A`, configure `Fault_BusA` and disable `Fault_BusB`.<br>4. If an unsupported bus (e.g. `SOURCE_33KV`) is requested, return `status = 'UNSUPPORTED'` or `'BLOCKED'` with an explicit error message. **Never silently fall back to Bus B.** | Test simulating Bus A fault, Bus B fault, and unsupported bus (`SOURCE_33KV`), asserting explicit unsupported status. |
| **DEF-P6-02** | `matlab/analysis/runDynamicFaultSimulation.m` (`p_validatePhysicalModelCompatibility`) | **HIGH** | The function only checks structural field presence in `network`, but does not validate whether network parameters (nominal voltage, transformer rating, line impedances, topology) match the physical model. | Passing an arbitrary 5-bus mesh network or 220 kV network into dynamic simulation attempts to simulate an unrelated 33/11 kV radial model. | Add explicit parameter validation verifying network nominal voltages (33 kV / 11 kV), transformer configuration (Ynyn0), and radial line structure. Return `status = 'UNSUPPORTED'` if network parameters do not match. | Test with non-matching network (e.g. 132 kV grid) verifying `UNSUPPORTED` simulation status. |
| **DEF-P6-03** | `matlab/analysis/runDynamicFaultSimulation.m` (`p_extractMeasurements`) & `runDynamicBreakerSwitchingSimulation.m` | **MEDIUM** | Measurement extraction does not strictly separate continuous analog signals (voltages, currents) from discrete binary signals (relay trip, breaker open/closed status). | Linear interpolation across discrete step changes in trip or breaker status can smooth step transitions, causing timing errors. Missing signals could default to zeros if corrupted. | 1. Use linear interpolation for analog continuous signals.<br>2. Use zero-order hold (`zoh`) for discrete logic/status signals.<br>3. Invalidate result if mandatory output ports or waveforms are missing or corrupted. **Never substitute synthetic zeros.** | Unit tests validating interpolation method selection, timestamp monotonicity, and rejection of missing signals. |
| **DEF-P6-04** | `docs/ENGINEERING_VALIDATION_REPORT.md` (Sections 1 & 2), `docs/assumptions.md` vs `matlab/config/getSystemMasterConfiguration.m` | **HIGH** | Implementation uses `grounded-wye / grounded-wye` (Ynyn0 / Yg-Yg, both neutrals solidly grounded). `docs/ENGINEERING_VALIDATION_REPORT.md` stated "Dyn11" in text while deriving wye-wye arithmetic, and included an arithmetic typo: `0.08 + 0.15 + 0.15 = 0.480 pu` (omitting $Z_{0,\text{source}} = 0.10\text{ pu}$). | Severe documentation inconsistency. Dyn11 isolates zero sequence from the HV source grid and introduces 30° phase displacement. Ynyn0 has 0° displacement and permits through zero-sequence current when both neutrals are grounded. | Reconcile all documentation to establish Ynyn0 as the authoritative master configuration. Document phase displacement (0° for Ynyn0, 30° for Dyn11), zero-sequence transfer behavior, and correct derivation to explicitly state: $Z_{0,\text{total}} = 0.10 + 0.08 + 0.15 + 0.15 = 0.480\text{ pu}$. | Symmetrical component sequence impedance verification tests. |
| **DEF-P6-05** | `matlab/network/traceRadialPath.m` | **HIGH** | `traceRadialPath.m` checks for `delta-grounded-wye`, but in the `else` branch assumes any transformer passes upstream zero-sequence current without checking if Wye-Wye neutrals are grounded. | If an ungrounded wye-wye (Y-Y) or single-grounded wye-wye (Yg-Y or Y-Yg) transformer is specified, zero-sequence current cannot circulate between HV and LV, but the code still includes upstream zero-sequence impedance. | Inspect `transformer.windingConnection` and grounding attributes (`primaryGrounding`, `secondaryGrounding`). For wye-wye, if either neutral is ungrounded, set zero-sequence path impedance to `Inf` (open circuit). | Unit test with ungrounded Y-Y transformer asserting $Z_0 = \infty$ and zero SLG fault current. |
| **DEF-P6-06** | `matlab/protection/evaluateEarthFaultProtection.m` | **HIGH** | 1. Invalid `instPickup_A` (e.g. negative or non-finite) silently defaults to `Inf`.<br>2. `settings.enabled` is cast with `logical()` without verifying scalar logical.<br>3. `settings.curveType` accepts arbitrary strings without validating against supported IEC curves. | Invalid or corrupt relay settings silently produce default behavior instead of alerting the engineer to an invalid protection setting. | 1. Throw error with identifier `'protection:InvalidSetting'` for negative/non-finite pickup, invalid TMS, and invalid `instPickup_A`.<br>2. Validate `enabled` as scalar logical.<br>3. Enforce supported IEC curve types (`standard inverse`, `very inverse`, `extremely inverse`, `definite`, `long time inverse`). | Unit tests asserting specific error identifiers on invalid settings. |
| **DEF-P6-07** | `matlab/protection/evaluateNegativeSequenceProtection.m` | **CRITICAL** | 1. Invalid `settings.mode` silently defaults to `'definite'`.<br>2. Invalid `thermalK` or `definiteDelay_s` silently fall back to defaults.<br>3. When $I_1 \approx 0$ and $I_2 > 0$, `unbalanceRatio_pct` is reported as `0.0%` (lines 87–91). | Pure negative-sequence current (100% unbalance) is incorrectly reported as 0% unbalance, preventing relay operation on severe unbalance! | 1. Throw validation error on invalid mode, thermalK, or definiteDelay_s.<br>2. When $I_1 \approx 0$ and $I_2 > 0$, report `unbalanceRatio_pct = Inf` (or documented infinite unbalance condition); report `0.0%` only when $I_2 \approx 0$. | Test pure negative sequence current ($I_1 = 0, I_2 > 0$) asserting `unbalanceRatio_pct == Inf` and invalid setting errors. |
| **DEF-P6-08** | `matlab/protection/evaluateInstantaneousOvercurrent.m` | **MEDIUM** | `settings.enabled` is cast without verifying scalar logical; `pickup_A` is not validated for finite positive value. | Inconsistent error-handling behavior compared to other ANSI elements. | Enforce scalar boolean `enabled` and finite positive `pickup_A`, throwing `'protection:InvalidSetting'`. | Unit tests asserting validation errors on invalid settings. |
| **DEF-P6-09** | `.github/workflows/tests.yml` vs Documentation | **LOW** | Documentation described CI jobs as running purely in parallel, but workflow defines `needs: analytical-unit-tests` for `simulink-integration-tests`. | Developer confusion regarding CI pipeline dependencies and execution triggers. | Reconcile documentation to explicitly explain the 2-stage pipeline (`analytical-unit-tests` followed by conditionally licensed `simulink-integration-tests`). | YAML syntax validation and workflow documentation review. |

---

## 4. Inspection Methodology and Verification Status

Every file listed in Section 2 and every issue recorded in Section 3 has been inspected directly in the local workspace. No claims of inspection have been made without direct verification.

- **Baseline Test Suite Execution:** Verified 350 tests executing cleanly with 349 passes and 1 license-blocked incomplete test.
- **Git State:** Verified clean working tree at commit `8d7b209db1e37d50b91fb8e7c76f1075ea4398ad` on branch `main`.

