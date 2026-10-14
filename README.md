# Power System Fault Analysis & Protection Coordination Simulator

## Overview

This project is a MATLAB, Simulink, and Simscape Electrical workspace for developing a power-system fault-analysis and protection-coordination simulator.

The repository includes:
- **MATLAB Analytical Engine:** Sequence-network calculations for 3PH, SLG, LL, and DLG faults, per-unit base systems, transformer vector group analysis, IEC inverse-time overcurrent relays, and protection coordination matrices.
- **Simscape Electrical Physical Engine:** Native time-domain simulation (`radial_fault_study_network.slx`) modeling a 33/11 kV distribution system with source impedance, Yg/Yg transformer leakage, distribution feeder sections, and configurable physical fault elements.
- **Multi-Fault Validation:** All four power system fault types (3PH, SLG, LL, DLG) and healthy steady state are fully implemented, stabilized against DAE index singularities, and validated against analytical sequence networks with sub-0.15% agreement for balanced and line-to-line faults.
- **Automated Regression Test Suite:** Over 160 unit and integration tests covering analytical, simulation, and protection coordination functions.

## Objectives

- Establish a traceable MATLAB analytical engine for symmetrical-component and fault-study calculations.
- Build a native Simulink/Simscape Electrical simulation engine for physical time-domain studies.
- Compare analytical and simulated results using explicit validation cases and tolerances.
- Provide a maintainable structure for protection behavior and coordination studies.

## Planned Features

- Configurable network and per-unit base definitions.
- Three-phase, single-line-to-ground, line-to-line, and double-line-to-ground fault studies.
- Sequence-network and impedance calculations.
- IEC inverse-time relay operating-characteristic and breaker-behavior studies.
- Ideal CT conversion and primary/backup protection coordination analysis.
- Integrated radial fault studies across multiple buses and fault types.
- Transformer-aware 33 kV/11 kV voltage-base and sequence-impedance modeling.
- Multi-branch radial studies with explicit branch and transformer relay locations.
- Protection zones, breaker clearing-time analysis, CT screening, fault
  sensitivity studies, and structured reports.
- Breaker-failure scenarios and explicit zone-selectivity outcomes.
- Optional sequence/phase phasor results and a protection selectivity matrix.
- Analytical-versus-simulation comparison reports and plots.
- MATLAB unit tests and integration tests.

## Technology Stack

- MATLAB
- Simulink
- Simscape
- Simscape Electrical
- Git

## Folder Structure

```text
power-system-fault-analysis-simulator/
├── docs/                 # Assumptions, architecture, validation, and setup guidance
├── matlab/               # Future MATLAB analytical and reporting code
├── simulink/             # Future Simulink and Simscape Electrical assets
├── tests/                # Unit and integration tests
├── results/              # Generated plots and reports
└── scripts/              # Setup and test utilities
```

See the individual directory documentation for the intended scope of each area.

## Prerequisites

Before development, verify access to a supported MATLAB release and the required Simulink, Simscape, and Simscape Electrical products. Product availability and licensing must be checked locally; this repository does not assume that any toolbox is installed.

Review [docs/setup-guide.md](docs/setup-guide.md) before adding implementation files.

## Setup

1. Clone or open the repository in a local workspace.
2. Open MATLAB and run the environment checks described in [docs/setup-guide.md](docs/setup-guide.md).
3. Review and complete the checklist in [docs/assumptions.md](docs/assumptions.md).
4. Agree on the validation cases and tolerances in [docs/validation-plan.md](docs/validation-plan.md).
5. Add implementation and tests incrementally while preserving the separation described in [docs/system-architecture.md](docs/system-architecture.md).

## Development Status

**Phase D & Phase E: Multi-Fault Simscape Validation and Relay Protection Coordination.**
- **All Four Fault Types Validated:** 3PH, SLG, LL, DLG, and Healthy steady-state fully simulated in native Simscape Electrical (`radial_fault_study_network.slx`).
  - 3PH fundamental current: $1872.22\,\text{A}$ vs $1874.51\,\text{A}$ (0.1225% error).
  - LL fundamental current: $938.13\,\text{A}$ vs $937.26\,\text{A}$ (0.0930% error).
  - DLG fundamental current: $1275.83\,\text{A}$ vs $1275.43\,\text{A}$ (0.0313% error against calibrated $Z_0 = 0.248\,\text{pu}$).
  - SLG fundamental current: $650.00\,\text{A}$ unloaded vs $649.58\,\text{A}$ (0.0770% error); $655.37\,\text{A}$ with 1 MW healthy-phase load superposition (0.8900% error).
  - Healthy load current: $53.02\,\text{A}$ vs $52.49\,\text{A}$ (1.0015% error).
- **Phase E Relay Protection and Coordination Layer:**
  - Standardized reproducible relay configuration (`createRadialRelayStudyConfiguration.m`): Downstream feeder relay (`RELAY_BUS_B`, CT 400/5 A, $I_p = 1.0\,\text{A}$, $\text{TMS} = 0.10$), substation incomer relay (`RELAY_BUS_A`, CT 600/5 A, $I_p = 1.0\,\text{A}$, $\text{TMS} = 0.25$), and 33 kV HV incomer relay (`RELAY_33KV`, CT 200/5 A, $I_p = 1.5\,\text{A}$, $\text{TMS} = 0.40$).
  - Full evaluation across all fault types (`evaluateRadialProtectionScenarios.m`): IEC Standard Inverse, Very Inverse, and Extremely Inverse curves supported.
  - Strict mathematical separation between Relay Coordination Time Interval ($\text{CTI} = t_{\text{backup}} - t_{\text{primary}}$) and Clearing-Time Margin ($\text{Margin} = t_{\text{backup}} - (t_{\text{primary}} + t_{\text{breaker,primary}})$).
  - Breaker-failure clearing: Validated backup relay tripping and fault clearance when primary breaker fails to open (`failedToOpen`).
- **Automated Regression Suite:** 181 total tests: **180 Passed, 0 Failed, 1 Incomplete** (filtered by assumption).

Analytical and Protection functions remain fully active:
- Relay operating time calculation (`calculateRelayOperatingTime`).
- Relay coordination verification (`checkRelayCoordination`).
- Breaker clearing time evaluation (`calculateBreakerClearingTime`).
- Breaker-failure analysis (`evaluateBreakerFailureScenario`).
- Directional supervision and CT screening (`evaluateDirectionalSupervision`, `screenCTSaturation`).
- Protection zone validation (`validateProtectionZones`).
- Fault sensitivity studies and reports (`runFaultSensitivityStudy`, `generateFaultSensitivityReport`).
- Network phasor analysis and protection selectivity matrices (`calculateNetworkPhasors`, `buildProtectionSelectivityMatrix`).
