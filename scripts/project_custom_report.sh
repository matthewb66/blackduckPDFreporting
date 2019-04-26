#!/bin/bash

# Script to search the Black Duck KB for project/version and produce a custom risk report PDF.
# Fields to be reported are defined in the XXX variable.
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
#	template file:		Template file in $BDREPORTDIR/template
#	project name:		Project name (required)
#   version name:		Version name (required)
#	pdffile:			PDF file name (optional - otherwise overall_report.pdf will be used)
#
BDREPORTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
LOGOFILE="${BDREPORTDIR}/template/bdlogo.jpg"
source "$BDREPORTDIR/conf/bdreport.inc"

usage_custom() {
	echo "Usage: $1 Template_file Project_name Version_name [PDF_file]"
	echo "	Use '$1 Template_file Project_search_string' to see a list of all matching projects"
	echo "	Or '$1 Template_file Project_name Version_search_string' to see a list of all versions for the project"
	end 0
}

if [ $# -lt 2 -a $# -gt 3 ]
then
	usage_custom project_custom_report.sh
fi

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL"
fi

TEMPLATE="$BDREPORTDIR/template/$1"
PROJECT=$2
VERSION=$3

if [ ! -r "$TEMPLATE" ]
then
	echo "Template file $TEMPLATE does not exist" >&2
	usage_custom project_custom_report.sh
fi

DEFPDF="report_custom_${PROJECT// /_}_${VERSION// /_}.pdf"
OUTPUTPDF=${4:-$DEFPDF}
if [ -r $OUTPUTPDF ]
then
	error "Output file $OUTPUTPDF already exists"
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


#Process table rows from template
#
#__TABLE_ROWS__:[.items[].componentName] [.items[].componentVersionName] [.items[].usages[0]] [.items[].reviewStatus] [.items[].policyStatus]

TABLEROWS="`grep __TABLE_ROWS__ \"$TEMPLATE\" | cut -f2 -d':'`"
if [ -z "$TABLEROWS" ]
then
	error "Unable to extract table rows from template file"
fi

VARNUM=1
for COLUMN in $TABLEROWS
do
	if [ "$COLUMN" != "__OP_TEXT__" -a "$COLUMN" != "__SEC_TEXT__" -a "$COLUMN" != "__LIC_TEXT__" ]
	then
		CMD="jq -r '$COLUMN|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/\"//g'"
		#echo $CMD
		VAR="COL$VARNUM"
		eval $VAR='(`eval $CMD`)'
		#echo ${!VAR[0]}
	fi
	((VARNUM++))
done

#Process replacement text
#
#__REPLACEMENTS__:REVIEWED,Yes|NOT_REVIEWED/No|IN_VIOLATION/Yes|DYNAMICALLY_LINKED/Dynamically Linked|STATICALLY_LINKED/Statically Linked|DEV_TOOL_EXCLUDED/Dev Tool/Excluded
#REPLACEMENTS="sed -e 's;`grep __REPLACEMENTS__ \"$TEMPLATE\" | cut -f2 -d':' | sed -e \"s:\|:;g' \-e \'s;:g\"`;g'"
SEDTEXT="`grep __REPLACEMENTS__ \"$TEMPLATE\" | cut -f2 -d':' | sed -e \"s:|:;g' \-e \'s;:g\"`"
REPLACEMENTS="sed -e 's;$SEDTEXT;g'"

if [ -z "$REPLACEMENTS" ]
then
	error "Unable to extract replacement text from template file"
fi
#Check that REPLACEMENTS sed command is valid
echo test | eval $REPLACEMENTS 1>/dev/null 2>&1
if [ $? -ne 0 ]
then
	error "Replacement text error - cannot extract from template file"
fi

COMPNAMES="`jq -r '[.items[].componentName]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/\"//g'`"
COMPVERNAMES=(`jq -r '[.items[].componentVersionName]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)

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

SEC_LOW_COUNT=0
SEC_MEDIUM_COUNT=0
SEC_HIGH_COUNT=0
SEC_UNKNOWN_COUNT=0
SEC_NONE_COUNT=0
LIC_LOW_COUNT=0
LIC_MEDIUM_COUNT=0
LIC_HIGH_COUNT=0
LIC_UNKNOWN_COUNT=0
LIC_NONE_COUNT=0
OP_LOW_COUNT=0
OP_MEDIUM_COUNT=0
OP_HIGH_COUNT=0
OP_UNKNOWN_COUNT=0
OP_NONE_COUNT=0

COMPNUM=0
>${TEMPFILE}_table

for COMPNAME in $COMPNAMES
do
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
	
	( printf ",[" 
	VARNUM=1
	for COLUMN in $TABLEROWS
	do
		if [ "$COLUMN" == "__OP_TEXT__" ]
		then
			OUTPUT="$OP_TEXT"
		elif [ "$COLUMN" == "__SEC_TEXT__" ]
		then
			OUTPUT="$SEC_TEXT"
		elif [ "$COLUMN" == "__LIC_TEXT__" ]
		then
			OUTPUT="$LIC_TEXT"
		else
			VAR="COL$VARNUM[$COMPNUM]"
			OUTPUT="\"${!VAR}\""
		fi
		if [ $VARNUM -eq 1 ]
		then
			printf "%s" "${OUTPUT}" 
		else
			printf ",%s" "${OUTPUT}"
		fi 
		((VARNUM++))
	done
	printf "]" ) | eval $REPLACEMENTS >> ${TEMPFILE}_table
	
#	echo ",[\"${COMPNAME//_/ }\",\"${COMPVERNAME//_/ }\",\"${USAGE_TEXT}\",${SEC_TEXT},${LIC_TEXT},${OP_TEXT},${REV_TEXT},${POL_TEXT}]" >> ${TEMPFILE}_table
		
	((COMPNUM++))
done

( cat "$TEMPLATE" | grep -v -e '__TABLE_ROWS__' -e '__REPLACEMENTS__' | \
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
-e "s/__LIC_UNKNOWN__/$LIC_UNKNOWN_COUNT/g" \
-e "s/__LIC_NONE__/$LIC_NONE_COUNT/g" \
-e "s/__OP_LOW__/$OP_LOW_COUNT/g" \
-e "s/__OP_MEDIUM__/$OP_MEDIUM_COUNT/g" \
-e "s/__OP_HIGH__/$OP_HIGH_COUNT/g" \
-e "s/__OP_UNKNOWN__/$OP_UNKNOWN_COUNT/g" \
-e "s/__OP_NONE__/$OP_NONE_COUNT/g" 
cat ${TEMPFILE}_table
echo ']]'
) > ${TEMPFILE}_json

#cp ${TEMPFILE}_json temp.json

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
