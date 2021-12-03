* ----------------------------------------------------------------------
*
*  	Step 2 Outcome Analysis - Spillover
*
* 	Created: 		2021 JUN 10
* 	Last updated: 	2021 Dec 2
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

local c_date = c(current_date)
local c_time = c(current_time)
local c_time_date = "`c_date'"+"_" +"`c_time'"
local time_string = subinstr("`c_time_date'", ":", "_", .)
local time_string = subinstr("`time_string'", " ", "_", .)
display "`time_string'"

log using Aim1_analysis_`time_string', replace

* use the dataset constructed in Aim1_mkg_exposure do file,
* which uses the joint KP-VA dataset to identify sepsis hospitalizations
* for creation of the exposure variable. 

use aim1_analytic_dataset, clear		

count 
	* 1,560,126

* count hospitalizations in each tertile, and unassigned 
tab slope_tertile, m	
tab slope_tertile if sample, m
	
* drop hospitals without a slope tertile (these are hospitals with 0 sepsis patients)
tab hospid if slope_tertile==.
drop if inlist(hospid, "E", "F", "G", "H")
		* drop 7 patients from 4 hospitals 

*drop hospitals with 1-15 sepsis patients 
		* see Aim1_step_mkg_exposure do file -- these hospitals were dropped
		* from exposure
drop if inlist(hospid, "A", "B", "C", "D")	
		* drop 596 patients from 4 hospitals 

count 
	* 1,559,523
		
		
*------------------
* New Variables
*------------------

* create new outcome variables - antibiotics in 24 hours 
gen abx_in_24hr = time_to_abx_min<=1440

tab abx_in_12hr
tab abx_in_24hr
tab abx_in_48hr

* tag hospitals 
egen taghosp = tag(hospid)

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


*----------
* Text
*----------
 
* median time-to-antibiotics decline overall & by tertile 
preserve

	keep if sample==1
	
		** Unadjusted **
		* overall decline in t2abx
		sum time_to_abx_min if admityear==2013, de 
		local med_t2abx_2013 = r(p50)
		
		sum time_to_abx_min if admityear==2018, de 
		local med_t2abx_2018 = r(p50)

		display (`med_t2abx_2013'-`med_t2abx_2018')/5
		
		* decline by tertile 
		forval i=1/3 {
			sum time_to_abx_min if admityear==2013 & slope_tertile==`i', de 
			local med_t2abx_2013_t`i' = r(p50)
			
			sum time_to_abx_min if admityear==2018 & slope_tertile==`i', de 
			local med_t2abx_2018_t`i' = r(p50)

			display (`med_t2abx_2013_t`i''-`med_t2abx_2018_t`i'')/5
		}
	 
		regress time_to_abx_min i.slope_tertile c.year 
		regress time_to_abx_min i.slope_tertile##c.year 
		margins slope_tertile, dydx(year)  
		margins slope_tertile, at(year=(1(1)6)) 
		marginsplot
	 
		nptrend time_to_abx_min , by(slope_tertile)
		
		** Adjusted **
		sum exposure_slope_min
		
restore

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


********************************************************************************
*								RAW DATA PLOTS						  		   *
********************************************************************************


*-----------------------------------
* ANTIBIOTICS - RAW
*-----------------------------------

* 12, 24, 48 hours 

