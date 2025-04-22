SELECT 
    p.payroll_year AS year,
    p.value AS payroll_value,
    v.name AS value_type,
    i.name AS industry_branch,
    u.name AS unit,
    pc.value AS food_price,  
    cpc.name AS food_category,
    cpc.price_unit AS food_unit
FROM 
    czechia_payroll p
JOIN 
    czechia_payroll_unit u ON p.unit_code = u.code
JOIN 
    czechia_payroll_industry_branch i ON p.industry_branch_code = i.code
JOIN 
    czechia_payroll_value_type v ON p.value_type_code = v.code
JOIN 
    czechia_price pc ON p.payroll_year = YEAR(pc.date_from)
LEFT JOIN 
	czechia_price_category cpc ON pc.category_code = cpc.code
WHERE 
    p.value IS NOT NULL
    AND u.name = "Kč";

