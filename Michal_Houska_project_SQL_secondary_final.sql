SELECT
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