foreach x in 12hr 24hr 48hr {
	
	tab abx_in_`x'
	bysort slope_tertile: tab abx_in_`x'

	* create hospital-year proportions
		preserve 
			* create proportion by hospital year 
			bysort hospid_enc year: gen hospitalyear_pat_count = _N
			bysort hospid_enc year: egen hospitalyear_abx`x'_count = total(abx_in_`x')
			bysort hospid_enc year : gen p_abx`x'_hospitalyear = hospitalyear_abx`x'_count/hospitalyear_pat_count

			* check if hospitals have 0% abx prescribing 
			sum p_abx`x'_hospitalyear
			
		* create parallel coordinates plot
		
			collapse p_abx`x'_hospitalyear , by(hospid hospid_enc year slope_tertile)
			
			label define slope_tertile 1 "Tertile 1" 2 "Tertile 2" 3 "Tertile 3", replace
			label val slope_tertile slope_tertile
							
			* reorganzing data for making parplots 
			forval i=1/6 {
			gen year`i' = 0
			replace year`i' = p_abx`x'_hospitalyear if year==`i'
			}
			
			parplot year1 year2 year3 year4 year5 year6 if slope_tertile==1
			drop year1-year6
			
			bysort hospid_enc: gen flag = 1 if slope_tertile!=slope_tertile[_n-1] & _n!=1
			replace flag=0 if flag==.
			bysort hospid_enc: egen max_flag = max(flag)
			bysort hospid_enc: egen slope_tertile_max = max(slope_tertile)
			
			keep hospid_enc year p_abx`x'_hospitalyear slope_tertile_max
			
			reshape wide p_abx`x'_hospitalyear, i(hospid_enc) j(year)
			
			rename p_abx`x'_hospitalyear1 y1
			rename p_abx`x'_hospitalyear2 y2
			rename p_abx`x'_hospitalyear3 y3
			rename p_abx`x'_hospitalyear4 y4
			rename p_abx`x'_hospitalyear5 y5
			rename p_abx`x'_hospitalyear6 y6

			label define slope_tertile_max 1 "Tertile 1" 2 "Tertile 2" 3 "Tertile 3"
			label val slope_tertile_max slope_tertile_max
			
			* parallel coordinates plots
			parplot y1 y2 y3 y4 y5 y6 ,	by(slope_tertile, total 		///
					rows(1) iscale(0.55) imargin(2 2 2 2)  ///	
					graphregion(color(white)) plotregion(color(white)) ///
					title("Antimicrobials within `x'", size(medsmall) ///
							color(black) margin(small) position(11) justification(left))) ///
					graphregion(color(white)) plotregion(color(white)) ///
					graphregion(fcolor(white)) plotregion(fcolor(white)) ///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018", labsize(small)) ///
					ylabel(0 "0" 0.5 ".5" 1 "1" , labsize(small) angle(0)) msymbol(none) lwidth(vthin) lcolor(%85) ///
					subtitle( , size(small)) tr(raw) fysize(48)
				
				gr_edit .note.text = {}
				gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.yaxis1[1].style.editstyle linestyle(color(none)) editcopy
				gr_edit .plotregion1.yaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
				gr_edit .plotregion1.xaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
				
					
					*graph save parplot_abx`x'_raw, replace
				
			restore

}	
	

*-------------------------------------
* Days of Antibiotics Therapy - RAW
*-------------------------------------

sum abx_days_use_30, d
bysort slope_tertile: sum abx_days_use_30, d

* create hospital-year proportions
	preserve 
		bysort hospid_enc year: egen abxdays_hospitalyear = mean(abx_days_use_30)

	* create parallel coordinates plot
	
		collapse abxdays_hospitalyear , by(hospid_enc year slope_tertile)
		sort hospid_enc year
		
		* reorganzing data for making parplots 
		forval i=1/6 {
		gen year`i' = 0
		replace year`i' = abxdays_hospitalyear if year==`i'
		}
		
		parplot year1 year2 year3 year4 year5 year6 if slope_tertile==1
		drop year1-year6
		
		bysort hospid_enc: gen flag = 1 if slope_tertile!=slope_tertile[_n-1] & _n!=1
		replace flag=0 if flag==.
		bysort hospid_enc: egen max_flag = max(flag)
		bysort hospid_enc: egen slope_tertile_max = max(slope_tertile)
		
		keep hospid_enc year abxdays_hospitalyear slope_tertile_max
		
		reshape wide abxdays_hospitalyear, i(hospid_enc) j(year)
		
		rename abxdays_hospitalyear1 y1
		rename abxdays_hospitalyear2 y2
		rename abxdays_hospitalyear3 y3
		rename abxdays_hospitalyear4 y4
		rename abxdays_hospitalyear5 y5
		rename abxdays_hospitalyear6 y6

		label define slope_tertile_max 1 "Tertile 1" 2 "Tertile 2" 3 "Tertile 3"
		label val slope_tertile_max slope_tertile_max
		
		* parallel coordinates plots
		parplot y1 y2 y3 y4 y5 y6 ,	by(slope_tertile, total 		///
				rows(1) iscale(0.55) imargin(2 2 2 2)  ///	
				graphregion(color(white)) plotregion(color(white)) ///
				title("Days of antimicrobial therapy", size(medsmall) ///
						color(black) margin(small) position(11) justification(left))) ///
				graphregion(color(white)) plotregion(color(white)) ///
				graphregion(fcolor(white)) plotregion(fcolor(white)) ///
				xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018", labsize(small)) ///
				ylabel( , labsize(small) angle(0)) msymbol(none) lwidth(vthin) lcolor(%85) ///
				subtitle( , size(small)) tr(raw) fysize(48)
			
			gr_edit .note.text = {}
			gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
			gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
			gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
			gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
			gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
			gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
			gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
			gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
			gr_edit .plotregion1.yaxis1[1].style.editstyle linestyle(color(none)) editcopy
			gr_edit .plotregion1.yaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
			gr_edit .plotregion1.xaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
			
				*graph save parplot_abxdays_raw, replace
			
		restore	


