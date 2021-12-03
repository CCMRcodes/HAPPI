* ----------------------------------------------------------------------
*
*  COMBINING KP, VA, SPECTRUM SCORES, MDROs INTO SINGLE HAPPI DATASET
*
* 	Created: 		2021 JUN 9
* 	Last updated: 	2021 OCT 29
* 	Author: 		S. Seelye
*
*-----------------------------------------------------------------------


*------------------------------------
* Program Setup and Import
*------------------------------------

version 16
cap log close
set more off
clear all
set linesize 80

cd ""


*--------------------
* Preparing VA Data 
*--------------------

use happi_20132018, clear

* create hospitalization-level dataset
keep if hospital_day==0

* drop variables we do not need for combined dataset
drop 	hospital_day patientsid edprior540_date		///
		lo_* hi_* mechvent_day1_3_hosp_ind 		

* drop mort30_admit - we are only going to use mort30_ed		
drop mort30_admit		
		
* rename variables to correspond with KP naming
gen hospid = sta6a
order hospid, after(sta6a)
drop sta6a sta3n 

gen male = gender=="M"
drop gender 
order male, after(race)

rename *_prior540 *
	 
rename aod_lung_hosp				aod_lung
rename aod_kidney_hosp				aod_kidney 
rename aod_liver_hosp				aod_liver 
rename aod_heme_hosp				aod_heme 
rename aod_lactate_hosp				aod_lactate 
rename newsirs_hosp_ind				newsirs_ind 

order abx_*, after(pressor)

tempfile va_happi 
save `va_happi'


** SPECTRUM SCORES **

* import spectrum scores 

local path \Daniel_spectrum score code_copy\Training

import delimited "`path'\Happi_24hr_ed_spectrum_score.csv", clear
drop v1 antimicrobial_combination spectrum_drug_combination
rename spectrum_score cumulative_spectrum_24hr
tempfile spectrum_24hr 
save `spectrum_24hr'

import delimited "`path'\Happi_48hr_ed_spectrum_score.csv", clear
drop v1 antimicrobial_combination spectrum_drug_combination
rename spectrum_score cumulative_spectrum_48hr
tempfile spectrum_48hr 
save `spectrum_48hr'

import delimited "`path'\Happi_14day_ed_outpatient_spectrum_score.csv", clear
drop v1 antimicrobial_combination spectrum_drug_combination
rename spectrum_score cumulative_spectrum_14day
tempfile spectrum_14d
save `spectrum_14d'

import delimited "`path'\Happi_30day_ed_outpatient_spectrum_score.csv", clear
drop v1 antimicrobial_combination spectrum_drug_combination
rename spectrum_score cumulative_spectrum_30day
tempfile spectrum_30d
save `spectrum_30d'

forval i=1/30 {
	import delimited "`path'\Happi_day`i'_ed_outpatient_spectrum_score.csv", clear
	drop v1 antimicrobial_combination spectrum_drug_combination 
	rename spectrum_score spectrum_score_day`i'
	tempfile spectrum_day`i'
	save `spectrum_day`i''
}


* merge VA HAPPI with spectrum scores
use `va_happi', clear 

merge 1:1 unique_hosp_count_id using `spectrum_24hr', nogenerate
merge 1:1 unique_hosp_count_id using `spectrum_48hr', nogenerate
merge 1:1 unique_hosp_count_id using `spectrum_14d', nogenerate
merge 1:1 unique_hosp_count_id using `spectrum_30d', nogenerate

forval i=1/30 {
	merge 1:1 unique_hosp_count_id using `spectrum_day`i'', nogenerate
}

* there are some patients who have spectrum scores but are not in the current
* cohort. these were patients from previous cohorts and will be dropped here.
drop if new_admitdate3==.

count 
	* 1,100,996

* check summary stats against numbers in spectrum_score_compare_dan_sarah
	
forval i=1/30 {
	tabstat spectrum_score_day`i', stat(n mean sd median)
}

