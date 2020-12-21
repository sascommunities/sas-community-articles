/* 1. Inputs */

%let rep_id = e720dcda-d654-4cf1-a316-1b34d6de80f9;

%let new_params = '{"resultParentFolderUri": "/folders/folders/9e8bb64e-f359-4c37-ab42-167ebabd564c","inputReportUri": "/reports/reports/e720dcda-d654-4cf1-a316-1b34d6de80f9","substitutionParameters": [{"key": "pr39","label": "Button bar - ReportParameterChangeMe","site": "parameterDefinition","structure": "single","type": "string","values": ["UPDATEVALUE"]}],"resultReportName": "NewReportName"}';

/*
 * get the base_uri to make all API calls
 */

%let BASE_URI = %sysfunc(getoption(servicesbaseurl));
%let BASE_URI = %substr(&BASE_URI, 1, %length(&BASE_URI)-1);
%put NOTE: &=BASE_URI;

/*
	2. GET REPORT PARAMETERS - OPTIONAL
	VERIFY THERE ARE PARAMETERS ON THE REPORT
    Parameters stored in REPPRMS.SUBSTITUTIONPARAMETERS
*/

filename repp TEMP;

proc http method='GET' 
	out=repp 
	url="&BASE_URI/reportTransforms/parameterizedReports/&rep_id./parameters"
	oauth_bearer=sas_services;
	headers "Content-Type"="application/json";

run;

libname repprms JSON fileref=repp;

/*
	3. UPDATE REPORT PARAMS using values in substitutionParameters
*/

filename repnp TEMP;

data _null_;
	file repnp;
	put &new_params;
run;

data _null_;
	infile repnp;
	input;
	putlog _infile_;
run;

filename repup TEMP;

proc http method="POST" in=repnp out=repup 
		url="&BASE_URI/reportTransforms/parameterizedReports" 
		query=("validate"="true" "useSavedReport"="true" "failOnError"="true" 
		"saveResult"="true" "replaceSavedReport"="true")
		oauth_bearer=sas_services;
	headers "Content-Type"="application/vnd.sas.report.transform+json" 
		"Accept"="application/vnd.sas.report.transform+json";
run;

libname nparams JSON fileref=repup;

/* 4.
 * get report elements
 * using this API
 * https://developer.sas.com/apis/rest/Visualization/#get-report-content-elements
 */

filename resp temp;

proc http
  method='GET' 
  url="&BASE_URI./reports/reports/&rep_id/content/elements"
  oauth_bearer=sas_services
  out=resp
  verbose
  ;
  headers
  "Accept" = "application/vnd.sas.collection+json"
  ;
  debug level=0;
run;
%put NOTE: &=SYS_PROCHTTP_STATUS_CODE;
%put NOTE: &=SYS_PROCHTTP_STATUS_PHRASE;

%put NOTE: resp json pretty print;
%*put %sysfunc( jsonpp(resp, log));
libname resp json;

title "Report elements root";
proc print data=resp.root;
run;
title "Report elements (items)";
proc print data=resp.items;
run;

/* 5.
 * get the visual elements we want
 * the are later used in the job creation
 */
proc sql noprint;
  select 
    name
  into 
    :visualElements separated by ","
  from
    resp.items
  where
   lowcase(type) in ("graph", "crosstab", "table", "text")
    
    and label ne " "
  ;
  %let n_visualElements = &sqlobs;
quit;
%put NOTE: &=n_visualElements;
%put NOTE: &=visualElements;

/* 6.
 * now get the image
 * 1. create a job
 * 2. check if finished
 * 3. get the image
 *  
 */

/* 6.1.
 * create a job to create the image
 * using this API
 * https://developer.sas.com/apis/rest/Visualization/#get-report-images-via-report-in-request-body
 */
filename resp temp;
proc http
  method='POST' 
  url="&BASE_URI/reportImages/jobs"
  oauth_bearer=sas_services
  query =(
 
    "reportUri" = "/reports/reports/&rep_id"
    "layoutType" = "normal" 
    "selectionType" = "visualElements" 
    "visualElementNames" = "&visualElements" 
    "size" = "900x692"
    "wait" = "1" /* we wait 5 seconds for thr image to be created */
 )

  out=resp
  verbose
  ;
  headers
    "Accept" = "application/vnd.sas.report.images.job+json"
   /* "Accept-Language" = "de-CH" */
/*     "Content-Type" = "application/vnd.sas.report.images.job.request+json" */
  ;
  debug level=0;
run;
%put NOTE: &=SYS_PROCHTTP_STATUS_CODE;
%put NOTE: &=SYS_PROCHTTP_STATUS_PHRASE;

%put NOTE: response create image job;
%*put %sysfunc( jsonpp(resp, log));

libname resp json;
title "create jobs root";
proc print data=resp.root;
run;

/*
 * get the jobid
 */
proc sql noprint;
  select
    id
  into
    :jobid trimmed
  from
    resp.root
  ;
quit;
%put NOTE: &=jobid;
  
/* 6.2.
 * check if job completed
 * using this API
 * https://developer.sas.com/apis/rest/Visualization/#get-the-state-of-the-job
 */
%macro va_img_check_jobstatus(
  jobid=
  , sleep=1
  , maxloop=50
);
%local jobStatus i;

