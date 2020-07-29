#!\bin\bash

# istyles/code/trimSwitchboard.sh
# Nigel Ward, May 2020

# many Switchboard files have some junk at the end that causes
#   my cepstral flux computation to output pure NaNs
#   (a few NaNs can be easily dealt with, but not 50-100%)
# empirically, this is vastly reduced by trimming off the last second
#   which this code does 

# to use, run from any directory full of .wav files, e.g switchboard/disc1/wavfiles
#  then source ..../trimSwitchboard.sh

for infile in $(ls *wav)
do

    echo nice sox $infile "${infile%%.*}"tr.wav fade 0 -1 0.01
    nice sox $infile "${infile%%.*}"tr.wav fade 0 -1 0.01
done    
