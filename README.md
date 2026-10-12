# Power System Fault Analysis & Protection Coordination Simulator

## Overview

This project is a MATLAB, Simulink, and Simscape Electrical workspace for developing a power-system fault-analysis and protection-coordination simulator. The repository begins as a Phase 0 engineering skeleton: assumptions, environment checks, analytical methods, simulation models, tests, and generated results will be added incrementally.

The project does not currently contain electrical parameters, engineering algorithms, relay logic, or Simulink models. No engineering validation has been performed.

## Objectives

- Establish a traceable MATLAB analytical engine for symmetrical-component and fault-study calculations.
- Build a separate Simulink/Simscape Electrical simulation engine for time-domain studies.
- Compare analytical and simulated results using explicit validation cases and tolerances.
- Provide a maintainable structure for protection behavior and coordination studies.

## Planned Features

- Configurable network and per-unit base definitions.
- Three-phase, single-line-to-ground, line-to-line, and double-line-to-ground fault studies.
- Sequence-network and impedance calculations.
- Relay operating-characteristic and breaker-behavior studies.
- Protection coordination analysis.
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

**Phase 0 — Repository and environment preparation.** The structure and starter documentation are in place. Analytical calculations, protection logic, Simulink models, and engineering validation are intentionally not yet implemented.
