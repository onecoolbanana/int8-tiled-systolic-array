# Tiled Systolic Array Matrix Multiplier

A 4×4 output-stationary systolic array in SystemVerilog that multiplies 16×16 INT8
matrices by tiling the problem across the array. Written for Icarus Verilog,
targeting FPGA synthesis (MAX 10 / DE10-Lite).

`C = A · B` where A and B are 16×16 INT8 and C is 16×16 INT32.

Current: **1092 cycles**, down from 3075 at first working version — a 2.8× speedup
from memory restructuring and output-side pipelining.

---

## How it works

The array is 4×4, so a 16×16 multiply is decomposed into tiles:

```
C[I][J] = Σ_K  A[I][K] · B[K][J]        I, J, K ∈ {0..3}
```

64 tile-multiplies, in loop order I → J → K with K innermost.

**Accumulation happens inside the PEs.** Each PE holds a 32-bit accumulator cleared
once per *output* tile, then accumulated across all four K steps. This avoids
draining the array and summing partials externally after every K step — the array
drains 16 times rather than 64, and the adders are the ones already inside the PEs.

**Data is pre-skewed in the tile buffers.** PE(r,c) receives its operand pair for
step k at cycle `k + r + c`, because A propagates rightward and B downward one PE
per cycle. The loader writes each tile into a 4×7 buffer with row `r` offset by `r`,
so streaming the buffer column by column produces the required diagonal wavefront:

```
a_buf[0] =   0    0    0   a00  a01  a02  a03
a_buf[1] =   0    0   a10  a11  a12  a13   0
a_buf[2] =   0   a20  a21  a22  a23   0    0
a_buf[3] =  a30  a31  a32  a33   0    0    0
```

`b_buf[c]` holds *column* c of the B tile, since PE column `c` must receive B's
column `c`.

**Operands live in two separate 32-bit memories** so an A word and a B word are read
in the same cycle. A is stored transposed, because at step k the array needs
`a_in_row[r] = A[r][k]` — a column of A. Transposing makes that one contiguous read.
B is needed as `b_in_row[c] = B[k][c]`, a row, so it stays row-major.

**Results are latched into shadow registers** at the end of the drain, so the store
of output tile (I,J) overlaps with the compute of (I,J+1) rather than stalling the
array for 17 cycles.

---

## Modules

| File | Module | Role |
|---|---|---|
| `pe.sv` | `pe` | Single MAC cell. INT8 × INT8 → INT32 accumulate, with `acc_clr`. Registers and forwards `a_out`/`b_out`. |
| `systolic_array.sv` | `systolic_array` | 4×4 generate grid of PEs. A flows left→right, B flows top→bottom. |
| `tile_loader.sv` | `tile_loader` | Fetches one A tile and one B tile in parallel from the two operand memories and writes them into the pre-skewed buffers. **5 cycles.** |
| `tile_sequencer.sv` | `tile_sequencer` | The FSM. Walks the (I, J, K) loop nest and issues all control: `acc_clr`, `stream_en`, `store_buffer`, and the loader/writer handshakes. |
| `result_writer.sv` | `result_writer` | Serialises the 16 shadowed accumulators to the result memory. 17 cycles, overlapped with compute. |
| `accelerator.sv` | `accelerator` | Structural top for simulation. Holds the stream mux, the shadow register bank, and all three memories. |
| `memory.sv` | `ram`, `result_memory` | Parameterised synchronous memories. |
| `gen_weights.py` | — | Generates `mem_a.hex`, `mem_b.hex`, and a golden `expected.hex`. |

### Control flow

```
IDLE ─start─► CLEAR ─► LOAD ─► STREAM ─┬─ K<3 ─► LOAD
                ▲                      │
                │                      └─ K=3 ─► DRAIN ─► STORE ─► WAIT_LAST
                └──────────────────────────────────┘        (last tile only)
                     (advance I,J; latch shadow, fire and forget)
```

`CLEAR` is entered once per output tile, immediately before K=0. During `LOAD` the
array inputs are forced to zero, so every PE computes `acc + 0·0 = acc` and the
accumulators hold across the gap. `DRAIN` waits for the final operand to reach
PE(3,3). `STORE` latches the accumulators and their destination tile indices into
the shadow bank, issues `store_start`, and moves on without waiting — only the
final tile waits for `store_done` before asserting `done`.

---

## Memory map

**`mem_a`** (64 × 32) — A packed **transposed**. Word `col*4 + rowgroup` holds
A column `col`, rows `rowgroup*4 .. +3`. `word[7:0]` is the lowest row index.

**`mem_b`** (64 × 32) — B packed **row-major**. Word `row*4 + colgroup` holds
B row `row`, columns `colgroup*4 .. +3`. `word[7:0]` is the lowest column index.

**`result_memory`** (256 × 32) — `C[i][j]` at word address `i*16 + j`.

Both operand addresses have the same shape, which is a useful check that the
packing is right:

