# Engineering Assumptions Checklist

This checklist identifies decisions that must be verified and recorded before engineering implementation. Items are intentionally unconfirmed at repository initialization.

## Network and Per-Unit System

- [ ] Confirm system frequency and nominal phase-to-phase voltage levels.
- [ ] Define and approve the system MVA base and voltage bases by voltage level.
- [ ] Define how current and impedance bases are derived and converted.
- [ ] Define the reference bus, phase sequence, and angle convention.
- [ ] Confirm whether network data is entered in physical units, per-unit values, or both.
- [ ] Define data precision, rounding, and significant-figure conventions.

## Sequence Networks and Fault Studies

- [ ] Verify positive-, negative-, and zero-sequence impedances for each network element.
- [ ] Confirm mutual coupling assumptions and whether they are neglected.
- [ ] Confirm source grounding and zero-sequence return-path assumptions.
- [ ] Define the fault impedance model and any prefault voltage assumptions.
- [ ] Define the fault types and fault-location representation to be supported.

The implemented analytical fault functions use per-unit Thevenin sequence
impedances and a prefault positive-sequence voltage. Their fault-impedance
conventions are intentionally different where required by the physical fault:

- A three-phase fault uses `Zf` in series with the positive-sequence network.
- A phase-A single-line-to-ground fault uses `3*Zf` in the series
  sequence-network denominator.
- A phase-B/C line-to-line fault uses `Zf` as the impedance directly between
  phases B and C.
- A phase-B/C double-line-to-ground fault uses `Zf` from each faulted phase to
  the common ground reference, producing `Z0 + 3*Zf` in the zero-sequence
  branch.

The line-to-line implementation uses A-B-C phase order and the
positive-sequence convention defined by `calculateSequenceComponents`.
Consequently, `I0 = 0`, `I2 = -I1`, phase A current is zero, and the B and C
currents are equal and opposite.

Fault functions reject a total or equivalent denominator whose magnitude is
below MATLAB's `eps` threshold. This protects against exactly or numerically
singular networks without imposing an engineering impedance tolerance on
otherwise valid complex data.

## Transformers

- [ ] Verify transformer ratings, impedance bases, and tap settings.
- [ ] Confirm winding configuration and grounding (for example, wye, delta, and grounded-neutral details).
- [ ] Confirm zero-sequence transfer behavior through each transformer.
- [ ] Document phase-shift conventions and the reference used for vector groups.
- [ ] Confirm treatment of off-nominal taps and phase-shifting transformers.

The transformer-aware illustrative case uses a 33 kV source bus, an 11 kV
distribution bus, and a common 10 MVA base. Transformer impedances are stored
in per-unit on the common MVA base with voltage bases tied to the rated
terminal voltages. The base current and base impedance are recalculated at the
faulted bus voltage level; the same ampere current must not be reused on both
transformer sides.

The supported transformer winding modes are:

- `grounded-wye-grounded-wye` with both neutrals grounded: the configured
  zero-sequence impedance is included in the source-to-fault path.
- `delta-grounded-wye`: zero-sequence transfer through the transformer is
  blocked and SLG/DLG studies across that transformer are rejected explicitly.

Other winding connections, ambiguous grounding, phase shifts, taps, mutual
coupling, and detailed transformer zero-sequence behavior are unsupported.
The illustrative transformer values are software-verification assumptions,
not validated utility-system data.

## Protection and Switching

- [ ] Verify relay input quantities, CT/VT ratios, polarity, and measurement locations.
- [x] Define the ideal relay equations, characteristic curves, pickup settings, time-dial settings, and units.
- [ ] Define breaker logic, interrupting delay, failure behavior, and reclosing assumptions.
- [ ] Define coordination objectives, grading margins, and selectivity criteria.
- [ ] Identify any vendor-specific behavior that must not be approximated without evidence.

The standalone overcurrent relay calculator uses the steady-state IEC inverse-time
equation

`t = TMS * k / ((Irelay / Ipickup)^alpha - 1)`

only when `Irelay > Ipickup`. It supports Standard Inverse (`k = 0.14`,
`alpha = 0.02`), Very Inverse (`k = 13.5`, `alpha = 1`), and Extremely
Inverse (`k = 80`, `alpha = 2`), with case-insensitive names and the `SI`,
`VI`, and `EI` aliases. `Inf` means that the relay does not trip under this
steady-state model.

This is an ideal analytical characteristic, not a physical relay simulation.
It does not model relay tolerances, CT saturation, transient/DC-offset effects,
breaker delay, or manufacturer-specific characteristic variations. Future
integration should pass measured or calculated branch/fault RMS current together
with explicit relay pickup and TMS settings; no network data structure is
introduced by this milestone.

For coordination checks, `faultCurrentPrimary_A` is an RMS current in primary
amperes. Each relay's `CTprimary_A` and `CTsecondary_A` ratings convert that
current to a relay current in CT secondary amperes. Each
`pickupCurrent_A` setting is therefore required to be on the CT secondary side.
The data flow is:

`fault current -> CT conversion -> relay operating time -> coordination check`

The ideal CT conversion is `Isecondary = Iprimary * CTsecondary / CTprimary`.
It does not model saturation, burden, phase error, or transient response.
Coordination is evaluated only for the supplied fault-current scenario. When
both relays operate, `CTI = t_backup - t_primary`; otherwise the result is
explicitly non-coordinated and its interval is reported as `Inf`.

For example, an 800 A primary fault through a 400/5 CT gives 10 A at the
primary relay. With a Very Inverse curve, pickup 2.5 A, and TMS 1, its time is
`13.5/(10/2.5 - 1) = 4.5 s`. Through an 800/5 CT, the backup sees 5 A; with
pickup 2.5 A and TMS 2, its time is `27 s`, giving a CTI of `22.5 s`.

