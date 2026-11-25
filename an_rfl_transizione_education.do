local first_year 		= ${first_year}
local last_year 		= ${last_year}
local including_age		// age_education
clear
set obs 1
gen butta=1
save ${graphs}/rfl_transizione_education.dta,replace

forvalues ksd=0/1{
	use "${data}/rfl_transizione" if inlist(college,`ksd'),clear
	/*******************************************************************************
	All years
	*******************************************************************************/
	
	reg age_first_job 	age_education  i.anno i.trim 				[pw=peso]
	regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
		append pval ci level(95) addlabel(outcome,"age_first_job",college,`ksd',gender,2,year,.)

	reg age_first_birth 	age_education  i.anno i.trim 				[pw=peso]
	est store birth_year
	regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
		append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,2,year,.)
	
	forvalues sklno=0/1 {
		reg age_first_job 	age_education  i.anno i.trim 			[pw=peso] if donna==`sklno'
		regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
			append pval ci level(95) addlabel(outcome,"age_first_job",college,`ksd',gender,`sklno',year,.)
	
		reg age_first_birth 	age_education  i.anno i.trim 			[pw=peso] if donna==`sklno'
		regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
			append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,`sklno',year,.)
			
	}
	
	/*******************************************************************************
	By years
	*******************************************************************************/
	forvalues akh=`first_year'/`last_year' {
		noi di "*******************************************"
		noi di `akh'
		noi di "*******************************************"
		reg age_first_job 	age_education  						[pw=peso] if anno==`akh'
		est store job_main
		regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
			append pval ci level(95) addlabel(outcome,"age_first_job",college,`ksd',gender,2,year,`akh')
	
		reg age_first_birth	age_education  						[pw=peso] if anno==`akh'
		est store birth_main
		regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
			append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,2,year,`akh')
	
		reg age_first_birth	age_first_job `including_age'				[pw=peso] if anno==`akh'
		est store birth_job
		regsave `including_age' age_first_job using ${graphs}/rfl_transizione_education.dta, ///
			append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,2,year,`akh',conditioning,"job & edu")
	
		forvalues sklno=0/1 {
			reg age_first_job 	age_education  					[pw=peso] if donna==`sklno' &  anno==`akh'
			est store job_main_s`sklno'
			regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
				append pval ci level(95) addlabel(outcome,"age_first_job",college,`ksd',gender,`sklno',year,`akh')
	
			reg age_first_birth	age_education  					[pw=peso] if donna==`sklno' &  anno==`akh'
			est store birth_main_s`sklno'
			regsave age_education using ${graphs}/rfl_transizione_education.dta, ///
				append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,`sklno',year,`akh')
				
			reg age_first_birth	age_first_job `including_age'			[pw=peso] if donna==`sklno' &  anno==`akh'
			est store birth_job
			regsave `including_age' age_first_job using ${graphs}/rfl_transizione_education.dta, ///
				append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,`sklno',year,`akh',conditioning,"job & edu")

		}
	
	}
	
	/*******************************************************************************
	Grpahs
	*******************************************************************************/
	use ${graphs}/rfl_transizione_education.dta if inlist(college,`ksd'),clear
	keep if regexm(outcome,"birth")==1
	keep if missing(conditioning)
	keep if !missing(year)
	#delimit;
	twoway  
		(connected coef year if gender==0, color(cranberry)) 
		(rcap ci_lower ci_upper year if gender==0, color(cranberry)) 
		(connected coef year if gender==1, color(dknavy)) 
		(rcap ci_lower ci_upper year if gender==1, color(dknavy)) 
		, 
		/*xlabel($first_year (1) $last_year)*/ 
		xti("") yti("OLS Coefficients") legend(pos(6) ring(1) row(1) order( 3 "Women" 1 "Men")) 
		yline(0) ylabel(.2(.1).5) ytick(.25(.1).45,grid)
		name(birth,replace)
	; #delimit cr;
	graph export "${graphs}/regs_rfl_transizione_birth_college`ksd'.pdf", replace
	
	use ${graphs}/rfl_transizione_education.dta if inlist(college,`ksd'),clear
	keep if regexm(outcome,"job")==1
	keep if !missing(year)
	#delimit;
	twoway  
		(connected coef year if gender==0, color(cranberry)) 
		(rcap ci_lower ci_upper year if gender==0, color(cranberry)) 
		(connected coef year if gender==1, color(dknavy)) 
		(rcap ci_lower ci_upper year if gender==1, color(dknavy)) 
		, 
		/*xlabel($first_year (1) $last_year)*/ 
		xti("") yti("OLS Coefficients") legend(pos(6) ring(1) row(1) order( 3 "Women" 1 "Men")) 
		yline(0) ylabel(.3(.1)1)
		name(job,replace)
	; #delimit cr;
	graph export "${graphs}/regs_rfl_transizione_job_college`ksd'.pdf", replace

	use ${graphs}/rfl_transizione_education.dta if inlist(college,`ksd'),clear
	keep if regexm(outcome,"birth")==1
	keep if !missing(conditioning)
	keep if !missing(year)
	keep if !inlist(var,"age_education")
	#delimit;
	twoway  
		(connected coef year if gender==0, color(cranberry)) 
		(rcap ci_lower ci_upper year if gender==0, color(cranberry)) 
		(connected coef year if gender==1, color(dknavy)) 
		(rcap ci_lower ci_upper year if gender==1, color(dknavy)) 
		, 
		/*xlabel($first_year (1) $last_year)*/ 
		xti("") yti("OLS Coefficients") legend(pos(6) ring(1) row(1) order( 3 "Women" 1 "Men")) 
		yline(0) ylabel(-.1(.1).5) ytick(-.05(.1).45,grid)
		name(birth_conditioning,replace)
	; #delimit cr;
	graph export "${graphs}/regs_rfl_transizione_birth_conditioning_college`ksd'.pdf", replace
	gr drop _all
}
