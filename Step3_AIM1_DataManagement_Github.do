/* 	Making time-to-antibiotics variable to bring into dataset
	
	Sarah Seelye
	Last Updated: 5/19/2021
*/

clear all
cap log close
cap more off
version 15.1

cd ""
		
local day : display %tdCYND daily("$S_DATE", "DMY")
di "`day'"

log using TimeToAbx_`day'.log, replace

use step2_HAPPI_20132018, clear 	

********************************************************************************
************************ CREATE TIME-TO-ANTIBIOTICS ****************************
********************************************************************************

* ------------------------------------------------------------------------------

** Conceptual Definition #1 **
** Create the Time of First Antibiotic Order + 45 Minutes **

* first identify whether the OrderStartDateTime occurs AFTER earliest_edisarrivaltime_hosp
gen 	order_after_patientarrival = .
replace order_after_patientarrival = 1 if earliest_cprs_abx_order>earliest_edisarrivaltime_hosp & earliest_cprs_abx_order!=. 
replace order_after_patientarrival = 0 if earliest_cprs_abx_order<earliest_edisarrivaltime_hosp & earliest_cprs_abx_order!=. 
replace order_after_patientarrival = 0 if earliest_cprs_abx_order==earliest_edisarrivaltime_hosp
replace order_after_patientarrival = 0 if earliest_cprs_abx_order==. 

tab order_after_patientarrival admityear, co 

* Next identify whether the OrderStartDateTime occurs BEFORE the 
* SpecialtyTransferDateTime. First I need to identify the inpatient 
* admission time using Day 1 of specialtytransferdatetime
bysort unique (datevalue): gen double admitdatetime = specialtytransferdatetime[1]
format admitdatetime %tc

list 	unique new_admitdate3 new_dischargedate3 hospital_day 			///
		specialtytransferdatetime admitdatetime in 1/50

gen 	order_before_specialtytrans = .
replace order_before_specialtytrans = 1 if earliest_cprs_abx_order<admitdatetime
replace order_before_specialtytrans = 0 if earliest_cprs_abx_order>admitdatetime & earliest_cprs_abx_order!=. 
replace order_before_specialtytrans = 0 if earliest_cprs_abx_order==.
replace order_before_specialtytrans = 0 if earliest_cprs_abx_order==admitdatetime

tab order_before_specialtytrans, m

* next identify whether the OrderStartDateTime occurs 
* AFTER PatientArrivalDateTime AND BEFORE SpecialtyTransferDateTime
gen 	order_btwn_arrival_trans = . 
replace order_btwn_arrival_trans = 1 if order_after_patientarrival==1 		///
								      & order_before_specialtytrans==1
replace order_btwn_arrival_trans = 0 if order_btwn_arrival_trans==.

tab order_btwn_arrival_trans, m
tab order_after_patientarrival order_before_specialtytrans, m
tab order_btwn_arrival_trans admityear, co

* create a new time for the OrderStartDateTime (t+45) for those orders that 
* occur between the PatientArrivalDateTime and SpecialtyTransferDateTime
gen 	double order_timeplus45_hosp = .
format 	order_timeplus45_hosp %tc
replace order_timeplus45_hosp = earliest_cprs_abx_order + msofminutes(45) ///
								if order_btwn_arrival_trans==1
label variable order_timeplus45_hosp "time of first ED abx order + 45 minutes"

* ------------------------------------------------------------------------------

** Preparation for Conceptual Definition #2 **

** Create the Time of First Antibiotic Order for Orders Before or at the Same
** Time as ED arrival **

* First, look at yearly breakdown of those with a CPRS order time BEFORE or 
* AT THE SAME TIME as ED arrival
tab admityear if earliest_cprs_abx_order<earliest_edisarrivaltime_hosp & earliest_cprs_abx_order!=. 
tab admityear if earliest_cprs_abx_order==earliest_edisarrivaltime_hosp 

* create an indicator for those with the same CPRS order time and  
* ED arrival time
gen sametime = 0
replace sametime=1 if earliest_cprs_abx_order==earliest_edisarrivaltime_hosp		

tab sametime admityear, co 
tab sametime admityear if hospital_day==0, m co
		
* create an indicator for those in which the CPRS order time occurs before
* the ED arrival time
gen cprs_before_ed = 0
replace cprs_before_ed = 1 if earliest_cprs_abx_order<earliest_edisarrivaltime_hosp & !missing(earliest_cprs_abx_order)

tab cprs_before_ed admityear, co 
tab cprs_before_ed admityear if hospital_day==0, m co 					

*-------------------------------------------------------------------------------

** Conceptual Definition #2 **
** Create the Time of ED to Hospital Transfer among patients with an ABX ordered in ED **

* create time of ED to hospital transfer using specialtytransferdatetime for 
* Day 1 (admitdatetime), if there is an antibiotic OrderStartDateTime that 
* occurs during the ED visit (ie between PatientArrivalDateTime and 
* SpecialtyTransferDateTime); Use specialtytransferdatetime for CPRS orders
* that occur at the same time as ED arrival or that occur before ED arrival
gen double 	transfer_time_hosp = .
replace transfer_time_hosp = admitdatetime if order_btwn_arrival_trans==1
replace transfer_time_hosp = admitdatetime if sametime==1
replace transfer_time_hosp = admitdatetime if cprs_before_ed==1
	
format 	transfer_time_hosp %tc
label variable transfer_time_hosp "time of ED to hospital transfer, hosp level"

list 	unique hospital_day earliest_edisarrivaltime_hosp					///
		specialtytransferdatetime admitdatetime order_btwn_arrival_trans 	///
		transfer_time_hosp in 1/75

*-------------------------------------------------------------------------------
** Conceptual Definition #3 **
** Create Antibiotic Delivery Time In BCMA **

* first identify whether the bcma_actiondatetime occurs after 
* the earliest_edisarrivaltime_hosp time

gen 	bcma_after_patientarrival = .
replace bcma_after_patientarrival = 1 if earliest_bcma_abx>earliest_edisarrivaltime_hosp & earliest_bcma_abx!=.
replace bcma_after_patientarrival = 0 if earliest_bcma_abx<earliest_edisarrivaltime_hosp & earliest_bcma_abx!=. 
replace bcma_after_patientarrival = 0 if earliest_bcma_abx==.				
		
tab bcma_after_patientarrival, m
	

*-------------------------------------------------------------------------------
** USE CONCEPTUAL DEFINITIONS TO CREATE TIME-TO-FIRST-ABX-DELIVERY **

** Create Time of First Antibiotics Delivery as the Earliest of 4 **
** (conceptual def 1, 2, & 3) **

gen double time_first_abx = min(order_timeplus45_hosp, 					///
								transfer_time_hosp, 					///
								earliest_bcma_abx)
format time_first_abx %tc

** Create Time-to-Antibiotics as ([time of first abx] - [time of ED arrival]) ** 
* time-to-abx in minutes
gen double time_to_abx_min = minutes(time_first_abx-earliest_edisarrivaltime_hosp)
label variable time_to_abx_min "time-to-antibiotics (in minutes)"
sum time_to_abx_min
sum time_to_abx_min if time_to_abx_min<0
sum time_to_abx_min if time_to_abx_min>2880

	* change to missing time_first_abx & time_to_abx_min that occurs before
	* ED arrival or after the 48 hour period
	replace time_first_abx = . if time_to_abx_min<0 | time_to_abx_min>2880
	replace time_to_abx_min = . if time_to_abx_min<0 | time_to_abx_min>2880

	
* time-to-abx in hours
gen double time_to_abx_hr = hours(time_first_abx-earliest_edisarrivaltime_hosp)
label variable time_to_abx_hr "time-to-antibiotics (in hours)"
sum time_to_abx_hr

** Receives ABX during 48-hour window **
gen abx_in_48hr = .
replace abx_in_48hr = 1 if !missing(time_to_abx_min)
replace abx_in_48hr = 0 if missing(time_to_abx_min)
tab abx_in_48hr 


********************************************************************************
************************** DESCRIPTIVE STATISTICS ******************************	
********************************************************************************

*********************************
** DISTRIBUTION OF TIME-TO-ABX **
*********************************

tab hospital_day admityear if hospital_day==1
tab abx_in_48hr admityear if hospital_day==1, co

sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1, detail

sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2013, detail
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2014, detail
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2015, detail
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2016, detail
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2017, detail
sum time_to_abx_min if abx_in_48hr==1 & hospital_day==1 & admityear==2018, detail

sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2013, detail
sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2014, detail
sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2015, detail
sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2016, detail
sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2017, detail
sum time_to_abx_hr if abx_in_48hr==1 & hospital_day==1 & admityear==2018, detail


*******************************************
** PROPORTIONS BY CONCEPTUAL DEFINITIONS **
*******************************************

* Proportion of Patients in Each of Three Conceptual Definitions	      
gen 	time_first_abx_bydef = .
replace time_first_abx_bydef = 1 if time_first_abx==order_timeplus45_hosp & time_first_abx!=.
replace time_first_abx_bydef = 2 if time_first_abx==transfer_time_hosp & time_first_abx!=.
replace time_first_abx_bydef = 3 if time_first_abx==earliest_bcma_abx & time_first_abx!=.
label define time_first_abx_bydef 1 "order_timeplus45" 2 "transfer time" 3 "first BCMA", replace
label values time_first_abx_bydef time_first_abx_bydef

tab time_first_abx_bydef admityear if hospital_day==1 & abx_in_48hr==1, co

			
**********************
** Organize Dataset **
**********************

sort patienticn new_admitdate3 hospital_day

* drop variables we no longer need
drop 	bcma_after_patientarrival 											///
		cprs_before_ed sametime order_btwn_arrival_trans 					///
		order_before_specialtytrans admitdatetime 							///
		order_after_patientarrival order_timeplus45_hosp 					///
		transfer_time_hosp

* order variables for team review of data 
order 	patienticn unique_hosp_count_id new_admitdate3 new_dischargedate3 	///
		datevalue hospital_day specialtytransferdatetime 					///
		earliest_specialtytransfer_hosp time_first_abx time_to_abx_hr		///
		time_to_abx_min abx_in_48hr earliest_edisarrivaltime_hosp 			///
		earliest_cprs_abx_order earliest_bcma_abx bcma_actiondatetime 		///
		bcma_daily_ind cprs_datetime_daily cprs_daily_ind

save step3_HAPPI_20132018, replace

log close

