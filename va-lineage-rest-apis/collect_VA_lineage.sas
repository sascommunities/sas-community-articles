/*

collect_VA_lineage.sas created by Daan Bijkerk @SAS

	script to collect lineage of VA reports in SAS Viya:
	
		- it retreives for each report the used columns (included calculated columns)
		- it processes all this information in a single table
		- it updates the work.lineage table with R_from and R_to columns (relations)

	required input:
	
		- work.reports (a dataset with report name and id)
	
	renerates:
	
		- work.lineage (a collection op report-column mappings)
		- work.lineage_with_relations (updated)
		- casuser.VADATA
	
	investigations:
	
		- does missing DATADEFINITIONS_BUSINESSITEMS or BUSINESSITEMFOLDER_ITEMS really means
			that there are no columns used in the report?
			(EXAMPLE: WARNING: BUSINESSITEMFOLDER_ITEMS does not exist
			(The Official CCBU Presales Team Page,6fe693c4-5a21-4708-9dc2-e8685402afb0))
		- does a 404 for a content request for a report really means there is no (correct) data?
			(EXAMPLE: WARNING: BUSINESSITEMFOLDER_ITEMS does not exist
			(The Official CCBU Presales Team Page,6fe693c4-5a21-4708-9dc2-e8685402afb0))
		- ITEMS_EDITORPROPERTIES seems to be unnecessary to check
			(is already always covered in ITEMS_EXPRESSION?)

*/

/* ------------------------------- settings ---------------------------------------*/


%let BASE_URI=%sysfunc(getoption(SERVICESBASEURL));
%put BASE_URI=&BASE_URI;
%let print_intermediate=0;
%let print_result=0;
%let refresh_cas=1;
%let caslib_out=casuser;

options nonotes nosource minoperator;
/* options notes source minoperator; */

cas;
caslib _all_ assign;

/* ------------------------------- result table ---------------------------------------*/


data _null_;
	if exist("work.lineage") then
		call execute("Proc delete data=work.lineage;run;");
run;


/* ------------------------------- get the lineage ---------------------------------------*/


/* get columns used in item columns */
%macro columns_in_item(dataset=, item=, columns_key=, item_key=);
	%put ==INPUT PARAMETERS FOR MACRO: &sysmacroname==;
	%put dataset=&dataset;
	%put item=&item;
	%put columns_key=&columns_key;
	%put item_key=&item_key;
	%put ==END PARAMETERS FOR MACRO: sysmacroname==;
	%let expressions=0;

	%if not %sysfunc(exist(RCONTENT.&dataset.)) %then
		%do;
			%put no &item columns found: RCONTENT.&dataset. doesnt exist;
			%return;
		%end;
	%else
		%do;
			%let expressions=1;

			proc sql noprint;
				select &item_key from rcontent.&dataset.;
			quit;

			%if &sqlobs eq 0 %then
				%do;
					%put no &item columns found;
					%return;
				%end;
		%end;

	%if &sqlobs eq 0 or &expressions eq 0 %then
		%do;
			%put no &item columns found;
			%return;
		%end;
	%else
		%do;

			/* calculated columns: search in expressions for used columns */
			
			%if &dataset eq ITEMS_EXPRESSION %then
				%do;

					proc sql noprint;
						select name into :all_columns separated by ' ' from 
							rcontent.BUSINESSITEMFOLDER_ITEMS where _element eq "DataItem";
					quit;

					%if &sqlobs eq 0 or &all_columns eq %then
						%do;
							%put no calculated columns found;
							%return;
						%end;
					%let in_calculated_columns=;
					%local i next_name;

					%do i=1 %to %sysfunc(countw(&all_columns));
						%let next_name = %scan(&all_columns, &i);

						data k;
							set rcontent.ITEMS_EXPRESSION;
							b=find(value, "{"||"&next_name"||",");
						run;

						proc sql noprint;
							select * from k where b ne 0;
						quit;

						proc delete data=k;
						run;

						%if &sqlobs ne 0 %then
							%do;
								%let in_calculated_columns = &in_calculated_columns "&next_name";
							%end;
					%end;

					%if &in_calculated_columns eq %then
						%do;
							%put no calculated columns found;
							%return;
						%end;
				%end;

			/* end calculated expressions part only */

			proc sql noprint;
				create table item_table_temp as select DISTINCT BF.name as column_id 
					length=64, BF.xref as xref length=64, BF.ordinal_businessItemFolder as 
					data, "" as dataset length=64 from rcontent.BUSINESSITEMFOLDER_ITEMS BF, 
					rcontent.&dataset. CD 
			
				%if &dataset ne ITEMS_EXPRESSION %then
					%do;
						where BF.&columns_key.=CD.&item_key. and BF._element eq "DataItem"
					%end;
				%else
					%do;
						where BF.name in(&in_calculated_columns);
					%end;
				;
			quit;

			proc sql noprint;
				select distinct(quote(column_id)) into :&item separated by ' ' from 
					item_table_temp;
			quit;

		%if &print_intermediate eq 1 %then
			%do;
				title "&item columns";
	
				proc print data=item_table_temp;
				run;
	
				title;
			%end;
	
		%if &sqlobs. ne 0 %then
			%do;
	
				data temp_item;
					set columns;
				run;
	
				proc sql;
					create table columns as select * from temp_item union all
					(select * from item_table_temp except all select * from temp_item);
				quit;
	
				proc delete data=item_table_temp;
				run;
	
				proc delete data=temp_item;
				run;
	
			%end;
		%else
			%do;
	
				proc delete data=item_table_temp;
				run;
	
				%return;
			%end;
	%end;
