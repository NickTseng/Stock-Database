USE [Stock]
GO
/****** Object:  UserDefinedFunction [dbo].[PtrValue]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[PtrValue]
(
	@ptr int, @ndate int
)
RETURNS float
AS
BEGIN
	RETURN (SELECT nClose FROM TickData WHERE Ptr=@ptr AND ndate=@ndate)

END

GO
/****** Object:  Table [dbo].[StrategyPerformanceHis]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StrategyPerformanceHis](
	[StrName] [varchar](32) NOT NULL,
	[buytime] [datetime] NULL,
	[selltime] [datetime] NULL,
	[buyprice] [float] NULL,
	[sellprice] [float] NULL,
	[TradeType] [int] NULL,
	[Entrydate] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[StrPerformanceView]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [dbo].[StrPerformanceView] AS
SELECT 
	   DATEPART(YEAR, selltime ) AS sYear, 
	   DATEPART(MONTH, selltime ) AS sMonth,
	   cast(buytime as datetime2(0)) AS Buytime, 
	   cast(selltime as datetime2(0)) AS SellTime,
	   buyprice, sellprice, TradeType, case when TradeType=0 then sellprice-buyprice else buyprice-sellprice end AS Profit   FROM [Stock].[dbo].[StrategyPerformanceHis]

GO
/****** Object:  View [dbo].[GetMonthlyPerformanceDetails]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/
CREATE VIEW [dbo].[GetMonthlyPerformanceDetails] AS
	WITH CTE AS
	(
	  SELECT StrName,coalesce (FORMAT(selltime,'yyyyMM'), 'All Time') AS [Month], 
	  CASE WHEN TradeType=1 THEN
				CAST(SUM(buyprice-sellprice) AS numeric(8,2))
		   ELSE	
				CAST(SUM(sellprice-buyprice) AS numeric(8,2)) END  AS SumProfit, 
	  count(*) AS NumTrades, 
	  CASE WHEN TradeType=1 THEN
				CAST(SUM(buyprice-sellprice)/count(*) AS numeric(8,2)) 
		   ELSE
				CAST(SUM(sellprice-buyprice)/count(*) AS numeric(8,2)) END AS AvgProfit, TradeType
		
		
		,SUM(CASE WHEN TradeType=1 and buyprice-sellprice>0 THEN 1 END) AS ShortWins
		,SUM(CASE WHEN TradeType=0 and sellprice-buyprice>0 THEN 1 END) AS LongWins
	  FROM [Stock].[dbo].[StrategyPerformanceHis]
	  GROUP BY StrName, rollup( FORMAT(selltime,'yyyyMM')), TradeType
	
	),

	WORST_SumProfit AS
	(
		SELECT S.* FROM CTE S INNER JOIN (
		SELECT MIN(SumProfit) AS MinSumProfit  FROM CTE) X ON S.SumProfit=X.MinSumProfit
	),
	WORST_AvgProfit AS
	(
		SELECT S.* FROM CTE S INNER JOIN (
		SELECT MIN(AvgProfit) AS MinAvgProfit  FROM CTE) X ON S.AvgProfit=X.MinAvgProfit
	)

	SELECT StrName, [Month],'Normal' AS Type ,SumProfit, NumTrades, 
			CAST(AvgProfit as numeric(8,2)) AS AvgProfit,TradeType,ISNULL(ShortWins,0) AS ShortWins, ISNULl(CAST(CAST(ShortWins as float)/NumTrades as numeric(5,2)),0) AS ShortWinRate, 
			ISNULL(LongWins,0) AS LongWins, ISNULL(CAST(CAST(LongWins as float)/NumTrades as numeric(5,2)),0) AS LongWinRate FROM CTE
	UNION ALL
	SELECT StrName, [Month],'Worst Sum',  SumProfit, NumTrades, CAST(AvgProfit as numeric(8,2)),TradeType,ShortWins,ShortWins/NumTrades,
			LongWins, CAST(CAST(LongWins as float)/NumTrades as numeric(5,2)) AS LongWinRate FROM WORST_SumProfit
	UNION ALL
	SELECT StrName, [Month],'Worst Avg', SumProfit, NumTrades, CAST(AvgProfit as numeric(8,2)),TradeType,ShortWins,ShortWins/NumTrades,
			LongWins, CAST(CAST(LongWins as float)/NumTrades as numeric(5,2)) AS LongWinRate FROM WORST_AvgProfit
	UNION ALL
	SELECT StrName, LEFT([Month],4) AS [YEAR],'Yearly' AS Type , SUM(SumProfit),SUM(NumTrades) , CAST(SUM(SumProfit)/SUM(NumTrades) as numeric(8,2)),TradeType,
			SUM(ShortWins),CAST(CAST(SUM(ShortWins) as float)/SUM(NumTrades) AS numeric(8,2)) AS ShortWinRate, SUM(LongWins), CAST(CAST(SUM(LongWins) as float)/SUM(NumTrades) AS numeric(8,2)) AS LongWinRate FROM CTE
	GROUP BY StrName, LEFT([Month],4), TradeType
	

  
  

  

  

GO
/****** Object:  View [dbo].[GetMonthlyPerformanceSum]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/

CREATE VIEW [dbo].[GetMonthlyPerformanceSum] AS
  SELECT  [StrName]
      ,[Month]
      ,[Type]
      ,SUM([SumProfit]) [SumProfit]
      ,SUM([NumTrades]) [NumTrades]
      ,CAST(SUM([SumProfit])/SUM([NumTrades]) as numeric(8,2)) [AvgProfit]
  FROM [Stock].[dbo].[GetMonthlyPerformanceDetails]
  WHERE Type IN ('All Time','Normal', 'Yearly')
  GROUP BY [StrName], [Month] ,[Type]
  
 

GO
/****** Object:  Table [dbo].[StockHistoryDaily]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockHistoryDaily](
	[stockNo] [varchar](10) NOT NULL,
	[sdate] [date] NOT NULL,
	[open] [float] NOT NULL,
	[highest] [float] NOT NULL,
	[lowest] [float] NOT NULL,
	[Close] [float] NOT NULL,
	[vol] [float] NOT NULL,
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK__StockHis__C90EA5065E5826s7] PRIMARY KEY CLUSTERED 
(
	[stockNo] ASC,
	[sdate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TempTicksIn5Min]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TempTicksIn5Min](
	[stime2] [datetime] NULL,
	[sopen] [decimal](8, 2) NULL,
	[shigh] [decimal](8, 2) NULL,
	[slowest] [decimal](8, 2) NULL,
	[sclose] [decimal](8, 2) NULL,
	[svol] [int] NULL
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[View_BuyTimeAnalysis]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/

CREATE VIEW [dbo].[View_BuyTimeAnalysis] AS

WITH CTE_MA (MarketDate, ClosingPrice, RowNumber,CloseMA5, CloseMA10, CloseMA30, VolMA5, VolMA10, VolMA30)
AS
(
SELECT stime2,
sclose,
ROW_NUMBER() OVER (ORDER BY stime2 ASC) RowNumber,
AVG(sclose) OVER (ORDER BY stime2 ASC ROWS 4 PRECEDING) AS CloseMA5,
AVG(sclose) OVER (ORDER BY stime2 ASC ROWS 9 PRECEDING) AS CloseMA10,
AVG(sclose) OVER (ORDER BY stime2 ASC ROWS 29 PRECEDING) AS CloseMA30,
AVG(svol) OVER (ORDER BY stime2 ASC ROWS 4 PRECEDING) AS VolMA5,
AVG(svol) OVER (ORDER BY stime2 ASC ROWS 9 PRECEDING) AS VolMA10,
AVG(svol) OVER (ORDER BY stime2 ASC ROWS 29 PRECEDING) AS VolMA30
FROM Stock..TempTicksIn5Min
)

SELECT  FORMAT(V.stime2,'yyyy-MM-dd HH:mm') stime2, 
		CAST(V.shigh as int) sHigh, 
		CAST(V.slowest as int) sLow,
		CAST(V.sopen as int) sOpen, 
		CAST(V.sclose as int) sClose,
		V.svol,
		sclose-sopen AS TickDiff,
		CAST(X.CloseMA5 as int) CloseMA5, 
		CAST(X.CloseMA10 as int) CloseMA10, 
		CAST(X.CloseMA30 as int) CloseMA30, 
		CAST(X.VolMA5 as int) VolMA5, 
		CAST(X.VolMA10 as int) VolMA10, 
		CAST(X.VolMA30 as int) VolMA30,
		FORMAT(S.selltime,'yyyy-MM-dd HH:mm') selltime, 
		S.buyprice, S.sellprice, S.TradeType, 
		CASE WHEN TradeType=1 THEN buyprice-sellprice
			 ELSE sellprice-buyprice END AS Profit, 
		DATEDIFF(DAY,stime2,selltime) AS TradeDays
		,PreClose
		,CASE WHEN PreClose IS NOT NULL AND abs(PreClose-sopen)>=120 THEN 'Gap' ELSE NULL END AS IsGap
		,PreClose-sopen AS GapSpan
FROM [Stock].[dbo].[TempTicksIn5Min] V LEFT JOIN  (SELECT [buytime] ,[selltime] ,[buyprice] ,[sellprice] ,[TradeType] FROM [Stock].[dbo].[StrategyPerformanceHis]) S ON V.stime2=S.buytime
LEFT JOIN (SELECT LAG([Close]/100,1,0) OVER (ORDER BY CAST(sdate as date) ) AS PreClose, sdate FROM Stock..StockHistoryDaily) D  ON  cast(sdate as date)=CAST(V.stime2 as date) AND FORMAT(stime2,'HH:mm')='08:45'
LEFT JOIN (SELECT 
MarketDate,
--RowNumber,
--ClosingPrice,
IIF(RowNumber > 4, CloseMA5, NULL) CloseMA5,
IIF(RowNumber > 9, CloseMA10, NULL) CloseMA10,
IIF(RowNumber > 29, CloseMA30, NULL) CloseMA30,
IIF(RowNumber > 4, VolMA5, NULL) VolMA5,
IIF(RowNumber > 9, VolMA10, NULL) VolMA10,
IIF(RowNumber > 29, VolMA30, NULL) VolMA30
--CASE WHEN RowNumber > 29 AND MA10 > MA30 THEN 'Over'
--	 WHEN RowNumber > 29 AND MA10 < MA30 THEN 'Below' ELSE NULL END as TradeSignal
FROM CTE_MA) X ON V.stime2=X.MarketDate






  

GO
/****** Object:  Table [dbo].[StockHistoryMin]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockHistoryMin](
	[stockNo] [varchar](10) NOT NULL,
	[sdate] [date] NOT NULL,
	[stime] [varchar](6) NOT NULL,
	[open] [float] NULL,
	[highest] [float] NULL,
	[lowest] [float] NULL,
	[Close] [float] NULL,
	[vol] [float] NULL,
	[TSession]  AS (case when [stime]>=' 08:45' AND [stime]<=' 13:45' then (0) when [stime]>=' 15:00' AND [stime]<=' 23:59' then (1) when [stime]>=' 00:00' AND [stime]<=' 05:00' then (1)  end),
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK__StockHis__508BD52E60FCC1DF] PRIMARY KEY CLUSTERED 
(
	[sdate] DESC,
	[stime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[GetTicksHour]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE function [dbo].[GetTicksHour](
@from date,
@to date,
@stockID varchar(8)
)
RETURNS TABLE AS RETURN

WITH CTE AS (
	SELECT (CAST([sdate] AS DATE)) [sdate], 
	CAST(CASE WHEN SUBSTRING(stime,5,2)>=46 THEN SUBSTRING(stime,2,2)+1 ELSE SUBSTRING(stime,2,2) END as varchar)+':45'stime2,
	CONVERT(DECIMAL(8,2), [open]/100) [open] , 
	CONVERT(DECIMAL(8,2), [highest]/100) [highest],
	CONVERT(DECIMAL(8,2), [lowest]/100) [lowest], 
	CONVERT(DECIMAL(8,2), [close]/100) [close], [vol] ,
	RANK() OVER (partition by CONVERT(varchar, (cast([sdate] as date))) +' ' + cast(CASE WHEN SUBSTRING(stime,5,2)>=46 THEN SUBSTRING(stime,2,2)+1 ELSE SUBSTRING(stime,2,2) END as varchar)+':45'  ORDER BY CAST([sdate] AS DATE), stime) [Rank]
	FROM  Stock..StockHistoryMin WHERE [sdate] BETWEEN @from AND @to

), CTE2 AS (
	SELECT S.stime2, 
	CASE WHEN [Rank]=1 THEN [open] ELSE 0 END [open], highest, lowest,
	CASE WHEN [Rank]=RK THEN [close] ELSE 0 END [close] , vol, T.RK 
	FROM CTE S INNER JOIN  (SELECT stime2, MAX([Rank] ) RK FROM CTE GROUP BY stime2) T ON S.stime2=T.stime2
)

SELECT  CAST(stime2 AS datetime) stime2, 
		MAX([open]) [open], 
		MAX(highest) highest, 
		MIN(lowest) lowest,
		MAX([close]) [close], 
		SUM(vol) vol FROM CTE2
WHERE CAST(stime2 as time) Between '00:45:00' AND '13:45:00'
GROUP BY stime2




GO
/****** Object:  UserDefinedFunction [dbo].[GetTicksIn5Min]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE function [dbo].[GetTicksIn5Min](
@from date,
@to date,
@stockID varchar(8)
)
RETURNS TABLE AS RETURN

WITH CTE AS (
	SELECT (CAST([sdate] AS DATE)) [sdate], 
	--(stime),LEFT(stime,4) + case when RIGHT(stime,1)<='5' then '0' else '5' END stimeround,
	CONVERT(varchar, (cast([sdate] as date))) +' ' + SUBSTRING(stime,2,4) + case when RIGHT(stime,1)<'5' then '0' else '5' END stime2,
	CONVERT(DECIMAL(8,2), [open]/100) [open] , 
	CONVERT(DECIMAL(8,2), [highest]/100) [highest],
	CONVERT(DECIMAL(8,2), [lowest]/100) [lowest], 
	CONVERT(DECIMAL(8,2), [close]/100) [close], [vol] ,
	RANK() OVER (partition by CONVERT(varchar, (cast([sdate] as date))) +' ' + SUBSTRING(stime,2,4) + CASE WHEN RIGHT(stime,1)<'5' then '0' else '5' END  ORDER BY CAST([sdate] AS DATE), stime) [Rank]
	FROM  Stock..StockHistoryMin WHERE stockNo=@stockID
	AND [sdate] BETWEEN @from AND @to

), CTE2 AS (
	SELECT S.stime2, 
	CASE WHEN [Rank]=1 THEN [open] ELSE 0 END [open], highest, lowest,
	CASE WHEN [Rank]=RK THEN [close] ELSE 0 END [close] , vol, T.RK 
	FROM CTE S INNER JOIN  (SELECT stime2, MAX([Rank] ) RK FROM CTE GROUP BY stime2) T ON S.stime2=T.stime2
)

SELECT  CAST(stime2 AS datetime) stime2, 
		MAX([open]) [open], 
		MAX(highest) highest, 
		MIN(lowest) lowest,
		MAX([close]) [close], 
		SUM(vol) vol FROM CTE2
WHERE CAST(stime2 as time) Between '08:45:00' AND '13:45:00'
GROUP BY stime2




GO
/****** Object:  Table [dbo].[TickData]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TickData](
	[stockIdx] [varchar](12) NOT NULL,
	[Ptr] [int] NOT NULL,
	[ndate] [int] NULL,
	[lTimehms] [int] NOT NULL,
	[lTimeMS] [int] NULL,
	[nBid] [float] NULL,
	[nAsk] [float] NULL,
	[nClose] [float] NULL,
	[nQty] [int] NULL,
	[Source] [varchar](8) NULL,
	[TSession]  AS (case when [lTimehms]>=(84500) AND [lTimehms]<=(134500) then (0) when [lTimehms]>=(150000) AND [lTimehms]<=(235959) then (1) when [lTimehms]>=(0) AND [lTimehms]<=(50000) then (1)  end),
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK_TickData] PRIMARY KEY CLUSTERED 
(
	[Ptr] ASC,
	[lTimehms] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [dbo].[GetTodayTick]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetTodayTick]
(@Session varchar(1)='%')
RETURNS TABLE 
AS
RETURN 
(
	
	SELECT stockIdx,sdate, ' ' + LEFT(stime,5) AS stime ,  nOpen, High, Low, nClose, nQty AS vol FROM (
	SELECT stockIdx, SUBSTRING(LTRIM(Str(S.ndate)),5,2) +'/'+RIGHT(S.ndate,2)+'/'+ LEFT(S.ndate,4) AS sdate,
					   DATEADD(MINUTE, 1 ,DATEADD(hour, (Time2 / 100) % 100,
					   DATEADD(minute, (Time2 / 1) % 100, cast('00:00:00' as time(0)))))  AS stime,
       Max(nClose)                                                                AS High,
       Min(nClose)                                                                AS Low,
       dbo.Ptrvalue(Min(Ptr),S.ndate)                                                     AS nOpen,
       dbo.Ptrvalue(Max(Ptr),S.ndate)                                                     AS nClose,
       Sum(nQty)                                                                  AS nQty
	FROM   [dbo].[TickData] X  WITH (nolock)
    INNER JOIN (SELECT ndate, lTimehms / 100 AS Time2 FROM [dbo].[TickData] 
				GROUP  BY ndate,lTimehms / 100) S
                ON S.ndate = X.ndate AND S.Time2 = X.lTimehms / 100 --WHERE lTimehms <=104959
	WHERE TSession = CASE WHEN @Session='%' THEN TSession ELSE @Session END
	GROUP BY Time2, S.ndate, stockIdx
	) E
	
	
	--CAST(stime as time(0)) >= '08:45:00' AND CAST(stime as time(0)) <= '13:45:00' 
	--AND cast(sdate as date) = cast(GETDATE() as date) 
)

GO
/****** Object:  Table [dbo].[ATM_DailyLog]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ATM_DailyLog](
	[ExecTime] [datetime] NULL,
	[Steps] [varchar](128) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ATM_Enviroment]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ATM_Enviroment](
	[Parameter] [varchar](64) NULL,
	[value] [varchar](64) NULL,
	[EntryDate] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[LineNotifyLog]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[LineNotifyLog](
	[MsgType] [varchar](32) NULL,
	[orderid] [int] NULL,
	[stockNo] [varchar](10) NULL,
	[SignalTime] [datetime] NULL,
	[BuyOrSell] [varchar](4) NULL,
	[Price] [float] NULL,
	[Size] [int] NULL,
	[NotifyTime] [datetime] NULL,
	[AlarmMessage] [varchar](256) NULL,
	[Result] [varchar](1) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Orders]    Script Date: 12/29/2019 02:22:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Orders](
	[orderid] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[stockNo] [varchar](10) NOT NULL,
	[SignalTime] [smalldatetime] NOT NULL,
	[BuyOrSell] [varchar](4) NOT NULL,
	[Size] [int] NOT NULL,
	[Price] [float] NULL,
	[DealPrice] [varchar](8) NULL,
	[DayTrade] [int] NULL,
	[TradeType] [int] NULL,
	[Result] [varchar](12) NULL,
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK__Orders__7AD2F46B2A8AE6E6] PRIMARY KEY CLUSTERED 
(
	[SignalTime] DESC,
	[BuyOrSell] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockHistoryDaily_ALL]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockHistoryDaily_ALL](
	[stockNo] [varchar](10) NOT NULL,
	[sdate] [varchar](16) NOT NULL,
	[open] [float] NOT NULL,
	[highest] [float] NOT NULL,
	[lowest] [float] NOT NULL,
	[Close] [float] NOT NULL,
	[vol] [float] NOT NULL,
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK__StockHis__C90EA5065E58456] PRIMARY KEY CLUSTERED 
(
	[stockNo] ASC,
	[sdate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockList]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockList](
	[StockNo] [varchar](12) NOT NULL,
	[StockName] [nvarchar](32) NULL,
	[PageNo] [int] NULL,
	[EntryDate] [datetime] NULL,
 CONSTRAINT [PK__StockLis__2C8517D17188EC79] PRIMARY KEY CLUSTERED 
(
	[StockNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StockQuoteDetails]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockQuoteDetails](
	[m_sStockidx] [int] NULL,
	[m_sDecimal] [float] NULL,
	[m_sTypeNo] [int] NULL,
	[m_cMarketNo] [int] NULL,
	[m_caStockNo] [int] NULL,
	[m_caName] [varchar](50) NULL,
	[m_nOpen] [float] NULL,
	[m_nHigh] [float] NULL,
	[m_nLow] [float] NULL,
	[m_nClose] [float] NULL,
	[m_nTickQty] [int] NULL,
	[m_nRef] [float] NULL,
	[m_nBid] [float] NULL,
	[m_nBc] [int] NULL,
	[m_nAsk] [float] NULL,
	[m_nAc] [int] NULL,
	[m_nTBc] [int] NULL,
	[m_nTAc] [int] NULL,
	[m_nTQty] [int] NULL,
	[m_nYQty] [int] NULL,
	[m_nUp] [float] NULL,
	[m_nDown] [float] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SystemLog]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SystemLog](
	[id] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL,
	[ExecTime] [datetime] NULL,
	[Message] [varchar](256) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[TickData_bak]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TickData_bak](
	[stockIdx] [varchar](12) NOT NULL,
	[Ptr] [int] NOT NULL,
	[ndate] [int] NULL,
	[lTimehms] [int] NULL,
	[lTimeMS] [int] NULL,
	[nBid] [float] NULL,
	[nAsk] [float] NULL,
	[nClose] [float] NULL,
	[nQty] [int] NULL,
	[Source] [varchar](8) NULL,
	[TSession]  AS (case when [lTimehms]>=(84500) AND [lTimehms]<=(134500) then (0) when [lTimehms]>=(150000) AND [lTimehms]<=(235959) then (1) when [lTimehms]>=(0) AND [lTimehms]<=(50000) then (1)  end),
	[EntryDate] [datetime] NULL
) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[BackupDbs]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[BackupDbs]
	
AS
BEGIN
	SET NOCOUNT ON;
	--net use s: \\tower\movies /user:HTG CrazyFourHorseMen

	/*You need to enable this first
	-- this turns on advanced options and is needed to configure xp_cmdshell
	sp_configure 'show advanced options', '1'
	RECONFIGURE
	-- this enables xp_cmdshell
	sp_configure 'xp_cmdshell', '1' 
	RECONFIGURE
	*/
	EXEC xp_cmdshell 'net use /delete X:'
	EXEC xp_cmdshell 'net use X: \\192.168.0.18\SQLBackup /user:HY  '

	DECLARE @filename varchar(32)
	SET @filename = 'X:\Stock' + FORMAT(GETDATE(),'yyyyMMdd_HHmmss') + '.bak'
	print @filename

	BACKUP DATABASE Stock TO DISK= @filename 
