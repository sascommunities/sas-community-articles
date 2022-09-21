/*

	retreive_relations.sas created by Daan Bijkerk @SAS

	script to collect relations of columns, datasets and libnames within VA reports:
	
		- it creates tables for relationships of columns, datasets and libnames

	required input:
	
		- casuser.VADATA (created by collect_VA_lineage.sas)
	
	regenerates:
	
		- work.column_relations
		- work.dataset_relations
		- work.library_relations
	
	issues:

		-

	investigations:
	
		- 

*/



options nonotes nosource;
/* options notes source; */

%let refresh_cas=1;
%let caslib_out=casuser;

cas;
caslib _all_ assign;


%macro get_relation(level=);
	%put ==INPUT PARAMETERS FOR MACRO: &sysmacroname==;
	%put level=&level;
	%put ==END PARAMETERS FOR MACRO: &sysmacroname====;

	data lineage_with_relations;
		length R_to $400;
		set &caslib_out..vadata(drop=R_from R_to);
		if _n_ = 0 then R_from =0;
		by id report;
		if first.report then R_from+1;
		else R_from=R_from;
	run;

	%let N_reports=;
	proc sql noprint;
		select max(R_from) into :N_reports
		from lineage_with_relations;
	quit;

	data &level._relations;
		length report $ 100.;
		length id $ 36.;
		length R_from $ 3.;
		length R_to $ 3.;
		stop;
	run;

	%do report_from=1 %to &N_reports.;

		proc sql noprint;
			create table from_columns as
			select report, column, library, dataset
			from lineage_with_relations where R_from eq &report_from;
		quit;

		%let report_name=;
		%let report_id=;
		proc sql noprint;
			select distinct report, id into :report_name, :report_id
			from lineage_with_relations where R_from eq &report_from;
		quit;

		%put report_name=&report_name.;
		%put report_id=&report_id.;

		proc sql noprint;
			create table temptemp as
				select distinct put(R.R_from,3.) as R_to length=3,
					"&report_name" as report length=100, 
					"&report_id" as id length=36,
					"&report_from" as R_from  length=3
				from from_columns FC, lineage_with_relations R
		 
			%if  &level eq column %then %do;
					where FC.column eq R.column
					and FC.library eq R.library
					and FC.dataset eq R.dataset	
					and R.R_from ne &report_from;
			%end;
			%if  &level eq dataset %then %do;
					where FC.library eq R.library
					and FC.dataset eq R.dataset
					and R.R_from ne &report_from;
			%end;
			%if  &level eq library %then %do;
					where FC.library eq R.library
					and R.R_from ne &report_from;
			%end;	
		quit;	

		%if &sqlobs ne 0 %then %do;; 

			data &level._relations;
				set &level._relations temptemp;
			run;

		%end;

	%end;
	proc delete data=from_columns; run;
%mend get_relation;

%get_relation(level=column);
%get_relation(level=dataset);
%get_relation(level=library);

/* ------------------------------- bring data to CAS for reporting ---------------------------------------*/


%macro send_to_cas;
	%if &refresh_cas eq 0 %then
		%do;
			%return;
		%end;
	cas;
	caslib _all_ assign;

	proc cas;
		lib="&caslib_out";
		tables={"VADATA_column_relations", "VADATA_dataset_relations", "VADATA_library_relations"};

		do i over tables;
			table.dropTable / quiet=True caslib=lib name=i;
		end;
	quit;

	data &caslib_out..VADATA_column_relations;
		length id $ 36.;
		length report $100;
		set column_relations;
	run;
	data &caslib_out..VADATA_dataset_relations;
		length id $ 36.;
		length report $100;
		set dataset_relations;
	run;
	data &caslib_out..VADATA_library_relations;
		length id $ 36.;
		length report $100;
		set library_relations;
	run;

	proc cas;
		lib="&caslib_out";
		tables={"VADATA_column_relations", "VADATA_dataset_relations", "VADATA_library_relations"};

		do i over tables;
			table.promote / name=i, caslib=lib, targetCaslib=lib;
		end;
	quit;

%mend send_to_cas;

%send_to_cas;




