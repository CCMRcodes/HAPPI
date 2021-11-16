/*Author: Shirley Wang (xiaoqing.wang@va.gov)*/
libname final '';
libname happi '';
libname labs '';
libname vitals '';
libname meds '';
libname temp '';
libname temp2 '';
libname sarah ''; 
libname acute '';


/****************** HAPPI CODES FOR AIM 2 ****************/
/*select only the HAPPI cohort*/
PROC SQL;
CREATE TABLE  aim2_happicohrot  (COMPRESS=YES) AS 
SELECT A.* FROM happi.HAPPIVAPD20132018_20200515 AS A
WHERE A.unique_hosp_count_id IN (SELECT  unique_hosp_count_id FROM happi.UNIQHAPPICRT_20132018_SW210105);
QUIT;

PROC SORT DATA=aim2_happicohrot;
BY  unique_hosp_count_id;
RUN;

/*get certain daily lab values back*/
/*low_plat, low_wbc, hi_ALT, hi_bili, hi_creat*/

/*platelet*/
DATA plat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET labs.PLAT_2018HAPPI_20200429 labs.plat_20162017happi_02112020 labs.PLAT_20122013HAPPI_03272020  labs.PLAT_20142015HAPPI_02112020 labs.PLAT_2019HAPPI_20200728;
RUN;

PROC SQL;
CREATE TABLE   plat_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM plat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  aim2_happicohrot);
QUIT;

%delete_ds(dslist =plat_20132017happi_02112020);

/*create HIGH & LOW values by patient and date*/ 
PROC SQL; 
CREATE TABLE all_plate_lo_2013_2018  AS    
SELECT *,  min(LabChemResultNumericValue) as lo_plate_daily 
FROM  plat_20132017happi_v1 
GROUP BY patienticn, LabSpecimenDate 
ORDER BY patienticn, LabSpecimenDate; 
QUIT; 
 
/*remove dupicate high and low values by patient-day before left join to VAPD cohort*/ 
PROC SORT DATA=all_plate_lo_2013_2018  nodupkey; 
BY  patienticn LabSpecimenDate ; 
RUN; 

/*WBC*/
DATA wbc_20132017happi (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET  labs.wbc_2014happi_02112020  labs.wbc_2015happi_02112020  labs.wbc_2016happi_02112020  labs.wbc_2017happi_02112020  labs.wbc_20122013happi_03272020
labs.WBC_2018HAPPI_20200429 labs.WBC_2019HAPPI_20200728;
RUN;

PROC SQL;
CREATE TABLE wbc_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM wbc_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM aim2_happicohrot);
QUIT;

%delete_ds(dslist=wbc_20132017happi);

/*create HIGH & LOW values by patient and date*/ 
PROC SQL; 
CREATE TABLE all_WBC_lo_2013_2018  AS    
SELECT *,  min(LabChemResultNumericValue) as lo_WBC_daily 
FROM  wbc_20132017happi_v1
GROUP BY patienticn, LabSpecimenDate 
ORDER BY patienticn, LabSpecimenDate; 
QUIT; 
 
/*remove dupicate high and low values by patient-day before left join to VAPD cohort*/ 
PROC SORT DATA=all_WBC_lo_2013_2018  nodupkey;
BY  patienticn LabSpecimenDate ; 
RUN; 

/*Creatinine*/
DATA creat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*combine all years of labs data*/
SET labs.CREAT_2018HAPPI_20200429 labs.creat_20162017happi_02112020 labs.CREAT_20122013HAPPI_03272020  labs.CREAT_20142015HAPPI_02112020 labs.CREAT_2019HAPPI_20200728;
RUN;

PROC SQL;
CREATE TABLE   creat_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM creat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  aim2_happicohrot);
QUIT;

%delete_ds(dslist =creat_20132017happi_02112020);

/*create HIGH & LOW values by patient and date*/ 
PROC SQL; 
CREATE TABLE all_creat_hi_2013_2018  AS    
SELECT *,  max(LabChemResultNumericValue) as hi_creat_daily 
FROM  creat_20132017happi_v1
GROUP BY patienticn, LabSpecimenDate 
ORDER BY patienticn, LabSpecimenDate; 
QUIT; 

/*remove dupicate high and low values by patient-day before left join to VAPD cohort*/ 
PROC SORT DATA=all_creat_hi_2013_2018 nodupkey;  
BY  patienticn LabSpecimenDate; 
RUN; 

/*bilirubin*/
DATA bili_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*combine all years of labs data*/
SET labs.BILI_2018HAPPI_20200429 labs.BILI_20142017HAPPI_02112020 labs.BILI_20122013HAPPI_03272020 labs.BILI_2019HAPPI_20200728;
RUN;

PROC SQL;
CREATE TABLE   bili_20132017happi_v1 (COMPRESS=YES) AS 
SELECT A.* FROM bili_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  aim2_happicohrot);
QUIT;

%delete_ds(dslist =bili_20132017happi_02112020);

/*create HIGH & LOW values by patient and date*/ 
PROC SQL; 
CREATE TABLE all_bili_hi_2013_2018  AS    
SELECT *,  max(LabChemResultNumericValue) as hi_bili_daily 
FROM   bili_20132017happi_v1 
GROUP BY patienticn, LabSpecimenDate 
ORDER BY patienticn, LabSpecimenDate; 
QUIT; 

/*remove dupicate high and low values by patient-day before left join to VAPD cohort*/ 
PROC SORT DATA=all_bili_hi_2013_2018 nodupkey;  
BY  patienticn LabSpecimenDate; 
RUN; 

/*ALT, 180-day,daily, and 72hrED*/
PROC SQL;
CREATE TABLE  alt_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM labs.ALT20132019_HAPPI_20200728 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  aim2_happicohrot);
QUIT;

/*create HIGH & LOW values by patient and date*/ 
PROC SQL; 
CREATE TABLE all_ALT_hi_2013_2018  AS    
SELECT *,  max(LabChemResultNumericValue) as hi_ALT_daily 
FROM   alt_20132017happi_v1 
GROUP BY patienticn, LabSpecimenDate 
ORDER BY patienticn, LabSpecimenDate; 
QUIT; 

/*remove dupicate high and low values by patient-day before left join to VAPD cohort*/ 
PROC SORT DATA=all_ALT_hi_2013_2018 nodupkey;  
BY  patienticn LabSpecimenDate; 
RUN; 

