/*******************************************************************************
cr_eulfs_transizione.do
Costruisce ${data}/eulfs_transizione.dta (analogo EU-LFS di rfl_transizione.dta)
Input : EU-LFS Scientific Use Files, yearly, ${eulfs}/CCYYYY_y.csv
Richiede (da master): ${data} ${first_year} ${last_year}

Nomenclatura Paesi (codici EU-LFS; paesi presenti sia nel 2004 sia nel 2024):
	AT: Austria
	BE: Belgio
	BG: Bulgaria
	CH: Svizzera
	CY: Cipro
	CZ: Repubblica Ceca
	DE: Germania
	DK: Danimarca
	EE: Estonia
	EL: Grecia
	ES: Spagna
	FI: Finlandia
	FR: Francia
	HR: Croazia
	HU: Ungheria
	IE: Irlanda
	IT: Italia
	LT: Lituania
	LU: Lussemburgo
	LV: Lettonia
	NL: Paesi Bassi
	NO: Norvegia
	PL: Polonia
	PT: Portogallo
	RO: Romania
	SE: Svezia
	SI: Slovenia
	SK: Slovacchia
Esclusi: UK (Regno Unito) e IS (Islanda) presenti solo nel 2004; MT (Malta) presente solo nel 2024.

Note anonimizzazione SUF (EU-LFS Database User Guide, Dec 2025, cap. 7.1):
	- YEARBIR non incluso: year_birth = anno - age.
	- AGE in classi quinquennali (AGE vuoto, solo AGE_GRP) per: CZ IE NL SK (tutte le eta');
	  IT PL HR DK CY (solo 0-14). Eta' imputata a caso nella classe, come etam in RFL.
	- SI: HATYEAR oscurato -> age_education disponibile solo se HATAGE e' fornito.
	- DE: sottocampione ~70% con pesi di anonimizzazione.
	- Tabelle per eta' singola non pubblicabili.

DIFFERENZA RISPETTO A RFL: in EU-LFS non esiste l'anno/eta' del primo lavoro
(YSTARTWK = inizio del lavoro attuale). age_first_job/dif_job non costruibili.
Proxy della selezione RFL "drop if missing(dif_job)": persone che hanno mai lavorato
(EMPSTAT==1 o YEARPR valorizzato). Attiva con ${restr_ever_worked}==1.
*******************************************************************************/
local first_year = ${first_year}
local last_year  = ${last_year}

global eulfs			/home/group/main/rdc/private/EULFS/dati/Yearly_Files/csv
global paesi_no_italia	AT BE BG CH CY CZ DE DK EE EL ES FI FR HR HU IE LT LU LV NL NO PL PT RO SE SI SK
global restr_ever_worked	= 1

set seed 2023
local keepingdata 	country refyear quarter refweek hhnum hhseqnum hhlink sex age age_grp ///
					hatlevel hatlev1d hatyear hatage coeffhh empstat yearpr
local numvars		refyear quarter refweek hhseqnum hhlink sex age hatlevel hatyear hatage ///
					coeffhh empstat yearpr

