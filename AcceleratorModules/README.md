# INT8 Matrix-Vector Accelerator

Parameterized SystemVerilog RTL for a single-MAC matrix-vector engine. Given a
row-major signed INT8 weight matrix and a signed INT8 activation vector, the
design computes one signed 32-bit output per row:

```text
output[row] = sum(weight[row][col] * activation[col])
```

This repository is a baseline for exploring RTL verification, throughput, and
area/timing tradeoffs. The verified system currently uses the unpipelined
`INT8_MAC`; `INT8_MACPipeline` is a separate experiment and is **not** connected
to the controller or included in the baseline results below.

## Architecture

```text
activation and weight memories (external, synchronous-read)
                         |
                         v
              MatrixVectorController
                         |
                         v
               DotProductController
                         |
                         v
                     INT8_MAC
                         |
                         v
              output memory (external)
```

- `MatrixVectorController` sequences rows and columns, generates memory
  addresses, and writes each completed output.
- `DotProductController` accepts operand pairs through a ready/valid interface,
  tracks vector length, and holds each result until it is accepted.
- `INT8_MAC` multiplies signed 8-bit operands and accumulates their products in
  a signed 32-bit register. The baseline has one MAC lane.
- The testbench models one-cycle synchronous activation and weight reads. The
  memories themselves are not part of the synthesized controller.

The current controller alternates a `FETCH` cycle and a `SEND` cycle for each
operand pair, then waits for the row result. This favors straightforward
control and verification over peak MAC utilization.

## Measured baseline

These are **RTL simulation** results, not timing-closed hardware measurements.
Latency is counted from accepted `start` to `done`; products/cycle is useful
products divided by that latency.

| Matrix | Latency (cycles) | Accepted pairs | Output writes | Products/cycle |
| --- | ---: | ---: | ---: | ---: |
| 1x1 | 3 | 1 | 1 | 0.3333 |
| 1x4 | 9 | 4 | 1 | 0.4444 |
| 4x1 | 12 | 4 | 4 | 0.3333 |
| 2x3 | 14 | 6 | 2 | 0.4286 |
| 4x4 | 36 | 16 | 4 | 0.4444 |
| 8x8 | 136 | 64 | 8 | 0.4706 |

## Status and next steps

- **Verified baseline:** the unpipelined RTL passes lint and self-checking
  simulation. The 4x4 quick-start command above was rerun successfully.
- **Synthesis:** a previous generic Yosys run reported 783 technology-independent
  cells and zero structural problems for the default 3x4 configuration. This is
  not a silicon-area, FPGA-resource, or maximum-frequency measurement. A
  reproducible synthesis command/script still needs to be added here.
- **Pipeline experiment:** `INT8_MACPipeline.sv` registers the product and its
  valid bit, but the surrounding controller and testbenches have not yet been
  updated for its extra latency. It is not part of the measured baseline.
- **Planned measurements:** map both designs to a documented FPGA or standard-
  cell target; report area, critical-path delay, clock frequency, and physical
  throughput alongside the cycle-level baseline.
