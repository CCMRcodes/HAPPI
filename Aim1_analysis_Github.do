* ------------------------------------------------------------------------------
*
*  Temporal Trends in Antimicrobial Prescribing for Infection and Sepsis
*
* 	Created: 		2021 Jul 02
* 	Last updated: 	2022 Jun 01
* 	Author: 		Sarah Seelye
*
*-------------------------------------------------------------------------------

*------------------------------------
* Program Setup and Import
*------------------------------------

version 16
cap log close
set more off
clear all
set linesize 80

cd ""

local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using "Aim1_JAMAIM_analysis_`day'.log", replace

* open dataset
use "aim1_analytic_dataset", clear
	
* count 
count 
	*1,560,126

* drop hospitals with 0-15 sepsis patients)
drop if inlist(hospid, "", "", "", "", "", "", "", "")
		* drop 603 patients from 8 hospitals
count 
	* 1,559,523

*------------------
* New Variables
*------------------

* create outcome variables - antibiotics in 24 hours 
gen abx_in_24hr = time_to_abx_min<=1440

tab abx_in_12hr
tab abx_in_24hr
tab abx_in_48hr

* create a sample of sepsis patients w/o tta restriction of 12 hours 
gen sepsample = septic_shock | severe_sepsis

* tag hospitals 
egen taghosp = tag(hospid)

* outcomes
gen los_7plus = hosp_los>=7
table los_7plus, c(n hosp_los mean hosp_los min hosp_los max hosp_los)

gen los_7plus_survivors = hosp_los>=7 if inhosp_mort==0
table los_7plus_survivors, c(n hosp_los mean hosp_los min hosp_los max hosp_los)

gen los_10plus = hosp_los>=10
table los_10plus, c(n hosp_los mean hosp_los min hosp_los max hosp_los)

gen los_10plus_survivors = hosp_los>=10 if inhosp_mort==0
table los_10plus_survivors, c(n hosp_los mean hosp_los min hosp_los max hosp_los)

gen abx_days_use_8plus = abx_days_use_30>=8
sum abx_days_use_30 if abx_days_use_8plus
sum abx_days_use_30 if abx_days_use_8plus==0

* change missing spectrum scores to 0 -- patients w/o antibiotic treatment
* have a spectrum score of 0 

sum cumulative_spectrum_24hr, det
replace cumulative_spectrum_24hr=0 if cumulative_spectrum_24hr==.
sum cumulative_spectrum_24hr, det
sum cumulative_spectrum_24hr if cumulative_spectrum_24hr>0, det

sum cumulative_spectrum_48hr, det
replace cumulative_spectrum_48hr=0 if cumulative_spectrum_48hr==.
sum cumulative_spectrum_48hr, det
sum cumulative_spectrum_48hr if cumulative_spectrum_48hr>0, det

sum cumulative_spectrum_14day, det
replace cumulative_spectrum_14day=0 if cumulative_spectrum_14day==.
sum cumulative_spectrum_14day, det
sum cumulative_spectrum_14day if cumulative_spectrum_14day>0, det

sum cumulative_spectrum_30day, det
replace cumulative_spectrum_30day=0 if cumulative_spectrum_30day==.
sum cumulative_spectrum_30day, det
sum cumulative_spectrum_30day if cumulative_spectrum_30day>0, det

* creating categories of receipt of broad spectrum coverage 
gen cumul_spec24hr_40plus = cumulative_spectrum_24hr>=40
table cumul_spec24hr_40plus, c(n cumulative_spectrum_24hr mean cumulative_spectrum_24hr min cumulative_spectrum_24hr max cumulative_spectrum_24hr)

gen cumul_spec24hr_45plus = cumulative_spectrum_24hr>=45
table cumul_spec24hr_45plus, c(n cumulative_spectrum_24hr mean cumulative_spectrum_24hr min cumulative_spectrum_24hr max cumulative_spectrum_24hr)

gen cumul_spec48hr_40plus = cumulative_spectrum_48hr>=40
table cumul_spec48hr_40plus, c(n cumulative_spectrum_48hr mean cumulative_spectrum_48hr min cumulative_spectrum_48hr max cumulative_spectrum_48hr)

gen cumul_spec48hr_45plus = cumulative_spectrum_48hr>=45
table cumul_spec48hr_45plus, c(n cumulative_spectrum_48hr mean cumulative_spectrum_48hr min cumulative_spectrum_48hr max cumulative_spectrum_48hr)

gen cumul_spec30d_40plus = cumulative_spectrum_30d>=40
table cumul_spec30d_40plus, c(n cumulative_spectrum_30d mean cumulative_spectrum_30d min cumulative_spectrum_30d max cumulative_spectrum_30d)

gen cumul_spec30d_45plus = cumulative_spectrum_30d>=45
table cumul_spec30d_45plus, c(n cumulative_spectrum_30d mean cumulative_spectrum_30d min cumulative_spectrum_30d max cumulative_spectrum_30d)

* create comorbidity scores for 12, 24, 48hr models 
local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 

quietly logit abx_in_12hr `comorbid'
predict comorbid_12hr

quietly logit abx_in_24hr `comorbid'
predict comorbid_24hr

quietly logit abx_in_48hr `comorbid'
predict comorbid_48hr

quietly nbreg abx_days_use_30 `comorbid'
predict comorbid_days

quietly regress cumulative_spectrum_24hr `comorbid'
predict comorbid_cumulspec_24hr

quietly regress cumulative_spectrum_48hr `comorbid'
predict comorbid_cumulspec_48hr

quietly regress cumulative_spectrum_14day `comorbid'
predict comorbid_cumulspec_14d

quietly regress cumulative_spectrum_30day `comorbid'
predict comorbid_cumulspec_30d

quietly logit inhosp_mort `comorbid'
predict comorbid_inhospmort

quietly logit mort30_ed `comorbid'
predict comorbid_mort30

quietly logit los_7plus `comorbid'
predict comorbid_los7plus

quietly logit los_7plus_survivors `comorbid'
predict comorbid_los7plus_surviv

quietly logit los_10plus `comorbid'
predict comorbid_los10plus

quietly logit los_10plus_survivors `comorbid'
predict comorbid_los10plus_surviv

quietly logit cumul_spec24hr_40plus `comorbid'
predict comorbid_spec24hr40plus

quietly logit cumul_spec24hr_45plus `comorbid'
predict comorbid_spec24hr45plus

quietly logit cumul_spec30d_40plus `comorbid'
predict comorbid_spec30d40plus

quietly logit cumul_spec30d_45plus `comorbid'
predict comorbid_spec30d45plus

quietly logit any_mdro_except_escr `comorbid'
predict comorbid_mdro

quietly logit any_mdro_blood_except_escr `comorbid'
predict comorbid_mdroblood


*------------
* Table 1
*------------

* Hospitalizations 
tab sample 

* Hosps by healthcare system
tab data 
tab data sample, co

* Patient characteristics 
sum age , det
sum age if sample , det

tab male 
tab male if sample

tab race
tab race if sample

gen race2 = .
replace race2 = 1 if race=="White"
replace race2 = 2 if race=="Black or African American"
replace race2 = 3 if inlist(race, "American Indian/Alaskan Native", ///
								  "Asian", "Native Hawaiian/Pacific Islander", ///
								  "Unknown")
label define race2 1 "White" 2 "Black" 3 "Other"
label values race2 race2
tab race race2

tab race2
tab race2 if sample

* Comorbidities 

gen dm_any = inlist(1, dm_comp, dm_uncomp)

foreach comorb in 	chf neuro pulm liver dm_any dm_comp cancer_any 	///
					cancer_met renal {
	tab `comorb' 
	tab `comorb' if sample
}

* Acute Organ Dysfunction 
foreach aod in 	aod_lactate aod_kidney pressor_in_72hr aod_liver aod_heme  ///
				aod_lung {
	tab `aod' 
	tab `aod' if sample				
}
 
tab aod_sum 
tab aod_sum if sample

* Hospital Outcomes 
sum hosp_los , det
sum hosp_los if sample , det

tab inhosp_mort 
tab inhosp_mort if sample

tab mort30_ed 
tab mort30_ed if sample

