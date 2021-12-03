/* 	Merging BCMA, CPRS & EDIS datasets to create a HAPPI cohort for 2013-2018
	
	Sarah Seelye
	Last Updated: 5/12/2021

		
*/

clear all
cap log close
cap more off
version 15.1

cd ""
		
local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using "mkg_step2_HAPPI_20132018.log", replace

*********************
** Use SIRS cohort **
*********************
use happivapd20132018, clear 	

* drop old cprs and bcma variables - after making changes to abx inclusions
* these variables are no longer relevant
drop earliest_cprs_abx_dailytime 	///
	 earliest_cprs_abx_order		///
	 clean_bcmaabx_daily			///
	 recodetomissing

* prepare dataset
order 	patienticn unique new_admitdate3 new_dischargedate3 datevalue 	///
		hospital_day 

* data organization
format patienticn %12.0g
sort patienticn new_admitdate3 datevalue

* Only keep those in analytic sample (SIRS+ on 2 or more; arrival through ED)
sort unique datevalue 
tab edis_hosp newsirs_hosp_ind, m
tab edis_hosp newsirs_hosp_ind if hospital_day==0, m
sum  earliest_edis if hospital_day==0
tab edis_hosp hospital_day if hospital_day<3
 
gen sample = 0
replace sample = 1 if edis_hosp==1 & newsirs_hosp_ind==1
tab sample
tab sample hospital_day if hospital_day<3

tab sample admityear if hospital_day==0, co
tab sample admityear, co

keep if sample==1

count 
tab hospital_day if hospital_day<4			

tempfile sample
save `sample'

* create a day -1 to be used to identify hospitalizations with a BCMA abx
* delivered on day -1
keep unique_hosp_count_id datevalue hospital_day patienticn new_admitdate3 new_dischargedate3 earliest_edisarrivaltime_hosp
keep if hospital_day==0
expand 2
bysort unique (datevalue): replace datevalue = datevalue[_n-1]-1 if _n>1
bysort unique (datevalue): replace hospital_day = hospital_day[_n+1]-1 if _n==1
drop if hospital_day==0

append using `sample'

* check duplicates in new file
duplicates tag patienticn datevalue, gen(tag2)
tab tag2
tab tag2 if hospital_day==-1
tab tag2 if hospital_day==0

drop if tag2==1 & hospital_day==-1 	//dropping day -1s if they represent a 
									//hospital day attached to another 
									//unique hospitalization
duplicates tag patienticn datevalue, gen(tag3)
tab tag3

drop tag*

* create a dataset with hospital_day -1 to identify BCMA deliveries prior to hospitalization
tempfile samplenewday
save `samplenewday'


**********
** BCMA **
**********

	/* Steps: 	1) 	Identify BCMAs administered 24 hours prior to EDIS arrival 
					time. We will drop patients who received BCMAs during this 
					time.
				2) 	Identify the earliest BCMA timestamp of a given 
					hospitalization. */
						

* use 2013-2018 BCMA file 
use abx_earliest20132018, clear
count // 

* keep only variables we need
keep actiondatetime patienticn actiondate	 

* rename variables 
rename actiondatetime	bcma_actiondatetime
rename actiondate 		datevalue 	

* format variables
format patienticn 	%12.0g
format datevalue 	%tdD_m_Y

* sort dataset
sort patienticn datevalue

tempfile bcma
save `bcma'

* Merge Files *
 
* pull in necessary variables from VAPD (using VA to VA transfer dataset)
use `samplenewday', clear

* merge sample with BCMA antibiotics file 
merge 1:1 patienticn datevalue using `bcma'
rename _merge merge_bcma

* drop observations that did not match from BCMA file
drop if merge_bcma==2

* organize dataset
order 	patienticn new_admitdate3 new_dischargedate3 datevalue unique 		///
		hospital_day earliest_edisarrivaltime_hosp specialtytransfer* bcma_actiondatetime 	
			//patientarriv* renamed earliest_edisarrivaltime_hosp
sort patienticn datevalue

* check number of bcma_actiondatetime 
sum bcma_actiondatetime if hospital_day>=0 //7,616,866


* Step 1 *