*--------------------------
* Spectrum Score
*--------------------------

* 24hr, 48hr, 14day, 30day

foreach x in 24hr 48hr 14day 30day {

	sum cumulative_spectrum_`x', d
	bysort slope_tertile: sum cumulative_spectrum_`x', d

	* create hospital-year proportions
		preserve 
			bysort hospid_enc year: egen spec`x'_hospitalyear = mean(cumulative_spectrum_`x')

		* create parallel coordinates plot
		
			collapse spec`x'_hospitalyear , by(hospid_enc year slope_tertile)
			sort hospid_enc year
			
			* first look at two way line
			twoway (line spec`x'_hospitalyear year, by(slope_tertile)  connect(ascending)) 
		
			* reorganzing data for making parplots 
			forval i=1/6 {
			gen year`i' = 0
			replace year`i' = spec`x'_hospitalyear if year==`i'
			}
			
			parplot year1 year2 year3 year4 year5 year6 if slope_tertile==1
			drop year1-year6
			
			bysort hospid_enc: gen flag = 1 if slope_tertile!=slope_tertile[_n-1] & _n!=1
			replace flag=0 if flag==.
			bysort hospid_enc: egen max_flag = max(flag)
			bysort hospid_enc: egen slope_tertile_max = max(slope_tertile)
			
			keep hospid_enc year spec`x'_hospitalyear slope_tertile_max
			
			reshape wide spec`x'_hospitalyear, i(hospid_enc) j(year)
			
			rename spec`x'_hospitalyear1 y1
			rename spec`x'_hospitalyear2 y2
			rename spec`x'_hospitalyear3 y3
			rename spec`x'_hospitalyear4 y4
			rename spec`x'_hospitalyear5 y5
			rename spec`x'_hospitalyear6 y6

			label define slope_tertile_max 1 "Tertile 1" 2 "Tertile 2" 3 "Tertile 3"
			label val slope_tertile_max slope_tertile_max
			
			* parallel coordinates plots
			parplot y1 y2 y3 y4 y5 y6 ,	by(slope_tertile, total 		///
					rows(1) iscale(0.55) imargin(2 2 2 2)  ///	
					graphregion(color(white)) plotregion(color(white)) ///
					title("Broadness of coverage `x'", size(medsmall) ///
							color(black) margin(small) position(11) justification(left))) ///
					graphregion(color(white)) plotregion(color(white)) ///
					graphregion(fcolor(white)) plotregion(fcolor(white)) ///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018", labsize(small)) ///
					ylabel( , labsize(small) angle(0)) msymbol(none) lwidth(vthin) lcolor(%85) ///
					subtitle( , size(small)) tr(raw) fysize(48)
				
				gr_edit .note.text = {}
				gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[1]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[2]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[3]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(color(black)) editcopy 
				gr_edit .plotregion1.plotregion1[4]._xylines[3].style.editstyle linestyle(width(vvthin)) editcopy
				gr_edit .plotregion1.yaxis1[1].style.editstyle linestyle(color(none)) editcopy
				gr_edit .plotregion1.yaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
				gr_edit .plotregion1.xaxis1[3].style.editstyle majorstyle(tickstyle(show_ticks(no))) editcopy
				
				*graph save parplot_spec`x'_raw, replace
				
			restore	
				
}
			

********************************************************************************
*								ANTIBIOTIC THERAPY						       *
*									ADJUSTED								   *
********************************************************************************
		
*----------------------------
* ANTIBIOTICS IN 12 HOURS 
*----------------------------

tab year abx_in_12hr, ro

* mixed logit model

local aod 														///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs														///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_12hr i.slope_tertile##c.year 					///
		c.age male `sirs' `aod' comorbid_12hr va || hospid_enc: , or

