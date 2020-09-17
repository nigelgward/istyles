#!/usr/bin/awk
# Nigel Ward, August 2020

# this is called by wordstats/runStats.sh
#   which is written by wordFreqAnalysis.m
# the input is in three columns: word, count in "zone", count in Switchboard
#   the "zone" is the 10% of tracks closest to a pole

# it's interesting to look at low frequency words, especially place names
#   and person names, but also rather distracting, so don't show them

BEGIN{
    getline < "swbd-various/swbdTotal.txt";
    totalSwbdCount = $0;
    getline < zoneTotal;  # a command-line parameter
    totalZoneCount = $0;
}
{
    if ($3 > 30) {
	ratioInZone = $2 / totalZoneCount;
	ratioInSwbd = $3 / totalSwbdCount;
	overallRatio = ratioInZone / ratioInSwbd;
	if ($3 > 15500) {
	    printf("%4.2f\t%12s** (%.5f/%.5f) \n",  overallRatio, $1, ratioInZone,ratioInSwbd); }
	else if (overallRatio > 2.0 || overallRatio < 0.5) {
	    printf("%4.2f\t%12s   (%.5f/%.5f) \n",  overallRatio, $1, ratioInZone,ratioInSwbd); }
    }
}
END{
    printf("0.51 -----------------------------------------------------\n")
    printf("1.00 -----------------------------------------------------\n")
    printf("1.99 -----------------------------------------------------\n")
}