%mend columns_in_item;



%macro get_report_resources(reportName=, reportUri=) / minoperator;
	%put --------------------------------------------------------------------------------------;
	%put ==INPUT PARAMETERS FOR MACRO: &sysmacroname==;
	%put reportName=&reportName;
	%put reportUri=&reportUri;
	%put ==END PARAMETERS FOR MACRO: sysmacroname==;

	/* get report content */
	filename rcontent temp;

	proc http oauth_bearer=sas_services method="GET" 
			url="&BASE_URI/reports/reports/&reportUri./content" out=rcontent;
		headers "Accept"="application/vnd.sas.report.content+json";
		debug level=0 OFF;
	run;

	libname rcontent json NO_REOPEN_MSG NOALLDATA MEMLEAVE=ALL JSONCOMPRESS 
		ORDINALCOUNT=2;

	/* response */
	 
	
	%if %symexist(SYS_PROCHTTP_STATUS_CODE) eq 1 %then
		%do;

			/* wrong response */
	    
			
			%if &SYS_PROCHTTP_STATUS_CODE. ne 200 %then
				%do;
					%put WARNING: response: &SYS_PROCHTTP_STATUS_CODE.: &SYS_PROCHTTP_STATUS_PHRASE. (&reportName, 
						&reportUri);
					%return;
				%end;
		%end;
	%else
		%do;
			%put WARNING: the HTTP PROC received no response (&reportName, &reportUri);
			%return;
		%end;

	%if not %sysfunc(exist(rcontent.BUSINESSITEMFOLDER_ITEMS)) %then
		%do;
			%put WARNING: BUSINESSITEMFOLDER_ITEMS does not exist (&reportName, 
				&reportUri);
			%return;
		%end;
	%else %if not %sysfunc(exist(rcontent.DATADEFINITIONS_BUSINESSITEMS)) %then
		%do;
			%put WARNING: DATADEFINITIONS_BUSINESSITEMS does not exist (&reportName, 
				&reportUri);
			%return;
		%end;

	proc sql noprint;
		create table in_report_object as select distinct 
			BF.name as column_id length=64, 
			BF.xref as xref length=64, 
			BF.ordinal_businessItemFolder as data, 
			"" as dataset length=64 
			from rcontent.BUSINESSITEMFOLDER_ITEMS BF, rcontent.DATADEFINITIONS_BUSINESSITEMS DF 
			where ((BF._element='DataItem') and DF.base=BF.name);
	quit;

	%let report_object="";

	proc sql noprint;
		select distinct(quote(column_id)) into :report_object separated by 
			' ' from in_report_object;
	quit;

	%if &print_intermediate eq 1 %then
		%do;
			title 'columns used without considering the calculated columns';

			proc print data=in_report_object;
			run;

			title;
		%end;

	data columns;
		set in_report_object;
	run;

	proc delete data=in_report_object;
	run;


	%let calculated="";
	%columns_in_item(dataset=ITEMS_EXPRESSION, item=calculated, columns_key=dummy, item_key=value);

	%let custom_category="";
	%columns_in_item(dataset=ITEMS_GROUPINGPARAMETERS, item=custom_category, columns_key=name, item_key=parameter);

	%let hierarchy="";
	%columns_in_item(dataset=ITEMS_LEVELLIST, item=hierarchy, columns_key=name, item_key=reference);

	%let geo="";
	%columns_in_item(dataset=ITEMS_GEOINFOS, item=geo, columns_key=ordinal_items, item_key=ordinal_items);