END

GO
/****** Object:  StoredProcedure [dbo].[ChkSKOorder]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ChkSKOorder] 
@intervalms int
AS

/*
  WITH CTE AS (
  SELECT ExecTime, lag(ExecTime,1) OVER (ORDER BY ExecTime) as lagtime
  FROM [Stock].[dbo].[ATM_DailyLog]
  WHERE Steps='2. Timer Ticks'

  )
  SELECT *, DATEDIFF(SECOND, lagtime, ExecTime ) FROM CTE 
  WHERE DATEDIFF(SECOND, lagtime, ExecTime )>300 --AND CONVERT(varchar(8), DATEADD(day, 0,GETDATE()),112)=CONVERT(varchar(8), ExecTime,112)
  ORDER BY ExecTime DESC
  */

  -- Round times to the nearest 5 minutes

IF DATEPART(weekday,GETDATE()) >=2 AND DATEPART(weekday,GETDATE())<=6
BEGIN
	DECLARE @selecttime datetime2
	DECLARE @nearestminutes int = 5
	select @selecttime=CAST(DATEADD( minute, ( DATEDIFF(minute, CONVERT(char(8),GETDATE(),112), GETDATE()) / @nearestminutes ) * @nearestminutes,  
			CONVERT(char(8),GETDATE(),112) ) as datetime2(0))   

	IF NOT EXISTS (SELECT 1 FROM dbo.ATM_DailyLog WHERE ExecTime BETWEEN @selecttime AND DATEADD(MILLISECOND,@intervalms,@selecttime ))
		SELECT 1
