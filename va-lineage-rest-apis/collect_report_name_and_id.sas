/*

	collect_report_name_and_id.sas created by Daan Bijkerk @SAS

	script to collect information of VA reports in SAS Viya:

		- it collects in parts (all) the reports in an SAS Viya environment

	renerates:
	
		- work.reports (a dataset with report name and id)

	issues:
		
		- to grab more then 100 reports directly from the API fails. (API returns 500 and 503)
		- this also collects reports that are in the waste bin (older versions for exampe)

	improvements:

		- allow better selection of reports to be analysed (improve flexibility filter used)

*/


/* ------------------------------- settings ---------------------------------------*/


%let number_of_reports=100;
%let BASE_URI=%sysfunc(getoption(SERVICESBASEURL));
%put BASE_URI=&BASE_URI;

options nonotes nosource minoperator;

/* options notes source minoperator; */

/* ------------------------------- result table ---------------------------------------*/


data _null_;
   if exist("work.reports") then 
   call execute("Proc delete data=work.reports;run;");
run;


/* ------------------------------- get the reports ---------------------------------------*/


%macro get_all_reports;


	%macro get_report(start=);
		%put ==INPUT PARAMETERS FOR MACRO: &sysmacroname==;
		%put start=&start;
		%put ==END PARAMETERS FOR MACRO: &sysmacroname====;
		FILENAME reportsL TEMP ENCODING='UTF-8';

		proc http url="&BASE_URI/reports/reports" method=GET out=reportsL 
				oauth_bearer=sas_services query=("limit"="&number_of_reports." 
				"filter"="startsWith(id,&start)");
			HEADERS "Accept"="application/vnd.sas.collection+json" 
				"Accept-Item"="application/vnd.sas.summary+json";
			debug level=0 OFF;
		run;

		/* response */
		 
		%if %symexist(SYS_PROCHTTP_STATUS_CODE) eq 1 %then
			%do;

				/* wrong response */
		    
				%if &SYS_PROCHTTP_STATUS_CODE. ne 200 %then
					%do;
						%put WARNING: response: &SYS_PROCHTTP_STATUS_CODE.: &SYS_PROCHTTP_STATUS_PHRASE.;
						filename reportsL clear;
						%return;
					%end;
			%end;
		%else
			%do;
				%put WARNING: the PROC HTTP received no response;
				filename reportsL clear;
				%return;
			%end;
		LIBNAME reportsL json NO_REOPEN_MSG NOALLDATA MEMLEAVE=ALL JSONCOMPRESS 
			ORDINALCOUNT=all;

		%if not %sysfunc(exist(reportsL.ITEMS)) %then
			%do;
				%put WARNING: no report start with &start;
				filename reportsL clear;
				%return;
			%end;
		%else
			%do;

				data test;
					set reportsL.ITEMS;
				run;

				%let varexist=0;

				proc sql noprint;
					select count(*) into :varexist from dictionary.columns where 
						libname="WORK" and memname="TEST" and upcase(name)="ID";
				quit;

				%if &varexist eq 0 %then
					%do;
						%put there is no id column;
						%return;
					%end;
				%else
					%do;

						proc sql noprint;
							select name, id from reportsL.ITEMS;
						quit;

						%if &sqlobs eq &number_of_reports %then
							%do;
								%put WARNING: possible not all reports have been collected;
							%end;
					%end;
			%end;

		%if not %sysfunc(exist(reports)) %then
			%do;

				proc sql noprint;
					create table reports as select name as name length 200, id from 
						reportsL.ITEMS order by modifiedTimeStamp desc;
				quit;

			%end;
		%else
			%do;

				proc sql noprint;
					create table temp as select name as name length 200, id from 
						reportsL.ITEMS order by modifiedTimeStamp desc;
				quit;

				data reports;
					set reports temp;
				run;

			%end;
		proc delete data=temp; run;
		proc delete data=test; run;
	%mend get_report;


	%let startwith=a b c d e f 0 1 2 3 4 5 6 7 8 9;
	%local j next_start;

	%do j=1 %to %sysfunc(countw(&startwith));
		%let next_start = %scan(&startwith, &j);
		%get_report(start=&next_start.);
		filename reportsL clear;
		LIBNAME reportsL clear;
	%end;

%mend get_all_reports;

%get_all_reports;

/* partition columns example */
/* data reports; */
/*    length name $200 id $36.; */
/*    infile datalines delimiter=',';  */
/*    input name $ id $; */
/*    datalines;                       */
/* Example report,bb2cf5ed-24ff-40d1-934a-d319757667f7 */
/* ; */

