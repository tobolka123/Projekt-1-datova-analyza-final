
-- discord: Tobolka			 @michalhouska

-- Zalozeni prvni tabulky, pojednava o rustu cen potravin a rustu mzdy v CR


SELECT
    cp.payroll_year AS rok,
    cpib.name AS odvetvi,
    ROUND(AVG(cp.value), 2) AS prumer
FROM czechia_payroll cp
JOIN czechia_payroll_industry_branch cpib 
    ON cp.industry_branch_code = cpib.code
WHERE 
    cp.industry_branch_code IS NOT NULL
    AND cp.value_type_code = (
        SELECT code 
        FROM czechia_payroll_value_type 
        WHERE name = 'Průměrná hrubá mzda na zaměstnance'
    )
GROUP BY 
    cp.payroll_year,
    cp.industry_branch_code;

SELECT
    YEAR(cp.date_from) AS rok,
    cpc.name AS produkt,
    ROUND(AVG(cp.value), 2) AS prumer,
    cpc.price_value AS mnozstvi,
    cpc.price_unit AS jednotka
FROM czechia_price cp
JOIN czechia_price_category cpc 
    ON cp.category_code = cpc.code
GROUP BY 
    cp.category_code,
    YEAR(cp.date_from);

SELECT COUNT(*) AS differing_years
FROM czechia_price
WHERE YEAR(date_from) != YEAR(date_to);

-- finalni tabulka s propojenou cenou a mzdou


SELECT
    mzdy.rok,
    mzdy.odvetvi,
    mzdy.prumer AS prumerna_mzda,
    ceny.produkt,
    ceny.prumer AS prumerna_cena,
    ceny.mnozstvi,
    ceny.jednotka
FROM (
    SELECT
        cp.payroll_year AS rok,
        cpib.name AS odvetvi,
        ROUND(AVG(cp.value), 2) AS prumer
    FROM czechia_payroll cp
    JOIN czechia_payroll_industry_branch cpib 
        ON cp.industry_branch_code = cpib.code
    WHERE 
        cp.industry_branch_code IS NOT NULL
        AND cp.value_type_code = (
            SELECT code 
            FROM czechia_payroll_value_type 
            WHERE name = 'Průměrná hrubá mzda na zaměstnance'
        )
    GROUP BY 
        cp.payroll_year,
        cp.industry_branch_code
) mzdy
JOIN (
    SELECT
        YEAR(cp.date_from) AS rok,
        cpc.name AS produkt,
        ROUND(AVG(cp.value), 2) AS prumer,
        cpc.price_value AS mnozstvi,
        cpc.price_unit AS jednotka
    FROM czechia_price cp
    JOIN czechia_price_category cpc 
        ON cp.category_code = cpc.code
    GROUP BY 
        cp.category_code,
        YEAR(cp.date_from)
) ceny
ON mzdy.rok = ceny.rok;