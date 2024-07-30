-- Задача 1

-- Создание таблицы

CREATE TABLE Cash (
    Id INT PRIMARY KEY,
    pdate SMALLDATETIME NOT NULL,
    Pay MONEY NOT NULL,
    balance MONEY NOT NULL
);

-- Заполнение таблицы

-- Создаем временную таблицу для хранения уникальных идентификаторов
CREATE TABLE #TempIds (
    Id INT PRIMARY KEY
);

-- Заполняем временную таблицу уникальными идентификаторами
DECLARE @Id INT = 1;
WHILE @Id <= 1000
BEGIN
    INSERT INTO #TempIds (Id)
    VALUES (@Id);

    SET @Id = @Id + 1;
END;

-- Создаем временную таблицу для хранения уникальных дат
CREATE TABLE #TempDates (
    Pdate SMALLDATETIME PRIMARY KEY
);

-- Заполняем временную таблицу уникальными датами
DECLARE @Date SMALLDATETIME = '2023-01-01';
WHILE @Date <= '2023-12-31'
BEGIN
    INSERT INTO #TempDates (Pdate)
    VALUES (@Date);

    SET @Date = DATEADD(DAY, 1, @Date);
END;

-- Вставляем данные в таблицу Cash
DECLARE @CurrentId INT;
DECLARE @RandomDate SMALLDATETIME;
DECLARE @Pay MONEY;

-- Цикл по всем Id
DECLARE IdCursor CURSOR FOR
SELECT Id FROM #TempIds;

OPEN IdCursor;

FETCH NEXT FROM IdCursor INTO @CurrentId;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Для каждого Id выбираем от 10 до 15 уникальных дат
    DECLARE @DateCount INT = 10 + ABS(CHECKSUM(NEWID()) % 6);

    -- Вставляем записи в таблицу Cash
    DECLARE @InsertedDates TABLE (Pdate SMALLDATETIME);

    WHILE (SELECT COUNT(*) FROM @InsertedDates) < @DateCount
    BEGIN
        -- Выбираем случайную дату
        SELECT TOP 1 @RandomDate = Pdate
        FROM #TempDates
        WHERE Pdate NOT IN (SELECT Pdate FROM @InsertedDates)
        ORDER BY NEWID();

        -- Генерируем случайную сумму Pay
        SET @Pay = CAST((RAND() * 2000 - 1000) AS DECIMAL(10,2));

        -- Вставляем запись
        INSERT INTO Cash (Id, pdate, Pay, balance)
        VALUES (@CurrentId, @RandomDate, @Pay, NULL);

        -- Добавляем дату в список вставленных дат
        INSERT INTO @InsertedDates (Pdate)
        VALUES (@RandomDate);
    END;

    FETCH NEXT FROM IdCursor INTO @CurrentId;
END;

CLOSE IdCursor;
DEALLOCATE IdCursor;

-- Удаляем временные таблицы
DROP TABLE #TempIds;
DROP TABLE #TempDates;


---Заполнение поля balance

-- Обновляем поле balance накопительной суммой
WITH RunningTotals AS (
    SELECT
        Id,
        pdate,
        Pay,
        SUM(Pay) OVER (PARTITION BY Id ORDER BY pdate, Id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS RunningTotal
    FROM
        Cash
)
UPDATE Cash
SET balance = RunningTotal
FROM RunningTotals
WHERE Cash.Id = RunningTotals.Id
AND Cash.pdate = RunningTotals.pdate
AND Cash.Pay = RunningTotals.Pay;


-- Задача 2
-- 1

-- Создание таблицы LastModifiedDate
CREATE TABLE LastModifiedDate
(
    CurrencyId int PRIMARY KEY,
    LastModifiedDate datetime
);

-- Заполнение таблицы LastModifiedDate
INSERT INTO LastModifiedDate (CurrencyId, LastModifiedDate)
SELECT CurrencyId, MAX(Cdate) AS LastModifiedDate
FROM ExchangeRate
GROUP BY CurrencyId;

-- Запрос для получения курса валют на заданную дату
DECLARE @Date datetime = '2024-07-25'; -- Укажите здесь вашу дату

SELECT 
    c.Name AS Валюта, 
    er.Rate AS [Курс на дату]
FROM 
    Currency c
JOIN 
    LastModifiedDate lmd ON c.Id = lmd.CurrencyId
JOIN 
    ExchangeRate er ON er.CurrencyId = c.Id AND er.Cdate = (
        SELECT MAX(Cdate)
        FROM ExchangeRate
        WHERE CurrencyId = c.Id AND Cdate <= @Date
    )
ORDER BY 
    c.Name;

-- 2

DECLARE @Bdate datetime = '2024-07-01'; -- Укажите начальную дату периода
DECLARE @Edate datetime = '2024-07-25'; -- Укажите конечную дату периода

SELECT 
    c.Name AS Валюта
FROM 
    Currency c
JOIN 
    ExchangeRate er ON c.Id = er.CurrencyId
WHERE 
    er.Cdate BETWEEN @Bdate AND @Edate
GROUP BY 
    c.Id, c.Name
HAVING 
    COUNT(DISTINCT er.Rate) = 1
ORDER BY 
    c.Name;


-- 3

WITH RankedRates AS (
    SELECT
        CurrencyId,
        Rate,
        Cdate,
        ROW_NUMBER() OVER (PARTITION BY CurrencyId ORDER BY Cdate) - 
        ROW_NUMBER() OVER (PARTITION BY CurrencyId, Rate ORDER BY Cdate) AS Grp
    FROM 
        ExchangeRate
), Periods AS (
    SELECT
        CurrencyId,
        Rate,
        MIN(Cdate) AS Bdate,
        MAX(Cdate) AS Edate
    FROM
        RankedRates
    GROUP BY
        CurrencyId,
        Rate,
        Grp
)
SELECT 
    CurrencyId,
    Rate,
    Bdate,
    Edate
FROM 
    Periods
ORDER BY 
    CurrencyId, 
    Bdate;
