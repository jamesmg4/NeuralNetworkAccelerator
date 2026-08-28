# Single-MAC Matrix-Vector Baseline Measurements

This document records the first performance baseline for the INT8 matrix-vector
accelerator. It explains how each result is measured, shows the calculations
used to derive the reported metrics, and describes why each metric matters.

These numbers describe RTL simulation behavior. Area, maximum clock frequency,
physical latency, and products per second will be added after synthesis and
static timing analysis.

## Baseline architecture

The measured design uses:

- One signed INT8 multiply-accumulate unit.
- A signed 32-bit accumulator.
- One `DotProductController` inside one `MatrixVectorController`.
- A row-major weight matrix.
- One-cycle synchronous activation and weight memory models.
- A `FETCH` cycle followed by a `SEND` cycle for each operand pair.
- An always-available output-memory write port.
- No multiplier pipeline and no parallel MAC lanes.

The baseline parameter sweep covers:

```text
1×1, 1×4, 4×1, 2×3, 4×4, and 8×8 weight matrices
```

For a weight matrix with `R` rows and `C` columns:

```text
Activation vector: C×1
Output vector:     R×1
Useful products:   R×C
Output writes:     R
```

Each product is accumulated into the dot product for its output row.

## Measurement environment

Measurements are collected by `tb/MatrixVectorController_tb.sv`. All counters
exist only in the testbench and do not add hardware to the synthesized design.

The measurement window begins on the rising edge where `start_accepted` is
true. It ends when `done` asserts after the final output has been written.

```text
start accepted                                      done asserted
      │                                                   │
      ├────────────── measurement window ─────────────────┤
```

For every dimension, the testbench uses two types of input data:

1. A deterministic, dimension-independent matrix and activation vector.
2. Ten signed randomized jobs whose results are calculated independently by a
   testbench reference loop.

Every deterministic and randomized job produces the same performance results
because control latency depends on matrix dimensions, not operand values.

Run the measurement with:

```sh
cd AcceleratorModules/tb
make matvec
```

Run lint and all functional tests with:

```sh
make lint
make test
```

## Baseline results

| Matrix | Latency | Busy | Accepted pairs | Writes | MAC utilization | Products/cycle |
|---:|---:|---:|---:|---:|---:|---:|
| 1×1 | 3 | 3 | 1 | 1 | 33.33% | 0.3333 |
| 1×4 | 9 | 9 | 4 | 1 | 44.44% | 0.4444 |
| 4×1 | 12 | 12 | 4 | 4 | 33.33% | 0.3333 |
| 2×3 | 14 | 14 | 6 | 2 | 42.86% | 0.4286 |
| 4×4 | 36 | 36 | 16 | 4 | 44.44% | 0.4444 |
| 8×8 | 136 | 136 | 64 | 8 | 47.06% | 0.4706 |

Typical simulation output is:

```text
latency=36 cycles, busy=36 cycles, accepted pairs=16, output writes=4
MAC utilization=44.44%, products/cycle=0.4444
```

## Total latency

Total latency is the number of rising clock edges required to complete one
entire matrix-vector request after its start command is accepted.

The testbench increments `total_latency_cycles` during the measurement window.
It also maintains a separate task-level elapsed-cycle counter and fails the
test if the two counters disagree.

For every matrix row, the current controller uses:

```text
COLS FETCH cycles
COLS SEND cycles
1 WAIT_RESULT cycle
= 2×COLS + 1 cycles per row
```

For a 4×4 matrix:

```text
latency = ROWS × (2 × COLS + 1)
        = 4 × (2 × 4 + 1)
        = 4 × 9
        = 36 cycles
```

Latency matters because it describes how long a single request takes. After
static timing analysis determines the clock period, cycle latency can be
converted into physical time:

```text
latency time = latency cycles × clock period
```

Reducing cycle latency or clock period reduces the time required for one
matrix-vector operation.

## Busy cycles

A busy cycle is a measured cycle in which the controller asserts `busy`.

The testbench measures it with behavior equivalent to:

```systemverilog
if (busy)
    busy_cycles <= busy_cycles + 1;
```

