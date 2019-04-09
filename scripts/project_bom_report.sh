#!/bin/bash

# Script to search the Black Duck KB for project/version and produce a vulnerability risk report PDF
#
# Description:
#		Searches for specified project name which must match only 1 project. Supply a project name search string without version string to see a list of
#		all matching projects, but you will need to rerun the command with the correct project name.
#		Will then search for specified version string within project versions which must match exactly. Enter a version search string to see a list of
#		all matching versions, but you will need to rerun the command with the correct version name to produce the report.
#		Will extract all components and produce license risk report sorted by risk profile in overall_report.pdf or file if specified (which
#		must not exist already).
#
# Arguments:
#	project name:		Project name (required)
#   version name:		Version name (required)
#	pdffile:			PDF file name (optional - otherwise overall_report.pdf will be used)
#
BDREPORTDIR="/INSTALLDIR"

TEMPLATE="$BDREPORTDIR/template/template_bom.json"
LOGOFILE="${BDREPORTDIR}/template/bdlogo.jpg"
source "$BDREPORTDIR/scripts/bdreport.env"

if [ $# -lt 1 -a $# -gt 3 ]
then
	usage project_bom_report.sh
fi

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL"
fi

PROJECT=$1
VERSION=$2

DEFPDF="report_overall_${PROJECT// /_}_${VERSION// /_}.pdf"
OUTPUTPDF=${3:-$DEFPDF}
if [ -r $OUTPUTPDF ]
then
	error "Output file $OUTPUTPDF already exists"
fi

if [ ! -r "$TEMPLATE" ]
then
	error "$TEMPLATE file missing"
fi

if [ ! -r "$LOGOFILE" ]
then
	LOGOFILE=
fi

TOKEN=$(get_auth_token)
if [ $? -ne 0 ]
then
	error "Unable to get API token"
fi

VERURL=$(get_projver "$PROJECT" "$VERSION")
if [ $? -ne 0 ]
then
	error "Unable to find project + version"
fi

#echo DEBUG: VERURL=$VERURL

# Find all components
api_call "${VERURL//[\"]}/components?limit=5000"
RET=$?
if [ $RET -lt 0 ]
then
	error "Unable to get components"
elif [ $RET -eq 0 -o "$RET" == "0" ]
then
	error "0 components in project"
fi
echo "$RET components found"

COMPNAMES="`jq -r '[.items[].componentName]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/\"//g'`"
COMPVERNAMES=(`jq -r '[.items[].componentVersionName]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)
USAGES=(`jq -r '[.items[].usages[0]]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)
REVIEWED=(`jq -r '[.items[].reviewStatus]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)
POLICIES=(`jq -r '[.items[].policyStatus]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)

SEC_UNKNOWN=(`jq -r '[.items[].securityRiskProfile.counts[0].count]|@tsv' $TEMPFILE`)
SEC_NONE=(`jq -r '[.items[].securityRiskProfile.counts[1].count]|@tsv' $TEMPFILE`)
SEC_LOW=(`jq -r '[.items[].securityRiskProfile.counts[2].count]|@tsv' $TEMPFILE`)
SEC_MEDIUM=(`jq -r '[.items[].securityRiskProfile.counts[3].count]|@tsv' $TEMPFILE`)
SEC_HIGH=(`jq -r '[.items[].securityRiskProfile.counts[4].count]|@tsv' $TEMPFILE`)

LIC_UNKNOWN=(`jq -r '[.items[].licenseRiskProfile.counts[0].count]|@tsv' $TEMPFILE`)
LIC_NONE=(`jq -r '[.items[].licenseRiskProfile.counts[1].count]|@tsv' $TEMPFILE`)
LIC_LOW=(`jq -r '[.items[].licenseRiskProfile.counts[2].count]|@tsv' $TEMPFILE`)
LIC_MEDIUM=(`jq -r '[.items[].licenseRiskProfile.counts[3].count]|@tsv' $TEMPFILE`)
LIC_HIGH=(`jq -r '[.items[].licenseRiskProfile.counts[4].count]|@tsv' $TEMPFILE`)

OP_UNKNOWN=(`jq -r '[.items[].operationalRiskProfile.counts[0].count]|@tsv' $TEMPFILE`)
OP_NONE=(`jq -r '[.items[].operationalRiskProfile.counts[1].count]|@tsv' $TEMPFILE`)
OP_LOW=(`jq -r '[.items[].operationalRiskProfile.counts[2].count]|@tsv' $TEMPFILE`)
OP_MEDIUM=(`jq -r '[.items[].operationalRiskProfile.counts[3].count]|@tsv' $TEMPFILE`)
OP_HIGH=(`jq -r '[.items[].operationalRiskProfile.counts[4].count]|@tsv' $TEMPFILE`)

SEC_UNKNOWN_COUNT=0
SEC_LOW_COUNT=0
SEC_MEDIUM_COUNT=0
SEC_HIGH_COUNT=0
SEC_NONE_COUNT=0

LIC_UNKNOWN_COUNT=0
LIC_LOW_COUNT=0
LIC_MEDIUM_COUNT=0
LIC_HIGH_COUNT=0
LIC_NONE_COUNT=0

OP_UNKNOWN_COUNT=0
OP_LOW_COUNT=0
OP_MEDIUM_COUNT=0
OP_HIGH_COUNT=0
OP_NONE_COUNT=0

COMPNUM=0
>${TEMPFILE}_table

for COMPNAME in $COMPNAMES
do
	COMPVERNAME="${COMPVERNAMES[$COMPNUM]}"

	if [[ -z "$COMPVERNAME" ]]
	then
		continue
	fi

	if [[ -z "${SEC_UNKNOWN[$COMPNUM]}" || -z "${SEC_NONE[$COMPNUM]}" || -z "${SEC_LOW[$COMPNUM]}" || -z "${SEC_MEDIUM[$COMPNUM]}" || -z "${SEC_HIGH[$COMPNUM]}" ]]
	then
		continue
	fi

	if [[ -z "${LIC_UNKNOWN[$COMPNUM]}" || -z "${LIC_NONE[$COMPNUM]}" || -z "${LIC_LOW[$COMPNUM]}" || -z "${LIC_MEDIUM[$COMPNUM]}" || -z "${LIC_HIGH[$COMPNUM]}" ]]
	then
		continue
	fi

	if [[ -z "${OP_UNKNOWN[$COMPNUM]}" || -z "${OP_NONE[$COMPNUM]}" || -z "${OP_LOW[$COMPNUM]}" || -z "${OP_MEDIUM[$COMPNUM]}" || -z "${OP_HIGH[$COMPNUM]}" ]]
	then
		continue
	fi

	#Check numerics
	re='^[0-9]+$'
	if [[ ! "${SEC_UNKNOWN[$COMPNUM]}" =~ $re || ! "${SEC_NONE[$COMPNUM]}" =~ $re || ! "${SEC_LOW[$COMPNUM]}" =~ $re || ! "${SEC_MEDIUM[$COMPNUM]}" =~ $re || ! "${SEC_HIGH[$COMPNUM]}" =~ $re ]]
	then
		continue
	fi
	if [[ ! "${LIC_UNKNOWN[$COMPNUM]}" =~ $re || ! "${LIC_NONE[$COMPNUM]}" =~ $re || ! "${LIC_LOW[$COMPNUM]}" =~ $re || ! "${LIC_MEDIUM[$COMPNUM]}" =~ $re || ! "${LIC_HIGH[$COMPNUM]}" =~ $re ]]
	then
		continue
	fi
	if [[ ! "${OP_UNKNOWN[$COMPNUM]}" =~ $re || ! "${OP_NONE[$COMPNUM]}" =~ $re || ! "${OP_LOW[$COMPNUM]}" =~ $re || ! "${OP_MEDIUM[$COMPNUM]}" =~ $re || ! "${OP_HIGH[$COMPNUM]}" =~ $re ]]
	then
		continue
	fi
	
	# Work out the overall component security risk counts
	SEC_TEXT=
	if (( SEC_HIGH[$COMPNUM] > 0 ))
	then
		((SEC_HIGH_COUNT++))
		SEC_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"High"]]'
	elif (( SEC_UNKNOWN[$COMPNUM] > 0 ))
	then
		((SEC_UNKNOWN_COUNT++))
		SEC_TEXT='"Unknown"'
	elif (( SEC_MEDIUM[$COMPNUM] > 0 ))
	then
		((SEC_MEDIUM_COUNT++))
		SEC_TEXT='"Medium"'
	elif (( SEC_LOW[$COMPNUM] > 0 ))
	then
		((SEC_LOW_COUNT++))
		SEC_TEXT='"Low"'
	elif (( SEC_NONE[$COMPNUM] > 0 ))
	then
		((SEC_NONE_COUNT++))
		SEC_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"None"]]'
	fi
	
	# Work out the overall component license risk counts	
	LIC_TEXT=
	if (( LIC_HIGH[$COMPNUM] > 0 ))
	then
		((LIC_HIGH_COUNT++))
		LIC_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"High"]]'
	elif (( LIC_UNKNOWN[$COMPNUM] > 0 ))
	then
		((LIC_UNKNOWN_COUNT++))
		LIC_TEXT='"Unknown"'
	elif (( LIC_MEDIUM[$COMPNUM] > 0 ))
	then
		((LIC_MEDIUM_COUNT++))
		LIC_TEXT='"Medium"'
	elif (( LIC_LOW[$COMPNUM] > 0 ))
	then
		((LIC_LOW_COUNT++))
		LIC_TEXT='"Low"'
	elif (( LIC_NONE[$COMPNUM] > 0 ))
	then
		((LIC_NONE_COUNT++))
		LIC_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"None"]]'
	fi

	# Work out the overall component op risk counts	
	OP_TEXT=
	if (( OP_HIGH[$COMPNUM] > 0 ))
	then
		((OP_HIGH_COUNT++))
		OP_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"High"]]'
	elif (( OP_UNKNOWN[$COMPNUM] > 0 ))
	then
		((OP_UNKNOWN_COUNT++))
		OP_TEXT='"Unknown"'
	elif (( OP_MEDIUM[$COMPNUM] > 0 ))
	then
		((OP_MEDIUM_COUNT++))
		OP_TEXT='"Medium"'
	elif (( OP_LOW[$COMPNUM] > 0 ))
	then
		((OP_LOW_COUNT++))
		OP_TEXT='"Low"'
	elif (( OP_NONE[$COMPNUM] > 0 ))
	then
		((OP_NONE_COUNT++))
		OP_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"None"]]'
	fi	
	
	if [ "${REVIEWED[$COMPNUM]}" == "REVIEWED" ]
	then
		REV_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"Yes"]]'
	else
		REV_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"No"]]'
	fi
	if [ "${POLICIES[$COMPNUM]}" == "IN_VIOLATION" ]
	then
		POL_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"Yes"]]'
	else
		POL_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"No"]]'
	fi

	if [ "${USAGES[$COMPNUM]}" == "DYNAMICALLY_LINKED" ]
	then
		USAGE_TEXT='Dynamically Linked'
	elif [ "${USAGES[$COMPNUM]}" == "STATICALLY_LINKED" ]
	then
		USAGE_TEXT='Statically Linked'
	elif [ "${USAGES[$COMPNUM]}" == "DEV_TOOL_EXCLUDED" ]
	then
		USAGE_TEXT='Dev Tool/ Excluded'
	else
		USAGE_TEXT='Other'
	fi

	echo ",[\"${COMPNAME//_/ }\",\"${COMPVERNAME//_/ }\",\"${USAGE_TEXT}\",${SEC_TEXT},${LIC_TEXT},${OP_TEXT},${REV_TEXT},${POL_TEXT}]" >> ${TEMPFILE}_table
		
	((COMPNUM++))
