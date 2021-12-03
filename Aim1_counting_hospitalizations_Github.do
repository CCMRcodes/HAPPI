* ----------------------------------------------------------------------
*
*  	Counting number of hospitalizations per year for each hospital
* 		to use for merging with the collapsed dataset for Figs 2 & 3
* 		in Aim1_step2_analysis file (at end of program)
*
* 	Created: 		2021 JUN 10
* 	Last updated: 	2021 DEC 2
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

local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using counting_hospitalizations_`day', replace

	
use aim1_analytic_dataset, clear		

count 
	* 1,560,126

*drop hospitals with 1-15 sepsis patients 
		* see Aim1_step_mkg_exposure do file -- these hospitals were dropped
		* from exposure
drop if inlist(hospid, "A", "B", "C", "D")	
		* drop 596 patients from 4 hospitals 

* drop hospitals without a slope tertile (these are hospitals with 0 sepsis patients)
tab hospid if slope_tertile==.
drop if inlist(hospid, "E", "F", "G", "H")
		* drop 7 patients from 4 hospitals 

count 
	* 1,559,523

* count hospitalizations for each hospital-year 
bysort hospid admityear: gen count_hosps_hospyear = _N

* collapse and find average hospitalizations over 6 years
collapse count_hosps_hospyear, by(hospid admityear)
bysort hospid: egen avecount_hosps_hospyear = mean(count_hosps_hospyear)
bysort hospid: keep if _n==1
keep hospid avecount_hosps_hospyear

save count_avehospitalizations_byhospital, replace


log close 