estimates store abx12hr		
predict yhat_abx12, mu
predict r0_abx12, reffects

estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose
	margins, at(year=(1(1)6)) nose
	
	margins slope_tertile, dydx(year) nose 
	
	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Antibiotics in 12 Hours", color(black)) 		///
					name(margins_abx12, replace) ///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("Probability") ///
					ylabel(.4(.1).7) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(neast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	 *graph save abx12hr_tertiles, replace				

* spaghetti plot
sort hospid_enc year 
	forval i=1/3 {
		spagplot yhat_abx12 year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_abx12_tert`i', replace) ylab(0(.2)1 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(.2)1 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_abx12_tert1 spag_abx12_tert2 spag_abx12_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Antimicrobial within 12 hours", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_abx12_combine, replace)
		*graph save spag_abx12_tert, replace
			
		
*-----------------------------------
* ANTIBIOTICS IN 24 HOURS
*-----------------------------------

* mixed logit model

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_24hr i.slope_tertile##c.year 	///
		c.age male `sirs' `aod' comorbid_24hr va || hospid_enc: , or

estimates store abx24hr		
predict yhat_abx24, mu
predict r0_abx24, reffects

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose
	margins, at(year=(1(1)6)) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Antibiotics in 24 Hours", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("Probability") ///
					ylabel(.4(.1).7) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))


	*graph save abx24hr_tertiles, replace				

	
* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_abx24 year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_abx24_tert`i', replace) ylab(0(.2)1 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(.2)1 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_abx24_tert1 spag_abx24_tert2 spag_abx24_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Antimicrobial within 24 hours", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_abx24_combine, replace)
		*graph save spag_abx24_tert, replace


*-----------------------------------
* ANTIBIOTICS IN 48 HOURS
*-----------------------------------

tab abx_in_48hr

* mixed logit model 

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc
		
melogit abx_in_48hr i.slope_tertile##c.year 		///
		c.age male `sirs' `aod' comorbid_48hr va || hospid_enc: , or

estimates store abx48hr		
predict yhat_abx48, mu
predict r0_abx48, reffects
	
estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose
	margins, at(year=(1(1)6)) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Antibiotics in 48 Hours", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("Probability") ///
					ylabel(.4(.1).7) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	*graph save abx48hr_tertiles, replace				
	
* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_abx48 year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_abx48_tert`i', replace) ylab(0(.2)1 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(.2)1 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_abx48_tert1 spag_abx48_tert2 spag_abx48_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Antimicrobial within 48 hours", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_abx48_combine, replace)
		*graph save spag_abx48_tert, replace

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
		
menbreg abx_days_use_30 i.slope_tertile##c.year c.age male `sirs' `aod' c.comorbid_days va || hospid_enc: 

estimates store abxdays		
predict yhat_daysuse, mu 
predict r0_daysuse, reffects

