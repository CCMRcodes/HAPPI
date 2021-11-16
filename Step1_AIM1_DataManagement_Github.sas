/*Author: Shirley Wang (xiaoqing.wang@va.gov)*/

/*Build VAPD VA to VA Trasnfer VAPD Dataset for 2013-2018*/
libname final '';
libname happi '';
libname labs '';
libname vitals '';
libname meds '';
libname temp '';
libname temp2 '';
libname sarah ''; 
libname acute '';

%macro delete_ds(dslist);

    proc datasets library = work nolist;
        delete &dslist.;
    quit;

%mend delete_ds;

/*combine the 2013-2018 as a whole (one single dataset)*/

/***********************************************************************************************************************************/
/*combine 2013, 2014-3017, and 2018 single-site VAPD and create VA to VA transfer VAPD dataset*/

DATA  VAPDsingle_20142017  (compress=yes);  
retain patienticn patientsid sta3n sta6a   datevalue specialtytransferdatetime dod_09212018_pull new_admitdate2 new_dischargedate2  
 proccode_mechvent_daily  gender hispanic race age;
SET final.SINGLESITE20142017SEPSIS20191224;
keep  patienticn patientsid sta6a sta3n  datevalue specialtytransferdatetime new_admitdate2 new_dischargedate2 
 proccode_mechvent_daily  gender hispanic race age dod_09212018_pull;
RUN;

DATA  VAPDsingle_2013  (compress=yes);  
retain patienticn patientsid sta3n sta6a   datevalue  dod_08052019_pull new_admitdate2 new_dischargedate2  
 proccode_mechvent_daily  gender hispanic race age;
SET final.SINGLESITE2013SEPSIS20191224;
keep  patienticn patientsid sta6a sta3n  datevalue  new_admitdate2 new_dischargedate2 
  proccode_mechvent_daily  gender hispanic race age dod_08052019_pull;
RUN;

/*get specialtytransferdatetime back first*/
/*sort to get the earliest specialtytransferdatetime by patient datevalue*/
PROC SORT DATA=temp.vapd2013_spectransfertime032520; 
BY  patienticn datevalue  specialtytransferdatetime;
RUN;

PROC SORT DATA=temp.vapd2013_spectransfertime032520  nodupkey out=vapd2013_spectransfertime032520 (compress=yes); 
BY  patienticn datevalue;
RUN;

PROC SQL;
	CREATE TABLE VAPDsingle_2013_v2  (compress=yes)  AS 
	SELECT A.*, B.specialtytransferdatetime
	FROM  VAPDsingle_2013  A
	LEFT JOIN vapd2013_spectransfertime032520  B ON A.patienticn =B.patienticn and a.datevalue=b.datevalue;
QUIT;

/*check spec datetime missing?*/
DATA  missing_spdate (compress=yes); 
SET  VAPDsingle_2013_v2;
if specialtytransferdatetime = .;
RUN;

DATA VAPDsingle_2013_v2b (compress=yes); 
retain patienticn patientsid sta3n sta6a   datevalue specialtytransferdatetime dod_08052019_pull new_admitdate2 new_dischargedate2  
 proccode_mechvent_daily  gender hispanic race age;
SET VAPDsingle_2013_v2  ;
keep patienticn patientsid sta3n sta6a   datevalue specialtytransferdatetime dod_08052019_pull new_admitdate2 new_dischargedate2  
 proccode_mechvent_daily  gender hispanic race age;
RUN;

/*rename dod variables then combine*/
DATA VAPDsingle_20142017 (compress=yes rename=dod_09212018_pull=dod); 
SET VAPDsingle_20142017;
RUN;

DATA VAPDsingle_2013_v2b (compress=yes rename=dod_08052019_pull=dod); 
SET VAPDsingle_2013_v2b;
RUN;

/*2018*/
DATA  VAPDsingle_2018  (compress=yes   rename=mechvent=proccode_mechvent_daily);  
retain patienticn patientsid sta3n sta6a  datevalue specialtytransferdatetime dod new_admitdate2 new_dischargedate2  
 mechvent  gender hispanic race age;
SET acute.VAPDSINGLESITE2018_20200508; 
if Ethnicity ='HISPANIC OR LATINO' then hispanic=1; else hispanic=0; 
keep  patienticn patientsid sta6a sta3n  datevalue specialtytransferdatetime new_admitdate2 new_dischargedate2 
mechvent  gender hispanic race age dod;
RUN;

/*combine VAPD single 2014-3017,VAPD single 2013 and VAPD single 2018 datasets*/
DATA  VAPDsingle_20132018  (compress=yes);
SET  VAPDsingle_20142017  VAPDsingle_2013_v2b VAPDsingle_2018;
if patienticn =1003214329 and new_admitdate2='01Jan2014'd and new_dischargedate2='03Jan2014'd then delete; /*delete a duplicate record, embedded specialty stay*/
RUN;

/*create new VA to VA transfer admit and discharge dates*/
/*Shirley's new code to roll up the VA to VA transfers in VAPD*/
/*1. sort the dataset by patient and admit/discharge dates*/
/*create unique patient hosp count*/
PROC SORT DATA=VAPDsingle_20132018 nodupkey out=testb; 
BY  patienticn new_admitdate2 new_dischargedate2;
RUN;

DATA testb (compress=yes); 
SET testb;
unique_hosp=_N_; 
RUN;

PROC SORT DATA=testb;
BY patienticn new_admitdate2 new_dischargedate2;
RUN;

/*label first patieticn, if first.patienticn then lag_discharge=discharge*/
DATA test2 (compress=yes); 
SET testb;
by patienticn;
if first.patienticn then do;
	lag_new_dischargedate=new_dischargedate2;  end;  /*create a lag_new_dischargedate for first unique patient, because they shouldn't have a lag_new_dischargedate, so it is =new_dischargedate2 */
    lag_new_dischargedate2=lag(new_dischargedate2); /*create a lag_new_dischargedate2*/
format lag_new_dischargedate mmddyy10.  lag_new_dischargedate2 mmddyy10.;
RUN;

DATA test3 (compress=yes); 
SET test2;
if lag_new_dischargedate NE . then lag_new_dischargedate2= .;
if lag_new_dischargedate = . then lag_new_dischargedate=lag_new_dischargedate2;
drop lag_new_dischargedate2;
diff_days=new_admitdate2 -lag_new_dischargedate; /*calculate date difference from last hosp discharge*/
RUN;

/*create first patienticn indicator, if first.patientinc is true, then it's a new hosp*/
DATA  test3 (compress=yes); 
SET test3 ;
by patienticn;
if first.patienticn then first_pat=0;
 first_pat+1;
RUN;

DATA test4 (compress=yes);
SET test3;
if (first_pat=1 ) OR (diff_days not in (1,0) )/*regardless of sta6a, if diff_days =0 then it is a new hosp*/
	then new_hosp_ind=1; else new_hosp_ind=0;
RUN;

/*check to see previous step works before only selecting new_hosp_ind=1*/
DATA  test5 (compress=yes); 
SET test4;
if new_hosp_ind=1;
RUN;

/*assign each unique_hosp and new_hosp_ind a unique ID*/
PROC SORT DATA= test5 nodupkey  OUT=Unique_hosp_ind (compress=yes); 
BY  patienticn unique_hosp new_hosp_ind;
RUN;

DATA Unique_hosp_ind (compress=yes);
SET  Unique_hosp_ind;
Unique_hosp_ind2=_n_;
RUN;

/*left join Unique_hosp_ind back to original dataset final_copy9*/
PROC SQL;
	CREATE TABLE test6 (compress=yes)  AS 
	SELECT A.*, B.Unique_hosp_ind2
	FROM test4 A
	LEFT JOIN Unique_hosp_ind  B ON A.patienticn =B.patienticn and a.unique_hosp=b.unique_hosp;
QUIT;

/*fill down in a table for Unique_hosp_ind*/
data test7 (drop=filledx compress=yes); 
set test6;
retain filledx; /*keeps the last non-missing value in memory*/
if not missing(Unique_hosp_ind2) then filledx=Unique_hosp_ind2; /*fills the new variable with non-missing value*/
Unique_hosp_ind2=filledx;
run;

PROC SORT DATA=test7;
BY  patienticn new_admitdate2 new_dischargedate2;
RUN;

/*use max and min group by Unique_ICU_specialty to get new speicaltytransferdate and specialtydischargedates*/
PROC SQL;
CREATE TABLE test8 (compress=yes) AS  
SELECT *, min(new_admitdate2) as new_admitdate3, max(new_dischargedate2) as new_dischargedate3
FROM test7
GROUP BY Unique_hosp_ind2;
QUIT;

DATA test8 (compress=yes); 
SET  test8;
format new_admitdate3 mmddyy10. new_dischargedate3 mmddyy10.;
RUN;

PROC SORT DATA=test8;
BY  patienticn new_admitdate2 new_dischargedate2;
RUN;

/*check where new_admitdate2 NE new_admitdate3 or new_dischargedate2 NE new_admitdate3*/
data check_data (compress=yes); 
set test8;
if (new_admitdate2 NE new_admitdate3) or (new_dischargedate2 NE new_dischargedate3);
keep patienticn sta6a new_admitdate2 new_admitdate3 new_dischargedate2 new_dischargedate3  unique_hosp_ind2;
run;

PROC SORT DATA=check_data;
BY Unique_hosp_ind2 new_admitdate2 new_dischargedate2;
RUN;

DATA check_data;
SET check_data;
by Unique_hosp_ind2;
IF FIRST.Unique_hosp_ind2 THEN keep = 1; else keep=0;
RUN;

PROC SORT DATA=test8   OUT= test9 (compress=yes); 
BY patienticn new_admitdate3 new_dischargedate3;
RUN;

/*left join new_admitdate3 & new_dischargedate3 to updated VAPD*/
PROC SQL;
	CREATE TABLE  VAPDsingle_20132018_v2  (compress=yes)  AS 
	SELECT A.*, B.new_admitdate3, b.new_dischargedate3
	FROM  VAPDsingle_20132018  A
	LEFT JOIN  test9 B
	ON A.patienticn=B.patienticn and a.new_admitdate2=b.new_admitdate2 and a.new_dischargedate2=b.new_dischargedate2;
QUIT;

/*check if any with missing admit and discharge dates*/
DATA  check_missings (compress=yes); 
SET  VAPDsingle_20132018_v2;
if new_admitdate3 =. or new_dischargedate3=.;
RUN;

/*create new admityear based on new_admitdate3*/
DATA  VAPDsingle_20132018_v2  (compress=yes); 
SET  VAPDsingle_20132018_v2 ;
admityear=year(new_admitdate3);
if admityear>2018 then delete; /*drop admityear greater than 2018*/
/*new hosp_los*/
hosp_LOS =(new_dischargedate3-new_admitdate3)+1;
RUN;

PROC FREQ DATA=VAPDsingle_20132018_v2  order=freq;
TABLE admityear;
RUN;

PROC MEANS DATA=VAPDsingle_20132018_v2   MIN MAX MEAN MEDIAN Q1 Q3;
VAR age;
RUN;

/*find duplicate pat-days and delete the ones with shorter hosp_LOS*/
/*look at duplicate patient-days on admission and discharge, regardless of facility*/
PROC SORT DATA=VAPDsingle_20132018_v2  nodupkey  OUT=vapd_daily_undup (compress=yes);
BY  patienticn datevalue;
RUN;

/*assigne each pat-day an unique id*/
DATA vapd_daily_undup (compress=yes); 
SET vapd_daily_undup;
unique_datevalue=_n_;
keep  patienticn sta6a datevalue new_admitdate2 new_admitdate3 new_dischargedate2 new_dischargedate3 unique_datevalue hosp_LOS admityear;
RUN;

/*left join unique pat-days back to VAPD 2013-2017 daily*/
PROC SQL;
	CREATE TABLE VAPDsingle_20132018_v2b (compress=yes)  AS 
	SELECT A.*, B.unique_datevalue
	FROM  VAPDsingle_20132018_v2  A
	LEFT JOIN  vapd_daily_undup B
	ON A.patienticn =B.patienticn and a.datevalue=b.datevalue;
QUIT;

/*create old_hosp_los, sort by descending old_hosp_LOS & descending hosp_losto keep the longer hosp_los for each pat-days*/
DATA VAPDsingle_20132018_v2b (compress=yes) ;
SET  VAPDsingle_20132018_v2b;
/*old hosp_los*/
old_hosp_LOS =(new_dischargedate2-new_admitdate2)+1;
RUN;

PROC SORT DATA= VAPDsingle_20132018_v2b ;
BY  unique_datevalue descending old_hosp_LOS descending hosp_los;
RUN;

PROC SORT DATA=VAPDsingle_20132018_v2b  nodupkey  OUT=VAPDsingle_20132018_v2c (compress=yes); 
BY patienticn datevalue;
RUN;

PROC SORT DATA=VAPDsingle_20132018_v2c  nodupkey  OUT=tesetdays1 (compress=yes);
BY  patienticn sta6a datevalue;
RUN;

PROC SORT DATA=VAPDsingle_20132018_v2c  nodupkey  OUT=tesetdays2 (compress=yes);
BY  patienticn datevalue;
RUN;

/*create new hospital_day and unique_hosp_count_id for VA to VA transfer VAPD*/
PROC SORT DATA=VAPDsingle_20132018_v2c ; 
BY patienticn  new_admitdate3 new_dischargedate3 datevalue;
RUN;

data VAPDsingle_20132018_v2d (compress=yes); 
set VAPDsingle_20132018_v2c;
by patienticn  new_admitdate3;
if first.new_admitdate3 then hospital_day=0;
hospital_day+1;
run;

/*get max hospital_day for each hosp and see if they match to hosp_los*/
PROC SORT DATA= VAPDsingle_20132018_v2d;
BY  patienticn  new_admitdate3 new_dischargedate3 descending hospital_day;
RUN;
PROC SORT DATA=VAPDsingle_20132018_v2d  nodupkey  OUT=max_hosp_day; 
BY patienticn  new_admitdate3 new_dischargedate3;
RUN;

data check_max_hosp_day; 
set max_hosp_day;
if hospital_day ne hosp_los;
flag_hosps=1;
run;

PROC SQL;
	CREATE TABLE  check_max_hosp_day2 (compress=yes)  AS 
	SELECT A.*, B.flag_hosps
	FROM   VAPDsingle_20132018_v2d  A
	LEFT JOIN check_max_hosp_day  B
	ON A.patienticn =B.patienticn and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3;
QUIT;

DATA check_max_hosp_day2b (compress=yes); 
SET  check_max_hosp_day2;
if flag_hosps=1;
keep patienticn sta6a datevalue new_admitdate3 new_dischargedate3 new_admitdate2 new_dischargedate2 hosp_LOS unique_datevalue  old_hosp_LOS flag_hosps hospital_day;
RUN;

/*1) delete those hosps with missing days from check_max_hosp_day2*/
DATA vapd20132018daily_v1A (compress=yes); 
SET check_max_hosp_day2;
if flag_hosps=1 then delete;
drop old_hosp_LOS unique_datevalue flag_hosps;
RUN;

PROC CONTENTS DATA=vapd20132018daily_v1A  VARNUM;
RUN;