```systemverilog
assign addr_a = (tile_k*4 + e)*4 + tile_i;
assign addr_b = (tile_k*4 + e)*4 + tile_j;
```

---

## Building and running

```bash
python gen_weights.py identity      # A random, B = I, so C == A
python gen_weights.py single        # A[5][9] = 1, so C row 5 == B row 9
python gen_weights.py random 42     # both random signed
python gen_weights.py random 42 --check    # also prints expected loader fetches

iverilog -g2012 -o accel.vvp rtl/*.sv
vvp accel.vvp
```

The testbench reads `expected.hex`, compares it against the result memory after
`done`, and reports a cycle count and mismatch count.

`identity` verifies addressing and skew. `random` is the test that matters — it is
the only one where all four byte lanes of every word carry distinct negative
values, which is where a packing-order or signedness error would hide.

Each module also has a standalone testbench. `tile_loader` and `tile_sequencer` in
particular are worth testing in isolation: addressing and loop-ordering bugs are
far cheaper to find there than through 64 tiles of full datapath.

---

## Performance

| Version | Cycles | MACs/cycle | Utilisation |
|---|---|---|---|
| Baseline — single byte-wide memory, no overlap | 3075 | 1.33 | 8.3% |
| Split `mem_a`/`mem_b`, widened to 32-bit | 1347 | 3.04 | 19.0% |
| Shadow registers on the accumulator output | **1092** | **3.75** | **23.4%** |

4096 MACs; array peak is 16 MACs/cycle.

### Where the time went, and why

The first working version was **8% utilised**. Profiling showed the array idle for
most of its cycles waiting on memory: the 4×4 grid consumes 8 bytes per cycle and a
single byte-wide port supplies 1, so loading a tile pair took 32 reads to feed 7
cycles of compute.

Splitting A and B into separate 32-bit memories made one word equal one tile row
and let both reads issue in the same cycle. Load dropped from 33 cycles to 5, for a
2.3× overall speedup.

That left the 17-cycle store as the next largest idle block. Latching the
accumulators into shadow registers let the writer run concurrently with the next
tile's compute, costing 512 flops and recovering another 19%.

Current breakdown, ~68 cycles per output tile:

| Phase | Cycles | Share |
|---|---|---|
| Stream (4 × 7) | 28 | 41% |
| Load (4 × 5) | 20 | 29% |
| Drain | 4 | 6% |
| FSM transitions | ~16 | 24% |

Store no longer appears — it runs entirely in the shadow of the next tile.

---

## Roadmap

**1. Double-buffer the tile registers.** Load tile K+1 while streaming tile K.
Ping-pong select rather than a copy, with the loader latching its own tile indices
at `load_start` so the sequencer can advance freely. Saves 3 × 5 cycles per output
tile (K=0 has nothing to overlap with). Estimated **~850 cycles**.

**2. Parameterise `N` and `MAT` throughout**, including tile-index widths, buffer
width `2N-1`, and the Python packer.

**3. Scale to 8×8.** With `TILES = MAT/N = 2` the loop nest becomes 8 tile-multiplies
instead of 64, and operand words widen to 64 bits. Expected ~300 cycles — but at
64 multipliers rather than 16, so utilisation should *fall*: bandwidth scales as
`N` while compute scales as `N²`. Measuring both sizes is the point.

**4. Continuous K-streaming.** Remove the gap between K steps entirely, dropping
streaming from `2N-1` cycles per tile to `N`. Requires replacing the broadcast
`acc_clr` with a `first` flag that travels alongside A through the skew path so it
self-times to `t = k + r + c` at each PE.

**5. A-tile reuse across J.** With loop order I → J → K, the A tiles for a fixed I
are identical for every J. Caching them cuts A traffic 4×.

**6. Host interface.** UART plus a command parser (`write-mem`, `read-mem`, `start`,
`read-status`) and an arbiter between the host and accelerator ports. A `pyserial`
host script drives the board and compares against a NumPy reference. Note the
DE10-Lite's onboard USB is JTAG-only, so this needs an external USB-UART module.

**7. Arbitrary dimensions.** `M`, `K`, `P` as runtime registers, with zero-padding
in the loader when a dimension is not a multiple of `N` — if the computed index
exceeds the real dimension, feed 0 instead of issuing a read. The array never
knows.

Theoretical floor for a 4×4 array on this problem is 256 cycles.

---

## Known limitations

- Dimensions fixed at 16×16; address arithmetic is written in terms of `N` and
  `MAT` but the values are hardcoded.
- No overflow detection. INT32 accumulators cannot overflow for 16×16 INT8 inputs
  (worst case ±2²¹), but larger matrices would need checking.
- No activation or requantisation stage. This is a plain matrix multiplier —
  intended as the compute core of a CNN inference engine, but not one yet.
- `$readmemh` initialisation is simulation-only and needs replacing with the UART
  load path for hardware.
- Not yet synthesised or timed on real hardware.
