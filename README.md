# OVERVIEW

A set of Bash scripts to support creating PDF reports using the Black Duck API.

Json-to-pdf (https://github.com/yogthos/json-to-pdf) is used to generate PDF files allowing configuration of the PDF layout, content and format in template json files.
Also uses jq to format JSON data from API calls (must be preinstalled).

List of scripts included in this package:
- *project_bom_report.sh*: Produces an overall report showing alphabetical list of components, including bar charts of license, vulnerability and operational risk
- *project_license_report.sh*: Produces a license report showing list of components sorted by license risk, including a bar chart of license risk
- *project_security_report.sh*: Produces a security report showing list of components sorted by vulnerability counts, including bar charts of security risk by component and overall
- *project_custom_report.sh*: Generate a general report of components using a custom template which can include API fields selected in the template.

# SUPPORTED PLATFORMS

Linux & MacOS (bash required)

# PREREQUISITES

JQ must be pre-installed (https://stedolan.github.io/jq/) - can be installed using yum/brew etc.

# INSTALLATION

1. Extract the project files to a chosen folder.
2. Ensure script files `scripts/*.sh` have execute permission (chmod +x)
3. Update the *BDREPORTDIR* value in all `scripts/*.sh` files to represent the top level folder where the solution is installed.
4. Add the scripts folder to the path (e.g. `export PATH=$PATH:/user/myuser/BDReporting/scripts`)
5. Create an API code (user access token) in the BD interface (use Username-->My Profile-->User Access Token)
5. Update the *HUBURL* and *APICODE* values in the scripts/bdreport.env file to represent your BD server and API code.

# QUICK START: EXAMPLE PDF REPORT

To produce an overall project report, run the command:

	project_bom_report.sh projname projversion

where:
- *projname* is a full project name string (use quotes if it includes spaces)
- *projversion* is a full version name string (use quotes if it includes spaces)

Upon successful execution, a PDF file with the name *report_overall_projname_projversion.pdf* will be created in the invocation folder.

If the *projname* string does not match a full project then a list of matching project names will be shown and the script will terminate.
For example running the command:

	project_bom_report.sh duck

Would result in the following example output:

	Matching projects found:
	[
	  "black-duck-detect",
	  "BlackduckNugetInspector",
	  "blackducksoftware_blackduck-webapp",
	  "Duck",
	  "Duck Hub Demo Jenkins Sandbox",
	  "duck-hub",
	  "JenkinsDucky"
	]
	Please rerun selecting specific Project and supply Version
	ERROR: Unable to find project + version

This can be repeated for the *projversion* string provided a valid *projectname* is provided.

It is also possible to specify the PDF filename in the command, for example:

	project_bom_report.sh projname projversion PDFfile

# OVERALL PROJECT PDF REPORT

The script *project_bom_report.sh* will produce an overall summary project report including 3 bar charts
showing vulnerabiity, license and operational risk (count of components) and an alphabetical table of components with the following headings:

- Component
- Version
- Usage
- Security Risk
- License Risk
- Operational Risk
- Reviewed
- Policy Violation

The script uses the template file template_bom.json, and produces an output PDF file *report_overall_projname_projversion.pdf* by default.

You can find an example overall project report [here]( https://github.com/matthewb66/blackduckPDFreporting/blob/master/examples/report_overall_duck-hub_3.0.pdf).

## Running Overall Report

Use the command:

	project_bom_report.sh projname projversion [pdffile]
	
where:
- *projname* (required) is a full project name string (use quotes if it includes spaces)
- *projversion* (required) is a full version name string (use quotes if it includes spaces)
- *pdffile* (optional) is an alternate output PDF file name.
	
## Configuring Overall Report

The template file *template_bom.json* is used to define the content and layout of the generated PDF file.
To learn more about the json-to-pdf format see here.
Note that it is not possible to remove columns in the table by deleting them from the template alone; you will need to modify
the script logic to delete columns.

Several values will be replaced within the template as follows:
- \_\_PROJECTNAME\_\_ - Project name string
- \_\_VERSIONNAME\_\_ - Version name string
- \_\_SEC\_HIGH\_\_ - Count of components with high risk vulnerabilities
- \_\_SEC\_MEDIUM\_\_ - Count of components with medium risk vulnerabilities
- \_\_SEC\_LOW\_\_ - Count of components with low risk vulnerabilities
- \_\_SEC\_NONE\_\_ - Count of components with no vulnerabilities
- \_\_LIC\_HIGH\_\_ - Count of components with high risk licenses
- \_\_LIC\_MEDIUM\_\_ - Count of components with medium risk licenses
- \_\_LIC\_LOW\_\_ - Count of components with low risk licenses
- \_\_LIC\_NONE\_\_ - Count of components with no risk licenses
- \_\_OP\_HIGH\_\_ - Count of components with high operational risk
- \_\_OP\_MEDIUM\_\_ - Count of components with medium operational risk
- \_\_OP\_LOW\_\_ - Count of components with low operational risk
- \_\_OP\_NONE\_\_ - Count of components with no operational risk

# LICENSE PDF REPORT

The script *project_license_report.sh* will produce a license project report including a bar chart
showing license risk (count of components) and an alphabetical table of components with the following headings:

- Component
- Version
- License
- Risk

The script uses the template file *template/template_license.json*, and produces an output PDF file *report_licensing_projname_projversion.pdf* by default.

You can find an example report [here](https://github.com/matthewb66/blackduckPDFreporting/blob/master/examples/report_licensing_risk_duck-hub_3.0.pdf).

## Running License Report

Use the command:

	project_license_report.sh projname projversion [pdffile]
	
where:
- *projname* (required) is a full project name string (use quotes if it includes spaces)
- *projversion* (required) is a full version name string (use quotes if it includes spaces)
- *pdffile* (optional) is an alternate output PDF file name.
	
## Configuring License Report

The template file *template/template_license.json* is used to define the content and layout of the generated PDF file.
To learn more about the json-to-pdf format see here.
Note that it is not possible to remove columns in the table by deleting them from the template alone; you will need to modify
the script logic to delete columns.

Several values will be replaced within the template as follows:
- \_\_PROJECTNAME\_\_ - Project name string
- \_\_VERSIONNAME\_\_ - Version name string
- \_\_COUNT\_HIGH\_\_ - Count of components with high risk licenses
- \_\_COUNT\_MEDIUM\_\_ - Count of components with medium risk licenses
- \_\_COUNT\_LOW\_\_ - Count of components with low risk licenses
- \_\_COUNT\_NONE\_\_ - Count of components with no risk licenses

# SECURITY PDF REPORT

The script *project_security_report.sh* will produce a license project report including 2 bar charts
showing security risk (count of components), total count of vulnerabilities and a table of components sorted by vulnerability counts with the following headings:

- Component
- Version
- High
- Medium
- Low

The script uses the template file *template/template_security.json*, and produces an output PDF file *report_security_projname_projversion.pdf* by default.

You can find an example report [here](https://github.com/matthewb66/blackduckPDFreporting/blob/master/examples/report_security_risk_duck-hub_3.0.pdf).

## Running Security Report

Use the command:

	project_security_report.sh projname projversion [pdffile]
	
where:
- *projname* (required) is a full project name string (use quotes if it includes spaces)
- *projversion* (required) is a full version name string (use quotes if it includes spaces)
- *pdffile* (optional) is an alternate output PDF file name.
	
## Configuring Security Report

The template file *template/template_security.json* is used to define the content and layout of the generated PDF file.
To learn more about the json-to-pdf format see here.
Note that it is not possible to remove columns in the table by deleting them from the template alone; you will need to modify
the script logic to delete columns.

Multiple values will be replaced within the template as follows:
- \_\_PROJECTNAME\_\_ - Project name string
- \_\_VERSIONNAME\_\_ - Version name string
- \_\_COMP\_HIGH\_\_ - Count of components with high vulnerability risk
- \_\_COMP\_MEDIUM\_\_ - Count of components with medium vulnerability risk
- \_\_COMP\_LOW\_\_ - Count of components with low vulnerability risk 
- \_\_COMP\_NONE\_\_ - Count of components with no vulnerability risk 
- \_\_VULNS\_HIGH\_\_ - Total count of high risk vulnerabilities
- \_\_VULNS\_MEDIUM\_\_ - Total count of medium risk vulnerabilities
- \_\_VULNS\_LOW\_\_ - Total count of low risk vulnerabilities

# CUSTOM PDF REPORT

The script *project_custom_report.sh* will produce a custom project report including, by default, 3 bar charts
showing security risk (count of components), total count of vulnerabilities and an alphabetical table of components with custom headings.

A template file must be specified as the first argument; an example is provided in *template/template_security.json*.
The output PDF file is *report_security_projname_projversion.pdf* by default.

You can find an example report [here](https://github.com/matthewb66/blackduckPDFreporting/blob/master/examples/report_custom_duck-hub_3.0.pdf).

# Running Custom Report

Use the command:

	project_custom_report.sh template_custom.json projname projversion [pdffile]
	
where:
- *template_custom.json* (required) is a json template file in the template folder (file name only required - not full path). 
- *projname* (required) is a full project name string (use quotes if it includes spaces)
- *projversion* (required) is a full version name string (use quotes if it includes spaces)
- *pdffile* (optional) is an alternate output PDF file name.
	
## Configuring Custom Report

Create a template file if you want to modify the content and layout of the generated PDF file (default example provided in *template/template_custom.json*).

The file contains the json-to-pdf formatting for the start of the document with some fields which will be replaced by values by the script as follows: 
- \_\_PROJECTNAME\_\_ - Project name string
- \_\_VERSIONNAME\_\_ - Version name string
- \_\_SEC\_HIGH\_\_ - Count of components with high risk vulnerabilities
- \_\_SEC\_MEDIUM\_\_ - Count of components with medium risk vulnerabilities
- \_\_SEC\_LOW\_\_ - Count of components with low risk vulnerabilities
- \_\_SEC\_NONE\_\_ - Count of components with no vulnerabilities
- \_\_LIC\_HIGH\_\_ - Count of components with high risk licenses
- \_\_LIC\_MEDIUM\_\_ - Count of components with medium risk licenses
- \_\_LIC\_LOW\_\_ - Count of components with low risk licenses
- \_\_LIC\_NONE\_\_ - Count of components with no risk licenses
- \_\_OP\_HIGH\_\_ - Count of components with high operational risk
- \_\_OP\_MEDIUM\_\_ - Count of components with medium operational risk
- \_\_OP\_LOW\_\_ - Count of components with low operational risk
- \_\_OP\_NONE\_\_ - Count of components with no operational risk

Two lines starting with the strings \_\_TABLE\_ROWS\_\_ and \_\_REPLACEMENTS\_\_ are used to define the layout and content of the table.

The '\_\_TABLE\_ROWS\_\_:' line defines the columns to be shown in the table comprising the fields to be included. The fields are space delimited and are either
in 'jq search format' defining fields to be extracted from the JSON API response or one of the strings \_\_SEC\_TEXT\_\_, \_\_LIC\_TEXT\_\_ or \_\_OP\_TEXT\_\_.
More information about jq search format strings can be found here. The JSON API response includes an array of components called items[] with multiple fields.
An example JSON API response is provided in the file examples/API_components.json.

An example line format is shown below:

    __TABLE_ROWS__:[.items[].componentName] [.items[].componentVersionName] [.items[].usages[0]] [.items[].reviewStatus] [.items[].policyStatus] __SEC_TEXT__

The '\_\_REPLACEMENTS\_\_:' line is used to replace text strings in the table for output formatting. The replacement pairs are separated by '|' and use ';' to separate the original text with the replacement.
To explain why this is required, the '[.items[].reviewStatus]' column will return one of the following values 'DYNAMICALLY\_LINKED,STATICALLY\_LINKED,DEV\_\TOOL\_EXCLUDED' which can be replaced with strings suited to display in the PDF.

An example replacements line is shown below:

    __REPLACEMENTS__:NOT_REVIEWED;No|REVIEWED;Yes|NOT_IN_VIOLATION;Yes|IN_VIOLATION;Yes|DYNAMICALLY_LINKED;Dynamically Linked|STATICALLY_LINKED;Statically Linked|DEV_TOOL_EXCLUDED;Dev Tool/Excluded

# UNDERSTANDING JSON-TO-PDF FILE FORMAT

Json-to-pdf is documented at https://github.com/yogthos/json-to-pdf.

An example json file is available [here](https://github.com/matthewb66/blackduckPDFreporting/blob/master/examples/json-to-pdf_example.json} which shows several of the additional capabilities to format PDF files.
