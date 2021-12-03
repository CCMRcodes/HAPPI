/* 	Making additional variables for HAPPI dataset 
		* antibiotics delivery 
		* community-onset infection 
		* cohort subpopulations 
	
	Sarah Seelye
	Last Updated: 2021 Oct 28 
		
*/

clear all
cap log close
cap more off
version 17.0

cd ""
		
local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using "mkg_step4_HAPPI.log", replace

* start with the step3 HAPPI dataset  
use step3_happi_20132018, clear

count //8,095,111
tab hospital_day if hospital_day==0 //1,100,996

*-----------------------------
* Pulling in Outpatient ABX
*-----------------------------
 	
* create a new dataset of patient days with an extra hospital day added - 
* I'll need to add one day after discharge to capture all abx scripts written 
* post discharge
keep patienticn unique_hosp_count_id datevalue hospital_day new_admitdate3 new_dischargedate3

* add one day for each patient to signify 1 day post-discharge
bysort unique (datevalue): gen last = _n == _N
expand 2 if last 
sort unique datevalue

bysort unique (datevalue): gen new_last = _n == _N
drop last 

replace hospital_day = . if new_last
replace datevalue = datevalue+1 if new_last

* drop extra days added that are duplicates from the following hospitalization 
drop if new_last==1 & tag==1

duplicates report patienticn datevalue

drop new_last tag max_tag

* merge with outpatient meds dataset
merge 1:1 patienticn datevalue using outpatabx1318_cleandaily

* drop un-merged from outpatient abx  
drop if _merge==2

sort unique datevalue

* create new variables for days supply and release date to only keep those 
* that were prescribed between 1 day prior and 1 day following discharge 
gen dayssupply_discharge = dayssupply 
gen releasedate_discharge = releasedate 
format releasedate_discharge %tdD_m_Y

gen outpat_rx_discharge_diff = abs(releasedate-new_dischargedate3)
tab outpat_rx_discharge_diff

tab outpat_rx_discharge_diff if hospital_day==. 

*br if outpat_rx_discharge>1 

* change new variables for dayssupply_discharge & releasedate_discharge
* to missing if abx dispensed greater than 1 day before or after discharge 
replace dayssupply_discharge=. if outpat_rx_discharge_diff>1
replace releasedate_discharge=. if outpat_rx_discharge_diff>1

* change dayssupply_disharge & releasedate_discharge to missing if not on missing 
* hospital_day. i'm doing this because i only want 1 dayssupply & releasedate 
* record for the hospitalization in order to not accidentally count two different
* abx outpat orders that may occur within a single hospitalization. we also  
* only want to count the  supply amount on the day of discharge
replace dayssupply_discharge=. if hospital_day!=. 
replace releasedate_discharge=. if hospital_day!=.

* count the supply amount on the day of discharge 
bysort unique_hosp_count_id new_admitdate3 (datevalue): replace dayssupply_discharge = dayssupply_discharge[_n+1] if dayssupply_discharge[_n+1]!=.

* check dayssupply_discharge is twice the number of those on hospital_day==.
* since we have two dayssupply values
sum dayssupply_discharge
sum dayssupply_discharge if hospital_day==.
sum dayssupply_discharge if hospital_day!=.

* replace releasedate_discharge to be the date released on discharge 
bysort unique_hosp_count_id new_admitdate3 (datevalue): replace releasedate_discharge = releasedate_discharge[_n+1] if releasedate_discharge[_n+1]!=.
codebook releasedate_discharge //162098

* confirmed above; drop hospital_day==.
drop if hospital_day==.

* only keep the variables we need for merging with the full dataset 
keep unique_hosp_count_id new_admitdate3 new_dischargedate3 datevalue dayssupply_discharge releasedate_discharge 
		
* merge to happi dataset to create the other abx delivery variables 
merge 1:1 unique_hosp_count_id datevalue using step2_happi_20132018	
order dod admityear hosp_los, before(patientsid)
drop patientsid-_merge

