#!/bin/bash
# Created by Francesco Talotta. v3.1beta
# 3.0 Modified for lsf queue system into boomer
# 2.0 Lots of improvments 
# 1.5:Added the searching of the right linear indipendent parameter 
# 1.4:Added the energy normalization and conversion in kJ/mol in res.sh
# 1.4:Added the second graph_kj with normalizated energies in kJ/mol in res.sh
# This script calculate the right geometry for a biatomic system, 
# equal to $i values of distance in angstrom. After that it create the CASSCF Nwchem 
# input and execute it. Distances are Angstrom

##############################      SETTINGS     ###################################
#-----------------------------------------------------------------------------------
procs=16     	# number of processors
walltime=01:00
filename=hf      # filename 
init=100.00   	# intial geometry control
end=100.00		# end geometry control
step=0.04		# step geometry control
forced=2.00		#the distance at what (>) the ortogonality is not forced
lastgeom=100	# the distance ot the asymtotic geometry
xmin=0	      # gnuplot variables	
xmax=2
ymax=25
graphtitle='H-F Potential energy curve'
res=no		      #if you want to execute the result script
execlast=no	      	#if you want to execute the asymptotic geometry calculus
#------------------------------------------------------------------------------------

counter=0
echo -e "Version \e[1;34m3.1\e[0m"

#assign the right tale value
if [ $(echo "$procs>=16" | bc) -eq 1 ]; then
 tale=16
else 
 tale=$procs
fi

if [ ! -d "std_out" ]; then
 mkdir std_out
fi

# For various configurations from $init to $end angstrom, with step equal of $step angstrom
for i in {0..100000..1}; do
 xcoord=$(echo "$init+$i*$step"  | bc -l | sed 's/^\./0./')   #For the linear molecules
 if [ $(echo "$xcoord>$end" | bc) -eq 1 ]; then			  #Exit from the i cycle when reached $end
   if [[ "$execlast" = "yes" ]]; then
     xcoord=$lastgeom							  #Do the asympotitc geometry
     else
     break
   fi
 fi

 file=${filename}_$xcoord

 counter=$((counter+1))
#Check for previous calculus and delete the files
 if [ -e "$file.out" ]; then
  rm "$file.out"
 if [ -e "file.db" ]; then
  rm "$file.db"
 fi
  if [ -e "$file.moves" ]; then
   rm "$file.movecs"
  fi
  if [ -e "$file.civec" ]; then
   rm "$file.civec"
  fi
 fi

if [  $(echo "$xcoord>$forced" | bc) -eq 1 ]; then   #this if is for create the right nwchem input greater than 0
					       #always true, never execute the forced calc
 touch ${file}.nw      #Create the new Nwchem input file
 cat >${file}.nw <<EOL
title "${file}"
scratch_dir /scratch/ftalotta/
memory heap 100 mb stack 1200 mb global 600 mb
geometry units an print
 f 0.0000	 0.0000	 0.0000
 h ${xcoord}	 0.0000	 0.0000
 symmetry c1
end
 
basis
 f library aug-cc-pvqz
 h library aug-cc-pvqz
end

charge 0

#set lindep:tol 1.0d-6
set tolguess 1e-7

scf
 singlet
 rhf
 maxiter 1000
end
 
task scf energy

mcscf
 active 10
 actelec 6
 multiplicity 1
 maxiter 1000
 #level 0.5
end
 
task mcscf energy
EOL

#touch $file.out  #creating the out file to benig the reading of the output
#tail -f $file.out > mypipe & #redirecting the tail -f to mypipe...to read it from another terminal do "cat mypipe
echo -e "\e[1;36mScheduling ${file}\e[0m"
if bjobs | grep -q "$file"; then   #check if there is a same filename 
id=$( bjobs | grep "$file" | cut -f1 -d' ')
bsub -w "done($id) || exit($id)" <<- EOF      
#BSUB -J $file
#BSUB -q normal
#BSUB -a openmpi
#BSUB -x
#BSUB -n $procs
#BSUB -R "span[ptile=$tale]"
#BSUB -o std_out/%J_stdout.txt
#BSUB -e std_out/%J_stderr.txt
#
#
#BSUB -W $walltime
#
#BSUB -B francesco_talotta@hotmail.com
#BSUB -N francesco_talotta@hotmail.com


export MPI_COMPILER=intel # intel OR gnu OR pgi OR nag
export MPI_HARDWARE=ib # ib (Infiniband) OR gige (Gigabit Ethernet)
export MPI_SOFTWARE=openmpi # Only commment this if you compiled with it off.

mpirun.lsf /home/ftalotta/software/nwchem-6.3/bin/LINUX64/nwchem ${file}.nw > ${file}.out
EOF
 echo -e "\e[91mDependent from $id process\e[0m"
