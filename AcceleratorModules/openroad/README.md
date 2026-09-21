# OpenROAD baseline

This directory contains the project-owned OpenROAD Flow Scripts configuration.
The OpenROAD repository and generated build products remain outside this Git
repository.

The baseline configuration uses:

- `MatrixVectorController` as the top-level design
- the SkyWater SKY130 high-density (`sky130hd`) platform
- a 3x4 weight matrix
- a 10 ns (100 MHz) target clock
- 35% initial core utilization

Assuming `OpenROAD-flow-scripts` and this repository are siblings, launch the
Docker flow from the accelerator repository root:

```sh
../OpenROAD-flow-scripts/flow/util/docker_shell -- \
  make DESIGN_CONFIG=/work/AcceleratorModules/openroad/sky130hd/config.mk
```

OpenROAD's Docker launcher mounts the directory from which it is invoked at
`/work`, which is why the configuration uses `/work` as its default project
root.

For a host installation instead of Docker, run the OpenROAD makefile with an
absolute project path:

```sh
make -C ../OpenROAD-flow-scripts/flow \
  DESIGN_CONFIG="$PWD/AcceleratorModules/openroad/sky130hd/config.mk" \
  NN_ACCEL_ROOT="$PWD"
```

Keep the baseline parameters and constraints unchanged for the first completed
run. Subsequent clock-period or matrix-size sweeps should be recorded as
separate experiments so their timing and area results remain comparable.