* save tempfile 
tempfile happi 
save `happi'

*----------
* AODs
*----------

* pull in AODs 
	* aod_mech_vent (aod_lung_hosp)
	* aod_creat_3_hosp (aod_kidney_hosp)
	* aod_bili_3_hosp (aod_liver_hosp)
	* aod_plate_3_hosp (aod_heme_hosp)
	* aod_lactate (aod_lactate_hosp)
	* pressor_in_72hr
	
				
use df_hosp_happi_cohort_definitions_full_cohort, clear 
count 	//1,100,996

* drop variables we don't need 
drop patienticn hospital_day 

* rename AOD variables for final HAPPI dataset
rename aod_mech_vent aod_lung_hosp
rename aod_creat_3_hosp aod_kidney_hosp
rename aod_bili_3_hosp aod_liver_hosp
rename aod_plate_3_hosp aod_heme_hosp
rename aod_lactate aod_lactate_hosp

* keep select variables
keep 	unique_hosp_count_id aod_lung_hosp aod_kidney_hosp aod_liver_hosp  ///
		aod_heme_hosp aod_lactate_hosp pressor_in_72hr

* count 
count 

* save tempfile 
tempfile aod 
save `aod'

* merge in aods 
use `happi', clear 
merge m:1 unique_hosp_count_id using `aod'
drop _merge
	
* check counts of aod variables are the same as before 
foreach var in 	pressor_in_72hr aod_lung 	aod_kidney  ///
				aod_liver 		aod_heme 	aod_lactate {
	
	tab `var' admityear if hospital_day==0
}

gen aod_ind = inlist(1, aod_lung, aod_kidney, aod_liver, aod_heme, aod_lactate)

tab aod_ind admityear if hospital_day==0


***************************************
** CREATE NEW ABX DELIVERY VARIABLES **
*************************************** 

* creat a single cprs or bcma indicator variable 
gen cprs_or_bcma = inlist(1, bcma_daily_ind, cprs_daily_ind)

* replace dayssupply to 0 for all missing
replace dayssupply_discharge= 0 if dayssupply_discharge==.

* create a single cprs/bcma/outpatient abx variable 
gen cprs_or_bcma_or_outpatabx = inlist(1, bcma_daily_ind, cprs_daily_ind)
replace cprs_or_bcma_or_outpatabx = dayssupply_discharge if dayssupply_discharge>0

* create an indicator of cprs/bcma/outpatient abx
gen cprs_or_bcma_or_outpatabx_ind = cprs_or_bcma_or_outpatabx>0


*----------------
* abx_seq4_hosp 
*----------------
	
	* Abx started within 48hrs
	* continued abx for 4+ consecutive days in hospital

* identify the beginning of each 'spell' of abx delivery;
* creating spells means that we'll be able to identify times when there 
* is a gap day between abx delivery	
bysort unique (datevalue): gen begin = cprs_or_bcma != cprs_or_bcma[_n-1]

* replace the first instance of begin to 0 if they do not receive antibiotics 
* on hospital_day 0 
replace begin = 0 if hospital_day==0 & cprs_or_bcma==0

* create spells 
bysort unique (datevalue): gen spell = sum(begin)
	
* identify length of spells for the FIRST spell that receives abx
bysort unique spell (hospital_day): gen length = _N if spell==1
replace length = 0 if missing(length)

* identify patients who received abx in 48 hr & received 4 consecutive days of 
* abx beginning on either hospital day 0, hospital day 1, hospital day 2, or hospital day 3 (and check hospital day 4)
	
		forval i = 0/3 {
			gen seq4_day`i'_mkg_ind = 0
			replace seq4_day`i'_mkg_ind = 1 if hospital_day==`i' & abx_in_48hr==1 & length>=4 & spell==1 
			
			bysort unique: egen seq4_day`i'_ind = max(seq4_day`i'_mkg_ind)	
	
		}
	
	gen abx_seq4_hosp = inlist(1, seq4_day0_ind, seq4_day1_ind, seq4_day2_ind, seq4_day3_ind)
	
	drop 	seq4_day0_mkg_ind seq4_day0_ind 	///
			seq4_day1_mkg_ind seq4_day1_ind 	///
			seq4_day2_mkg_ind seq4_day2_ind 	///
			seq4_day3_mkg_ind seq4_day3_ind	

			