* Drop Hospitalizations with a BCMA on the Day Prior to ED Admission

	/* 	We will create an indicator for patients who received BCMA ABX in 24 hrs 
		prior to ED admission and then drop those patients from the dataset, as 
		we do not want to include patients already treated with ABX at the VA 
		(e.g. CLC nursing home patients) within 24 hrs of arriving at the ED. */

* check BCMA datetimes that precede ED arrival
gen flag = 1 if bcma_actiondatetime<earliest_edisarrivaltime_hosp &			///
				bcma_actiondatetime!=. & earliest_edisarrivaltime_hosp!=.
tab flag //24,329

bysort unique (datevalue): egen flag_hosp = max(flag)
tab flag_hosp //123,283
tab flag_hosp if hospital_day==0 //11,745

* calculate the number of hours difference between bcma_actiondatetime & ED arrival
gen double bcma_prior_er_hrs = bcma_actiondatetime-earliest_edisarrivaltime_hosp  ///
								if  !missing(bcma_actiondatetime) &			///
									!missing(earliest_edisarrivaltime_hosp)
gen bcma_prior_er_hrs_diff = bcma_prior_er_hrs/(1000*60*60)

sum bcma_prior_er_hrs_diff
sum bcma_prior_er_hrs_diff if bcma_prior_er_hrs_diff<0 & bcma_prior_er_hrs_diff>-24 //10,460

* create a flag for those that receive BCMA in 24 hours prior to ED arrival
gen bcma_prior_er_24hrs_flag = 1 if bcma_prior_er_hrs_diff<0 & bcma_prior_er_hrs_diff>-24 
tab bcma_prior_er_24hrs_flag //10,460

bysort unique (datevalue): egen bcma_prior_er_24hrs_flag_hosp = max(bcma_prior_er_24hrs_flag)
tab bcma_prior_er_24hrs_flag_hosp //104,505
tab bcma_prior_er_24hrs_flag_hosp hospital_day if hospital_day<2 //9764 hosp

* drop hospitalizations that have a BCMA delivered 24 hours prior to ED arrival
drop if bcma_prior_er_24hrs_flag_hosp==1 //104,505 pat-days dropped

sum bcma_prior_er_hrs_diff
sum bcma_prior_er_hrs_diff if bcma_prior_er_hrs_diff<0 & bcma_prior_er_hrs_diff>-24 
sum bcma_prior_er_hrs_diff if bcma_prior_er_hrs_diff<0 //2563 - all negative values less than -24 hours

* Step 2 *

* create a new bcma datetime variable that only includes BCMA datetimes
* that occur after ED arrival - this will be used to calculate the time-to-abx
* exposure variable. we will change the bcma actiondatetime to missing for
* those that have a bcma delivery more than 24 hours before ED arrival (<-24), but 
* we do not drop these patients from the dataset - we simply change their 
* bcma datetime to missing. That is, we drop patients who received BCMA from 0-24 hrs
* prior to ED arrival (because these may be CLC/nursing home transfers), but we
* will keep patients who have a BCMA more than 24 hours prior to ED rrival (<-24)
* because these may have been prior hospitalizations with hospital discharge 
* though those bcma times will be changed to missing
gen double bcma_actiondatetime_new = bcma_actiondatetime 
replace bcma_actiondatetime_new = . if 	bcma_actiondatetime<earliest_edisarrivaltime_hosp ///
										& !missing(bcma_actiondatetime)		 ///
										& !missing(earliest_edisarrivaltime_hosp) //2563 changed to missing
format bcma_actiondatetime_new %tc

bysort unique new_admitdate3 (datevalue): gen countnonmissing_bcma = sum(!missing(bcma_actiondatetime_new)) if !missing(bcma_actiondatetime_new) 

bysort unique (countnonmissing_bcma): gen double earliest_bcma_abx = bcma_actiondatetime_new[1]
format earliest_bcma_abx %tc

sort unique new_admitdate3 datevalue

* drop the old bcma_actiondatetime variable that included timestamp values
* prior to Day 0
drop bcma_actiondatetime
rename bcma_actiondatetime_new bcma_actiondatetime

* drop variables we no longer need
drop 	flag flag_hosp bcma_prior_er_hrs bcma_prior_er_hrs_diff 			///
		bcma_prior_er_24hrs_flag bcma_prior_er_24hrs_flag_hosp 				///
		countnonmissing_bcma
		
* count hospital_days
tab hospital_day if hospital_day<4

