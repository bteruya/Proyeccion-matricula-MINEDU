/*******************************************************************************
					PROYECCIÓN DE VARIABLES EDUCATIVAS
					Orden: 4
					Dofile: Matricula
					Brenda Teruya
*******************************************************************************/
cd "D:\Brenda GoogleDrive\Trabajo\MINEDU_trabajo\Proyecciones"

*-------------------------------Matrícula---------------------------------------
use "3. Data\Datasets_intermedios\matricula_secciones_peru_2013-2018.dta",  clear
isid year CODOOII

destring CODOOII, gen(codooii)
xtset codooii year

tssmooth exponential mat_exp1 = matri_4, forecast(2)  // forecast 2019 y 2020

replace CODOOII = CODOOII[_n-1] if CODOOII == ""

bys codooii: gen mat_ma = (matri_4[_n-1] + matri_4[_n-2] + matri_4[_n-3])/3
replace mat_ma= (mat_ma[_n-1] + matri_4[_n-2] + matri_4[_n-3])/3 if year == 2020

gen epm_ma2018 = abs(mat_ma - matri_4)/matri_4 if year == 2018
gen epm_exp2018 = abs(mat_exp1 - matri_4)/matri_4 if year == 2018
*-------------------------------------------------------------------------------
*Cohort Survival Ratio
gen CSR = (matri_4 + L1.matri_4 + L2.matri_4) /(L1.matri_3 + L2.matri_3 + L3.matri_3)
replace CSR = L1.CSR if inlist(year, 2019,2020)
gen mat_CSR = CSR * L1.matri_4
replace  mat_CSR = CSR * L1.mat_CSR if year == 2019 | year == 2020

gen epm_csr2018 = abs(mat_CSR - matri_4)/matri_4 if year == 2018


*-------------------------------------------------------------------------------
*preparando variables para el bucle

gen yniv = matri_4
label var yniv "Nivel de matri_4"
gen ylog = log(matri_4)
label var ylog "Log matri_4"
gen yinv = 1/matri_4
label var yinv "Inversa matri_4"

gen tniv = year
label var tniv "Nivel de tiempo"
gen tlog = log(year)
label var tlog "Log tiempo"
gen tinv = 1/year
label var tinv "Inversa tiempo"
gen mat_metodo_ue = ""
label var mat_metodo_ue "Método escogido por UGEL con método UE"

gen mat_metodo = ""

gen epm_ue2018 = .

gen mat_ue = .
label var mat_ue "Resultado de estimacion por UGEL"

encode CODOOII, gen(ugel)


foreach y in yniv ylog yinv {

	foreach x in tniv tlog tinv {

	gen modelo_`y'_`x' = .
	label var modelo_`y'_`x' "Estimación del modelo `y' vs `x' "
	gen epm_`y'_`x' = .
	label var epm_`y'_`x' "Error porcentual medio del modelo `y' vs `x' "

	}
}
*-------------------------------------------------------------------------------
*ugel por ugel

summarize ugel
local ugel_max = r(max)

forvalues ugel = 1/`ugel_max' {
	display `ugel'
local mat_min = .
	foreach y in yniv ylog yinv {

		foreach x in tniv tlog tinv {
			
		*local y yniv
		*loca x tniv
		*local ugel 1
		
		regress `y' `x' if ugel == `ugel'
		predict modelo_aux if ugel == `ugel', xb
		
		replace modelo_`y'_`x' = modelo_aux if ugel == `ugel' 
		
		if `y' == ylog {
			replace modelo_`y'_`x' = exp(modelo_`y'_`x')
		} 
		else if `y' == yinv{
			replace modelo_`y'_`x' = 1/modelo_`y'_`x'
		}
		
		replace epm_`y'_`x' = abs(modelo_`y'_`x' - matri_4)/matri_4 ///
			if ugel == `ugel' & year == 2018
		
		mvencode epm_`y'_`x'  if ugel == `ugel', mv(0) override

		summarize epm_`y'_`x' if ugel == `ugel' 
		if r(sum) < `mat_min' {
			local mat_min = r(sum)
			replace mat_metodo_ue = "epm_`y'_`x'" if ugel == `ugel'	

			replace mat_ue =  modelo_`y'_`x' if ugel == `ugel'
			replace epm_ue2018 = epm_`y'_`x' if ugel == `ugel'
		
		}
		
		drop modelo_aux

		}
	}

dis `min_metodo'
codebook mat_metodo_ue
	
}
 
mvencode epm_ma2018  epm_exp2018 epm_ue2018 , mv(0) override
 
local mat_min = .
foreach var of varlist epm_ma2018  epm_exp2018 epm_ue2018 epm_csr2018 {

summarize `var'
	return list
	if r(sum) < `mat_min' {
		local mat_min = r(sum)
		replace mat_metodo = "`var'"	
	}
}

dis `mat_min'
codebook mat_metodo
count if year == 2018
local error = 100*`mat_min'/r(N)
dis "El error porcentual medio del mejor modelo es `error'% para el 2018"

replace epm_ma2018 = epm_ma2018/221
replace epm_exp2018 = epm_exp2018/221
replace epm_ue2018 = epm_ue2018/221
replace epm_csr2018 = epm_csr2018/221


collapse (sum) mat_ue matri_4 mat_exp1 mat_ma mat_CSR ///
	epm_ma2018  epm_exp2018 epm_ue2018 epm_csr2018 , by(year)

export excel using "4. Codigos\Output\Proyeccion.xls", ///
	sheet("Matricula") sheetreplace firstrow(variables)
	