tab mort30_ed admityear if inlist(admityear, 2013, 2018), co chi2
tab mort30_ed admityear if inlist(admityear, 2013, 2018) & sample, co chi2


************************
* Table 2 - unadjusted
************************

* Receipt of antimicrobial therapy
sum time_to_abx_hr if abx_in_12hr==1, det
bysort admityear: sum time_to_abx_hr if abx_in_12hr==1, det
nptrend time_to_abx_hr if abx_in_12hr==1, by(admityear)

tab abx_in_12hr
tab admityear abx_in_12hr , row
nptrend abx_in_12hr, by(admityear)

tab abx_in_24hr
tab admityear abx_in_24hr , row
nptrend abx_in_24hr, by(admityear)
nptrend admityear, by(abx_in_24hr)

tab abx_in_48hr
tab admityear abx_in_48hr , row
nptrend abx_in_48hr, by(admityear)

sum abx_days_use_30, de
bysort admityear: sum abx_days_use_30, de
nptrend abx_days_use_30, by(admityear)

* Broadness of antibacterial coverage
sum cumulative_spectrum_24hr
table admityear , c(mean cumulative_spectrum_24hr)
nptrend cumulative_spectrum_24hr, by(admityear)

sum cumulative_spectrum_48hr
table admityear , c(mean cumulative_spectrum_48hr)
nptrend cumulative_spectrum_48hr, by(admityear)
nptrend admityear, by(cumulative_spectrum_48hr)
regress cumulative_spectrum_48hr year

sum cumulative_spectrum_14d
table admityear , c(mean cumulative_spectrum_14d)
nptrend cumulative_spectrum_14d, by(admityear)

sum cumulative_spectrum_30d
table admityear , c(mean cumulative_spectrum_30d)
nptrend cumulative_spectrum_30d, by(admityear)

tab admityear cumul_spec24hr_40plus, ro
nptrend cumul_spec24hr_40plus, by(admityear)

tab admityear cumul_spec24hr_45plus, ro
nptrend cumul_spec24hr_45plus, by(admityear)

tab admityear cumul_spec30d_40plus, ro
nptrend cumul_spec30d_40plus, by(admityear)

tab admityear cumul_spec30d_45plus, ro
nptrend cumul_spec30d_45plus, by(admityear)

* Outcomes 
tab inhosp_mort admityear, co
nptrend inhosp_mort, by(admityear)

tab mort30_ed admityear, co
nptrend mort30_ed, by(admityear)

tab los_7plus admityear, co
nptrend los_7plus, by(admityear)

tab los_7plus_survivors admityear, co
nptrend los_7plus_survivors, by(admityear)

tab los_10plus admityear, co
nptrend los_10plus, by(admityear)

tab los_10plus_survivors admityear, co
nptrend los_10plus_survivors, by(admityear)

* Antimicrobial Resistance
tab any_mdro_except_escr admityear, co
nptrend any_mdro_except_escr, by(admityear)

tab any_mdro_blood_except_escr admityear, co
nptrend any_mdro_blood_except_escr, by(admityear)


************************
* Table 2 - Adjusted
************************

* Receipt of antimicrobial therapy
//time to abx 
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress time_to_abx_hr c.year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_tta_t1 if e(sample)
sum yhat_tta_t1, de
table year, c(median yhat_tta_t1 p25 yhat_tta_t1 p75 yhat_tta_t1)
table year, c(mean yhat_tta_t1 sd yhat_tta_t1)
histogram yhat_tta_t1 if abx_in_12hr


//abx in 12 hr
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit abx_in_12hr c.year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_abx12_t1 
sum yhat_abx12
table admityear, c(mean yhat_abx12_t1)

//abx in 24 hr
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit abx_in_24hr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_abx24_t1 
sum yhat_abx24_t1
table admityear, c(mean yhat_abx24_t1)


//abx in 48 hr
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit abx_in_48hr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_abx48_t1 
sum yhat_abx48_t1
table admityear, c(mean yhat_abx48_t1)


//abx days
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress abx_days_use_30 year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_daysuse_t1 
sum yhat_daysuse_t1, de
table admityear, c(mean yhat_daysuse_t1 median yhat_daysuse_t1)

* Broadness of antibacterial coverage
//24hr
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress cumulative_spectrum_24hr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_spec24_t1 
sum yhat_spec24_t1, de
table admityear, c(mean yhat_spec24_t1 median yhat_spec24_t1)

//48hr
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress cumulative_spectrum_48hr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_spec48_t1 
sum yhat_spec48_t1, de
table admityear, c(mean yhat_spec48_t1 median yhat_spec48_t1)

//14 day
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress cumulative_spectrum_14d year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_spec14d_t1 
sum yhat_spec14d_t1, de
table admityear, c(mean yhat_spec14d_t1 median yhat_spec14d_t1)

//30 day
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress cumulative_spectrum_30d year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))
predict yhat_spec30d_t1 
sum yhat_spec30d_t1, de
table admityear, c(mean yhat_spec30d_t1 median yhat_spec30d_t1)

//48hr - 40plus
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit cumul_spec48hr_40plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

//48hr - 45plus
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit cumul_spec48hr_45plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))


//30 day - 40 plus
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit cumul_spec30d_40plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))


//30 day - 45 plus
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit cumul_spec30d_45plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

* Outcomes 
//in-hospital mortality
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit inhosp_mort year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

//30-day mortality
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit mort30_ed year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

// LOS - 7 plus
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit los_7plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))


// LOS - 7 plus survivors
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit los_7plus_survivors year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

// LOS - 10 plus 
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit los_10plus year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

// LOS - 10 plus survivors
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit los_10plus_survivors year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

// LOS among all hospitalizations
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress hosp_los year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

predict yhat_los 
sum yhat_los, de
table admityear, c(mean yhat_los median yhat_los p25 yhat_los p75 yhat_los)

// LOS among hospitalizations with live discharges
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
regress hosp_los year c.age male `sirs' `aod' `comorbid' va if inhosp_mort==0
margins
margins, at(year=(1 2 3 4 5 6))

predict yhat_los_surv 
sum yhat_los_surv, de
table admityear, c(mean yhat_los_surv median yhat_los_surv p25 yhat_los_surv p75 yhat_los_surv)

* Antimicrobial Resistance
// MDR
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit any_mdro_except_escr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))

// MDR - blood
local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 
		
logit any_mdro_blood_except_escr year c.age male `sirs' `aod' `comorbid' va 
margins
margins, at(year=(1 2 3 4 5 6))


*************************************************************
* eTable 4 - unadjusted & adjusted - for sepsis patients
*************************************************************

preserve

	keep if sepsample==1 & abx_in_12hr==1
	count

	tab admityear

	*---------------
	* Unadjusted
	*---------------
	
	* Receipt of antimicrobial therapy
	sum time_to_abx_hr, det
	bysort admityear: sum time_to_abx_hr, det
	nptrend time_to_abx_hr, by(admityear)

	sum abx_days_use_30, de
	bysort admityear: sum abx_days_use_30, de
	nptrend abx_days_use_30, by(admityear)

	* Broadness of antibacterial coverage
	sum cumulative_spectrum_24hr
	table admityear , c(mean cumulative_spectrum_24hr)
	nptrend cumulative_spectrum_24hr, by(admityear)

	sum cumulative_spectrum_48hr
	table admityear , c(mean cumulative_spectrum_48hr)
	nptrend cumulative_spectrum_48hr, by(admityear)

	sum cumulative_spectrum_14d
	table admityear , c(mean cumulative_spectrum_14d)
	nptrend cumulative_spectrum_14d, by(admityear)

	sum cumulative_spectrum_30d
	table admityear , c(mean cumulative_spectrum_30d)
	nptrend cumulative_spectrum_30d, by(admityear)

	tab admityear cumul_spec24hr_40plus, ro
	nptrend cumul_spec24hr_40plus, by(admityear)

	tab admityear cumul_spec24hr_45plus, ro
	nptrend cumul_spec24hr_45plus, by(admityear)

	tab admityear cumul_spec30d_40plus, ro
	nptrend cumul_spec30d_40plus, by(admityear)

	tab admityear cumul_spec30d_45plus, ro
	nptrend cumul_spec30d_45plus, by(admityear)

	* Outcomes 
	tab inhosp_mort admityear, co
	nptrend inhosp_mort, by(admityear)

	tab mort30_ed admityear, co
	nptrend mort30_ed, by(admityear)

	tab los_7plus admityear, co
	nptrend los_7plus, by(admityear)

	tab los_7plus_survivors admityear, co
	nptrend los_7plus_survivors, by(admityear)

	tab los_10plus admityear, co
	nptrend los_10plus, by(admityear)

	tab los_10plus_survivors admityear, co
	nptrend los_10plus_survivors, by(admityear)

	* Antimicrobial Resistance
	tab any_mdro_except_escr admityear, co
	nptrend any_mdro_except_escr, by(admityear)

	tab any_mdro_blood_except_escr admityear, co
	nptrend any_mdro_blood_except_escr, by(admityear)

