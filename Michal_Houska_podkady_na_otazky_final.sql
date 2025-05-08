-- zde jsou datove podklady na zodpovezeni otazek

SELECT
    mzdy.rok,
    mzdy.odvetvi,
    mzdy.prumerna_mzda,
    ceny.produkt,
    ceny.prumerna_cena,
    ceny.mnozstvi,
    ceny.jednotka
FROM (
    SELECT
        cp.payroll_year AS rok,
        cpib.name AS odvetvi,
        ROUND(AVG(cp.value), 2) AS prumerna_mzda
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
        cpib.name
) mzdy
JOIN (
    SELECT
        YEAR(cp.date_from) AS rok,
        cpc.name AS produkt,
        ROUND(AVG(cp.value), 2) AS prumerna_cena,
        cpc.price_value AS mnozstvi,
        cpc.price_unit AS jednotka
    FROM czechia_price cp
    JOIN czechia_price_category cpc 
        ON cp.category_code = cpc.code
    GROUP BY 
        YEAR(cp.date_from),
        cpc.name,
        cpc.price_value,
        cpc.price_unit
) ceny
ON mzdy.rok = ceny.rok
ORDER BY mzdy.rok, mzdy.odvetvi, ceny.produkt;


    e.country,
    e.year,
    e.GDP,
    e.gini,
    e.population,
    e.taxes
FROM
    economies e
JOIN
    countries c ON e.country = c.country
WHERE
    c.continent = 'Europe'
ORDER BY
    e.country,
    e.year;




-- 1. otazka: Rostou v průběhu let mzdy ve všech odvětvích, nebo v některých klesají?
    
-- Vypoved: Ano, rostou ve vsech odvetvich, ale nachazeji se male useky, kde prumerna mzda docasne trochu klesne.

SELECT
    rok,
    odvetvi,
    prumerna_mzda,
    LAG(prumerna_mzda) OVER (PARTITION BY odvetvi ORDER BY rok) AS predchozi_mzda,
    ROUND(prumerna_mzda - LAG(prumerna_mzda) OVER (PARTITION BY odvetvi ORDER BY rok), 2) AS zmena,
    CASE 
        WHEN prumerna_mzda < LAG(prumerna_mzda) OVER (PARTITION BY odvetvi ORDER BY rok)
        THEN 'Klesá'
        ELSE 'Roste nebo beze změny'
    END AS trend
FROM (
    SELECT
        cp.payroll_year AS rok,
        cpib.name AS odvetvi,
        ROUND(AVG(cp.value), 2) AS prumerna_mzda
    FROM czechia_payroll cp
    JOIN czechia_payroll_industry_branch cpib ON cp.industry_branch_code = cpib.code
    WHERE cp.value_type_code = (
        SELECT code FROM czechia_payroll_value_type WHERE name = 'Průměrná hrubá mzda na zaměstnance'
    )
    GROUP BY cp.payroll_year, cpib.name
) mzdy
ORDER BY odvetvi, rok;



-- 2. otazka: Kolik je možné si koupit litrů mléka a kilogramů chleba za první a poslední srovnatelné období v dostupných datech cen a mezd?

-- Vypoved: Za 1. srovnatelne obdobi(=SO) si muzeme za 20,667 kc koupit 1282 chlebu, za posledni SO si koupime 1340 chlebu. Pri cene mleka to je 1. SO 1431 a pri poslednim SO to je 1639.

WITH mzdy AS (
    SELECT
        cp.payroll_year AS rok,
        ROUND(AVG(cp.value), 2) AS prumerna_mzda
    FROM czechia_payroll cp
    WHERE cp.value_type_code = (
        SELECT code 
        FROM czechia_payroll_value_type 
        WHERE name = 'Průměrná hrubá mzda na zaměstnance'
    )
    GROUP BY cp.payroll_year
),
ceny AS (
    SELECT
        YEAR(cp.date_from) AS rok,
        cpc.name AS produkt,
        ROUND(AVG(cp.value), 2) AS prumerna_cena,
        cpc.price_value AS mnozstvi
    FROM czechia_price cp
    JOIN czechia_price_category cpc ON cp.category_code = cpc.code
    WHERE cpc.name IN ('Mléko polotučné pasterované', 'Chléb konzumní kmínový')
    GROUP BY YEAR(cp.date_from), cpc.name, cpc.price_value
),
spojene AS (
    SELECT 
        c.rok,
        c.produkt,
        m.prumerna_mzda,
        c.prumerna_cena,
        ROUND(m.prumerna_mzda / (c.prumerna_cena / c.mnozstvi), 2) AS mozne_mnozstvi
    FROM ceny c
    JOIN mzdy m ON c.rok = m.rok
),
hranice AS (
    SELECT MIN(rok) AS prvni, MAX(rok) AS posledni FROM spojene
)
SELECT 
    s.rok,
    s.produkt,
    s.prumerna_mzda,
    s.prumerna_cena,
    s.mozne_mnozstvi