local files
foreach cc in IT ${paesi_no_italia} {
	forvalues yy = `first_year'/`last_year' {
		capture confirm file "${eulfs}/`cc'`yy'_y.csv"
		if _rc {
			noi di as error "File mancante: `cc'`yy'_y.csv"
			continue
		}
		import delimited using "${eulfs}/`cc'`yy'_y.csv", clear case(lower) varnames(1) stringcols(_all)
		foreach v of local keepingdata {
			capture confirm variable `v'
			if _rc {
				noi di as error "`cc'`yy': variabile `v' assente"
				gen str1 `v' = ""
			}
		}
		keep `keepingdata'
		foreach v of local keepingdata {
			replace `v' = strtrim(`v')
		}
		destring `numvars', replace force
		gen paese = "`cc'"
		ren refyear anno
		replace anno = `yy' if missing(anno)

		/* Pesi */
		keep if coeffhh>0 & !missing(coeffhh)							// Sottocampione annuale per analisi con background familiare
		gen peso = coeffhh												// Yearly weights (in migliaia)
		qui count
		if r(N)==0 noi di as error "`cc'`yy': nessuna obs con COEFFHH>0"

		/* Demographics */
			* Identify HH
		gen trim = quarter
		replace trim = min(ceil(refweek/13),4) if missing(trim) & inrange(refweek,1,53)
		qui count if missing(trim)
		if r(N)>0 noi di as error "`cc'`yy': `r(N)' obs senza trimestre (QUARTER/REFWEEK)"
		gen famiglia = paese + "_" + string(anno) + "_" + string(trim) + "_" + hhnum
			* age
		gen age_lo = real(regexs(1)) if regexm(age_grp,"([0-9]+)[^0-9]+([0-9]+)")
		gen age_hi = real(regexs(2)) if regexm(age_grp,"([0-9]+)[^0-9]+([0-9]+)")
		replace age_lo = real(regexs(1))     if missing(age_lo) & regexm(upper(age_grp),"GE|\+") & regexm(age_grp,"^[^0-9]*([0-9]+)[^0-9]*$")
		replace age_hi = age_lo + 4          if missing(age_hi) & !missing(age_lo)
		replace age_lo = real(regexs(1)) - 2 if missing(age_lo) & regexm(age_grp,"^([0-9]+)$")			// Codifica a valore centrale (es. 17 = 15-19): VERIFICARE con tab age_grp
		replace age_hi = age_lo + 4          if missing(age_hi) & !missing(age_lo)
		gen age_imp = missing(age) & !missing(age_lo)
		replace age = runiformint(age_lo,age_hi) if age_imp==1			// Imputed randomly (come etam in RFL)
		qui count if missing(age)
		if r(N)>0 noi di as error "`cc'`yy': `r(N)' obs con eta' mancante (controllare age_grp)"
		gen year_birth = anno - age
			* Age of the oldest children
		gen tmp = age if inlist(hhlink,3)								// Son/daughter of reference person (anche del solo partner)
		egen age_oldest_children = max(tmp), by(famiglia)
		gen age_first_birth = age - age_oldest_children if inlist(hhlink,1,2)
		drop if age_first_birth<15
			* gender
		gen donna = sex==2

		/* Job (proxy: mai lavorato) */
		gen ever_worked = empstat==1 | inrange(yearpr,1900,anno)

		/* Education */
		gen year_education = hatyear if inrange(hatyear,1900,anno)
		gen age_education = hatage if inrange(hatage,0,120)
		replace age_education = year_education - year_birth if missing(age_education) & !missing(year_education)
		drop if age_education<10
		gen college = hatlev1d=="H" if inlist(hatlev1d,"L","M","H")
		replace college = inrange(hatlevel,500,899) if missing(college) & inrange(hatlevel,0,899)

		/* Children & Education */
		gen dif_children = age_first_birth - age_education

		keep if inlist(hhlink,1,2)
		drop if missing(dif_children)
		if ${restr_ever_worked}==1 keep if ever_worked==1

		keep paese anno trim famiglia hhseqnum hhlink age age_imp year_birth donna ///
			age_oldest_children age_first_birth year_education age_education college ///
			hatlevel ever_worked dif_children peso
		compress
		tempfile f_`cc'`yy'
		save `f_`cc'`yy'', replace
		local files `files' `f_`cc'`yy''
	}
}
clear
append using `files'
label var paese				"Paese (codice EU-LFS)"
label var age_imp			"Eta' imputata da AGE_GRP"
label var age_first_birth	"Eta' alla nascita del primo figlio (figlio piu' vecchio co-residente)"
label var age_education		"Eta' al conseguimento del titolo piu' alto"
label var college			"Terziaria (HATLEV1D==H, ISCED 5-8)"
label var ever_worked		"Ha mai lavorato (EMPSTAT==1 o YEARPR valido)"

/* Controlli */
noi tab paese anno
noi tab paese age_imp, row nofreq
noi tabstat age_education age_first_birth, by(paese) stat(mean p50 n)

save "${data}/eulfs_transizione", replace
