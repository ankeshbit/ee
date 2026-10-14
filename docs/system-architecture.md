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
- Converting primary fault current to each relay's CT secondary current.
- Checking primary/backup operating times and scenario-specific CTI.
- Running multiple fault scenarios and returning structured fault, relay, and
  coordination results.
- Validating transformer terminals, voltage bases, winding connections, and
  zero-sequence transfer assumptions.
- Producing machine-readable result structures for tests and reports.

## Simulink Simulation Engine

The Simulink and Simscape Electrical engine owns dynamic, time-domain representations
of the power network, faults, measurement points, and protection devices.
Component selections are verified against Simscape Electrical physical modeling
blocks (`ee_lib.slx`), explicitly rejecting legacy Specialized Power Systems (`powerlib`).

Dynamic model execution is governed by a license-aware entry point:
- `checkSimulationCapabilities`: Audits product installation, licenses, APIs, and components.
- `runDynamicFaultSimulation`: Deterministic entry point that halts execution safely with
  status `BLOCKED` when licensing prerequisites are not met, avoiding model corruption or fake data.
- Detailed model parameters, block inventory, and wiring topology are documented in
  `docs/simulation-model-specification.md`.

## Interface Between Engines

The analytical-to-simulation interface is governed by strict configuration, schema,
and comparison contracts documented in `docs/simulation-integration.md`:

- **Input Contract:** `validateSimulationInput` normalizes the network, fault scenario,
  timing parameters, solver options (`ode23t`, $\Delta t_{\text{max}} = 50\,\mu\text{s}$),
  and requested measurement locations.
- **Output Schema:** `createSimulationResultSchema` and `validateSimulationResult` enforce
  consistent execution states (`NOT_RUN`, `BLOCKED`, `BUILD_FAILED`, `SIMULATION_FAILED`,
  `SIMULATION_COMPLETED`, `MEASUREMENTS_INVALID`, `VALIDATION_COMPLETED`), waveform arrays,
  provenance metadata, and strict rejection of unsimulated data claims.
- **Measurement Processing:** `validateMeasurementWindow`, `extractSimulationRMS`, and
  `estimateFundamentalPhasor` extract steady-state RMS currents and fundamental complex phasors
  from time-domain waveforms over integer post-transient cycles.
- **Cross-Engine Comparison:** `compareAnalyticalAndSimulation` validates agreement against
  analytical benchmark values within approved tolerances and rejects cross-transformer
  comparisons across mismatched voltage bases.

The current protection data flow is:

`fault current in primary amperes -> relay-specific CT conversion -> relay operating time in seconds -> primary/backup coordination result`.

Relay pickup settings are expressed in CT secondary amperes. Breaker opening
time is not included in relay operating time or CTI.

The integrated analytical entry point is
`runIntegratedFaultStudy(network, scenarios, relays, coordinationPairs)`.
The network is validated by `validateRadialNetwork`; an illustrative test
configuration is provided by `createIllustrativeRadialNetwork`, while
`createIllustrativeTransformerRadialNetwork` provides a 33/11 kV case. A scenario
identifies a faulted bus, fault type, and per-unit fault impedance. Its output
contains per-unit and ampere fault-current values, phase and sequence currents,
relay secondary currents and operating times, and applicable coordination
results. `convertPuImpedanceBase` applies per-unit base conversion only when
the voltage bases refer to the same physical transformer side. The current
topology model supports a connected branched radial network with one upstream
element per non-source bus. A fault study walks the unique source-to-fault path
through branch and transformer elements. Relay locations are explicit for new
configurations: branch `from`/`to` sides or transformer `high`/`low` sides.
The legacy `protectedBranch` field remains supported and maps to the branch
from-bus side.

Only path elements carry the modeled single-source fault contribution. Sibling
branches receive zero current. Current in per unit is converted to amperes
using the voltage base at each relay measurement side, then converted through
that relay's CT. This preserves distinct high-side and low-side transformer
relay currents. The model does not include taps, phase shifts, load flow,
mutual coupling, directional elements, parallel sources, or mesh networks.

The advanced protection layer is separate from the fault solver. Protection
zones validate relay, network-element, and optional breaker references.
`calculateBreakerClearingTime` adds a configured breaker opening delay after
relay operating time. `runFaultSensitivityStudy` reuses the integrated study
results and emits relay and coordination tables containing CT-secondary
current, pickup ratio, relay time, breaker delay, total clearing time, CT
screening status, and directional status. `generateFaultSensitivityReport`
creates scenario, relay-time, coordination, failed-coordination,
non-operating-relay, CT-warning, and unsupported-direction tables.

Directional decisions are unsupported unless explicit current and polarizing
voltage phasors are supplied. CT screening is a threshold warning, not an
electromagnetic saturation calculation.

`evaluateBreakerFailureScenario` consumes one integrated fault-study result,
explicit zones, relays, breakers, and a non-mutating failure override. It
checks primary zone coverage, primary pickup, breaker state, configured
backup eligibility, directional blocking status, and backup breaker state.
It returns separate relay CTI, primary/backup total clearing times,
clearing-time margin, and an explicit uncleared status when no modeled path
succeeds. `runFaultSensitivityStudy` optionally evaluates these scenarios and
`generateFaultSensitivityReport` exposes backup outcomes, uncleared faults,
and zone-configuration issues in separate tables.

## Repository Boundaries

- `matlab/` contains analytical and reporting implementation.
- `simulink/` contains `.slx` models and reusable simulation libraries.
- `tests/` contains tests that exercise one engine or compare both engines.
- `results/` contains generated artifacts and should not become a source-data store.
- `docs/` contains assumptions, decisions, validation criteria, and environment guidance.
## Phasor and selectivity layer

The optional phasor layer consumes `runIntegratedFaultStudy` results, computes
sequence and phase quantities at supported radial-path buses and relay
locations, and passes positive-sequence phasors to the existing directional
supervision evaluator. `buildProtectionSelectivityMatrix` combines those
measurements with sensitivity-table timing and breaker-failure outcomes
without recalculating electrical quantities. Unsupported off-path or missing
phasor cases remain explicit statuses.
