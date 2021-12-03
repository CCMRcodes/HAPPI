/* 	This file brings in comorbidities, AODs, subpopulations, and abx delivery 
	(community onset infection) variables to create final HAPPI dataset.
	
	Sarah Seelye
	Last Updated: 29 Oct 2021
*/

clear all
cap log close
cap more off
version 15.1

cd ""
		
local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using step5mkghappi_`day'", replace


** START WITH STEP 3 OF THE HAPPI DATASET **
use step3_HAPPI_20132018, clear

* check cohort size
count // 8,095,111
tab hospital_day if hospital_day==1 //1,100,996

* save temporary file
tempfile happi
save `happi'

********************************************************************************
**								 COMORBIDITIES								  **
********************************************************************************

** 540 DAY COMORBIDITIES LOOKBACK **

* pull in full comorbidity file		
use happi_comorbidprior540_20201203, clear
count 

* save temporary file
tempfile comorbid
save `comorbid'

* use happi dataset to merge with comorbidity 540 day lookback dataset
use `happi'
merge m:1 unique_hosp_count_id using `comorbid'

* drop anyone not matched. these are comorbidities for hospitalizations 
* from the old cohort (created in May)
drop if _merge==2

* check cohort size
count // 8,095,111
tab hospital_day if hospital_day==1 //1,100,996

drop _merge


********************************************************************************
**   		SUBPOPULATIONS, AOD, & ADDITIONAL ABX-RELATED VARIABLES 		  **
********************************************************************************

* Bring in variables from the new_step3_mkgHAPPI dataset 

merge m:1 unique_hosp_count_id using aod_abx_subpop_HAPPI_20132018
drop _merge
drop merge_cprs orderableitemname

* save new dataset
compress
save happi_20132018, replace

log close