END


GO
/****** Object:  StoredProcedure [dbo].[ChkTick]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[ChkTick] AS

BEGIN

IF EXISTS (SELECT 1 FROM dbo.TickData WITH (NOLOCK) HAVING ISNULL(MAX(EntryDate),0) < DATEADD(MINUTE, -1,GETDATE()))
BEGIN
    EXEC xp_cmdshell 'powershell.exe "C:\TradeSoft\SKQuote.ps1"  '
END



END
GO
/****** Object:  StoredProcedure [dbo].[sp_BakupTick]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/

CREATE PROCEDURE [dbo].[sp_BakupTick] AS

SET XACT_ABORT ON
BEGIN TRAN
	INSERT INTO  [Stock].[dbo].[TickData_bak] ([stockIdx] ,[Ptr],[ndate],[lTimehms],[lTimeMS],[nBid],[nAsk],[nClose],[nQty],[Source],[EntryDate])
	SELECT [stockIdx] ,[Ptr],[ndate],[lTimehms],[lTimeMS],[nBid],[nAsk],[nClose],[nQty],[Source],[EntryDate] FROM [Stock].[dbo].[TickData] S
	WHERE NOT EXISTS (SELECT 1 FROM [Stock].[dbo].[TickData_bak]  T WHERE S.ndate=T.ndate AND S.Ptr=T.Ptr )
	
	COMMIT
	TRUNCATE TABLE dbo.[TickData]


GO
/****** Object:  StoredProcedure [dbo].[sp_CheckTickbakcup]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/

CREATE procedure [dbo].[sp_CheckTickbakcup] AS
WITH CTE AS(
SELECT  ndate, 
case 
when lTimehms=84500 THEN 'Morning start'  
when lTimehms=134459 then 'Morning end'
when lTimehms=150000 then 'Night start'
when lTimehms>=45900 then 'Night end'

END AS TickChk
FROM [Stock].[dbo].[TickData_bak]
group by ndate, 
case 
when lTimehms=84500 THEN 'Morning start'  
when lTimehms=134459 then 'Morning end'
when lTimehms=150000 then 'Night start'
when lTimehms>=45900 then 'Night end'
 END
 -- order by ndate DESC
 ),
 CTE2 AS (
 SELECT * FROM CTE WHERE TickChk is not null )

 SELECT ndate,  count(TickChk)FROM CTE2
 GROUP BY ndate
 --HAVING count(TickChk)<4
 order by ndate DESC


 
GO
/****** Object:  StoredProcedure [dbo].[sp_ChkLatest_KLine]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_ChkLatest_KLine] 
@Chktype int = 0,
@Session int = 0
AS 
BEGIN

SET NOCOUNT ON
DECLARE @exists int
SET @exists=1

/*
Check any data exist on -1 day, if now is weekday, -2 day if now is Sunday, -3 day if it now is Monday
Also return 0 if today's data exists
*/