done

( cat "$TEMPLATE" | \
sed -e "s/__PROJECTNAME__/$PROJECT/g" \
-e "s/__VERSIONNAME__/$VERSION/g" \
-e "s/__SEC_LOW__/$SEC_LOW_COUNT/g" \
-e "s/__SEC_MEDIUM__/$SEC_MEDIUM_COUNT/g" \
-e "s/__SEC_HIGH__/$SEC_HIGH_COUNT/g" \
-e "s/__SEC_UNKNOWN__/$SEC_UNKNOWN_COUNT/g" \
-e "s/__SEC_NONE__/$SEC_NONE_COUNT/g" \
-e "s/__LIC_LOW__/$LIC_LOW_COUNT/g" \
-e "s/__LIC_MEDIUM__/$LIC_MEDIUM_COUNT/g" \
-e "s/__LIC_HIGH__/$LIC_HIGH_COUNT/g" \
-e "s/__LIC_UNKNOWN__/$LIC_UNKNOWN/g" \
-e "s/__LIC_NONE__/$LIC_NONE_COUNT/g" \
-e "s/__OP_LOW__/$OP_LOW_COUNT/g" \
-e "s/__OP_MEDIUM__/$OP_MEDIUM_COUNT/g" \
-e "s/__OP_HIGH__/$OP_HIGH_COUNT/g" \
-e "s/__OP_UNKNOWN__/$OP_UNKNOWN_COUNT/g" \
-e "s/__OP_NONE__/$OP_NONE_COUNT/g" 
cat ${TEMPFILE}_table
echo ']]'
) > ${TEMPFILE}_json

JAVACMD="java -jar \"$BDREPORTDIR/$JSONTOPDFJAR\" \"$OUTPUTPDF\""
if [ -z "$LOGOFILE" ]
then
	eval $JAVACMD ${TEMPFILE}_json
else
	eval $JAVACMD ${TEMPFILE}_json "$LOGOFILE"
fi

if [ ! -r "$OUTPUTPDF" ]
then
	error "PDF file $OUTPUTPDF was not created due to error with Java program"
else
	echo "PDF file $OUTPUTPDF created successfully"
fi

end 0