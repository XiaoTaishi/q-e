#!/bin/bash

# set default core num
CORENUM=16
RUN=srun
WORKING_DIR=$(pwd)
FILENAME=$(basename $WORKING_DIR)
TASK=""

# this function is used for verifying the valiadity of parameters
isValidArg() {
    echo $1
    if [[ "${1:0:1}" && "-" && "$1" ]]; then
        return 1
    else
        return 0
    fi
}

while [ "$1" ]
    do
        case "$1" in
            -n|--core-num)
                if [[ $(isValidArg "$2") ]]; then
                    CORENUM="$2"
                    shift 2
                else
                    shift 1
                fi
                ;;
            -t|--task)
                if [[ $(isValidArg "$2") ]]; then
                    TASK="$2"
                    shift 2
                else
                    shift 1
                fi
                ;;
            -m|--module)
                if [[ $(isValidArg "$2") ]]; then
                    MODULE="$2"
                    shift 2
                else
                    shift 1
                fi
                ;;
            -h|--help)
                cat  << _EOF_

-------------------------------------------------------------------
|                         USER GUIDE                              |
-------------------------------------------------------------------
This shell script is used to launch QE (Quantum Espresso) task in a
cluster that has slrum environment.
                
!!SPECIAL NOTE!!
The folder's name must be the same as the prefix of the input file.
e.g. Pt3Y_111 is a feasible folder name for launching a task named
"Pt3Y_111.opt.in".

Arguments                 Usage

-n[--core-num]            Specify the core number that is used. 
                          16 by default.

-t[--task]                Specify the task that is going to be executed.
                          This must match the suffix of the corresponding 
                          intput file. For example, scf for the SCF
                          calculation and the name of input file must be
                          "Pt_111.scf.in".

-m[--module]              Specify the module that is used by calculation.
                          For common task, it will be decided automatically
                          according to the task name.

-h[--help]                Show all valid arguments and their usage.

_EOF_
                exit 1
                ;;
            *)
                echo Invalid arguments, use "-h[--help]" to show all the valid arguments.
                exit 0
                ;;
        esac
    done

# decide which module to use
if [[ -z "$MODULE" ]]; then
    case "$TASK" in
        opt|scf|nscf)
            MODULE="pw.x";;
        charge|pdos|ldos)
            MODULE="pp.x";;
	all)
	    MODULE="all";;
        *)
        echo "qe.sh: Unknown operation, please specify both the module name using -m[--module] and the task name using -t[--task]"
        exit -1
        ;;
    esac
fi

echo "Set CORENUM = $CORENUM"
echo "Set MODULE = $MODULE"
echo "Set TASK = $TASK"

echo "Running the program..."
if [[ "$MODULE" -eq "all" ]]; then
    ${RUN} -n ${CORENUM} pw.x -i ${FILENAME}.scf.in > ${FILENAME}.scf.out
    if [[ $? -eq 0 ]]; then
        echo "scf calculation completed"
    fi 
   ${RUN} -n ${CORENUM} pw.x -i ${FILENAME}.nscf.in > ${FILENAME}.nscf.out
    if [[ $? -eq 0 ]]; then
        echo "nscf calculation completed"
    fi
    ${RUN} -n ${CORENUM} pp.x -i ${FILENAME}.charge.in > ${FILENAME}.charge.out
    if [[ $? -eq 0 ]]; then
        echo "charge density calculation completed"
    fi
    ${RUN} -n ${CORENUM} pp.x -i ${FILENAME}.fs.in > ${FILENAME}.fs.out
    if [[ $? -eq 0 ]]; then
        echo  "fermi softness calculation completed"
    fi
else
    ${RUN} -p hpxg -n ${CORENUM} ${MODULE} -i ${FILENAME}.${TASK}.in > ${FILENAME}.${TASK}.out
fi

if [[ $? -eq 0 ]]; then
	echo "$TASK finished successfully."
fi