---Current only check morning session on daily
IF @Chktype=0 --- Check daily k bar
BEGIN
	IF EXISTS(SELECT 1 FROM dbo.StockHistoryDaily HAVING MAX(CAST(sdate as DATE))=
			 (SELECT CAST(DATEADD(DAY, CASE DATENAME(WEEKDAY, GETDATE()) WHEN 'Sunday' THEN -2 WHEN 'Monday' THEN -3 ELSE -1 END, DATEDIFF(DAY, 0, GETDATE())) AS DATE))
			 OR MAX(CAST(sdate as DATE))=CAST(GETDATE() as DATE))
	BEGIN
		SET @exists=0	
	END
END
ELSE --- Check minute k bar
BEGIN
	--Morning session
	IF @Session=0 AND EXISTS(SELECT 1 FROM dbo.StockHistoryMin HAVING MAX(CAST(sdate as DATE))=
			 (SELECT CAST(DATEADD(DAY, CASE DATENAME(WEEKDAY, GETDATE()) WHEN 'Sunday' THEN -2 WHEN 'Monday' THEN -3 ELSE -1 END, DATEDIFF(DAY, 0, GETDATE())) AS DATE))  
			 OR MAX(CAST(sdate as DATE))=CAST(GETDATE() as DATE))
	BEGIN
		SET @exists=0	
	END

	--Night session
	--Only check time between 15:00 to 23:59 for now, not necessary to check next day
	IF (@Session=1 )
	BEGIN
		DECLARE @dtmin datetime
		SET @dtmin=	(SELECT CAST(CAST(sdate as varchar(10)) + MAX(stime) as datetime2(0) ) FROM dbo.StockHistoryMin WHERE sdate=(SELECT MAX(sdate) FROM dbo.StockHistoryMin WHERE TSession=1) AND TSession=1
					GROUP by sdate)
					print('Night min' +cast(@dtmin as varchar))
		/* If rule
		1.Current time between Tueday to Friday 15:00 to 23:59, check today day 15:00 to 23:59
		2.Current time T+1 session, check previous day 00:00 to 05:00, this only happen if it re-run on T+1 session
		3.Current time Monday, check prior 2 day (Saturday) 00:00 to 05:00
		*/
		IF (@dtmin BETWEEN CAST(CONVERT(char(9),DATEADD(DAY,0,GETDATE()),112)+ '00:00:00' as datetime2(0)) AND CAST( CONVERT(char(9),DATEADD(DAY,0,GETDATE()),112)+ '05:00:00' as datetime2(0))
		   AND CONVERT(varchar(8),getdate(),114) BETWEEN '15:00:00' AND '23:59:59')
		   
		   OR (@dtmin BETWEEN CAST(CONVERT(char(9),DATEADD(DAY,-1,GETDATE()),112)+ '00:00:00' as datetime2(0)) AND CAST( CONVERT(char(9),DATEADD(DAY,-1,GETDATE()),112)+ '05:00:00' as datetime2(0))	
		   AND CONVERT(varchar(8),getdate(),114) BETWEEN '00:00:00' AND '05:00:00')

		   OR (DATENAME(WEEKDAY, GETDATE())='Monday' AND @dtmin BETWEEN CAST(CONVERT(char(9),DATEADD(DAY,-2,GETDATE()),112)+ '00:00:00' as datetime2(0)) AND CAST( CONVERT(char(9),DATEADD(DAY,-3,GETDATE()),112)+ '05:00:00' as datetime2(0)))
			SET @exists=0	
	END
