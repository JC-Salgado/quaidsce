*! version 1.1.1  1dec2020

program quaidsce, eclass

	version 12
	ms_get_version quaidsce
	ms_compile_mata, package(quaidsce) version(`package_version')
	
	if replay() {
		if "`e(cmd)'" != "quaidsce" {
			error 301 
		}
		Display `0'
		exit
	}
	
	Estimate `0'

end

program Estimate, eclass

	version 12

	syntax varlist [if] [in] ,					///
		  ANOT(real)						///
		[ LNEXPenditure(varlist min=1 max=1 numeric) 		///
		  EXPenditure(varlist min=1 max=1 numeric) 		///
		  PRices(varlist numeric)				///
		  LNPRices(varlist numeric) 				///
		  DEMOgraphics(varlist numeric)				///
		  noQUadratic 						///
		  noCEnsor   ///
		  INITial(name) noLOg Level(cilevel) VCE(passthru) * ]
		  
	local shares `varlist'
	
	di `shares'
	
	if "`options'" != "" {
		di as error "`options' not allowed"
		exit 198
	}
	
	if "`prices'" != "" & "`lnprices'" != "" {
		di as error "cannot specify both {cmd:prices()} and "	///
			as error "{cmd:lnprices()}"
		exit 198
	}
	if "`prices'`lnprices'" == "" {
		di as error "must specify {cmd:prices()} or {cmd:lnprices()}"
		exit 198
	}
	
	if "`expenditure'" != "" & "`lnexpenditure'" != "" {
		di as error "cannot specify both {cmd:expenditure()} "	///
			as error "and {cmd:lnexpenditure()}"
		exit 198
	}
	if "`expenditure'`lnexpenditure'" == "" {
		di as error						///
"must specify {cmd:expenditure()} or {cmd:lnexpenditure()}"
		exit 198
	}
		
	local neqn : word count `shares'
	if `neqn' < 3 {
		di as error "must specify at least 3 expenditure shares"
		exit 498
	}
	
	if `=`:word count `prices'' + `:word count `lnprices''' != `neqn' {
		if "`prices'" != "" {
			di as error "number of price variables must "	///
				as error "equal number of equations "	///
				as error "(`neqn')"
		}
		else {
			di as error "number of log price variables "	///
				as error "must equal number of "	///
				as error "equations (`neqn')"
		}
		exit 498
	}

	marksample touse
	markout `touse' `prices' `lnprices' `demographics'
	markout `touse' `expenditure' `lnexpenditure'



	local i 1
	while (`i' < `neqn') {
		local shares2 `shares2' `:word `i' of `shares''
		local `++i'
	}
	
	// Check whether variables make sense
	tempvar sumw
	egen double `sumw' = rsum(`shares') if `touse'
	cap assert reldif(`sumw', 1) < 1e-4 if `touse'
	if _rc {
		di as error "expenditure shares do not sum to one"
		exit 499
	}

	if "`prices'" != "" {
		local usrprices 1
		local lnprices
		foreach x of varlist `prices' {
			summ `x' if `touse', mean
			if r(min) <= 0 {
				di as error "nonpositive value(s) for `x' found"
				exit 499
			}
			tempvar ln`x'
			qui gen double `ln`x'' = ln(`x') if `touse'
			local lnprices `lnprices' `ln`x''
		}
	}
	if "`expenditure'" != "" {
		local usrexpenditure 1
		summ `expenditure' if `touse', mean
		if r(min) <= 0 {
			di as error "nonpositive value(s) for "		///
				as error "`expenditure' found"
			exit 499
		}
		tempvar lnexp
		qui gen double `lnexp' = ln(`expenditure') if `touse'
		local lnexpenditure `lnexp'
	}
	
	
	if "`quadratic'" == "noquadratic" {
		local np = 2*(`neqn'-1) + `neqn'*(`neqn'-1)/2
	}
	else {
		local np = 3*(`neqn'-1) + `neqn'*(`neqn'-1)/2
	}
	
	
	
	if "`demographics'" == "" {
		local demos "nodemos"
		local demoopt ""
		local ndemos = 0
	}
	else {
		local demos ""
		local demoopt "demographics(`demographics')"
		local ndemos : word count `demographics'
		local np = `np' + `ndemos'*(`neqn'-1) + `ndemos'
	}
	
	if "`initial'" != "" {
		local rf = rowsof(`initial')
		local cf = colsof(`initial')
		if `rf' != 1 | `cf' != `np' {
			di "Initial vector must be 1 x `np'"
			exit 503
		}
		else {
			local initialopt initial(`initial')
		}
	}
	
	// GM: Check whether censoring exists & Probit
	
		if "`censor'" == "nocensor" {
		}
		else {
		local np2 : word count `lnprices' `lnexp'  `demographics' intercept
		mat c=J(1,`np2',.)
		local pdf 
		local cdf
		foreach x of varlist `shares' {
			summ `x' if `touse', mean
			if r(min) > 0 {
				di as error "noncensoring for `x' found"
				exit 499
			}

	// GM: Probit	as 
				
			tempvar z`x' pdf`x' cdf`x' du`x' tmp`x' tau
			qui gen double `z`x'' = 1 if `x' > 0  & `touse'
			replace `z`x'' = 0 if `x' == 0  & `touse'
			probit `z`x'' `lnprices' `lnexp'   `demographics'
			matrix `tmp`x''=e(b)
			

			quietly predict `du`x''
			gen `pdf`x''= normalden(`du`x'')
			gen `cdf`x''= normal(`du`x'')
	
		
			mat c=c \ `tmp`x''
			local pdf `pdf' `pdf`x''
			local cdf `cdf' `cdf`x''
			
		}
		*delete the first row
		mata st_matrix("tau",select(st_matrix("c"),st_matrix("c")[.,2]:~=.))
		
		local i 1
		while (`i' < `neqn') {
		local pdf2 `pdf2' `:word `i' of `pdf''
		local `++i'
		}
		local i 1
		while (`i' < `neqn') {
		local cdf2 `cdf2' `:word `i' of `cdf''
		local `++i'
		local np = `np' + (`neqn'-1) 
		
	}
	}
	
	
	nlsur __quaidsce @ `shares2' if `touse',				///
		lnp(`lnprices') lnexp(`lnexpenditure') cdfi(`cdf2') pdfi(`pdf2') a0(`anot')	///
		nparam(`np') neq(`=`neqn'-1') fgnls noeqtab nocoeftab	///
		`quadratic' `options' `demoopt'  `initialopt' `log' `vce'
		
		*add `censor'

	// do delta method to get cov matrix

	tempname b bfull V Vfull Delta
	mat `b' = e(b)
	mat `V' = e(V)

	mata:_quaidsce__fullvector("`b'", `neqn', "`quadratic'", 		///
					`ndemos', "`bfull'")
	mata:_quaidsce__delta(`neqn', "`quadratic'", `ndemos', "`Delta'")
	mat `Vfull' = `Delta'*`V'*`Delta''

	forvalues i = 1/`neqn' {
		local namestripe `namestripe' alpha:alpha_`i'
	}
	forvalues i = 1/`neqn' {
		local namestripe `namestripe' beta:beta_`i'
	}
	forvalues j = 1/`neqn' {
		forvalues i = `j'/`neqn' {
			local namestripe `namestripe' gamma:gamma_`i'_`j'
		}
	}
	if "`quadratic'" == "" {
		forvalues i = 1/`neqn' {
			local namestripe `namestripe' lambda:lambda_`i'
		}
	}
	if `ndemos' > 0 {
		foreach var of varlist `demographics' {
			forvalues i = 1/`neqn' {
				local namestripe `namestripe' eta:eta_`var'_`i'
			}
		}
		foreach var of varlist `demographics' {
			local namestripe `namestripe' rho:rho_`var'
		}
	}
	
	mat colnames `bfull' = `namestripe'
	mat colnames `Vfull' = `namestripe'
	mat rownames `Vfull' = `namestripe'
	
	tempname alpha beta gamma lambda eta rho ll
	mata:_quaidsce__getcoefs("`b'", `neqn', "`quadratic'", `ndemos', 	///
			"`alpha'", "`beta'", "`gamma'", "`lambda'",	///
			"`eta'", "`rho'")	
	scalar `ll' = e(ll)
	local vcetype	`e(vcetype)'
	local clustvar	`e(clustvar)'
	local vcer	`e(vce)'
	local nclust	`e(N_clust)'

	qui count if `touse'
	local capn = r(N)
	
	eret post 		`bfull' `Vfull', esample(`touse')	
	eret matrix alpha	= `alpha'
	eret matrix beta	= `beta'
	eret matrix gamma	= `gamma'
	if "`quadratic'" == "" {
		eret matrix lambda = `lambda'
	}
	else {
		eret local quadratic	"noquadratic"
	}
	if `ndemos' > 0 {
		eret matrix eta = `eta'
		eret matrix rho = `rho'
		eret local demographics `demographics'
		eret scalar ndemos = `ndemos'
	}
	else {
		eret scalar ndemos = 0
	}
	
	eret scalar N		= `capn'
	eret scalar ll		= `ll'
	
	eret scalar anot	= `anot'
	eret scalar ngoods	= `neqn'

	if "`usrprices'" != "" {
		eret local prices	`prices'
	}
	else {
		eret local lnprices	`lnprices'
	}
	if "`usrexpenditure'" != "" {
		eret local expenditure	`expenditure'
	}
	else {
		eret local lnexpenditure `lnexpenditure'
	}
	eret local lhs		"`shares'"
	eret local demographics	"`demographics'"
	
	eret local vcetype	`vcetype'
	eret local clustvar	`clustvar'
	eret local vcer		`vce'
	if "`nclust'" != "" {
		eret scalar N_clust	= `nclust'
	}
	
	eret local predict	"quaidsce_p"
	eret local estat_cmd 	"quaidsce_estat"
	eret local cmd 		"quaidsce"

	Display, level(`level')

end

program Display

	syntax , [Level(cilevel)]
	
	di
	if "`e(quadratic)'" == "" {
		di in smcl as text "Quadratic AIDS model"
		di in smcl as text "{hline 20}"
	}
	else {
		di in smcl as text "AIDS model"
		di in smcl as text "{hline 10}"
	}
	di as text "Number of obs          = " as res %10.0g `=e(N)'
	di as text "Number of demographics = " as res %10.0g `=e(ndemos)'
	di as text "Alpha_0                = " as res %10.0g `=e(anot)'
	di as text "Log-likelihood         = " as res %10.0g `=e(ll)'
	di
	
	_coef_table, level(`level')
	
end
exit