tabstat cumulative_spectrum_24hr, by(admityear) stat(n mean sd median p25 p75)
tabstat cumulative_spectrum_48hr, by(admityear) stat(n mean sd median p25 p75)
tabstat cumulative_spectrum_14d, by(admityear) stat(n mean sd median p25 p75)
tabstat cumulative_spectrum_30d, by(admityear) stat(n mean sd median p25 p75)
	
* save temporary file for merging with Aim 2 variables 
tempfile va_happi_spectrum
save `va_happi_spectrum'


** AIM 2 VARIABLES **
	
* import dataset 
import sas using aim2_alloutcomes, clear	
drop sta6a edisarrivaldate

tempfile aim2 
save `aim2'
	
* merge aim 2 variables with VA HAPPI 
use `va_happi_spectrum', clear 
merge 1:1 unique_hosp_count_id using `aim2'	
drop if _merge==2
drop _merge

	
** FINAL PREP FOR APPENDING WITH KP DATA **
	
* rename patient ids prior to appending with KP data
rename patienticn patientid 
rename unique_hosp_count_id uniqid 

* ordering variables 
order *mort*, after(hosp_los)

* drop variables we don't need 
drop 	bcma_actiondatetime bcma_daily_ind cprs_datetime_daily cprs_daily_ind 	///
		proccode_mechvent_daily edis_daily earliest_pressors72hrstarttime 		

* create quarter variable 
gen quarter = quarter(new_admitdate3)
gen quarter2 = quarter
replace quarter2 = 5 if quarter == 1 & admityear==2014
replace quarter2 = 6 if quarter == 2 & admityear==2014
replace quarter2 = 7 if quarter == 3 & admityear==2014
replace quarter2 = 8 if quarter == 4 & admityear==2014
replace quarter2 = 9 if quarter == 1 & admityear==2015
replace quarter2 = 10 if quarter == 2 & admityear==2015
replace quarter2 = 11 if quarter == 3 & admityear==2015
replace quarter2 = 12 if quarter == 4 & admityear==2015
replace quarter2 = 13 if quarter == 1 & admityear==2016
replace quarter2 = 14 if quarter == 2 & admityear==2016
replace quarter2 = 15 if quarter == 3 & admityear==2016
replace quarter2 = 16 if quarter == 4 & admityear==2016
replace quarter2 = 17 if quarter == 1 & admityear==2017
replace quarter2 = 18 if quarter == 2 & admityear==2017
replace quarter2 = 19 if quarter == 3 & admityear==2017
replace quarter2 = 20 if quarter == 4 & admityear==2017
replace quarter2 = 21 if quarter == 1 & admityear==2018
replace quarter2 = 22 if quarter == 2 & admityear==2018
replace quarter2 = 23 if quarter == 3 & admityear==2018
replace quarter2 = 24 if quarter == 4 & admityear==2018

tab quarter2 quarter
tab quarter2 admityear

drop quarter 
rename quarter2 quarter 
tab quarter

* rename variables to suggest union rather than intersection of any_mdro and mdro_escr
rename any_mdro_wescr any_mdro_or_escr 
tab any_mdro_or_escr
tab mdro_escr any_mdro_or_escr

rename any_mdro_blood_wescr any_mdro_blood_or_escr
tab escr_blood any_mdro_blood_or_escr

* identify race variable for VA data
tab race, m
rename race race_va

* identify hispanic for VA data
tab hispanic, m 
rename hispanic hispanic_va

* identify dataset 
gen data = "va" 