END
SELECT @exists
END
		





GO
/****** Object:  StoredProcedure [dbo].[sp_GetMDD]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/


CREATE PROCEDURE [dbo].[sp_GetMDD] 
@Function int=0 
AS

DECLARE @MDD float, @sYear int, @sMonth int, @TradeType int, @Profit int, @MAX int, @buytime datetime, @selltime datetime
DECLARE cur cursor for 
SELECT sYear, sMonth, TradeType, Profit, Buytime, SellTime
  FROM [Stock].[dbo].[StrPerformanceView]
  ORDER BY Buytime

SELECT @MDD=0, @MAX=0

OPEN cur

FETCH NEXT FROM cur INTO @sYear, @sMonth, @TradeType, @Profit, @buytime, @selltime

WHILE @@FETCH_STATUS=0
BEGIN
	IF @Profit<=1
		SET @MDD = @MDD + abs(@Profit)
		IF @Function=1
			PRINT 'Buy: ' + CAST(@buytime as varchar) + '   Sell: ' + CAST(@selltime as varchar) + '  TradeType: ' +CASt(@TradeType as varchar) + ' MDD: ' + CAST(@MDD As varchar)
		
		IF @MDD > @MAX 
		BEGIN
			SET @MAX = @MDD
		END
	ELSE
		SET @MDD=0
	
	FETCH NEXT FROM cur INTO @sYear, @sMonth, @TradeType, @Profit, @buytime, @selltime
END

CLOSE cur
DEALLOCATE cur 

PRINT 'MDD:' +  CAST(@MAX as char(4))

GO
/****** Object:  StoredProcedure [dbo].[sp_GetNotifyOrders]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
Insert oreders to the LineNotify table, once the order is notified the result column would set to 1
Limited return data to 10 rows in case over send by human error
Use signal time trace back to X days ago to find out if theres phantom orders on previous day
*/
CREATE PROCEDURE [dbo].[sp_GetNotifyOrders] AS
BEGIN
	SET NOCOUNT ON

	------------------------------------------Order Message---------------------------------------------------

	INSERT INTO [Stock].[dbo].LineNotifyLog([MsgType], [orderid] ,[stockNo] ,[SignalTime] ,[BuyOrSell] ,[Size] ,[Price])
	SELECT 'Order',[orderid] ,[stockNo] ,[SignalTime] ,[BuyOrSell] ,[Size] ,[Price]
	FROM [dbo].[Orders] X
	WHERE 
	CONVERT(varchar(8),SignalTime,112) BETWEEN CONVERT(varchar(8), DATEADD(DAY, -5, GETDATE()),112) AND CONVERT(varchar(8),GETDATE(),112)
	AND NOT EXISTS 
	(SELECT 1 FROM [dbo].LineNotifyLog S WHERE S.[stockNo]=X.[stockNo] AND S.SignalTime=X.SignalTime AND S.BuyOrSell=X.BuyOrSell)

	--------------------------------------Stock ATM Message---------------------------------------------------
	INSERT INTO [Stock].[dbo].LineNotifyLog([MsgType],[orderid], [SignalTime], [AlarmMessage])
	SELECT 'Alarm',NEXT VALUE FOR dbo.Seq_ForAlarm,ExecTime, [Message] FROM dbo.SystemLog X
	WHERE CONVERT(varchar(8),ExecTime, 112)=CONVERT(varchar(8),DATEADD(day, 0,GETDATE()), 112)
	AND NOT EXISTS (SELECT 1 FROM dbo.LineNotifyLog S WHERE S.[SignalTime]=X.ExecTime AND S.[AlarmMessage]=X.[Message])
	AND [Message] like '3%' AND CAST(ExecTime as time(0)) BETWEEN '08:45:00' AND '13:45:00'

	--------------------------------------Return reuslt--------------------------------------------------------
	SELECT TOP 5 [orderid] ,[stockNo] ,[SignalTime] ,[BuyOrSell] ,[Size] ,[Price], [AlarmMessage], [MsgType] FROM dbo.LineNotifyLog
	WHERE Result IS NULL

 END