* drop Day -1; no longer need
drop if hospital_day<0

* create a daily bcma indicator
gen bcma_daily_ind = 1 if !missing(bcma_actiondatetime) 
replace bcma_daily_ind = 0 if missing(bcma_actiondatetime)

tab bcma_daily_ind if hospital_day>0  // 3,683,249 
tab bcma_daily_ind if hospital_day>=0 // 3,687,294


********** 
** CPRS ** 
**********

* merge cleaned CPRS orders that include the earliest CPRS order for each day
merge 1:1 patienticn datevalue using cprs_earliestorders_2013201

* drop CPRS orders that don't match to our cohort 
rename _merge merge_cprs
drop if merge_cprs==2

* create a new cprs_daily variable that codes to missing cases occurring at or 
* after earliest_specialtytransfer_hosp
gen double cprs_datetime_daily = cprs_orderstartdatetime
format cprs_datetime_daily %tc
replace cprs_datetime_daily = . if cprs_orderstartdatetime>=earliest_specialtytransfer_hosp  ///
								& !missing(cprs_orderstartdatetime)

* recode cprs_datetime_daily to missing if patients who receive the order more 
* than 48 hours prior to specialtytransferdatetime
gen double order_admit_hr = hours(specialtytransferdatetime-cprs_orderstartdatetime)
replace cprs_datetime_daily=. if order_admit_hr>48 & !missing(order_admit_hr) 
	* 93 changes made
			
* create a new earliest cprs variable at the hosp level
bysort unique (datevalue): 												///
	gen countnonmissing_cprs = sum(!missing(cprs_datetime_daily)) 		///
							   if !missing(cprs_datetime_daily) 

bysort unique (countnonmissing_cprs): gen double earliest_cprs_abx_order = cprs_datetime_daily[1]
format earliest_cprs_abx_order %tc

sort unique new_admitdate3 datevalue				

br uniq datevalue earliest_edis earliest_specialty cprs_orderstartdatetime cprs_datetime_daily countnonmissing_cprs earliest_cprs_abx_order

* create a daily indicator for cprs orders
gen cprs_daily_ind = 1 if !missing(cprs_datetime_daily)
replace cprs_daily_ind = 0 if missing(cprs_datetime_daily)

* calculate number of cprs orders per day
tab cprs_daily_ind //397,755
codebook earliest_cprs_abx_order //5,409,320 (out of 8,479,188) missing

drop cprs_orderstartdatetime countnonmissing_cprs cprs_abxorderstartdate order_admit_hr


**********
** EDIS **
**********

* # HOURS BETWEEN EDIS ARRIVAL AND SPECIALTY TRANSFER DATE TIME *

* check the number of hours between EDIS & admission date time
gen double ED_admit_hr = hours(earliest_specialtytransfer_hosp -earliest_edisarrivaltime_hosp)
sum ED_admit_hr	
sum ED_admit_hr	if hospital_day==1 // 1,149,149

sum ED_admit_hr	if ED_admit_hr<0 //10949 pat-days
sum ED_admit_hr	if ED_admit_hr<0 & hospital_day==1 //1471 hosp

sum ED_admit_hr	if ED_admit_hr>12 //585,583 pat-days
sum ED_admit_hr	if ED_admit_hr>12 & hospital_day==1 //76,936

sum ED_admit_hr	if ED_admit_hr>24 //174,913 pat-days
sum ED_admit_hr	if ED_admit_hr>24 & hospital_day==1 //23,324
bysort admityear: sum ED_admit_hr if ED_admit_hr>24 & hospital_day==1 
bysort sta3n admityear: sum ED_admit_hr if ED_admit_hr>24 & hospital_day==1 
					
sum ED_admit_hr	if ED_admit_hr>36 //18,128 pat-days
sum ED_admit_hr	if ED_admit_hr>36 & hospital_day==1 //2375

sum ED_admit_hr	if ED_admit_hr>48 //1727 pat-days
sum ED_admit_hr	if ED_admit_hr>48 & hospital_day==1 //36

sum ED_admit_hr	if ED_admit_hr>72 //1620 pat-days
sum ED_admit_hr	if ED_admit_hr>72 & hospital_day==1 //22

sort ED_admit_hr unique datevalue		

