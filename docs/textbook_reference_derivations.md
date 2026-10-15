# Textbook Independent Reference Cases & Symmetrical Component Derivations

This document presents independent, step-by-step hand calculations for balanced and unbalanced faults on a textbook power system network. These derivations do **not** call the simulator code; they serve as independent analytical truth benchmarks for unit tests.

---

## 1. Textbook Network Parameters

- **System Power Base:** $S_{\text{base}} = 100\text{ MVA}$
- **System Voltage Base:** $V_{\text{base}} = 11\text{ kV}$ (Line-to-Line RMS)
- **Base Current:**
  $$I_{\text{base}} = \frac{S_{\text{base}}}{\sqrt{3} \times V_{\text{base}}} = \frac{100 \times 10^6}{\sqrt{3} \times 11\,000} = \frac{100\,000}{11\sqrt{3}} \approx 5248.638024\text{ A}$$
- **Base Impedance:**
  $$Z_{\text{base}} = \frac{V_{\text{base}}^2}{S_{\text{base}}} = \frac{11\,000^2}{100 \times 10^6} = 1.21\,\Omega$$
- **Prefault Thevenin Voltage:**
  $$V_{\text{th}} = 1.0\angle 0^\circ\text{ pu} = 1.0 + j0.0\text{ pu}$$
- **Thevenin Sequence Impedances:**
  - Positive sequence: $Z_1 = 0.0 + j0.25\text{ pu}$
  - Negative sequence: $Z_2 = 0.0 + j0.25\text{ pu}$
  - Zero sequence: $Z_0 = 0.0 + j0.50\text{ pu}$

---

## 2. Symmetrical Sequence Fault Derivations

### Case 1: Symmetrical Three-Phase Fault (3PH)

In a balanced 3-phase fault, the negative- and zero-sequence networks are inactive ($I_2 = 0, I_0 = 0$).
The sequence equation is:
$$I_1 = \frac{V_{\text{th}}}{Z_1 + Z_f}$$

#### 1A. Bolted ($Z_f = 0$):
$$I_1 = \frac{1.0}{j0.25} = -j4.0\text{ pu} \implies |I_f| = 4.0\text{ pu}$$
$$I_{f,\text{amp}} = 4.0 \times 5248.638024 = 20\,994.5521\text{ A}$$

#### 1B. Fault Impedance ($Z_f = 0.05\text{ pu}$):
$$Z_{\text{total}} = 0.05 + j0.25\text{ pu}$$
$$|Z_{\text{total}}| = \sqrt{0.05^2 + 0.25^2} = \sqrt{0.0025 + 0.0625} = \sqrt{0.065} \approx 0.25495097568\text{ pu}$$
$$|I_1| = \frac{1.0}{0.25495097568} \approx 3.922322703\text{ pu}$$
$$I_{f,\text{amp}} = 3.922322703 \times 5248.638024 \approx 20\,586.848\text{ A}$$

---

### Case 2: Single-Line-to-Ground Fault (SLG, Phase A to Ground)

For a phase-A to ground fault, sequence networks are connected in series:
$$I_0 = I_1 = I_2 = \frac{V_{\text{th}}}{Z_1 + Z_2 + Z_0 + 3Z_f}$$
The faulted phase current is:
$$I_a = I_0 + I_1 + I_2 = 3 I_1 = \frac{3 V_{\text{th}}}{Z_1 + Z_2 + Z_0 + 3Z_f}$$

#### 2A. Bolted ($Z_f = 0$):
$$Z_{\text{total}} = Z_1 + Z_2 + Z_0 = j0.25 + j0.25 + j0.50 = j1.0\text{ pu}$$
$$I_1 = \frac{1.0}{j1.0} = -j1.0\text{ pu}$$
$$I_a = 3(-j1.0) = -j3.0\text{ pu} \implies |I_a| = 3.0\text{ pu}$$
$$I_{f,\text{amp}} = 3.0 \times 5248.638024 = 15\,745.9141\text{ A}$$

#### 2B. Fault Impedance ($Z_f = 0.05\text{ pu}$):
$$Z_{\text{total}} = 3(0.05) + j(0.25 + 0.25 + 0.50) = 0.15 + j1.0\text{ pu}$$
$$|Z_{\text{total}}| = \sqrt{0.15^2 + 1.0^2} = \sqrt{0.0225 + 1.0} = \sqrt{1.0225} \approx 1.01118742\text{ pu}$$
$$|I_1| = \frac{1.0}{1.01118742} \approx 0.98893635\text{ pu}$$
$$|I_a| = 3 \times 0.98893635 \approx 2.96680905\text{ pu}$$
$$I_{f,\text{amp}} = 2.96680905 \times 5248.638024 \approx 15\,571.706\text{ A}$$

---

### Case 3: Line-to-Line Fault (LL, Phase B to Phase C)

For a fault between phases B and C with impedance $Z_f$ connected directly between them:
$$I_0 = 0$$
$$I_1 = -I_2 = \frac{V_{\text{th}}}{Z_1 + Z_2 + Z_f}$$
Phase currents:
$$I_a = 0$$
$$I_b = -I_c = -j\sqrt{3} I_1 \implies |I_b| = |I_c| = \sqrt{3} |I_1|$$

#### 3A. Bolted ($Z_f = 0$):
$$Z_1 + Z_2 = j0.25 + j0.25 = j0.50\text{ pu}$$
$$I_1 = \frac{1.0}{j0.50} = -j2.0\text{ pu}$$
$$|I_b| = \sqrt{3} \times 2.0 = 2\sqrt{3} \approx 3.464101615\text{ pu}$$
$$I_{f,\text{amp}} = 2\sqrt{3} \times 5248.638024 \approx 18\,181.821\text{ A}$$