* confirm that none of the abx_seq4_hosp==1 observations have abx_in_48hr			
tab abx_seq4_hosp abx_in_48hr

* count/% of abx_seq4_hosp 
tab abx_seq4_hosp admityear if hospital_day==0	& abx_in_48hr==1, co		


*---------------------------------
* abx_seq_discharge_with_script 
*---------------------------------

	* abx_in_48hr=1
	* patient discharged 
	* completed 4+ days as outpatient & inpatient 
		* completed = alive for 4+ days to receive abx

* first, identify the first day of abx administration for each hospitalization
gen first_doa = . 
replace first_doa = hospital_day if begin==1 & spell==1	
bysort unique: egen first_doa_hosp = max(first_doa)


* next, identify the total number of abx from the FIRST spell for 
* inpatient and outpatient abx 
			
		* identify the beginning of each 'spell' of abx delivery which includes 
		* both inpatient and outpatient meds;
		* creating spells means that we'll be able to identify times when there 
		* is a gap day between abx delivery	
		bysort unique (datevalue): gen begin_inpat_or_outpat = cprs_or_bcma_or_outpatabx_ind != cprs_or_bcma_or_outpatabx_ind[_n-1]

		* replace the first instance of begin to 0 if they do not receive antibiotics 
		* on hospital_day 0 
		replace begin_inpat_or_outpat = 0 if hospital_day==0 & cprs_or_bcma_or_outpatabx_ind==0
	
		* create spells 
		bysort unique (datevalue): gen spell_inpat_or_outpat = sum(begin_inpat_or_outpat)
			
		* identify the total number of abx for the FIRST spell that receives
		* inpat or outpat abx
		bysort unique spell_inpat_or_outpat (hospital_day): egen totabxseq_inpat_or_outpat = sum(cprs_or_bcma_or_outpatabx) if spell_inpat_or_outpat==1
		replace totabxseq_inpat_or_outpat = 0 if missing(totabxseq_inpat_or_outpat)

		bysort unique: egen totabxseq1_hosp = max(totabxseq_inpat_or_outpat)
		
		drop totabxseq_inpat_or_outpat

* next, identify the number of days alive from the first day of abx 
gen date_doa = datevalue if !missing(first_doa)
format date_doa %td

bysort unique_hosp_count_id (hospital_day): egen first_doa_date_hosp = max(date_doa)		
format first_doa_date_hosp %td 

gen daysalive_from_firstdoa = dod-first_doa_date_hosp

by unique_hosp_count_id: egen daysalive_from_firstdoa_hosp = max(daysalive_from_firstdoa)

gen daysalive_from_firstdoa_4plus = daysalive_from_firstdoa>=4
		