/*2)for those 237, expand into daily*/
DATA check_max_hosp_v1A (compress=yes);
SET  check_max_hosp_day;
drop datevalue any_BCMAabx_daily proccode_mechvent_daily any_pressor_daily hospital_day  flag_hosps;
RUN;

/*Create a row for each calendar day at a given STA6A*/
data check_max_hosp_v1B (compress=yes); 
set check_max_hosp_v1A;
do datevalue=new_admitdate3 to new_dischargedate3;
	datevalue=datevalue; output;
end;
format datevalue mmddyy10.;
run;

PROC SQL;
	CREATE TABLE check_max_hosp_v1C  (compress=yes)  AS 
	SELECT A.*,  b.proccode_mechvent_daily 
	FROM  check_max_hosp_v1B   A
	LEFT JOIN VAPDsingle_20132018_v2c  B
	ON A.patienticn =B.patienticn and a.datevalue=b.datevalue;
QUIT;

PROC SORT DATA=check_max_hosp_v1C;
BY patienticn datevalue descending old_hosp_LOS descending hosp_los;
RUN;

PROC SORT DATA=check_max_hosp_v1C nodupkey; 
BY  patienticn datevalue;
RUN;

PROC SORT DATA=check_max_hosp_v1C;
BY patienticn  new_admitdate3 new_dischargedate3 datevalue;
RUN;

DATA check_max_hosp_v1D (compress=yes);  
retain patienticn patientsid sta3n sta6a datevalue specialtytransferdatetime dod new_admitdate2 new_dischargedate2 proccode_mechvent_daily
gender hispanic race age new_admitdate3 new_dischargedate3 admityear hosp_LOS hospital_day;
SET check_max_hosp_v1C ;
by patienticn  new_admitdate3;
if first.new_admitdate3 then hospital_day=0;
hospital_day+1;
drop old_hosp_LOS  unique_datevalue;
RUN;

/*3) combine daily and then check dup pat-days and hosp count*/
DATA new_VAPD20132018_daily_v1 (compress=yes); 
SET check_max_hosp_v1D vapd20132018daily_v1A;
RUN;

/*check ducplicate patient-days*/
PROC SORT DATA=new_VAPD20132018_daily_v1 nodupkey dupout=dupdays; 
BY patienticn datevalue;
RUN;

/*combine and look into those 15 duplicate patient-days*/
DATA dupdays (compress=yes);
SET dupdays;
dupdays=1;
keep patienticn datevalue dupdays;
RUN;

/*look at days*/
PROC SQL;
	CREATE TABLE dupdays_v2 (compress=yes)  AS
	SELECT A.*, B.dupdays
	FROM  new_VAPD20132018_daily_v1  A
	LEFT JOIN dupdays  B ON A.patienticn =B.patienticn and a.datevalue=b.datevalue;
QUIT;

DATA dupdays_v3 (compress=yes); 
SET dupdays_v2;
if dupdays=1;
keep patienticn datevalue dupdays new_admitdate3 new_dischargedate3 new_admitdate2 new_dischargedate2;
RUN;

/*drop those hospitalizations*/
PROC SQL;
	CREATE TABLE  days (compress=yes)  AS
	SELECT A.*, B.dupdays as drop
	FROM   new_VAPD20132018_daily_v1  A
	LEFT JOIN dupdays_v3  B
	ON A.patienticn =B.patienticn and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3;
QUIT;

PROC FREQ DATA=days  order=freq;
TABLE drop;
RUN;

DATA days (compress=yes); 
SET  days;
if drop=1 then delete;
drop drop;
RUN;

/*check dups again*/
PROC SORT DATA=days  nodupkey  OUT=days_check (compress=yes); 
BY patienticn datevalue;
RUN;

PROC SORT DATA=days  nodupkey  OUT=days_check2 (compress=yes); /*0 dups*/
BY patienticn datevalue  new_admitdate3 new_dischargedate3;
RUN;

/* # of hospital_day=1 should equal unique hosp count*/
PROC FREQ DATA=days  order=freq; 
TABLE  hospital_day;
RUN;

PROC SORT DATA=days nodupkey  OUT=hosps (compress=yes); 
BY patienticn new_admitdate3 new_dischargedate3;
RUN;

PROC FREQ DATA=hosps;
TABLE admityear;
RUN;

/*count unique hospitalizations, then sum up hosp_los, should equal daily count*/
PROC SORT DATA=days   OUT=days2;
BY  patienticn  new_admitdate3 new_dischargedate3 descending hospital_day;
RUN;

PROC SORT DATA=days2  nodupkey;
BY patienticn  new_admitdate3 new_dischargedate3;
RUN;

PROC SQL;
CREATE TABLE  days2check AS  
SELECT *, sum(hospital_day) as sum_hospital_day
FROM days2;
QUIT;

/*assign each patienticn, newadmitdate3 & newdischargedate3 an unique hosp id*/
/*create unique patient hosp count*/
PROC SORT DATA=hosps;
BY patienticn  new_admitdate3 new_dischargedate3;
RUN;

DATA final_copy_undup2 (compress=yes); 
SET hosps;
unique_hosp_count_id=_N_; 
RUN;

/*match unique_hosp back to original dataset VAPD_20132018*/
PROC SQL;
	CREATE TABLE  VAPD_20132018_v2  (compress=yes)  AS   
	SELECT A.*, B.unique_hosp_count_id
	FROM  days   A
	LEFT JOIN final_copy_undup2  B ON A.patienticn =B.patienticn  and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3;
QUIT;

/*recalculate 30 day mort and in hosp mort*/
DATA  VAPD_20132018_v2 (compress=yes);  
SET VAPD_20132018_v2;
/*inhosp_mort mort30_admit*/
if not missing(dod) then do;
	deathdaysafterdischarge=datdif(new_dischargedate3, dod, 'act/act');  
	deathdaysafteradmit=datdif(new_admitdate3,dod, 'act/act');
end;
if not missing(dod) and abs(deathdaysafterdischarge)<=1 then inhosp_mort=1;
	else inhosp_mort=0;
if not missing(dod) and abs(deathdaysafteradmit) <=30 then mort30_admit=1;
       else mort30_admit=0;
RUN;

/*check %*/
DATA inhosp_mort (compress=yes keep=inhosp_mort patienticn new_admitdate3 new_dischargedate3) 
mort30_admit (compress=yes keep= mort30_admit patienticn new_admitdate3 new_dischargedate3);
SET VAPD_20132018_v2;
if mort30_admit=1 then output mort30_admit;
if inhosp_mort=1 then output inhosp_mort;
RUN;

PROC SORT DATA=inhosp_mort  nodupkey; 
BY  patienticn new_admitdate3 new_dischargedate3;
RUN;

PROC SORT DATA=mort30_admit  nodupkey; 
BY  patienticn new_admitdate3 new_dischargedate3;
RUN;

/*save a perm dataset*/
DATA happi.VAPDvatova20132018_daily05122020 (compress=yes); 
SET  VAPD_20132018_v2;
drop new_admitdate2 new_dischargedate2 deathdaysafterdischarge deathdaysafteradmit;
RUN;

DATA VAPD_20132018_v2 (compress=yes); 
SET happi.VAPDvatova20132018_daily05122020;
if new_admitdate3 < '02jan2013'd then delete;
RUN;

PROC SORT DATA=VAPD_20132018_v2  nodupkey  OUT=VAPD_20132018_v2_hosp;
BY  patienticn new_admitdate3 new_dischargedate3;
RUN;

PROC FREQ DATA=VAPD_20132018_v2_hosp;
TABLE admityear;
RUN;

PROC SORT DATA=VAPD_20132018_v2  nodupkey  OUT=VAPD_20132018_v2_hospcheck; 
BY  patienticn unique_hosp_count_id;
RUN;

PROC SORT DATA=VAPD_20132018_v2  nodupkey  OUT=pat_dayscheck; 
BY patienticn datevalue;
RUN;

%delete_ds(dslist =VAPD_20132018_v2_hospcheck);
%delete_ds(dslist =pat_dayscheck);

/*******************************************************************************/
/*create day 0s */
/*select day 1 of each hospitalization, so SpecialtyTransferDateTime is earliest for day 0*/
/*this step is different from the original code*/
DATA day1_only (compress=yes); 
SET VAPD_20132018_v2;
if hospital_day =1; /*equals # of unique hospitalzations*/
RUN;

DATA  day0_revise  (compress=yes);
SET day1_only;
datevalue=(new_admitdate3-1); /*create new datevalue*/
hospital_day=0; /*overwrite hospital_day=1 to 0*/
/*reset some variable values for day 0*/
proccode_mechvent_daily=.;
format datevalue mmddyy10.;
RUN;


/*3312960 + 18347242=21,660,202 pat-fac-days*/
/*method 1: use append to combine the datasets*/
proc append base=VAPD_20132018_v2  data=day0_revise force; /*21,660,202 pat-fac-days*/
run;

PROC SORT DATA=VAPD_20132018_v2; 
BY unique_hosp_count_id datevalue specialtytransferdatetime;
RUN;

/*create Mechanical ventilation indicator (any mechanical vent on day1-day3)*/
DATA mechvent (compress=yes); 
SET VAPD_20132018_v2;
if proccode_mechvent_daily=1 and (0<hospital_day<4) then mechvent_day1_3_hosp_ind=1; else mechvent_day1_3_hosp_ind=0;
if mechvent_day1_3_hosp_ind=1;
keep patienticn unique_hosp_count_id mechvent_day1_3_hosp_ind proccode_mechvent_daily hospital_day;
RUN;

PROC SORT DATA=mechvent  nodupkey; 
BY unique_hosp_count_id mechvent_day1_3_hosp_ind;
RUN;

PROC SQL;
	CREATE TABLE VAPD_20132018_v3  (compress=yes)  AS 
	SELECT A.*, B.mechvent_day1_3_hosp_ind
	FROM  VAPD_20132018_v2   A
	LEFT JOIN mechvent  B ON A.unique_hosp_count_id=B.unique_hosp_count_id;
QUIT;

/*********************************************************************************************************/
/*create ED_admit_daily indicator for day 0 or 1. Merge the indicator back to VAPD_20132017_v3 later. Also
create a ED_admit_hosp indicator for day 0 or 1.*/
/*create a dataset of day 0 or day 1 only and look for EDIS 2013-2018 encounters*/
DATA vapd20132018_day0or1 (compress=yes); 
SET  VAPD_20132018_v3;
if hospital_day in (0,1);
RUN;

/*Add EDIS Timestamp*/
/*Pull in EDIS 2013-2017 dataset from VINCI: happi.EDIS20132017_PATARRV2_SW031320*/
/*Clean EDIS dataset before merging with VAPD 2013-2017*/
PROC SORT DATA=happi.EDIS20132017_PATARRV2_SW031320  nodupkey  OUT=Edis20132017 (compress=yes); 
BY patienticn PatientArrivalDateTime;
RUN;

PROC CONTENTS DATA=Edis20132017  VARNUM;
RUN;

/*EDIS 2018 dataset*/
PROC SORT DATA=happi.EDIS2018_PATARR_SW043020  nodupkey  OUT=Edis2018 (compress=yes ); 
BY patienticn PatientArrivalDateTime;
RUN;

DATA Edis2018  (compress=yes);
SET  Edis2018;
keep EDISLogSID EDISLogIEN Sta3n EnteredDateTime EDISTrackingAreaSID PatientSID
PatientArrivalDateTime PatientDepartureDateTime ArrivalEDISTrackingCodeSID VisitSID PatientVisitReason
DispositionEDISTrackingCodeSID DispositionDateTime DispositionDateTimeTransformSID StatusEDISTrackingCodeSID PatientICN;
RUN;

/*combine 2013-2017 and 2018*/
DATA Edis20132018 (compress=yes); 
SET  Edis20132017 Edis2018;
RUN;

/*create a clean EDIS 2013-2017 for left joining to VAPD*/
DATA Edis20132018_v2   (compress=yes rename=patienticn2=patienticn); 
SET  Edis20132018;
PatientArrivalDate=datepart(PatientArrivalDateTime);
format PatientArrivalDate mmddyy10.;
ED_Admit=1;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

%delete_ds(dslist =Edis20132018);
%delete_ds(dslist =Edis2018);
%delete_ds(dslist =Edis20132017);

/*want the earliest EDIS arrival time per pat-day, sort first then undup by pat-day*/
PROC SORT DATA=Edis20132018_v2; 
BY  patienticn PatientArrivalDate PatientArrivalDateTime;
RUN;

PROC SORT DATA=Edis20132018_v2 nodupkey  out=Edis20132018_v3 (compress=yes); 
BY  patienticn PatientArrivalDate;
RUN;

DATA Edis20132018_v3 (compress=yes);
SET  Edis20132018_v3;
EDIS_daily = 1;
EDIS_hosp =1;
RUN;

/*merge to VAPD 2013-2017 day0or1 dataset*/
PROC SQL;
	CREATE TABLE Edis20132018_v4  (compress=yes)  AS 
	SELECT A.*, B.EDIS_daily, b.EDIS_hosp, b.PatientArrivalDateTime as EDIS_ArrivalDateTime, b.PatientArrivalDate as EDIS_ArrivalDate
	FROM  vapd20132018_day0or1   A
	LEFT JOIN Edis20132018_v3 B ON A.patienticn =B.patienticn and a.datevalue=b.PatientArrivalDate;
QUIT;

/*are there hospitalizations with EDIS timestamps on both day 0 and 1?*/
PROC SQL;
CREATE TABLE sum_EDIScounts  AS 
SELECT *, sum(EDIS_daily) as sum_EDIScounts
FROM Edis20132018_v4
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC FREQ DATA=sum_EDIScounts order=freq; 
TABLE sum_EDIScounts;
RUN;

/*need to get earliest EDIS admit time per hosp*/
DATA Earliest_EDIStime_hosp (compress=yes); 
SET Edis20132018_v4;
if EDIS_daily=1;
RUN;

PROC SORT DATA=Earliest_EDIStime_hosp;
BY unique_hosp_count_id EDIS_ArrivalDateTime;
RUN;

PROC SORT DATA=Earliest_EDIStime_hosp  nodupkey; 
BY unique_hosp_count_id;
RUN;

/*get unique EDIS_daily before merging*/
DATA EDIS_daily_v1 (compress=yes); 
SET Edis20132018_v4;
if EDIS_daily=1;
RUN;

PROC SORT DATA=EDIS_daily_v1  nodupkey; 
BY patienticn EDIS_ArrivalDate;
RUN;

/*merge edis_hosp, Earliest_EDIStime_hosp and EDIS_daily to VAPD 2013-2018*/
PROC SQL;
	CREATE TABLE VAPD_20132018_v4  (compress=yes)  AS 
	SELECT A.*, B.EDIS_daily, c.EDIS_hosp, c.EDIS_ArrivalDateTime as earliest_EDISArrivalTime_hosp
	FROM  VAPD_20132018_v3   A
	LEFT JOIN  EDIS_daily_v1 B ON A.patienticn=B.patienticn and a.datevalue=b.EDIS_ArrivalDate 
    left join Earliest_EDIStime_hosp C on a.unique_hosp_count_id=c.unique_hosp_count_id;
QUIT;

/*** Get earliest specialtytransferdatetime per hosp ***/
PROC SORT DATA=VAPD_20132018_v4  OUT=spectime (compress=yes keep=unique_hosp_count_id specialtytransferdatetime);
BY unique_hosp_count_id specialtytransferdatetime;
RUN;

