# System Architecture

## Architectural Intent

The project will separate deterministic analytical calculations from time-domain simulation assets. This separation supports independent testing, clearer traceability, and direct comparison between calculated fault quantities and simulated waveforms.

## MATLAB Analytical Engine

The MATLAB engine will own configuration data, network representation, per-unit conversions, sequence-network calculations, analytical fault studies, protection calculations, and report preparation. Functions should receive explicit inputs and return structured results rather than relying on hidden workspace state. Configuration and engineering data should remain distinguishable from algorithms and generated outputs.

Planned responsibilities include:

- Loading and validating network and study configuration.
- Converting quantities to and from the agreed per-unit system.
- Building network impedance representations.
- Solving analytical fault cases.
- Evaluating relay and coordination calculations once their equations and assumptions are approved.
- Producing machine-readable result structures for tests and reports.

## Simulink Simulation Engine

The Simulink engine will own dynamic, time-domain representations of the network, faults, protection devices, breakers, measurement points, and reusable subsystems. Simscape Electrical models will be added only after the required products and modeling conventions are verified.

Simulation models should expose documented parameters and measurement interfaces. Model-specific initialization should be explicit and should not silently replace the analytical configuration.

## Interface Between Engines

The interface will use versioned configuration and result schemas. A study definition should identify the network case, base values, fault type and location, protection settings, solver configuration, and expected outputs. Analytical results and simulation outputs should be normalized into comparable quantities with units, timestamps, and metadata.

## Repository Boundaries

- `matlab/` contains analytical and reporting implementation.
- `simulink/` contains `.slx` models and reusable simulation libraries.
- `tests/` contains tests that exercise one engine or compare both engines.
- `results/` contains generated artifacts and should not become a source-data store.
- `docs/` contains assumptions, decisions, validation criteria, and environment guidance.
