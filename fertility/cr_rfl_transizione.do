local first_year = ${first_year}
local last_year = ${last_year}

set seed 2023
local keepingdata_old etam c55 	c56	c60  c61  c62	sg26 sg27 coef1 anno trim mfrfam edulev dipind cond3* relpar  sg11 rip3 cletad cittad
local keepingdata_new etam qc58 qc58a 	qc63 qc64 qc64a qh04 qh05 coef1 anno trim mfrfam edulev dipind cond3 relparm qsf11 rip3 cletad cittad
clear
forvalues skdbf=2014/2020 {
	append using "${rfl}/1_`skdbf'.dta" ,keep(`keepingdata_old')
	append using "${rfl}/2_`skdbf'.dta" ,keep(`keepingdata_old')
	append using "${rfl}/3_`skdbf'.dta" ,keep(`keepingdata_old')
	append using "${rfl}/4_`skdbf'.dta" ,keep(`keepingdata_old')
}
forvalues skdbf=2021/2024 {
	append using "${rfl}/`skdbf'_1.dta" ,keep(`keepingdata_new')
	append using "${rfl}/`skdbf'_2.dta" ,keep(`keepingdata_new')
	append using "${rfl}/`skdbf'_3.dta" ,keep(`keepingdata_new')
	append using "${rfl}/`skdbf'_4.dta" ,keep(`keepingdata_new')
}

/* Harmonizing */
replace cond3=cond3new if inrange(anno,2018,2020)
replace qc58=c55 	if anno<2021
replace qc58a=c56 	if anno<2021
replace qc63=c60 	if anno<2021
replace qc64=c61 	if anno<2021
replace qc64a=c62 	if anno<2021
recode sg26 (998 997=.)
recode sg27 (998 997=.)								// Not binding. Just for completeness
replace qh04=sg26 	if anno<2021
replace qh05=sg27 	if anno<2021
replace qc64=c61 	if anno<2021
replace relparm=relpar 	if anno<2017
replace qsf11=sg11 	if anno<2021
/* Pesi */
gen peso=coef1/4								// Yearly weights
/* Demographics */
	* Identify HH
gen under="_"
egen famiglia=concat(anno under trim under mfrfam)
	* age
gen age=etam									// Imputed randomly
replace age=runiformint(0,2) 	if inlist(etam,0)
replace age=runiformint(3,5) 	if inlist(etam,3)
replace age=runiformint(6,10) 	if inlist(etam,6)
replace age=runiformint(11,14) 	if inlist(etam,11)
gen year_birth=anno-age
	* Age of the oldest children
gen tmp=age if inlist(relparm,6,7)						// Children of PR or his/her partener
egen age_oldest_children=max(tmp),by(famiglia)
gen age_first_birth=age-age_oldest_children if inlist(relparm,1,2,3)
drop if age_first_birth<15							/* Nota che può essere anche <0 (3 casi), se la badante sposa il nonno
										   Nota che allo stesso modo può esserci gente che ha figli a 55+ età. in questi casi, tipicamente uno dei due è molto più giovane (2% osservazioni). per vederli usa
										   gen tmp=missing(age_at_first_birth )
										   egen min=min(tmp),by(famiglia )
										   egen max=max(tmp),by(famiglia )
										   egen check=max(age_at_first_birth),by(famiglia )
										   br famiglia anno trim mfrfam age year_birth edulev age* relp if check>60 & min==0 & max==1										   
										*/

	* gender
gen donna=qsf11==2
/* Job */
replace qc64=qc58 if inlist(qc63,1) & missing(qc64)				// This is the first job
replace qc64a=qc58a if inlist(qc63,1) & missing(qc64a)				// This is the first job
ren qc64 year_first_job
gen age_first_job=year_first_job-year_birth
replace age_first_job=qc64a	if inlist(year_first_job,997)			
replace age_first_job=.		if inlist(age_first_job,997)			
*ren qc60 year_first_indeterminato						// riservato istat


/* Education */
ren qh04 year_education
recode year_education (997=.)
ren qh05 age_education
replace  age_education=year_education-year_birth if missing(age_education) & !missing(year_education)	// Only one info is available. I recover one for the other
drop if age_education<10							// Less than basic education (almost 50% of these have basic education as highest edu attainment)
gen college=inlist(edulev,6)	if !missing(edulev)

/* Job & Education */
gen dif_job=age_first_job -age_education					// 20% di persone è <0. E' corretto/possibile perchè posso iniziare a lavorare prima di laurearmi (sono quasi tutti laureati!). Li droppo per avere (quasi) certezza che la laurea sia servita
drop if dif_job<0

/* Children & Education */
gen dif_children=age_first_birth -age_education					

keep if inlist(relparm,1,2,3)
drop if missing(dif_children)
drop if missing(dif_job)
drop if age_first_job<8 | age_first_job>80					// Few cases for v old people. 

save "${data}/rfl_transizione",replace
