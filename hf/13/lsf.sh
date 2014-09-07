#This script subscribe an lsf job into boomer
if [ -e "$1.out" ]; then
 rm $1.out
fi
touch $1.out
bsub <<- EOF
#BSUB -J $1
#BSUB -q normal
#BSUB -a openmpi
#BSUB -x
#BSUB -n 2
#BSUB -R "span[ptile=2]"
#BSUB -o std_out/%J_stdout.txt
#BSUB -e std_out/%J_stderr.txt
#
#
#BSUB -W 00:30
#
#BSUB -B francesco_talotta@hotmail.com
#BSUB -N francesco_talotta@hotmail.com


export MPI_COMPILER=intel # intel OR gnu OR pgi OR nag
export MPI_HARDWARE=ib # ib (Infiniband) OR gige (Gigabit Ethernet)
export MPI_SOFTWARE=openmpi # Only commment this if you compiled with it off.

mpirun.lsf /home/ftalotta/software/nwchem-6.3/bin/LINUX64/nwchem $1.nw > $1.out
EOF