estat summarize 
	
	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	margins, dydx(year) nose
		
	margins, at(year=(1(1)6)) nose

	margins slope_tertile, dydx(year) nose
				
	margins slope_tertile, at(year=(1(1)6)) nose 
	
	marginsplot, 	title("Days of Therapy", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ylabel(4(1)7) ylabel(, angle(0)) ylabel(, nogrid)	///
					ytitle("Days")				///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	*graph save daysabx_tertiles, replace		
	
* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_daysuse year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_days_tert`i', replace) ylab(0(2)10 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(2)10 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_days_tert1 spag_days_tert2 spag_days_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Days of antimicrobial therapy", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_days_combine, replace)
		*graph save spag_days_tert, replace

		
********************************************************************************
*								SPECTRUM SCORE						       	   *
********************************************************************************

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

meglm cumulative_spectrum_24hr i.slope_tertile##c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_24hr_cat va || hospid_enc: 	

estimates store spec24hr		
predict yhat_spec24hr, mu
predict r0_spec24hr, reffects
		
estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Spectrum Score (24 hours)", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("Spectrum Score") ///
					ylabel(16(4)30) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

		
	*graph save spectrum_24hr, replace		

	
* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_spec24hr year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_spec24hr_tert`i', replace) ylab(0(4)36 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(4)36 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_spec24hr_tert1 spag_spec24hr_tert2 spag_spec24hr_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Broadness of coverage - first 24 hours", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_spec24hr_combine, replace)
		*graph save spag_spec24hr_tert, replace
		
	
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

meglm cumulative_spectrum_48hr i.slope_tertile##c.year i.agegrp male `aod' `sirs' va i.comorbid_cumulspec_48hr_cat || hospid_enc: 	

estimates store spec48hr		
predict yhat_spec48hr, mu
predict r0_spec48hr, reffects

estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Spectrum Score (48 hours)", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("")  ///
					ylabel(16(4)30) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	*graph save spectrum_48hr, replace		

	
* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_spec48hr year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_spec48hr_tert`i', replace) ylab(0(4)36 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(4)36 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_spec48hr_tert1 spag_spec48hr_tert2 spag_spec48hr_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Broadness of coverage - first 48 hours", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_spec48hr_combine, replace)
		*graph save spag_spec48hr_tert, replace
		
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
	
meglm cumulative_spectrum_14day i.slope_tertile##c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_14d_cat va	|| hospid_enc: 	

estimates store spec14day		
predict yhat_spec14day, mu
predict r0_spec14day, reffects

estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Spectrum Score (14 days)", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("Spectrum Score")  ///
					ylabel(16(4)30) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	*graph save spectrum_14day, replace		

* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_spec14day year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_spec14d_tert`i', replace) ylab(0(4)36 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(4)36 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_spec14d_tert1 spag_spec14d_tert2 spag_spec14d_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Broadness of coverage - first 14 days", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_spec14d_combine, replace)
		*graph save spag_spec14d_tert, replace

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

meglm cumulative_spectrum_30day i.slope_tertile##c.year 	///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_30d_cat va	|| hospid_enc: 	

estimates store spec30day		
predict yhat_spec30day, mu
predict r0_spec30day, reffects
	
estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	*margins slope_tertile, at(year=(1(1)6)) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	marginsplot, 	title("Spectrum Score (30 days)", color(black)) 		///
					xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018") ///
					xtitle("Year")	///
					ytitle("")  ///
					ylabel(16(4)30) ylabel(, angle(0)) ylabel(, nogrid)	///
					graphregion(color(white)) plotregion(color(white)) ///
					plotopts(msymbol(none)) legend(cols(1) position(0) bplacement(seast) region(lcolor(white))) 		///
					plot( , label("Tertile 1 (largest decline)" "Tertile 2 (middle decline)" "Tertile 3 (least decline)"))

	*graph save spectrum_30day, replace		

* spaghetti plot
sort hospid_enc year 

	forval i=1/3 {
		spagplot yhat_spec30day year if slope_tertile==`i' , id(hospid_enc)  ///
			name(spag_spec30d_tert`i', replace) ylab(0(4)36 , grid gmax) note("") ///
			graphregion(color(white)) 		///
			ytitle("") ylab(0(4)36 , angle(0) grid gmax)		///
			xtitle(Year) xlabel(1 "2013" 2 "2014" 3 "2015" 4 "2016" 5 "2017" 6 "2018")	///
			title("Tertile `i'", size(medsmall) color(black) margin(medsmall) position(11) justification(left))
		gr_edit .plotregion1.plot2.draw_view.setstyle, style(no)
}
	
	graph combine spag_spec30d_tert1 spag_spec30d_tert2 spag_spec30d_tert3, ///
			rows(1) fysize(50) iscale(0.5) imargin(2 2 2 2) graphregion(color(white)) ///
			title("Broadness of coverage - first 30 days", size(small) color(black) margin(small) position(11) justification(left)) ///
			name(spag_spec30d_combine, replace)
		*graph save spag_spec30d_tert, replace

		
*-------------------------------------------------------------------------------
* Sensitivity analyses of spectrum score, using only those with score >0 
*-------------------------------------------------------------------------------

sum cumulative_spectrum_24hr if cumulative_spectrum_24hr>0 , det
sum cumulative_spectrum_48hr if cumulative_spectrum_48hr>0 , det
sum cumulative_spectrum_14day if cumulative_spectrum_14day>0 , det
sum cumulative_spectrum_30day if cumulative_spectrum_30day>0 , det

*--------------------------
* Spectrum Score, 24 HRs
*--------------------------
	
*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_24hr i.slope_tertile##c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_24hr_cat va if cumulative_spectrum_24hr>0 || hospid_enc: 	

estimates store spec24hr		
		
estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	
*--------------------------
* Spectrum Score, 48 HRs
*--------------------------

*  mixed generalized linear model
local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_48hr i.slope_tertile##c.year 	///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_48hr_cat va if cumulative_spectrum_48hr>0	|| hospid_enc: 	

estimates store spec48hr		

estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

		
*--------------------------
* Spectrum Score, 14 Days
*--------------------------

*  mixed generalized linear model

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_14day i.slope_tertile##c.year 		///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_14d_cat va if cumulative_spectrum_14day>0	|| hospid_enc: 	

estimates store spec14day		

estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 

	
*--------------------------
* Spectrum Score, 30 Days
*--------------------------

local aod 																		///
		 aod_lactate aod_kidney pressor_in_72hr aod_liver		///
		 aod_heme aod_lung 			
		
local sirs																		///
		sirs_temp sirs_rr sirs_pulse sirs_wbc

meglm cumulative_spectrum_30day i.slope_tertile##c.year 	///	
		i.agegrp male `aod' `sirs' i.comorbid_cumulspec_30d_cat va if cumulative_spectrum_30day>0	|| hospid_enc: 	

estimates store spec30day		
	
estat icc
estat summarize 

	* test overall significance of interaction
	testparm i.slope_tertile#c.year		

	* margins
	margins, dydx(year) nose

	margins slope_tertile, dydx(year) nose 

	margins slope_tertile, at(year=(1(1)6)) nose 


********************************************************************************
*							 FIGURES 2 AND 3						   		   *
********************************************************************************

preserve

	foreach x in abx12 abx24 abx48 daysuse spec24hr spec48hr spec14day spec30day  {
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
				slope_tertile, by(hospid admityear)

	bysort hospid (admityear): gen n=_n

	foreach x in abx12 abx24 abx48 daysuse spec24hr spec48hr spec14day spec30day  {
		gen yhat_`x'_y1 = yhat_`x'_hospyearmed if n==1
		gen yhat_`x'_y6 = yhat_`x'_hospyearmed if n==6
		bysort hospid: egen yhat_`x'_y1_fill = max(yhat_`x'_y1)
		bysort hospid: egen yhat_`x'_y6_fill = max(yhat_`x'_y6)
		gen ave_change_peryear_`x' =(yhat_`x'_y6_fill-yhat_`x'_y1_fill)/5
		gen p_change_`x' = (yhat_`x'_y1_fill-yhat_`x'_y6_fill)/yhat_`x'_y1_fill	
	}	

	drop *y1* *y6*	
		
	order hospid admityear exposure* *abx12* *abx24* *abx48* *daysuse* *spec24* *spec48* *spec14* *spec30*

* merge with hospitalization count dataset (see do file counting_hospitalizations)
merge m:1 hospid using count_avehospitalizations_byhospital, nogen
	
* keep only variables we still need 
keep hospid exposure_slope_hr exposure_slope_min ave_change_peryear* slope_tertile n avecount_hosps_hospyear	
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

foreach x in spec24hr spec48hr spec14d spec30d {	
	pwcorr ave_change_peryear_`x' exposure_slope_hr, sig
	spearman ave_change_peryear_`x' exposure_slope_hr
}


* abx in 12, 24, 48 hrs	
foreach x in abx12 abx24 abx48 {	
		
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
		twoway 	(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==1 , msymbol(Oh) msize(small)) ///
				(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==2 , msymbol(Oh) msize(small)) ///
				(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==3 , msymbol(Oh) msize(small)) ///
				(lfit ave_change_peryear_`x' exposure_slope_hr [pweight=weight_`x']),	///
				legend(off) 			///
				note("Correlation coefficient=`rho_`x'', p-value=`rho_p_`x''" "Slope=`b_`x'' (`lci_`x'', `hci_`x''), p-value=`p_`x''", /// 
						position(8) ring(0) size(vsmall) margin(medsmall)) ///
				title("Antimicrobials in `x'", size(medsmall) just(left) margin(medium) color(black)) ///
				yline(0) ///
				ylab(-0.02(0.01)0.02, labsize(small) nogrid) graphregion(color(white)) ///
				xlab(, labsize(small)) ///
				ytitle("Yearly Change in Proportion Receiving Antimicrobials", size(small) margin(medsmall))	////
				xtitle("Yearly Change in Time-to-Antibiotics (hours)", size(small) margin(medsmall)) ///
				name(hospchange_`x', replace)
		
		*graph save "hospchange_`x'", replace
		
}

