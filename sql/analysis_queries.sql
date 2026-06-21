/* ============================================================
   ASX SECTOR PULSE — SQL ANALYSIS QUERIES
   ============================================================
   Dataset : 10 ASX-listed companies across 3 sectors
             Banking    -> CBA, ANZ, NAB, WBC
             Retail     -> WOW, COL, JBH
             Healthcare -> CSL, RMD, COH
   Period  : 2 years of daily closing prices
   Table   : StockPrices (TradeDate, Ticker, ClosePrice, TradeDate_clean)
   Tool    : SQLite (tested in DBeaver)
   ============================================================ */


/* ------------------------------------------------------------
   QUERY 1 — Daily Price Trend

   QUESTION: How has each stock's price moved day by day
   over the 2-year period?
   ------------------------------------------------------------ */
SELECT
    TradeDate_clean AS TradeDate,
    Ticker,
    CASE
        WHEN Ticker IN ('CBA','ANZ','NAB','WBC') THEN 'Banking'
        WHEN Ticker IN ('WOW','COL','JBH')       THEN 'Retail'
        WHEN Ticker IN ('CSL','RMD','COH')       THEN 'Healthcare'
    END AS Sector,
    ClosePrice
FROM StockPrices
ORDER BY Ticker, TradeDate_clean;


/* ------------------------------------------------------------
   QUERY 2 — Monthly Return %

   QUESTION: In any given month, did each stock go up or down,
   and by how much?
   ------------------------------------------------------------ */
WITH MonthlyPrices AS (
    SELECT
        Ticker,
        strftime('%Y-%m', TradeDate_clean) AS YearMonth,
        ClosePrice,
        ROW_NUMBER() OVER (
            PARTITION BY Ticker, strftime('%Y-%m', TradeDate_clean)
            ORDER BY TradeDate_clean ASC
        ) AS rn_first,
        ROW_NUMBER() OVER (
            PARTITION BY Ticker, strftime('%Y-%m', TradeDate_clean)
            ORDER BY TradeDate_clean DESC
        ) AS rn_last
    FROM StockPrices
)
SELECT
    Ticker,
    YearMonth,
    MAX(CASE WHEN rn_first = 1 THEN ClosePrice END) AS MonthOpen,
    MAX(CASE WHEN rn_last  = 1 THEN ClosePrice END) AS MonthClose,
    ROUND(
        (MAX(CASE WHEN rn_last = 1 THEN ClosePrice END)
         - MAX(CASE WHEN rn_first = 1 THEN ClosePrice END))
        / MAX(CASE WHEN rn_first = 1 THEN ClosePrice END) * 100
    , 2) AS MonthlyReturnPct
FROM MonthlyPrices
GROUP BY Ticker, YearMonth
ORDER BY Ticker, YearMonth;


/* ------------------------------------------------------------
   QUERY 3 — Volatility by Ticker

   QUESTION: Which stocks are risky/jumpy day-to-day, and
   which are stable?
   ------------------------------------------------------------ */
WITH DailyReturns AS (
    SELECT
        Ticker,
        (ClosePrice - LAG(ClosePrice) OVER (PARTITION BY Ticker ORDER BY TradeDate_clean))
            / LAG(ClosePrice) OVER (PARTITION BY Ticker ORDER BY TradeDate_clean) * 100 AS DailyReturnPct
    FROM StockPrices
)
SELECT
    Ticker,
    ROUND(AVG(DailyReturnPct), 4) AS AvgDailyReturn,
    ROUND(
        SQRT(AVG(DailyReturnPct*DailyReturnPct) - AVG(DailyReturnPct)*AVG(DailyReturnPct))
    , 4) AS Volatility
FROM DailyReturns
WHERE DailyReturnPct IS NOT NULL
GROUP BY Ticker
ORDER BY Ticker;


/* ------------------------------------------------------------
   QUERY 4 — Cumulative Return Ranking

   QUESTION: If I'd invested $100 in each stock 2 years ago,
   which made me the most money?
   ------------------------------------------------------------ */
WITH FirstLast AS (
    SELECT
        Ticker,
        FIRST_VALUE(ClosePrice) OVER (
            PARTITION BY Ticker ORDER BY TradeDate_clean
        ) AS FirstPrice,
        LAST_VALUE(ClosePrice) OVER (
            PARTITION BY Ticker ORDER BY TradeDate_clean
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS LastPrice
    FROM StockPrices
)
SELECT DISTINCT
    Ticker,
    ROUND((LastPrice - FirstPrice) / FirstPrice * 100, 2) AS CumulativeReturnPct
FROM FirstLast
ORDER BY CumulativeReturnPct DESC;


/* ------------------------------------------------------------
   QUERY 5 — Risk-Adjusted Return

   QUESTION: Which stock gave the best reward without making
   you nervous? (return earned per unit of risk taken)
   ------------------------------------------------------------ */
WITH DailyReturns AS (
    SELECT
        Ticker,
        (ClosePrice - LAG(ClosePrice) OVER (PARTITION BY Ticker ORDER BY TradeDate_clean))
            / LAG(ClosePrice) OVER (PARTITION BY Ticker ORDER BY TradeDate_clean) * 100 AS DailyReturnPct
    FROM StockPrices
)
SELECT
    Ticker,
    ROUND(AVG(DailyReturnPct), 4) AS AvgDailyReturn,
    ROUND(
        SQRT(AVG(DailyReturnPct*DailyReturnPct) - AVG(DailyReturnPct)*AVG(DailyReturnPct))
    , 4) AS Volatility,
    ROUND(
        AVG(DailyReturnPct) /
        NULLIF(SQRT(AVG(DailyReturnPct*DailyReturnPct) - AVG(DailyReturnPct)*AVG(DailyReturnPct)), 0)
    , 4) AS RiskAdjustedReturn
FROM DailyReturns
WHERE DailyReturnPct IS NOT NULL
GROUP BY Ticker
ORDER BY RiskAdjustedReturn DESC;


/* ------------------------------------------------------------
   QUERY 6 — Price Fact Sheet

   QUESTION: What's the price range and basic stats for each
   stock at a glance?
   ------------------------------------------------------------ */
SELECT
    Ticker,
    CASE
        WHEN Ticker IN ('CBA','ANZ','NAB','WBC') THEN 'Banking'
        WHEN Ticker IN ('WOW','COL','JBH')       THEN 'Retail'
        WHEN Ticker IN ('CSL','RMD','COH')       THEN 'Healthcare'
    END AS Sector,
    MIN(TradeDate_clean) AS StartDate,
    MAX(TradeDate_clean) AS EndDate,
    COUNT(*)              AS TradingDays,
    ROUND(MIN(ClosePrice), 2) AS MinPrice,
    ROUND(MAX(ClosePrice), 2) AS MaxPrice,
    ROUND(AVG(ClosePrice), 2) AS AvgPrice
FROM StockPrices
GROUP BY Ticker
ORDER BY Sector, Ticker;