PROC SORT DATA=spectime  nodupkey; 
BY  unique_hosp_count_id;
RUN;

PROC SQL;
	CREATE TABLE VAPD_20132018_v5 (compress=yes)  AS 
	SELECT A.*, B.specialtytransferdatetime as earliest_specialtytransfer_hosp
	FROM  VAPD_20132018_v4  A
	LEFT JOIN spectime B ON A.unique_hosp_count_id=B.unique_hosp_count_id;
QUIT;

%delete_ds(dslist =VAPD_20132018_V3);
%delete_ds(dslist =VAPD_20132018_V4);

/*need both BCMA pressor and CPRS pressor orders*/
/*pull in CPRS Pressors orders 2013-2017 and 2018, then clean before merging to VAPD*/
/*get CPRS orders for Vasopressors, want the the 72 hr window of ED arrival*/
/*need to clean the data first, exclude some pressors that are not PO or IV routes*/
DATA pressors_CPRStime20132017 (compress=yes rename=patienticn2=patienticn);
SET  meds.cprs_pressors20132017_sw20200318;
CPRS_pressorsStartDate = datepart(CPRS_OrderStartDateTime);
format CPRS_pressorsStartDate  mmddyy10.;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

DATA pressors_CPRStime2018 (compress=yes rename=patienticn2=patienticn); 
SET meds.CPRS_PRESSORS2018_SW20200430 ;
CPRS_pressorsStartDate = datepart(CPRS_OrderStartDateTime);
format CPRS_pressorsStartDate  mmddyy10.;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

PROC CONTENTS DATA=pressors_CPRStime20132017 VARNUM;
RUN;

PROC CONTENTS DATA=pressors_CPRStime2018 VARNUM;
RUN;

DATA pressors_CPRStime (compress=yes);
SET pressors_CPRStime20132017 pressors_CPRStime2018;
RUN;

%delete_ds(dslist =pressors_CPRStime20132017);
%delete_ds(dslist =pressors_CPRStime2018);

PROC SQL;
CREATE TABLE names_only (compress=yes) AS 
SELECT *
FROM pressors_CPRStime
WHERE  OrderableItemName not like '%HEMORRHOID%' ;
QUIT;

DATA names_only2 (compress=yes) ;
SET names_only ;
last_10=substr(OrderableItemName,length(OrderableItemName)-9,10);
RUN;

PROC FREQ DATA= names_only2 order=freq;
TABLE  last_10 /out=CPRSPressors2017_last10Name;
RUN;

DATA missing (compress=yes); 
SET names_only2;
if last_10='';
RUN;

PROC SQL;
CREATE TABLE names_only2b (compress=yes) AS 
SELECT distinct last_10
FROM names_only2
WHERE last_10 like '%SOLN,OPH%';
QUIT;

PROC SQL;
CREATE TABLE names_only2c (compress=yes) AS 
SELECT distinct last_10
FROM names_only2
WHERE last_10 like '%SUPP,RTL%';
QUIT;

PROC SQL;
CREATE TABLE names_only2d (compress=yes) AS 
SELECT distinct last_10, OrderableItemName
FROM names_only2
WHERE OrderableItemName like '%EYE%' or last_10 like '%EYE%';
QUIT;

DATA check (compress=yes); 
SET   names_only2;
if last_10 in ('E SOLN,OPH', '% SOLN,OPH', 'SOLN,INHL', 'SOLN,OPH', 'SOLN,NASAL', '% SUPP,RTL', 'PHRINE TAB', 
'L SOLN,OPH', ') SOLN,OPH', 'E SUPP,RTL', 'H SOLN,OPH', '* SOLN,OPH', 'L SUPP,RTL', 'T SOLN,OPH', 'e SOLN,OPH', 
'OR EYE-AL', 'SUPP,RTL', ') SUPP,RTL', 'N SOLN,OPH', 'S SOLN,OPH', 'NE HCL TAB', 'FEE basis)', 'SUPP,RTL','M OINT,RTL', 'EL GEL,RTL','e SUPP,RTL',
'OR EYE-AL', '  SOLN,OPH','ECTION OPH','NE OPH IRR','  SOLN,OPH','% SOLN,OPH',') SOLN,OPH','* SOLN,OPH','E SOLN,OPH','H SOLN,OPH','L SOLN,OPH',
'N SOLN,OPH','S SOLN,OPH','T SOLN,OPH','e SOLN,OPH','  SUPP,RTL','% SUPP,RTL',') SUPP,RTL','E SUPP,RTL','L SUPP,RTL','e SUPP,RTL', '2.5% 1 GTT');
RUN;

/*Hallie adjudicated above list and decided to drop total of 32947 obs.*/
DATA names_only3 (compress=yes); 
SET names_only2 ;
if last_10 in ('E SOLN,OPH', '% SOLN,OPH', 'SOLN,INHL', 'SOLN,OPH', 'SOLN,NASAL', '% SUPP,RTL', 'PHRINE TAB', 'INHL - RTX','SOLN,INHL',
'L SOLN,OPH', ') SOLN,OPH', 'E SUPP,RTL', 'H SOLN,OPH', '* SOLN,OPH', 'L SUPP,RTL', 'T SOLN,OPH', 'e SOLN,OPH', 'F SOLN,OPH', 'SOLN,INHL',
'OR EYE-AL', 'SUPP,RTL', ') SUPP,RTL', 'N SOLN,OPH', 'S SOLN,OPH', 'NE HCL TAB', 'FEE basis)', 'SUPP,RTL','M OINT,RTL', 'EL GEL,RTL','e SUPP,RTL',
'OR EYE-AL', '  SOLN,OPH','ECTION OPH','NE OPH IRR','  SOLN,OPH','% SOLN,OPH',') SOLN,OPH','* SOLN,OPH','E SOLN,OPH','H SOLN,OPH','L SOLN,OPH',
'N SOLN,OPH','S SOLN,OPH','T SOLN,OPH','e SOLN,OPH','  SUPP,RTL','% SUPP,RTL',') SUPP,RTL','E SUPP,RTL','L SUPP,RTL','e SUPP,RTL','2.5% 1 GTT') then delete;
RUN;

PROC FREQ DATA=names_only3  order=freq;
TABLE  last_10 OrderableItemName;
RUN;

PROC SORT DATA=names_only3;
BY patienticn CPRS_OrderStartDateTime CPRS_pressorsStartDate;
RUN;

PROC SORT DATA=names_only3  nodupkey  OUT=pressors_CPRStime_v2 (compress=yes); 
BY  patienticn CPRS_OrderStartDateTime;
RUN;


/*Fix earliest_Pressors72hrStartTime to include BOTH CPRS AND BCMA time. Get all times for CPRS pressor AND BCMA pressor combined than calulate the
72 hr window from ED arrival.*/
/*CPRS pressors 2013-2018,n=480820*/
DATA CPRS_pressors_v1 (compress=yes rename=CPRS_pressorsStartDate=pressordate rename=CPRS_OrderStartDateTime=pressordatetime); 
retain  patienticn CPRS_pressorsStartDate  CPRS_OrderStartDateTime pressors_ind;
SET pressors_CPRStime_v2;
pressors_ind=1;
keep patienticn CPRS_pressorsStartDate  CPRS_OrderStartDateTime pressors_ind;
RUN;

/*BCMA pressors 2013-2017, n=172896*/
DATA BCMA_pressors (compress=yes rename=ActionDate=pressordate rename=ActionDateTime=pressordatetime);
retain patienticn ActionDate  ActionDateTime pressors_ind;
SET happi.PRES_EARLIEST20132018_20200428;
year=year(ActionDate);
pressors_ind=1;
keep patienticn ActionDate  ActionDateTime pressors_ind;
RUN;

/*combine CPRS and BCMA*/
DATA pressor_all (compress=yes);
SET  CPRS_pressors_v1 BCMA_pressors;
RUN;

%delete_ds(dslist =CPRS_pressors_v1);
%delete_ds(dslist =BCMA_pressors);

PROC SORT DATA=pressor_all ;
BY  patienticn pressordate pressordatetime;
RUN;

/*create sub dataset of revise_v3*/
DATA revise_v3_cohort (compress=yes); 
SET VAPD_20132018_v5;
keep patienticn datevalue edis_daily earliest_edisarrivaltime_hosp unique_hosp_count_id;
RUN;

/*merge with VAPD to get the 72 hour window from ED arrival*/
/*for each patient, merge in the pressors, one to many merge*/
PROC SQL;
	CREATE TABLE pressors_20132018  (compress=yes)  AS 
	SELECT A.*, B.pressorDateTime, b.pressorDate
	FROM  revise_v3_cohort  A
	LEFT JOIN pressor_all  B ON A.patienticn=B.patienticn;
QUIT;

/*creat if pressors are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA pressors_20132018_test (compress=yes);
SET  pressors_20132018;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,pressorDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then keep=1; /*keep the vitals within the 72 hours window*/
RUN;

DATA pressors_20132018_V2 (compress=yes); 
SET  pressors_20132018_test;
if keep=1;
RUN;

/*each ED arrival can have multiple pressor orders within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=pressors_20132018_V2;
BY unique_hosp_count_id pressorDateTime;
RUN;

/*get the earliest CPRS Pressors order per hospitalization within that 72 hour window of ED arrival*/
PROC SORT DATA=pressors_20132018_V2  nodupkey  OUT=pressors_20132018_V3 (compress=yes); 
BY  unique_hosp_count_id;
RUN;

/*merge earilest CPRS pressors order within the 72 hour window back to VAPD*/
PROC SQL;
	CREATE TABLE VAPD_20132018_v6  (compress=yes)  AS 
	SELECT A.*, B.pressorDateTime as earliest_Pressors72hrStartTime
	FROM  VAPD_20132018_v5  A
	LEFT JOIN  pressors_20132018_V3 B
	ON A.patienticn =B.patienticn and A.unique_hosp_count_id =B.unique_hosp_count_id;
QUIT;

%delete_ds(dslist =VAPD_20132018_v5);
%delete_ds(dslist =pressors_20132018_test);
%delete_ds(dslist =pressors_20132018_V2);

/*create a dataset with only view fields*/
DATA cohort (compress=yes); 
SET VAPD_20132018_v6;
keep patienticn unique_hosp_count_id datevalue earliest_specialtytransfer_hosp earliest_EDISArrivalTime_hosp new_admitdate3 new_dischargedate3;  
RUN;
/*this cohort can also be in unique hosp-level since each hosp have an discharge date and earliest ED admittime*/

/********/
PROC SORT DATA=cohort  nodupkey  OUT=cohort_hosp (compress=yes); 
BY  unique_hosp_count_id earliest_EDISArrivalTime_hosp;
RUN;
/********/

/*add the 72 hr labs and vitals*/;
/*******************************************************************************************************/
/*the labs merged dataset is huge, make sure to only keep the need fields and delete datasets as it goes*/

/*creatinine, run data 2013-2018, but don't want to change all the names for 2013-2017*/
DATA creat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET labs.CREAT_2018HAPPI_20200429 labs.creat_20162017happi_02112020 labs.CREAT_20122013HAPPI_03272020  labs.CREAT_20142015HAPPI_02112020;
RUN;

PROC SQL;
CREATE TABLE   creat_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM creat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  cohort_hosp);
QUIT;