* drop cases more than 48 hours between EDIS arrival and SpecialtyTransfer
drop if ED_admit_hr>48 // dropped 1727 (36 hosp)

* save the current dataset, which we will use later to merge with the updated
* dataset, which constructs a revised earliest_edisarrivaltime_hosp variable
* (see following code)
tempfile happi
save `happi'

* # HOURS BETWEEN EDIS ARRIVAL AND SPECIALTY TRANSFER DATE TIME *

* create an indicator for those in the ED longer than 12 hours
gen ED_12hr_plus = (ED_admit_hr>12)
tab ED_12hr_plus

* only keep first hospital day
keep if hospital_day<=1 		

* only keep variables we need
keep 	patienticn unique_hosp_count_id new_admitdate3 						///
		earliest_edisarrivaltime_hosp earliest_specialtytransfer_hosp		///
		datevalue hospital_day ED_admit_hr ED_12hr_plus
sort patienticn unique datevalue

* create indicator for HAPPI dataset
gen happi = 1

* merge with EDIS dataset to see how many EDIS arrival times there are in one
* hospitalization (on day 0 or day 1)
merge 1:1 unique datevalue using "vapd1318_alledistime_sw20200515"

* count the number of EDIS timestamps for each patient
forval i = 1/6 {
	gen edis`i' = !missing(edistime_`i')
}

gen edis_count = edis1 + edis2 + edis3 + edis4 + edis5 + edis6

* only keep those hospital days with an EDIS time 
drop if edis_count==0

* drop those not in the HAPPI dataset
drop if happi!=1

* check whether there are duplicates by unique hosp
duplicates report unique_hosp_count_id 
duplicates tag unique, gen(dup) 

* identify unique hospitalizations
bysort unique: gen count = _n
tab count

* count number of edis admissions on day 0 or 1
bysort unique: gen mkg_edis_count_hosp = sum(edis_count)
bysort unique: egen edis_count_hosp = max(mkg_edis_count_hosp)
drop mkg_edis_count_hosp

tab dup edis_count_hosp if count==1
display 1149113-1097845
display 51268/1149113 //4.5% of sample has more than 1 EDIS arrival time

* check how many patients have multiple edis times on the second consecutive 
* day in the ED
tab edis_count if count==2 //>4% have between 2-4 EDIS counts on 2nd day (Day 1)
tab hospital_day if count==2 //all count=2 occurs on Day 1

* calculate the hour difference between EDIS arrival and SpecialtyTransferTime
* for each of the EDIS arrival times listed
forval i = 1/6 {
	gen double edis_hr_diff`i' = hours(earliest_specialtytransfer_hosp-edistime_`i')
}

* check if there are any edis arrival times that occur after specialty transfer
* time (negative value); change to missing those that occur after specialty
* transfer time
forval i = 1/6 {
	sum edis_hr_diff`i' 
	sum edis_hr_diff`i' if edis_hr_diff`i'<0
	replace edistime_`i' = . if edis_hr_diff`i'<0
}