%do i = 1 %to &maxLoop;
  filename jobrc temp;
  proc http
    method='GET' 
    url="&BASE_URI//reportImages/jobs/&jobid/state"
    oauth_bearer=sas_services
  
    out=jobrc
    verbose
    ;
    headers
      "Accept" = "text/plain"
    ;
    debug level=0;
  run;
  %put NOTE: &=SYS_PROCHTTP_STATUS_CODE;
  %put NOTE: &=SYS_PROCHTTP_STATUS_PHRASE;
  
  %put NOTE: response check job status;
  data _null_;
      infile jobrc;
      input line : $32.;
      putlog "NOTE: &sysmacroname jobId=&jobid i=&i status=" line;
      if line in ("completed", "failed") then do;
      end;
      else do;
        putlog "NOTE: &sysmacroname &jobid status=" line "sleep for &sleep.sec";
        rc = sleep(&sleep, 1);
      end;  
      call symputx("jobstatus", line);
  run;
  filename jobrc clear;
  %if &jobstatus = completed %then %do;
    %put NOTE: &sysmacroname &=jobid &=jobStatus;
    %return;
  %end;
  %if &jobstatus = failed %then %do;
    %put ERROR: &sysmacroname &=jobid &=jobStatus;
    %return;
  %end;
%end;
%mend;

%va_img_check_jobstatus(jobid=&jobid)

/*
 * Get job info
 * using API
 * https://developer.sas.com/apis/rest/Visualization/#get-specified-job
 */
filename resp temp;
proc http
  method='GET' 
  url="&BASE_URI/reportImages/jobs/&jobid"
  oauth_bearer=sas_services
  out=resp
  verbose
  ;
  headers
    "Accept" = "application/vnd.sas.report.images.job+json"
    "Content-Type" = "application/vnd.sas.report.images.job.request+json"
  ;
  debug level=0;
run;
%put NOTE: &=SYS_PROCHTTP_STATUS_CODE;
%put NOTE: &=SYS_PROCHTTP_STATUS_PHRASE;

%put NOTE: response create image job;
%*put %sysfunc( jsonpp(resp, log));

libname resp json;
title "get report images root";
proc print data=resp.root;
run;
title "get report images links";
proc print data=resp.images_links;
run;
title;

proc sql;
  create table img_info as
  select
    img.*
    , imgl.*
  from
    resp.images as img
    , resp.images_links as imgl
  where
    img.ordinal_images = imgl.ordinal_images
    and method = "GET"
    and rel = "image"
  ;
quit;

/* 6.3.
 * macro to get images
 * using API
 * https://developer.sas.com/apis/rest/Visualization/#get-image
 */
%macro va_report_get_image(
method=get
, imghref=
, outfile=
, type=
, jobid=
);
%put NOTE: &sysmacroname &method &imghref &outfile;

data _null_;
  rc = dcreate("&jobid", "~");
run;
filename img "~/&jobid/&outfile..svg";
proc http
  method = "&method"
  url = "&BASE_URI/&imghref"
  out=img
  oauth_bearer=sas_services
  verbose
;
  headers
    "Accept" = "&type"
    "Content-Type" = "application/vnd.sas.report.images.job.request+json"
  ;
  debug level=0;
run;
%put NOTE: response get image;
%put NOTE: &=SYS_PROCHTTP_STATUS_CODE;
%put NOTE: &=SYS_PROCHTTP_STATUS_PHRASE;
%mend;

/*
 * build macro calls
 */
filename getimg temp;
data _null_;
  set img_info;
  file getimg;
  length line $ 2048;
  line = cats(
    '%va_report_get_image('
    , cats("method=", method)
    , ","
    , cats("imghref=", href)
    , ","
    , cats("type=", type)
    , ","
    , cats("outfile=", catx("_", sectionName, elementName,  visualType) )
    , ","
    , "jobid=&jobid"
    , ")"
  );
  put line;
  putlog line;
run;

%inc getimg / source2;

/* 7. GENERATE PNG FROM SVG */

%let save_dir = /home/sasdemo;

options set=PATH="/var/lib/snapd/snap/bin/:$PATH";

%macro transform_image(name, folder);

 	filename timg pipe "inkscape --export-filename=&save_dir/&folder/&name..png &save_dir/&folder/&name..svg";
	data _null_;
		infile timg;
		input;
		put _infile_;
	run;
%mend;


filename transf temp;
data _null_;
  set img_info;
  file transf;
  length line $ 2048;
  line = cats(
    '%transform_image('
    , cats("name=", catx("_", sectionName, elementName,  visualType) )
    , ","
    , "folder=&jobid"
    , ")"
  );
  put line;
  putlog line;
run;

%inc transf / source2;  


/* 8. GENERATE PPT FROM PNG */


%macro print_images(name, folder, titl);

	title "Export for graph: &titl";

	data _NULL_;
	 	dcl odsout obj();
	 	obj.image(file:"&save_dir/&folder/&name..png", height:"800", width:"800");
	run;

%mend;

filename ppt temp;

data _null_;
  set img_info;
  file ppt;
  length line $ 2048;
  line = cats(
    '%print_images('
    , cats("name=", catx("_", sectionName, elementName,  visualType) )
    , ","
    , "folder=&jobid,"
    , cats("titl=",sectionLabel)
	, ")" 
  );
  put line;
  putlog line;
run;


ods powerpoint file="&save_dir/&jobid/new_ppt.pptx";

%inc ppt / source2;  

ods powerpoint close;