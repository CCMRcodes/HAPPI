* ------------------------------------------------------------------------------
*
*  Create the exposure variable to be used in the outcome analysis 
*
* 	Created: 		2021 Jul 02
* 	Last updated: 	2021 Dec 02
* 	Author: 		S. Seelye
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

use kp_va_happi, clear
	
local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using Aim1_exposure_`day', replace

*------------------
* New Variables
*------------------

* create new outcome variables - antibiotics in 12/24 hours 
gen abx_in_12hr = time_to_abx_min<=720
tab abx_in_12hr
sum time_to_abx_min time_to_abx_hr if abx_in_12hr==1

* any type of cancer (metastatic & w/o metastasis)
gen cancer_any = .
replace cancer_any=1 if cancer_met==1 | cancer_nonmet==1
replace cancer_any=0 if missing(cancer_any)
tab cancer_any cancer_met 
tab cancer_any cancer_nonmet
tab cancer_met cancer_nonmet
tab cancer_met cancer_nonmet if data=="va"
tab cancer_met cancer_nonmet if data=="kp"

* count number of acute organ dysfunctions
gen aod_sum =  	aod_lactate + aod_kidney + pressor_in_72hr + aod_liver +	///
				aod_heme + aod_lung

* create the sample for the exposure variable: 
	* patients with severe_sepsis or septic_shock within 12hr
gen sample = 0
replace sample = 1 if abx_in_12hr & (septic_shock | severe_sepsis)				
tab sample

* create indictor for VA data 
gen va = data=="va"

* encode hospid 
encode hospid, gen(hospid_enc)

* create year variable
gen year = .
replace year = 1 if admityear==2013
replace year = 2 if admityear==2014
replace year = 3 if admityear==2015
replace year = 4 if admityear==2016
replace year = 5 if admityear==2017
replace year = 6 if admityear==2018

* save tempfile to merge in tertile classifications 
tempfile happi 
save `happi'

*----------------------------
* Create Exposure Variable
*----------------------------

* Only Keep Sepsis Hospitalizations for the Exposure 
keep if sample==1


* first, drop hospitals with <15 sepsis patients 
	* check number of sepsis patients per hospital
	preserve
	bysort hospid: gen sep_hosp_count = _N
	bysort hospid: gen hosp_count = _n
	keep if hosp_count==1

	sum sep_hosp_count, detail
	list hospid sep_hosp_count if sep_hosp_count<15
	sum sep_hosp_count if sep_hosp_count>=15, detail
	restore 

	* drop hospitals that have fewer than 15 sepsis hospitalizations
	drop if inlist(hospid, "A", "B", "C", "D")	
		* drop 18 patients from 4 hospitals 


* tag hospitals 
egen taghosp = tag(hospid_enc) // 152 hospitals with >15 sepsis 
egen taghospquart = tag(hospid_enc quarter)
egen taghospyear = tag(hospid_enc year)

* mixed linear random slope model 
local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
mixed time_to_abx_hr c.year c.age male `sirs' `aod' `comorbid' va || hospid_enc: year, cov(unstr)

estimates store exposure_hr

predict exposure_predhr, fitted 
predict r1_hr r0_hr, reffects reses(expos_resehr*)

gen exposure_intercept_hr = _b[_cons] + r0_hr
gen exposure_slope_hr = _b[year] + r1_hr

xtile tertile_hr = exposure_slope_hr if taghosp==1, nq(3) 
bysort tertile_hr: sum exposure_slope_hr if taghosp==1, det
label define tertile_hr 1 "rapid accelerators" 					///
						 2 "slow accelerators"						///
						 3 "flat accelerators"
label values tertile_hr tertile_hr

bysort hospid_enc: egen maxtert_hr = max(tertile_hr)
gen slope_tertile_hr = maxtert_hr

bysort slope_tertile_hr year: sum exposure_predhr, de

preserve 

*spaghetti plot
sort hospid_enc year

