#!/bin/bash

# Script to search the Black Duck KB for project/version and produce a license risk report PDF
#
# Description:
#		Searches for specified project name which must match only 1 project. Supply a project name search string without version string to see a list of
#		all matching projects, but you will need to rerun the command with the correct project name.
#		Will then search for specified version string within project versions which must match exactly. Enter a version search string to see a list of
#		all matching versions, but you will need to rerun the command with the correct version name to produce the report.
#		Will extract all components and produce license risk report sorted by risk profile in license_risk_report.pdf or file if specified (which
#		must not exist already).
#
# Arguments:
#	project name:		Project name (required)
#   version name:		Version name (required)
#	pdffile:			PDF file name (optional - otherwise license_risk_report.pdf will be used)
#
BDREPORTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."
TEMPLATE="$BDREPORTDIR/template/template_license.json"
LOGOFILE="${BDREPORTDIR}/template/bdlogo.jpg"
source "$BDREPORTDIR/conf/bdreport.inc"

if [ $# -lt 1 -a $# -gt 3 ]
then
	usage project_license_report.sh
fi

if [ -z "$APICODE" -o -z "$HUBURL" ]
then
	error "Please set the API code and BD Server URL"
fi

PROJECT=$1
VERSION=$2

DEFPDF="report_licensing_risk_${PROJECT// /_}_${VERSION// /_}.pdf"
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
COMPVERNAMES=(`jq -r '[.items[].componentVersionName]|@tsv' $TEMPFILE | sed -e 's/		/	No_version	/g' -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)
LIC_NAMES=(`jq -r '[.items[].licenses[0].licenseDisplay]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/,//g' -e 's/"//g'`)

ALL_UNKNOWN=(`jq -r '[.items[].licenseRiskProfile.counts[0].count]|@tsv' $TEMPFILE`)
ALL_OK=(`jq -r '[.items[].licenseRiskProfile.counts[1].count]|@tsv' $TEMPFILE`)
ALL_LOW=(`jq -r '[.items[].licenseRiskProfile.counts[2].count]|@tsv' $TEMPFILE`)
ALL_MEDIUM=(`jq -r '[.items[].licenseRiskProfile.counts[3].count]|@tsv' $TEMPFILE`)
ALL_HIGH=(`jq -r '[.items[].licenseRiskProfile.counts[4].count]|@tsv' $TEMPFILE`)

COUNT_UNKNOWN=0
COUNT_OK=0
COUNT_LOW=0
COUNT_MEDIUM=0
COUNT_HIGH=0
COUNT_NONE=0

COMPNUM=0
>${TEMPFILE}_high.json
>${TEMPFILE}_med.json
>${TEMPFILE}_low.json
>${TEMPFILE}_unknown.json
>${TEMPFILE}_none.json

#jq -r '[.items[].componentName]' $TEMPFILE | sed -e 's/,//g' -e '/\[/d' -e '/]/d' > ${TEMPFILE}_names

for COMPNAME in $COMPNAMES
do
	COMPVERNAME="${COMPVERNAMES[$COMPNUM]}"
	LIC_NAME="${LIC_NAMES[$COMPNUM]}"

	if [[ -z "$COMPVERNAME" || -z "$LIC_NAME" || -z "${ALL_UNKNOWN[$COMPNUM]}" || -z "${ALL_OK[$COMPNUM]}" || -z "${ALL_LOW[$COMPNUM]}" || -z "${ALL_MEDIUM[$COMPNUM]}" || -z "${ALL_HIGH[$COMPNUM]}" ]]
	then
		continue
	fi

	#Check numerics
	re='^[0-9]+$'
	if [[ ! "${ALL_UNKNOWN[$COMPNUM]}" =~ $re || ! "${ALL_OK[$COMPNUM]}" =~ $re || ! "${ALL_LOW[$COMPNUM]}" =~ $re || ! "${ALL_MEDIUM[$COMPNUM]}" =~ $re || ! "${ALL_HIGH[$COMPNUM]}" =~ $re ]]
	then
		continue
	fi
		
	LIC_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"None"]]'
	if (( ALL_HIGH[$COMPNUM] > 0 ))
	then
		LIC_TEXT='["cell",["phrase",{"color":[200, 0, 0]},"High"]]'
		((COUNT_HIGH++))
		OUTFILE=_high
	elif (( ALL_UNKNOWN[$COMPNUM] > 0 ))
	then
		LIC_TEXT='"Unknown"'
		((COUNT_UNKNOWN++))
		OUTFILE=_unknown
	elif (( ALL_MEDIUM[$COMPNUM] > 0 ))
	then
		LIC_TEXT='"Medium"'
		((COUNT_MEDIUM++))
		OUTFILE=_med
	elif (( ALL_LOW[$COMPNUM] > 0 ))
	then
		LIC_TEXT='"Low"'
		((COUNT_LOW++))
		OUTFILE=_low
	elif (( ALL_OK[$COMPNUM] > 0 ))
	then
		LIC_TEXT='["cell",["phrase",{"color":[10, 200, 10]},"None"]]'
		((COUNT_NONE++))
		OUTFILE=_none
	fi

	echo ",[\"${COMPNAME//_/ }\",\"${COMPVERNAME//_/ }\",\"${LIC_NAME//_/ }\",$LIC_TEXT]" >> ${TEMPFILE}${OUTFILE}.json
		
	((COMPNUM++))
done

#echo "$COMPNUM components processed"

( cat "$TEMPLATE" | \
sed -e "s/__PROJECTNAME__/$PROJECT/g" \
-e "s/__VERSIONNAME__/$VERSION/g" \
-e "s/__COUNT_LOW__/$COUNT_LOW/g" \
-e "s/__COUNT_MEDIUM__/$COUNT_MEDIUM/g" \
-e "s/__COUNT_HIGH__/$COUNT_HIGH/g" \
-e "s/__COUNT_UNKNOWN__/$COUNT_UNKNOWN/g" \
-e "s/__COUNT_NONE__/$COUNT_NONE/g"
cat ${TEMPFILE}_high.json
#cat ${TEMPFILE}_unknown.json
cat ${TEMPFILE}_med.json
cat ${TEMPFILE}_low.json
cat ${TEMPFILE}_none.json
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