%delete_ds(dslist =creat_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_creat2017  (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as creat_value
	FROM   cohort  A
	LEFT JOIN  creat_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
/*(-180days & -90days thru hospital discharge) for labs */
DATA creat_180day (compress=yes)
     creat_90day (compress=yes) 
     creat_fromED_72hr_keep (compress=yes) 
     creat_hosp (compress=yes); 
SET labs_creat2017;
datediff_days=intck('day',LabSpecimenDate,new_dischargedate3); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if  new_admitdate3 <= LabSpecimenDate <= new_dischargedate3 then hosp_keep=1;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if lab_180day=1 then output creat_180day;
if lab_90day=1 then output creat_90day;
if hosp_keep=1 then output creat_hosp;
if fromED_72hr_keep=1 then output creat_fromED_72hr_keep;
RUN;

%delete_ds(dslist =labs_creat2017);

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=creat_180day; 
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=creat_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=creat_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

proc sort data=creat_hosp;
by unique_hosp_count_id LabChemSpecimenDateTime;
run;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.creat20132018_fromED_72hr (compress=yes)  AS  
SELECT *, min(creat_value) as lo_creat_72hrED, max(creat_value) as hi_creat_72hrED
FROM creat_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.creat20132018_fromED_72hr  nodupkey; 
BY  unique_hosp_count_id lo_creat_72hrED hi_creat_72hrED;
RUN;

DATA labs.creat20132018_fromED_72hr  (compress=yes);
SET  labs.creat20132018_fromED_72hr ;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.creat20132018_180day (compress=yes)  AS   
SELECT *, min(creat_value) as lo_creat_180day, max(creat_value) as hi_creat_180day
FROM creat_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.creat20132018_180day   nodupkey; 
BY  unique_hosp_count_id lo_creat_180day hi_creat_180day;
RUN;

DATA labs.creat20132018_180day  (compress=yes);
SET  labs.creat20132018_180day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.creat20132018_90day (compress=yes)  AS  
SELECT *, min(creat_value) as lo_creat_90day, max(creat_value) as hi_creat_90day
FROM creat_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.creat20132018_90day   nodupkey; 
BY  unique_hosp_count_id lo_creat_90day hi_creat_90day;
RUN;

DATA labs.creat20132018_90day  (compress=yes);
SET  labs.creat20132018_90day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value hour_diff fromED_72hr_keep;
RUN;

/*get creat hospitalizaton hi and low values*/
PROC SQL;
CREATE TABLE labs.creat20132018_hosp (compress=yes)  AS   
SELECT *, min(creat_value) as lo_creat_hosp, max(creat_value) as hi_creat_hosp
FROM creat_hosp
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.creat20132018_hosp nodupkey; 
BY  unique_hosp_count_id lo_creat_hosp hi_creat_hosp;
RUN;

DATA labs.creat20132018_hosp (compress=yes);
SET  labs.creat20132018_hosp;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value hour_diff fromED_72hr_keep;
RUN;

/*delete datasets and run other labs*/
%delete_ds(dslist =creat_fromed_72hr_keep); 
%delete_ds(dslist =creat_180day);
%delete_ds(dslist =creat_90day);
%delete_ds(dslist =creat_hosp);
%delete_ds(dslist =creat_20132017happi_v1);



/**************************************************************/
/*platelet*/
DATA plat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*43153015*/ /*combine all years of labs data*/
SET labs.PLAT_2018HAPPI_20200429 labs.plat_20162017happi_02112020 labs.PLAT_20122013HAPPI_03272020  labs.PLAT_20142015HAPPI_02112020;
RUN;

PROC SQL;
CREATE TABLE  plat_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM plat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  cohort_hosp);
QUIT;

%delete_ds(dslist =plat_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_plat2017  (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as plat_value
	FROM   cohort  A
	LEFT JOIN  plat_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*plat if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
/*(-180days & -90days thru hospital discharge) for labs */
DATA plat_180day (compress=yes) 
     plat_90day (compress=yes) 
     plat_fromED_72hr_keep (compress=yes) 
     plat_hosp (compress=yes); 
SET labs_plat2017;
datediff_days=intck('day',LabSpecimenDate,new_dischargedate3); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if  new_admitdate3 <= LabSpecimenDate <= new_dischargedate3 then hosp_keep=1;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if lab_180day=1 then output plat_180day;
if lab_90day=1 then output plat_90day;
if hosp_keep=1 then output plat_hosp;
if fromED_72hr_keep=1 then output plat_fromED_72hr_keep;
RUN;

%delete_ds(dslist =labs_plat2017);

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=plat_180day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=plat_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=plat_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

proc sort data=plat_hosp;
by unique_hosp_count_id LabChemSpecimenDateTime;
run;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.plat20132018_fromED_72hr (compress=yes)  AS  
SELECT *, min(plat_value) as lo_plat_72hrED, max(plat_value) as hi_plat_72hrED
FROM plat_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.plat20132018_fromED_72hr  nodupkey;
BY  unique_hosp_count_id lo_plat_72hrED hi_plat_72hrED;
RUN;

DATA labs.plat20132018_fromED_72hr  (compress=yes);
SET  labs.plat20132018_fromED_72hr ;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.plat20132018_180day (compress=yes)  AS  
SELECT *, min(plat_value) as lo_plat_180day, max(plat_value) as hi_plat_180day
FROM plat_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.plat20132018_180day nodupkey; 
BY  unique_hosp_count_id lo_plat_180day hi_plat_180day;
RUN;

DATA labs.plat20132018_180day (compress=yes);
SET  labs.plat20132018_180day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.plat20132018_90day (compress=yes)  AS   
SELECT *, min(plat_value) as lo_plat_90day, max(plat_value) as hi_plat_90day
FROM plat_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.plat20132018_90day nodupkey; 
BY  unique_hosp_count_id lo_plat_90day hi_plat_90day;
RUN;

DATA labs.plat20132018_90day (compress=yes);
SET  labs.plat20132018_90day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value hour_diff fromED_72hr_keep;
RUN;

/*get plat hospitalizaton hi and low values*/
PROC SQL;
CREATE TABLE labs.plat20132018_hosp (compress=yes) AS   
SELECT *, min(plat_value) as lo_plat_hosp, max(plat_value) as hi_plat_hosp
FROM plat_hosp
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.plat20132018_hosp nodupkey; 
BY  unique_hosp_count_id lo_plat_hosp hi_plat_hosp;
RUN;

DATA labs.plat20132018_hosp (compress=yes);
SET  labs.plat20132018_hosp;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value hour_diff fromED_72hr_keep;
RUN;

/*delete datasets and run other labs*/
%delete_ds(dslist =plat_fromed_72hr_keep); 
%delete_ds(dslist =plat_180day);
%delete_ds(dslist =plat_90day);
%delete_ds(dslist =plat_hosp);
%delete_ds(dslist =plat_20132017happi_v1);


/*************************************************************/
/*bilirubin*/
DATA bili_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET labs.BILI_2018HAPPI_20200429 labs.BILI_20142017HAPPI_02112020 labs.BILI_20122013HAPPI_03272020;
RUN;

PROC SQL;
CREATE TABLE bili_20132017happi_v1 (COMPRESS=YES) AS 
SELECT A.* FROM bili_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort_hosp);
QUIT;

%delete_ds(dslist =bili_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_bili2017 (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as bili_value
	FROM   cohort  A
	LEFT JOIN  bili_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*bili if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
/*(-180days & -90days thru hospital discharge) for labs */
DATA bili_180day (compress=yes) 
     bili_90day (compress=yes) 
     bili_fromED_72hr_keep (compress=yes) 
     bili_hosp (compress=yes); 
SET labs_bili2017;
datediff_days=intck('day',LabSpecimenDate,new_dischargedate3); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if  new_admitdate3 <= LabSpecimenDate <= new_dischargedate3 then hosp_keep=1;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if lab_180day=1 then output bili_180day;
if lab_90day=1 then output bili_90day;
if hosp_keep=1 then output bili_hosp;
if fromED_72hr_keep=1 then output bili_fromED_72hr_keep;
RUN;

%delete_ds(dslist =labs_bili2017);

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=bili_180day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=bili_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=bili_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

proc sort data=bili_hosp;
by unique_hosp_count_id LabChemSpecimenDateTime;
run;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.bili20132018_fromED_72hr (compress=yes) AS    
SELECT *, min(bili_value) as lo_bili_72hrED, max(bili_value) as hi_bili_72hrED
FROM bili_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.bili20132018_fromED_72hr  nodupkey; 
BY  unique_hosp_count_id lo_bili_72hrED hi_bili_72hrED;
RUN;

DATA labs.bili20132018_fromED_72hr  (compress=yes);
SET  labs.bili20132018_fromED_72hr;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.bili20132018_180day (compress=yes) AS  
SELECT *, min(bili_value) as lo_bili_180day, max(bili_value) as hi_bili_180day
FROM bili_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.bili20132018_180day nodupkey; 
BY  unique_hosp_count_id lo_bili_180day hi_bili_180day;
RUN;

DATA labs.bili20132018_180day (compress=yes);
SET  labs.bili20132018_180day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value hour_diff fromED_72hr_keep;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE labs.bili20132018_90day (compress=yes)  AS  
SELECT *, min(bili_value) as lo_bili_90day, max(bili_value) as hi_bili_90day
FROM bili_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.bili20132018_90day  nodupkey; 
BY  unique_hosp_count_id lo_bili_90day hi_bili_90day;
RUN;

DATA labs.bili20132018_90day (compress=yes);
SET  labs.bili20132018_90day;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value hour_diff fromED_72hr_keep;
RUN;

/*get bili hospitalizaton hi and low values*/
PROC SQL;
CREATE TABLE labs.bili20132018_hosp (compress=yes)  AS   
SELECT *, min(bili_value) as lo_bili_hosp, max(bili_value) as hi_bili_hosp
FROM bili_hosp
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.bili20132018_hosp   nodupkey; 
BY  unique_hosp_count_id lo_bili_hosp hi_bili_hosp;
RUN;

DATA labs.bili20132018_hosp  (compress=yes);
SET  labs.bili20132018_hosp;
drop datediff_days hosp_keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value hour_diff fromED_72hr_keep;
RUN;

/*delete datasets and run other labs*/
%delete_ds(dslist =bili_fromed_72hr_keep); 
%delete_ds(dslist =bili_180day);
%delete_ds(dslist =bili_90day);
%delete_ds(dslist =bili_hosp);
%delete_ds(dslist =bili_20132017happi_v1);


/*************************************************************************/
/*Lactate*/
DATA lactate_20132017happi (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET  labs.lactate_20122013happi_02112020 labs.lactate_20142017happi_02112020 labs.LACTATE_2018HAPPI_20200429;
RUN;

PROC SQL;
CREATE TABLE lactate_20132017happi_v1 (COMPRESS=YES) AS 
SELECT A.* FROM lactate_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort_hosp);
QUIT;

%delete_ds(dslist=lactate_20132017happi);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_lactate20132017 (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as lactate_value
	FROM   cohort_hosp  A
	LEFT JOIN  lactate_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA lactate_fromED_72hr_keep (compress=yes); 
SET labs_lactate20132017;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if fromED_72hr_keep=1;
RUN;

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=lactate_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.lactate20132018_fromED_72hr (compress=yes) AS   
SELECT *, min(lactate_value) as lo_lactate_72hrED, max(lactate_value) as hi_lactate_72hrED
FROM lactate_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.lactate20132018_fromED_72hr  nodupkey; 
BY  unique_hosp_count_id lo_lactate_72hrED hi_lactate_72hrED;
RUN;

DATA labs.lactate20132018_fromED_72hr  (compress=yes);
SET  labs.lactate20132018_fromED_72hr;
drop datediff_days lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate lactate_value hour_diff fromED_72hr_keep;
RUN;

/*delete datasets and run other labs*/
%delete_ds(dslist =labs_lactate20132017);
%delete_ds(dslist =lactate_fromed_72hr_keep); 
%delete_ds(dslist =lactate_20132017happi_v1);


/**********************************************************/
/*WBC*/
DATA wbc_20132017happi (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*combine all years of labs data*/
SET  labs.wbc_2014happi_02112020  labs.wbc_2015happi_02112020  labs.wbc_2016happi_02112020  labs.wbc_2017happi_02112020  labs.wbc_20122013happi_03272020
labs.WBC_2018HAPPI_20200429;
RUN;

PROC SQL;
CREATE TABLE wbc_20132017happi_v1 (COMPRESS=YES) AS 
SELECT A.* FROM wbc_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort_hosp);
QUIT;

%delete_ds(dslist=wbc_20132017happi);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_wbc20132017 (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as wbc_value
	FROM  cohort_hosp  A
	LEFT JOIN  wbc_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs & vitals are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA wbc_fromED_72hr_keep (compress=yes); 
SET labs_wbc20132017;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,LabChemSpecimenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then fromED_72hr_keep=1;  /*keep the labs within the 72 hours window*/
if fromED_72hr_keep=1;
RUN;

/*each ED arrival can have multiple labs within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=wbc_fromED_72hr_keep;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

/*get the hi/lo lab values per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE labs.wbc20132018_fromED_72hr (compress=yes)  AS    
SELECT *, min(wbc_value) as lo_wbc_72hrED, max(wbc_value) as hi_wbc_72hrED
FROM wbc_fromED_72hr_keep
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=labs.wbc20132018_fromED_72hr  nodupkey; 
BY  unique_hosp_count_id lo_wbc_72hrED hi_wbc_72hrED;
RUN;

DATA labs.wbc20132018_fromED_72hr  (compress=yes);
SET  labs.wbc20132018_fromED_72hr ;
drop datediff_days lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate wbc_value hour_diff fromED_72hr_keep;
RUN;

/*delete datasets and run other labs*/
%delete_ds(dslist =labs_wbc20132017);
%delete_ds(dslist =wbc_fromed_72hr_keep); 
%delete_ds(dslist = wbc_20132017happi_v1);
%delete_ds(dslist = wbc_20132017happi);

/**************************************************************************************/
/*RESPIRATION*/
DATA resp_20132017happi (compress=yes); 
SET  vitals.RESPIRATION2016_HAPPI_20200212  vitals.RESPIRATION2017_HAPPI_20200212 vitals.RESPIRATION2013_HAPPI_20200326
vitals.RESPIRATION2014_HAPPI_20200212  vitals.RESPIRATION2015_HAPPI_20200212 vitals.RESP2018_HAPPI_20200429;
RUN;

PROC SQL;
CREATE TABLE resp_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM resp_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort_hosp);
QUIT;

%delete_ds(dslist=resp_20132017happi);

/*for each patient, merge in the vitals, one to many merge*/
PROC SQL;
	CREATE TABLE vitals_resp20132017 (compress=yes)  AS 
	SELECT A.*, B.VitalSignTakenDateTime, b.vital_date, b.VitalResultNumeric as resp_value
	FROM  cohort_hosp  A
	LEFT JOIN resp_20132017happi_v1  B	ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA vitals_resp20132017 (compress=yes); 
SET vitals_resp20132017;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,VitalSignTakenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then keep=1; /*keep the vitals within the 72 hours window*/
if keep=1;
RUN;

/*each ED arrival can have multiple vitals within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=vitals_resp20132017;
BY unique_hosp_count_id VitalSignTakenDateTime;
RUN;

/*get the worst (lowest) vitals value per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE vitals.Resp20132018_FROMED_72HR (compress=yes)  AS 
SELECT *, min(resp_value) as lo_resp_72hrED, max(resp_value) as hi_resp_72hrED
FROM vitals_resp20132017
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=vitals.Resp20132018_FROMED_72HR nodupkey;
BY  unique_hosp_count_id  lo_resp_72hrED  hi_resp_72hrED;
RUN;


/***********************************************************************************************/
/*Temperature*/
DATA temp_20132017happi (compress=yes); 
SET  vitals.TEMP2016_HAPPI_20200212  vitals.TEMP2017_HAPPI_20200212 vitals.TEMP2013_HAPPI_20200326
vitals.TEMP2014_HAPPI_20200212  vitals.TEMP2015_HAPPI_20200212  vitals.TEMP2018_HAPPI_20200429;
RUN;

PROC SQL;
CREATE TABLE temp_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM temp_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM  cohort_hosp);
QUIT;

%delete_ds(dslist=temp_20132017happi);

/*for each patient, merge in the vitals, one to many merge*/
PROC SQL;
	CREATE TABLE vitals_temp20132017  (compress=yes)  AS 
	SELECT A.*, B.VitalSignTakenDateTime, b.vital_date, b.VitalResultNumeric as temp_value
	FROM  cohort_hosp  A
	LEFT JOIN temp_20132017happi_v1 B ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA vitals_temp20132017 (compress=yes); 
SET vitals_temp20132017;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,VitalSignTakenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then keep=1; /*keep the vitals within the 72 hours window*/
if keep=1;
RUN;

/*each ED arrival can have multiple vitals within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=vitals_temp20132017;
BY unique_hosp_count_id VitalSignTakenDateTime;
RUN;

/*get the worst (lowest) vitals value per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE vitals.Temp20132018_FROMED_72HR (compress=yes) AS  
SELECT *, min(temp_value) as lo_temp_72hrED, max(temp_value) as hi_temp_72hrED
FROM vitals_temp20132017
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=vitals.Temp20132018_FROMED_72HR nodupkey; 
BY  unique_hosp_count_id  lo_temp_72hrED  hi_temp_72hrED;
RUN;

/******************************************************************************************/
/*Pulse*/
DATA pulse_20132017happi (compress=yes); 
SET  vitals.PULSE2016_HAPPI_20200212  vitals.PULSE2017_HAPPI_20200212 vitals.PULSE2013_HAPPI_20200326
vitals.PULSE2014_HAPPI_20200212  vitals.PULSE2015_HAPPI_20200212 vitals.PULSE2018_HAPPI_20200429;
RUN;

PROC SQL;
CREATE TABLE pulse_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM pulse_20132017happi AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort_hosp);
QUIT;

%delete_ds(dslist=pulse_20132017happi);

/*for each patient, merge in the vitals, one to many merge*/
PROC SQL;
	CREATE TABLE vitals_pulse20132017  (compress=yes)  AS 
	SELECT A.*, B.VitalSignTakenDateTime, b.vital_date, b.VitalResultNumeric as pulse_value
	FROM  cohort_hosp  A
	LEFT JOIN pulse_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*creat if labs are within 24 hrs prior to ED arrival and 48 hours after ED arrival variables*/
DATA vitals_pulse20132017 (compress=yes); 
SET vitals_pulse20132017;
hour_diff = INTCK('hour',earliest_EDISArrivalTime_hosp,VitalSignTakenDateTime); /*positive value=after ED, negative value=prior ED*/
if  -24=<hour_diff<=48 then keep=1; /*keep the vitals within the 72 hours window*/
if keep=1;
RUN;

/*each ED arrival can have multiple vitals within that 72 hour window, sort the data first by admit (unique_hosp_count_id)*/
PROC SORT DATA=vitals_pulse20132017;
BY unique_hosp_count_id VitalSignTakenDateTime;
RUN;

/*get the worst (lowest) vitals value per hospitalization within that 72 hour window of ED arrival*/
PROC SQL;
CREATE TABLE vitals.Pulse20132018_FROMED_72HR (compress=yes)  AS  
SELECT *, min(pulse_value) as lo_pulse_72hrED, max(pulse_value) as hi_pulse_72hrED
FROM vitals_pulse20132017
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=vitals.Pulse20132018_FROMED_72HR nodupkey; 
BY  unique_hosp_count_id  lo_pulse_72hrED  hi_pulse_72hrED;
RUN;


/****/
/*merge all the labs & vitals back to VAPD*/
PROC SQL;
	CREATE TABLE  VAPD_20132018_v6b (compress=yes)  AS 
	SELECT A.*, B.lo_pulse_72hrED, b.hi_pulse_72hrED,  c.lo_temp_72hrED, c.hi_temp_72hrED, 
           d.lo_resp_72hrED, d.hi_resp_72hrED,  e.lo_wbc_72hrED, e.hi_wbc_72hrED
	FROM  VAPD_20132018_v6   A
	LEFT JOIN vitals.Pulse20132018_FROMED_72HR  B ON A.patienticn =B.patienticn and A.unique_hosp_count_id =B.unique_hosp_count_id
    LEFT JOIN vitals.TEMP20132018_FROMED_72HR  c ON A.patienticn =c.patienticn and A.unique_hosp_count_id =c.unique_hosp_count_id
    LEFT JOIN vitals.RESP20132018_FROMED_72HR  d ON A.patienticn =d.patienticn and A.unique_hosp_count_id =d.unique_hosp_count_id
    LEFT JOIN labs.WBC20132018_FROMED_72HR  e ON A.patienticn =e.patienticn and A.unique_hosp_count_id =e.unique_hosp_count_id;
QUIT;

PROC SQL;
	CREATE TABLE  VAPD_20132018_v6c (compress=yes)  AS
	SELECT A.*, B.lo_bili_180day, b.hi_bili_180day, c.lo_bili_72hrED, c.hi_bili_72hrED,x.lo_bili_90day, x.hi_bili_90day,q.lo_bili_hosp, q.hi_bili_hosp,
	            d.lo_creat_180day, d.hi_creat_180day, e.lo_creat_72hrED, e.hi_creat_72hrED,m.lo_creat_90day,m.hi_creat_90day,n.lo_creat_hosp,n.hi_creat_hosp,
                f.lo_plat_180day, f.hi_plat_180day, g.lo_plat_72hrED, g.hi_plat_72hrED,s.lo_plat_90day,s.hi_plat_90day,t.lo_plat_hosp,t.hi_plat_hosp,
                h.lo_lactate_72hrED, h.hi_lactate_72hrED
	FROM  VAPD_20132018_v6b   A
	LEFT JOIN labs.BILI20132018_180DAY B ON A.patienticn =B.patienticn and A.unique_hosp_count_id =B.unique_hosp_count_id
    LEFT JOIN labs.BILI20132018_FROMED_72HR  c ON A.patienticn =c.patienticn and A.unique_hosp_count_id =c.unique_hosp_count_id
LEFT JOIN labs.BILI20132018_90DAY  x ON A.patienticn =x.patienticn and A.unique_hosp_count_id =x.unique_hosp_count_id
LEFT JOIN labs.BILI20132018_HOSP  q ON A.patienticn =q.patienticn and A.unique_hosp_count_id =q.unique_hosp_count_id
    LEFT JOIN labs.CREAT20132018_180DAY  d ON A.patienticn =d.patienticn and A.unique_hosp_count_id =d.unique_hosp_count_id
    LEFT JOIN labs.CREAT20132018_FROMED_72HR  e ON A.patienticn =e.patienticn and A.unique_hosp_count_id =e.unique_hosp_count_id
LEFT JOIN labs.CREAT20132018_90DAY  m ON A.patienticn =m.patienticn and A.unique_hosp_count_id =m.unique_hosp_count_id
LEFT JOIN labs.CREAT20132018_HOSP  n ON A.patienticn =n.patienticn and A.unique_hosp_count_id =n.unique_hosp_count_id
    LEFT JOIN labs.PLAT20132018_180DAY  f ON A.patienticn =f.patienticn and A.unique_hosp_count_id =f.unique_hosp_count_id
    LEFT JOIN labs.PLAT20132018_FROMED_72HR  g ON A.patienticn =g.patienticn and A.unique_hosp_count_id =g.unique_hosp_count_id
LEFT JOIN labs.PLAT20132018_90DAY  s ON A.patienticn =s.patienticn and A.unique_hosp_count_id =s.unique_hosp_count_id
LEFT JOIN labs.PLAT20132018_HOSP  t ON A.patienticn =t.patienticn and A.unique_hosp_count_id =t.unique_hosp_count_id
    LEFT JOIN labs.LACTATE20132018_FROMED_72HR  h ON A.patienticn =h.patienticn and A.unique_hosp_count_id =h.unique_hosp_count_id;
QUIT;


/*add clean_bcmaabx_daily indicator using the "BCMA earliest ABX data cleaned" datasets*/
DATA BCMA_daily (compress=yes); 
SET happi.abx_earliest20142017_20200311 happi.ABX_EARLIEST2013_20200330 happi.ABX_EARLIEST2018_20200505;
RUN;

PROC SORT DATA=BCMA_daily  nodupkey; /*0 dups*/
BY   patienticn ActionDate earliest_ABXactionDateTime;
RUN;

PROC SQL;
	CREATE TABLE  VAPD_20132018_v7  (compress=yes)  AS 
	SELECT A.*, B.earliest_ABXactionDateTime as clean_bcmaabx_daily
	FROM VAPD_20132018_v6c  A
	LEFT JOIN BCMA_daily  B ON A.patienticn=B.patienticn and a.datevalue=b.ActionDate;
QUIT;


/************************************************************************************************************************/
/*Add CPRS ABX daily timestamp to replace earliest_cprs_abx_order*/
DATA cprs_abxorders_20132018 (compress=yes); 
SET  meds.CPRS_ABXORDERS_2018_SMS20200504    sarah.cprs_abxorders_sms20200327 /*2013-2017 dataset*/;
CPRS_ABX_daily=1;
RUN;

/*sort and undup to get 'earliest_cprs_abx_dailytime’ */
PROC SORT DATA=cprs_abxorders_20132018;
BY patienticn cprs_abxorderstartdate cprs_orderstartdatetime;
RUN;

PROC SORT DATA=cprs_abxorders_20132018 nodupkey out=cprs_abxorders_v2 (compress=yes); 
BY  patienticn cprs_abxorderstartdate;
RUN;

PROC SQL;
	CREATE TABLE  revise_v2 (compress=yes)  AS 
	SELECT A.*, B.cprs_orderstartdatetime as earliest_cprs_abx_dailytime
	FROM   VAPD_20132018_v7   A
	LEFT JOIN cprs_abxorders_v2  B ON A.patienticn=B.patienticn and a.datevalue=b.cprs_abxorderstartdate;
QUIT;

/*if earliest_cprs_abx_dailytime > earliest_specialtytransfer_hosp then recode as missing*/
DATA revise_v2b  (compress=yes); 
SET revise_v2 ;
if earliest_cprs_abx_dailytime > earliest_specialtytransfer_hosp then recodetomissing=.;
else recodetomissing=earliest_cprs_abx_dailytime;
format recodetomissing datetime16.;
RUN;

PROC SQL;
CREATE TABLE revise_v2c AS  
SELECT *, min(recodetomissing) as earliest_cprs_abx_order
FROM revise_v2b
GROUP BY unique_hosp_count_id;
QUIT;

DATA revise_v2c (compress=yes);
SET revise_v2c;
format earliest_cprs_abx_order datetime16.;
RUN;

PROC SORT DATA= revise_v2c;
BY  patienticn unique_hosp_count_id datevalue;
RUN;

PROC SORT DATA=revise_v2c  nodupkey  OUT=test (compress=yes); 
BY  unique_hosp_count_id  earliest_cprs_abx_order;
RUN;

proc sql;
SELECT count(distinct unique_hosp_count_id) 
FROM revise_v2c;
quit;

/*****************************************************************************************************************/
/*Define SIRS+: SIRS is defined as 2 or more:
•	Temp > 100.4 or < 96.8,
•	Heart Rate > 90 ,
•	Respiratory Rate > 20 ,
•	White Blood Cells > 12K or < 4K */
/*revised with the 72 hour window, this "day" values doesn't matter anymore. 24hrs before ED presentation to 48hrs after ED presentation.*/
DATA ED_only_SIRS (compress=yes);
SET  revise_v2c;
if EDIS_hosp=1;
if (lo_temp_72hrED < 96.8 and lo_temp_72hrED NE .)  or (hi_temp_72hrED > 100.4 and hi_temp_72hrED NE . )  
     then SIRS_temp=1; else SIRS_temp=0;
if (hi_pulse_72hrED > 90 and hi_pulse_72hrED NE . ) 
     then SIRS_pulse=1; else SIRS_pulse=0;
if (hi_resp_72hrED > 20 and hi_resp_72hrED NE . ) 
     then SIRS_rr=1; else SIRS_rr=0;
if (hi_wbc_72hrED > 12 and hi_wbc_72hrED NE . ) or (lo_wbc_72hrED < 4 and lo_wbc_72hrED NE .) 
     then SIRS_wbc=1; else SIRS_wbc=0;
RUN;

/*Count Sum of SIRs indicators*/
PROC SQL;
CREATE TABLE ED_only_SIRS_V1 (compress=yes)  AS 
SELECT *, sum(SIRS_temp,SIRS_pulse,SIRS_rr, SIRS_wbc) as sum_SIRS_count
FROM ED_only_SIRS;
QUIT;

/* SIRS is defined as 2 or more*/
DATA ED_only_SIRS_V2 (compress=yes);
SET ED_only_SIRS_V1;
if sum_SIRS_count >=2 then newSIRS_hosp_ind=1; else newSIRS_hosp_ind=0;
keep unique_hosp_count_id SIRS_temp SIRS_pulse SIRS_rr SIRS_wbc sum_SIRS_count admityear newSIRS_hosp_ind;
RUN;

PROC SORT DATA=ED_only_SIRS_V2  nodupkey; /*get hosp-level SIRS counts*/ 
BY unique_hosp_count_id SIRS_temp SIRS_pulse SIRS_rr SIRS_wbc sum_SIRS_count;
RUN;

PROC FREQ DATA=ED_only_SIRS_V2;
TABLE admityear;
RUN;

/*Interim data analysis #1 */
PROC FREQ DATA=ED_only_SIRS_V2 ;
where newSIRS_hosp_ind=1;
TABLE  newSIRS_hosp_ind*admityear  sum_SIRS_count*admityear
SIRS_temp*admityear SIRS_pulse*admityear SIRS_rr*admityear SIRS_wbc*admityear ;
RUN;

/*merge the SIRS indicators back to VAPD*/
PROC SQL;
	CREATE TABLE VAPD_20132018_v8  (compress=yes)  AS 
	SELECT A.*, B.newSIRS_hosp_ind, b.SIRS_temp, b.SIRS_pulse, b.SIRS_rr, b.SIRS_wbc, b.sum_SIRS_count
	FROM  revise_v2c A
	LEFT JOIN  ED_only_SIRS_V2 B ON A.unique_hosp_count_id =B.unique_hosp_count_id ;
QUIT;

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

%lowcase(VAPD_20132018_v8) /*change name of dataset here*/

PROC CONTENTS DATA=VAPD_20132018_v8  VARNUM;
RUN;

/*make perm dataset to pass on to Sarah and Daniel*/
DATA happi.HAPPIVAPD20132018_20200515 (compress=yes); 
SET VAPD_20132018_v8;
RUN;

PROC SORT DATA=happi.HAPPIVAPD20132018_20200515  nodupkey dupout=dups OUT=test; 
BY patienticn datevalue;
RUN;

PROC SORT DATA=happi.HAPPIVAPD20132018_20200515  nodupkey  OUT=sta6a (compress=yes keep=sta6a); /*151 sta6a*/
BY  sta6a;
RUN;



/**********************************************************************************************************************/
/*create a new VAPD 2013-2018 day 0 and 1 only dataset with wide EDIS times for Sarah*/
/*5/5/20: create a separate EDIS dataset with all arrival timestamps for Sarah to look at*/
/*Add EDIS Timestamp*/
/*Pull in EDIS 2013-2017 dataset from VINCI: happi.EDIS20132017_PATARRV2_SW031320*/
/*Clean EDIS dataset before merging with VAPD 2013-2017*/
PROC SORT DATA=happi.EDIS20132017_PATARRV2_SW031320  nodupkey  OUT=Edis20132017_v2 (compress=yes); 
BY patienticn PatientArrivalDateTime;
RUN;

/*EDIS 2018 dataset*/
PROC SORT DATA=happi.EDIS2018_PATARR_SW043020  nodupkey  OUT=Edis2018_v2 (compress=yes ); 
BY patienticn PatientArrivalDateTime;
RUN;

/*combine 2013-2017 and 2018*/
DATA Edis20132018_v2 (compress=yes); 
SET  Edis20132017_v2 Edis2018_v2;
RUN;

/*create a clean EDIS 2013-2017 for left joining to VAPD*/
DATA Edis20132018_v2 (compress=yes rename=patienticn2=patienticn); 
SET  Edis20132018_v2;
PatientArrivalDate=datepart(PatientArrivalDateTime);
format PatientArrivalDate mmddyy10.;
ED_Admit=1;
patienticn2 = input(patienticn, 10.);
drop patienticn;
RUN;

/*want the earliest EDIS arrival time per pat-day, sort first then undup by pat-day*/
PROC SORT DATA=Edis20132018_v2; 
BY  patienticn PatientArrivalDate PatientArrivalDateTime;
RUN;

PROC SORT DATA=Edis20132018_v2  nodupkey  OUT=Edis20132018_v2b; 
BY  patienticn PatientArrivalDate PatientArrivalDateTime;
RUN;

/*transpose EDIS data from long to wide by patient-day*/
DATA EDIS_long (compress=yes);
SET Edis20132018_v2b ;
keep patienticn PatientArrivalDate PatientArrivalDateTime;
RUN;

PROC TRANSPOSE DATA=EDIS_long OUT=EDIS_wide (DROP=_NAME_ _LABEL_)  PREFIX= EDISTime_ ; 
BY patienticn PatientArrivalDate;
VAR PatientArrivalDateTime;
RUN;

/*create day 0 or 1 cohort only*/
DATA day0and1_only (compress=yes); 
SET happi.HAPPIVAPD20132018_20200515;
if hospital_day in (1,0);
keep patienticn admityear unique_hosp_count_id datevalue new_admitdate3 new_dischargedate3 sta6a hospital_day;
RUN;

PROC SQL;
	CREATE TABLE  EDIS_cohort_HAPPI (compress=yes)  AS 
	SELECT A.*, B.EDISTime_1,B.EDISTime_2,B.EDISTime_3,B.EDISTime_4,B.EDISTime_5,B.EDISTime_6,B.EDISTime_7,B.EDISTime_8,B.EDISTime_9
	FROM  day0and1_only   A
	LEFT JOIN EDIS_wide  B
	ON A.patienticn =B.patienticn and a.datevalue=b.PatientArrivalDate;
QUIT;

PROC FREQ DATA=EDIS_cohort_HAPPI  order=freq;
TABLE EDISTime_7; /*none*/
RUN;

DATA happi.VAPD1318_ALLEDISTIME_SW20200515 (compress=yes);
SET EDIS_cohort_HAPPI  ;
drop EDISTime_7 -EDISTime_9;
RUN;



/***********************************************************************************************************************************************/
/*Create a dataset of 30 Elixhauser Comorbid indicators for VA TO VA Transfer VAPDs 2013-2018 and keep patienticn and datevalue for merging with 
final HAPPI Dataset.*/

/*get 2013 VA to VA transfer Elixhauser comorbid indicators*/
DATA vapd2013 (compress=yes) ;
retain  patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
SET final.VATOVA2013SEPSIS_20191224 ;
keep patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
RUN;

PROC SORT DATA=vapd2013 nodupkey; 
BY  patienticn datevalue;
RUN;

/*get 2014-2017 VA to VA transfer Elixhauser comorbid indicators*/
DATA vapd20142017 (compress=yes);
retain  patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
SET final.VATOVA20142017SEPSIS_20191224;
keep patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
RUN;

PROC SORT DATA=vapd20142017 nodupkey; 
BY  patienticn datevalue;
RUN;


/*get 2018 VA to VA transfer Elixhauser comorbid indicators. Try to get comorbid on patient-day level, so using 2018 single-site VAPD is fine too.*/
/*select only diag codes to run elixhauser code*/
DATA copy2018 (compress=yes); 
SET  temp.VAPDSinglesite2018_20200526;
keep patienticn datevalue  icd10code1-icd10code25  sta6a specialtytransferdate  specialtydischargedate;
RUN;

/*remove duplicate specialty stay */
PROC SORT DATA=copy2018 nodupkey 
OUT=copy2018_v2 (keep=patienticn sta6a specialtytransferdate  specialtydischargedate  icd10code1-icd10code25); 
BY  patienticn sta6a specialtytransferdate  specialtydischargedate ;
RUN;

/*calculate elixhauser comorbid*/
/*take out decimals in icd10 diag codes*/
DATA copy2018_v2 (compress=yes); 
SET  copy2018_v2;
icd10code1=compress(icd10code1,'.'); icd10code2=compress(icd10code2,'.'); icd10code3=compress(icd10code3,'.');icd10code4=compress(icd10code4,'.');icd10code5=compress(icd10code5,'.');
icd10code6=compress(icd10code6,'.');icd10code7=compress(icd10code7,'.');icd10code8=compress(icd10code8,'.');icd10code9=compress(icd10code9,'.');icd10code10=compress(icd10code10,'.');
icd10code11=compress(icd10code11,'.'); icd10code12=compress(icd10code12,'.'); icd10code13=compress(icd10code13,'.');icd10code14=compress(icd10code14,'.');icd10code15=compress(icd10code15,'.');
icd10code16=compress(icd10code16,'.');icd10code17=compress(icd10code17,'.');icd10code18=compress(icd10code18,'.');icd10code19=compress(icd10code19,'.');icd10code20=compress(icd10code20,'.');
icd10code21=compress(icd10code21,'.'); icd10code22=compress(icd10code22,'.'); icd10code23=compress(icd10code23,'.');icd10code24=compress(icd10code24,'.');icd10code25=compress(icd10code25,'.');
RUN;

/*transpose icd10 into long form*/
proc transpose data=copy2018_v2  out=icd10_long1 (rename=COL1=Diagnosiscode drop=_NAME_); 
var icd10code1-icd10code25;
by patienticn sta6a specialtytransferdate  specialtydischargedate;
run;

/*group  icd10 Elixhauser Comorbidities*/
data all_diag_V2 (compress=yes); 
set icd10_long1;

/* Congestive Heart Failure */
         if  Diagnosiscode IN: ('39891','40201','40211','40291','40401','40403','40411','40413','40491',
                 '40493','4254','4255','4257','4258','4259','428','I099','I110','I130','I132','I255','I420','I425','I426','I427','I428',
                          'I429','I43','I50','P290')  then ELX_GRP_1 = 1;
            LABEL ELX_GRP_1='Congestive Heart Failure';

         /* Cardiac Arrhythmia */
         if  Diagnosiscode IN: ('4260','42613','4267','4269','42610','42612','4270','4271','4272','4273',
                 '4274','4276','4278','4279','7850','99601','99604','V450','V533','I441','I442','I443','I456','I459','I47','I48','I49','R000','R001',
                          'R008','T821','Z450','Z950') then ELX_GRP_2 = 1;
            LABEL ELX_GRP_2='Cardiac Arrhythmia';

         /* Valvular Disease */
         if  Diagnosiscode IN: ('0932','394','395','396','397','424','7463','7464','7465','7466','V422','V433','A520','I05','I06','I07','I08','I091','I098','I34','I35','I36','I37',
                          'I38','I39','Q230','Q231','Q232','Q233','Z952','Z953','Z954')
                  then ELX_GRP_3 = 1;
            LABEL ELX_GRP_3='Valvular Disease';

         /* Pulmonary Circulation Disorders */
         if  Diagnosiscode IN: ('4150','4151','416','4170','4178','4179','I26','I27','I280','I288','I289') then ELX_GRP_4 = 1;
            LABEL ELX_GRP_4='Pulmonary Circulation Disorders';

         /* Peripheral Vascular Disorders */
         if  Diagnosiscode IN: ('0930','4373','440','441','4431','4432','4438','4439','4471','5571','5579','V434','I70','I71','I731','I738','I739','I771','I790','I792','K551','K558',
                          'K559','Z958','Z959')
                  then ELX_GRP_5 = 1;
            LABEL ELX_GRP_5='Peripheral Vascular Disorders';

         /* Hypertension Uncomplicated */
         if  Diagnosiscode IN: ('401', 'I10') then ELX_GRP_6 = 1;
            LABEL ELX_GRP_6='Hypertension Uncomplicated';

         /* Hypertension Complicated */
         if  Diagnosiscode IN: ('402','403','404','405','I11','I12','I13','I15') then ELX_GRP_7 = 1;
            LABEL ELX_GRP_7='Hypertension Complicated';

         /* Paralysis */
         if  Diagnosiscode IN: ('3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449','G041','G114','G801','G802','G81','G82','G830','G831','G832','G833',
                          'G834','G839')  then ELX_GRP_8 = 1;
           LABEL ELX_GRP_8='Paralysis';

         /* Other Neurological Disorders */
         if  Diagnosiscode IN: ('3319','3320','3321','3334','3335','33392','334','335','3362','340','341',
                  '345','3481','3483','7803','7843','G10','G11','G12','G13','G20','G21','G22','G254','G255','G312','G318',
                          'G319','G32','G35','G36','G37','G40','G41','G931','G934','R470','R56') then ELX_GRP_9 = 1;
           LABEL ELX_GRP_9='Other Neurological Disorders';

         /* Chronic Pulmonary Disease */
         if  Diagnosiscode IN: ('4168','4169','490','491','492','493','494','495','496','500','501','502',
                  '503','504','505','5064','5081','5088','I278','I279','J40','J41','J42','J43','J44','J45','J46','J47','J60','J61',
                          'J62','J63','J64','J65','J66','J67','J684','J701','J703') then ELX_GRP_10 = 1;
           LABEL ELX_GRP_10='Chronic Pulmonary Disease';

         /* Diabetes Uncomplicated */
         if  Diagnosiscode IN: ('2500','2501','2502','2503','E100','E101','E109','E110','E111','E119','E120','E121','E129','E130',
                          'E131','E139','E140','E141','E149') then ELX_GRP_11 = 1;
           LABEL ELX_GRP_11='Diabetes Uncomplicated';

         /* Diabetes Complicated */
         if  Diagnosiscode IN: ('2504','2505','2506','2507','2508','2509','E102','E103','E104','E105','E106','E107','E108','E112','E113','E114','E115',
                          'E116','E117','E118','E122','E123','E124','E125','E126','E127','E128','E132',
                          'E133','E134','E135','E136','E137','E138','E142','E143','E144','E145','E146',
                          'E147','E148') then ELX_GRP_12 = 1;
           LABEL ELX_GRP_12='Diabetes Complicated';

         /* Hypothyroidism */
         if  Diagnosiscode IN: ('2409','243','244','2461','2468','E00','E01','E02','E03','E890') then ELX_GRP_13 = 1;
           LABEL ELX_GRP_13='Hypothyroidism';

         /* Renal Failure */
         if  Diagnosiscode IN: ('40301','40311','40391','40402','40403','40412','40413','40492','40493',
                  '585','586','5880','V420','V451','V56','I120','I131','N18','N19','N250','Z490','Z491','Z492','Z940','Z992') then ELX_GRP_14 = 1;
           LABEL ELX_GRP_14='Renal Failure';

         /* Liver Disease */
         if  Diagnosiscode IN: ('07022','07023','07032','07033','07044','07054','0706','0709','4560','4561',
                  '4562','570','571','5722','5723','5724','5728','5733','5734','5738','5739','V427',
			'B18','I85','I864','I982','K70','K711','K713','K714','K715','K717','K72','K73',
                          'K74','K760','K762','K763','K764','K765','K766','K767','K768','K769','Z944')
                  then ELX_GRP_15 = 1;
           LABEL ELX_GRP_15='Liver Disease';

         /* Peptic Ulcer Disease excluding bleeding */
         if  Diagnosiscode IN: ('5317','5319','5327','5329','5337','5339','5347','5349','K257','K259','K267','K269','K277','K279','K287','K289')
                  then ELX_GRP_16 = 1;
           LABEL ELX_GRP_16='Peptic Ulcer Disease excluding bleeding';

         /* AIDS/HIV */
         if  Diagnosiscode IN: ('042','043','044','B20','B21','B22','B24')  then ELX_GRP_17 = 1;
           LABEL ELX_GRP_17='AIDS/HIV';

         /* Lymphoma */
         if  Diagnosiscode IN: ('200','201','202','2030','2386','C81','C82','C83','C84','C85','C88','C96','C900','C902') then ELX_GRP_18 = 1;
           LABEL ELX_GRP_18='Lymphoma';

         /* Metastatic Cancer */
         if  Diagnosiscode IN: ('196','197','198','199','C77','C78','C79','C80') then ELX_GRP_19 = 1;
           LABEL ELX_GRP_19='Metastatic Cancer';

         /* Solid Tumor without Metastasis */
         if  Diagnosiscode IN: ('140','141','142','143','144','145','146','147','148','149','150','151','152',
                  '153','154','155','156','157','158','159','160','161','162','163','164','165','166','167',
                  '168','169','170','171','172','174','175','176','177','178','179','180','181','182','183',
                  '184','185','186','187','188','189','190','191','192','193','194','195',
				'C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13',
                          'C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30',
                          'C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C45','C46','C47','C48',
                          'C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63',
                          'C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C97')
                  then ELX_GRP_20 = 1;
           LABEL ELX_GRP_20='Solid Tumor without Metastasis';

         /* Rheumatoid Arthritis/collagen */
         if  Diagnosiscode IN: ('446','7010','7100','7101','7102','7103','7104','7108','7109','7112','714',
                  '7193','720','725','7285','72889','72930','L940','L941','L943','M05','M06','M08','M120','M123','M30','M310','M311','M312','M313',
                          'M32','M33','M34','M35','M45','M461','M468','M469') then ELX_GRP_21 = 1;
           LABEL ELX_GRP_21='Rheumatoid Arthritis/collagen';

         /* Coagulopathy */
         if  Diagnosiscode IN: ('286','2871','2873','2874','2875','D65','D66','D67','D68','D691','D693','D694','D695','D696')  then ELX_GRP_22 = 1;
           LABEL ELX_GRP_22='Coagulopathy';

         /* Obesity */
         if  Diagnosiscode IN: ('2780','E66') then ELX_GRP_23 = 1;
           LABEL ELX_GRP_23='Obesity';

         /* Weight Loss */
         if  Diagnosiscode IN: ('260','261','262','263','7832','7994','E40','E41','E42','E43','E44','E45','E46','R634','R64') then ELX_GRP_24 = 1;
           LABEL ELX_GRP_24='Weight Loss';

         /* Fluid and Electrolyte Disorders */
         if  Diagnosiscode IN: ('2536','276','E222','E86','E87') then ELX_GRP_25 = 1;
           LABEL ELX_GRP_25='Fluid and Electrolyte Disorders';

         /* Blood Loss Anemia */
         if  Diagnosiscode IN: ('2800','D500') then ELX_GRP_26 = 1;
           LABEL ELX_GRP_26='Blood Loss Anemia';

         /* Deficiency Anemia */
         if  Diagnosiscode IN: ('2801','2808','2809','281','D508','D509','D51','D52','D53') then ELX_GRP_27 = 1;
           LABEL ELX_GRP_27='Deficiency Anemia';

         /* Alcohol Abuse */
         if  Diagnosiscode IN: ('2652','2911','2912','2913','2915','2918','2919','3030','3039','3050',
                  '3575','4255','5353','5710','5711','5712','5713','980','V113','F10','E52','G621','I426',
			'K292','K700','K703','K709','T51','Z502','Z714','Z721') then ELX_GRP_28 = 1;
           LABEL ELX_GRP_28='Alcohol Abuse';

         /* Drug Abuse */
         if  Diagnosiscode IN: ('292','304','3052','3053','3054','3055','3056','3057','3058','3059','V6542',
			'F11','F12','F13','F14','F15','F16','F18','F19','Z715','Z722')
                  then ELX_GRP_29 = 1;	
           LABEL ELX_GRP_29='Drug Abuse';

         /* Psychoses */
         if  Diagnosiscode IN: ('2938','295','29604','29614','29644','29654','297','298',
			'F20','F22','F23','F24','F25','F28','F29','F302','F312','F315')
                  then ELX_GRP_30 = 1;
           LABEL ELX_GRP_30='Psychoses';

         /* Depression */
         if  Diagnosiscode IN: ('2962','2963','2965','3004','309','311','F204','F313','F314','F315','F32','F33','F341','F412','F432') then ELX_GRP_31 = 1;
           LABEL ELX_GRP_31='Depression';
run;

data ELX_GRP_1 ELX_GRP_2 ELX_GRP_3 ELX_GRP_4 ELX_GRP_5 ELX_GRP_6 ELX_GRP_7 ELX_GRP_8 ELX_GRP_9 ELX_GRP_10 
ELX_GRP_11 ELX_GRP_12 ELX_GRP_13 ELX_GRP_14 ELX_GRP_15 ELX_GRP_16 ELX_GRP_17 ELX_GRP_18 ELX_GRP_19 ELX_GRP_20
ELX_GRP_21 ELX_GRP_22 ELX_GRP_23 ELX_GRP_24 ELX_GRP_25 ELX_GRP_26 ELX_GRP_27 ELX_GRP_28 ELX_GRP_29 ELX_GRP_30  ELX_GRP_31;
set ALL_DIAG_V2; 
if ELX_GRP_1 = 1 then output ELX_GRP_1;
if ELX_GRP_2 = 1 then output ELX_GRP_2;
if ELX_GRP_3 = 1 then output ELX_GRP_3;
if ELX_GRP_4 = 1 then output ELX_GRP_4;
if ELX_GRP_5 = 1 then output ELX_GRP_5;
if ELX_GRP_6 = 1 then output ELX_GRP_6;
if ELX_GRP_7 = 1 then output ELX_GRP_7;
if ELX_GRP_8 = 1 then output ELX_GRP_8;
if ELX_GRP_9 = 1 then output ELX_GRP_9;
if ELX_GRP_10 = 1 then output ELX_GRP_10;
if ELX_GRP_11 = 1 then output ELX_GRP_11;
if ELX_GRP_12 = 1 then output ELX_GRP_12;
if ELX_GRP_13 = 1 then output ELX_GRP_13;
if ELX_GRP_14 = 1 then output ELX_GRP_14;
if ELX_GRP_15 = 1 then output ELX_GRP_15;
if ELX_GRP_16 = 1 then output ELX_GRP_16;
if ELX_GRP_17 = 1 then output ELX_GRP_17;
if ELX_GRP_18 = 1 then output ELX_GRP_18;
if ELX_GRP_19 = 1 then output ELX_GRP_19;
if ELX_GRP_20 = 1 then output ELX_GRP_20;
if ELX_GRP_21 = 1 then output ELX_GRP_21;
if ELX_GRP_22 = 1 then output ELX_GRP_22;
if ELX_GRP_23 = 1 then output ELX_GRP_23;
if ELX_GRP_24 = 1 then output ELX_GRP_24;
if ELX_GRP_25 = 1 then output ELX_GRP_25;
if ELX_GRP_26 = 1 then output ELX_GRP_26;
if ELX_GRP_27 = 1 then output ELX_GRP_27;
if ELX_GRP_28 = 1 then output ELX_GRP_28;
if ELX_GRP_29 = 1 then output ELX_GRP_29;
if ELX_GRP_30 = 1 then output ELX_GRP_30;
if ELX_GRP_31 = 1 then output ELX_GRP_31;
run;

/*remove duplicates*/
%macro nums (num);
PROC SORT DATA=ELX_GRP_&num.  nodupkey ;
BY patienticn sta6a specialtytransferdate  specialtydischargedate ELX_GRP_&num.;
RUN;
%mend nums;
%nums(1);
%nums(2);
%nums(3);
%nums(4);
%nums(5);
%nums(6);
%nums(7);
%nums(8);
%nums(9);
%nums(10);
%nums(11);
%nums(12);
%nums(13);
%nums(14);
%nums(15);
%nums(16);
%nums(17);
%nums(18);
%nums(19);
%nums(20);
%nums(21);
%nums(22);
%nums(23);
%nums(24);
%nums(25);
%nums(26);
%nums(27);
%nums(28);
%nums(29);
%nums(30);
%nums(31);

PROC SQL;
	CREATE TABLE  Elixhauser_V1 (compress=yes) AS  
	SELECT A.*, B.ELX_GRP_1, c.ELX_GRP_2, d.ELX_GRP_3, e.ELX_GRP_4, f.ELX_GRP_5, g.ELX_GRP_6
	FROM  copy2018  A
	LEFT JOIN  elx_grp_1 B ON A.Patienticn =B.Patienticn and a.Sta6a=b.Sta6a and a.specialtytransferdate=b.specialtytransferdate and a.specialtydischargedate=b.specialtydischargedate
    LEFT JOIN  elx_grp_2 c ON A.Patienticn =c.Patienticn and a.Sta6a=c.Sta6a and a.specialtytransferdate=c.specialtytransferdate and a.specialtydischargedate=c.specialtydischargedate
	LEFT JOIN  elx_grp_3 d ON A.Patienticn =d.Patienticn and a.Sta6a=d.Sta6a and a.specialtytransferdate=d.specialtytransferdate and a.specialtydischargedate=d.specialtydischargedate
	LEFT JOIN  elx_grp_4 e ON A.Patienticn =e.Patienticn and a.Sta6a=e.Sta6a and a.specialtytransferdate=e.specialtytransferdate and a.specialtydischargedate=e.specialtydischargedate
	LEFT JOIN  elx_grp_5 f ON A.Patienticn =f.Patienticn and a.Sta6a=f.Sta6a and a.specialtytransferdate=f.specialtytransferdate and a.specialtydischargedate=f.specialtydischargedate
	LEFT JOIN  elx_grp_6 g ON A.Patienticn =g.Patienticn and a.Sta6a=g.Sta6a and a.specialtytransferdate=g.specialtytransferdate and a.specialtydischargedate=g.specialtydischargedate;
QUIT;

PROC SQL;
	CREATE TABLE  Elixhauser_V2 (compress=yes) AS 
	SELECT A.*, B.ELX_GRP_7, c.ELX_GRP_8, d.ELX_GRP_9, e.ELX_GRP_10, f.ELX_GRP_11, g.ELX_GRP_12, h.ELX_GRP_13, i.ELX_GRP_14, j.ELX_GRP_15
	FROM  Elixhauser_V1 A
	LEFT JOIN  elx_grp_7 B ON A.Patienticn =B.Patienticn and a.Sta6a=b.Sta6a and a.specialtytransferdate=b.specialtytransferdate and a.specialtydischargedate=b.specialtydischargedate
    LEFT JOIN  elx_grp_8 c ON A.Patienticn =c.Patienticn and a.Sta6a=c.Sta6a and a.specialtytransferdate=c.specialtytransferdate and a.specialtydischargedate=c.specialtydischargedate
	LEFT JOIN  elx_grp_9 d ON A.Patienticn =d.Patienticn and a.Sta6a=d.Sta6a and a.specialtytransferdate=d.specialtytransferdate and a.specialtydischargedate=d.specialtydischargedate
	LEFT JOIN  elx_grp_10 e ON A.Patienticn =e.Patienticn and a.Sta6a=e.Sta6a and a.specialtytransferdate=e.specialtytransferdate and a.specialtydischargedate=e.specialtydischargedate
	LEFT JOIN  elx_grp_11 f ON A.Patienticn =f.Patienticn and a.Sta6a=f.Sta6a and a.specialtytransferdate=f.specialtytransferdate and a.specialtydischargedate=f.specialtydischargedate
	LEFT JOIN  elx_grp_12 g ON A.Patienticn =g.Patienticn and a.Sta6a=g.Sta6a and a.specialtytransferdate=g.specialtytransferdate and a.specialtydischargedate=g.specialtydischargedate
	LEFT JOIN  elx_grp_13 h ON A.Patienticn =h.Patienticn and a.Sta6a=h.Sta6a and a.specialtytransferdate=h.specialtytransferdate and a.specialtydischargedate=h.specialtydischargedate
	LEFT JOIN  elx_grp_14 i ON A.Patienticn =i.Patienticn and a.Sta6a=i.Sta6a and a.specialtytransferdate=i.specialtytransferdate and a.specialtydischargedate=i.specialtydischargedate
	LEFT JOIN  elx_grp_15 j ON A.Patienticn =j.Patienticn and a.Sta6a=j.Sta6a and a.specialtytransferdate=j.specialtytransferdate and a.specialtydischargedate=j.specialtydischargedate;
QUIT;

PROC SQL;
	CREATE TABLE  Elixhauser_V3 (compress=yes) AS 
	SELECT A.*, B.ELX_GRP_16, c.ELX_GRP_17, d.ELX_GRP_18, e.ELX_GRP_19, f.ELX_GRP_20, g.ELX_GRP_21, h.ELX_GRP_22, i.ELX_GRP_23, j.ELX_GRP_24, k.ELX_GRP_25
	FROM  Elixhauser_V2 A
	LEFT JOIN  elx_grp_16 B ON A.Patienticn =B.Patienticn and a.Sta6a=b.Sta6a and a.specialtytransferdate=b.specialtytransferdate and a.specialtydischargedate=b.specialtydischargedate
    LEFT JOIN  elx_grp_17 c ON A.Patienticn =c.Patienticn and a.Sta6a=c.Sta6a and a.specialtytransferdate=c.specialtytransferdate and a.specialtydischargedate=c.specialtydischargedate
	LEFT JOIN  elx_grp_18 d ON A.Patienticn =d.Patienticn and a.Sta6a=d.Sta6a and a.specialtytransferdate=d.specialtytransferdate and a.specialtydischargedate=d.specialtydischargedate
	LEFT JOIN  elx_grp_19 e ON A.Patienticn =e.Patienticn and a.Sta6a=e.Sta6a and a.specialtytransferdate=e.specialtytransferdate and a.specialtydischargedate=e.specialtydischargedate
	LEFT JOIN  elx_grp_20 f ON A.Patienticn =f.Patienticn and a.Sta6a=f.Sta6a and a.specialtytransferdate=f.specialtytransferdate and a.specialtydischargedate=f.specialtydischargedate
	LEFT JOIN  elx_grp_21 g ON A.Patienticn =g.Patienticn and a.Sta6a=g.Sta6a and a.specialtytransferdate=g.specialtytransferdate and a.specialtydischargedate=g.specialtydischargedate
	LEFT JOIN  elx_grp_22 h ON A.Patienticn =h.Patienticn and a.Sta6a=h.Sta6a and a.specialtytransferdate=h.specialtytransferdate and a.specialtydischargedate=h.specialtydischargedate
	LEFT JOIN  elx_grp_23 i ON A.Patienticn =i.Patienticn and a.Sta6a=i.Sta6a and a.specialtytransferdate=i.specialtytransferdate and a.specialtydischargedate=i.specialtydischargedate
	LEFT JOIN  elx_grp_24 j ON A.Patienticn =j.Patienticn and a.Sta6a=j.Sta6a and a.specialtytransferdate=j.specialtytransferdate and a.specialtydischargedate=j.specialtydischargedate
	LEFT JOIN  elx_grp_25 k ON A.Patienticn =k.Patienticn and a.Sta6a=k.Sta6a and a.specialtytransferdate=k.specialtytransferdate and a.specialtydischargedate=k.specialtydischargedate;
QUIT;

PROC SQL;
	CREATE TABLE Elixhauser_2015_2017 (compress=yes) AS 
	SELECT A.*, B.ELX_GRP_26, c.ELX_GRP_27, d.ELX_GRP_28, e.ELX_GRP_29, f.ELX_GRP_30, g.ELX_GRP_31
	FROM   Elixhauser_V3 A
	LEFT JOIN  elx_grp_26 B ON A.Patienticn =B.Patienticn and a.Sta6a=b.Sta6a and a.specialtytransferdate=b.specialtytransferdate and a.specialtydischargedate=b.specialtydischargedate
    LEFT JOIN  elx_grp_27 c ON A.Patienticn =c.Patienticn and a.Sta6a=c.Sta6a and a.specialtytransferdate=c.specialtytransferdate and a.specialtydischargedate=c.specialtydischargedate
	LEFT JOIN  elx_grp_28 d ON A.Patienticn =d.Patienticn and a.Sta6a=d.Sta6a and a.specialtytransferdate=d.specialtytransferdate and a.specialtydischargedate=d.specialtydischargedate
	LEFT JOIN  elx_grp_29 e ON A.Patienticn =e.Patienticn and a.Sta6a=e.Sta6a and a.specialtytransferdate=e.specialtytransferdate and a.specialtydischargedate=e.specialtydischargedate
	LEFT JOIN  elx_grp_30 f ON A.Patienticn =f.Patienticn and a.Sta6a=f.Sta6a and a.specialtytransferdate=f.specialtytransferdate and a.specialtydischargedate=f.specialtydischargedate
	LEFT JOIN  elx_grp_31 g ON A.Patienticn =g.Patienticn and a.Sta6a=g.Sta6a and a.specialtytransferdate=g.specialtytransferdate and a.specialtydischargedate=g.specialtydischargedate;
QUIT;

PROC SQL;
CREATE TABLE Elixhauser_2018 (compress=yes) AS 
SELECT *, sum(ELX_GRP_1, ELX_GRP_2, ELX_GRP_3, ELX_GRP_4, ELX_GRP_5, ELX_GRP_6, ELX_GRP_7 ,
              ELX_GRP_8, ELX_GRP_9, ELX_GRP_10, ELX_GRP_11, ELX_GRP_12, ELX_GRP_13, ELX_GRP_14 ,
              ELX_GRP_15, ELX_GRP_16, ELX_GRP_17, ELX_GRP_18, ELX_GRP_19, ELX_GRP_20, ELX_GRP_21,
              ELX_GRP_22, ELX_GRP_23, ELX_GRP_24, ELX_GRP_25, ELX_GRP_26, ELX_GRP_27, ELX_GRP_28,
              ELX_GRP_29, ELX_GRP_30, ELX_GRP_31) as sum_Elixhauser_count
FROM Elixhauser_2015_2017;
QUIT;

/*rename variables*/
DATA Elixhauser_2018 (compress=yes);
SET Elixhauser_2018;
if elx_grp_1 NE 1 then elx_grp_1 =0; if elx_grp_2 NE 1 then elx_grp_2 =0;
if elx_grp_3 NE 1 then elx_grp_3 =0;if elx_grp_4 NE 1 then elx_grp_4 =0;
if elx_grp_5 NE 1 then elx_grp_5 =0;if elx_grp_6 NE 1 then elx_grp_6 =0;
if elx_grp_7 NE 1 then elx_grp_7 =0;if elx_grp_8 NE 1 then elx_grp_8 =0;
if elx_grp_9 NE 1 then elx_grp_9 =0;if elx_grp_10 NE 1 then elx_grp_10 =0;
if elx_grp_11 NE 1 then elx_grp_11 =0; if elx_grp_12 NE 1 then elx_grp_12 =0;
if elx_grp_13 NE 1 then elx_grp_13 =0;if elx_grp_14 NE 1 then elx_grp_14 =0;
if elx_grp_15 NE 1 then elx_grp_15 =0;if elx_grp_16 NE 1 then elx_grp_16 =0;
if elx_grp_17 NE 1 then elx_grp_17 =0;if elx_grp_18 NE 1 then elx_grp_18 =0;
if elx_grp_19 NE 1 then elx_grp_19 =0;if elx_grp_20 NE 1 then elx_grp_20 =0;
if elx_grp_21 NE 1 then elx_grp_21 =0; if elx_grp_22 NE 1 then elx_grp_22 =0;
if elx_grp_23 NE 1 then elx_grp_23 =0;if elx_grp_24 NE 1 then elx_grp_24 =0;
if elx_grp_25 NE 1 then elx_grp_25 =0;if elx_grp_26 NE 1 then elx_grp_26 =0;
if elx_grp_27 NE 1 then elx_grp_27 =0;if elx_grp_28 NE 1 then elx_grp_28 =0;
if elx_grp_29 NE 1 then elx_grp_29 =0;if elx_grp_30 NE 1 then elx_grp_30 =0;
if elx_grp_31 NE 1 then elx_grp_31 =0;
elixhauser_VanWalraven=sum(7*ELX_GRP_1, -1*ELX_GRP_3, 4*ELX_GRP_4, 2*ELX_GRP_5, 0*ELX_GRP_7, 7*ELX_GRP_8, 6*ELX_GRP_9, 3*ELX_GRP_10, 5*ELX_GRP_14, 11*ELX_GRP_15, 9*ELX_GRP_18,
      12*ELX_GRP_19, 4*ELX_GRP_20, 0*ELX_GRP_21, -4*ELX_GRP_23, 6*ELX_GRP_24, 5*ELX_GRP_25, -2*ELX_GRP_26, -2*ELX_GRP_27, -7*ELX_GRP_29, -3*ELX_GRP_31, 0*ELX_GRP_16,
		0*ELX_GRP_11, 0*ELX_GRP_12, 0*ELX_GRP_17, 5*ELX_GRP_2, 0*ELX_GRP_13, 3*ELX_GRP_22, 0*ELX_GRP_28, 0*ELX_GRP_30);
RUN;

DATA Elixhauser_2018_v2 (compress=yes);
SET Elixhauser_2018;
if  ELX_GRP_6=1 or ELX_GRP_7=1 then htn=1; else htn=0;
rename 
		ELX_GRP_1=chf
		ELX_GRP_2=cardic_arrhym
		ELX_GRP_3=valvular_d2
		ELX_GRP_4=pulm_circ
		ELX_GRP_5=pvd
/*		ELX_GRP_6=htn_uncomp*/
/*		ELX_GRP_7=htn_comp*/
		ELX_GRP_8=paralysis
		ELX_GRP_9=neuro
		ELX_GRP_10=pulm
		ELX_GRP_11=dm_uncomp
		ELX_GRP_12=dm_comp
		ELX_GRP_13=hypothyroid
		ELX_GRP_14=renal
		ELX_GRP_15=liver
		ELX_GRP_16=pud
		ELX_GRP_17=ah
		ELX_GRP_18=lymphoma
		ELX_GRP_19=cancer_met
		ELX_GRP_20=cancer_nonmet
		ELX_GRP_21=ra
		ELX_GRP_22=coag
		ELX_GRP_23=obesity
		ELX_GRP_24=wtloss
		ELX_GRP_25=fen
		ELX_GRP_26=anemia_cbl
		ELX_GRP_27=anemia_def
		ELX_GRP_28=etoh
		ELX_GRP_29=drug
		ELX_GRP_30=psychoses
		ELX_GRP_31=depression;
RUN;

DATA vapd2018 (compress=yes); 
retain  patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
SET Elixhauser_2018_v2;
keep patienticn datevalue sum_elixhauser_count elixhauser_vanwalraven htn chf cardic_arrhym valvular_d2 pulm_circ
pvd paralysis neuro pulm dm_uncomp dm_comp hypothyroid renal liver pud ah lymphoma cancer_met cancer_nonmet ra coag obesity
wtloss fen anemia_cbl anemia_def etoh drug psychoses depression;
run;

PROC SORT DATA=vapd2018 nodupkey; 
BY patienticn datevalue;
RUN;

/*combine 2013-2018*/
DATA vapd_all (compress=yes); 
SET  vapd2013 vapd20142017 vapd2018;
RUN;

/*should undup by patient-day again */
PROC SORT DATA=vapd_all nodupkey out=vapd_all2 (compress=yes); 
BY patienticn datevalue;
RUN;

/*happi.HAPPI_DAILY1318_06082020 is dataset Daniel created with only HAPPI hospitalizations, a subset of the 
VAPD 2013-2018 data*/
PROC SQL;
	CREATE TABLE  happi.HAPPIDaily1318Comorbid_20200609 (compress=yes)  AS  
	SELECT A.*, B.*
	FROM  happi.HAPPI_DAILY1318_06082020   A
	LEFT JOIN  vapd_all2  B
	ON A.patienticn =B.patienticn and a.datevalue=b.datevalue ;
QUIT;

PROC SORT DATA=happi.HAPPIDaily1318Comorbid_20200609  nodupkey  OUT=sta6a (compress=yes keep=sta6a); 
BY  sta6a;
RUN;







/***********************************************************************************************************************************/
/***********************************************************************************************************************************/
/*6/30/20: Daniel needs prior 90 and 180 day labs before ED arrival date on Creat, Plat and Bili*/
/*use only HAPPI cohort 2013-2018, get EDIS arrival date back*/
/*merge to happi hosp cohort, get EDIS entry date back*/
PROC SORT DATA=happi.HAPPIVAPD20132018_20200515  nodupkey  
OUT=HAPPIVAPD20132018_20200515 (compress=yes keep=patienticn new_admitdate3 new_dischargedate3 earliest_edisarrivaltime_hosp);
BY patienticn new_admitdate3 new_dischargedate3 earliest_edisarrivaltime_hosp;
RUN;

DATA HAPPI20132018 (compress=yes); 
SET happi.UNIQHAPPICRT_20132018_SW210105;
admityear=year(new_admitdate3);
RUN;

PROC SQL;
	CREATE TABLE  cohort2 (compress=yes)  AS 
	SELECT A.*, B.earliest_edisarrivaltime_hosp
	FROM  HAPPI20132018  A
	LEFT JOIN HAPPIVAPD20132018_20200515  B
	ON A.patienticn =B.patienticn and a.new_admitdate3=b.new_admitdate3 and a.new_dischargedate3=b.new_dischargedate3;
QUIT;

/*Sarah:I believe she said to go back 24 hours prior to ED arrival date, so I was assuming she wanted to use the hour/min time stamp. 
Using your example, if EDIS arrival time was 1/3/18 at 12:30pm, we would want labs prior to 1/2/18 at 12:30pm for 90 and 180 days. 
Since we’re using the HAPPI cohort, everyone should have an EDIS arrival timestamp, which would make the 24 hour, hour-based period a bit easier to calculate.*/

/*create timestamp of 24 hours prior to EDIS arrival datetime*/
DATA cohort2b (compress=yes);
SET cohort2;
new_datetime=intnx("HOUR",earliest_edisarrivaltime_hosp, -24);
format new_datetime DATETIME20.;
new_date=datepart(new_datetime);
format new_date mmddyy10.;
RUN;

/*the labs merged dataset is huge, make sure to only keep the need fields and delete datasets as it goes*/


/*creatinine, run data 2013-2018, but don't want to change all the names for 2013-2017*/
DATA creat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*combine all years of labs data*/
SET labs.CREAT_2018HAPPI_20200429 labs.creat_20162017happi_02112020 labs.CREAT_20122013HAPPI_03272020  labs.CREAT_20142015HAPPI_02112020;
RUN;

PROC SQL;
CREATE TABLE   creat_20132017happi_v1  (COMPRESS=YES) AS
SELECT A.* FROM creat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM  cohort2b);
QUIT;

%delete_ds(dslist =creat_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_creat2017  (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as creat_value
	FROM   cohort2b  A
	LEFT JOIN  creat_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

%delete_ds(dslist =creat_20132017happi_v1);

/*if LabChemSpecimenDateTime < new_datetime then keep*/
DATA labs_creat2017b (compress=yes) ;
SET  labs_creat2017;
if LabChemSpecimenDateTime < new_datetime then keep=1; 
if keep=1;
RUN;

/*create 90 days and 180 days prior datasets*/
DATA creat_180day (compress=yes) 
     creat_90day (compress=yes); 
SET labs_creat2017b;
datediff_days=intck('day',LabSpecimenDate,new_date); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if lab_180day=1 then output creat_180day;
if lab_90day=1 then output creat_90day;
RUN;

%delete_ds(dslist =labs_creat2017);
%delete_ds(dslist =labs_creat2017b);

PROC SORT DATA=creat_180day; 
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=creat_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;


/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE creat20132018_180day (compress=yes)  AS   
SELECT *, min(creat_value) as lo_creat_180day, max(creat_value) as hi_creat_180day
FROM creat_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=creat20132018_180day   nodupkey; 
BY  unique_hosp_count_id lo_creat_180day hi_creat_180day;
RUN;

DATA creat20132018_180day  (compress=yes);
SET  creat20132018_180day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value ;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE creat20132018_90day (compress=yes)  AS  
SELECT *, min(creat_value) as lo_creat_90day, max(creat_value) as hi_creat_90day
FROM creat_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=creat20132018_90day   nodupkey; 
BY  unique_hosp_count_id lo_creat_90day hi_creat_90day;
RUN;

DATA creat20132018_90day  (compress=yes);
SET  creat20132018_90day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate creat_value;
RUN;

/*******************************/
/*platelet*/
DATA plat_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue); /*combine all years of labs data*/
SET labs.PLAT_2018HAPPI_20200429 labs.plat_20162017happi_02112020 labs.PLAT_20122013HAPPI_03272020  labs.PLAT_20142015HAPPI_02112020;
RUN;

PROC SQL;
CREATE TABLE   plat_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM plat_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM cohort2b);
QUIT;

%delete_ds(dslist =plat_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_plat2017 (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as plat_value
	FROM  cohort2b A
	LEFT JOIN  plat_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

%delete_ds(dslist =plat_20132017happi_v1);

/*if LabChemSpecimenDateTime < new_datetime then keep*/
DATA labs_plat2017b (compress=yes) ;
SET  labs_plat2017;
if LabChemSpecimenDateTime < new_datetime then keep=1; 
if keep=1;
RUN;

/*CREATE 90 days and 180 days prior datasets*/
DATA plat_180day (compress=yes) 
     plat_90day (compress=yes); 
SET labs_plat2017b;
datediff_days=intck('day',LabSpecimenDate,new_date); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if lab_180day=1 then output plat_180day;
if lab_90day=1 then output plat_90day;
RUN;

%delete_ds(dslist =labs_plat2017);
%delete_ds(dslist =labs_plat2017b);

PROC SORT DATA=plat_180day; 
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=plat_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;


/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE plat20132018_180day (compress=yes)  AS   
SELECT *, min(plat_value) as lo_plat_180day, max(plat_value) as hi_plat_180day
FROM plat_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=plat20132018_180day   nodupkey; 
BY  unique_hosp_count_id lo_plat_180day hi_plat_180day;
RUN;

DATA plat20132018_180day  (compress=yes);
SET  plat20132018_180day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE plat20132018_90day (compress=yes) AS  
SELECT *, min(plat_value) as lo_plat_90day, max(plat_value) as hi_plat_90day
FROM plat_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=plat20132018_90day nodupkey; 
BY  unique_hosp_count_id lo_plat_90day hi_plat_90day;
RUN;

DATA plat20132018_90day (compress=yes);
SET  plat20132018_90day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate plat_value;
RUN;

/****************************************/
/*bilirubin*/
DATA bili_20132017happi_02112020 (compress=yes keep=patienticn LabChemSpecimenDateTime LabSpecimenDate  LabChemResultNumericValue);  /*combine all years of labs data*/
SET labs.BILI_2018HAPPI_20200429 labs.BILI_20142017HAPPI_02112020 labs.BILI_20122013HAPPI_03272020;
RUN;

PROC SQL;
CREATE TABLE bili_20132017happi_v1  (COMPRESS=YES) AS 
SELECT A.* FROM bili_20132017happi_02112020 AS A
WHERE A.patienticn IN (SELECT patienticn FROM COHORT2B);
QUIT;

%delete_ds(dslist =bili_20132017happi_02112020);

/*for each patient, merge in the labs, one to many merge*/
PROC SQL;
	CREATE TABLE labs_bili2017 (compress=yes)  AS 
	SELECT A.*, B.LabChemSpecimenDateTime, b.LabSpecimenDate, b.LabChemResultNumericValue as bili_value
	FROM COHORT2B  A
	LEFT JOIN  bili_20132017happi_v1  B ON A.patienticn=B.patienticn;
QUIT;

/*if LabChemSpecimenDateTime < new_datetime then keep*/
DATA labs_bili2017b (compress=yes);
SET  labs_bili2017;
if LabChemSpecimenDateTime < new_datetime then keep=1; 
if keep=1;
RUN;

%delete_ds(dslist =bili_20132017happi_v1);

/*CREATE 90 days and 180 days prior datasets*/
DATA bili_180day (compress=yes)
     bili_90day (compress=yes); 
SET labs_bili2017b;
datediff_days=intck('day',LabSpecimenDate,new_date); 
if  0<= datediff_days <=180 then lab_180day=1; 
if  0<= datediff_days <=90 then lab_90day=1;
if lab_180day=1 then output bili_180day;
if lab_90day=1 then output bili_90day;
RUN;

%delete_ds(dslist =labs_bili2017);
%delete_ds(dslist =labs_bili2017b);

PROC SORT DATA=bili_180day; 
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

PROC SORT DATA=bili_90day;
BY unique_hosp_count_id LabChemSpecimenDateTime;
RUN;

/*get the hi/lo lab values per hospitalization within 180 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE bili20132018_180day (compress=yes)  AS   
SELECT *, min(bili_value) as lo_bili_180day, max(bili_value) as hi_bili_180day
FROM bili_180day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=bili20132018_180day nodupkey; 
BY  unique_hosp_count_id lo_bili_180day hi_bili_180day;
RUN;

DATA bili20132018_180day (compress=yes);
SET  bili20132018_180day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value ;
RUN;

/*get the hi/lo lab values per hospitalization within 90 days of hospitalization discharge*/
PROC SQL;
CREATE TABLE bili20132018_90day (compress=yes)  AS  
SELECT *, min(bili_value) as lo_bili_90day, max(bili_value) as hi_bili_90day
FROM bili_90day
GROUP BY unique_hosp_count_id
ORDER BY unique_hosp_count_id;
QUIT;

PROC SORT DATA=bili20132018_90day nodupkey; 
BY  unique_hosp_count_id lo_bili_90day hi_bili_90day;
RUN;

DATA bili20132018_90day (compress=yes);
SET  bili20132018_90day;
drop datediff_days keep lab_90day lab_180day datevalue LabChemSpecimenDateTime LabSpecimenDate bili_value;
RUN;

PROC SQL;
	CREATE TABLE  happi.labs_3waysepsis_tab2_20200702  (compress=yes)  AS /*1,101,239 HAPPI cohort hosps*/
	SELECT A.*, B.lo_bili_90day as lo_bili_90day_tab2, b.hi_bili_90day as hi_bili_90day_tab2, 
	            c.lo_bili_180day as lo_bili_180day_tab2, c.hi_bili_180day as hi_bili_180day_tab2, 
                D.lo_plat_90day as lo_plat_90day_tab2, d.hi_plat_90day as hi_plat_90day_tab2, 
	            e.lo_plat_180day as lo_plat_180day_tab2, e.hi_plat_180day as hi_plat_180day_tab2,
                F.lo_creat_90day as lo_creat_90day_tab2, f.hi_creat_90day as hi_creat_90day_tab2, 
	            g.lo_creat_180day as lo_creat_180day_tab2, g.hi_creat_180day as hi_creat_180day_tab2
	FROM   COHORT2B  A
	LEFT JOIN bili20132018_90day  B ON A.unique_hosp_count_id =B.unique_hosp_count_id 
    LEFT JOIN bili20132018_180day  C ON A.unique_hosp_count_id =c.unique_hosp_count_id 
    LEFT JOIN plat20132018_90day  D ON A.unique_hosp_count_id =d.unique_hosp_count_id 
    LEFT JOIN plat20132018_180day  E ON A.unique_hosp_count_id =e.unique_hosp_count_id 
    LEFT JOIN creat20132018_90day  F ON A.unique_hosp_count_id =f.unique_hosp_count_id 
    LEFT JOIN creat20132018_180day  G ON A.unique_hosp_count_id =g.unique_hosp_count_id;
QUIT;