restore

	*---------------
	* Adjusted
	*---------------

	drop yhat_*
	
	* Receipt of antimicrobial therapy
	//time to abx 
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress time_to_abx_hr c.year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_tta_t2 if e(sample)
	sum yhat_tta_t2, de
	table year, c(median yhat_tta_t2 p25 yhat_tta_t2 p75 yhat_tta_t2 mean yhat_tta_t2 n yhat_tta_t2)
	histogram yhat_tta_t2 if abx_in_12hr


	//abx days
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress abx_days_use_30 year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_daysuse_t2 
	sum yhat_daysuse_t2, de
	table admityear, c(mean yhat_daysuse_t2 median yhat_daysuse_t2)

	* Broadness of antibacterial coverage
	//24hr
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress cumulative_spectrum_24hr year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_spec24_t2 
	sum yhat_spec24_t2, de
	table admityear, c(mean yhat_spec24_t2 median yhat_spec24_t2)

	//48hr
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress cumulative_spectrum_48hr year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_spec48_t2 
	sum yhat_spec48_t2, de
	table admityear, c(mean yhat_spec48_t2 median yhat_spec48_t2)

	//14 day
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress cumulative_spectrum_14d year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_spec14d_t2 
	sum yhat_spec14d_t2, de
	table admityear, c(mean yhat_spec14d_t2 median yhat_spec14d_t2)

	//30 day
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress cumulative_spectrum_30d year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_spec30d_t2 
	sum yhat_spec30d_t2, de
	table admityear, c(mean yhat_spec30d_t2 median yhat_spec30d_t2)

	//48hr - 40plus
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit cumul_spec48hr_40plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))
	predict yhat_spec24h40_t2 
	sum yhat_spec24h40_t2, de
	table admityear, c(mean yhat_spec24h40_t2 median yhat_spec24h40_t2)


	//48hr - 45plus
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit cumul_spec48hr_45plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))


	//30 day - 40 plus
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit cumul_spec30d_40plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))


	//30 day - 45 plus
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit cumul_spec30d_45plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	* Outcomes 
	//in-hospital mortality
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit inhosp_mort year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	//30-day mortality
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit mort30_ed year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	// LOS - 7 plus
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit los_7plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))


	// LOS - 7 plus survivors
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit los_7plus_survivors year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	// LOS - 10 plus 
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit los_10plus year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	// LOS - 10 plus survivors
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit los_10plus_survivors year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	
	// LOS among all hospitalizations
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress hosp_los year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	predict yhat_los_sep 
	sum yhat_los, de
	table admityear, c(mean yhat_los_sep median yhat_los_sep)

	// LOS among hospitalizations with live discharges
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	regress hosp_los year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample & inhosp_mort==0
	margins
	margins, at(year=(1 2 3 4 5 6))

	predict yhat_los_survsep 
	sum yhat_los_survsep, de
	table admityear, c(mean yhat_los_survsep median yhat_los_survsep)

	
	* Antimicrobial Resistance
	// MDR
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit any_mdro_except_escr year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))

	// MDR - blood
	local aod 														///
			 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
			 aod_heme aod_lung 			
			
	local sirs														///
			sirs_temp sirs_rr sirs_pulse sirs_wbc

	local comorbid 															///
			cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
			renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
			pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
			anemia_cbl anemia_def etoh drug psychoses depression 
			
	logit any_mdro_blood_except_escr year c.age male `sirs' `aod' `comorbid' va if abx_in_12hr & sepsample 
	margins
	margins, at(year=(1 2 3 4 5 6))




********************************************************************************
* Models for Table 3 - Hospital-level trends in ABX prescribing for all patients 
********************************************************************************
	
*----------------------------
* ANTIBIOTICS IN 12 HOURS 
*----------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_12hr c.year c.age male `sirs' `aod' comorbid_12hr va || hospid_enc: , or

estimates store abx12hr		
predict yhat_abx12, mu
predict r0_abx12, reffects

*-----------------------------------
* ANTIBIOTICS IN 24 HOURS
*-----------------------------------

* mixed logit model

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_24hr c.year c.age male `sirs' `aod' comorbid_24hr va || hospid_enc: , or

estimates store abx24hr		
predict yhat_abx24, mu
predict r0_abx24, reffects

*-----------------------------------
* ANTIBIOTICS IN 48 HOURS
*-----------------------------------

* mixed logit model 

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_48hr c.year c.age male `sirs' `aod' comorbid_48hr va || hospid_enc: , or

estimates store abx48hr		
predict yhat_abx48, mu
predict r0_abx48, reffects
	
*-------------------------------
* Days of Antibiotics Therapy
*-------------------------------

sum abx_days_use_30, det
sum abx_days_use_30 if never_treated==0, det

bysort year: sum abx_days_use_30, det

* mixed negative binomial model	
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
menbreg abx_days_use_30 c.year c.age male `sirs' `aod' c.comorbid_days va || hospid_enc: 

estimates store abxdays		
predict yhat_daysuse, mu 
predict r0_daysuse, reffects


*--------------------------
* Spectrum Score, 24 HRs
*--------------------------

sum age, det
gen agegrp = .
replace agegrp = 1 if age>=18 & age<35
replace agegrp = 2 if age>=35 & age<50
replace agegrp = 3 if age>=50 & age<65
replace agegrp = 4 if age>=65 & age<80
replace agegrp = 5 if age>=80

sum comorbid_cumulspec_24hr, det
xtile comorbid_cumulspec_24hr_cat = comorbid_cumulspec_24hr, nq(4)
	
*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_24hr c.year i.agegrp male `aod' `sirs' i.comorbid_cumulspec_24hr_cat va || hospid_enc: 	

estimates store spec24hr		
predict yhat_spec24hr, mu
predict r0_spec24hr, reffects


*--------------------------
* Spectrum Score, 48 HRs
*--------------------------
sum comorbid_cumulspec_48hr, det
xtile comorbid_cumulspec_48hr_cat = comorbid_cumulspec_48hr, nq(4)
	
*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_48hr c.year i.agegrp male `aod' `sirs' va i.comorbid_cumulspec_48hr_cat || hospid_enc: 	

estimates store spec48hr		
predict yhat_spec48hr, mu
predict r0_spec48hr, reffects
	
*--------------------------
* Spectrum Score, 14 Days
*--------------------------

xtile comorbid_cumulspec_14d_cat = comorbid_cumulspec_14d, nq(4)

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_14day c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_14d_cat va	|| hospid_enc: 	

estimates store spec14day		
predict yhat_spec14day, mu
predict r0_spec14day, reffects

*--------------------------
* Spectrum Score, 30 Days
*--------------------------
xtile comorbid_cumulspec_30d_cat = comorbid_cumulspec_30d, nq(4)

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
			
meglm cumulative_spectrum_30day c.year 	///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_30d_cat va	|| hospid_enc: 	

estimates store spec30day		
predict yhat_spec30day, mu
predict r0_spec30day, reffects

*-------------------------
* Inhospital Mortality
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit inhosp_mort c.year c.age male `sirs' `aod' comorbid_inhospmort va || hospid_enc: , or

estimates store inhospmort	
predict yhat_inhosp, mu
predict r0_inhosp, reffects