* days of abx 
rreg ave_change_peryear_daysuse exposure_slope_hr, gen(weight_daysuse)	
	matrix list r(table) 
	matrix row=r(table) 
	matrix list row 
	local beta_daysuse=row[1,1]
	local lowci_daysuse=row[5,1]
	local hici_daysuse=row[6,1]
	local pval_daysuse=row[4,1]

	local b_daysuse: display %5.3f `beta_daysuse'
	local lci_daysuse: display %5.3f `lowci_daysuse'
	local hci_daysuse: display %5.3f `hici_daysuse'
	local p_daysuse: display %5.3f `pval_daysuse'

	di `b_daysuse' 
	di `lci_daysuse' 
	di `hci_daysuse' 
	di `p_daysuse'
			
spearman ave_change_peryear_daysuse exposure_slope_hr
	return list
	local rho_daysuse: display %5.3f r(rho)
	display `rho_daysuse'
	local rho_p_daysuse: display %5.3f r(p)
	display `rho_p_daysuse'

twoway 	(scatter ave_change_peryear_daysuse exposure_slope_hr if slope_tertile==1 , msymbol(Oh) msize(small)) ///
		(scatter ave_change_peryear_daysuse exposure_slope_hr if slope_tertile==2 , msymbol(Oh) msize(small)) ///
		(scatter ave_change_peryear_daysuse exposure_slope_hr if slope_tertile==3 , msymbol(Oh) msize(small)) ///
		(lfit ave_change_peryear_daysuse exposure_slope_hr [pweight=weight_daysuse]),	///
		legend(off) 	///
		note("Correlation coefficient=`rho_daysuse', p-value=`rho_p_daysuse'" "Slope=`b_daysuse' (`lci_daysuse', `hci_daysuse'), p-value=`p_daysuse'", /// 
						position(8) ring(0) size(vsmall) margin(medsmall)) ///		
		title("Days of Antimicrobial Therapy", size(medsmall) just(left) margin(medium) color(black)) ///
		yline(0) ///
		ylab(, labsize(small) nogrid) graphregion(color(white)) ///
		xlab(, labsize(small)) ///
		ytitle("Yearly Change in Antimicrobial Days", size(small) margin(medsmall))	////
		xtitle("Yearly Change in Time-to-Antibiotics (hours)", size(small) margin(medsmall)) ///
		name(hospchange_daysuse, replace)
		
		*graph save "hospchange_daysuse", replace
		
