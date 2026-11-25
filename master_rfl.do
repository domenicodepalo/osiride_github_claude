clear all
global rfl     		/home/group/main/rdc/private/FLAV/dati/wave
global graphs		/home/user/c155300/tmp/wfh/risultati
global main		/home/group/main/892fl/policy/Attivita_correnti/fertilità/DDSL
global data		${main}/DTA/rfl
global prog		${main}/PROG/rfl
global graphs		${main}/GRAPHS/rfl
global log		${main}/LOG/rfl
global first_year 	= 2014
global last_year  	= 2024

set seed 2023
/* Dati */
qui do "${prog}/cr_rfl_transizione.do"
qui do "${prog}/cr_rfl_presenza_figli.do"
/* Analisi */
do "${prog}/an_rfl_transizione.do"
do "${prog}/an_rfl_transizione_education.do"
do "${prog}/an_rfl_presenza_figli.do"
do "${prog}/an_rfl_couples.do"
do "${prog}/an_rfl_presenza_figli_area.do"
do "${prog}/an_rfl_couples.do"
do "${prog}/an_rfl_correlazioni_edu_job_birth.do"


qui do "${prog}/cr_eusilc_presenza_figli.do"
do "${prog}/an_eusilc_presenza_figli.do"
gr drop _all