/*get the 180-day, 90-day, hosp and 72hr window*/
/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_ALT2017  (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as ALT_value
	FROM  AIM2_HAPPICOHROT  A
	LEFT JOIN  alt_20132017happi_v1 B ON A.patienticn=B.patienticn;
QUIT;

/*ALT if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
/*(-180days & -90days thru hospital discharge) for labs */
DATA ALT_180day (compress=yes) 
     ALT_90day (compress=yes) 
     ALT_fromED_72hr_keep (compress=yes) 
     ALT_hosp (compress=yes); 
SET labs_ALT2017;
datediff_days=intck('day',LabSpecimenDate,new_dischargedate3); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if  new_admitdate3 <= LabSpecimenDate <= new_dischargedate3 then hosp_keep=1;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if lab_180day=1 then output ALT_180day;
if lab_90day=1 then output ALT_90day;
if hosp_keep=1 then output ALT_hosp;
if fromED_72hr_keep=1 then output ALT_fromED_72hr_keep;
RUN;

%delete_ds(dslist =labs_ALT2017);

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=ALT_180day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=ALT_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=ALT_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

proc sort data=ALT_hosp;
by unique_hosp_count_id LabChemSpecimenDateTime;
run;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.ALT20132018_fromED_72hr (compress=yes)  AS   
SELECT *, min(ALT_value) as lo_ALT_72hrED, max(ALT_value) as hi_ALT_72hrED
FROM ALT_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.ALT20132018_fromED_72hr  nodupkey ;
BY  unique_hosp_count_id lo_ALT_72hrED hi_ALT_72hrED;
RUN;

DATA labs.ALT20132018_fromED_72hr  (compress=yes) ;
SET  labs.ALT20132018_fromED_72hr ;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate ALT_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.ALT20132018_180day (compress=yes)  AS  
SELECT *, min(ALT_value) as lo_ALT_180day, max(ALT_value) as hi_ALT_180day
FROM ALT_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.ALT20132018_180day   nodupkey; 
BY  unique_hosp_count_id lo_ALT_180day hi_ALT_180day;
RUN;

DATA labs.ALT20132018_180day (compress=yes);
SET  labs.ALT20132018_180day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate ALT_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.ALT20132018_90day (compress=yes)  AS   
SELECT *, min(ALT_value) as lo_ALT_90day, max(ALT_value) as hi_ALT_90day
FROM ALT_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.ALT20132018_90day nodupkey; 
BY  unique_hosp_count_id lo_ALT_90day hi_ALT_90day;
RUN;

DATA labs.ALT20132018_90day  (compress=yes);
SET  labs.ALT20132018_90day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate ALT_value hour_diff fromED_72hr_keep;
RUN;

/*get ALT hospitalizaton hi and low values*/
PROC SQL;
CREATE TABLE labs.ALT20132018_hosp (compress=yes)  AS   
SELECT *, min(ALT_value) as lo_ALT_hosp, max(ALT_value) as hi_ALT_hosp
FROM ALT_hosp
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.ALT20132018_hosp nodupkey; 
BY  unique_hosp_count_id lo_ALT_hosp hi_ALT_hosp;
RUN;

DATA labs.ALT20132018_hosp (compress=yes);
SET  labs.ALT20132018_hosp;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate ALT_value hour_diff fromED_72hr_keep;
RUN;


/*merge all the lab values back to HAPPI cohort daily*/
PROC SQL;
	CREATE TABLE  AIM2_HAPPIcohort_v2  (compress=yes)  AS 
	SELECT A.*, B.hi_ALT_180day,  C.hi_ALT_hosp, d.hi_ALT_72hrED, e.hi_ALT_daily, f.hi_bili_daily, g.hi_creat_daily, h.lo_wbc_daily, i.lo_plate_daily
	FROM  AIM2_HAPPICOHROT   A
	LEFT JOIN  labs.ALT20132018_180day B ON A.unique_hosp_count_id =B.unique_hosp_count_id 
    LEFT JOIN  labs.ALT20132018_hosp C ON A.unique_hosp_count_id =C.unique_hosp_count_id 
    LEFT JOIN  labs.ALT20132018_fromED_72hr D ON A.unique_hosp_count_id =D.unique_hosp_count_id 
    LEFT JOIN  ALL_ALT_HI_2013_2018  E ON A.patienticn =E.patienticn and a.datevalue=e.LabSpecimenDate
    LEFT JOIN  ALL_bili_HI_2013_2018  F ON A.patienticn =F.patienticn and a.datevalue=f.LabSpecimenDate
    LEFT JOIN ALL_creat_HI_2013_2018 G ON A.patienticn =g.patienticn and a.datevalue=g.LabSpecimenDate
    LEFT JOIN ALL_wbc_LO_2013_2018 h ON A.patienticn=h.patienticn and a.datevalue=h.LabSpecimenDate
	LEFT JOIN ALL_Plate_LO_2013_2018 i ON A.patienticn=i.patienticn and a.datevalue=i.LabSpecimenDate;
QUIT;

/*get EDIS arrival date*/
DATA AIM2_HAPPIcohort_v2b (compress=yes); 
SET AIM2_HAPPIcohort_v2;
edisarrivaldate= datepart(earliest_edisarrivaltime_hosp);
format edisarrivaldate mmddyy10.;
RUN;



/*Thrombocytopenia: "The lowest platelet count during days 2-12 after ED arrival meets BOTH criteria:
•	 < 150 cells/L
•	a >50% decline from the lowest platelet count during the 72-hr screening window".*/

/*get the lowest plat value during days2-12 per hosp*/
DATA low_plat_days2_12_hosp (compress=yes); 
SET AIM2_HAPPIcohort_v2b;
day2_date=edisarrivaldate+2;
day12_date=edisarrivaldate+12;
format day2_date mmddyy10. day12_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 lo_plat_72hred  hospital_day hosp_los day12_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=low_plat_days2_12_hosp  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE low_plat_days2_12_hosp_v2  (compress=yes)  AS
	SELECT A.*, b.LabSpecimenDate, b.LabChemResultNumericValue as Plat_value
	FROM  low_plat_days2_12_hosp    A
	LEFT JOIN  plat_20132017happi_v1 B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA= low_plat_days2_12_hosp_v2;
BY  unique_hosp_count_id LabSpecimenDate;
RUN;

DATA low_plat_days2_12_hosp_v3 (compress=yes);
SET low_plat_days2_12_hosp_v2;
if  day2_date <= LabSpecimenDate <= day12_date then keep=1;
if keep=1;
RUN;

PROC SQL;
CREATE TABLE low_plat_days2_12_hosp_v4 (compress=yes)  AS   
SELECT *, min(Plat_value) as low_plat_days2_12_hosp
FROM low_plat_days2_12_hosp_v3
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=low_plat_days2_12_hosp_v4  nodupkey; 
BY  unique_hosp_count_id low_plat_days2_12_hosp;
RUN;

/*merge low_plat_days2_12_hosp2 back to AIM2_HAPPIcohort_v2 */
PROC SQL;
	CREATE TABLE  AIM2_HAPPIcohort_v3 (compress=yes)  AS
	SELECT A.*, B.low_plat_days2_12_hosp
	FROM  AIM2_HAPPIcohort_v2   A
	LEFT JOIN  low_plat_days2_12_hosp_v4 B ON A.unique_hosp_count_id=B.unique_hosp_count_id;
QUIT;

DATA platelets (compress=yes);
SET AIM2_HAPPIcohort_v3;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 lo_plat_72hred lo_plate_daily hospital_day hosp_los low_plat_days2_12_hosp; 
RUN;

DATA platelets2 (compress=yes);
SET  platelets;
if (low_plat_days2_12_hosp NE . and low_plat_days2_12_hosp<150 )
 and (low_plat_days2_12_hosp NE . and low_plat_days2_12_hosp < (lo_plat_72hred*0.5)) 
    then Thrombocytopenia=1;
      else Thrombocytopenia=0;
run;

PROC FREQ DATA=platelets2  order=freq;
TABLE Thrombocytopenia;
RUN;

DATA Thrombocytopenia_daily (compress=yes);
SET  platelets2;
if Thrombocytopenia=1;
RUN;

PROC SORT DATA=Thrombocytopenia_daily  nodupkey  OUT=Thrombocytopenia_hosp (compress=yes);
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE  Thrombocytopenia_hosp_v2 (compress=yes)  AS
	SELECT A.*, B.Thrombocytopenia as Thrombocytopenia_hosp
	FROM  platelets  A
	LEFT JOIN  Thrombocytopenia_hosp B ON A.unique_hosp_count_id =B.unique_hosp_count_id;
QUIT;

DATA Thrombocytopenia_hosp_v3 (compress=yes); 
SET  Thrombocytopenia_hosp_v2;
if Thrombocytopenia_hosp Ne 1 then Thrombocytopenia_hosp =0;
admityear=year(new_admitdate3);
RUN;

PROC SORT DATA=Thrombocytopenia_hosp_v3  nodupkey;
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=Thrombocytopenia_hosp_v3  order=freq;
TABLE  admityear;
RUN;

PROC SORT DATA=Thrombocytopenia_hosp_v3;
BY admityear;
RUN;

PROC FREQ DATA=Thrombocytopenia_hosp_v3;
by admityear;
TABLE  Thrombocytopenia_hosp;
RUN;

DATA happi.HAPPI_AIM2_Thrombocytopenia_hosp (compress=yes); 
SET Thrombocytopenia_hosp_v3;
if Thrombocytopenia_hosp=1;
RUN;

PROC SORT DATA=happi.HAPPI_AIM2_Thrombocytopenia_hosp  nodupkey  OUT=test;
BY  unique_hosp_count_id;
RUN;




/*Leukopenia (low white blood cell count):
"The lowest white blood cell count (WBC) during days 2-12 after ED arrival meets BOTH criteria:
•	 < 4,500 cells/L
•	a >50% decline from the lowest WBC during the 72-hr screening window"*/

/*get the lowest wbc value during days2-12 per hosp*/
DATA low_wbc_days2_12_hosp (compress=yes); 
SET AIM2_HAPPIcohort_v2b;
day2_date=edisarrivaldate+2;
day12_date=edisarrivaldate+12;
format day2_date mmddyy10. day12_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 lo_wbc_72hred  hospital_day hosp_los day12_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=low_wbc_days2_12_hosp  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE low_wbc_days2_12_hosp_v2  (compress=yes)  AS
	SELECT A.*, b.LabSpecimenDate, b.LabChemResultNumericValue as Wbc_value
	FROM  low_wbc_days2_12_hosp  A
	LEFT JOIN  wbc_20132017happi_v1 B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA= low_wbc_days2_12_hosp_v2;
BY  unique_hosp_count_id LabSpecimenDate;
RUN;

DATA low_wbc_days2_12_hosp_v3 (compress=yes);
SET low_wbc_days2_12_hosp_v2;
if  day2_date <= LabSpecimenDate <= day12_date then keep=1;
if keep=1;
RUN;

PROC SQL;
CREATE TABLE low_wbc_days2_12_hosp_v4 (compress=yes)  AS   
SELECT *, min(Wbc_value) as low_wbc_days2_12_hosp
FROM low_wbc_days2_12_hosp_v3
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=low_wbc_days2_12_hosp_v4  nodupkey; 
BY  unique_hosp_count_id low_wbc_days2_12_hosp;
RUN;

/*merge low_wbc_days2_12_hosp2 back to AIM2_HAPPIcohort_v2 */
PROC SQL;
	CREATE TABLE  AIM2_HAPPIcohort_v3wbc (compress=yes)  AS
	SELECT A.*, B.low_WBC_days2_12_hosp
	FROM  AIM2_HAPPIcohort_v2   A
	LEFT JOIN  low_wbc_days2_12_hosp_v4  B ON A.unique_hosp_count_id=B.unique_hosp_count_id;
QUIT;

DATA wbc (compress=yes);
SET AIM2_HAPPIcohort_v3wbc;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 lo_wbc_72hred lo_wbc_daily hospital_day hosp_los low_wbc_days2_12_hosp; 
RUN;

DATA wbc2 (compress=yes);
SET  wbc;
if (low_wbc_days2_12_hosp NE . and low_wbc_days2_12_hosp<4.5 )
 and (low_wbc_days2_12_hosp NE . and low_wbc_days2_12_hosp < (lo_wbc_72hred*0.5)) 
    then Leukopenia=1;
      else Leukopenia=0;
run;

data check_missingWBC;
set wbc2;
if lo_wbc_72hred =.;
run;

PROC FREQ DATA=check_missingWBC  order=freq;
TABLE  Leukopenia;
RUN;

PROC SORT DATA=wbc2;
BY unique_hosp_count_id hospital_day;
RUN;

PROC FREQ DATA=wbc2  order=freq;
TABLE Leukopenia;
RUN;

DATA Leukopenia_daily (compress=yes);
SET  wbc2;
if Leukopenia=1;
RUN;

PROC SORT DATA=Leukopenia_daily  nodupkey  OUT=Leukopenia_hosp (compress=yes);
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE  Leukopenia_hosp_v2 (compress=yes)  AS
	SELECT A.*, B.Leukopenia as Leukopenia_hosp
	FROM  wbc   A
	LEFT JOIN  Leukopenia_hosp B ON A.unique_hosp_count_id =B.unique_hosp_count_id;
QUIT;

DATA Leukopenia_hosp_v3 (compress=yes); 
SET  Leukopenia_hosp_v2;
if Leukopenia_hosp Ne 1 then Leukopenia_hosp =0;
admityear=year(new_admitdate3);
RUN;

PROC SORT DATA=Leukopenia_hosp_v3  nodupkey;
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=Leukopenia_hosp_v3  order=freq;
TABLE  admityear;
RUN;

PROC SORT DATA=Leukopenia_hosp_v3;
BY admityear;
RUN;

PROC FREQ DATA=Leukopenia_hosp_v3;
by admityear;
TABLE  Leukopenia_hosp;
RUN;

DATA happi.HAPPI_AIM2_Leukopenia_hosp (compress=yes); 
SET Leukopenia_hosp_v3;
if Leukopenia_hosp =1;
RUN;


/*Acute liver injury:
"Meets EITHER ALT criteria OR total bilirubin criteria

ALT Criteria:
The highest ALT* (alanine aminotransferase) measurement during days 2-90 after ED arrival meets BOTH criteria:
• > 80 IU/L
• a >50% increase from highest ALT during 72-hour screening window***

Total Bilirubin criteria
The highest total bilirubin measurement during days 2-90 after ED arrival meets  BOTH criteria:
• > 2.4 mg/dL
• a >50% increase from highest bilirubin during 72-hour screening window**"*/

/*ALT: get the highest ALT value during days 2-90 per hosp*/
DATA hi_alt_days2_90_hosp (compress=yes); 
SET AIM2_HAPPIcohort_v2b;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+90;
format day2_date mmddyy10. day90_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hi_alt_72hred hi_ALT_180day hi_ALT_hosp
hospital_day hosp_los day90_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=hi_alt_days2_90_hosp  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE hi_alt_days2_90_hosp_v2  (compress=yes)  AS
	SELECT A.*, b.LabSpecimenDate, b.LabChemResultNumericValue as ALT_value
	FROM  hi_alt_days2_90_hosp   A
	LEFT JOIN alt_20132017happi_v1  B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA=hi_alt_days2_90_hosp_v2;
BY  unique_hosp_count_id LabSpecimenDate;
RUN;

/* hi_alt_days2_90_hosp*/
DATA  hi_alt_days2_90_hosp_v3 (compress=yes);
SET  hi_alt_days2_90_hosp_v2;
if  day2_date <= LabSpecimenDate <= day90_date then keep=1;
if keep=1;
RUN;

PROC SQL;
CREATE TABLE  hi_alt_days2_90_hosp_v4 (compress=yes)  AS   
SELECT *, max(ALT_value) as hi_alt_days2_90_hosp
FROM  hi_alt_days2_90_hosp_v3
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA= hi_alt_days2_90_hosp_v4 nodupkey; 
BY  unique_hosp_count_id  hi_alt_days2_90_hosp;
RUN;

/*highest ALT value in the 180 days prior to ED arrival*/
data ALT_180day_ED (compress=yes); 
set hi_alt_days2_90_hosp_v2;
datediff_days=intck('day',LabSpecimenDate,edisarrivaldate); 
if  0<= datediff_days <=180 then lab_180dayED=1; 
if lab_180dayED=1; 
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hospital_day hosp_los ALT_value edisarrivaldate datediff_days lab_180dayED LabSpecimenDate;
run;

PROC SQL;
CREATE TABLE  ALT_180day_ED_v2 (compress=yes)  AS   
SELECT *, max(ALT_value) as hi_alt_180dayed_hosp
FROM  ALT_180day_ED
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=  ALT_180day_ED_v2 nodupkey; 
BY  unique_hosp_count_id  hi_alt_180dayed_hosp;
RUN;



/*Get highest total bilirubin measurement during days 2-90 after ED arrival*/
DATA hi_Bili_days2_90_hosp (compress=yes); 
SET AIM2_HAPPIcohort_v2b;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+90;
format day2_date mmddyy10. day90_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hi_Bili_72hred hi_BILI_180day hi_BILI_hosp
hospital_day hosp_los day90_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=hi_Bili_days2_90_hosp  nodupkey;
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE hi_Bili_days2_90_hosp_v2 (compress=yes)  AS
	SELECT A.*, b.LabSpecimenDate, b.LabChemResultNumericValue as BILI_value
	FROM  hi_Bili_days2_90_hosp   A
	LEFT JOIN Bili_20132017happi_v1  B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA= hi_Bili_days2_90_hosp_v2;
BY  unique_hosp_count_id LabSpecimenDate;
RUN;

DATA  hi_Bili_days2_90_hosp_v3 (compress=yes);
SET  hi_Bili_days2_90_hosp_v2;
if  day2_date <= LabSpecimenDate <= day90_date then keep=1;
if keep=1;
RUN;

PROC SQL;
CREATE TABLE  hi_Bili_days2_90_hosp_v4(compress=yes)  AS   
SELECT *, max(BILI_value) as hi_Bili_days2_90_hosp
FROM  hi_Bili_days2_90_hosp_v3
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA= hi_Bili_days2_90_hosp_v4  nodupkey; 
BY  unique_hosp_count_id  hi_Bili_days2_90_hosp;
RUN;


/*highest BILI value in the 180 days prior to ED arrival*/
data BILI_180day_ED (compress=yes); 
set hi_Bili_days2_90_hosp_v2;
datediff_days=intck('day',LabSpecimenDate,edisarrivaldate); 
if  0<= datediff_days <=180 then lab_180dayED=1; 
if lab_180dayED=1; 
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hospital_day hosp_los BILI_value edisarrivaldate datediff_days lab_180dayED LabSpecimenDate;
run;

PROC SQL;
CREATE TABLE  BILI_180day_ED_v2 (compress=yes)  AS   
SELECT *, max(BILI_value) as hi_Bili_180dayed_hosp
FROM  BILI_180day_ED
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=BILI_180day_ED_v2 nodupkey; 
BY  unique_hosp_count_id  hi_Bili_180dayed_hosp;
RUN;


/*merge ALT and Bili back to VAPD*/
PROC SQL;
	CREATE TABLE HAPPI_ALT_BILI  (compress=yes)  AS 
	SELECT A.*, B.hi_ALT_days2_90_hosp, c.hi_Bili_days2_90_hosp, d.hi_ALT_180dayed_hosp, e.hi_Bili_180dayed_hosp
	FROM AIM2_HAPPICOHORT_V2B    A
	LEFT JOIN hi_ALT_days2_90_hosp_v4   B ON A.unique_hosp_count_id =B.unique_hosp_count_id
    LEFT JOIN hi_Bili_days2_90_hosp_v4  C ON A.unique_hosp_count_id =C.unique_hosp_count_id
    LEFT JOIN ALT_180day_ED_v2 D ON A.unique_hosp_count_id =D.unique_hosp_count_id
     LEFT JOIN BILI_180day_ED_v2 E ON A.unique_hosp_count_id =E.unique_hosp_count_id;
QUIT;


/***If ALT was not checked during 72-hr screening window, then use highest value in the 180 days prior to ED arrival. 
If ALT was not checked in the prior 180 days, then use 40 IU/L.*/
data HAPPI_ALT_BILI2 (compress=yes);
set HAPPI_ALT_BILI;
if hi_ALT_72hrED NE . then ALT_value_failure =hi_ALT_72hrED;
 else if hi_ALT_72hrED = . and hi_ALT_180dayed_hosp NE . then ALT_value_failure=hi_ALT_180dayed_hosp; 
  else if hi_ALT_72hrED = . and hi_ALT_180dayed_hosp =. then  ALT_value_failure =40;
run;


/***If total bilirubin was not checked during the 72-hr screening window, 
then use highest value in the 180 days prior to ED arrival. If total bilirubin was not checked in the prior 180 days, then use 1.2 mg/dL*/
DATA HAPPI_ALT_BILI3 (compress=yes);
SET  HAPPI_ALT_BILI2;
if hi_Bili_72hrED NE . then Bili_value_failure =hi_Bili_72hrED;
 else if hi_Bili_72hrED = . and hi_Bili_180dayed_hosp NE . then Bili_value_failure=hi_Bili_180dayed_hosp; 
  else if hi_Bili_72hrED = . and hi_Bili_180dayed_hosp =. then  Bili_value_failure  =1.2;
run;


DATA HAPPI_ALT_BILI4 (compress=yes);
SET HAPPI_ALT_BILI3;
/*ALT*/
if (hi_ALT_days2_90_hosp NE . and hi_ALT_days2_90_hosp > 80)
 and (hi_ALT_days2_90_hosp NE . and hi_ALT_days2_90_hosp > (ALT_value_failure*1.5)) 
    then ALT_liver_injury =1;
      else ALT_liver_injury =0;
/*bili*/
if (hi_bili_days2_90_hosp NE . and hi_bili_days2_90_hosp > 2.4)
 and (hi_bili_days2_90_hosp NE . and hi_bili_days2_90_hosp > (bili_value_failure*1.5)) 
    then bili_liver_injury =1;
      else bili_liver_injury =0;

if ALT_liver_injury =1 or bili_liver_injury =1 then  Acute_liver_injury=1; else Acute_liver_injury =0;
keep  patienticn unique_hosp_count_id datevalue hi_bili_days2_90_hosp bili_value_failure hi_ALT_days2_90_hosp ALT_value_failure
Acute_liver_injury bili_liver_injury ALT_liver_injury new_admitdate3 new_dischargedate3;
RUN;

DATA Acute_liver_injury (compress=yes);
SET HAPPI_ALT_BILI4;
if Acute_liver_injury=1;
RUN;

PROC SORT DATA=Acute_liver_injury  nodupkey  OUT=happi.HAPPI_AIM2_acuteliverinjury_hosp (compress=yes); 
BY unique_hosp_count_id;
RUN;


DATA HAPPI_ALT_BILI5 (compress=yes); 
SET HAPPI_ALT_BILI4;
admityear=year(new_admitdate3);
RUN;

PROC SORT DATA=HAPPI_ALT_BILI5  nodupkey;
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=HAPPI_ALT_BILI5  order=freq;
TABLE  admityear;
RUN;

PROC SORT DATA=HAPPI_ALT_BILI5;
BY admityear;
RUN;

PROC FREQ DATA=HAPPI_ALT_BILI5;
by admityear;
TABLE  Acute_liver_injury;
RUN;


/**Acute renal injury:
New initiation of dialysis during days 2-90 after ED arrival
Exclude hospitalizations with end stage renal disease
OR
The highest 2 creatinine values during days 2-90 after ED arrival meets BOTH criteria:
•  0.5 mg/dL
• A >50% increase in creatinine from highest creatinine during 72-hr screening window  **/

/*get diagnosis codes back for aim2_happicohort_v2b*/
DATA  VAPD_diag_20142017  (compress=yes);  
retain patienticn patientsid sta3n sta6a  datevalue unit_dx1-unit_dx26;
SET final.SINGLESITE20142017_20200720;
keep  patienticn patientsid sta3n sta6a  datevalue unit_dx1-unit_dx26;
RUN;

DATA  VAPD_diag_2013  (compress=yes);  
retain patienticn patientsid sta3n sta6a   datevalue  unit_dx1-unit_dx25;
SET final.SINGLESITE2013_20200721;
keep  patienticn patientsid sta6a sta3n  datevalue unit_dx1-unit_dx25;
RUN;


/*2018*/
DATA VAPD_INPAT2018 (compress=yes); 
SET acute.VAPD_INPAT2018;
specialtytransferdate=datepart(specialtytransferdatetime);
format specialtytransferdate mmddyy10.;
keep patienticn patientsid sta3n sta6a icd10code1-icd10code25 specialtytransferdate;
rename icd10code1-icd10code25=unit_dx1-unit_dx25;      
RUN;

DATA VAPD_INPAT2018 (compress=yes rename=patienticn2=patienticn); 
SET VAPD_INPAT2018;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

PROC SORT DATA=VAPD_INPAT2018 ; 
BY   patienticn specialtytransferdate unit_dx1-unit_dx25;
RUN;

PROC SORT DATA=VAPD_INPAT2018  nodupkey;
BY   patienticn specialtytransferdate;
RUN;

DATA  VAPDsingle_2018  (compress=yes );  
retain patienticn patientsid sta3n sta6a  datevalue specialtytransferdate;
SET acute.VAPDSINGLESITE2018_20200508;  
keep  patienticn patientsid sta3n sta6a  datevalue specialtytransferdate;
RUN;

PROC SQL;
	CREATE TABLE VAPDsingle_2018_v2  (compress=yes)  AS
	SELECT A.*, B.unit_dx1,B.unit_dx2,B.unit_dx3,B.unit_dx4,B.unit_dx5,B.unit_dx6,B.unit_dx7,B.unit_dx8,B.unit_dx9,B.unit_dx10,
	            B.unit_dx11,B.unit_dx12,B.unit_dx13,B.unit_dx14,B.unit_dx15,B.unit_dx16,B.unit_dx17,B.unit_dx18,B.unit_dx19,B.unit_dx20,
				B.unit_dx21,B.unit_dx22,B.unit_dx23,B.unit_dx24,B.unit_dx25
	FROM  VAPDsingle_2018   A
	LEFT JOIN  VAPD_INPAT2018 B ON A.patienticn =B.patienticn and a.specialtytransferdate=b.specialtytransferdate ;
QUIT;

DATA  MISSING_DIAG2018 (compress=yes);
SET VAPDsingle_2018_v2;
IF unit_dx1 ='';
RUN;

DATA  MISSING_DIAG20142017 (compress=yes); 
SET VAPD_diag_20142017;
IF unit_dx1 ='';
RUN;

DATA  MISSING_DIAG2013 (compress=yes); 
SET VAPD_diag_2013;
IF unit_dx1 ='';
RUN;

DATA VAPDsingle_20132018 (compress=yes drop=specialtytransferdate); 
SET VAPD_diag_2013  VAPD_diag_20142017 VAPDsingle_2018_v2;
RUN;

PROC SORT DATA=VAPDsingle_20132018  nodupkey; 
BY patienticn datevalue ;
RUN;

/*MERGE TO HAPPI COHORT*/
PROC SQL;
	CREATE TABLE  AIM2_HAPPICOHORT_V2B_diag (compress=yes)  AS 
	SELECT A.*, B.unit_dx1,B.unit_dx2,B.unit_dx3,B.unit_dx4,B.unit_dx5,B.unit_dx6,B.unit_dx7,B.unit_dx8,B.unit_dx9,B.unit_dx10,
	            B.unit_dx11,B.unit_dx12,B.unit_dx13,B.unit_dx14,B.unit_dx15,B.unit_dx16,B.unit_dx17,B.unit_dx18,B.unit_dx19,B.unit_dx20,
				B.unit_dx21,B.unit_dx22,B.unit_dx23,B.unit_dx24,B.unit_dx25,B.unit_dx26
	FROM  AIM2_HAPPICOHORT_V2B   A
	LEFT JOIN VAPDsingle_20132018  B ON A.patienticn =B.patienticn and a.datevalue=b.datevalue;
QUIT;

/*find end renal disease hosp level */
DATA renal_daily (compress=yes) ;
SET  AIM2_HAPPICOHORT_V2B_diag;
if unit_dx1 in ('585.6','N18.6') or  unit_dx2 in ('585.6','N18.6') or unit_dx3 in ('585.6','N18.6') or unit_dx4 in ('585.6','N18.6') or 
unit_dx5 in ('585.6','N18.6') or unit_dx6 in ('585.6','N18.6') or unit_dx7 in ('585.6','N18.6') or unit_dx8 in ('585.6','N18.6') or unit_dx9 in ('585.6','N18.6') or 
unit_dx10 in ('585.6','N18.6') or unit_dx11 in ('585.6','N18.6') or unit_dx12 in ('585.6','N18.6') or unit_dx13 in ('585.6','N18.6') or unit_dx14 in ('585.6','N18.6') or 
unit_dx15 in ('585.6','N18.6') or unit_dx16 in ('585.6','N18.6') or unit_dx17 in ('585.6','N18.6') or unit_dx18 in ('585.6','N18.6') or unit_dx19 in ('585.6','N18.6') or 
unit_dx20 in ('585.6','N18.6') or unit_dx21 in ('585.6','N18.6') or unit_dx22 in ('585.6','N18.6') or unit_dx23 in ('585.6','N18.6') or unit_dx24 in ('585.6','N18.6') or 
unit_dx25 in ('585.6','N18.6') or unit_dx26 in ('585.6','N18.6') then renal_daily =1; else renal_daily=0;
if renal_daily =1; 
keep patienticn unique_hosp_count_id datevalue unit_dx1-unit_dx26 renal_daily;
RUN;

PROC SORT DATA=renal_daily  nodupkey;
BY patienticn unique_hosp_count_id ;
RUN;

PROC SQL;
	CREATE TABLE AIM2_HAPPICOHORT_V2B_renalhosp  (compress=yes)  AS
	SELECT A.*, B.renal_daily as end_renaldisease_hosp
	FROM   AIM2_HAPPICOHORT_V2B  A
	LEFT JOIN  renal_daily B ON A.unique_hosp_count_id =B.unique_hosp_count_id ;
QUIT;

PROC FREQ DATA=AIM2_HAPPICOHORT_V2B_renalhosp  order=freq;
TABLE  end_renaldisease_hosp;
RUN;

DATA AIM2_HAPPICOHORT_V2B_renalhosp (compress=yes);
SET  AIM2_HAPPICOHORT_V2B_renalhosp;
if end_renaldisease_hosp NE 1 then end_renaldisease_hosp =0;
RUN;


/*get Dialysis: repulled procedure codes for entire 2013-2019 April, cleaned in VINCI and saved as happi.happidialysis20132019_20200805*/
/*New initiation of dialysis during days 2-90 after ED arrival*/
/*get each hosp ED arrival, then merge in dialysis dataset and get day 2-90 indicator*/
DATA Dialysis_days2_90_hosp (compress=yes); 
SET AIM2_HAPPICOHORT_V2B_renalhosp;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+12;
format day2_date mmddyy10. day90_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hospital_day hosp_los day90_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=Dialysis_days2_90_hosp  nodupkey;
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE Dialysis_days2_90_hosp_v2  (compress=yes)  AS
	SELECT A.*, b.procdate, b.Dialysis_daily
	FROM  Dialysis_days2_90_hosp   A
	LEFT JOIN happi.happidialysis20132019_20200921  B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA=Dialysis_days2_90_hosp_v2;
BY  unique_hosp_count_id  procdate;
RUN;

DATA  Dialysis_days2_90_hosp_v3 (compress=yes);
SET  Dialysis_days2_90_hosp_v2;
if  day2_date <= procDate <= day90_date then keep=1;
if keep=1;
RUN;

PROC SORT DATA=Dialysis_days2_90_hosp_v3  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE HAPPICOHORT_V2B_renaldialysis  (compress=yes)  AS 
	SELECT A.*, B.Dialysis_daily as Dialysis_days2_90_hosp
	FROM AIM2_HAPPICOHORT_V2B_renalhosp  A
	LEFT JOIN  Dialysis_days2_90_hosp_v3 B ON A.unique_hosp_count_id =B.unique_hosp_count_id;
QUIT;

DATA HAPPICOHORT_V2B_renaldialysis (compress=yes) ;
SET  HAPPICOHORT_V2B_renaldialysis;
if Dialysis_days2_90_hosp NE 1 then Dialysis_days2_90_hosp =0;
RUN;


/*get creat labs, use second highest per hosp*/
DATA hi_creat_days2_90_hosp (compress=yes);
SET AIM2_HAPPIcohort_v2b;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+12;
format day2_date mmddyy10. day90_date mmddyy10.;
keep patienticn unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 hi_Creat_72hred hi_CREAT_180day hi_CREAT_hosp
hospital_day hosp_los day90_date day2_date edisarrivaldate; 
RUN;

PROC SORT DATA=hi_Creat_days2_90_hosp  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE hi_Creat_days2_90_hosp_v2  (compress=yes)  AS
	SELECT A.*, b.LabSpecimenDate, b.LabChemResultNumericValue as CREAT_value
	FROM  hi_Creat_days2_90_hosp  A
	LEFT JOIN Creat_20132017happi_v1  B ON A.patienticn =B.patienticn;
QUIT;

PROC SORT DATA= hi_Creat_days2_90_hosp_v2;
BY  unique_hosp_count_id LabSpecimenDate;
RUN;

DATA  hi_Creat_days2_90_hosp_v3 (compress=yes);
SET  hi_Creat_days2_90_hosp_v2;
if  day2_date <= LabSpecimenDate <= day90_date then keep=1;
if keep=1;
RUN;

/*GET SECOND HIGHEST CREAT LAB VALUE PER HOSP. But highest and second highest can't be the same value, so remove dup creat lab values by hosp*/
PROC SORT DATA=hi_Creat_days2_90_hosp_v3 nodupkey  OUT= hi_Creat_days2_90_hosp_v3b (compress=yes);
BY unique_hosp_count_id creat_value;
RUN;

PROC SORT DATA=hi_Creat_days2_90_hosp_v3b; 
BY unique_hosp_count_id descending CREAT_value;
DATA hi_Creat_days2_90_hosp_v4;
SET hi_Creat_days2_90_hosp_v3b;
BY  unique_hosp_count_id;
IF FIRST.unique_hosp_count_id  THEN rank = 0; 
rank + 1;
RUN;

/*those with only 1 value per hosp? yes there are those with only 1 unique create value per hosp */
PROC FREQ DATA=hi_Creat_days2_90_hosp_v4  order=freq; 
TABLE  rank;
RUN;

DATA hi_Creat_days2_90_hosp_v4b (compress=yes);
SET  hi_Creat_days2_90_hosp_v4;
if rank =1 then flag_1=1; else flag_1=0;
if rank=2 then flag_2=1; else flag_2=0;
RUN;

DATA flag_1 (compress=yes) flag_2 (compress=yes);
SET hi_Creat_days2_90_hosp_v4b ;
if flag_1=1 then output flag_1;
if flag_2=1 then output flag_2;
RUN;

PROC SORT DATA=flag_1  nodupkey;
BY unique_hosp_count_id;
RUN;

PROC SORT DATA=flag_2  nodupkey;
BY unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE  hi_Creat_days2_90_hosp_v4c (compress=yes)  AS 
	SELECT A.*, B.flag_1, c.flag_2
	FROM hi_Creat_days2_90_hosp_v4    A
	LEFT JOIN flag_1  b ON A.unique_hosp_count_id =B.unique_hosp_count_id 
    LEFT JOIN flag_2  c ON A.unique_hosp_count_id =c.unique_hosp_count_id;
QUIT;

/*separate out flag_1 and flag_2, then combine together*/
DATA only_1lab (compress=yes); 
SET hi_Creat_days2_90_hosp_v4c;
if flag_2 =.;
hi2_creat_value= . ; /*On 8/10/20, Hallie said if there’s only 1 creat lab value within days 2-90 after ED arrival, then drop, don’t meet outcome. So replace those with
only 1 lab as missing.*/
RUN;

DATA gt_1lab (compress=yes); 
SET hi_Creat_days2_90_hosp_v4c;
if flag_2 ne .;
hi2_creat_value=CREAT_value;
RUN;

DATA gt_1lab (compress=yes);
SET gt_1lab;
if rank=2;
RUN;

/*combine then undup*/
DATA hi_Creat_days2_90_hosp_v5 (compress=yes);
SET only_1lab gt_1lab;
RUN;

PROC SORT DATA=hi_Creat_days2_90_hosp_v5  nodupkey; 
BY   unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE  happicohort_creatrenaldialysis (compress=yes)  AS 
	SELECT A.*, B.hi2_creat_value as hi2_creat_days2_90_hosp
	FROM   HAPPICOHORT_V2B_renaldialysis  A
	LEFT JOIN hi_Creat_days2_90_hosp_v5  B ON A.unique_hosp_count_id =B.unique_hosp_count_id;
QUIT;


DATA happicohort_creatrenaldialysis2 (compress=yes); 
SET happicohort_creatrenaldialysis;
if (end_renaldisease_hosp =0) and  /*Exclude hospitalizations with end stage renal disease*/
( (Dialysis_days2_90_hosp=1) /*New initiation of dialysis during days 2-90 after ED arrival*/
OR
/*creat*/
 ((hi2_creat_days2_90_hosp NE . and hi2_creat_days2_90_hosp >=0.5 )
 and (hi2_creat_days2_90_hosp NE . and hi2_creat_days2_90_hosp > (hi_creat_72hred*1.5)) ))
    then acute_renal_injury =1;
      else acute_renal_injury =0;
keep patienticn unique_hosp_count_id hi2_creat_days2_90_hosp hi_creat_72hred Dialysis_days2_90_hosp end_renaldisease_hosp acute_renal_injury admityear;
RUN;

PROC SORT DATA=happicohort_creatrenaldialysis2  nodupkey; 
BY unique_hosp_count_id;
RUN;

PROC SORT DATA=happicohort_creatrenaldialysis2;
BY admityear;
RUN;

PROC FREQ DATA=happicohort_creatrenaldialysis2;
by admityear;
TABLE  Acute_renal_injury;
RUN;

DATA happi.HAPPI_AIM2_acuterenalinjury_hosp (compress=yes); 
SET happicohort_creatrenaldialysis2 ;
if acute_renal_injury =1;
RUN;



/*C.Diff outcome*/
/*datasets: happi.UNIQHAPPICRT_20132018_SW210105, happi.CDIFFALLTESTS_TAO_SW20210105*/
/*from HAPPI cohrot, flag those hospitalizations with positive C.Diff tests during days 2-90 after ED arrival*/
PROC SQL;
CREATE TABLE   aim2cdiff_happicohort  (COMPRESS=YES) AS 
SELECT A.* FROM happi.HAPPIVAPD20132018_20200515 AS A
WHERE A.unique_hosp_count_id IN (SELECT unique_hosp_count_id  FROM happi.UNIQHAPPICRT_20132018_SW210105);
QUIT;

/*get EDIS arrival date*/
DATA aim2cdiff_happicohort (compress=yes); 
SET aim2cdiff_happicohort;
edisarrivaldate= datepart(earliest_edisarrivaltime_hosp);
format edisarrivaldate mmddyy10.;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+90;
format day2_date mmddyy10. day90_date mmddyy10.;
RUN;

DATA aim2cdiff_happicohortV2 (compress=yes);
SET aim2cdiff_happicohort ;
keep patienticn sta6a new_admitdate3 new_admitdate3 earliest_edisarrivaltime_hosp edisarrivaldate day2_date day90_date unique_hosp_count_id;
RUN;

PROC SORT DATA=aim2cdiff_happicohortV2  nodupkey; 
BY  unique_hosp_count_id;
RUN;

/*merge in Tao's C.Diff dataset on patienticn*/
DATA org_cdiffalltestssw20200826 (compress=yes  rename=patienticn2=patienticn); 
SET  happi.CDIFFALLTESTS_TAO_SW20210105;
if PositiveResult=1;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

PROC SORT DATA=org_cdiffalltestssw20200826 nodupkey; 
BY patienticn TestDateTime;
RUN;

PROC SORT DATA=org_cdiffalltestssw20200826; 
BY  TestDateTime;
RUN;


PROC SQL;
	CREATE TABLE  aim2cdiff_happicohortV3 (compress=yes)  AS 
	SELECT A.*, b.TestDateTime, B.PositiveResult
	FROM   aim2cdiff_happicohortV2  A
	LEFT JOIN org_cdiffalltestssw20200826  B ON A.patienticn =B.patienticn;
QUIT;

DATA aim2cdiff_happicohortV3 (compress=yes); 
SET  aim2cdiff_happicohortV3;
TestDate=datepart(TestDateTime);
format TestDate mmddyy10.;
RUN;

/*get indicator on positive c.diff during days 2-90 after ED arrival.
Each hospitalization can have more than 1 positive c.diff test*/
DATA aim2cdiff_happicohortV3b (compress=yes); 
SET aim2cdiff_happicohortV3;
if  day2_date <= TestDate <= day90_date then keep=1;
if keep=1;
RUN;

/*how many unique HAPPI hosps have positive c.diff test?*/
PROC SORT DATA=aim2cdiff_happicohortV3b  nodupkey  OUT=pos_test_hosps (compress=yes); 
BY  unique_hosp_count_id; RUN;

DATA  aim2cdiff_happicohortV3b (compress=yes); 
SET  aim2cdiff_happicohortV3b;
Testday2_date=TestDate+2;
Testday14_date=TestDate+14;
format Testday2_date mmddyy10. Testday14_date mmddyy10.;
RUN;


/*clean abx for c.diff meds. only keep oral/enteral vancomycin OR oral/enteral/intravenous metronidazole */
/*combine all dispensed, solution and additive*/
DATA addcdiffabx1319_sw20200828 (compress=yes rename=patienticn2=patienticn);
SET  meds.addcdiffabx1319_sw20200828;
patienticn2 = input(patienticn, 10.);
keep patienticn2 PatientSID sta3n LocalDrugNameWithDose ActionDateTime;
RUN;

DATA solcdiffabx1319_sw20200828 (compress=yes rename=patienticn2=patienticn);
SET  meds.solcdiffabx1319_sw20200828;
patienticn2 = input(patienticn, 10.);
keep patienticn2 PatientSID sta3n LocalDrugNameWithDose ActionDateTime;
RUN;

DATA dispcdiffabx1319_sw20200828 (compress=yes rename=patienticn2=patienticn);
SET  meds.dispcdiffabx1319_sw20200828;
patienticn2 = input(patienticn, 10.);
keep patienticn2 PatientSID sta3n LocalDrugNameWithDose ActionDateTime;
RUN;

DATA all_drugs (compress=yes); 
SET addcdiffabx1319_sw20200828  solcdiffabx1319_sw20200828  dispcdiffabx1319_sw20200828;
RUN;

PROC FREQ DATA=all_drugs  order=freq;
TABLE LocalDrugNameWithDose;
RUN;

/*change to all caps for LocalDrugNameWithDose*/
DATA  all_drugs_v2(compress=yes);
SET  all_drugs;
LocalDrugNameWithDose_v2=upcase(LocalDrugNameWithDose);
RUN;

PROC SQL;
CREATE TABLE  all_drugs_v3  AS  
SELECT *,
       case  when LocalDrugNameWithDose_v2  like '%VANCOMYC%' then 'VANCOMYCIN'
	         when  LocalDrugNameWithDose_v2  like '%METRONIDAZ%' then 'METRONIDAZOLE'
			 ELSE 'OTHER'
			   END as drug_name
FROM all_drugs_v2;
QUIT;

PROC FREQ DATA= all_drugs_v3   order=freq;
TABLE  drug_name;
RUN;

DATA CHECK_OTHERS (compress=yes);
SET all_drugs_v3;
IF drug_name='OTHER';
RUN;

PROC FREQ DATA=CHECK_OTHERS  order=freq; /*DELETE AFTER REVIEW*/
TABLE LocalDrugNameWithDose_v2;
RUN;

DATA all_drugs_v4 (compress=yes); 
SET  all_drugs_v3;
IF drug_name='OTHER' then delete;
RUN;

DATA vanco (compress=yes)  metro (compress=yes);
SET  all_drugs_v4;
if  drug_name='VANCOMYCIN' then output vanco;
else output metro; 
RUN;

PROC FREQ DATA=vanco  order=freq;
TABLE LocalDrugNameWithDose_v2;
RUN;

PROC FREQ DATA=metro  order=freq;
TABLE LocalDrugNameWithDose_v2;
RUN;

/*only keep oral for vancomycin*/
PROC SQL;
CREATE TABLE  vanco_v2  AS  
SELECT *,
       case  when LocalDrugNameWithDose_v2  like '%ORAL%' or LocalDrugNameWithDose_v2  like '%CAP%' then 1
			 ELSE 0
			   END as keep
FROM vanco;
QUIT;

DATA vanco_keep (compress=yes) vanco_drop (compress=yes);
SET  vanco_v2;
if keep=1 then output vanco_keep; 
else output vanco_drop; 
RUN;

PROC FREQ DATA=vanco_keep  order=freq;
TABLE  LocalDrugNameWithDose_v2;
RUN;

PROC FREQ DATA=vanco_drop  order=freq;
TABLE  LocalDrugNameWithDose_v2;
RUN;


/*only drop cream/gel for metronidazole*/
PROC SQL;
CREATE TABLE  metro_v2  AS  
SELECT *,
       case  when LocalDrugNameWithDose_v2  like '%CREA%' or LocalDrugNameWithDose_v2  like '%GEL%' or LocalDrugNameWithDose_v2  like '%TOP%'
	   or LocalDrugNameWithDose_v2  like '%RTL%' or LocalDrugNameWithDose_v2  like '%OINT%' or LocalDrugNameWithDose_v2  like '%LOT%'
   then 0
			 ELSE 1
			   END as keep
FROM metro;
QUIT;

DATA metro_keep (compress=yes) metro_drop (compress=yes);
SET  metro_v2;
if keep=1 then output metro_keep; 
else output metro_drop; 
RUN;

PROC FREQ DATA=metro_keep  order=freq;
TABLE  LocalDrugNameWithDose_v2;
RUN;

PROC FREQ DATA=metro_drop  order=freq;
TABLE  LocalDrugNameWithDose_v2;
RUN;

/*Hallie reviewed both metro_keep, metro_drop, vanco_drop & vanco_keep lists and said they are right. 8/30/2020*/
/*combine the keep lists*/
DATA all_keep (compress=yes);
SET metro_keep vanco_keep;
RUN;

DATA all_keep2 (compress=yes);
SET all_keep;
ActionDate=datepart(actiondatetime);
format ActionDate mmddyy10.;
drop LocalDrugNameWithDose_v2 drug_name keep;
RUN;

PROC SQL;
	CREATE TABLE aim2cdiff_happicohortV4  (compress=yes)  AS 
	SELECT A.*, B.ActionDate, b.LocalDrugNameWithDose
	FROM  aim2cdiff_happicohortV3b A LEFT JOIN  all_keep2  B ON A.patienticn=B.patienticn;
QUIT;

/*The antibiotic treatment occurred following the positive C.difficile test result—specifically, the patient received at least 1 dose of antibiotic targeting C.Difficile during the 2-14 days after the C.difficile test result returned positive  */
DATA aim2cdiff_happicohortV4b (compress=yes);
SET aim2cdiff_happicohortV4;
if  testday2_date <= ActionDate <= testday14_date then finalkeep=1;
RUN;

PROC SORT DATA=aim2cdiff_happicohortV4b;
BY unique_hosp_count_id TestDate ActionDate;
RUN;

DATA happi_CDiff_cohort (compress=yes); 
SET  aim2cdiff_happicohortV4b;
if finalkeep=1;
RUN;

PROC SORT DATA=happi_CDiff_cohort  nodupkey  out=happi.HAPPI_AIM2_CDiff_HOSP (compress=yes rename=finalkeep=cdiff_infection); 
BY unique_hosp_count_id;
RUN;

/*look into outpatient meds and CPRS orders for C.Diff ABX for those 3,420 hosps that don't have BCMA ABX to treat C.Diff*/
PROC SQL;
CREATE TABLE  happi.negabx_cdiffcohort (COMPRESS=YES) AS 
SELECT A.* FROM pos_test_hosps AS A
WHERE A.unique_hosp_count_id Not IN (SELECT  unique_hosp_count_id  FROM happi.HAPPI_AIM2_CDiff_HOSP);
QUIT;

/*clean CPRS ABX: oral/enteral vancomycin OR oral/enteral/intravenous metronidazole */
DATA CPRS_abx (compress=yes rename=OrderableItemname_v2=OrderableItemname);
SET meds.CPRS_CDIFFABX20132019_SW20200916;
OrderableItemname_v2=upcase(OrderableItemname);
drop OrderableItemname;
RUN;

PROC FREQ DATA= CPRS_abx order=freq;
TABLE OrderableItemName;
RUN;

/*further drop those creams, eye, etc.*/
proc sql;
create table all_cprsabx (compress=yes) as 
select *, case
when OrderableItemName like '%GEL%' or OrderableItemname like '%CREAM%' or OrderableItemname like '%OINT%'
or OrderableItemName like '%RECTAL%' or OrderableItemname like '%VAG%' or OrderableItemname like '%IRRG%'
or OrderableItemname like '%OTIC%' or OrderableItemname like '%OPH%' or OrderableItemname like '%OPTH%'
or OrderableItemname like '%OPHTH%' or OrderableItemname like '%TOPICAL%' or OrderableItemname like 'TOP'
or OrderableItemname like '%NASAl%' or OrderableItemname like '%LOTION%' or OrderableItemname like '%INHL%'
or OrderableItemname like '%EYE%' or OrderableItemname like '%TOP SOL%' or OrderableItemname like '%TOP SOLN%'
/*or OrderableItemname like '%PWD%'*/ or OrderableItemname like '%TUBE%' or OrderableItemname like '%IRRIG%'
then 1 else 0
end as drop
from CPRS_abx;
quit;

PROC FREQ DATA=all_cprsabx order=freq;
where drop=1;
TABLE  OrderableItemname;
RUN;

DATA all_cprsabx (compress=yes);
SET all_cprsabx;
if drop ne 1;
RUN;

/*label vanco and metro separately*/
proc sql;
create table all_cprsabx_v2 (compress=yes) as 
select *, case
when OrderableItemName like '%VANCOMY%' then 1 else 0
end as VANCOMYCIN
from all_cprsabx;
quit;

DATA vanco_abx (compress=yes)  metro_abx (compress=yes);
SET  all_cprsabx_v2;
if VANCOMYCIN=1 then output vanco_abx; 
else output metro_abx; 
RUN;

PROC FREQ DATA=vanco_abx  order=freq;
TABLE  OrderableItemName;
RUN;

PROC FREQ DATA=metro_abx  order=freq;
TABLE  OrderableItemName;
RUN;


/*only keep oral for vancomycin*/
PROC SQL;
CREATE TABLE  vanco_abx_v2  AS  
SELECT *,
       case  when OrderableItemName  like '%ORAL%' or OrderableItemName like '%CAP%' then 1
			 ELSE 0
			   END as keep
FROM vanco_abx;
QUIT;

DATA vanco_keep (compress=yes) vanco_drop (compress=yes);
SET vanco_abx_v2;
if keep=1 then output vanco_keep; 
else output vanco_drop; 
RUN;

PROC FREQ DATA=vanco_keep  order=freq;
TABLE  OrderableItemName;
RUN;

PROC FREQ DATA=vanco_drop  order=freq;
TABLE  OrderableItemName;
RUN;

DATA cprs_all_keep (compress=yes drop=drop keep VANCOMYCIN); 
SET metro_abx vanco_keep;
CPRS_OrderStartDate=datepart(CPRS_OrderStartDateTime);
format CPRS_OrderStartDate mmddyy10.;
cprs_abx_ind=1;
RUN;

PROC SORT DATA=cprs_all_keep  nodupkey  OUT=cprs_all_keep2 (compress=yes); 
BY  patienticn CPRS_OrderStartDate;
RUN;

/*clean outpat ABX: oral/enteral vancomycin OR oral/enteral/intravenous metronidazole */
DATA OUTPATCDIFFABX201319SW20200917 (compress=yes rename=localDrugNameWithDose_v2=localDrugNameWithDose);
SET meds.OUTPATCDIFFABX201319SW20200917;
localDrugNameWithDose_v2=upcase(localDrugNameWithDose);
drop localDrugNameWithDose;
RUN;

PROC FREQ DATA= OUTPATCDIFFABX201319SW20200917 order=freq;
TABLE localDrugNameWithDose;
RUN;

/*further drop those creams, eye, etc.*/
proc sql;
create table all_outptsabx (compress=yes) as
select *, case
when localDrugNameWithDose like '%GEL%' or localDrugNameWithDose like '%CREAM%' or localDrugNameWithDose like '%OINT%'
or localDrugNameWithDose like '%RECTAL%' or localDrugNameWithDose like '%VAG%' or localDrugNameWithDose like '%IRRG%'
or localDrugNameWithDose like '%OTIC%' or localDrugNameWithDose like '%OPH%' or localDrugNameWithDose like '%OPTH%'
or localDrugNameWithDose like '%OPHTH%' or localDrugNameWithDose like '%TOPICAL%' or localDrugNameWithDose like 'TOP'
or localDrugNameWithDose like '%NASAl%' or localDrugNameWithDose like '%LOTION%' or localDrugNameWithDose like '%INHL%'
or localDrugNameWithDose like '%EYE%' or localDrugNameWithDose like '%TOP SOL%' or localDrugNameWithDose like '%TOP SOLN%'
/*or localDrugNameWithDose like '%PWD%'*/ or localDrugNameWithDose like '%TUBE%' or localDrugNameWithDose like '%IRRIG%'
then 1 else 0
end as drop
from OUTPATCDIFFABX201319SW20200917;
quit;

PROC FREQ DATA=all_outptsabx order=freq;
where drop=1;
TABLE  localDrugNameWithDose;
RUN;

DATA all_outptsabx (compress=yes); 
SET all_outptsabx;
if drop ne 1;
RUN;

/*label vanco and metro separately*/
proc sql;
create table all_outptsabx_v2 (compress=yes) as 
select *, case
when localDrugNameWithDose like '%VANCOMY%' then 1 else 0
end as VANCOMYCIN
from all_outptsabx;
quit;

DATA vanco_outabx (compress=yes)  metro_outabx (compress=yes);
SET  all_outptsabx_v2;
if VANCOMYCIN=1 then output vanco_outabx; 
else output metro_outabx; 
RUN;

PROC FREQ DATA=vanco_outabx  order=freq;
TABLE localDrugNameWithDose;
RUN;

PROC FREQ DATA=metro_outabx  order=freq;
TABLE  localDrugNameWithDose;
RUN;

/*only keep oral for vancomycin*/
PROC SQL;
CREATE TABLE  vanco_outabx_v2  AS  
SELECT *,
       case  when localDrugNameWithDose  like '%ORAL%' or localDrugNameWithDose like '%CAP%' then 1
			 ELSE 0
			   END as keep
FROM vanco_outabx;
QUIT;

DATA vanco_outabxkeep (compress=yes) vanco_outabxdrop (compress=yes);
SET vanco_outabx_v2;
if keep=1 then output vanco_outabxkeep; 
else output vanco_outabxdrop; 
RUN;

PROC FREQ DATA=vanco_outabxkeep  order=freq;
TABLE  localDrugNameWithDose;
RUN;

PROC FREQ DATA=vanco_outabxdrop  order=freq;
TABLE localDrugNameWithDose;
RUN;

DATA outabx_all_keep (compress=yes drop=drop keep VANCOMYCIN); 
SET metro_outabx  vanco_outabxkeep;
ReleaseDate=datepart(ReleaseDateTime);
format ReleaseDate mmddyy10.;
out_abx_ind=1;
RUN;

PROC SORT DATA=outabx_all_keep  nodupkey  OUT=outabx_all_keep2 (compress=yes);
BY  patienticn ReleaseDate;
RUN;

/*merge cprs and outpat meds to happi.negabx_cdiffcohort*/
DATA negabx_cdiffcohort (compress=yes);
SET happi.negabx_cdiffcohort;
Testday2_date=TestDate+2;
Testday14_date=TestDate+14;
format Testday2_date mmddyy10. Testday14_date mmddyy10.;
RUN;

PROC SQL;
	CREATE TABLE  all_cprs_outmed_cohort (compress=yes)  AS 
	SELECT A.*, B.ReleaseDate, b.out_abx_ind, c.CPRS_OrderStartDate, c.cprs_abx_ind
	FROM  negabx_cdiffcohort   A
	LEFT JOIN outabx_all_keep2  B ON A.patienticn =B.patienticn 
    LEFT JOIN cprs_all_keep2  C ON A.patienticn =C.patienticn;
QUIT;

DATA all_cprs_outmed_cohort_v2 (compress=yes); 
SET all_cprs_outmed_cohort;
if (Testday2_date<= ReleaseDate <=Testday14_date) then outpat_keep=1; else outpat_keep=0; 
if (Testday2_date<= CPRS_OrderStartDate <=Testday14_date) then cprs_keep=1; else cprs_keep=0;
if outpat_keep=1 or cprs_keep=1 then final_keep=1; else final_keep=0;
if final_keep=1;
RUN;

PROC FREQ DATA=all_cprs_outmed_cohort_v2  order=freq;
TABLE  outpat_keep cprs_keep;
RUN;

PROC SORT DATA=all_cprs_outmed_cohort_v2 nodupkey  OUT= all_cprs_outmed_cohort_v3; 
BY unique_hosp_count_id;
RUN;

DATA all_cprs_outmed_cohort_v4 (compress=yes);
SET all_cprs_outmed_cohort_v3;
cdiff_infection=1;
keep patienticn sta6a new_admitdate3 unique_hosp_count_id earliest_edisarrivaltime_hosp edisarrivaldate day2_date
day90_date TestDateTimePositiveResult TestDate keep Testday2_date Testday14_date ActionDate LocalDrugNameWithDose cdiff_infection;
RUN;

/*add up the 1096 and 17069 hosps, total shoudl be 18574 hosps*/
DATA happi.HAPPI_AIM2_CDiff_HOSP (compress=yes); 
SET happi.HAPPI_AIM2_CDiff_HOSP  all_cprs_outmed_cohort_v4;
RUN;

PROC SORT DATA=happi.HAPPI_AIM2_CDiff_HOSP nodupkey; 
BY  unique_hosp_count_id;
RUN;

DATA happi.HAPPI_AIM2_CDiff_HOSP (compress=yes);
SET  happi.HAPPI_AIM2_CDiff_HOSP;
admityear=year(new_admitdate3);
RUN;

PROC FREQ DATA=happi.HAPPI_AIM2_CDiff_HOSP  order=freq;
TABLE  admityear;
RUN;





/*********************************************************************************************************************/
/*Isolation of new resistant bacteria*/
/*Tao's Table*/
DATA MDRO_TAO_SW20200922 (compress=yes rename=patienticn2=patienticn); 
SET  happi.MDRO_TAO_SW20210105;
patienticn2 = input(patienticn, 10.);
drop patienticn;
SpecimenDate=datepart(SpecimenTakenDateTime);
format SpecimenDate mmddyy10.;
RUN;

PROC SORT DATA=MDRO_TAO_SW20200922;
BY  patienticn SpecimenTakenDateTime;
RUN;

PROC FREQ DATA=MDRO_TAO_SW20200922;
TABLE Case_Definition AntibioticSensitivityIEN;
RUN;

/*test how many duplicate patienticn, SpecimenTakenDateTime, Case_Definition and AntibioticSensitivityIEN*/
PROC SORT DATA=MDRO_TAO_SW20200922  nodupkey  OUT=test; 
BY  patienticn SpecimenTakenDateTime Case_Definition AntibioticSensitivityIEN;
RUN;

PROC SORT DATA=MDRO_TAO_SW20200922  nodupkey  OUT=test2; 
BY  patienticn SpecimenTakenDateTime Case_Definition;
RUN;

PROC SORT DATA=MDRO_TAO_SW20200922  nodupkey  OUT=test3; 
BY  patienticn SpecimenTakenDateTime;
RUN;

/*was collected during calendar days +2-90 after calendar day of ED arrival AND no positive 
culture/swab for that organism in the 180 calendar days prior to calendar day of ED arrival.*/
/*9/29/20: Hallie said to drop MSSA and CPE*/
DATA MDRO_TAO_SW20200922_v2 (compress=yes); 
SET MDRO_TAO_SW20200922;
if Case_Definition in ('MSSA','CPE','CRK_cdc2015','CRAB','MDRE') then delete;
RUN;

PROC FREQ DATA=MDRO_TAO_SW20200922_v2  order=freq;
TABLE Case_Definition ;
RUN;

PROC SORT DATA=MDRO_TAO_SW20200922_v2 ;
BY  SpecimenTakenDateTime;
RUN;



/*make indicators for after (2-90) and prior (180) ED arrival for each case_definition (type)*/
DATA AIM2_HAPPIcohort_hosp (compress=yes); 
SET  aim2_happicohrot;
edisarrivaldate= datepart(earliest_edisarrivaltime_hosp);
format edisarrivaldate mmddyy10.;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+90;
EDprior180_date=edisarrivaldate-180;
format day2_date mmddyy10. day90_date mmddyy10. EDprior180_date mmddyy10. ;
keep patienticn sta6a unique_hosp_count_id new_dischargedate3 new_admitdate3 edisarrivaldate day2_date day90_date EDprior180_date admityear;
RUN;

PROC SORT DATA=AIM2_HAPPIcohort_hosp  nodupkey; 
BY unique_hosp_count_id;
RUN;

/*one to many merge*/
PROC SQL;
	CREATE TABLE  MDR_data (compress=yes)  AS 
	SELECT A.*, B.SpecimenDate, b.Case_Definition, b.AntibioticSensitivityIEN
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN MDRO_TAO_SW20200922_v2  B ON A.patienticn=B.patienticn;
QUIT;

PROC SORT DATA=MDR_data;
BY unique_hosp_count_id  SpecimenDate;
RUN;

DATA MDR_data_v2 (compress=yes); 
SET  MDR_data;
/*MDRPA*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='MDRPA' then MDRPA_2_90dayED=1; else MDRPA_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='MDRPA' then MDRPA_180priorED=1; else MDRPA_180priorED=0;
/*MRSA*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='MRSA' then MRSA_2_90dayED=1; else MRSA_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='MRSA' then MRSA_180priorED=1; else MRSA_180priorED=0;
/*VRE*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='VRE' then VRE_2_90dayED=1; else VRE_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='VRE' then VRE_180priorED=1; else VRE_180priorED=0;
/*ESBL*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='ESBL' then ESBL_2_90dayED=1; else ESBL_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='ESBL' then ESBL_180priorED=1; else ESBL_180priorED=0;
/*CRE_CDC2015*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='CRE_CDC2015' then CRE_CDC2015_2_90dayED=1; else CRE_CDC2015_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='CRE_CDC2015' then CRE_CDC2015_180priorED=1; else CRE_CDC2015_180priorED=0;
/*Acinetobacter*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='Acinetobacter' then Acinetobacter_2_90dayED=1; else Acinetobacter_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='Acinetobacter' then Acinetobacter_180priorED=1; else Acinetobacter_180priorED=0;
RUN;


/*creat each dataset for types*/
DATA Acinetobacter (compress=yes); 
SET  MDR_data_v2;
if Acinetobacter_180priorED=0 and Acinetobacter_2_90dayED=1;
MDRO_Acinetobacter=1;
RUN;

PROC SORT DATA=Acinetobacter nodupkey  OUT=Acinetobacter_hosp; 
BY unique_hosp_count_id;
RUN;
PROC FREQ DATA=Acinetobacter_hosp;
TABLE  admityear;
RUN;

DATA MDRPA (compress=yes); 
SET  MDR_data_v2;
if MDRPA_180priorED=0 and MDRPA_2_90dayED=1;
MDRO_MDRPA=1;
RUN;

PROC SORT DATA=MDRPA  nodupkey  OUT=MDRPA_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=MDRPA_hosp;
TABLE  admityear;
RUN;

DATA MRSA (compress=yes); 
SET  MDR_data_v2;
if MRSA_180priorED=0 and MRSA_2_90dayED=1;
MDRO_MRSA=1;
RUN;

PROC SORT DATA=MRSA  nodupkey  OUT=MRSA_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=MRSA_hosp;
TABLE  admityear;
RUN;


DATA VRE (compress=yes); 
SET  MDR_data_v2;
if VRE_180priorED=0 and VRE_2_90dayED=1;
MDRO_VRE=1;
RUN;

PROC SORT DATA=VRE  nodupkey  OUT=VRE_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=VRE_hosp;
TABLE  admityear;
RUN;


DATA ESBL (compress=yes); 
SET  MDR_data_v2;
if ESBL_180priorED=0 and ESBL_2_90dayED=1;
MDRO_ESBL=1;
RUN;

PROC SORT DATA=ESBL  nodupkey  OUT=ESBL_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=ESBL_hosp;
TABLE  admityear;
RUN;

DATA CRE_CDC2015 (compress=yes); 
SET  MDR_data_v2;
if CRE_CDC2015_180priorED=0 and CRE_CDC2015_2_90dayED=1;
MDRO_CRE_CDC2015=1;
RUN;

PROC SORT DATA=CRE_CDC2015  nodupkey  OUT=CRE_CDC2015_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=CRE_CDC2015_hosp;
TABLE  admityear;
RUN;

PROC SQL;
	CREATE TABLE  HAPPI_MDRO (compress=yes)  AS 
	SELECT A.*, B.MDRO_Acinetobacter, c.MDRO_ESBL, d.MDRO_MDRPA, e.MDRO_MRSA,f.MDRO_VRE
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN Acinetobacter_hosp  B ON A.unique_hosp_count_id =B.unique_hosp_count_id 
	LEFT JOIN ESBL_hosp  C ON A.unique_hosp_count_id =C.unique_hosp_count_id
	LEFT JOIN MDRPA_hosp  d ON A.unique_hosp_count_id =d.unique_hosp_count_id
	LEFT JOIN MRSA_hosp  e ON A.unique_hosp_count_id =e.unique_hosp_count_id
    LEFT JOIN VRE_hosp  f ON A.unique_hosp_count_id =f.unique_hosp_count_id;
QUIT;

DATA happi.HAPPI_AIM2_MDRO_HOSP (compress=yes); 
SET  HAPPI_MDRO;
MDRO_CRE_CDC2015=0;
if MDRO_Acinetobacter NE 1 then MDRO_Acinetobacter=0;
if MDRO_ESBL NE 1 then MDRO_ESBL=0;
if MDRO_MDRPA NE 1 then MDRO_MDRPA=0;
if MDRO_MRSA NE 1 then MDRO_MRSA=0;
if MDRO_VRE NE 1 then MDRO_VRE=0;
if MDRO_VRE=1 or MDRO_MRSA=1 or  MDRO_MDRPA=1 or MDRO_ESBL=1 or MDRO_Acinetobacter=1 
or MDRO_CRE_CDC2015=1  then any_MDRO=1; else any_MDRO=0;
RUN;

/*check*/
proc sql;
SELECT count(distinct unique_hosp_count_id), admityear 
FROM happi.HAPPI_AIM2_MDRO_HOSP
where MDRO_VRE=1
group by admityear
order by admityear;
quit;

proc sql;
SELECT count(distinct unique_hosp_count_id), admityear 
FROM happi.HAPPI_AIM2_MDRO_HOSP
where any_MDRO=1
group by admityear
order by admityear;
quit;

/********************************************************************************************/
/*90-day mortality from ED arrival*/
data aim2_happicohrot_90dmort (compress=yes); 
set AIM2_HAPPIcohort_hosp;
drop day2_date EDprior180_date;
run;

PROC SQL;
	CREATE TABLE aim2_happicohrot_90dmort_v1  (compress=yes)  AS
	SELECT A.*, B.dod_20210112_pull
	FROM  aim2_happicohrot_90dmort   A
	LEFT JOIN happi.DOD_20210112_PULL  B ON A.patienticn=B.patienticn;
QUIT;

/*recalculate 30 day mort and in hosp mort*/
DATA happi.aim2_happicohrot_90dmortED (compress=yes);  
SET aim2_happicohrot_90dmort_v1;
if not missing(DOD_20210112_PULL) then do; 
	deathdaysafterED=datdif(edisarrivaldate,DOD_20210112_PULL, 'act/act');
end;
/*90 day mort after ED arrival*/
if not missing(DOD_20210112_PULL) and abs(deathdaysafterED) <=90 then mort90_ED=1;
       else mort90_ED=0;
/*30 day mort after ED arrival*/
if not missing(DOD_20210112_PULL) and abs(deathdaysafterED) <=30 then mort30_ED=1;
       else mort30_ED=0;
RUN;

proc sql;
SELECT count(distinct unique_hosp_count_id), admityear 
FROM happi.aim2_happicohrot_90dmortED
where mort90_ED=1
group by admityear
order by admityear;
quit;


/*****************************************************************************************************************************************/
/*AIM 2: ALLERGY*/

/*After piloting 2017 only data, now clean the 2013-2018 data*/
libname allergy '';

PROC SORT DATA=allergy.ALLERGY20132018_SW20210118   nodupkey  OUT=allergy20132018_sw20200625 (COMPRESS=YES); 
BY  PatientSID sta3n OriginationDateTime AllergySID  AllergicReactant ReactionSID ReactionSynonym;
RUN;

DATA allergy20132018_sw20200625 (compress=yes rename=patienticn2=patienticn); 
SET allergy20132018_sw20200625;
AllergicReactant2=upcase(AllergicReactant); /*turn all units into uppercase*/
orgin_date=datepart(OriginationDateTime);
format orgin_date mmddyy10.;
patienticn2 = input(patienticn, 10.);
drop patienticn;
year=year(orgin_date);
RUN;

PROC SQL;
CREATE TABLE  cohort   (COMPRESS=YES) AS 
SELECT A.* FROM allergy20132018_sw20200625 AS A
WHERE A.patienticn IN (SELECT  patienticn FROM  happi.uniqhappicrt_20132018_sw210105);
QUIT;

/*find antibiotic drugs*/
/*note, on 6/16/20, Hallie added a few abx names after reviewing the non-abx list below*/
PROC SQL;
CREATE TABLE  find   AS
SELECT *,
       case  WHEN ALLERGICREACTANT2  LIKE ('%ACYCLOVIR%') OR ALLERGICREACTANT2  LIKE ('%AMIKACIN%') OR ALLERGICREACTANT2  LIKE ('%AMOXICILLIN%') OR ALLERGICREACTANT2  LIKE ('%CLAVULANATE%') OR 
ALLERGICREACTANT2  LIKE ('%AMPHOTERICIN B%') OR ALLERGICREACTANT2  LIKE ('%AMPICILLIN%') OR ALLERGICREACTANT2  LIKE ('%SULBACTAM%') OR 
ALLERGICREACTANT2  LIKE ('%ANIDULAFUNGIN%') OR ALLERGICREACTANT2  LIKE ('%AZITHROMYCIN%') OR ALLERGICREACTANT2  LIKE ('%AZTREONAM%') OR ALLERGICREACTANT2  LIKE ('%CASPOFUNGIN%') OR 
ALLERGICREACTANT2  LIKE ('%CEFACLOR%') OR ALLERGICREACTANT2  LIKE ('%CEFADROXIL%') OR ALLERGICREACTANT2  LIKE ('%CEFAMANDOLE%') OR ALLERGICREACTANT2  LIKE ('%CEFAZOLIN%') OR 
ALLERGICREACTANT2  LIKE ('%CEFDINIR%') OR ALLERGICREACTANT2  LIKE ('%CEFDITOREN%') OR ALLERGICREACTANT2  LIKE ('%CEFEPIME%') OR ALLERGICREACTANT2  LIKE ('%CEFIXIME%') OR 
ALLERGICREACTANT2  LIKE ('%CEFMETAZOLE%') OR ALLERGICREACTANT2  LIKE ('%CEFONICID%') OR ALLERGICREACTANT2  LIKE ('%CEFOPERAZONE%') OR ALLERGICREACTANT2  LIKE ('%CEFOTAXIME%') OR 
ALLERGICREACTANT2  LIKE ('%CEFOTETAN%') OR ALLERGICREACTANT2  LIKE ('%CEFOXITIN%') OR ALLERGICREACTANT2  LIKE ('%CEFPODOXIME%') OR 
ALLERGICREACTANT2  LIKE ('%CEFPROZIL%') OR ALLERGICREACTANT2  LIKE ('%CEFTAROLINE%') OR ALLERGICREACTANT2  LIKE ('%CEFTAZIDIME%') OR 
ALLERGICREACTANT2  LIKE ('%AVIBACTAM%') OR ALLERGICREACTANT2  LIKE ('%CEFTIBUTEN%') OR ALLERGICREACTANT2  LIKE ('%CEFTIZOXIME%') OR ALLERGICREACTANT2  LIKE ('%TAZOBACTAM%') OR 
ALLERGICREACTANT2  LIKE ('%CEFTRIAXONE%') OR ALLERGICREACTANT2  LIKE ('%CEFUROXIME%') OR ALLERGICREACTANT2  LIKE ('%CEPHALEXIN%') OR ALLERGICREACTANT2  LIKE ('%CEPHALOTHIN%') OR ALLERGICREACTANT2  LIKE ('%CEPHAPIRIN%') OR 
ALLERGICREACTANT2  LIKE ('%CEPHRADINE%') OR ALLERGICREACTANT2  LIKE ('%CHLORAMPHENICOL%') OR ALLERGICREACTANT2  LIKE ('%CIDOFOVIR%') OR ALLERGICREACTANT2  LIKE ('%CINOXACIN%') OR 
ALLERGICREACTANT2  LIKE ('%CIPROFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%CLINDAMYCIN%') OR ALLERGICREACTANT2  LIKE ('%CLOXACILLIN%') OR ALLERGICREACTANT2  LIKE ('%COLISTIN%') OR 
ALLERGICREACTANT2  LIKE ('%COLISTIMETHATE%') OR ALLERGICREACTANT2  LIKE ('%DALBAVANCIN%') OR ALLERGICREACTANT2  LIKE ('%DAPTOMYCIN%') OR ALLERGICREACTANT2  LIKE ('%DICLOXACILLIN%') OR 
ALLERGICREACTANT2  LIKE ('%DORIPENEM%') OR ALLERGICREACTANT2  LIKE ('%DOXYCYCLINE%') OR ALLERGICREACTANT2  LIKE ('%ERTAPENEM%') OR 
ALLERGICREACTANT2  LIKE ('%FIDAXOMICIN%') OR ALLERGICREACTANT2  LIKE ('%FLUCONAZOLE%') OR ALLERGICREACTANT2  LIKE ('%FOSCARNET%') OR ALLERGICREACTANT2  LIKE ('%FOSFOMYCIN%') OR ALLERGICREACTANT2  LIKE ('%GANCICLOVIR%') OR 
ALLERGICREACTANT2  LIKE ('%GATIFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%GENTAMICIN%') OR ALLERGICREACTANT2  LIKE ('%IMIPENEM%') OR ALLERGICREACTANT2  LIKE ('%ITRACONAZOLE%') OR 
ALLERGICREACTANT2  LIKE ('%KANAMYCIN%') OR ALLERGICREACTANT2  LIKE ('%LEVOFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%LINCOMYCIN%') OR ALLERGICREACTANT2  LIKE ('%LINEZOLID%') OR 
ALLERGICREACTANT2  LIKE ('%MEROPENEM%') OR ALLERGICREACTANT2  LIKE ('%METHICILLIN%') OR ALLERGICREACTANT2  LIKE ('%METRONIDAZOLE%') OR ALLERGICREACTANT2  LIKE ('%MEZLOCILLIN%') OR 
ALLERGICREACTANT2  LIKE ('%MICAFUNGIN%') OR ALLERGICREACTANT2  LIKE ('%MINOCYCLINE%') OR ALLERGICREACTANT2  LIKE ('%MOXIFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%NAFCILLIN%') OR 
ALLERGICREACTANT2  LIKE ('%NITROFURANTOIN%') OR ALLERGICREACTANT2  LIKE ('%NORFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%OFLOXACIN%') OR ALLERGICREACTANT2  LIKE ('%ORITAVANCIN%') OR 
ALLERGICREACTANT2  LIKE ('%OXACILLIN%') OR ALLERGICREACTANT2  LIKE ('%PENICILLIN%') OR ALLERGICREACTANT2  LIKE ('%PERAMIVIR%') OR ALLERGICREACTANT2  LIKE ('%PIPERACILLIN%') OR 
ALLERGICREACTANT2  LIKE ('%TAZOBACTAM%') OR ALLERGICREACTANT2  LIKE ('%PIVAMPICILLIN%') OR ALLERGICREACTANT2  LIKE ('%POLYMYXIN B%') OR ALLERGICREACTANT2  LIKE ('%POSACONAZOLE%') OR 
ALLERGICREACTANT2  LIKE ('%QUINUPRISTIN%') OR ALLERGICREACTANT2  LIKE ('%DALFOPRISTIN%') OR ALLERGICREACTANT2  LIKE ('%STREPTOMYCIN%') OR ALLERGICREACTANT2  LIKE ('%SULFADIAZINE%') OR 
ALLERGICREACTANT2  LIKE ('%TRIMETHOPRIM%') OR ALLERGICREACTANT2  LIKE ('%SULFAMETHOXAZOLE%') OR ALLERGICREACTANT2  LIKE ('%SULFISOXAZOLE%') OR 
ALLERGICREACTANT2  LIKE ('%TEDIZOLID%') OR ALLERGICREACTANT2  LIKE ('%TELAVANCIN%') OR ALLERGICREACTANT2  LIKE ('%TELITHROMYCIN%') OR ALLERGICREACTANT2  LIKE ('%TETRACYCLINE%') OR 
ALLERGICREACTANT2  LIKE ('%TICARCILLIN%') OR ALLERGICREACTANT2  LIKE ('%CLAVULANATE%') OR ALLERGICREACTANT2  LIKE ('%TIGECYCLINE%') OR ALLERGICREACTANT2  LIKE ('%TOBRAMYCIN%') OR 
ALLERGICREACTANT2  LIKE ('%TRIMETHOPRIM%') OR ALLERGICREACTANT2  LIKE ('%SULFAMETHOXAZOLE%') OR ALLERGICREACTANT2  LIKE ('%VANCOMYCIN%') OR ALLERGICREACTANT2  LIKE ('%VORICONAZOLE%')
 OR ALLERGICREACTANT2  LIKE ('%SULFA DRUGS%')  OR ALLERGICREACTANT2  LIKE ('%BACTRIM%') OR ALLERGICREACTANT2  LIKE ('%LEVAQUIN%')
 OR ALLERGICREACTANT2  LIKE ('%AUGMENTIN%') OR ALLERGICREACTANT2  LIKE ('%BACTRIM DS%')
OR ALLERGICREACTANT2  LIKE ('%ERYTHROMYCIN%') OR ALLERGICREACTANT2  LIKE ('%ZOSYN INJECTION%') OR ALLERGICREACTANT2  LIKE ('%ZITHROMAX%')
OR ALLERGICREACTANT2  LIKE ('%OSELTAMIVIR%') OR ALLERGICREACTANT2  LIKE ('%ISAVUCONAZONIUM%') OR ALLERGICREACTANT2  LIKE ('%CLARITHROMYCIN%') OR ALLERGICREACTANT2  LIKE ('%RIFAMPIN%')
then 'abx'
			 ELSE 'non_abx'
			   END as drug_name
FROM cohort;
QUIT;

PROC FREQ DATA=find   order=freq; 
TABLE drug_name;
RUN;

DATA abx_only (compress=yes); 
SET  find ;
if drug_name ='abx';
RUN;

PROC FREQ DATA=abx_only order=freq;
TABLE ALLERGICREACTANT2;
RUN;

/*merge to happi hosp cohort, get EDIS entry date back*/
PROC SORT DATA=happi.HAPPIVAPD20132018_20200515  nodupkey  
OUT=HAPPIVAPD20132018_20200515 (compress=yes keep=patienticn new_admitdate3 new_dischargedate3 earliest_edisarrivaltime_hosp)  ;
BY patienticn new_admitdate3 new_dischargedate3 earliest_edisarrivaltime_hosp;
RUN;

DATA HAPPI20132018 (compress=yes); 
SET happi.uniqhappicrt_20132018_sw210105;
admityear=year(new_admitdate3);
drop  earliest_edisarrivaltime_hosp;
RUN;

PROC SQL;
	CREATE TABLE  cohort2 (compress=yes)  AS 
	SELECT A.*, B.earliest_edisarrivaltime_hosp
	FROM  HAPPI20132018  A
	LEFT JOIN HAPPIVAPD20132018_20200515  B
	ON A.patienticn =B.patienticn and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3 ;
QUIT;

DATA cohort2b (compress=yes); 
SET  cohort2;
EDIS_date=datepart(earliest_edisarrivaltime_hosp);
format EDIS_date mmddyy10.;
RUN;

/*merge in allergies, one to many merge*/
PROC SQL;
	CREATE TABLE  cohort3 (compress=yes)  AS 
	SELECT A.*, B.orgin_date, b.AllergicReactant2, b.ObservedHistorical, b.AllergyType, b.Mechanism, b.ReactionSynonym
	FROM   cohort2b  A
	LEFT JOIN  abx_only B 	ON A.patienticn =B.patienticn ;
QUIT;

PROC SORT DATA= cohort3;
BY patienticn;
RUN;

/*select only the allergy dates within 9 days of EDIS arrival time*/
DATA cohort3b (compress=yes); 
SET cohort3;
if orgin_date=. then delete;
RUN;

DATA cohort3b (compress=yes);
SET cohort3b;
day_diff = orgin_date-EDIS_date; /*calculate datedif between orgin_date and EDIS_date*/
if 0<=day_diff <=9 then keep9days=1; else keep9days=0;
if day_diff <0 then before=1; else before=0;
if day_diff >0 then after=1; else after=0;
if day_diff=0 then same=1; else same=0;
RUN;

DATA keep9days (compress=yes); 
SET cohort3b;
if keep9days=1;
RUN;

PROC FREQ DATA=keep9days;
TABLE  day_diff;
RUN;

PROC SQL;
	CREATE TABLE cohort4  (compress=yes)  AS 
	SELECT A.*, B.EDIS_date, b.orgin_date, b.AllergicReactant2, b.day_diff,b.ObservedHistorical, b.AllergyType, b.Mechanism, b.ReactionSynonym
	FROM  HAPPI20132018   A
	LEFT JOIN keep9days  B
	ON A.patienticn =B.patienticn and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3;
QUIT;

/*count unique hosps with allergies*/
DATA unique_hosp  (compress=yes); 
SET cohort4;
if orgin_date NE .;
RUN;

PROC FREQ DATA=unique_hosp;
TABLE  day_diff ObservedHistorical AllergyType Mechanism  AllergicReactant2;
RUN;

PROC SORT DATA=unique_hosp  nodupkey out=unique_hosp2; 
BY  unique_hosp_count_id;
RUN;

DATA  day0_only (compress=yes); 
SET unique_hosp;
if day_diff=0;
RUN;

PROC FREQ DATA=day0_only;
TABLE ObservedHistorical AllergyType Mechanism;
RUN;

DATA  day1ormore_only (compress=yes); 
SET unique_hosp;
if day_diff>0;
RUN;

PROC FREQ DATA=day1ormore_only;
TABLE ObservedHistorical AllergyType Mechanism;
RUN;

PROC FREQ DATA=unique_hosp;
TABLE day_diff*ObservedHistorical;
RUN;

/*create the new variables: 
o	Hallie’s thoughts:
?	For Day 0 and Day 1 we should use only observed allergies
?	Days 2-9 include all abx allergies
•	Any historic allergies beyond Day 2 are likely discovered because the patient had a reaction
?	Variable to bring into HAPPI – abx allergy variable, indicator yes if observed on days 0 or 1, OR  any allergy (historical or observed) on days 2-9
?	Keep the dataset with more detail so that we could go back and make edits later   */

/*there are a few duplicate hospitalizations due to more than 1 allergic reaction during the stay*/
PROC SORT DATA=unique_hosp  nodupkey  OUT=days;
BY  unique_hosp_count_id day_diff;
RUN;

/*make new variables*/
DATA allergy.HAPPYCohort20132018_20210118 (compress=yes rename=orgin_date=origination_date rename=AllergicReactant2=AllergicReactant);
SET  days;
if  (day_diff in (0,1)) and (ObservedHistorical='o') then    day0_1_obs_allergy=1; else   day0_1_obs_allergy=0;
if  day_diff in (2,3,4,5,6,7,8,9) then day2_9_any_allergy =1; else day2_9_any_allergy =0;
if  (day_diff in (2,3,4,5,6,7,8,9))  and (ObservedHistorical='h') then  day2_9_his_allergy=1; else  day2_9_his_allergy=0;
if  (day_diff in (2,3,4,5,6,7,8,9))  and (ObservedHistorical='o') then  day2_9_obs_allergy=1; else  day2_9_obs_allergy=0;
if day0_1_obs_allergy=1 or day2_9_any_allergy=1 then allergy_abx_ind=1; else  allergy_abx_ind=0;
RUN;

PROC FREQ DATA=allergy.HAPPYCohort20132018_20210118  order=freq;
TABLE  allergy_abx_ind day2_9_any_allergy day0_1_obs_allergy;
RUN;

proc sql;
SELECT count(distinct unique_hosp_count_id), admityear 
FROM allergy.HAPPYCohort20132018_20210118
where allergy_abx_ind=1
group by admityear
order by admityear;
quit;

DATA view_allergy (compress=yes); 
SET  allergy.HAPPYCohort20132018_20210118;
keep unique_hosp_count_id  EDIS_date origination_date day_diff ObservedHistorical day0_1_obs_allergy day2_9_any_allergy day2_9_his_allergy day2_9_obs_allergy  allergy_abx_ind;
RUN;

DATA allergy.HAPPICohort20132018_20210316 (compress=yes); 
SET allergy.HAPPYCohort20132018_20210118 ;
if allergy_abx_ind=1;
RUN;

PROC SORT DATA=allergy.HAPPICohort20132018_20210316  nodupkey; 
BY  unique_hosp_count_id;
RUN;


/*********************************************************************************************************************/
/*3/1/2021: Isolation of new resistant bacteria, looking only at blood samples*/
/*Tao's Table with sampletypes*/
DATA mdrosample_tao_sw20210105 (compress=yes rename=patienticn2=patienticn); 
SET  happi.mdrosample_tao_sw20210105;
patienticn2 = input(patienticn, 10.);
drop patienticn;
SpecimenDate=datepart(SpecimenTakenDateTime);
format SpecimenDate mmddyy10.;
RUN;

PROC SORT DATA=mdrosample_tao_sw20210105  nodupkey  OUT=mdrosample_v2 (compress=yes); 
BY  patienticn SpecimenTakenDateTime Case_Definition SampleType;
RUN;

/*was collected during calendar days +2-90 after calendar day of ED arrival AND no positive 
culture/swab for that organism in the 180 calendar days prior to calendar day of ED arrival.*/
/*9/29/20: Hallie said to drop MSSA and CPE*/
DATA mdrosample_v3 (compress=yes); 
SET mdrosample_v2;
if Case_Definition in ('MSSA','CPE','CRK_cdc2015','CRAB','MDRE') then delete;
RUN;

PROC FREQ DATA=mdrosample_v3  order=freq;
TABLE Case_Definition SampleType;
RUN;

/*KEEP ONLY BLOOD, SERUM, OR PLASMA*/
DATA mdrosample_v3B (compress=yes); 
SET mdrosample_v3;
IF SAMPLETYPE NOT IN ('BLOOD','SERUM','PLASMA') THEN DELETE;
RUN;

PROC FREQ DATA=mdrosample_v3B  order=freq;
TABLE  SAMPLETYPE;
RUN;

/*select only the HAPPI cohort*/
PROC SQL;
CREATE TABLE  aim2_happicohrot  (COMPRESS=YES) AS 
SELECT A.* FROM happi.HAPPIVAPD20132018_20200515 AS A
WHERE A.unique_hosp_count_id IN (SELECT  unique_hosp_count_id  FROM happi.UNIQHAPPICRT_20132018_SW210105);
QUIT;

PROC SORT DATA=aim2_happicohrot;
BY  unique_hosp_count_id;
RUN;

/*make indicators for after (2-90) and prior (180) ED arrival for each case_definition (type)*/
DATA AIM2_HAPPIcohort_hosp (compress=yes); 
SET  aim2_happicohrot;
edisarrivaldate= datepart(earliest_edisarrivaltime_hosp);
format edisarrivaldate mmddyy10.;
day2_date=edisarrivaldate+2;
day90_date=edisarrivaldate+90;
EDprior180_date=edisarrivaldate-180;
format day2_date mmddyy10. day90_date mmddyy10. EDprior180_date mmddyy10. ;
keep patienticn sta6a unique_hosp_count_id new_dischargedate3 new_admitdate3 edisarrivaldate day2_date day90_date EDprior180_date admityear;
RUN;

PROC SORT DATA=AIM2_HAPPIcohort_hosp  nodupkey; 
BY unique_hosp_count_id;
RUN;

/*one to many merge*/
PROC SQL;
	CREATE TABLE  MDR_data (compress=yes)  AS 
	SELECT A.*, B.SpecimenDate, b.Case_Definition, b.AntibioticSensitivityIEN
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN mdrosample_v3B  B ON A.patienticn=B.patienticn;
QUIT;

PROC SORT DATA=MDR_data;
BY unique_hosp_count_id  SpecimenDate;
RUN;

DATA MDR_data_v2 (compress=yes); 
SET  MDR_data;
/*MDRPA*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='MDRPA' then MDRPA_2_90dayED=1; else MDRPA_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='MDRPA' then MDRPA_180priorED=1; else MDRPA_180priorED=0;
/*MRSA*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='MRSA' then MRSA_2_90dayED=1; else MRSA_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='MRSA' then MRSA_180priorED=1; else MRSA_180priorED=0;
/*VRE*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='VRE' then VRE_2_90dayED=1; else VRE_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='VRE' then VRE_180priorED=1; else VRE_180priorED=0;
/*ESBL*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='ESBL' then ESBL_2_90dayED=1; else ESBL_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='ESBL' then ESBL_180priorED=1; else ESBL_180priorED=0;
/*CRE_CDC2015*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='CRE_CDC2015' then CRE_CDC2015_2_90dayED=1; else CRE_CDC2015_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='CRE_CDC2015' then CRE_CDC2015_180priorED=1; else CRE_CDC2015_180priorED=0;
/*Acinetobacter*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='Acinetobacter' then Acinetobacter_2_90dayED=1; else Acinetobacter_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='Acinetobacter' then Acinetobacter_180priorED=1; else Acinetobacter_180priorED=0;
RUN;


/*creat each dataset for types*/
DATA Acinetobacter (compress=yes); 
SET  MDR_data_v2;
if Acinetobacter_180priorED=0 and Acinetobacter_2_90dayED=1;
MDRO_Acinetobacter=1;
RUN;

PROC SORT DATA=Acinetobacter nodupkey  OUT=Acinetobacter_hosp; 
BY unique_hosp_count_id;
RUN;
PROC FREQ DATA=Acinetobacter_hosp;
TABLE  admityear;
RUN;

DATA MDRPA (compress=yes); 
SET  MDR_data_v2;
if MDRPA_180priorED=0 and MDRPA_2_90dayED=1;
MDRO_MDRPA=1;
RUN;

PROC SORT DATA=MDRPA  nodupkey  OUT=MDRPA_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=MDRPA_hosp;
TABLE  admityear;
RUN;

DATA MRSA (compress=yes); 
SET  MDR_data_v2;
if MRSA_180priorED=0 and MRSA_2_90dayED=1;
MDRO_MRSA=1;
RUN;

PROC SORT DATA=MRSA  nodupkey  OUT=MRSA_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=MRSA_hosp;
TABLE  admityear;
RUN;


DATA VRE (compress=yes); 
SET  MDR_data_v2;
if VRE_180priorED=0 and VRE_2_90dayED=1;
MDRO_VRE=1;
RUN;

PROC SORT DATA=VRE  nodupkey  OUT=VRE_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=VRE_hosp;
TABLE  admityear;
RUN;


DATA ESBL (compress=yes); 
SET  MDR_data_v2;
if ESBL_180priorED=0 and ESBL_2_90dayED=1;
MDRO_ESBL=1;
RUN;

PROC SORT DATA=ESBL  nodupkey  OUT=ESBL_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=ESBL_hosp;
TABLE  admityear;
RUN;

DATA CRE_CDC2015 (compress=yes);
SET  MDR_data_v2;
if CRE_CDC2015_180priorED=0 and CRE_CDC2015_2_90dayED=1;
MDRO_CRE_CDC2015=1;
RUN;

PROC SORT DATA=CRE_CDC2015  nodupkey  OUT=CRE_CDC2015_hosp; 
BY unique_hosp_count_id;
RUN;

PROC FREQ DATA=CRE_CDC2015_hosp;
TABLE  admityear;
RUN;

PROC SQL;
	CREATE TABLE  HAPPI_MDRO (compress=yes)  AS
	SELECT A.*, B.MDRO_Acinetobacter, c.MDRO_ESBL, d.MDRO_MDRPA, e.MDRO_MRSA,f.MDRO_VRE
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN Acinetobacter_hosp  B ON A.unique_hosp_count_id =B.unique_hosp_count_id 
	LEFT JOIN ESBL_hosp  C ON A.unique_hosp_count_id =C.unique_hosp_count_id
	LEFT JOIN MDRPA_hosp  d ON A.unique_hosp_count_id =d.unique_hosp_count_id
	LEFT JOIN MRSA_hosp  e ON A.unique_hosp_count_id =e.unique_hosp_count_id
    LEFT JOIN VRE_hosp  f ON A.unique_hosp_count_id =f.unique_hosp_count_id;
QUIT;

DATA happi.HAPPI_AIM2_MDROBLOOD_HOSP (compress=yes); 
SET  HAPPI_MDRO;
MDRO_CRE_CDC2015=0;
if MDRO_Acinetobacter NE 1 then MDRO_Acinetobacter=0;
if MDRO_ESBL NE 1 then MDRO_ESBL=0;
if MDRO_MDRPA NE 1 then MDRO_MDRPA=0;
if MDRO_MRSA NE 1 then MDRO_MRSA=0;
if MDRO_VRE NE 1 then MDRO_VRE=0;
if MDRO_VRE=1 or MDRO_MRSA=1 or  MDRO_MDRPA=1 or MDRO_ESBL=1 or MDRO_Acinetobacter=1 
or MDRO_CRE_CDC2015=1  then any_MDRO_blood=1; else any_MDRO_blood=0;
RUN;

/*check by changing each MDRO type in the where statment*/
proc sql;
SELECT count(distinct unique_hosp_count_id), admityear
FROM happi.HAPPI_AIM2_MDROBLOOD_HOSP 
where MDRO_MRSA=1
group by admityear
order by admityear;
quit;

proc sql;
SELECT count(distinct unique_hosp_count_id), admityear 
FROM happi.HAPPI_AIM2_MDROBLOOD_HOSP
where any_MDRO=1
group by admityear
order by admityear;
quit;



/****************************************************************************************
/*4/8/21: On 3/30/21 Makoto added ESCR to the app.mdro in CDW. Hallie said to add to AIM2 outcomes
as MDRO_ESCR and ESCR_blood.*/
proc freq data=happi.mdrosample_tao_sw20210105;
table Case_Definition;
run;

data mdro_makoto_sw20210407 (compress=yes); 
SET  happi.mdro_makoto_sw20210407;
SpecimenDate=datepart(SpecimenTakenDateTime);
format SpecimenDate mmddyy10.;
if Case_Definition='ESCR';
RUN;

PROC SORT DATA=mdro_makoto_sw20210407;
BY  patienticn SpecimenTakenDateTime;
RUN;

/*one to many merge*/
PROC SQL;
	CREATE TABLE  ESCR_data (compress=yes)  AS 
	SELECT A.*, B.SpecimenDate, b.Case_Definition, b.AntibioticSensitivityIEN
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN mdro_makoto_sw20210407 B ON A.patienticn=B.patienticn;
QUIT;

PROC SORT DATA=ESCR_data;
BY unique_hosp_count_id  SpecimenDate;
RUN;

DATA ESCR_data_v2 (compress=yes); 
SET  ESCR_data;
/*ESCR*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='ESCR' then ESCR_2_90dayED=1; else ESCR_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='ESCR' then ESCR_180priorED=1; else ESCR_180priorED=0;
run;

/*creat each dataset for types*/
DATA ESCR (compress=yes); 
SET  ESCR_data_v2;
if ESCR_180priorED=0 and ESCR_2_90dayED=1;
ESCR=1;
RUN;

PROC SORT DATA=ESCR nodupkey  OUT=ESCR_hosp; 
BY unique_hosp_count_id;
RUN;
PROC FREQ DATA=ESCR_hosp;
TABLE  admityear;
RUN;


/******************* ESCR Blood Samples only *********************/
proc freq data=happi.MDROSAMPLE_MAKOTO_SW20210408;
table sampletype;
run;

data MDROSAMPLE_MAKOTO_SW20210408 (compress=yes);
SET  happi.MDROSAMPLE_MAKOTO_SW20210408;
SpecimenDate=datepart(SpecimenTakenDateTime);
format SpecimenDate mmddyy10.;
if Case_Definition='ESCR' and  
SAMPLETYPE IN ('BLOOD','SERUM','PLASMA'); /*KEEP ONLY BLOOD, SERUM, OR PLASMA*/
RUN;

proc freq data=MDROSAMPLE_MAKOTO_SW20210408;
table sampletype Case_Definition;
run;

PROC SORT DATA=MDROSAMPLE_MAKOTO_SW20210408;
BY  patienticn SpecimenTakenDateTime;
RUN;

/*one to many merge*/
PROC SQL;
	CREATE TABLE  ESCRblood_data (compress=yes)  AS 
	SELECT A.*, B.SpecimenDate, b.Case_Definition, b.AntibioticSensitivityIEN
	FROM  AIM2_HAPPIcohort_hosp   A
	LEFT JOIN MDROSAMPLE_MAKOTO_SW20210408 B ON A.patienticn=B.patienticn;
QUIT;

PROC SORT DATA=ESCRblood_data;
BY unique_hosp_count_id  SpecimenDate;
RUN;

DATA ESCRblood_data_v2 (compress=yes); 
SET  ESCRblood_data;
/*ESCR*/
if (day2_date <= SpecimenDate <= day90_date) and Case_Definition ='ESCR' then ESCR_2_90dayED=1; else ESCR_2_90dayED=0;
if (EDprior180_date <= SpecimenDate < edisarrivaldate) and Case_Definition ='ESCR' then ESCR_180priorED=1; else ESCR_180priorED=0;
run;

/*creat each dataset for types*/
DATA ESCRblood (compress=yes); 
SET  ESCRblood_data_v2;
if ESCR_180priorED=0 and ESCR_2_90dayED=1;
ESCRblood=1;
RUN;

PROC SORT DATA=ESCRblood nodupkey  OUT=ESCRblood_hosp; 
BY unique_hosp_count_id;
RUN;
PROC FREQ DATA=ESCRblood_hosp;
TABLE  admityear;
RUN;

/*4/15/21: merge ESCR and ESCR_blood inds back to VAPD HAPPI dataset: happi.AIM2_alloutcomes_20210316*/
/**********************************************************************************/
/*Create an AIMS 2 HAPPI cohort dataset for Sarah*/
/*HAPPI cohort, hosp level*/
DATA AIM2_HAPPIcohort_hosp_v2 (compress=yes); 
SET  AIM2_HAPPIcohort_hosp;
drop day2_date day90_date EDprior180_date;
RUN;

PROC SORT DATA=allergy.HAPPYCohort20132018_20210118 nodupkey  OUT=test;
BY  unique_hosp_count_id;
RUN;
/*merge all AIM2 outcomes variables*/
/*happi.HAPPI_AIM2_Thrombocytopenia_hosp, Thrombocytopenia_hosp
happi.HAPPI_AIM2_Leukopenia_hosp, Leukopenia_hosp
happi.HAPPI_AIM2_acuteliverinjury_hosp, Acute_liver_injury
happi.HAPPI_AIM2_acuterenalinjury_hosp, acute_renal_injury
happi.HAPPI_AIM2_CDiff_HOSP, cdiff_infection
happi.HAPPI_AIM2_MDRO_HOSP, any_MDRO
happi.HAPPI_AIM2_MDROBLOOD_HOSP, any_MDRO_blood
happi.aim2_happicohrot_90dmortED, mort90_ED
allergy.HAPPICohort20132018_20210316, allergy_abx_ind*/
PROC SQL;
	CREATE TABLE AIM2_HAPPIcohort_hosp_v3  (compress=yes)  AS 
	SELECT A.*, B.Thrombocytopenia_hosp, c.Leukopenia_hosp, d.Acute_liver_injury,
	  e.acute_renal_injury, f.cdiff_infection, g.any_MDRO,  g.MDRO_Acinetobacter,
	  g.MDRO_ESBL,g.MDRO_MDRPA,g.MDRO_MRSA,g.MDRO_VRE,g.MDRO_CRE_CDC2015,
     h.any_MDRO_blood, h.MDRO_Acinetobacter as Acinetobacter_Blood,
	  h.MDRO_ESBL as ESBL_Blood, h.MDRO_MDRPA as MDRPA_Blood,
     h.MDRO_MRSA as MRSA_Blood, h.MDRO_VRE as VRE_Blood, h.MDRO_CRE_CDC2015 as CRE_cdc2015_Blood,
	 s.ESCR as MDRO_ESCR, w.ESCRBlood as ESCR_blood,i.mort90_ED,i.mort30_ED, k.allergy_abx_ind
	FROM  AIM2_HAPPIcohort_hosp_v2   A
	LEFT JOIN  happi.HAPPI_AIM2_Thrombocytopenia_hosp B ON A.unique_hosp_count_id =B.unique_hosp_count_id 
    LEFT JOIN happi.HAPPI_AIM2_Leukopenia_hosp  c ON A.unique_hosp_count_id =c.unique_hosp_count_id
	LEFT JOIN  happi.HAPPI_AIM2_acuteliverinjury_hosp d ON A.unique_hosp_count_id =d.unique_hosp_count_id
	LEFT JOIN  happi.HAPPI_AIM2_acuterenalinjury_hosp e ON A.unique_hosp_count_id =e.unique_hosp_count_id
	LEFT JOIN  happi.HAPPI_AIM2_CDiff_HOSP f ON A.unique_hosp_count_id =f.unique_hosp_count_id
	LEFT JOIN  happi.HAPPI_AIM2_MDRO_HOSP g ON A.unique_hosp_count_id =g.unique_hosp_count_id
	LEFT JOIN  happi.HAPPI_AIM2_MDROBLOOD_HOSP h ON A.unique_hosp_count_id =h.unique_hosp_count_id
    LEFT JOIN ESCR_hosp  s ON A.unique_hosp_count_id =s.unique_hosp_count_id
    LEFT JOIN ESCRblood_hosp  w ON A.unique_hosp_count_id =w.unique_hosp_count_id
	LEFT JOIN  happi.aim2_happicohrot_90dmortED i ON A.unique_hosp_count_id =i.unique_hosp_count_id
	LEFT JOIN  allergy.HAPPICohort20132018_20210316 k ON A.unique_hosp_count_id =k.unique_hosp_count_id;
QUIT;


DATA happi.AIM2_alloutcomes_20210415 (compress=yes); /*1101014*/
SET AIM2_HAPPIcohort_hosp_v3;
if Thrombocytopenia_hosp NE 1 then Thrombocytopenia_hosp=0;
if Leukopenia_hosp NE 1 then Leukopenia_hosp=0;
if Acute_liver_injury NE 1 then Acute_liver_injury=0;
if acute_renal_injury NE 1 then acute_renal_injury=0;
if cdiff_infection NE 1 then cdiff_infection=0;
if allergy_abx_ind NE 1 then allergy_abx_ind=0;
if MDRO_ESCR NE 1 then MDRO_ESCR=0;
if ESCR_blood NE 1 then ESCR_blood=0;
if MDRO_ESCR=1 or any_MDRO=1 then Any_MDRO_wESCR=1; else Any_MDRO_wESCR =0;
if ESCR_blood=1 or Any_MDRO_Blood=1 then Any_MDRO_Blood_wESCR=1; else Any_MDRO_Blood_wESCR=0;
RUN;

proc freq data=happi.AIM2_alloutcomes_20210415;
table Any_MDRO_wESCR*admityear  Any_MDRO_Blood_wESCR*admityear;
run;

/*macro to change all variables from uppercase to lowercases because unlike SAS, STATA is case sensitive*/ 
%macro lowcase(dsn); 
     %let dsid=%sysfunc(open(&dsn)); 
     %let num=%sysfunc(attrn(&dsid,nvars)); 
     %put &num;
     data &dsn; 
           set &dsn(rename=( 
        %do i = 1 %to &num; 
        %let var&i=%sysfunc(varname(&dsid,&i));      /*function of varname returns the name of a SAS data set variable*/
        &&var&i=%sysfunc(lowcase(&&var&i))         /*rename all variables*/ 
        %end;)); 
        %let close=%sysfunc(close(&dsid)); 
  run; 
%mend lowcase; 

%lowcase(happi.AIM2_alloutcomes_20210415)