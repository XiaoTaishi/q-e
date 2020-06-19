# Quantum Espresso for Fermi softness

This package is modified based on QE and implements Fermi softness calculation.

## What is Fermi softness (FS)?

Fermi softness is a property to accurately quantify chemical reactivity of solid surfaces developed by Prof. Lin Zhuang (Wuhan University). For more information, please refer to [Angew. Chem. Int. Ed. 2016, 55, 6239-6243](https://doi.org/10.1002/anie.201601824).

## HOW TO USE

### Install

```Shell
./configure
make all
```

### Submit task

General procedure can be found on [./PP/examples/FermiSoftness_example/fermi_softness.sh](https://github.com/idocx/q-e/tree/master/PP/examples/FermiSoftness_example/fermi_softness.sh). You must get the wavefunction files before calculating Fermi softness (`OPT -> SCF -> NSCF -> FS`).

For more info, you can refer to the original repo (https://github.com/QEF/q-e).

## Options

The input file for Fermi softness has following format. (example: [./PP/examples/FermiSoftness_example/HfN_111.fs.in](https://github.com/idocx/q-e/tree/master/PP/examples/FermiSoftness_example/HfN_111.fs.in))

```Fortran
&INPUTPP
	prefix = "*prefix of files saved by program pw.x*"
	outdir = "*directory containing the input data, i.e. the same as in pw.x*"
	filplot = "*file 'filplot' contains the quantity selected by plot_num*"
	plot_num = 23  ! this flag represents option of calculating Fermi softness
/

&PLOT
	iflag = 3  ! 3D plot
	fileout = "*Output file's name*"
	output_format = 6  ! cube file
/
```

You should submit the task with `pp.x` submodule.
```Shell
pp.x -i xxx.fs.in > xxx.fs.out
```

You can find a gird file with the name of `$fileout` after calculation.

## Visualization

You can project the Fermi softness value to a given surface using [VMD](https://www.ks.uiuc.edu/Research/vmd/).

## Alternative source

If you find it too slow to clone this repo from Github, you can also download it from [a mirror server](https://yuxingfei.com/src/qe.tar.gz).