The integrated study engine uses a radial network structure containing one
common three-phase base, a source bus and Thevenin sequence impedance, buses
with line-to-line voltage bases, directed branches with sequence impedances,
and optional explicit transformers. Branch and transformer impedances are
per-unit on the common MVA base, with voltage references recorded at their
physical terminal sides. The unique path from the source to a faulted bus is
added to the source Thevenin impedance to form the faulted-bus sequence
equivalent.

The topology may contain multiple outgoing branches, but each non-source bus
has exactly one upstream element and the complete network must be connected to
the source. For each fault, the engine identifies the unique source-to-fault
path. Only elements on that path carry the modeled fault contribution; relays
on sibling branches receive zero current and are reported as non-operating.
This is a single-source radial approximation, not a full branch-current,
directional-protection, load-flow, or parallel-contribution solution.

New relays should explicitly identify `measurementElementType` (`branch` or
`transformer`), `measurementElementId`, and `measurementSide` (`from` or `to`
for branches, `high` or `low` for transformers). Legacy relays with
`protectedBranch` remain supported and are interpreted as measuring the branch
from-bus side. A path relay uses the common fault-current per-unit value with
the current base at its measurement bus. Therefore transformer high-side and
low-side relays do not receive the same ampere current. The illustrative
network values are software-verification assumptions and are not validated
system data.

## Advanced protection-analysis assumptions

Protection zones are explicit structures containing a zone identifier,
protected element type and identifier, primary relay, backup relay
identifiers, required CTI, and optional breaker/fault-location references.
Zone membership is configuration metadata; it does not prove selectivity,
breaker-failure coverage, or correct fault-current contribution.

Breaker opening delay is a separate post-relay interval:

`total clearing time = relay operating time + breaker opening delay`

The existing CTI definition remains relay-to-relay operating-time difference:

`CTI = t_backup_relay - t_primary_relay`

Sensitivity reports additionally provide total clearing times and the
clearing-time margin:

`clearing-time margin = t_backup_total - t_primary_total`

No breaker delay is inserted into the IEC relay equation.

The directional module is bounded. The integrated radial fault model does not
provide relay polarizing-voltage phasors, so its default result is
`unsupported`, not a guessed forward or reverse decision. If explicitly
provided current and polarizing-voltage phasors are available, the optional
criterion uses the sign of:

`real(I * conjugate(Vpolarizing) * exp(-j*characteristicAngle))`

Zero polarizing voltage returns `indeterminate`. This is not a commercial
directional relay model.

CT screening compares calculated CT secondary current with an explicitly
configured threshold when available. Results are `withinConfiguredLimits`,
`exceedsConfiguredThreshold`, or `insufficientData`. Threshold exceedance is
only a warning and does not prove saturation; remaining below a threshold does
not prove that saturation cannot occur. Excitation curves, burden, winding
resistance, remanence, DC offset, and transient electromagnetic behavior are
not modeled.

## Software and Simulation Environment

- [x] Record the MATLAB release used for each validation run: MATLAB R2026b.
- [x] Verify availability and license status for Simulink, Simscape, and Simscape Electrical.
- [ ] Confirm supported model configuration and solver choices.
- [ ] Define simulation stop time, maximum step size, initialization method, and tolerances.
- [ ] Define numerical comparison tolerances for magnitudes, angles, timing, and event ordering.
- [ ] Record all assumptions and deviations in version-controlled documentation.

The current development environment reports valid Simulink and Simscape
licenses, but no Simscape Electrical license. Consequently, no physical
electrical simulation model or simulation result is claimed at this stage.

## Breaker failure and zone selectivity

### Phasor and selectivity outputs

`calculateNetworkPhasors` uses the existing fault-study sequence currents and
the source-plus-unique-radial-path equivalent. Sequence bus voltages are
calculated as `V1 = Vth - Z1*I1`, `V2 = -Z2*I2`, and `V0 = -Z0*I0`;
phase quantities are reconstructed with the existing A-B-C sequence transform.
Only buses and relay measurement locations on the source-to-fault path are
supported. Off-path measurements are explicitly marked unsupported.

`runFaultSensitivityStudy` can set `options.includePhasors = true` to retain
phasor results and build a selectivity matrix from those actual measurements.
The matrix reports modeled eligibility and timing; it is not a commercial
relay model or evidence of field selectivity.

Breaker configurations may include a `state` of `closed`, `opened`,
`failedToOpen`, or `notCommanded`. Only a configured `closed` breaker can
clear a fault. A failure scenario supplies a non-mutating override such as
`failedBreakerId` or `failedBreakerIds`; the original configuration is not
changed.

The breaker-failure evaluator requires exactly one explicitly applicable zone
for an unambiguous primary decision. No applicable zone returns a missing
coverage outcome, while multiple applicable zones return an overlap outcome.
Zone membership is not inferred from a relay branch.

For a primary breaker failure, only backup relays listed by the applicable
zone are eligible. They must have operated in the integrated fault result,
have an available breaker in a clearable state, not be disabled, and not be
blocked by a configured reverse, unsupported, or indeterminate directional
result. When multiple backups are eligible, the one with the smallest
modeled relay-operating-time plus breaker-delay is selected. If none can
clear the fault, the status is `NOT_CLEARED_BY_MODELED_PROTECTION`.

The evaluator reports relay CTI as `t_backup_relay - t_primary_relay` and
clearing-time margin as `t_backup_relay - t_primary_total_clearing`. These
remain distinct quantities. Arc interruption, current-zero behavior, breaker
interrupting capability, breaker-failure timing logic, and transient fault
decay are unsupported.