forval i=1/3 {
	spagplot exposure_predhr year if slope_tertile_hr==`i' , id(hospid)  ///
		name(spag_tert`i', replace) ylab(0(2)8, grid gmax) note("") ///
		graphregion(color(white)) 		///
		ytitle("Time to antibiotics, h") ylab(0(2)8, angle(0) grid gmax)		///
		xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
		title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left)) 
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
		
		*graph save spag_tert`i', replace

}

* combine graphs 
graph combine spag_tert1 spag_tert2 spag_tert3,	///
	  rows(1) fysize(60) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
	  name(spag_combine, replace)

		*graph save Figure1_spag_tertiles, replace	  

		
* fit fully adjusted model using year as a continuous variable with minute outcome
* variable for paper text & Supplemental Table 3		

sum age, det
gen agegrp = .
replace agegrp = 1 if age>=18 & age<35
replace agegrp = 2 if age>=35 & age<50
replace agegrp = 3 if age>=50 & age<65
replace agegrp = 4 if age>=65 & age<80
replace agegrp = 5 if age>=80

local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 

regress time_to_abx_min `comorbid'
predict comorbid_timemin


local comorbid 															///
		cancer_nonmet cancer_met pulm chf dm_uncomp dm_comp	liver neuro ///
		renal htn cardic_arrhym valvular_d2 pulm_circ pvd paralysis 	///
		pud hypothyroid ah lymphoma ra coag obesity wtloss fen			///
		anemia_cbl anemia_def etoh drug psychoses depression 

local demograph 																///
		age male

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
meglm time_to_abx_min c.year c.age male `sirs' `aod' `comorbid' va || hospid_enc: year, cov(unstr)		

estimates store exposure_min 
		
estat icc		
predict exposure_predmin, fitted
predict minhat, fitted

predict r1_min r0_min, reffects reses(expos_resemin*)

margins, dydx(year)