#### 3B. Fault Impedance ($Z_f = 0.05\text{ pu}$):
$$Z_{\text{total}} = 0.05 + j0.50\text{ pu}$$
$$|Z_{\text{total}}| = \sqrt{0.05^2 + 0.50^2} = \sqrt{0.2525} \approx 0.50249378\text{ pu}$$
$$|I_1| = \frac{1.0}{0.50249378} \approx 1.9900744\text{ pu}$$
$$|I_b| = \sqrt{3} \times 1.9900744 \approx 3.4469106\text{ pu}$$
$$I_{f,\text{amp}} = 3.4469106 \times 5248.638024 \approx 18\,091.59\text{ A}$$

---

### Case 4: Double-Line-to-Ground Fault (DLG, Phases B and C to Ground)

For a B-C to ground fault with impedance $Z_f$ in each faulted phase branch to ground:
$$Z_{\text{parallel}} = \frac{Z_2 (Z_0 + 3Z_f)}{Z_2 + (Z_0 + 3Z_f)}$$
$$I_1 = \frac{V_{\text{th}}}{Z_1 + Z_{\text{parallel}}}$$
$$I_2 = -I_1 \left( \frac{Z_0 + 3Z_f}{Z_2 + Z_0 + 3Z_f} \right)$$
$$I_0 = -I_1 \left( \frac{Z_2}{Z_2 + Z_0 + 3Z_f} \right)$$

#### 4A. Bolted ($Z_f = 0$):
$$Z_{\text{parallel}} = \frac{j0.25 \times j0.50}{j0.25 + j0.50} = \frac{-0.125}{j0.75} = j\frac{1}{6} \approx j0.16666667\text{ pu}$$
$$Z_{\text{total}} = Z_1 + Z_{\text{parallel}} = j0.25 + j\frac{1}{6} = j\frac{5}{12}\text{ pu} \approx j0.41666667\text{ pu}$$
$$I_1 = \frac{1.0}{j(5/12)} = -j2.40\text{ pu}$$
$$I_2 = j2.40 \times \frac{0.50}{0.75} = j1.60\text{ pu}$$
$$I_0 = j2.40 \times \frac{0.25}{0.75} = j0.80\text{ pu}$$

Phase currents:
$$I_a = I_0 + I_1 + I_2 = j0.80 - j2.40 + j1.60 = 0$$
$$I_b = I_0 + a^2 I_1 + a I_2 = -3.4641016 + j1.2\text{ pu} = -2\sqrt{3} + j1.2\text{ pu}$$
$$|I_b| = \sqrt{(-2\sqrt{3})^2 + 1.2^2} = \sqrt{12 + 1.44} = \sqrt{13.44} \approx 3.666060556\text{ pu}$$
$$|I_c| = |I_b| \approx 3.666060556\text{ pu}$$
#### 4B. Fault Impedance ($Z_f = 0.05\text{ pu}$):
$$Z_g = Z_0 + 3Z_f = j0.50 + 3(0.05) = 0.15 + j0.50\text{ pu}$$
$$Z_{\text{den}} = Z_2 + Z_g = j0.25 + (0.15 + j0.50) = 0.15 + j0.75\text{ pu}$$
$$Z_{\text{parallel}} = \frac{Z_2 \cdot Z_g}{Z_2 + Z_g} = \frac{j0.25 \times (0.15 + j0.50)}{0.15 + j0.75} = \frac{-0.125 + j0.0375}{0.15 + j0.75}$$
Multiplying numerator and denominator by the complex conjugate $(0.15 - j0.75)$:
$$|Z_{\text{den}}|^2 = 0.15^2 + 0.75^2 = 0.0225 + 0.5625 = 0.585$$
$$Z_{\text{parallel}} = \frac{(-0.125 + j0.0375)(0.15 - j0.75)}{0.585} = \frac{0.009375 + j0.099375}{0.585} = \frac{1}{62.4} + j0.16987179\text{ pu}$$
$$Z_{\text{total}} = Z_1 + Z_{\text{parallel}} = j0.25 + 0.01602564 + j0.16987179 = 0.01602564 + j0.41987179\text{ pu}$$
$$|Z_{\text{total}}| = \sqrt{0.01602564^2 + 0.41987179^2} \approx 0.4201775\text{ pu}$$
Sequence currents:
$$I_1 = \frac{1.0}{0.01602564 + j0.41987179} \approx 0.09077156 - j2.37821483\text{ pu} \implies |I_1| \approx 2.3799446\text{ pu}$$
$$I_2 = -I_1 \left(\frac{Z_g}{Z_{\text{den}}}\right) \approx 0.09077156 + j1.62178517\text{ pu} \implies |I_2| \approx 1.6243232\text{ pu}$$
$$I_0 = -I_1 \left(\frac{Z_2}{Z_{\text{den}}}\right) \approx -0.18154312 + j0.75642965\text{ pu} \implies |I_0| \approx 0.7779038\text{ pu}$$
Phase currents:
$$I_a = I_0 + I_1 + I_2 = 0$$
$$I_b = I_0 + a^2 I_1 + a I_2 \implies |I_b| \approx 3.90489754\text{ pu}$$
$$I_c = I_0 + a I_1 + a^2 I_2 \implies |I_c| \approx 3.38746542\text{ pu}$$
$$I_{f,\text{max,pu}} = \max(|I_b|, |I_c|) \approx 3.90489754\text{ pu}$$
$$I_{f,\text{max,amp}} = 3.90489754 \times 5248.638024 \approx 20\,495.39\text{ A}$$
Ground return current:
$$I_g = 3 I_0 = 3(-0.18154312 + j0.75642965) \implies |I_g| \approx 3 \times 0.77790985 \times 5248.638024 \approx 12\,248.90\text{ A}$$

