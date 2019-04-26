source "$BDREPORTDIR/conf/bdreport.env"
TEMPFILE=/tmp/bd1$$
JSONTOPDFJAR=target/json-to-pdf-example-1.0-jar-with-dependencies.jar

end () {
	rm -f $TEMPFILE ${TEMPFILE}_*
	rm -f outstream.pdf
	exit $1
}

error () {
	echo "ERROR: $*" >&2
	end 1
}

usage() {
	echo "Usage: $1 Project_name Version_name [PDF_file]"
	echo "	Use '$1 Project_search_string' to see a list of all matching projects"
	echo "	Or '$1 Project_name Version_search_string' to see a list of all versions for the project"
	end 0
}

get_auth_token() {
	curl $CURLOPTS -X POST --header "Authorization: token $APICODE" --header "Accept:application/json" $HUBURL/api/tokens/authenticate > $TEMPFILE 2>/dev/null
	if [ $? -ne 0 ] || [ ! -r $TEMPFILE ]
	then
		echo API request failure >&2
		return -1
	fi

	jq '.bearerToken' $TEMPFILE|sed -e 's/^"//' -e 's/"$//'
	return 0
}

api_call() {
	rm -f $TEMPFILE
	curl $CURLOPTS -X GET --header "Authorization: Bearer $TOKEN" "$1" 2>/dev/null >$TEMPFILE
	if [ $? -ne 0 ] || [ ! -r $TEMPFILE ]
	then
		( echo API Error:
		echo  curl -X GET --header "Authorization: Bearer $TOKEN" "$1" ) >&2
		return -1
	fi

	COUNT=`jq -r '.totalCount' $TEMPFILE`
	if [ -z "$COUNT" ]
	then
		return -1
	fi
	
	return $COUNT
}

check_prereqs() {
	#TEST="`echo '{\"test\":100}' | jq .test`"
	#if [ -z "$TEST" -o "$TEST" != '100' ]
	hash jq 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "jq package required - please install before continuing" >&2
		return -1
	fi
	hash curl 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "curl package required - please install before continuing" >&2
		return -1
	fi
	hash sed 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "sed package required - please install before continuing" >&2
		return -1
	fi
	hash sort 2>/dev/null
	if [ $? -ne 0 ]
	then
		echo "sort package required - please install before continuing" >&2
		return -1
	fi
	if [ ! -r "$BDREPORTDIR/$JSONTOPDFJAR" ]
	then
		echo "JSON to PDF Jar file missing" >&2
		return -1
	fi
	return 0
}

get_project() {
	#Get  projects
	SEARCHPROJ="${1// /+}"
	api_call "$HUBURL/api/projects?q=name:$SEARCHPROJ"
	if [ $? -lt 0 ]
	then
		return -1
	fi

	FOUND=false
	SEARCHPROJ="${1// /_}"
	PROJNAMES="`jq -r '[.items[].name]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/\"//g' -e 's/,//g'`"
	PROJURLS=(`jq -r '[.items[]._meta.href]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/\"//g' -e 's/,//g'`)
	PROJURL=
	PROJNUM=0
	for PROJ in $PROJNAMES
	do
#		echo DEBUG: PROJ=$PROJ SEARCHPROJ=$SEARCHPROJ >&2
		if [ "$PROJ" == "$SEARCHPROJ" ]
		then
			FOUND=true
			PROJURL="${PROJURLS[$PROJNUM]}"
			break
		fi
		((PROJNUM++))
	done

	if [ $FOUND == false ]
	then
		( echo "Matching projects found:"
		jq -r '[.items[].name]' $TEMPFILE
		echo "Please rerun selecting specific Project and supply Version" ) >&2
		return -1
	fi

	echo "Project '$PROJ' found ..." >&2

#	echo DEBUG: PROJURL=$PROJURL >&2
	echo $PROJURL
	return 0
}

get_versions() {
	# Get Version
	api_call "${1//[\"]}/versions"
	if [ $? -lt 0 ]
	then
		return -1
	fi
	
	SEARCHVERSION="${2// /_}"
	VERNAMES=(`jq -r '[.items[].versionName]|@tsv' $TEMPFILE | sed -e 's/ /_/g' -e 's/\"//g' -e 's/,//g'`)

	VERURLS="`jq -r '[.items[]._meta.href]|@tsv' $TEMPFILE`"
	VERNUM=0
	local FOUNDVERSIONURL=
	for VERURL in $VERURLS
	do
		VERNAME=${VERNAMES[$VERNUM]}
	
		if [ "$VERNAME" == "$SEARCHVERSION" ]
		then
			FOUNDVERSIONURL=$VERURL
			break 2
		fi
		((VERNUM++))
	done

	if [ -z "$FOUNDVERSIONURL" ]
	then
		( echo "Unable to find version '$VERSION'"
		echo "Available versions:"
		jq -r '[.items[].versionName]' $TEMPFILE | sed -e 's/,//g'
		echo "Single version must be specified" ) >&2
		return -1
	fi

	echo "Version '$VERSION' found ..." >&2
	echo $FOUNDVERSIONURL
	return 0
}

get_projver() {
	PROJURL=$(get_project "$1")
	if [ $? -ne 0 ]
	then
		return -1
	fi
	
#	echo DEBUG: PROJURL=$PROJURL >&2
	
	VERURL=$(get_versions "$PROJURL" "$2")
	if [ $? -ne 0 ]
	then
		return -1
	fi
	
	echo $VERURL
	return 0
}

check_prereqs
if [ $? -ne 0 ]
then
	error "Missing prerequisites"
fi