* change to missing all edis times that occur *after* specialty transfer time
forval i = 1/6 {
	replace edis_hr_diff`i' = . if edis_hr_diff`i'<0
	sum edis_hr_diff`i' 
}

* now select the latest EDIS arrival time
gen double latest_edis_arrival_daily = max(edistime_1, edistime_2, 			/// 
										   edistime_3, edistime_4, 			///
										   edistime_5, edistime_6)
format latest_edis_arrival_daily %tc

* check the hour difference between edis arrival and new latest edis time
* first drop old edis hour difference variable
drop edis_hr_diff*

gen double edis_hr_diff = hours(earliest_specialtytransfer_hosp-latest_edis_arrival_daily)
sum edis_hr_diff
sum edis_hr_diff if edis_hr_diff>12

bysort count: sum edis_hr_diff if edis_hr_diff>12 

* create a hospitalization-level variable that uses the latest EDIS
* arrival time
bysort unique (datevalue): egen double latest_edis_arrival_hosp = max(latest_edis_arrival_daily)
format latest_edis_arrival_hosp %tc

* check the hour difference between the new hosp-level edis arrival time and the 
* specialty transfer time. first drop the old edis hour difference variable
drop edis_hr_diff

gen double edis_hr_diff = hours(earliest_specialtytransfer_hosp-latest_edis_arrival_hosp)
sum edis_hr_diff
sum edis_hr_diff if edis_hr_diff>12
sum edis_hr_diff if edis_hr_diff>12 & count==1
tab count

* keep only the first record for each hospitalization
count //1,175,289
keep if count==1
sum edis_hr_diff //1,147,642 --  those with an EDIS arrival time that occurred AFTER
				 //specialty transfer time were changed to '.' earlier

sum edis_hr_diff if edis_hr_diff>12

gen edis_12hr_plus = (edis_hr_diff>12) & !missing(edis_hr_diff)
tab edis_12hr_plus admityear, co

* compare the original 'earliest EDIS variable' to the revised 'latest EDIS variable'
gen double edis_hr_diff_sw = hours(earliest_specialtytransfer_hosp-earliest_edisarrivaltime_hosp)

gen edis_time_diff = edis_hr_diff_sw!=edis_hr_diff
tab edis_time_diff

tab count if edis_hr_diff_sw>12 & edis_hr_diff>12 & !missing(edis_hr_diff)
tab count if edis_hr_diff_sw>12 & edis_hr_diff<12 & !missing(edis_hr_diff)
tab count if edis_hr_diff_sw<12 & edis_hr_diff>12 & !missing(edis_hr_diff)
tab count if edis_hr_diff_sw<12 & edis_hr_diff<12 & !missing(edis_hr_diff)

* drop both versions with EDIS times greater than 12 hours from Specialty
* Transfer Date Time
drop if edis_hr_diff_sw>12 & edis_hr_diff>12 & !missing(edis_hr_diff)	

* revise earliest EDIS variable (original time) to take the value of
* the revised variable (latest EDIS arrival time) for those cases where
* the original is >12 hrs from SpecialtyTransfer and the revised is <12 hrs
* from Specialty Transfer
replace earliest_edisarrivaltime_hosp = latest_edis_arrival_hosp			///
			if edis_hr_diff_sw>12 & edis_hr_diff<=12 & !missing(edis_hr_diff)

sum earliest_edisarrivaltime_hosp	//1,100,996
count	//1,100,996

* double check that the revised earliest edis variable doesn't have any
* times >12 hrs from SpecialtyTransfer
gen double edis_hr_diff_rvsd = hours(earliest_specialtytransfer_hosp-earliest_edisarrivaltime_hosp)
sum edis_hr_diff_rvsd if edis_hr_diff_rvsd>12

* only keep variables needed for merging back to full dataset
keep unique_hosp_count_id earliest_edisarrivaltime_hosp 

* save the dataset with the updated EDIS arrival timestamp
tempfile edis
save `edis'

* open the happi dataset to merge new edis times
* make sure to drop the old earliest_edisarrivaltime_hosp first
use `happi', clear
drop earliest_edisarrivaltime_hosp

merge m:1 unique_hosp_count_id using `edis'

* check number of cases from the happi dataset that don't merge;
* those that don't merge are the hospitalizations that are dropped
* when we revise the EDIS time to require EDIS within 12 hrs of specialty
* transfer
tab _merge // 382,350 
tab hospital_day _merge if hospital_day<=1 // 48,117 
sum earliest_edisarrivaltime_hosp

* drop those that didn't merge (ie. don't have an EDIS time)
drop if _merge==1

* check number of hosp. in new dataset
tab hospital_day if hospital_day<=1 //1,101,014 => 1,100,996 

* make sure that there are no edis times >12 hrs from specialty transfer time
drop ED_admit_hr
gen double ED_admit_hr = hours(earliest_specialtytransfer_hosp-earliest_edisarrivaltime_hosp)
sum ED_admit_hr if ED_admit_hr>12 //0

* check missing edis arrival times
codebook earliest_edisarrivaltime_hosp //0 missing

* drop variables we no longer needed					
drop ED_admit_hr _merge sample merge_bcma

************************
** FINALIZING DATASET **
************************

sort unique datevalue		

count //8,095,111
tab hospital_day if hospital_day<4	//1,100,996 

* order variables
order 	patienticn unique_hosp_count_id new_admitdate3 new_dischargedate3  	///
		datevalue hospital_day earliest_edisarrivaltime_hosp 				///
		earliest_cprs_abx_order bcma_actiondatetime earliest_bcma_abx

* save new interim dataset
save step2_HAPPI_20132018, replace

log close

