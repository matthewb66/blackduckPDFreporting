#!/bin/bash

# Script to search the Black Duck KB for project/version and produce a vulnerability risk report PDF
#
# Description:
#		Searches for specified project name which must match only 1 project. Supply a project name search string without version string to see a list of 
#		all matching projects, but you will need to rerun the command with the correct project name.
#		Will then search for specified version string within project versions which must match exactly. Enter a version search string to see a list of
#		all matching versions, but you will need to rerun the command with the correct version name to produce the report.
#		Will extract all components and produce vulnerability risk report sorted by risk profile in security_risk_report.pdf or file
#		if specified (which must not exist already).
#
# Arguments:
#	project name:		Project name (required)
#   version name:		Version name (required)
#	pdffile:			PDF file name (optional - otherwise security_risk_report.pdf will be used)
#
BDREPORTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPLATE="$BDREPORTDIR/template/template_security.json"
LOGOFILE="${BDREPORTDIR}/template/bdlogo.jpg"
source "$BDREPORTDIR/conf/bdreport.inc"

if [ $# -lt 1 -a $# -gt 3 ]
then
	usage project_security_report.sh
fi

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL"
fi

PROJECT=$1
VERSION=$2

DEFPDF="report_security_risk_${PROJECT// /_}_${VERSION// /_}.pdf"
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

ALL_UNKNOWN=(`jq -r '[.items[].securityRiskProfile.counts[0].count]|@tsv' $TEMPFILE`)
ALL_NONE=(`jq -r '[.items[].securityRiskProfile.counts[1].count]|@tsv' $TEMPFILE`)
ALL_LOW=(`jq -r '[.items[].securityRiskProfile.counts[2].count]|@tsv' $TEMPFILE`)
ALL_MEDIUM=(`jq -r '[.items[].securityRiskProfile.counts[3].count]|@tsv' $TEMPFILE`)
ALL_HIGH=(`jq -r '[.items[].securityRiskProfile.counts[4].count]|@tsv' $TEMPFILE`)

COMP_UNKNOWN=0
COMP_LOW=0
COMP_MEDIUM=0
COMP_HIGH=0
COMP_NONE=0

VULNS_UNKNOWN=0
VULNS_LOW=0
VULNS_MEDIUM=0
VULNS_HIGH=0
VULNS_NONE=0

COMPNUM=0
>${TEMPFILE}_table

#jq -r '[.items[].componentName]' $TEMPFILE | sed -e 's/,//g' -e '/\[/d' -e '/]/d' > ${TEMPFILE}_names

for COMPNAME in $COMPNAMES
do
	COMPVERNAME="${COMPVERNAMES[$COMPNUM]}"

	if [[ -z "$COMPVERNAME" || -z "${ALL_UNKNOWN[$COMPNUM]}" || -z "${ALL_NONE[$COMPNUM]}" || -z "${ALL_LOW[$COMPNUM]}" || -z "${ALL_MEDIUM[$COMPNUM]}" || -z "${ALL_HIGH[$COMPNUM]}" ]]
	then
		continue
	fi

	#Check numerics
	re='^[0-9]+$'
	if [[ ! "${ALL_UNKNOWN[$COMPNUM]}" =~ $re || ! "${ALL_NONE[$COMPNUM]}" =~ $re || ! "${ALL_LOW[$COMPNUM]}" =~ $re || ! "${ALL_MEDIUM[$COMPNUM]}" =~ $re || ! "${ALL_HIGH[$COMPNUM]}" =~ $re ]]
	then
		continue
	fi
	
	# Work out the overall component vulnerability	
	VULN_TEXT=
	if (( ALL_HIGH[$COMPNUM] > 0 ))
	then
		((COMP_HIGH++))
	elif (( ALL_UNKNOWN[$COMPNUM] > 0 ))
	then
		((COMP_UNKNOWN++))
	elif (( ALL_MEDIUM[$COMPNUM] > 0 ))
	then
		((COMP_MEDIUM++))
	elif (( ALL_LOW[$COMPNUM] > 0 ))
	then
		((COMP_LOW++))
	elif (( ALL_NONE[$COMPNUM] > 0 ))
	then
		((COMP_NONE++))
	fi

	((VULNS_UNKNOWN+=ALL_UNKNOWN[$COMPNUM]))
	((VULNS_LOW+=ALL_LOW[$COMPNUM]))
	((VULNS_MEDIUM+=ALL_MEDIUM[$COMPNUM]))
	((VULNS_HIGH+=ALL_HIGH[$COMPNUM]))
	((VULNS_NONE+=ALL_NONE[$COMPNUM]))
	
	echo "[${COMPNAME//_/ },${COMPVERNAME//_/ },${ALL_HIGH[$COMPNUM]},${ALL_MEDIUM[$COMPNUM]},${ALL_LOW[$COMPNUM]}]" >> ${TEMPFILE}_table
		
	((COMPNUM++))
done 

( cat "$TEMPLATE" | \
sed -e "s/__PROJECTNAME__/$PROJECT/g" \
-e "s/__VERSIONNAME__/$VERSION/g" \
-e "s/__COMP_LOW__/$COMP_LOW/g" \
-e "s/__COMP_MEDIUM__/$COMP_MEDIUM/g" \
-e "s/__COMP_HIGH__/$COMP_HIGH/g" \
-e "s/__COMP_UNKNOWN__/$COMP_UNKNOWN/g" \
-e "s/__COMP_NONE__/$COMP_NONE/g" \
-e "s/__VULNS_LOW__/$VULNS_LOW/g" \
-e "s/__VULNS_MEDIUM__/$VULNS_MEDIUM/g" \
-e "s/__VULNS_HIGH__/$VULNS_HIGH/g" \
-e "s/__VULNS_UNKNOWN__/$VULNS_UNKNOWN/g" \
-e "s/__VULNS_NONE__/$VULNS_NONE/g" 
sort -k 3 -k 4 -k 5 -t , -n -r ${TEMPFILE}_table | sed -e 's/,/","/g' -e 's/\[/,\["/' -e 's/]/"]/' -e 's/""/"/g'
echo ']]'
) > ${TEMPFILE}_json

#cp ${TEMPFILE}_json debug.json

if [ -z "$LOGOFILE" ]
then
	java -jar "$BDREPORTDIR/target/json-to-pdf-example-1.0-jar-with-dependencies.jar" "$OUTPUTPDF" ${TEMPFILE}_json
else
	java -jar "$BDREPORTDIR/target/json-to-pdf-example-1.0-jar-with-dependencies.jar" "$OUTPUTPDF" ${TEMPFILE}_json "$LOGOFILE"
fi

if [ ! -r "$OUTPUTPDF" ]
then
	error "PDF file $OUTPUTPDF was not created due to error with Java program"
else
	echo "PDF file $OUTPUTPDF created successfully"
fi

end 0
