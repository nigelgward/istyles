# prepMetadata.sh, in istyles/code,  for getting Switchboard metadata into a Matlab-friendly format 
# Nigel Ward, June 2020
# to run
#   cd istyles/swbd-various
#   bash ../code/prepMetadata.sh

awk '{if ($2=="\"A\",") {print substr($1,1,4), 0,  substr($3,1,4), substr($6, 1, 3)} else {print substr($1,1,4), 1, substr( $3,1,4), substr($6, 1, 3)}}' /cygdrive/f/nigel/comparisons/en-swbd/ldc-docs/call_con_tab.csv > call_con_tab_numeric.csv
# gives fields: file, side, speaker, topic

awk '{if ($4=="\"MALE\",") {print substr($1,1,4), 0, substr($5,1,4)} else {print substr($1,1,4), 1, substr($5,1,4)}}' /cygdrive/f/nigel/comparisons/en-swbd/ldc-docs/caller_tab.csv > caller_tab_numeric.csv
# gives field: speaker, gender, birthyear

sort -k3 call_con_tab_numeric.csv > cctn_sorted.csv

join -1 3  cctn_sorted.csv caller_tab_numeric.csv | awk '{print $2, $3, $1, $5, $6, $4}' > metadata.txt

# output lines are filenum, side, speaker, isFemale, birthyear,  topic

# where the content of each topic is in ldc-docs/topic_tab.csv