gen exposure_intercept_min = _b[_cons] + r0_min
gen exposure_slope_min = _b[year] + r1_min


	program aveyrchg, rclass 
		version 16
		sum minhat if year==1, det
		local minhatyr1 = r(p50)
		sum minhat if year==6, det
		local minhatyr6 = r(p50)
		return scalar avechange = (`minhatyr1'-`minhatyr6')/5
	end 

	bootstrap r(avechange), reps(1000) seed(5649): aveyrchg

* create slope tertiles 		
sum exposure_slope_min if taghosp==1, det
xtile tertile_min = exposure_slope_min if taghosp==1, nq(3) 
bysort tertile_min: sum exposure_slope_min if taghosp==1, det
label define tertile_min 1 "rapid accelerators" 					///
						 2 "slow accelerators"						///
						 3 "flat accelerators"
label values tertile_min tertile_min

bysort hospid_enc: egen maxtert_min = max(tertile_min)
gen slope_tertile = maxtert_min

label define slope_tertile 1 "rapid accelerators" 					///
						 2 "slow accelerators"						///
						 3 "flat accelerators"
label values slope_tertile slope_tertile						 

table admityear, c(median exposure_predmin mean exposure_predmin)	
table admityear if slope_tertile==1, c(median exposure_predmin mean exposure_predmin)	
table admityear if slope_tertile==2, c(median exposure_predmin mean exposure_predmin)	
table admityear if slope_tertile==3, c(median exposure_predmin mean exposure_predmin)	

bysort slope_tertile: sum exposure_slope_min if taghosp==1, det

	program aveyrchg_tert1, rclass 
		version 16
		sum minhat if year==1 & slope_tertile==1, det
		local minhatyr1t1 = r(p50)
		sum minhat if year==6 & slope_tertile==1, det
		local minhatyr6t1 = r(p50)
		return scalar avechange_tert1 = (`minhatyr1t1'-`minhatyr6t1')/5
	end 
	
	bootstrap r(avechange_tert1), reps(1000) seed(1234): aveyrchg_tert1


	program aveyrchg_tert2, rclass 
		version 16
		sum minhat if year==1 & slope_tertile==2, det
		local minhatyr1t2 = r(p50)
		sum minhat if year==6 & slope_tertile==2, det
		local minhatyr6t2 = r(p50)
		return scalar avechange_tert2 = (`minhatyr1t2'-`minhatyr6t2')/5
	end 
	
	bootstrap r(avechange_tert2), reps(1000) seed(1234): aveyrchg_tert2


	program aveyrchg_tert3, rclass 
		version 16
		sum minhat if year==1 & slope_tertile==3, det
		local minhatyr1t3 = r(p50)
		sum minhat if year==6 & slope_tertile==3, det
		local minhatyr6t3 = r(p50)
		return scalar avechange_tert3 = (`minhatyr1t3'-`minhatyr6t3')/5
	end 
	
	bootstrap r(avechange_tert3), reps(1000) seed(1234): aveyrchg_tert3

oneway exposure_slope_min slope_tertile, tab
pwmean exposure_slope_min, over(slope_tertile) mcompare(tukey) effects
kwallis exposure_slope_min, by(slope_tertile)

* create baseline time-to-abx values for each sta6a using first 2 quarters that
* hospitals are in dataset; not all hospitals are present in quarter 1 & 2,
* so first identify the first and second quarters when each hospital first
* appears
gsort hospid_enc quarter -taghospquart
bysort hospid_enc (quarter): gen first2quarters_mkg =  sum(taghospquart)
gen first2quarters = inlist(first2quarters_mkg, 1, 2)
tab quarter first2quarters

bysort hospid_enc (quarter): egen t2a_basehosp = median(time_to_abx_min) if first2quarters==1
bysort hospid_enc (quarter): replace t2a_basehosp = t2a_basehosp[_n-1] if t2a_basehosp==.
sum t2a_basehosp if taghosp==1, det
					
* create tertiles for the hospital baseline
xtile baseline_tertile = t2a_basehosp if taghosp==1, nq(3)			
bysort baseline_tertile: sum t2a_basehosp if taghosp==1, det

gsort hospid_enc -baseline_tertile
by hospid_enc: replace baseline_tertile = baseline_tertile[_n-1] if baseline_tertile==.
tab baseline_tertile if taghosp

label define baseline_tertile 1 "fastest baseline t2a" 		///
					 2 "middle baseline t2a"						///
					 3 "slowest baseline t2a", replace
label values baseline_tertile baseline_tertile

bysort baseline_tertile: sum t2a_basehosp, det

tab baseline_tertile slope_tertile if taghosp==1, chi2 cell

* number of hospitals in each slope tertile by healthcare system
tab slope_tertile data if taghosp==1

	* checking slopes - minute
	bysort hospid year: egen median_predmin_hospyear = median(exposure_predmin)
	gen median_predmin_hospyr1 = median_predmin_hospyear if year==1
	gen median_predmin_hospyr6 = median_predmin_hospyear if year==6
	bysort hospid: egen median_predmin_hospyr1_fill = max(median_predmin_hospyr1)
	bysort hospid: egen median_predmin_hospyr6_fill = max(median_predmin_hospyr6)
	gen median_predmin_hospslope = (median_predmin_hospyr6_fill-median_predmin_hospyr1_fill)/5

		preserve
		collapse median_predmin_hospslope exposure_slope_min, by(hospid)	
		list hospid median_predmin_hospslope exposure_slope_min 
		restore
	
	* checking slopes - hour
	bysort hospid year: egen median_predhr_hospyear = median(exposure_predhr)
	gen median_predhr_hospyr1 = median_predhr_hospyear if year==1
	gen median_predhr_hospyr6 = median_predhr_hospyear if year==6
	bysort hospid: egen median_predhr_hospyr1_fill = max(median_predhr_hospyr1)
	bysort hospid: egen median_predhr_hospyr6_fill = max(median_predhr_hospyr6)
	gen median_predhr_hospslope = (median_predhr_hospyr6_fill-median_predhr_hospyr1_fill)/5

		preserve
		collapse median_predhr_hospslope exposure_slope_hr, by(hospid)	
		list hospid median_predhr_hospslope exposure_slope_hr 
		restore
	
* keep only the slope tertile and baseline tertile classifications for each hospital 
keep if taghosp==1
keep hospid slope_tertile baseline_tertile exposure_slope_hr exposure_slope_min

* save tempfile to merge back to full happi dataset 
tempfile tertile 
save `tertile'

* merge tertiles into full happi dataset 
use `happi', clear 
merge m:1 hospid using `tertile'

drop _merge 

* save analytic dataset 
save aim1_analytic_dataset, replace 

log close 