*-------------------------
* 30-Day Mortality
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit mort30_ed c.year c.age male `sirs' `aod' comorbid_mort30 va || hospid_enc: , or

estimates store mort30	
predict yhat_mort30, mu
predict r0_mort30, reffects


*-------------------------
* LOS - 7 Days All
*-------------------------

xtile comorbid_los7plus_cat = comorbid_los7plus, nq(4)

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_7plus c.year c.age male `sirs' `aod' comorbid_los7plus va || hospid_enc: , or

estimates store los7all	
predict yhat_los7all, mu
predict r0_los7all, reffects

*-------------------------
* LOS - 7 Days Survivors
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_7plus_survivors c.year c.age male `sirs' `aod' comorbid_los7plus_surviv va || hospid_enc: , or

estimates store los7surv	
predict yhat_los7surv, mu
predict r0_los7surv, reffects


*-------------------------
* LOS - 10 Days All
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_10plus c.year c.age male `sirs' `aod' comorbid_los10plus va || hospid_enc: , or

estimates store los10all	
predict yhat_los10all, mu
predict r0_los10all, reffects

*-------------------------
* LOS - 10 Days Survivors
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_10plus_survivors c.year c.age male `sirs' `aod' comorbid_los10plus_surviv va || hospid_enc: , or

estimates store los10surv	
predict yhat_los10surv, mu
predict r0_los10surv, reffects


*---------------------------
* 24hr Spectrum Score 40+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec24hr_40plus c.year c.age male `sirs' `aod' comorbid_spec24hr40plus va || hospid_enc: , or

estimates store spec24hr40	
predict yhat_spec24hr40, mu
predict r0_spec24hr40, reffects


*---------------------------
* 24hr Spectrum Score 45+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec24hr_45plus c.year c.age male `sirs' `aod' comorbid_spec24hr45plus va || hospid_enc: , or

estimates store spec24hr45	
predict yhat_spec24hr45, mu
predict r0_spec24hr45, reffects


*---------------------------
* 30 Day Spectrum Score 40+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec30d_40plus c.year c.age male `sirs' `aod' comorbid_spec30d40plus va || hospid_enc: , or

estimates store spec30d40	
predict yhat_spec30d40, mu
predict r0_spec30d40, reffects


*---------------------------
* 30 Day Spectrum Score 45+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec30d_45plus c.year c.age male `sirs' `aod' comorbid_spec30d45plus va || hospid_enc: , or

estimates store spec30d45	
predict yhat_spec30d45, mu
predict r0_spec30d45, reffects


*--------------------
* New MDR culture
*--------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit any_mdro_except_escr  c.year c.age male `sirs' `aod' comorbid_mdro va || hospid_enc: , or

estimates store mdro	
predict yhat_mdro, mu
predict r0_mdro, reffects


*-------------------------
* New MDR blood culture
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit any_mdro_blood_except_escr  c.year c.age male `sirs' `aod' comorbid_mdroblood va || hospid_enc: , or

estimates store mdroblood	
predict yhat_mdroblood, mu
predict r0_mdroblood, reffects


*****************************************************************************************
* Models for eTable 5 - Hospital-level trends in ABX prescribing for patients W/O sepsis
*****************************************************************************************
	
*----------------------------
* ANTIBIOTICS IN 12 HOURS 
*----------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_12hr c.year c.age male `sirs' `aod' comorbid_12hr va if sepsample==0 || hospid_enc: , or

predict yhat_abx12_nosep if e(sample), mu
predict r0_abx12_nosep if e(sample), reffects

*-----------------------------------
* ANTIBIOTICS IN 24 HOURS
*-----------------------------------

* mixed logit model

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_24hr c.year c.age male `sirs' `aod' comorbid_24hr va if sepsample==0 || hospid_enc: , or

predict yhat_abx24_nosep if e(sample), mu
predict r0_abx24_nosep if e(sample), reffects

*-----------------------------------
* ANTIBIOTICS IN 48 HOURS
*-----------------------------------

* mixed logit model 

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_48hr c.year c.age male `sirs' `aod' comorbid_48hr va if sepsample==0 || hospid_enc: , or

predict yhat_abx48_nosep if e(sample), mu
predict r0_abx48_nosep if e(sample), reffects
	
*-------------------------------
* Days of Antibiotics Therapy
*-------------------------------

* mixed negative binomial model	
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
menbreg abx_days_use_30 c.year c.age male `sirs' `aod' c.comorbid_days va if sepsample==0 || hospid_enc: 

predict yhat_daysuse_nosep if e(sample), mu 
predict r0_daysuse_nosep if e(sample), reffects


*--------------------------
* Spectrum Score, 24 HRs
*--------------------------

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_24hr c.year i.agegrp male `aod' `sirs' i.comorbid_cumulspec_24hr_cat va if sepsample==0 || hospid_enc: 	

predict yhat_spec24hr_nosep if e(sample), mu
predict r0_spec24hr_nosep if e(sample), reffects


*--------------------------
* Spectrum Score, 48 HRs
*--------------------------

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_48hr c.year i.agegrp male `aod' `sirs'  ///
		i.comorbid_cumulspec_48hr_cat va if sepsample==0  || hospid_enc: 	

predict yhat_spec48hr_nosep if e(sample), mu
predict r0_spec48hr_nosep if e(sample), reffects
	
*--------------------------
* Spectrum Score, 14 Days
*--------------------------

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_14day c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_14d_cat va if sepsample==0	|| hospid_enc: 	

predict yhat_spec14day_nosep if e(sample), mu
predict r0_spec14day_nosep if e(sample), reffects

*--------------------------
* Spectrum Score, 30 Days
*--------------------------

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
			
meglm cumulative_spectrum_30day c.year 	///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_30d_cat va if sepsample==0	|| hospid_enc: 	

predict yhat_spec30day_nosep if e(sample), mu
predict r0_spec30day_nosep if e(sample), reffects

*-------------------------
* Inhospital Mortality
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit inhosp_mort c.year c.age male `sirs' `aod' comorbid_inhospmort va if sepsample==0 || hospid_enc: , or

predict yhat_inhosp_nosep if e(sample), mu
predict r0_inhosp_nosep if e(sample), reffects


*-------------------------
* 30-Day Mortality
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit mort30_ed c.year c.age male `sirs' `aod' comorbid_mort30 va if sepsample==0 || hospid_enc: , or

predict yhat_mort30_nosep if e(sample), mu
predict r0_mort30_nosep if e(sample), reffects


*-------------------------
* LOS - 7 Days All
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_7plus c.year c.age male `sirs' `aod' comorbid_los7plus va if sepsample==0 || hospid_enc: , or

predict yhat_los7all_nosep if e(sample), mu
predict r0_los7all_nosep if e(sample), reffects

*-------------------------
* LOS - 7 Days Survivors
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_7plus_survivors c.year c.age male `sirs' `aod' comorbid_los7plus_surviv va if sepsample==0 || hospid_enc: , or

predict yhat_los7surv_nosep if e(sample), mu
predict r0_los7surv_nosep if e(sample), reffects


*-------------------------
* LOS - 10 Days All
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_10plus c.year c.age male `sirs' `aod' comorbid_los10plus va if sepsample==0 || hospid_enc: , or

predict yhat_los10all_nosep if e(sample), mu
predict r0_los10all_nosep if e(sample), reffects

*-------------------------
* LOS - 10 Days Survivors
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit los_10plus_survivors c.year c.age male `sirs' `aod' comorbid_los10plus_surviv va if sepsample==0 || hospid_enc: , or

predict yhat_los10surv_nosep if e(sample), mu
predict r0_los10surv_nosep if e(sample), reffects


*---------------------------
* 24hr Spectrum Score 40+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec24hr_40plus c.year c.age male `sirs' `aod' comorbid_spec24hr40plus va if sepsample==0 || hospid_enc: , or

predict yhat_spec24hr40_nosep if e(sample), mu
predict r0_spec24hr40_nosep if e(sample), reffects


*---------------------------
* 24hr Spectrum Score 45+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec24hr_45plus c.year c.age male `sirs' `aod' comorbid_spec24hr45plus va if sepsample==0 || hospid_enc: , or

