--Задача 1
WITH Salaries AS (
    SELECT
        map.vsp_id,
        map.manager_id,
        dm.manager_name,
        dm.sal AS sal,
        (
            SELECT sal
            FROM data_manager m
            JOIN map_vsp2manager mvm2 ON m.id = mvm2.manager_id
            WHERE mvm2.vsp_id = map.vsp_id AND m.sal > dm.sal
            ORDER BY m.id DESC
            LIMIT 1
        ) AS bigger_sal,
        (
            SELECT manager_name
            FROM data_manager m
            JOIN map_vsp2manager mvm2 ON m.id = mvm2.manager_id
            WHERE mvm2.vsp_id = map.vsp_id AND m.sal > dm.sal
            ORDER BY m.id DESC
            LIMIT 1
        ) AS bigger_sal_name,
  		(
        	SELECT MAX(dm.sal) 
          	FROM Data_manager as dm
          	JOIN Map_vsp2manager as map2
          	ON dm.id = map2.manager_id
          	WHERE map2.vsp_id =  map.vsp_id
        ) as max_vsp_sal,
  		(SELECT MAX(sal)FROM Data_manager) as max_sal
    FROM map_vsp2manager map
    JOIN data_manager dm ON map.manager_id = dm.id
)
SELECT 
	s.manager_id as id,
    s.manager_name,
    s.sal,
    vsp.vsp_name,
    COALESCE(s.bigger_sal, '-1') as bigger_sal,
    COALESCE(s.bigger_sal_name, '-1') as bigger_sal_name,
    s.max_sal
FROM Salaries  as s
JOIN Data_vsp as vsp
ON s.vsp_id = vsp.id


--Задача 2
WITH EmployeeChanges AS (
  SELECT
    saphr_id,
    department_text,
    start_report_dt,
    end_report_dt,
    is_boss,
    LAG(is_boss, 1, 0) OVER (PARTITION BY saphr_id, department_text ORDER BY start_report_dt) AS prev_is_boss
  FROM employee_profile
),
BossChanges AS (
  SELECT
    saphr_id,
    department_text,
    start_report_dt,
    end_report_dt,
    is_boss
  FROM EmployeeChanges
  WHERE is_boss = 1
),
EmployeePeriods AS (
  SELECT
    e.saphr_id,
    e.department_text,
    e.start_report_dt,
    e.end_report_dt,
    b.saphr_id AS boss_id
  FROM EmployeeChanges e
  LEFT JOIN BossChanges b
    ON e.saphr_id = b.saphr_id
    AND e.department_text = b.department_text
    AND e.start_report_dt >= b.start_report_dt
    AND e.start_report_dt <= b.end_report_dt
)
SELECT
  saphr_id,
  department_text,
  start_report_dt,
  end_report_dt,
  COALESCE(boss_id, -1) AS boss_id
FROM EmployeePeriods
ORDER BY saphr_id, start_report_dt;


--Задача 3
WITH LatestStatus AS (
    SELECT
        id,
        MAX(end_dttm) AS end_dttm
    FROM MS
    GROUP BY id
)

SELECT 
MS.id, 
        	CASE 
        		WHEN l.end_dttm = '9999-12-31' AND DATEDIFF(month, MS.start_dttm, GETDATE()) > 6 THEN 'No changes'
        		WHEN l.end_dttm = '9999-12-31' AND DATEDIFF(month, MS.start_dttm, GETDATE()) <= 6 THEN 'Changed'
        		WHEN l.end_dttm != '9999-12-31' THEN 'Changed'
            END AS Marital_status
FROM LatestStatus as l 
JOIN MS 
ON l.id = MS.id AND MS.end_dttm = l.end_dttm
ORDER BY id




--Задача 4

1) SELECT SUM(
		 i.item_price*ordd.amount
		)
FROM items as i JOIN order_details as ordd
ON ordd.item_id = i.item_id

2) WITH MaxAmountPerItem AS (
    SELECT
        ordd.item_id,
        MAX(ordd.amount) as max_amount
    FROM order_details as ordd
    GROUP BY ordd.item_id
)

SELECT
    i.item_name,
    m.max_amount,
    ord.user_id AS id
FROM MaxAmountPerItem m
JOIN items as i ON m.item_id = i.item_id
JOIN order_details as ordd ON m.item_id = ordd.item_id AND m.max_amount = ordd.amount
JOIN orders as ord ON ordd.order_id = ord.order_id
ORDEr BY i.item_name

3) WITH ordering AS(
SELECT 
  ord.order_id  as  order_id,
  SUM(ordd.amount * i.item_price) as total
FROM Order_details as ordd
JOIN Items as i ON i.item_id = ordd.item_id
JOIN Orders as ord
ON ord.order_id = ordd.order_id
GROUP BY ord.order_id)

SELECT AVG(100 * ord.delivery_price/ ordering.total) FROM ordering
JOIN orders as ord
ON ord.order_id = ordering.order_id



--Задача 5


CREATE PROCEDURE getReport AS
BEGIN 
    DECLARE @i INT
    DECLARE @item_name NVARCHAR(50)
    DECLARE @cost_date DATE
    DECLARE @cost INT
    DECLARE @cost_pr INT
    DECLARE @counter INT
    SET @counter = 1
    SET @i = 1
    
    CREATE TABLE #TempResults (
        id INT IDENTITY(1, 1),
        item_name NVARCHAR(50),
    )
    
    INSERT INTO #TempResults (item_name,amount)
    SELECT DISTINCT item_name, 0
    FROM item_cost
    
    WHILE @i <= (SELECT COUNT(*) FROM #TempResults)
    BEGIN
        DECLARE c1 CURSOR LOCAL FAST_FORWARD FOR
        SELECT item_name, cost_date, cost
        FROM item_cost
        WHERE item_name = (SELECT item_name FROM #TempResults WHERE id = @i)
        
        OPEN c1
        FETCH NEXT FROM c1 INTO @item_name, @cost_date, @cost_pr
        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF (ABS(100*(@cost - @cost_pr)/@cost_pr)) > 1
            BEGIN
                SET @counter = 1;
            END
            ELSE
            BEGIN
                SET @counter = @counter + 1;
            END
            FETCH NEXT FROM c1 INTO @item_name, @cost_date, @cost
        END
       	UPDATE #TempResults
            SET amount = @counter
            WHERE #TempResults.item_name = @item_name
        CLOSE c1
        DEALLOCATE c1
        SET @i = @i + 1
    END
END

EXEC getReport
SELECT * FROM #TempResults
