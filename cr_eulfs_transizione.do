/*******************************************************************************
cr_eulfs_transizione.do
Costruisce ${data}/eulfs_transizione.dta (analogo EU-LFS di rfl_transizione.dta)
Input : EU-LFS Scientific Use Files (SUF), yearly, ${eulfs}/CCYYYY_y.csv
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

Anonimizzazione SUF (EU-LFS Database User Guide, Dec 2025, cap. 7.1):
	- YEARBIR non incluso nei SUF.
	- AGE solo in classi quinquennali (AGE vuoto, solo AGE_GRP), tutte le eta': CZ IE NL SK.
	- AGE in classi quinquennali solo per 0-14: IT PL HR DK CY.
	- AGE in anni singoli con piccola perturbazione (15-74): HR DK CY.
	- SI: HATYEAR oscurato.
	- DE: sottocampione ~70% con pesi di anonimizzazione (gia' nei pesi del file).
	- Tabelle per eta' singola non pubblicabili.
*******************************************************************************/
local first_year = ${first_year}
local last_year  = ${last_year}

global eulfs			/home/group/main/rdc/private/EULFS/dati/Yearly_Files/csv
global age_classes		CZ IE NL SK		// Forniscono solo classi di eta' (AGE_GRP) per tutte le eta', non l'eta' puntuale
global paesi_no_italia	/* ${age_classes} */ AT BE BG CH CY DE DK EE EL ES FI FR HR HU LT LU LV NO PL PT RO SE SI	// Paesi presenti sia nel 2004 sia nel 2024, esclusa IT. Elimino ${age_classes} perche' forniscono solo classi di eta': eta' dei genitori e dei figli entrambe imputate -> errore di misura su age_first_birth
global restr_ever_worked	= 1			// 1 = tengo solo chi ha mai lavorato. Proxy della selezione RFL "drop if missing(dif_job)": in EU-LFS non c'e' l'eta'/anno del primo lavoro (YSTARTWK = inizio del lavoro attuale)

set seed 2023							// Come RFL: rende riproducibile l'imputazione casuale dell'eta'
local keepingdata 	country refyear quarter refweek hhnum hhseqnum hhlink sex age age_grp ///
					hatlevel hatlev1d hatyear hatage coeffhh empstat yearpr				// Solo le variabili necessarie: riduce la memoria
local numvars		refyear quarter refweek hhseqnum hhlink sex age hatlevel hatyear hatage ///
					coeffhh empstat yearpr												// Variabili da convertire in numeriche

