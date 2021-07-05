#!/bin/bash
# in the Switchboard directory :
# for discX in disc1 disc2 disc3 disc4
#    mkdir wavfiles
#    cd data
#    bash sph-to-wav.bash
# end
for infile in $(ls *sph)
do
    echo "${infile%%.*}".wav
    echo nice sox $infile ../wavfiles/"${infile%%.*}".wav
    nice sox $infile ../wavfiles/"${infile%%.*}".wav
done

    