* use the following logic in creating abx_seq_discharge_with_script variable

	* If first day of ABX is:
		* Hospital_day 0 (first_doa_hosp)
			* abx in 48hr
			* hosp_los<=2 OR (hosp_los<=3 IF abx_seq4_hosp=0 [they're not counted in abx_seq4_hosp])
			* total abx seq for hosp>=4 (totabxseq1_hosp)
			* alive for 4 days after first day of abx
		* Hospital_day 1
			* abx in 48hr
			* hosp_los<=3 OR (hosp_los<=4 IF abx_seq4_hosp=0 [they're not counted in abx_seq4_hosp])
			* total abx seq for hosp>=4
			* alive for 4 days after first day of abx
		* Hospital_day 2
			* abx in 48hr
			* hosp_los<=4 OR (hosp_los<=5 IF abx_seq4_hosp=0 [they're not counted in abx_seq4_hosp])
			* total abx seq for hosp>=4 
			* alive for 4 days after first day of abx
		* Hospital_day 3
			* abx in 48hr
			* hosp_los<=5 OR (hosp_los<=6 IF abx_seq4_hosp=0 [they're not counted in abx_seq4_hosp])
			* total abx seq for hosp >=4
			* alive for 4 days after first day of abx

gen abx_seq_discharge_with_script = 0
replace abx_seq_discharge_with_script = 1 if abx_in_48hr & first_doa_hosp==0 & (hosp_los<=2 | (hosp_los<=3 & abx_seq4_hosp==0)) & totabxseq1_hosp>=4  //& daysalive_from_firstdoa_4plus			
replace abx_seq_discharge_with_script = 1 if abx_in_48hr & first_doa_hosp==1 & (hosp_los<=3 | (hosp_los<=4 & abx_seq4_hosp==0)) & totabxseq1_hosp>=4  //& daysalive_from_firstdoa_4plus			
replace abx_seq_discharge_with_script = 1 if abx_in_48hr & first_doa_hosp==2 & (hosp_los<=4 | (hosp_los<=5 & abx_seq4_hosp==0)) & totabxseq1_hosp>=4  //& daysalive_from_firstdoa_4plus			
replace abx_seq_discharge_with_script = 1 if abx_in_48hr & first_doa_hosp==3 & (hosp_los<=5 | (hosp_los<=6 & abx_seq4_hosp==0))  & totabxseq1_hosp>=4  //& daysalive_from_firstdoa_4plus			

* count/%
tab abx_seq_discharge_with_script admityear if hospital_day==0 & abx_in_48hr==1, co			


*-----------------
* abx_seq_death
*-----------------

	* abx started within 48 hrs & died on abx prior to completing 4 full days
	* of abx; abx use must occur on consecutive days; include outpatient or 
	* inpatient medications
			* abx_in_48hr=1
			* received <4 days of abx sequence (totabxseq1_hosp<4)
			* alive for less than 4 days after first abx (daysalive_from_firstdoa_4plus=0)
			* daysalive_from_firstdoa <= totabxseq1_hosp

* create abx_seq_death with above criteria			
gen abx_seq_death = 0
replace abx_seq_death = 1 if abx_in_48hr & totabxseq1_hosp<4 & daysalive_from_firstdoa_4plus==0 & (daysalive_from_firstdoa<=totabxseq1_hosp)		

bysort unique (hospital_day): egen abx_seq_death_hosp = max(abx_seq_death)

drop abx_seq_death
rename abx_seq_death_hosp abx_seq_death

* count/%
tab abx_seq_death
tab abx_seq_death admityear if hospital_day==0 & abx_in_48hr==1, co			


*------------------
* early_abx_stop 
*------------------

	* early_abx_stop criteria:
		* abx_in_48hr
		* remain on abx for <4 consecutive days 
		* alive for 1 calendar day with no abx (daysalive_from_firstdoa > totabxseq1_hosp)
		

gen early_abx_stop = 0
replace early_abx_stop = 1 if abx_in_48hr & totabxseq1_hosp<4 & (daysalive_from_firstdoa>totabxseq1_hosp) 

* count/%
tab early_abx_stop
tab early_abx_stop admityear if hospital_day==0 & abx_in_48hr==1, co			


*---------------
* data checks 
*---------------

* look at the patients who don't match up between abx_in_48hr & the 4 categories 
gen abx48_4cat = abx_seq4_hosp + abx_seq_discharge_with_script + abx_seq_death + early_abx_stop
tab abx48_4cat //everyone is in a mutually exclusive category
tab abx48_4cat abx_in_48hr
tab abx48_4cat abx_in_48hr if hospital_day==0
tab abx48_4cat admityear if hospital_day==0


* create a flag for the hosp-days that don't align between the categories and abx_in_48hr
gen flag = abx_in_48hr!=abx48_4cat
tab flag 

* all looks good!


*-----------------------------
* community-onset infection
*-----------------------------

	* includes:
		* abx_seq4_hosp
		* abx_seq_discharge_with_script 
		* abx_seq_death

gen comm_onset_infection = inlist(1, abx_seq4_hosp, abx_seq_discharge_with_script, abx_seq_death)
tab comm_onset_infection admityear if hospital_day==0 & abx_in_48hr
tab comm_onset_infection admityear if hospital_day==0 , co

tab comm_onset_infection admityear if hospital_day==0 & time_to_abx_hr<=12 & abx_in_48hr, co
tab comm_onset_infection admityear if hospital_day==0 & time_to_abx_hr>12 & abx_in_48hr, co

gen abx_seq4_death_presc = comm_onset_infection 

*-------------------
* abx_days_use_30
*-------------------

	* Days of antibiotic treatment, inpatient & outpatient in first 30 days 
	* after hospital presentation 

bysort unique_hosp_count_id (hospital_day): egen abx_days_use_30 = sum(cprs_or_bcma_or_outpatabx)

* top code to 30 
replace abx_days_use_30 = 30 if abx_days_use_30>30 

table admityear if hospital_day==0, stat(mean abx_days_use_30) stat(median abx_days_use_30) 
bysort admityear: sum abx_days_use_30 if hospital_day==0, de 

*--------------
* abx_any_30 
*--------------

gen abx_any_30 = abx_days_use_30>0

bysort abx_any_30: sum abx_days_use_30

tab abx_any_30 admityear if hospital_day==0, co

****************************************
** CREATE NEW SUBPOPULATION VARIABLES **
****************************************

	* Use AOD, abx in 48 hr, and community-onset infection variable to create 
	* study subpopulations 

*----------------	
* Septic Shock 
*----------------
	
		* abx_in_48hr
		* comm_onset_infection - remain on abx for 4+ consecutive days OR 
		* 						 die while on abx, prior to 4+ consecutive days
		* shock (pressor_in_72hr)
	
gen septic_shock = comm_onset_infection & pressor_in_72hr
tab septic_shock admityear if hospital_day==1, co


*-----------------
* Severe Sepsis 
*-----------------
		
		* abx_in_48hr
		* comm_onset_infection - remain on abx for 4+ consecutive days OR 
		* 						 die while on abx, prior to 4+ consecutive days
		* NO shock (pressor_in_72hr=0)
		* any other AOD EXCEPT shock 


* create severe sepsis 
gen severe_sepsis = comm_onset_infection & aod_ind & pressor_in_72hr==0
tab severe_sepsis admityear if hospital_day==0, co


*--------------------
* Infection Cohort
*--------------------

		* abx_in_48hr
		* comm_onset_infection - remain on abx for 4+ consecutive days OR 
		* 						 die while on abx, prior to 4+ consecutive days
		* NO shock (pressor_in_72hr=0)
		* NO other AOD

*gen no_aod_or_shock = .
*replace no_aod_or_shock = 1 if pressor_in_72hr==0 & aod_lung==0 & aod_kidney==0 & aod_liver==0 & aod_heme==0 & aod_lactate==0		
		
gen infection_cohort = comm_onset_infection & aod_ind==0 & pressor_in_72hr==0
tab infection_cohort admityear if hospital_day==0, co

*------------------
* Early Abx Stop
*------------------

tab early_abx_stop admityear if hospital_day==0 , co			


*-----------------
* Never Treated
*-----------------

gen never_treated = abx_in_48hr==0
tab never_treated admityear if hospital_day==0 , co			
tab abx_in_48hr admityear if hospital_day==0 , co			


*************************************************
** PREP DATA FOR STEP 4 MERGE TO HAPPI DATASET **
*************************************************

keep if hospital_day==0	

keep 	unique_hosp_count_id			///
		abx_seq4_hosp					///
		abx_seq4_death_presc			///
		abx_any_30						///
		abx_days_use_30					///
		abx_seq_discharge_with_script	///
		abx_seq_death					///
		early_abx_stop					///
		septic_shock					///
		severe_sepsis					///
		infection_cohort				///
		never_treated					///
		comm_onset_infection			///
		aod_lung_hosp 					///
		aod_kidney_hosp 				///
		aod_liver_hosp  				///
		aod_heme_hosp					///
		aod_lactate_hosp 				///
		pressor_in_72hr
	
order unique pressor aod* abx* comm_onset_infection 
order comm_onset_infection, after(abx_seq4_death_presc)

save aod_abx_subpop_HAPPI_20132018, replace		

count //1,100,996
		
log close 