The controller is busy in `FETCH`, `SEND`, and `WAIT_RESULT`. It is not busy in
`IDLE` or `FINISH`.

For every measured configuration:

```text
busy cycles = latency cycles
```

This means the controller does not return to an idle state in the middle of a
job. It does not mean that the MAC performs useful arithmetic during all 27
cycles. `FETCH` and `WAIT_RESULT` are busy control cycles without a newly
accepted product.

Busy time matters to a system scheduler because another job cannot be started
while the accelerator is occupied.

## Accepted operand pairs

One operand pair contains one activation and one weight. The pair is counted
only when the ready/valid input handshake succeeds:

```systemverilog
dotp_input_accepted = dotp_in_valid && dotp_in_ready;
```

The testbench increments `accepted_operand_pairs` only on this event. Counting
the handshake rather than `dotp_in_valid` prevents a stalled pair from being
counted repeatedly.

The expected number is:

```text
accepted pairs = ROWS × COLS
```

In this single-MAC architecture, every accepted pair corresponds to one useful
multiplication and accumulation. This metric is both a work count and a
correctness check: too few pairs would omit products, while too many would
duplicate products.

## Output writes

`output_write` tells the output memory to store `output_data` at `output_addr`
on the current rising edge.

Each weight row produces one element of the output vector, so:

```text
output writes = ROWS
```

The testbench checks both the number of writes and every stored result. The
write count matters because correct-looking data alone would not detect every
missing or duplicate output transaction. It also describes the minimum output
bandwidth required by the accelerator.

## MAC utilization

MAC utilization measures the fraction of busy cycles that accept useful
arithmetic work. For the 4×4 configuration:

```text
MAC utilization = accepted operand pairs / busy cycles
                = 16 / 36
                = 0.4444
                = 44.44%
```

The remaining 55.56% of busy cycles are scheduling overhead in this baseline:

```text
16 FETCH cycles
4 WAIT_RESULT cycles
= 20 non-accepting busy cycles
```

This result matters because the design pays the area cost of a MAC even when
the MAC is not accepting a new pair. The sweep ranges from 33.33% utilization
for one-column matrices to 47.06% for the 8×8 matrix. Longer rows amortize the
single result cycle, but the alternating `FETCH` and `SEND` schedule prevents
utilization from reaching 50%. A future design can be compared against these
numbers to determine whether prefetching or pipelining keeps the MAC active
more often.

The testbench uses an accepted input pair as the definition of useful MAC work.
This is valid for the present fixed-latency MAC because every accepted pair
causes exactly one accumulation.

## Products per cycle

Products per cycle measures useful work relative to complete request latency.
For the 4×4 configuration:

```text
products per cycle = accepted operand pairs / total latency cycles
                   = 16 / 36
                   = 0.4444 products/cycle
```

It currently equals MAC utilization because busy cycles equal latency cycles.
They are still distinct metrics:

- MAC utilization divides by cycles for which the controller reports `busy`.
- Products per cycle divides by the complete measured request latency.

Products per cycle becomes physical throughput after synthesis determines a
safe clock frequency:

```text
products per second = products per cycle × clock frequency
```

Because the clock frequency has not been measured yet, this report does not
claim a products-per-second result.

## Interpretation

All six configurations pass deterministic testing and ten randomized jobs per
configuration. Accepted-pair counts, output-write counts, and cycle latency all
match their dimension-derived expectations.

The principal performance limitation is the alternating `FETCH` and `SEND`
schedule. Every useful `SEND` cycle is preceded by a memory-fetch cycle. The
baseline is intentionally retained because it is simple and verified. Future
prefetching, pipelining, or parallel-lane designs should be evaluated using the
same measurement definitions and test cases.

## Measurements still pending

RTL simulation cannot determine physical area or maximum clock frequency. The
following measurements require synthesis and static timing analysis for a
documented target technology:

- Standard-cell or FPGA resource area.
- Critical-path delay.
- Maximum safe clock frequency.
- Physical latency in seconds.
- Products per second and MACs per second.

These results should be appended without replacing the cycle-level baseline.
