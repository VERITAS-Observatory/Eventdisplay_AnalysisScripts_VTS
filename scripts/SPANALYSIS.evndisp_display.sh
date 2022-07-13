#!/bin/bash
# display data files with eventdisplay

if [ ! -n "$1" ] || [ "$1" = "-h" ]; then
# begin help message
echo "
EVNDISP special-purpose analysis: display data file and write results to file

SPANALYSIS.evndisp_display.sh <run number> [telescope combination] [calib] [highres] [TARGET] [WOBBLENORTH] [WOBBLEEAST] [RAOFFSET]

Note that not all parameters are the standard parameters used for the typical analysis.

required parameter:

    <run number>            run number of VERITAS data file (vbf or cvbf file)

optional parameters:
 
    [teltoana]              use 1 for T1 only, 13 for T1 and T3 only, etc.
                            (default telescope combination is 1234)
                            
    [calib]		    0 or nocalib for -nocalibnoproblem, 1 or db for -readCalibDB [default], 2 or raw for -plotraw & -nocalibnoproblem

    [highres]		    0 or lowres for regular window, 1 or highres for -highres (default), 2 or paper for -plotpaper

    [TARGET]                target name (Crab, Mrk421, 1es2344, lsi+61303)
                            (for more do 'evndisp -printtargets')
                            
    [WOBBLENORTH]           wobble offsets north (e.g. 0.5) or south (e.g. -0.5)
                            in units of degrees
    
    [WOBBLEEAST]            wobble offsets east (e.g. 0.5) or west (e.g. -0.5)
                            in units of degrees
    
    [RAOFFSET]              right ascension offset for off run
                            (e.g. 7.5 for off run 30 min later)

--------------------------------------------------------------------------------
"
#end help message
exit
fi

# Run init script
bash $(dirname "$0")"/helper_scripts/UTILITY.script_init.sh"
[[ $? != "0" ]] && exit 1

# Parse command line arguments
RUN=$1
[[ "$2" ]] && TELTOANA=$2 || TELTOANA="1234"
if [[ $TELTOANA == "-1" ]]; then
    TELTOANA="1234"
fi

if [[ "$3" == "0" ]] || [[ "$3" == "nocalib" ]] ; then
	CALIBOPT=" -nocalibnoproblem "
elif   [[ "$3" == "2" ]] || [[ "$3" == "raw" ]] ; then 
	CALIBOPT=" -plotraw -nocalibnoproblem "
else
	CALIBOPT=" -readCalibDB "
fi

PLOTOPT=" -highres "
if [[ "$4" == "1" ]] || [[ "$4" == "highres" ]]; then
	PLOTOPT=" -highres "
elif [[ "$4" == "0" ]] || [[ "$4" == "lowres" ]]; then
	PLOTOPT=" "
elif   [[ "$4" == "2" ]] || [[ "$4" == "paper" ]] ; then 
	PLOTOPT=" -highres -plotpaper "
fi

# array analysis cut (depend on ED version)
EDVERSION=`$EVNDISPSYS/bin/evndisp --version | tr -d .`
ACUTS="EVNDISP.reconstruction.runparameter"
if [[ $EDVERSION = "v4"* ]]; then
   ACUTS="EVNDISP.reconstruction.runparameter.v4x"
fi
OPT="-display=1 -reconstructionparameter $ACUTS -vbfnsamples "

OPT="$OPT $PLOTOPT $CALIBOPT "

[[ "$5" ]] && OPT="$OPT -target $5"
[[ "$6" ]] && OPT="$OPT -wobblenorth=$6"
[[ "$7" ]] && OPT="$OPT -wobbleeast=$7"
[[ "$8" ]] && OPT="$OPT -raoffset=$8"

# Set remaining run options
OPT="$OPT runnumber=$RUN -teltoana=$TELTOANA"

# Run evndisp
echo "$EVNDISPSYS/bin/evndisp $OPT"
$EVNDISPSYS/bin/evndisp $OPT 

exit