else 
 bsub <<- EOF      
#BSUB -J $file
#BSUB -q normal
#BSUB -a openmpi
#BSUB -x
#BSUB -n $procs
#BSUB -R "span[ptile=$tale]"
#BSUB -o std_out/%J_stdout.txt
#BSUB -e std_out/%J_stderr.txt
#
#
#BSUB -W $walltime
#
#BSUB -B francesco_talotta@hotmail.com
#BSUB -N francesco_talotta@hotmail.com


export MPI_COMPILER=intel # intel OR gnu OR pgi OR nag
export MPI_HARDWARE=ib # ib (Infiniband) OR gige (Gigabit Ethernet)
export MPI_SOFTWARE=openmpi # Only commment this if you compiled with it off.

mpirun.lsf /home/ftalotta/software/nwchem-6.3/bin/LINUX64/nwchem ${file}.nw > ${file}.out
EOF
fi

else 
 touch ${file}.nw      #Create the new Nwchem input file
 cat >${file}.nw <<EOL
title "${file}"
scratch_dir /scratch/ftalotta/
memory heap 100 mb stack 1200 mb global 600 mb
geometry units an print
 f 0.0000	 0.0000	 0.0000
 h ${xcoord}	 0.0000	 0.0000
 symmetry c1
end
 
basis
 f library aug-cc-pvqz
 h library aug-cc-pvqz
end

charge 0

set lindep:tol 1.0d-9
set tolguess 1e-7

scf
 singlet
 rhf
 maxiter 300
end
 
task scf energy

mcscf
 active 10
 actelec 6
 multiplicity 1
 maxiter 300
 #level 0.5
end
 
task mcscf energy
EOL

echo -e "\e[1;35mSubmitting the forced ${file}\e[0m"
if bjobs | grep -q "$file"; then   #check if there is a same filename in the queue 
id=$( bjobs | grep "$file" | cut -f1 -d' ')
 bsub -w "done($id) || exit($id)" <<- EOF  
#BSUB -J $file
#BSUB -q normal
#BSUB -a openmpi
#BSUB -x
#BSUB -n $procs
#BSUB -R "span[ptile=$tale]"
#BSUB -o std_out/%J_stdout.txt
#BSUB -e std_out/%J_stderr.txt
#
#
#BSUB -W $walltime
#
#BSUB -B francesco_talotta@hotmail.com
#BSUB -N francesco_talotta@hotmail.com

export MPI_COMPILER=intel # intel OR gnu OR pgi OR nag
export MPI_HARDWARE=ib # ib (Infiniband) OR gige (Gigabit Ethernet)
export MPI_SOFTWARE=openmpi # Only commment this if you compiled with it off.

mpirun.lsf /home/ftalotta/software/nwchem-6.3/bin/LINUX64/nwchem ${file}.nw > ${file}.out
EOF
 echo -e "\e[91mDependend from $id process\e[0m"
else           #in there is not files with the same name in queue 
 bsub <<- EOF      
#BSUB -J $file
#BSUB -q normal
#BSUB -a openmpi
#BSUB -x
#BSUB -n $procs
#BSUB -R "span[ptile=$tale]"
#BSUB -o std_out/%J_stdout.txt
#BSUB -e std_out/%J_stderr.txt
#
#
#BSUB -W $walltime
#
#BSUB -B francesco_talotta@hotmail.com
#BSUB -N francesco_talotta@hotmail.com


export MPI_COMPILER=intel # intel OR gnu OR pgi OR nag
export MPI_HARDWARE=ib # ib (Infiniband) OR gige (Gigabit Ethernet)
export MPI_SOFTWARE=openmpi # Only commment this if you compiled with it off.

mpirun.lsf /home/ftalotta/software/nwchem-6.3/bin/LINUX64/nwchem ${file}.nw > ${file}.out
EOF
fi

fi	#this end the first if for the 

echo ''
 if [ $(echo "$xcoord==$lastgeom" | bc) -eq 1 ]; then    #if we are in the last geom 
   break								   #the cycle exits
 fi	
done  #This is the end of the i cycle
bjobs

#tput smso
echo -e "\e[0;36mTotal number of calc submitted=${counter}\e[0m"
#tput rmso

#Send notification when all is done
#curl -s \
#  -F "token=abLTvahG1cQxRGRqRiRHMickYmbdAx" \
#  -F "user=uyuWYTsNG5RePrrnCS9YinGqwQvtqt" \
#  -F "message=Done with ${filename} Nwchem calc." \
#  https://api.pushover.net/1/messages.json

#execute the res.sh 
#if [[ "$res" = "yes" ]]; then
#sh ./res.sh
#fi