* spectrum score - 24hr, 48hr, 14days, 30days
foreach x in spec24hr spec48hr spec14d spec30d {	

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
		twoway 	(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==1 , msymbol(Oh) msize(small)) ///
				(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==2 , msymbol(Oh) msize(small)) ///
				(scatter ave_change_peryear_`x' exposure_slope_hr if slope_tertile==3 , msymbol(Oh) msize(small)) ///
				(lfit ave_change_peryear_`x' exposure_slope_hr [pweight=weight_`x']),	///
				legend(off) 			///
				note("Correlation coefficient=`rho_`x'', p-value=`rho_p_`x''" "Slope=`b_`x'' (`lci_`x'', `hci_`x''), p-value=`p_`x''", /// 
						position(8) ring(0) size(vsmall) margin(medsmall)) ///
				title("Broadness of Coverage in `x'", size(medsmall) just(left) margin(medium) color(black)) ///
				yline(0) ///
				ylab(, labsize(small) nogrid) graphregion(color(white)) ///
				xlab(, labsize(small)) ///
				ytitle("Yearly Change in Spectrum Score", size(small) margin(medsmall))	////
				xtitle("Yearly Change in Time-to-Antibiotics (hours)", size(small) margin(medsmall)) ///
				name(hospchange_`x', replace)
		
		*graph save "hospchange_`x'", replace
		
}

log close	
	