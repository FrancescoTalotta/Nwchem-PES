#!/bin/bash
# Version 3.2beta
# 3.2: Added time print and average time calculation
# This part is also executed from the main script main.sh
# Executing this script alone, aviod the recalculation of all data
# Added the search of the minimal energy and corresponding 
# minimal distance. Added the normalization of the energy 
# with the reference energy (energy at 100 angstrom), and 
# conversion into kJ/mol, and the second plot

out=results.out

#read from main.sh file
filename=$(grep 'filename=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | tr -d ' ')
graphtitle=$(grep 'graphtitle=' "main.sh" | cut -f2 -d"'" | cut -f1 -d"#")
xmin=$(grep 'xmin=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
xmax=$(grep 'xmax=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
ymax=$(grep 'ymax=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
init=$(grep 'init=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
step=$(grep 'step=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
end=$(grep 'end=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')
lastgeom=$(grep 'lastgeom=' "main.sh" | cut -f2 -d"=" | cut -f1 -d"#" | sed -e 's/[ \t]*$//')

cat /dev/null > $out #erase all previous informations
echo "-------------RESULTS-------------" >> $out
date >> $out #insert the current date
echo '' >> $out

if [ -e "fit.log" ];then
 rm fit.log
fi

if [ -e "${filename}_$lastgeom.00.out" ]; then
 mv ${filename}_$lastgeom.00.out ${filename}_100.out
fi

minenergy=0.0
counter=0
total=0
maxtime=0.0
maxtimegeom=0.0

for file in $(ls ${filename}_*.out | sort -V | rev |cut -c 5- |rev) ; do  #this reads from the files and extract only the name

#Check the convergence
if grep -q 'MCSCF Converged' "$file.out";
 then
 #For time calculation
 counter=$((counter+1))
 tim=$(grep -E 'Total times  cpu:' "$file.out" | grep -oE '[^ ]+$')
 time2=$(echo ${tim%?})
 total=$(echo "$total+$time2" | bc -l )
 if [ $(echo "$time2 > $maxtime" | bc) -eq 1 ]; then      #Search for the max time 
    maxtime=$time2                       
    maxtimegeom=$file                   
 fi


 echo "$file converged time $tim" >>$out
 warning=0
else 
 echo "$file NOT converged" >>$out
 warning=1
 fi
 done

 echo '' >> $out
 echo "Mean time is: $(echo "$total/($counter*60)" | bc) minutes, $(echo "$total/($counter)" | bc)s" >> $out
 echo "Max time is: ${maxtime}s, did by $maxtimegeom" >> $out
 echo '' >> $out

 echo "Energy are:" >> $out
 graph=graph.dat	     #Data file, containing the distance and the energies in Hartree
 graph2=graph_kj.dat    #Data file, containing the distance and normalized energies in kcal/mol
 rif=${filename}_${lastgeom}		     #Reference file at $lastgeom Angstrom

 if [ -e "$rif.out" ]; then 		#check if the reference file exist
 rifen=$(grep 'Total MCSCF energy' "$rif.out" | cut -f2 -d"=")   #Reference energy at 100 Angstrom
 else
 echo "Can't find $rif file"
# exit 0
 fi

 cat /dev/null > $graph   #erase last data
 cat /dev/null > $graph2   #erase last data

 for file in $(ls ${filename}_*.out | sort -V | rev |cut -c 5- |rev) ; do  #this reads from the files and extract only the name

 lengh=$(echo "$(echo ${#filename})+2" | bc)	#lengh of the character #filename
xcoord=$(echo $file | cut -c ${lengh}-)
	tim=$(grep -E 'Total times  cpu:' "$file.out" | grep -oE '[^ ]+$')

	echo "Distance (A)"=$xcoord >> $out
	value=$(grep 'Total MCSCF energy' "$file.out")  #| sed -e 's/^[ \t]*//' >> $out   #sed, to remove black space before
	echo $value   $tim >> $out
	energy=$(grep 'Total MCSCF energy' "$file.out" | cut -f2 -d"=")
	if [ -e "$rif.out" ]; then
	ennorm=$(echo "$energy - $rifen" | bc -l)  #normalized energies. 
	enkjmol=$(echo "$ennorm*627.503" | bc -l)  #conversion from Hartree to kcal/mol\
		fi

		echo "${xcoord} ${energy}" >> $graph
		echo "${xcoord} ${enkjmol}" >> $graph2

		if [ $(echo "$energy < $minenergy" | bc) -eq 1 ]; then      #Search for the minimal energy
		minenergy=$energy							 #Export it with the equilibrium distance
		eqdist=$xcoord							 
		fi
		done

#Output some usefull info into $out file
		echo '' >> $out
		echo '-------------------------------------------------------' >> $out
		echo 'Minimal parameters:' >> $out
		echo '' >> $out
		echo "Minimal Energy=$minenergy (Hartree)" | sed -e 's/^[ \t]*//' >> $out   #sed, to erase the blank spaces
		echo "Equilibrium Distance=$eqdist (Angstrom)" >> $out

		if [ -e "$rif.out" ]; then
		minenkj=$(echo "scale=2;(($minenergy-$rifen)*627.503)/1" | bc -l) #Export the minimal energy in kcal/mol. The /1 is to enable the scale
		echo "Minimal Energy=$minenkj (kcal/mol)" >> $out
		fi


#Gnuplot plot in hartree 
		gnuplot <<- EOF
		set terminal postscript enhanced color
		set output "graph.ps"
		set title "$graphtitle"
		set  autoscale                        # scale axes automatically
		set xrange [0:10]
		set yrange [$minenergy-0.1:-75.0]
		unset log                              # remove any log-scaling
		unset label                            # remove any previous labels
		set xtic 1.0                           # set xtics to 1 interval
		set mxtics 2
		set ytic auto                          # set ytics automatically
#set label "{${FILE}}" at 18,100
		set encoding iso_8859_1
		set xlabel "Distance (\305)"
		set ylabel "Energy (a.u.)"
#set arrow 1 from 0.0 to 20,0 nohead
#set xzeroaxis
		plot "${graph}" using 1:2 title "CASSCF Energy" with linespoints lw 2 pt 7
		EOF

#Gnuplot plot in kJ/mol normalized energies + polinomial fitting with x**15
		if [ -e "$rif.out" ]; then
		gnuplot <<- EOF
		set terminal postscript enhanced color
		set output "graph_kj.ps"
		set title "$graphtitle"
		set  autoscale                        # scale axes automatically
		set xrange [$xmin:$xmax]
		set yrange [$minenkj-10:$ymax]
		unset log                              # remove any log-scaling
		unset label                            # remove any previous labels
		set xtic 1.0                           # set xtics to 1 interval
		set mxtics 2
		set ytic auto                          # set ytics automatically
		set encoding iso_8859_1
		set label "{E_{min}= ${minenkj} (kcal/mol)}" at 1.3,-50 # plot the min energy
		set label "{R_{m}= ${eqdist} (\305)}" at 1.3,-80	# plot the eq distance
		set xlabel "Distance (\305)"
		set ylabel "Energy (kcal/mol)"
#set arrow 1 from 0.0 to 20,0 nohead
	set xzeroaxis
#f(x)=-e*((r/x)**12-2*(r/x)**6)
	f(x)=a+b*x+c*x**2+d*x**3+e*x**4+f*x**5#+f*x**6+g*x**7+h*x**8+i*x**9+l*x**10+m*x**11+n*x**12+o*x**13+p*x**14+q*x**15
#e=$minenkj
#r=$eqdist
	a=b=c=d=e=f=g=h=i=l=m=n=o=p=q=r=s=1
	fit [$eqdist-0.1:$eqdist+0.2] f(x) '${graph2}' using 1:2 via a,b,c,d,e,f#,g,h,i,l,m,n,o,p,q
	plot f(x) title "Fitting",  "${graph2}" using 1:2 title "CASSCF Energy" with points lw 2 pt 7
	EOF
#evince graph_kj.ps
#Extracting fitting parameters from gnuplot fit.log file 
	row1=$(grep -rne 'Final set of param' fit.log | cut -f1 -d":" | sed -e 's/[ \t]*$//')
	row2=$(grep -rne 'correlation matrix' fit.log | cut -f1 -d":" | sed -e 's/[ \t]*$//')

	a=$(sed -n "$row1,${row2}p" fit.log | grep 'a[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
	b=$(sed -n "$row1,${row2}p" fit.log | grep 'b[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
	c=$(sed -n "$row1,${row2}p" fit.log | grep 'c[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
	d=$(sed -n "$row1,${row2}p" fit.log | grep 'd[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
	e=$(sed -n "$row1,${row2}p" fit.log | grep 'e[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
	f=$(sed -n "$row1,${row2}p" fit.log | grep 'f[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#g=$(sed -n "$row1,${row2}p" fit.log | grep 'g[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#h=$(sed -n "$row1,${row2}p" fit.log | grep 'h[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#i=$(sed -n "$row1,${row2}p" fit.log | grep 'i[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#l=$(sed -n "$row1,${row2}p" fit.log | grep 'l[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#m=$(sed -n "$row1,${row2}p" fit.log | grep 'm[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#n=$(sed -n "$row1,${row2}p" fit.log | grep 'n[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#o=$(sed -n "$row1,${row2}p" fit.log | grep 'o[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#p=$(sed -n "$row1,${row2}p" fit.log | grep 'p[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')
#q=$(sed -n "$row1,${row2}p" fit.log | grep 'q[[:space:]]\{15\}' | cut -f2 -d"=" | cut -f1 -d"+" | sed -e 's/^[ \t]*//')

	if [ ! -e "min" ]; then
	echo 'Min program not exist'
	echo 'Stop'
	exit 0
	fi

#Calling the min fortran program to find the minimal energy from gnuplot fitting function
	forres=$(echo -e "$a\n$b\n$c\n$d\n$e\n$f\n$eqdist" | ./min)

	forminen=$(echo $forres | cut -f2 -d' ')
	forminx=$(echo $forres | cut -f1 -d' ')
	forminenhr=$(echo "scale=12;$forminen/627.503+$rifen" | bc -l) #Reconversion of energy from kcal to hartree in absolute manner

#Plotting fitted equilibrium distance and energy
	echo "Equilibrium distance from fitting=$forminx (Angstrom)" >> $out
	echo "Minimal energy from fitting= $forminen (Kcal/mol)" >> $out
	echo "Minimal energy from fitting (not scaled)= $forminenhr (Hartree)" >> $out
fi