local files
foreach cc in IT ${paesi_no_italia} {
	forvalues yy = `first_year'/`last_year' {
		capture confirm file "${eulfs}/`cc'`yy'_y.csv"
		if _rc {
			noi di as error "File mancante: `cc'`yy'_y.csv"							// Segnala e salta i paese-anno senza file
			continue
		}
		import delimited using "${eulfs}/`cc'`yy'_y.csv", clear case(lower) varnames(1) stringcols(_all)	// Tutto stringa: evita che Stata scelga tipi diversi tra file (es. colonne vuote); converto dopo
		foreach v of local keepingdata {
			capture confirm variable `v'
			if _rc {
				noi di as error "`cc'`yy': variabile `v' assente"						// Variabili assenti in alcuni anni/paesi: creo vuota e segnalo
				gen str1 `v' = ""
			}
		}
		keep `keepingdata'
		foreach v of local keepingdata {
			qui replace `v' = strtrim(`v')
		}
		replace quarter = regexs(1) if regexm(quarter,"([1-4])$")					// QUARTER e' alfanumerico (es. "Q1" o "2014Q1"): tengo la cifra del trimestre
		destring `numvars', replace force											// force: codici non numerici -> missing
		gen paese = "`cc'"																// Codice paese dal nome file
		ren refyear anno																// Stesso nome di RFL
		replace anno = `yy' if missing(anno)

		/* Pesi */
		keep if coeffhh>0 & !missing(coeffhh)							// Sottocampione per analisi con background familiare (HHLINK): User Guide cap. 7.2 prescrive COEFFHH
		gen peso = coeffhh												// Peso annuale (in migliaia). In RFL: coef1/4; qui il peso e' gia' annuale
		qui count
		if r(N)==0 {
			noi di as error "`cc'`yy': nessuna obs con COEFFHH>0 (niente dati familiari): paese-anno escluso"	// Senza HHLINK non posso costruire age_first_birth
			continue
		}

		/* Demographics */
			* Identify HH
		gen trim = quarter												// Trimestre fisso di riferimento (come trim in RFL)
		replace trim = min(ceil(refweek/13),4) if missing(trim) & inrange(refweek,1,53)	// Se QUARTER manca, lo ricavo dalla settimana di riferimento
		qui count if missing(trim)
		if r(N)>0 noi di as error "`cc'`yy': `r(N)' obs senza trimestre (QUARTER/REFWEEK)"
		gen famiglia = paese + "_" + string(anno) + "_" + string(trim) + "_" + hhnum	// Come RFL (anno_trim_mfrfam): la stessa famiglia puo' comparire in piu' trimestri dello stesso anno
			* age
		gen age_lo = real(regexs(1)) if regexm(age_grp,"([0-9]+)[^0-9]+([0-9]+)")	// Estremi della classe (es. "Y5-9" o "5-9"). Rilevante solo per i bambini 0-14 in IT PL HR DK CY
		gen age_hi = real(regexs(2)) if regexm(age_grp,"([0-9]+)[^0-9]+([0-9]+)")
		replace age_lo = real(regexs(1))     if missing(age_lo) & regexm(upper(age_grp),"GE|\+") & regexm(age_grp,"^[^0-9]*([0-9]+)[^0-9]*$")	// Classe aperta (es. "Y_GE75")
		replace age_hi = age_lo + 4          if missing(age_hi) & !missing(age_lo)
		replace age_lo = real(regexs(1)) - 2 if missing(age_lo) & regexm(age_grp,"^([0-9]+)$")			// Codifica a valore centrale (es. 7 = 5-9)
		replace age_hi = age_lo + 4          if missing(age_hi) & !missing(age_lo)
		gen age_imp = missing(age) & !missing(age_lo)
		replace age = runiformint(age_lo,age_hi) if age_imp==1			// Imputed randomly nella classe (come etam in RFL)
		qui count if missing(age)
		if r(N)>0 noi di as error "`cc'`yy': `r(N)' obs con eta' mancante (controllare age_grp)"
		gen year_birth = anno - age										// YEARBIR non e' nei SUF: come RFL (anno-age)
			* Age of the oldest children
		gen tmp = age if inlist(hhlink,3)								// Figlio/a della persona di riferimento (incl. figli del solo partner) = relparm 6,7 in RFL
		egen age_oldest_children = max(tmp), by(famiglia)				// Figlio piu' vecchio co-residente (come RFL: non vedo i figli usciti di casa)
		gen age_first_birth = age - age_oldest_children if inlist(hhlink,1,2)	// Persona di riferimento e partner = relparm 1,2,3 in RFL
		drop if age_first_birth<15										// Come RFL
			* gender
		gen donna = sex==2

		/* Job (proxy: mai lavorato) */
		gen ever_worked = empstat==1 | inrange(yearpr,1900,anno)		// Occupato ora, o anno di fine dell'ultimo lavoro valido. Non uso EXISTPR: codifica cambiata nel 2021

		/* Education */
		gen year_education = hatyear if inrange(hatyear,1900,anno)		// Anno del titolo piu' alto (= qh04 RFL); 9999 = non applicabile
		gen age_education = hatage if inrange(hatage,0,120)				// Eta' al titolo piu' alto (= qh05 RFL), calcolata da Eurostat su YEARBIR esatto
		replace age_education = year_education - year_birth if missing(age_education) & !missing(year_education)	// Come RFL: se manca l'eta', la ricavo dall'anno
		drop if age_education<10										// Come RFL
		gen college = hatlev1d=="H" if inlist(hatlev1d,"L","M","H")		// Terziaria ISCED 5-8 (= edulev 6 RFL; include anche terziaria breve ISCED 5)
		replace college = inrange(hatlevel,500,899) if missing(college) & inrange(hatlevel,0,899)	// Se HATLEV1D manca, uso HATLEVEL

		/* Children & Education */
		gen dif_children = age_first_birth - age_education

		keep if inlist(hhlink,1,2)										// Come RFL
		drop if missing(dif_children)									// Come RFL
		if ${restr_ever_worked}==1 keep if ever_worked==1				// Sostituisce "drop if missing(dif_job)" e "drop if dif_job<0" di RFL

		keep paese anno trim famiglia hhseqnum hhlink age age_imp year_birth donna ///
			age_oldest_children age_first_birth year_education age_education college ///
			hatlevel ever_worked dif_children peso
		compress
		tempfile f_`cc'`yy'
		save `f_`cc'`yy'', replace										// Un file ridotto per paese-anno: evita di caricare tutti i CSV insieme
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
noi tab paese anno													// Paesi-anno presenti (es. SI esce da sola se mancano HATYEAR e HATAGE)
noi tab paese age_imp, row nofreq									// Quota di eta' imputate per paese
noi tabstat age_education age_first_birth, by(paese) stat(mean p50 n)

save "${data}/eulfs_transizione", replace