predict yhat_spec24hr45_nosep if e(sample), mu
predict r0_spec24hr45_nosep if e(sample), reffects

*---------------------------
* 30 Day Spectrum Score 40+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec30d_40plus c.year c.age male `sirs' `aod' comorbid_spec30d40plus va if sepsample==0 || hospid_enc: , or

predict yhat_spec30d40_nosep if e(sample), mu
predict r0_spec30d40_nosep if e(sample), reffects


*---------------------------
* 30 Day Spectrum Score 45+
*---------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meqrlogit cumul_spec30d_45plus c.year c.age male `sirs' `aod' comorbid_spec30d45plus va if sepsample==0 || hospid_enc: , or

predict yhat_spec30d45_nosep if e(sample), mu
predict r0_spec30d45_nosep if e(sample), reffects


*--------------------
* New MDR culture
*--------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit any_mdro_except_escr  c.year c.age male `sirs' `aod' comorbid_mdro va if sepsample==0 || hospid_enc: , or

predict yhat_mdro_nosep if e(sample), mu
predict r0_mdro_nosep if e(sample), reffects


*-------------------------
* New MDR blood culture
*-------------------------

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit any_mdro_blood_except_escr  c.year c.age male `sirs' `aod' comorbid_mdroblood va if sepsample==0 || hospid_enc: , or

predict yhat_mdroblood_nosep if e(sample), mu
predict r0_mdroblood_nosep if e(sample), reffects