* save temporary file to append with KP data 
tempfile va_data 
save `va_data'


*--------------------
* Preparing KP Data
*--------------------

use KP\EAH_COHORT_DS_VARS, clear 

* rename variables 
rename uniqueid uniqid 

* create admityear variable from quarter
gen admityear = .
replace admityear = 2013 if inrange(quarter, 1, 4)
replace admityear = 2014 if inrange(quarter, 5, 8)
replace admityear = 2015 if inrange(quarter, 9, 12)
replace admityear = 2016 if inrange(quarter, 13, 16)
replace admityear = 2017 if inrange(quarter, 17, 20)
replace admityear = 2018 if inrange(quarter, 21, 24)
tab admityear quarter 

* create a string variable for hospital id to correspond to VA hospid variable
tostring hospid, replace

* rename mort_admit 
rename mort30_admit mort30_ed

* recode any_mdro 
drop any_mdro 
gen any_mdro = .
recode any_mdro .=1 if mdro_acinetobacter | mdro_mdrpa | mdro_mrsa | mdro_vre | mdro_cre_cdc2015
recode any_mdro .=0 if any_mdro == .

tab mdro_escr any_mdro 

* create any_mdro_or_escr
gen any_mdro_or_escr = .
replace any_mdro_or_escr = 1 if any_mdro==1 | mdro_escr==1  
replace any_mdro_or_escr = 0 if any_mdro_or_escr==.

tab mdro_escr any_mdro_or_escr

* recode any_mdro_blood  
drop any_mdro_blood
gen any_mdro_blood = .
replace any_mdro_blood = 1 if acinetobacter_blood | mdrpa_blood | mrsa_blood | vre_blood | cre_cdc2015_blood		
replace any_mdro_blood = 0 if any_mdro_blood == .		

tab escr_blood any_mdro_blood

* create any_mdro_blood_or_escr
gen any_mdro_blood_or_escr = 1 if any_mdro_blood==1 | escr_blood==1 
replace any_mdro_blood_or_escr = 0 if any_mdro_blood_or_escr==. 

tab escr_blood any_mdro_blood_or_escr

* identify race variable for KP data
tab race, m
rename race race_kp

* identify hispanic for KP data
tab hispanic, m 
rename hispanic hispanic_kp

* identify dataset 
gen data = "kp"

* save temporary file to append to VA data 
tempfile kp_data 
save `kp_data'


*------------------
* Append Datasets 
*------------------
use `va_data', clear 
append using `kp_data'

count 
	* 1,560,126

tab data 	
	
* organize dataset 
order admityear quarter, after(datevalue)
order aod_ind, after(pressor_in_72hr)

* order all datetime variables at the end 
order 	specialtytransferdatetime earliest_specialtytransfer_hosp 	///
		time_first_abx earliest_edisarrivaltime_hosp 				///
		earliest_cprs_abx_order earliest_bcma_abx, last 

* rename any_mdro and any_mdro_blood
rename any_mdro any_mdro_except_escr 
rename any_mdro_blood any_mdro_blood_except_escr

* create new race variable 
tab race_va data, m 
tab race_kp data, m

gen race = "." 
replace race = "American Indian/Alaskan Native" if race_va=="AMERICAN INDIAN OR ALASKA NATIVE"
replace race = "American Indian/Alaskan Native" if race_kp=="1. American Indian/Alaskan Native"
replace race = "Asian" if race_va=="ASIAN"
replace race = "Asian" if race_kp=="2. Asian"
replace race = "Black or African American" if race_va=="BLACK OR AFRICAN AMERICAN"
replace race = "Black or African American" if race_kp=="3. Black or African American" 
replace race = "Native Hawaiian/Pacific Islander" if race_va=="NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER"
replace race = "Native Hawaiian/Pacific Islander" if race_kp=="5. Native Hawaiian/Pacific Islander"
replace race = "Unknown" if race_va=="UNKNOWN" | race_va=="UNKNOWN BY PATIENT"
replace race = "Unknown" if race_kp=="6. Unknown" 
replace race = "White" if race_va=="WHITE" | race_va=="WHITE NOT OF HISP ORIG"
replace race = "White" if race_kp=="7. White"
replace race = "Unknown" if race_va=="" & data=="va" 
replace race = "Unknown" if race_va=="DECLINED TO ANSWER"

tab race, m

drop race_va race_kp

* create new ethnicity variable 
tab hispanic_va data, m
tab hispanic_kp data, m

gen hispanic = .
replace hispanic = 1 if hispanic_va==1 & data=="va"
replace hispanic = 1 if hispanic_kp==1 & data=="kp"
replace hispanic = 0 if hispanic_va==0 & data=="va"
replace hispanic = 0 if hispanic_kp==0 & data=="kp"

tab hispanic data, m 
tab hispanic hispanic_va 
tab hispanic hispanic_kp 

drop hispanic_va hispanic_kp

order race hispanic, after(age)
		
save kp_va_happi, replace



		