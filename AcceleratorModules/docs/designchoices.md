# INT8 MAC and Dot-Product Engine Design Choices

This document records the design decisions made for the first version of the
INT8 multiply-accumulate (MAC) and dot-product controller. These choices favor
a small, understandable, and verifiable design that can later be replicated or
widened for a neural-network accelerator.

## Datapath

### Signed INT8 operands

The operands `a` and `b` are signed 8-bit two's-complement values. One MAC can
therefore accept one pair of scalar INT8 values per clock cycle.

The interface is intentionally scalar rather than an entire vector presented in
parallel. A vector is streamed through the module one element pair at a time.
This keeps the first implementation small and reduces memory bandwidth and
wiring requirements. Future versions can instantiate multiple MAC lanes to
process several element pairs per cycle.

### Product and accumulator widths

Multiplying two signed 8-bit values produces a signed 16-bit product. The
product is explicitly sign-extended before it is added to the signed 32-bit
accumulator.

The 32-bit accumulator was selected to support dot products substantially
longer than an INT8 product width alone would permit. The current design does
not detect or saturate accumulator overflow. A wider accumulator may be needed
if future workloads accumulate very long vectors or combine partial sums.

### No product pipeline register

The multiplication is combinational and the resulting product is accumulated
on an enabled rising clock edge. There is no registered multiplication stage.
This avoids accidentally accumulating the previous cycle's product and gives
the MAC a simple throughput of one accepted element pair per cycle.

Pipelining is deferred until synthesis and timing results show that the
combinational multiplier limits the target clock frequency.

## MAC control interface

The MAC has `clear` and `enable` controls instead of its own ready/valid
handshake:

- `clear = 1` clears the accumulator to zero on the rising clock edge.
- Otherwise, `enable = 1` adds the current `a * b` product to the accumulator.
- Otherwise, the accumulator holds its value.
- `clear` has priority over `enable` if both are asserted.

The MAC has fixed latency and cannot stall, so a separate MAC-level handshake
is unnecessary. The surrounding dot-product controller is responsible for
flow control and drives `enable` only when an input transfer occurs.

## Dot-product controller

### MAC ownership

The dot-product controller instantiates one `INT8_MAC`. The controller owns
vector length tracking and handshakes; the MAC owns multiplication and
accumulation. Arithmetic is not duplicated in the controller.

### Input ready/valid handshake

The input contains `a`, `b`, `vec_len`, `in_valid`, and `in_ready`.

- The upstream producer asserts `in_valid` when `a`, `b`, and the applicable
  metadata are valid.
- The controller asserts `in_ready` when it can accept an element pair.
- An element transfers only on a rising edge where both signals are high.

The internal name for this transfer event is:

```systemverilog
input_fire = in_valid && in_ready;
```

`fire` is project terminology for a successful ready/valid transfer; it is not
a SystemVerilog keyword. `mac_enable` is equal to `input_fire`, ensuring that a
stalled or invalid input is never accumulated or counted.

The controller asserts `in_ready` in both `IDLE` and `MAC`:

- In `IDLE`, it is ready for the first pair of a new vector.
- In `MAC`, it is ready for the next pair of the current vector.
- In `DONE`, it stops accepting inputs until the current result is consumed.

### Vector-length protocol

`vec_len` is an unsigned 16-bit element count. It is sampled with the first
successful input transfer and stored in `len_reg`. Its value on later pairs of
the same vector is ignored.

The upstream producer must supply a vector contiguously in transaction order,
although it may insert cycles with `in_valid = 0`. Once a vector begins, pairs
from another vector must not be interleaved with it.

The current interface supports lengths from 1 through 65,535. A length of zero
is invalid because an input pair is already being presented; defensively, the
controller treats `vec_len = 0` as a one-element vector so it cannot lock up.

### Element counter

`count` is 16 bits because it tracks the number of accepted elements against
the 16-bit `vec_len`. It increments only on `input_fire`, so input bubbles and
stalls do not change the count.

`next_element_count` is 17 bits and represents `count + 1` for the element being
accepted on the current edge. The extra bit prevents the addition from wrapping
before the controller compares it with `len_reg`.

### Output ready/valid handshake

The output contains `acc`, `acc_valid`, and `acc_ready`.

- The controller asserts `acc_valid` when `acc` contains a complete dot product.
- The downstream consumer asserts `acc_ready` when it can accept that result.
- The result transfers only on a rising edge where both signals are high.

The internal transfer event is:

```systemverilog
output_fire = acc_valid && acc_ready;
```

While `acc_valid = 1` and `acc_ready = 0`, the controller remains in `DONE`,
holds the result stable, and applies backpressure by deasserting `in_ready`.
When `output_fire` occurs, the MAC accumulator is cleared and the controller
returns to `IDLE`.

This version does not accept the first pair of a new vector in the same cycle
that the previous result is consumed. That introduces a boundary bubble but
keeps the control and accumulator ownership simple. This can be optimized later
if measurements show that it materially limits throughput.

### Controller states

The controller uses three states:

- `IDLE`: waiting for and accepting the first input pair.
- `MAC`: accepting the remaining pairs of the current vector.
- `DONE`: holding a completed result until the output handshake occurs.

## Reset behavior

`rst_n` is an asynchronous active-low reset for both modules. It immediately
returns the controller to `IDLE`, clears its length and count registers, and
clears the MAC accumulator.

The MAC's ordinary `clear` input is synchronous and is currently asserted when
a completed result is consumed.

## Verification

Permanent self-checking testbenches use Icarus Verilog in SystemVerilog mode.
They cover:

- Positive, negative, zero, and boundary INT8 operands.
- MAC enable, hold, clear priority, and reset behavior.
- Single-element and multi-element dot products.
- Input bubbles and output backpressure.
- Reset during an unfinished dot product.
- A randomized signed 32-element dot product checked against a testbench model.

The tests are located in `tb/` and can be run with:

```sh
cd AcceleratorModules/INT8_MAC/tb
make
```

## Deliberately deferred decisions

The following are not part of this first version and should be decided using
system-level requirements and synthesis measurements:

- The number of parallel MAC lanes.
- Multiplier or adder pipelining.
- SRAM/register-file organization and required read bandwidth.
- Bias addition, activation functions, rounding, requantization, and INT8
  saturation.
- Accumulator overflow handling or a wider accumulator.
- Support for multiple dot products in flight.
- Removing the one-cycle transaction-boundary bubble.