GO
/****** Object:  StoredProcedure [dbo].[sp_GetTickData]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Script for SelectTopNRows command from SSMS  ******/



CREATE PROCEDURE [dbo].[sp_GetTickData] As

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--加一分鐘使用後歸法
SELECT DATEADD(MINUTE,1,Cast(Str(S.ndate) + ' '
            + LEFT(Replicate(0, 4-Len(Time2))+Ltrim(Str(Time2)), 2)
            + ':'
            + RIGHT(Replicate(0, 4-Len(Time2))+Ltrim(Str(Time2)), 2) AS DATETIME)) AS Time2,
       Max(nClose)                                                                AS High,
       Min(nClose)                                                                AS Low,
       dbo.Ptrvalue(Min(Ptr),S.ndate)                                                     AS nOpen,
       dbo.Ptrvalue(Max(Ptr),S.ndate)                                                     AS nClose,
       Sum(nQty)                                                                  AS nQty
FROM   [Stock].[dbo].[TickData] X
       INNER JOIN (SELECT ndate,
                          lTimehms / 100 AS Time2
                   FROM   [Stock].[dbo].[TickData]
                   GROUP  BY ndate,
                             lTimehms / 100) S
               ON S.ndate = X.ndate
                  AND S.Time2 = X.lTimehms / 100
GROUP  BY Time2,
          S.ndate
ORDER  BY Time2


--select cast('00:00' as time)
/*
SELECT ndate,lTimehms/100 , SUM(nQty)
FROM [Stock].[dbo].[TickData]
GROUP BY ndate,lTimehms/100
order by lTimehms/100
*/

GO
/****** Object:  StoredProcedure [dbo].[sp_GetTickInHour]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  UserDefinedFunction [dbo].[GetTicksIn5Min]    Script Date: 2019/6/26 下午 11:00:50 ******/

CREATE PROCEDURE [dbo].[sp_GetTickInHour] 
@from date,
@to date,
@stockID varchar(8)
AS
	SET NOCOUNT ON-----This make sp work like a query, prevent any insert rowcount returns
	
	-----------------------------------History minute data-------------------------------
	SELECT (CAST([sdate] AS DATE)) [sdate], 
	CONVERT(varchar, (cast([sdate] as date))) + ' ' + CAST(CASE WHEN SUBSTRING(stime,5,2)>=46 AND SUBSTRING(stime,2,2)<23 THEN SUBSTRING(stime,2,2)+1 
																WHEN SUBSTRING(stime,5,2)>=46 AND SUBSTRING(stime,2,2)=23 THEN '00'
																ELSE SUBSTRING(stime,2,2) END as varchar)+':45'stime2,
	CONVERT(DECIMAL(8,2), [open]/100) [open] , 
	CONVERT(DECIMAL(8,2), [highest]/100) [highest],
	CONVERT(DECIMAL(8,2), [lowest]/100) [lowest], 
	CONVERT(DECIMAL(8,2), [close]/100) [close], [vol] ,
	RANK() OVER (partition by CONVERT(varchar, (cast([sdate] as date))) +' ' + cast(CASE WHEN SUBSTRING(stime,5,2)>=46 
	THEN SUBSTRING(stime,2,2)+1 ELSE SUBSTRING(stime,2,2) END as varchar)+':45'  ORDER BY CAST([sdate] AS DATE), stime) [Rank] INTO #TEMP1
	FROM  Stock..StockHistoryMin WHERE CAST(sdate as date) BETWEEN @from AND @to

	-----------------------------------Tick data--------------------------------------
	
	IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.StockHistoryMin WHERE cast(sdate as date) = (SELECT  MAX(cast(cast(ndate as varchar) as date))  FROM dbo.[TickData]))
	BEGIN
		INSERT INTO #TEMP1
		SELECT (CAST([sdate] AS DATE)) [sdate], 
		CONVERT(varchar, (cast([sdate] as date))) + ' ' + CAST(CASE WHEN SUBSTRING(stime,5,2)>=46 AND SUBSTRING(stime,2,2)<23 THEN SUBSTRING(stime,2,2)+1 
																	WHEN SUBSTRING(stime,5,2)>=46 AND SUBSTRING(stime,2,2)=23 THEN '00'
																	ELSE SUBSTRING(stime,2,2) END as varchar)+':45'stime2,
		CONVERT(DECIMAL(8,2), [nopen]/100) [open] , 
		CONVERT(DECIMAL(8,2), High/100) [High],
		CONVERT(DECIMAL(8,2), Low/100) [lowest], 
		CONVERT(DECIMAL(8,2), nClose/100) [close], [vol] ,
		RANK() OVER (partition by CONVERT(varchar, (cast([sdate] as date))) +' ' + cast(CASE WHEN SUBSTRING(stime,5,2)>=46 
		THEN SUBSTRING(stime,2,2)+1 ELSE SUBSTRING(stime,2,2) END as varchar)+':45'  ORDER BY CAST([sdate] AS DATE), stime) [Rank] 
		FROM  Stock..GetTodayTick()
	END
	------------use max to find open and close for the period
	SELECT stime2, MAX([Rank] ) RK INTO #TEMP2 FROM #TEMP1 GROUP BY stime2

	------------prepare index for later join
	create index idx on #TEMP1 (stime2) 
	create index idx on #TEMP2 (stime2) 

