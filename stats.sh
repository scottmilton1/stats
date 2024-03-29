#!/bin/sh
#
# Name:        stats.sh
# Author:      Scott Milton
# Date:        10/19/15
# Description: This shell script will calculate averages and medians from an
#              an input file of numbers or from standard input. The script
#              accepts command line arguments, validates them for correctness,
#              and calculates the statistics across rows or columns based on
#              the command line instructions.
#
# general format for command is
# stats {-rows | cols} [input_file]
#
################################################################################



################################################################################
## Function:        validateInt()   
## Description:     This function validates a parameter to make sure it is an
##                  integer. Negative integers are accepted.
## Parameters:      takes one unnamed parameter, the value to validate
## Pre-conditions:  an argument is passed to the function
## Post-conditions: The argument has been validated as an integer. If it is not
##                  a valid integer, an error message is output to standard
##                  error and the program exits with an unsuccessful return
##                  value.
## 
################################################################################
validateInt ()
{
  # compare first argument to regex for integer values
  if ! [[ "$1" =~ ^-?+[[:digit:]]+$ ]]
  then
    echo -e "stats: input values must be integers.\n" >&2
    exit 1
  fi

  return 0
}



################################################################################
## Function:        calculateAvg()
## Description:     This function calculates an average value by dividing a sum
##                  by a count of terms and rounding the result.
## Parameters:      takes two unnamed parameter, the first is the sum value
##                  and the second is a count of the number of terms in
##                  the string.
## Pre-conditions:  both arguments are integers. the first should be larger
##                  than the second
## Post-conditions: The average value has been calculated and stored in the 
##                  global variable $avg.
## 
################################################################################
calculateAvg ()
{
  floor=`expr $1 / $2` # $1 is $sum and $2 is $count of terms / lines

  # determine significant digit for rounding
  fraction=`expr $1 \* 10 / $2 - $floor \* 10`

  # round based on value of significant digit
  if [[ $fraction -ge 5 ]]
  then
    avg=`expr $floor + 1` # round up
  else
    avg=$floor # leave rounded down
  fi

  return 0
}



################################################################################
## Function:        calculateMedian()
## Description:     This function calculates a median value from a string of
##                  integers separated by newline characters.
## Parameters:      takes two unnamed parameter, the first is the string of
##                  integers and the second is a count of the number of terms in
##                  the string.
## Pre-conditions:  the first argument passed to the function is a string and
##                  the second is an integer
## Post-conditions: The median value has been calculated and stored in the
##                  global variable $med.
## 
################################################################################
calculateMedian ()
{
  # determine how many terms to cut from string in order to reach median
  firstHalf=`expr $2 / 2 + 1`

  # get the median 
  med=$(echo "$1" | sort -n | cut -d$'\n' -f ${firstHalf}- | head -1)

  return 0
}



valid=1
option=${1:0:2} # get first two character of first command-line argument

# validate args and disqualify anything invalid
# case: command has too few or too many args
if [[ "$#" -lt 1 || "$#" -gt 2 ]]
then
  valid=0 

# case: first arg is not string that begins with lower case '-c' or '-r'
elif [[ $option != '-c' && $option != '-r' ]]
then 
  valid=0

# case: second argument is switch (begins with dash), not filename
# technically, filename could begin with a dash, but generally not done
elif [[ "$#" -eq 2 && ${2:0:1} = '-' ]]
then
  valid=0
fi

# if args were invalid, send error message to standard error and exit
if [ $valid == 0 ]
then
  echo -e "Usage: stats {-rows|-cols} [file]\n" >&2
  exit 1
fi

# if file name given store it in variable in preparation for reading data
if [[ "$#" -eq 2 ]]
then
  FILE=$2

  # check to make sure file exists and is readable
  if ! [[ -e "$FILE" && -r "$FILE" ]]
  then
    echo -e "stats: cannot read $FILE \n" >&2
    exit 1
  fi

# otherwise, if file name not provided get input from stdin
else
  #echo -e '\nEnter any number of integers separated by spaces.'
  #echo -e '\nEnd each line of integers with a carriage return.'
  #echo -e '\nPush <ctrl> + d when finished.'

  # store user input in temp file with process id in name
  FILE=TMP_$$ 
  cat > $FILE

  # set up trap to catch interrupt, hangup, and terminate signals and remove
  # the temp file if program terminates unexpectedly
  trap "rm -f TMP_$$; exit 1" INT HUP TERM
fi

# calculate the number of terms in the first row and store in variable
# for assignment, we can assume that all rows have the same number of terms 
read line<$FILE # read one line
count=$(echo "$line" | wc -w) # get word count of the line

# determine which option user selected (rows or columns + process accordingly
if [ $option == '-r' ]
then
  printf '\nAverage Median\n'
 
  sum=0
  str=$(echo -e "\n") 

  # read one line at a time and store terms in array  
  while read -a line
  do        
    # calculate and display average (mean)
    for num in "${line[@]}" # iterate over terms stored in array
    do
      # check to make sure current $num is an integer
      validateInt "$num"

      # add it to the sum
      sum=`expr $sum + $num`
      
      # build string version of line to help calculate median below
      str=$(echo -e "$num\n$str")
    done

    # call function to calculate average
    # since BASH does not allow return values (aside from exit status),
    # the calculated value is stored in the global variable $avg
    calculateAvg "$sum" "$count"

    # call function to calculate median
    calculateMedian "$str" "$count"
    
    echo -e "$avg\t$med"
    sum=0
    str=""
  done < $FILE


elif [ $option = '-c' ]
then
  printf '\nAverages:\n'
    
  # found help here: http://www.cyberciti.biz/faq/linux-unix-applesox-bsd-bash-cstyle-for-loop/
  for ((i=0; i<${count}; i++)); # this gets the ith term for calculations
  do
    sum=0
    lineCount=0
    str=$(echo -e "\n")

    # read one line at a time and store terms in array
    while read -a line 
    do
      # get only the ith term from each line
      num="${line[$i]}"

      # check to make sure it is an integer 
      validateInt "$num"
 
      # add it to the sum
      sum=`expr $sum + $num`

      #build a string to help calculate the median
      str=$(echo -e "$num\n$str")

      lineCount=`expr $lineCount + 1`
     
    done < $FILE

    # store each string of column data in array
    arr[$i]=$str

    # call function to calculate average.
    calculateAvg "$sum" "$lineCount"

    echo -ne "$avg\t"
  done
 
  # calculate and display median
  printf '\nMedians:\n'
  
  for ((i=0; i<${count}; i++));
  do
    # get the ith column stored in array
    str="${arr[$i]}"

    # call function to calculate the median
    calculateMedian "$str" "$lineCount" 
    
    echo -ne "$med\t"  
  done
  printf '\n'
fi

printf '\n'

# remove the temp file (if it was created) and exit normally
if [[ "$#" -ne 2 ]]
then
  rm -f TMP_$$
fi
exit 0