FROM spojene s
JOIN hranice h ON s.rok = h.prvni OR s.rok = h.posledni
ORDER BY s.produkt, s.rok;



-- 3. otazka: Která kategorie potravin zdražuje nejpomaleji (je u ní nejnižší percentuální meziroční nárůst)?

-- Vypoved: Nepomaleji se "zdrazuje" curk krystolovy a to o prumer -1.92 %.

WITH rocni_ceny AS (
    SELECT
        YEAR(cp.date_from) AS rok,
        cpc.name AS produkt,
        ROUND(AVG(cp.value), 2) AS prumerna_cena
    FROM czechia_price cp
    JOIN czechia_price_category cpc ON cp.category_code = cpc.code
    GROUP BY YEAR(cp.date_from), cpc.name
),
rocni_zmena AS (
    SELECT
        produkt,
        rok,
        prumerna_cena,
        LAG(prumerna_cena) OVER (PARTITION BY produkt ORDER BY rok) AS predchozi_cena
    FROM rocni_ceny
)
SELECT
    produkt,
    ROUND(AVG((prumerna_cena - predchozi_cena) / predchozi_cena * 100), 2) AS prumerna_mezirocni_zmena_pct
FROM rocni_zmena
WHERE predchozi_cena IS NOT NULL
GROUP BY produkt
ORDER BY prumerna_mezirocni_zmena_pct ASC
LIMIT 1;


-- 4. otazka: Existuje rok, ve kterém byl meziroční nárůst cen potravin výrazně vyšší než růst mezd (větší než 10 %)?

-- Vypoved: Zadne vyrazne narusty cena nad 10 % nejsou.

WITH mzdy AS (
    SELECT
        payroll_year AS rok,
        ROUND(AVG(value), 2) AS prumerna_mzda
    FROM czechia_payroll
    WHERE value_type_code = (
        SELECT code FROM czechia_payroll_value_type WHERE name = 'Průměrná hrubá mzda na zaměstnance'
    )
    GROUP BY payroll_year
),
ceny AS (
    SELECT
        YEAR(cp.date_from) AS rok,
        ROUND(AVG(cp.value), 2) AS prumerna_cena
    FROM czechia_price cp
    GROUP BY YEAR(cp.date_from)
),
zmeny AS (
    SELECT
        mzdy.rok,
        mzdy.prumerna_mzda,
        ceny.prumerna_cena,
        LAG(mzdy.prumerna_mzda) OVER (ORDER BY mzdy.rok) AS mzda_pred,
        LAG(ceny.prumerna_cena) OVER (ORDER BY ceny.rok) AS cena_pred
    FROM mzdy
    JOIN ceny ON mzdy.rok = ceny.rok
)
SELECT
    rok,
    ROUND((prumerna_mzda - mzda_pred) / mzda_pred * 100, 2) AS rust_mezd_pct,
    ROUND((prumerna_cena - cena_pred) / cena_pred * 100, 2) AS rust_cen_pct,
    ROUND((prumerna_cena - cena_pred) / cena_pred * 100 - (prumerna_mzda - mzda_pred) / mzda_pred * 100, 2) AS rozdil
FROM zmeny
WHERE mzda_pred IS NOT NULL AND cena_pred IS NOT NULL
  AND ((prumerna_cena - cena_pred) / cena_pred * 100 - (prumerna_mzda - mzda_pred) / mzda_pred * 100) > 10;



-- 5. otazka: Má výška HDP vliv na změny ve mzdách a cenách potravin? Neboli, pokud HDP vzroste výrazněji v jednom roce, projeví se to na cenách potravin či mzdách ve stejném nebo násdujícím roce výraznějším růstem?

-- Vypoved: Ano, vliv to ma, ale cena neni primo umerna HDP, takze s vyssim HDP jsou ceny jakoby "levnejsi" - nemaji takovou hodnotu jako meli predtim

WITH mzdy AS (
    SELECT
        payroll_year AS year,
        ROUND(AVG(value), 2) AS avg_salary
    FROM czechia_payroll
    WHERE value_type_code = (
        SELECT code FROM czechia_payroll_value_type
        WHERE name = 'Průměrná hrubá mzda na zaměstnance'
    )
    GROUP BY payroll_year
),
ceny AS (
    SELECT
        YEAR(date_from) AS year,
        ROUND(AVG(value), 2) AS avg_price
    FROM czechia_price
    GROUP BY YEAR(date_from)
),
ekonomika_cr AS (
    SELECT
        e.year,
        e.GDP,
        e.gini,
        e.population,
        e.taxes
    FROM economies e
    JOIN countries c ON e.country = c.country
    WHERE c.country = 'Czech Republic'
)
SELECT
    e.year,
    e.GDP,
    e.gini,
    e.population,
    e.taxes,
    mzdy.avg_salary,
    ceny.avg_price
FROM ekonomika_cr e
LEFT JOIN mzdy ON mzdy.year = e.year
LEFT JOIN ceny ON ceny.year = e.year
ORDER BY e.year;


