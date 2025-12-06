CREATE DATABASE customer_transactions;
USE customer_transactions;

-- импортируем таблицу customers из файла csv
SELECT * FROM customers; -- проверка 

-- заменяем пустые поля на NULL
UPDATE customers SET gender = NULL WHERE gender = '';
UPDATE customers SET age = NULL  WHERE age= '';
ALTER TABLE customers MODIFY age  INT NULL;

-- вторую таблицу создаем через запрос
CREATE TABLE  transactions
(date_new DATE,
id_check  INT,
id_client INT,
count_products DECIMAL(10,3),
sum_payment DECIMAL(10,2));

-- загружаем данные в новую, пустую таблицу
LOAD DATA INFILE "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions_info_final.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ';'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM transactions;

/*Используя данные таблиц customer_info.xlsx (информация о клиентах) и transactions_info.xlsx 
(информация о транзакциях за период с 01.06.2015 по 01.06.2016), нужно вывести:
1. список клиентов с непрерывной историей за год, то есть каждый месяц на регулярной основе 
без пропусков за указанный годовой период, средний чек за период с 01.06.2015 по 01.06.2016, 
средняя сумма покупок за месяц, количество всех операций по клиенту за период;*/

WITH active_clients AS (
    SELECT ID_client
    FROM transactions
    WHERE date_new BETWEEN '2015-06-01' AND '2016-05-31'
    GROUP BY ID_client
    HAVING COUNT(DISTINCT DATE_FORMAT(date_new, '%Y-%m')) = 12
)
SELECT  tr.ID_client,  ct.Gender,  ct.age,
    ROUND(AVG(tr.Sum_payment), 2) AS avg_check,         -- средний чек клиента
    ROUND(SUM(tr.Sum_payment) / 12, 2) AS avg_monthly_sum, -- средняя сумма покупок клиента за месяц 
    COUNT(*) AS total_operations                 -- количество всех операций клиента
FROM transactions tr
JOIN active_clients ac ON ac.ID_client = tr.ID_client
LEFT JOIN customers ct ON ct.Id_client = tr.ID_client
WHERE tr.date_new BETWEEN '2015-06-01' AND '2016-05-31'
GROUP BY tr.ID_client, ct.Gender, ct.age
ORDER BY tr.ID_client;

/*2. информацию в разрезе месяцев:
a. средняя сумма чека в месяц;
b. количество операций в месяц;
c. количество клиентов, которые совершали операции;
d. долю от общего количества операций за год и долю в месяц от общей суммы операций;
e. вывести % соотношение M/F/NA в каждом месяце с их долей затрат; */

SELECT
    DATE_FORMAT(tr.date_new, '%Y-%m') AS month,
    ROUND(AVG(tr.Sum_payment),2)      AS avg_check,          -- a. средняя сумма чека в месяц;
	COUNT(*)                          AS total_operations,   -- b. количество операций в месяц;
    COUNT(DISTINCT tr.ID_client)      AS total_clients,    -- c. количество клиентов, которые совершали операции;
-- d. долю от общего количества операций за год и долю в месяц от общей суммы операций;  
    ROUND(COUNT(*)*100.0 / SUM(COUNT(*)) OVER (),2) AS "% operations_of_year",
    ROUND(SUM(tr.Sum_payment)*100.0 / SUM(SUM(tr.Sum_payment)) OVER (),2) AS "% amount_of_year",
--  e. вывести % соотношение M/F/NA в каждом месяце с их долей затрат;  
	ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='M' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS "% ops_M", 
	ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='F' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS "% ops_F",
	ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='NA' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS "% ops_NA",
    ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='M' THEN tr.sum_payment END) * 100.0 / SUM(tr.sum_payment), 2) AS "% amount_M",
	ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='F' THEN tr.sum_payment END) * 100.0 / SUM(tr.sum_payment), 2) AS "% amount_F",
	ROUND(SUM(CASE WHEN COALESCE(ct.gender,'NA')='NA' THEN tr.sum_payment END) * 100.0 / SUM(tr.sum_payment), 2) AS "% amount_NA"
FROM transactions tr
LEFT JOIN customers ct ON ct.Id_client = tr.ID_client
WHERE tr.date_new BETWEEN '2015-06-01' AND '2016-05-31' -- так как в пункте d напсиано за год, поэтому июнь 2016 не включительно 
GROUP BY DATE_FORMAT(tr.date_new, '%Y-%m')
ORDER BY month;


/*3. возрастные группы клиентов с шагом 10 лет и отдельно клиентов, у которых нет данной информации, 
с параметрами сумма и количество операций за весь период, и поквартально - средние показатели и %.*/
WITH quarterly_data AS (
    SELECT 
        CASE 
            WHEN ct.age IS NULL THEN 'Not specified'
            WHEN ct.age < 10 THEN '0 to 9 years'
            WHEN ct.age < 20 THEN '10 to 19 years'
            WHEN ct.age < 30 THEN '20 to 29 years'
            WHEN ct.age < 40 THEN '30 to 39 years'
            WHEN ct.age < 50 THEN '40 to 49 years'
            WHEN ct.age < 60 THEN '50 to 59 years'
            WHEN ct.age < 70 THEN '60 to 69 years'
            ELSE '70 years and older'
        END AS age_group,
        CONCAT(YEAR(tr.date_new), '-Q', QUARTER(tr.date_new)) AS quarter,
        SUM(tr.Sum_payment) AS quarterly_amount,
        COUNT(*) AS quarterly_operations
    FROM transactions tr
    LEFT JOIN customers ct ON ct.Id_client = tr.ID_client
    GROUP BY age_group, quarter
)
SELECT
    age_group,
    SUM(quarterly_amount) AS total_amount,
    SUM(quarterly_operations) AS total_operations,
    ROUND(AVG(quarterly_amount), 2) AS avg_quarterly_amount,
    ROUND(AVG(quarterly_operations), 2) AS avg_quarterly_operations,
    ROUND(SUM(quarterly_amount) * 100.0 / SUM(SUM(quarterly_amount)) OVER (), 2) AS pct_of_total_amount,
    ROUND(SUM(quarterly_operations) * 100.0 / SUM(SUM(quarterly_operations)) OVER (), 2) AS pct_of_total_operations
FROM quarterly_data
GROUP BY age_group
ORDER BY age_group;
   