SELECT  CAST(stime2 AS datetime) stime2, 
		MAX([open]) [open], 
		MAX(highest) highest, 
		MIN(lowest) lowest,
		MAX([close]) [close], 
		SUM(vol) vol FROM (
	SELECT S.stime2, 
	CASE WHEN [Rank]=1 THEN [open] ELSE 0 END [open], highest, lowest,
	CASE WHEN [Rank]=RK THEN [close] ELSE 0 END [close] , vol, T.RK 
	FROM #TEMP1 S INNER JOIN #TEMP2 T ON S.stime2=T.stime2) E
--WHERE CAST(stime2 as time) Between '00:45:00' AND '13:45:00'
GROUP BY stime2
ORDER BY stime2




GO
/****** Object:  StoredProcedure [dbo].[sp_GetTicksDaily]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE procedure [dbo].[sp_GetTicksDaily]
@from date,
@to date,
@stockID varchar(8),
@session int
AS
BEGIN

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @dtdaily date, @ticktime date
SELECT @dtdaily = MAX(CAST([sdate] as date)) FROM Stock.dbo.StockHistoryDaily
SELECT @ticktime = MAX(CONVERT(datetime,convert(char(8),ndate))) FROM Stock.dbo.TickData WHERE lTimehms BETWEEN 84500 AND 134500
--FORMAT(@ticktime,'yyyyMMdd')
--CONVERT(varchar(8),@ticktime,112)
IF @ticktime>@dtdaily
BEGIN
	DECLARE @tickopen float, @tickclose float, @tickhigh float, @ticklow float, @tickvol int
	SELECT @tickopen = nClose FROM Stock.dbo.TickData WHERE Ptr=(SELECT MIN(Ptr) FROM Stock.dbo.TickData WHERE ndate=CONVERT(varchar(8),@ticktime,112) AND lTimehms BETWEEN 84500 AND 134500)
	SELECT @tickclose = nClose FROM Stock.dbo.TickData WHERE Ptr=(SELECT MAX(Ptr) FROM Stock.dbo.TickData WHERE ndate=CONVERT(varchar(8),@ticktime,112) AND lTimehms BETWEEN 84500 AND 134500)
	SELECT @tickhigh = MAX(nClose) FROM Stock.dbo.TickData WHERE ndate=CONVERT(varchar(8),@ticktime,112) AND lTimehms BETWEEN 84500 AND 134500
	SELECT @ticklow = MIN(nClose) FROM Stock.dbo.TickData WHERE ndate=CONVERT(varchar(8),@ticktime,112) AND lTimehms BETWEEN 84500 AND 134500
	SELECT @tickvol = SUM(nQty) FROM Stock.dbo.TickData WHERE ndate=CONVERT(varchar(8),@ticktime,112) AND lTimehms BETWEEN 84500 AND 134500

	SELECT @ticktime AS [sdate] , CONVERT(DECIMAL(8,2), @tickopen/100), CONVERT(DECIMAL(8,2), @tickhigh/100), CONVERT(DECIMAL(8,2), @ticklow/100), CONVERT(DECIMAL(8,2), @tickclose/100), @tickvol
	UNION

	SELECT CAST([sdate] as date) AS [sdate],CONVERT(DECIMAL(8,2), [open]/100) , CONVERT(DECIMAL(8,2), [highest]/100)  ,CONVERT(DECIMAL(8,2), [lowest]/100),  
				CONVERT(DECIMAL(8,2), [close]/100), [vol] FROM Stock.dbo.StockHistoryDaily WHERE stockNo=@stockID AND CAST([sdate] as date) 
				 BETWEEN @from AND @to 
	ORDER BY [sdate] ASC
END

ELSE
BEGIN
	SELECT CAST([sdate] as date) AS [sdate],CONVERT(DECIMAL(8,2), [open]/100) , CONVERT(DECIMAL(8,2), [highest]/100)  ,CONVERT(DECIMAL(8,2), [lowest]/100),  
				CONVERT(DECIMAL(8,2), [close]/100), [vol] FROM Stock.dbo.StockHistoryDaily WHERE stockNo=@stockID AND CAST([sdate] as date) 
				 BETWEEN @from AND @to 
	ORDER BY [sdate] ASC
END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_GetTicksIn5Min]    Script Date: 12/29/2019 02:22:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetTicksIn5Min] 
@from date,
@to date,
@stockID varchar(8),
@session varchar(1) = '%'

AS
	/*
	K bar pattern
	Bar count from  1,2,3,4,5 
	Next bar 6,7,8,9,0
	9:01, 9:02, 9:03, 9:04, 9:05 -----> 9:00
	9:06, 9:07, 9:08, 9:09, 9:10 -----> 9:05
	*/
	SET NOCOUNT ON-----This make sp work like a query, prevent any insert rowcount returns
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	DECLARE @fromtime varchar(1), @endtime varchar(6)
	DECLARE @dtmin datetime, @ticktime datetime
	SET @dtmin = (SELECT CAST(CAST(sdate as varchar(10)) + MAX(stime) as datetime2(0) ) FROM dbo.StockHistoryMin WHERE sdate=(SELECT MAX(sdate) FROM Stock.dbo.StockHistoryMin)
					GROUP by sdate)

	SET @ticktime = (SELECT CAST(MIN(CONVERT(datetime2(0),convert(char(8),ndate))) as char(11)) + CAST(DATEADD(MINUTE, 0 ,DATEADD(hour, (lTimehms / 100 / 100) % 100,
					   DATEADD(minute, (lTimehms / 100 / 1) % 100, CAST('00:00:00' as time(0))))) as varchar(8)) FROM (
							SELECT ndate, MIN(ltimehms) AS ltimehms  FROM TickData WHERE ndate = (SELECT MIN(ndate) FROM TickData)
						GROUP BY ndate) E GROUP by lTimehms)
	
/*  Date case when----> When it's 00:00 unwind back to 23:55, because 00:00 belong to 23:55
			  else----> Just minus 5 minutes
	Time case when ---->when it's 0 minus 5 minutes
				   ---->it's 1 to 5 floor down to 0 minutes
				   ---->it's 6 to 9 floor down to 5 minutes 
	*/
	SELECT (CAST([sdate] AS DATE)) [sdate] ,
	CASE WHEN 	
	CAST (stime as time(0)) = '00:00:00' THEN CAST(DATEADD(day,-1,CAST([sdate] AS DATE)) AS VARCHAR) ELSE 
	CAST(CAST([sdate] AS DATE) AS VARCHAR)  END + ' ' + LEFT(
	   CASE WHEN RIGHT(stime,1)='0' THEN DATEADD(MINUTE,-5,CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='1' AND RIGHT(stime,1)<='5'THEN DATEADD(MINUTE,-CAST(RIGHT(stime,1) as int),CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='6' AND RIGHT(stime,1)<='9'THEN DATEADD(MINUTE,-(CAST(RIGHT(stime,1) as int)-5),CAST(stime as time(0)))
			END,5) AS stime2 ,
	CONVERT(DECIMAL(8,2), [open]/100) [open] , 
	CONVERT(DECIMAL(8,2), [highest]/100) [highest],
	CONVERT(DECIMAL(8,2), [lowest]/100) [lowest], 
	CONVERT(DECIMAL(8,2), [close]/100) [close], [vol] ,
	RANK() OVER (partition by 
	CASE WHEN 	
	CAST (stime as time(0)) = '00:00:00' THEN CAST(DATEADD(day,-1,CAST([sdate] AS DATE)) AS VARCHAR) ELSE 
	CAST(CAST([sdate] AS DATE) AS VARCHAR)  END + ' ' + LEFT(
	   CASE WHEN RIGHT(stime,1)='0' THEN DATEADD(MINUTE,-5,CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='1' AND RIGHT(stime,1)<='5'THEN DATEADD(MINUTE,-CAST(RIGHT(stime,1) as int),CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='6' AND RIGHT(stime,1)<='9'THEN DATEADD(MINUTE,-(CAST(RIGHT(stime,1) as int)-5),CAST(stime as time(0)))
			END,5)
	ORDER BY CAST([sdate] AS DATE), stime ) [Rank]
    INTO #TEMP1
	FROM dbo.StockHistoryMin WHERE stockNo=@stockID
	AND [sdate] BETWEEN @from AND @to AND TSession = CASE WHEN  @session='%' THEN TSession ELSE @session END

	/*
	 The parameter does not take time as filter range, it only filter date
	 When trade seesion is 1, it would mistakenly unwind to the prior day than fromdate

	 This is also the reason that we have first min tick at 8:46, not 8:45. 8:46 ~ 9:00 all count as 8:45 in 5 Min K bar
	 Thus, 00:00 should count as 23:55 5 Min K bar
	*/
	DELETE FROM #TEMP1
	WHERE stime2=CAST(DATEADD(day,-1,CAST(@from AS DATE)) AS VARCHAR) + ' ' + '23:55'

	--select stime2, count(1) from #TEMP1  GROUP BY stime2 order by count(1)

	--If tick data is greater than StockHistoryMin, then it's today
	print('Ticks table min time ' + cast(@ticktime as varchar))
	print('Minutes table max time ' + cast(@dtmin as varchar))
	IF @ticktime>@dtmin
	BEGIN
		print('Get Ticks')
		INSERT INTO #TEMP1
		SELECT (CAST([sdate] AS DATE)) [sdate], 
		CAST(CAST([sdate] AS DATE) AS VARCHAR) + ' ' +
			LEFT(CASE WHEN RIGHT(stime,1)='0' THEN DATEADD(MINUTE,-5,CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='1' AND RIGHT(stime,1)<='5'THEN DATEADD(MINUTE,-CAST(RIGHT(stime,1) as int),CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='6' AND RIGHT(stime,1)<='9'THEN DATEADD(MINUTE,-(CAST(RIGHT(stime,1) as int)-5),CAST(stime as time(0)))
			END,5) AS stime2,
		CONVERT(DECIMAL(8,2), [nopen]/100) [open] , 
		CONVERT(DECIMAL(8,2), High/100) [High],
		CONVERT(DECIMAL(8,2), Low/100) [lowest], 
		CONVERT(DECIMAL(8,2), nClose/100) [close], [vol] ,
		RANK() OVER (partition by 
		CAST(CAST([sdate] AS DATE) AS VARCHAR) + ' ' +
			LEFT(CASE WHEN RIGHT(stime,1)='0' THEN DATEADD(MINUTE,-5,CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='1' AND RIGHT(stime,1)<='5'THEN DATEADD(MINUTE,-CAST(RIGHT(stime,1) as int),CAST(stime as time(0)))
			WHEN RIGHT(stime,1)>='6' AND RIGHT(stime,1)<='9'THEN DATEADD(MINUTE,-(CAST(RIGHT(stime,1) as int)-5),CAST(stime as time(0)))
			END,5) 
		ORDER BY CAST([sdate] AS DATE), stime) [Rank]
		FROM  dbo.GetTodayTick(@session)
		WHERE CAST([sdate] AS DATE) BETWEEN @from AND @to 
	END
	
	SELECT stime2, MAX([Rank] ) RK INTO #TEMP2 FROM #TEMP1 GROUP BY stime2
	
	------------prepare index for later join
	--create index idx on #TEMP1 (stime2) 
	--create index idx on #TEMP2 (stime2) 

	--This part remove the latest bar if the bar isn't compeleted yet
	--If we only want up to 08:45 bar, but we have a new bar 09:00 at current time 09:00:01
	--Then remove this uncompeleted bar, this only gurantee this bar is at least 4 minutes
	------------------------------------------------------------------------------------
	DECLARE @fullrnk smallint, @MaxTime datetime
	SELECT @fullrnk=MAX([Rank]), @MaxTime=stime2 FROM #TEMP1 WHERE stime2=(SELECT MAX(stime2) FROM #TEMP1) GROUP BY stime2

	IF @fullrnk<>5 --If the bar doesn't consist 5 minutes
	BEGIN
			DELETE FROM #TEMP1 WHERE stime2=@MaxTime
	END
	--------------------------------------------------------------------------------------

	SELECT  CAST(stime2 AS datetime) stime2, 
			MAX([open]) [open], 
			MAX(highest) highest, 
			MIN(lowest) lowest,
			MAX([close]) [close], 
			SUM(vol) vol FROM (
		SELECT S.stime2, 
		CASE WHEN [Rank]=1 THEN [open] ELSE 0 END [open], highest, lowest,
		CASE WHEN [Rank]=RK THEN [close] ELSE 0 END [close] , vol, T.RK 
		FROM #TEMP1 S INNER JOIN #TEMP2 T ON S.stime2=T.stime2) E
	--WHERE CAST(stime2 as time) Between '00:45:00' AND '13:45:00'
	GROUP BY stime2 
	ORDER BY CAST(stime2 AS datetime) ASC




GO