;
	%let primary_key="";
	%columns_in_item(dataset=ITEMS_PRIMARYKEY, item=primary_key, columns_key=ordinal_items, item_key=ordinal_items);

	%let partition="";
	%columns_in_item(dataset=ITEMS_PARTITIONS, item=partition, columns_key=ordinal_items, item_key=ordinal_items);

	%let editor_properties="";
	%columns_in_item(dataset=ITEMS_EDITORPROPERTIES, item=editor_properties, columns_key=ordinal_items, item_key=ordinal_items);

	/* adding table information */
	data va_datasets(replace=yes);
		set rcontent.datasources;
	run;

	proc sql noprint;
		update columns set dataset=(select label from va_datasets where 
			va_datasets.ordinal_dataSources=columns.data) where columns.data in(select 
			ordinal_dataSources from va_datasets);
	quit;

	proc delete data=va_datasets;
	run;

	proc sql;
		create table temp_lineage as select 
			C.xref as column, 
			C.column_id, 
			C.dataset, 
			upcase(CR.library) as library length=25, 
			case when C.column_id in(&report_object) then 'Y' else 'N' end as in_report_object, 
			case when C.column_id in(&calculated) then 'Y' else 'N' end as in_calculated, 
			case when C.column_id in(&custom_category) then 'Y' else 'N' end as in_custom_category, 
			case when C.column_id in(&hierarchy) then 'Y' else 'N' end as in_hierarchy, 
			case when C.column_id in(&geo) then 'Y' else 'N' end as in_geo, 
			case when C.column_id in(&primary_key) then 'Y' else 'N' end as in_primarykey, 
			case when C.column_id in(&partition) then 'Y' else 'N' end as in_partition, 
			case when C.column_id in(&editor_properties) then 'Y' else 'N' end as in_editorproperties 
			from RCONTENT.DATASOURCES_CASRESOURCE CR, columns C 
			where C.dataset eq CR.table;
	quit;

	proc delete data=columns;
	run;

	%if not %sysfunc(exist(lineage)) %then
		%do;

			data lineage;
				id=symget('reportUri');
				report=symget('reportName');
				set temp_lineage;
			run;

			proc sort data=lineage out=lineage nodupkey;
				by _all_;
			run;

		%end;
	%else
		%do;

			data temp_lineage;
				id=symget('reportUri');
				report=symget('reportName');
				set temp_lineage;
			run;

			proc sort data=temp_lineage out=temp_lineage nodupkey;
				by _all_;
			run;

			data lineage;
				set lineage temp_lineage;
			run;

		%end;

	proc delete data=temp_lineage;
	run;

	%if &print_result eq 1 %then
		%do;
			title "RESULT: columns used in report: &reportName (&reportUri)";

			proc print data=lineage;
			run;

			title;
		%end;
	%let items=;

	proc sql noprint;
		select memname into :items separated by ' ' from dictionary.tables where 
			libname eq 'RCONTENT' and memname like "ITEMS_%";
	quit;

	%put &items;

	%if &sqlobs ne 0 %then
		%do;
			%local i next_mem;

			%do i=1 %to %sysfunc(countw(&items));
				%let next_mem = %scan(&items, &i);

				%if not(&next_mem in ITEMS_EXPRESSION ITEMS_GROUPINGPARAMETERS 
					ITEMS_LEVELLIST ITEMS_GEOINFOS ITEMS_PRIMARYKEY ITEMS_PARTITIONS 
					ITEMS_EDITORPROPERTIES) %then
						%do;
						%put WARNING: There might be columns missed: see &next_mem;
					%end;
				%else
					%do;
						%put check;
					%end;
			%end;
		%end;
%mend get_report_resources;



data _null_;
	set reports;
	call execute(cats('%nrstr(%%get_report_resources)', '(reportName=', name, ',', 
		'reportUri=', id, ');'));
	filename rcontent clear;
	libname rcontent clear;
run;

proc sort data=lineage(drop=column_id) out=lineage nodupkey;
	by _all_;
run;

%macro update_lineage_with_relations;

	proc sort data=lineage out=lineage;
		by id report;
	run;
	
	data lineage_with_relations;
		length R_to $400;
		set lineage;
		if _n_ = 0 then R_from =0;
		by id report;
		if first.report then R_from+1;
		else R_from=R_from;
		R_to="";
	run;

	%let N_reports=;
	proc sql noprint;
		select max(R_from) into :N_reports
		from lineage_with_relations;
	quit;

	%do report_from=1 %to &N_reports.;

		/* create R_to column */
		proc sql noprint;
			create table from_columns as
			select report, column, library, dataset
			from lineage_with_relations where R_from eq &report_from;
		quit;

		%let reports_to=;
		proc sql noprint;
			select distinct R_from into: reports_to separated by ' '
			from from_columns FC, lineage_with_relations R
			where FC.column eq R.column
				and FC.library eq R.library
				and FC.dataset eq R.dataset
				and R.R_from ne &report_from
		;quit;	
		proc delete data=from_columns; run;		

		proc sql noprint;
			update lineage_with_relations 
			set R_to = "&reports_to"
			where R_from eq &report_from
		;quit;	

	%end;

	data lineage_with_relations(drop=from);
		length R_to $400;
		set lineage_with_relations(rename=(R_from=from));
		R_from = put(from, 6.);
	run;

%mend update_lineage_with_relations;

%update_lineage_with_relations;


/* ------------------------------- print the results ---------------------------------------*/
title "number of reports in lineage";

proc sql;
	select count(distinct id) as N_reports from lineage;
quit;

title;
title "summary report columns per report (dataset & library)";

proc sql;
	select report, library, dataset, id, count(*) as N from lineage group by id, 
		report, dataset, library
	order by report, library, dataset;
quit;

title;


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
		tables={"vadata"};

		do i over tables;
			table.dropTable / quiet=True caslib=lib name=i;
		end;
	quit;

	data &caslib_out..vadata;
		set lineage_with_relations;
	run;

	proc cas;
		lib="&caslib_out";
		tables={"vadata"};

		do i over tables;
			table.promote / name=i, caslib=lib, targetCaslib=lib;
		end;
	quit;

%mend send_to_cas;

%send_to_cas;



