/*******************************************************************************
an_eulfs_transizione_education.do
Analogo EU-LFS delle figure regs_rfl_transizione_{birth,job}_college{0,1}.pdf
Output: ${graphs}/regs_eulfs_transizione_birth_{si,no}_italia_college{0,1}.pdf
Richiede: ${data}/eulfs_transizione.dta (cr_eulfs_transizione.do), ${paesi_no_italia},
          ${graphs} ${first_year} ${last_year}, regsave (ssc)

Figure "job" (reg age_first_job age_education) NON prodotte: in EU-LFS non c'e'
l'eta'/anno del primo lavoro (vedi cr_eulfs_transizione.do).

no_italia: regressioni pooled sui paesi in ${paesi_no_italia}, con effetti fissi
paese ${fe_paese} (lasciare vuota la global per replicare la specifica RFL senza FE).
Pesi = COEFFHH (pesi di popolazione: i paesi grandi pesano di piu').
*******************************************************************************/
local first_year 		= ${first_year}
local last_year 		= ${last_year}
global fe_paese			i.paese_n

if "${paesi_no_italia}"=="" {
	di as error "Global paesi_no_italia vuota: eseguire prima cr_eulfs_transizione.do"
	exit 198
}

clear
set obs 1
gen butta=1
save ${graphs}/eulfs_transizione_education.dta,replace

foreach campione in si_italia no_italia {
	if "`campione'"=="si_italia" {
		local paesi IT
		local fe
	}
	else {
		local paesi ${paesi_no_italia}
		local fe ${fe_paese}
	}
	forvalues ksd=0/1{
		use "${data}/eulfs_transizione" if inlist(college,`ksd'),clear
		gen byte in_campione = 0
		foreach cc of local paesi {
			replace in_campione = 1 if paese=="`cc'"
		}
		keep if in_campione==1
		encode paese, gen(paese_n)
		/*******************************************************************************
		By years
		*******************************************************************************/
		forvalues akh=`first_year'/`last_year' {
			noi di "*******************************************"
			noi di "`campione' college`ksd' `akh'"
			noi di "*******************************************"
			forvalues sklno=0/1 {
				capture noisily reg age_first_birth	age_education `fe'		[pw=peso] if donna==`sklno' &  anno==`akh'
				if _rc==0 {
					regsave age_education using ${graphs}/eulfs_transizione_education.dta, ///
						append pval ci level(95) addlabel(outcome,"age_first_birth",college,`ksd',gender,`sklno',year,`akh',campione,"`campione'")
				}
			}
		}

		/*******************************************************************************
		Grpahs
		*******************************************************************************/
		use ${graphs}/eulfs_transizione_education.dta if inlist(college,`ksd') & campione=="`campione'",clear
		keep if regexm(outcome,"birth")==1
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
		graph export "${graphs}/regs_eulfs_transizione_birth_`campione'_college`ksd'.pdf", replace
		gr drop _all
	}
}