* save current dataset to retain the predicted values in case program crashes
*save Data\aim1_analytic_dataset_jamaimrr_20220228, replace		


			*******************************************************************************
			** ADDENDUM: add 48hr spectrum score 40+ yhats and r0 to the dataset for 
			**			 sepsis and non-sepsis hospitalizations 
			*******************************************************************************

			use Data\aim1_analytic_dataset_jamaimrr_20220228, clear

			gen cumul_spec48hr_40plus = cumulative_spectrum_48hr>=40
			table cumul_spec48hr_40plus, c(n cumulative_spectrum_48hr mean cumulative_spectrum_48hr min cumulative_spectrum_48hr max cumulative_spectrum_48hr)

			gen cumul_spec48hr_45plus = cumulative_spectrum_48hr>=45
			table cumul_spec48hr_45plus, c(n cumulative_spectrum_48hr mean cumulative_spectrum_48hr min cumulative_spectrum_48hr max cumulative_spectrum_48hr)

			quietly logit cumul_spec48hr_40plus `comorbid'
			predict comorbid_spec48hr40plus

			quietly logit cumul_spec48hr_45plus `comorbid'
			predict comorbid_spec48hr45plus


			** Including Patients with Sepsis in Analysis **

			*---------------------------
			* 48hr Spectrum Score 40+
			*---------------------------

			local aod 														///
					 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
					 aod_heme aod_lung 			
					
			local sirs														///
					sirs_temp sirs_rr sirs_pulse sirs_wbc
					
			meqrlogit cumul_spec48hr_40plus c.year c.age male `sirs' `aod' comorbid_spec48hr40plus va || hospid_enc: , or

			estimates store spec48hr40	
			predict yhat_spec48hr40, mu
			predict r0_spec48hr40, reffects


			*---------------------------
			* 48hr Spectrum Score 45+
			*---------------------------

			local aod 														///
					 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
					 aod_heme aod_lung 			
					
			local sirs														///
					sirs_temp sirs_rr sirs_pulse sirs_wbc
					
			meqrlogit cumul_spec48hr_45plus c.year c.age male `sirs' `aod' comorbid_spec48hr45plus va || hospid_enc: , or

			estimates store spec48hr45	
			predict yhat_spec48hr45, mu
			predict r0_spec48hr45, reffects


			** EXCLUDING Patients with Sepsis from Analysis **

			*---------------------------
			* 48hr Spectrum Score 40+
			*---------------------------

			local aod 														///
					 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
					 aod_heme aod_lung 			
					
			local sirs														///
					sirs_temp sirs_rr sirs_pulse sirs_wbc
					
			meqrlogit cumul_spec48hr_40plus c.year c.age male `sirs' `aod' comorbid_spec48hr40plus va if sepsample==0 || hospid_enc: , or

			predict yhat_spec48hr40_nosep if e(sample), mu
			predict r0_spec48hr40_nosep if e(sample), reffects


			*---------------------------
			* 48hr Spectrum Score 45+
			*---------------------------

			local aod 														///
					 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
					 aod_heme aod_lung 			
					
			local sirs														///
					sirs_temp sirs_rr sirs_pulse sirs_wbc
					
			meqrlogit cumul_spec48hr_45plus c.year c.age male `sirs' `aod' comorbid_spec48hr45plus va if sepsample==0 || hospid_enc: , or

			predict yhat_spec48hr45_nosep if e(sample), mu
			predict r0_spec48hr45_nosep if e(sample), reffects


			* save predicted values for additional analysis
			preserve
				keep hospid admityear yhat_spec48hr40 r0_spec48hr40 ///
								  yhat_spec48hr45 r0_spec48hr45 /// 
								  yhat_spec48hr40_nosep r0_spec48hr40_nosep ///
								  yhat_spec48hr45_nosep r0_spec48hr45_nosep 
								  	
			* create predicted values for additional analysis 
				foreach x in spec48hr40 spec48hr45  {
					bysort hospid admityear: egen yhat_`x'_hospyearmed = median(yhat_`x')
				}

			* must rename the _nosep variables to conform with stata requirements
				rename yhat_spec48hr40_nosep yhat_spec48hr40nosep
				rename yhat_spec48hr45_nosep yhat_spec48hr45nosep
				
			* create median values for each hospital	
				foreach x in spec48hr40nosep spec48hr45nosep  {
					bysort hospid admityear: egen yhat_`x'_hospyearmed = median(yhat_`x')
				}
				
				collapse 	r0_spec48hr40 yhat_spec48hr40_hospyearmed	///
							r0_spec48hr45 yhat_spec48hr45_hospyearmed	///
							r0_spec48hr40_nosep yhat_spec48hr40nosep_hospyearmed	///
							r0_spec48hr45_nosep yhat_spec48hr45nosep_hospyearmed	///
							, by(hospid admityear)	

				bysort hospid (admityear): gen n=_n

				foreach x in  spec48hr40 spec48hr45    {
					gen yhat_`x'_y1 = yhat_`x'_hospyearmed if n==1
					gen yhat_`x'_y6 = yhat_`x'_hospyearmed if n==6
					bysort hospid: egen yhat_`x'_y1_fill = max(yhat_`x'_y1)
					bysort hospid: egen yhat_`x'_y6_fill = max(yhat_`x'_y6)
					gen ave_change_peryear_`x' =(yhat_`x'_y6_fill-yhat_`x'_y1_fill)/5
					gen p_change_`x' = (yhat_`x'_y1_fill-yhat_`x'_y6_fill)/yhat_`x'_y1_fill	
				}	

				* rename _nosep variable again so that it conforms to stata requirements 
				rename yhat_spec48hr40nosep_hospyearmed yhat_spec48hr40ns_hospyearmed
				rename yhat_spec48hr45nosep_hospyearmed yhat_spec48hr45ns_hospyearmed
				
				foreach x in  spec48hr40ns spec48hr45ns    {
					gen yhat_`x'_y1 = yhat_`x'_hospyearmed if n==1
					gen yhat_`x'_y6 = yhat_`x'_hospyearmed if n==6
					bysort hospid: egen yhat_`x'_y1_fill = max(yhat_`x'_y1)
					bysort hospid: egen yhat_`x'_y6_fill = max(yhat_`x'_y6)
					gen ave_change_peryear_`x' =(yhat_`x'_y6_fill-yhat_`x'_y1_fill)/5
					gen p_change_`x' = (yhat_`x'_y1_fill-yhat_`x'_y6_fill)/yhat_`x'_y1_fill	
				}	
				
				drop *y1* *y6*	
					
				order hospid admityear 
				drop r0* n p_*

					*save hosp_avechangespec48hr_fortable4_20220316, replace 

			restore	



************
* Table 3 *
************

* use dataset with predicted values 
use Data\aim1_analytic_dataset_jamaimrr_20220228, clear

* saving predicted values for additional analysis 

preserve

	foreach x in abx12 abx24 abx48 daysuse  ///
				 spec24hr spec48hr spec14day spec30day  ///
				 inhosp mort30 los7all los7surv los10all los10surv ///
				 spec24hr40 spec24hr45 spec30d40 spec30d45 ///
				 mdro mdroblood  {
		bysort hospid admityear: egen yhat_`x'_hospyearmed = median(yhat_`x')
	}

	collapse 	exposure_slope_hr exposure_slope_min 	///
				r0_abx12 yhat_abx12_hospyearmed			///
				r0_abx24 yhat_abx24_hospyearmed			///
				r0_abx48 yhat_abx48_hospyearmed			///
				r0_daysuse yhat_daysuse_hospyearmed		///
				r0_spec24hr yhat_spec24hr_hospyearmed		///
				r0_spec48hr yhat_spec48hr_hospyearmed		///
				r0_spec14day yhat_spec14day_hospyearmed		///
				r0_spec30day yhat_spec30day_hospyearmed		///
				r0_inhosp yhat_inhosp_hospyearmed		///
				r0_mort30 yhat_mort30_hospyearmed 	///
				r0_los7all yhat_los7all_hospyearmed ///
				r0_los7surv yhat_los7surv_hospyearmed	///
				r0_los10all yhat_los10all_hospyearmed	///
				r0_los10surv yhat_los10surv_hospyearmed	///
				r0_spec24hr40 yhat_spec24hr40_hospyearmed	///
				r0_spec24hr45 yhat_spec24hr45_hospyearmed	///
				r0_spec30d40 yhat_spec30d40_hospyearmed	///
				r0_spec30d45 yhat_spec30d45_hospyearmed		///
				r0_mdro yhat_mdro_hospyearmed 	///
				r0_mdroblood yhat_mdroblood_hospyearmed	/// 
				slope_tertile, by(hospid admityear)	

	bysort hospid (admityear): gen n=_n

	foreach x in  abx12 abx24 abx48 daysuse spec24hr spec48hr spec14day spec30day  ///
				  inhosp mort30 los7all los7surv los10all los10surv ///
				  spec24hr40 spec24hr45 spec30d40 spec30d45 ///
				  mdro mdroblood  {
		gen yhat_`x'_y1 = yhat_`x'_hospyearmed if n==1
		gen yhat_`x'_y6 = yhat_`x'_hospyearmed if n==6
		bysort hospid: egen yhat_`x'_y1_fill = max(yhat_`x'_y1)
		bysort hospid: egen yhat_`x'_y6_fill = max(yhat_`x'_y6)
		gen ave_change_peryear_`x' =(yhat_`x'_y6_fill-yhat_`x'_y1_fill)/5
		gen p_change_`x' = (yhat_`x'_y1_fill-yhat_`x'_y6_fill)/yhat_`x'_y1_fill	
	}	

	drop *y1* *y6*	
		
	order hospid admityear exposure* *abx12* *abx24* *abx48* *daysuse* *spec24* *spec48* *spec14* *spec30*	

		*save table4a_20220228, replace 

restore	


* open dataset	
use "Data\table4a_20220228.dta", clear	
	
* merge with hospitalization count dataset (see do file counting_hospitalizations)
merge m:1 hospid using "Data\count_avehospitalizations_byhospital_20211104, nogen

* merge in the spec48hr variables created in the addendum
merge 1:1 hospid admityear using "Data\hosp_avechangespec48hr_fortable4_20220316.dta", nogen

* drop the nosep variables from the addendum 
drop yhat_spec48hr40ns_hospyearmed yhat_spec48hr45ns_hospyearmed ave_change_peryear_spec48hr40ns ave_change_peryear_spec48hr45ns
	
* keep only variables we still need 
keep hospid exposure_slope_hr exposure_slope_min ave_change_peryear* r0_* n slope_tertile avecount_hosps_hospyear	
keep if n==1
drop if ave_change_peryear_abx12==.
rename avecount_hosps_hospyear avepophosp
	
* run diagnostics on OLS regression 
regress ave_change_peryear_abx12 exposure_slope_hr
lvr2plot, mlabel(hospid)
predict d1, cooksd
clist hospid ave_change_peryear_abx12 exposure_slope_hr d1 if d1>4/147, noobs
predict r1, rstandard 
gen absr1 = abs(r1)
gsort -absr1
clist hospid absr1 in 1/10, noobs
				
* check correlation coefficients	
foreach x in abx12 abx24 abx48 {	
	pwcorr ave_change_peryear_`x' exposure_slope_hr, sig
	spearman ave_change_peryear_`x' exposure_slope_hr, stats(rho p)
}

pwcorr ave_change_peryear_daysuse exposure_slope_hr, sig
spearman ave_change_peryear_daysuse exposure_slope_hr
return list

foreach x in spec24hr spec48hr spec14day spec30day {	
	pwcorr ave_change_peryear_`x' exposure_slope_hr, sig
	spearman ave_change_peryear_`x' exposure_slope_hr
}


*----------------
* ABX in 12 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx12 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_abx12 exposure_slope_hr, gen(weight_abx12)	

* pearson 
pwcorr ave_change_peryear_abx12 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_abx12 exposure_slope_hr	

*----------------
* ABX in 24 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx24 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_abx24 exposure_slope_hr, gen(weight_abx24)	

* pearson 
pwcorr ave_change_peryear_abx24 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_abx24 exposure_slope_hr	
	
*----------------
* ABX in 48 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx48 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_abx48 exposure_slope_hr, gen(weight_abx48)	


* pearson 
pwcorr ave_change_peryear_abx48 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_abx48 exposure_slope_hr	
	
*------------------
* Days of Therapy
*------------------

* spearman 
spearman ave_change_peryear_daysuse exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_daysuse exposure_slope_hr, gen(weight_daysuse)	

* pearson 
pwcorr ave_change_peryear_daysuse exposure_slope_hr, sig	
* regression
regress ave_change_peryear_daysuse exposure_slope_hr	
	
*------------------------
* Spectrum Score - 24hr
*------------------------
	
* spearman 
spearman ave_change_peryear_spec24hr exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec24hr exposure_slope_hr, gen(weight_spec24hr)	

* pearson 
pwcorr ave_change_peryear_spec24hr exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec24hr exposure_slope_hr	


*------------------------
* Spectrum Score - 48hr
*------------------------

* spearman 
spearman ave_change_peryear_spec48hr exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec48hr exposure_slope_hr, gen(weight_spec48hr)	

* pearson 
pwcorr ave_change_peryear_spec48hr exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec48hr exposure_slope_hr	
	

*------------------------
* Spectrum Score - 14day
*------------------------

* spearman 
spearman ave_change_peryear_spec14day exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec14day exposure_slope_hr, gen(weight_spec14day)	
	

* pearson 
pwcorr ave_change_peryear_spec14day exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec14day exposure_slope_hr	

*------------------------
* Spectrum Score - 30day
*------------------------

* spearman 
spearman ave_change_peryear_spec30day exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec30day exposure_slope_hr, gen(weight_spec30day)	
	
* pearson 
pwcorr ave_change_peryear_spec30day exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec30day exposure_slope_hr	


*------------------------
* Inhospital Mortality
*------------------------

* spearman 
spearman ave_change_peryear_inhosp exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_inhosp exposure_slope_hr, gen(weight_inhosp)	
	
* pearson 
pwcorr ave_change_peryear_inhosp exposure_slope_hr, sig	
* regression
regress ave_change_peryear_inhosp exposure_slope_hr	


*------------------------
* 30-day Mortality
*------------------------
	
* spearman 
spearman ave_change_peryear_mort30 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_mort30 exposure_slope_hr, gen(weight_mort30)

* pearson 
pwcorr ave_change_peryear_mort30 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_mort30 exposure_slope_hr	

*------------------------
* LOS - 7+ (all)
*------------------------

* spearman 
spearman ave_change_peryear_los7all exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_los7all exposure_slope_hr, gen(weight_los7all)	


* pearson 
pwcorr ave_change_peryear_los7all exposure_slope_hr, sig	
* regression
regress ave_change_peryear_los7all exposure_slope_hr	

*------------------------
* LOS - 7+ (survivor)
*------------------------

* spearman 
spearman ave_change_peryear_los7surv exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los7surv exposure_slope_hr, gen(weight_los7surv)	
	

* pearson 
pwcorr ave_change_peryear_los7surv exposure_slope_hr, sig	
* regression
regress ave_change_peryear_los7surv exposure_slope_hr	


*------------------------
* LOS - 10+ (all)
*------------------------

* spearman 
spearman ave_change_peryear_los10all exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los10all exposure_slope_hr, gen(weight_los10all)	


* pearson
pwcorr ave_change_peryear_los10all exposure_slope_hr, sig	
* regression
regress ave_change_peryear_los10all exposure_slope_hr	

*------------------------
* LOS - 10+ (survivor)
*------------------------

* spearman 
spearman ave_change_peryear_los10surv exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los10surv exposure_slope_hr, gen(weight_los10surv)	
	

* pearson
pwcorr ave_change_peryear_los10surv exposure_slope_hr, sig	
* regression
regress ave_change_peryear_los10surv exposure_slope_hr	


*---------------------
* Spectrum, 24hr 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec24hr40 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec24hr40 exposure_slope_hr, gen(weight_spec24hr40)	
	
* pearson 
pwcorr ave_change_peryear_spec24hr40 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec24hr40 exposure_slope_hr	


*---------------------
* Spectrum, 24hr 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec24hr45 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec24hr45 exposure_slope_hr, gen(weight_spec24hr45)	
	
* pearson 
pwcorr ave_change_peryear_spec24hr45 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec24hr45 exposure_slope_hr	


*---------------------
* Spectrum, 48hr 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec48hr40 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec48hr40 exposure_slope_hr, gen(weight_spec48hr40)	
	
* pearson 
pwcorr ave_change_peryear_spec48hr40 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec48hr40 exposure_slope_hr	


*---------------------
* Spectrum, 48hr 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec48hr45 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec48hr45 exposure_slope_hr, gen(weight_spec48hr45)	
	
* pearson 
pwcorr ave_change_peryear_spec48hr45 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec48hr45 exposure_slope_hr	


*---------------------
* Spectrum, 30d 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec30d40 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec30d40 exposure_slope_hr, gen(weight_spec30d40)	
	
* pearson 
pwcorr ave_change_peryear_spec30d40 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec30d40 exposure_slope_hr	


*---------------------
* Spectrum, 30d 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec30d45 exposure_slope_hr, stats(rho p)	
	
* robust regression
rreg ave_change_peryear_spec30d45 exposure_slope_hr, gen(weight_spec30d45)	
	

* pearson 
pwcorr ave_change_peryear_spec30d45 exposure_slope_hr, sig	
* regression
regress ave_change_peryear_spec30d45 exposure_slope_hr	

*------------
* Any MDRO
*------------

* spearman 
spearman ave_change_peryear_mdro exposure_slope_hr, stats(rho p)	
	
* robust regression
rreg ave_change_peryear_mdro exposure_slope_hr, gen(weight_mdro)	


* pearson
pwcorr ave_change_peryear_mdro exposure_slope_hr, sig	
* regression
regress ave_change_peryear_mdro exposure_slope_hr		

*------------
* Any MDRO
*------------

* spearman 
spearman ave_change_peryear_mdroblood exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_mdroblood exposure_slope_hr, gen(weight_mdroblood)	
	

* pearson
pwcorr ave_change_peryear_mdroblood exposure_slope_hr, sig	
* regression
regress ave_change_peryear_mdroblood exposure_slope_hr		

*-------------
* Figure 2
*-------------


* abx in 12, 24, 48 hrs	
foreach x in abx48 spec48hr daysuse {	
		
		* drop weights previously defined
		drop weight_`x'
		
		* robust regression
		rreg ave_change_peryear_`x' exposure_slope_hr, gen(weight_`x')	
			matrix list r(table) 
			matrix row=r(table) 
			matrix list row 
			local beta_`x'=row[1,1]
			local lowci_`x'=row[5,1]
			local hici_`x'=row[6,1]
			local pval_`x'=row[4,1]

			local b_`x': display %5.3f `beta_`x''
			local lci_`x': display %5.3f `lowci_`x''
			local hci_`x': display %5.3f `hici_`x''
			local p_`x': display %5.3f `pval_`x''

			di `b_`x'' 
			di `lci_`x'' 
			di `hci_`x'' 
			di `p_`x''

		* spearman 
		spearman ave_change_peryear_`x' exposure_slope_hr, stats(rho p)	
			return list
			local rho_`x': display %5.3f r(rho)
			display `rho_`x''
			local rho_p_`x': display %5.3f r(p)
			display `rho_p_`x''

		* figure	
		twoway 	(scatter ave_change_peryear_`x' exposure_slope_hr , msymbol(Oh) msize(small)) ///
				(lfit ave_change_peryear_`x' exposure_slope_hr [pweight=weight_`x']),	///
				legend(off) 			///
				note("Correlation coefficient=`rho_`x'', p-value=`rho_p_`x''" "Slope=`b_`x'' (`lci_`x'', `hci_`x''), p-value=`p_`x''", /// 
						position(8) ring(0) size(vsmall) margin(medsmall)) ///
				title("`x'", size(medsmall) just(left) margin(medium) color(black)) ///
				yline(0) ///
				ylab(, labsize(small) nogrid) graphregion(color(white)) ///
				xlab(, labsize(small)) ///
				ytitle("Yearly Change in `x'", size(small) margin(medsmall))	////
				xtitle("Yearly Change in Time-to-Antibiotics for Sepsis", size(small) margin(medsmall)) ///
				name(hospchange_`x', replace)
		
		*graph save "hospchange_`x'" "Figures\Figure2_`x'_20220302.gph", replace
		
}

graph combine 	"Figures\Figure2_abx48_20220302.gph" ///
				"Figures\Figure2_spec48hr_20220302.gph" ///
				"Figures\Figure2_daysuse_20220302.gph", ///
				rows(2) fysize(110) iscale(0.5) imargin(2 2 2 2) graphregion(color(white))


************
* eTable 5 *
************

* open dataset with predicted values from models
use Data\aim1_analytic_dataset_jamaimrr_20220228, clear		

* only keep the predicted values of the non-sepsis values
foreach x in 	abx12 abx24 abx48 daysuse  ///
				 spec24hr spec48hr spec14day spec30day  ///
				 inhosp mort30 los7all los7surv los10all los10surv ///
				 spec24hr40 spec24hr45 spec30d40 spec30d45 ///
				 mdro mdroblood  {

	drop r0_`x' yhat_`x' 			 
}					

drop _est_*

* rename yhat and r0 variables to drop ~_nosep so that the code is consistent
* with code for Table 4a
rename yhat_*_nosep yhat_*
rename r0_*_nosep r0_*

* drop sepsis patients -- for Table 4b, we're excluding sepsis patients from 
* the calculation of the outcome
drop if sepsample==1

* saving predicted values for additional analysis in Table 1

preserve

	foreach x in abx12 abx24 abx48 daysuse  ///
				 spec24hr spec48hr spec14day spec30day  ///
				 inhosp mort30 los7all los7surv los10all los10surv ///
				 spec24hr40 spec24hr45 spec30d40 spec30d45 ///
				 mdro mdroblood  {
		bysort hospid admityear: egen yhat_`x'_hospyearmed = median(yhat_`x')
	}

	collapse 	exposure_slope_hr exposure_slope_min 	///
				r0_abx12 yhat_abx12_hospyearmed			///
				r0_abx24 yhat_abx24_hospyearmed			///
				r0_abx48 yhat_abx48_hospyearmed			///
				r0_daysuse yhat_daysuse_hospyearmed		///
				r0_spec24hr yhat_spec24hr_hospyearmed		///
				r0_spec48hr yhat_spec48hr_hospyearmed		///
				r0_spec14day yhat_spec14day_hospyearmed		///
				r0_spec30day yhat_spec30day_hospyearmed		///
				r0_inhosp yhat_inhosp_hospyearmed		///
				r0_mort30 yhat_mort30_hospyearmed 	///
				r0_los7all yhat_los7all_hospyearmed ///
				r0_los7surv yhat_los7surv_hospyearmed	///
				r0_los10all yhat_los10all_hospyearmed	///
				r0_los10surv yhat_los10surv_hospyearmed	///
				r0_spec24hr40 yhat_spec24hr40_hospyearmed	///
				r0_spec24hr45 yhat_spec24hr45_hospyearmed	///
				r0_spec30d40 yhat_spec30d40_hospyearmed	///
				r0_spec30d45 yhat_spec30d45_hospyearmed		///
				r0_mdro yhat_mdro_hospyearmed 	///
				r0_mdroblood yhat_mdroblood_hospyearmed	/// 
				slope_tertile, by(hospid admityear)	

	bysort hospid (admityear): gen n=_n

	foreach x in  abx12 abx24 abx48 daysuse spec24hr spec48hr spec14day spec30day  ///
				  inhosp mort30 los7all los7surv los10all los10surv ///
				  spec24hr40 spec24hr45 spec30d40 spec30d45 ///
				  mdro mdroblood  {
		gen yhat_`x'_y1 = yhat_`x'_hospyearmed if n==1
		gen yhat_`x'_y6 = yhat_`x'_hospyearmed if n==6
		bysort hospid: egen yhat_`x'_y1_fill = max(yhat_`x'_y1)
		bysort hospid: egen yhat_`x'_y6_fill = max(yhat_`x'_y6)
		gen ave_change_peryear_`x' =(yhat_`x'_y6_fill-yhat_`x'_y1_fill)/5
		gen p_change_`x' = (yhat_`x'_y1_fill-yhat_`x'_y6_fill)/yhat_`x'_y1_fill	
	}	

	drop *y1* *y6*	
		
	order hospid admityear exposure* *abx12* *abx24* *abx48* *daysuse* *spec24* *spec48* *spec14* *spec30*	

		*save "Data\table4b_20220228.dta", replace 

restore	


* open dataset	
use "Data\table4b_20220228.dta", clear	

* merge in the spec48hr variables created in the addendum
merge 1:1 hospid admityear using "Data\hosp_avechangespec48hr_fortable4_20220316.dta", nogen

* drop the sepsis variables that we don't need from the addendum 
drop yhat_spec48hr40_hospyearmed yhat_spec48hr45_hospyearmed ave_change_peryear_spec48hr40 ave_change_peryear_spec48hr45
	
* keep only variables we still need 
keep hospid exposure_slope_hr exposure_slope_min ave_change_peryear* r0_* n slope_tertile 	
keep if n==1
drop if ave_change_peryear_abx12==.
	
* run diagnostics on OLS regression 
regress ave_change_peryear_abx12 exposure_slope_hr
lvr2plot, mlabel(hospid)
predict d1, cooksd
clist hospid ave_change_peryear_abx12 exposure_slope_hr d1 if d1>4/147, noobs
predict r1, rstandard 
gen absr1 = abs(r1)
gsort -absr1
clist hospid absr1 in 1/10, noobs
				
* check correlation coefficients	
foreach x in abx12 abx24 abx48 {	
	pwcorr ave_change_peryear_`x' exposure_slope_hr, sig
	spearman ave_change_peryear_`x' exposure_slope_hr, stats(rho p)
}

pwcorr ave_change_peryear_daysuse exposure_slope_hr, sig
spearman ave_change_peryear_daysuse exposure_slope_hr
return list

foreach x in spec24hr spec48hr spec14day spec30day {	
	pwcorr ave_change_peryear_`x' exposure_slope_hr, sig
	spearman ave_change_peryear_`x' exposure_slope_hr
}


*----------------
* ABX in 12 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx12 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_abx12 exposure_slope_hr, gen(weight_abx12)	
	

*----------------
* ABX in 24 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx24 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_abx24 exposure_slope_hr, gen(weight_abx24)	
	
*----------------
* ABX in 48 hrs
*----------------

* spearman 
spearman ave_change_peryear_abx48 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_abx48 exposure_slope_hr, gen(weight_abx48)	
	
*------------------
* Days of Therapy
*------------------

* spearman 
spearman ave_change_peryear_daysuse exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_daysuse exposure_slope_hr, gen(weight_daysuse)	
	
*------------------------
* Spectrum Score - 24hr
*------------------------
	
* spearman 
spearman ave_change_peryear_spec24hr exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec24hr exposure_slope_hr, gen(weight_spec24hr)	


*------------------------
* Spectrum Score - 48hr
*------------------------

* spearman 
spearman ave_change_peryear_spec48hr exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec48hr exposure_slope_hr, gen(weight_spec48hr)	
	

*------------------------
* Spectrum Score - 14day
*------------------------

* spearman 
spearman ave_change_peryear_spec14day exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec14day exposure_slope_hr, gen(weight_spec14day)	
	

*------------------------
* Spectrum Score - 30day
*------------------------

* spearman 
spearman ave_change_peryear_spec30day exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_spec30day exposure_slope_hr, gen(weight_spec30day)	
	

*------------------------
* Inhospital Mortality
*------------------------

* spearman 
spearman ave_change_peryear_inhosp exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_inhosp exposure_slope_hr, gen(weight_inhosp)	
	

*------------------------
* 30-day Mortality
*------------------------
	
* spearman 
spearman ave_change_peryear_mort30 exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_mort30 exposure_slope_hr, gen(weight_mort30)

*------------------------
* LOS - 7+ (all)
*------------------------

* spearman 
spearman ave_change_peryear_los7all exposure_slope_hr, stats(rho p)	
			
* robust regression
rreg ave_change_peryear_los7all exposure_slope_hr, gen(weight_los7all)	


*------------------------
* LOS - 7+ (survivor)
*------------------------

* spearman 
spearman ave_change_peryear_los7surv exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los7surv exposure_slope_hr, gen(weight_los7surv)	
	


*------------------------
* LOS - 10+ (all)
*------------------------

* spearman 
spearman ave_change_peryear_los10all exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los10all exposure_slope_hr, gen(weight_los10all)	
	

*------------------------
* LOS - 10+ (survivor)
*------------------------

* spearman 
spearman ave_change_peryear_los10surv exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_los10surv exposure_slope_hr, gen(weight_los10surv)	
	

*---------------------
* Spectrum, 24hr 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec24hr40 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec24hr40 exposure_slope_hr, gen(weight_spec24hr40)	
	

*---------------------
* Spectrum, 24hr 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec24hr45 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec24hr45 exposure_slope_hr, gen(weight_spec24hr45)	


*---------------------
* Spectrum, 48hr 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec48hr40ns exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec48hr40ns exposure_slope_hr, gen(weight_spec48hr40)	


*---------------------
* Spectrum, 48hr 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec48hr45ns exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec48hr45ns exposure_slope_hr, gen(weight_spec48hr45)	
	
	

*---------------------
* Spectrum, 30d 40+
*---------------------

* spearman 
spearman ave_change_peryear_spec30d40 exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_spec30d40 exposure_slope_hr, gen(weight_spec30d40)	
	

*---------------------
* Spectrum, 30d 45+
*---------------------

* spearman 
spearman ave_change_peryear_spec30d45 exposure_slope_hr, stats(rho p)	
	
* robust regression
rreg ave_change_peryear_spec30d45 exposure_slope_hr, gen(weight_spec30d45)	
	

*------------
* Any MDRO
*------------

* spearman 
spearman ave_change_peryear_mdro exposure_slope_hr, stats(rho p)	
	
* robust regression
rreg ave_change_peryear_mdro exposure_slope_hr, gen(weight_mdro)	
	

*------------
* Any MDRO
*------------

* spearman 
spearman ave_change_peryear_mdroblood exposure_slope_hr, stats(rho p)	

* robust regression
rreg ave_change_peryear_mdroblood exposure_slope_hr, gen(weight_mdroblood)	
	
log close