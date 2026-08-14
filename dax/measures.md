# <img src="https://api.iconify.design/lucide:calculator.svg?color=%23F3F4F6" width="22" valign="middle" /> &nbsp;DAX Measures — Multi-Channel E-Commerce Analytics

Power BI calculation logic and analytical measures for unified Shopee & Lazada performance reporting.

---

## <img src="https://api.iconify.design/lucide:folder.svg?color=%23F3F4F6" width="20" valign="middle" /> &nbsp;Measure Groups

| Group | Purpose |
|---|---|
| `!!Calculator` | Core volume, gross revenue, net payout, and blended ROAS |
| `!MoM%` | Month-over-Month growth calculations (Smart MTD comparison) |
| `!Campaign` | Performance breakdown by Campaign Type (Mega Day, Payday, Normal) |
| `!Spend` | Advertising & performance spend aggregation across platforms |
| `!Color` | Conditional formatting logic for UI scorecards |

---

## 1. Core Revenue & Payouts

```dax
Gross Revenue = 
SUM('Order_Sp'[Sales]) + SUM('Order_Lz'[Sales])
```

```dax
Net Payout = 
SUM('Order_Sp'[Net Payout]) + SUM('Order_Lz'[Net Payout])
```

```dax
Total Orders = 
DISTINCTCOUNT('Order_Sp'[Order ID]) + DISTINCTCOUNT('Order_Lz'[Order ID])
```

```dax
AOV = 
DIVIDE([Gross Revenue], [Total Orders], 0)
```

---

## 2. Smart MoM Growth (MTD Same-Day vs Full-Month Logic)

**Problem:** In the current ongoing month, comparing Month-to-Date (e.g. 14 days) against a completed previous month (30/31 days) causes artificial negative growth alerts on dashboards.

**Solution:** Dynamically branch logic based on whether the selected period is the current month:
- **Current Month:** Compare MTD elapsed days against the **exact same day range** of the previous month.
- **Historical Months:** Compare full month vs previous full month.

```dax
% MoM Growth (Smart) =
VAR Today          = TODAY()
VAR SelectedMonth  = MONTH(MAX('DimDate'[Date]))
VAR SelectedYear   = YEAR(MAX('DimDate'[Date]))
VAR IsCurrentMonth = (SelectedMonth = MONTH(Today) && SelectedYear = YEAR(Today))
VAR DaysElapsed    = DAY(Today)

VAR CurrentSales      = [Gross Revenue]
VAR LastMonthFull     = CALCULATE([Gross Revenue], DATEADD('DimDate'[Date], -1, MONTH))
VAR LastMonthSameDays =
    CALCULATE(
        [Gross Revenue],
        DATESBETWEEN(
            'DimDate'[Date],
            DATE(YEAR(EOMONTH(Today, -1)), MONTH(EOMONTH(Today, -1)), 1),
            DATE(YEAR(EOMONTH(Today, -1)), MONTH(EOMONTH(Today, -1)), DaysElapsed)
        )
    )

RETURN
    IF(
        ISBLANK(CurrentSales), BLANK(),
        IF(
            IsCurrentMonth,
            DIVIDE(CurrentSales - LastMonthSameDays, LastMonthSameDays),
            DIVIDE(CurrentSales - LastMonthFull,     LastMonthFull)
        )
    )
```

---

## 3. Advertising Spend & Blended ROAS

### Total Marketing Spend
Combines platform in-app ads (Shopee Ads, Lazada Sponsored Solutions) and affiliate marketing (AMS, CPAS):

```dax
Total Ad Spend = 
SUM('Ads_Sp'[Ad Spend]) + SUM('AMS_Sp'[Spend]) + SUM('AMS_Lz'[Spend]) + SUM('CPAS_Ps'[Spend])
```

### Blended ROAS
Measures overall marketing efficiency across all paid channels against total gross revenue:

```dax
Blended ROAS = 
DIVIDE([Gross Revenue], [Total Ad Spend], 0)
```

---

## 4. Platform-Aware AOV Breakdown

Allows dynamic evaluation when filtering by platform slicer:

```dax
AOV by Platform =
VAR SelectedPlatform = SELECTEDVALUE('DimPlatform'[PlatformName])
VAR Sales_LZ  = CALCULATE(SUM('Order_Lz'[Sales]),          'Order_Lz'[Order Status] = "delivered")
VAR Orders_LZ = CALCULATE(DISTINCTCOUNT('Order_Lz'[Order ID]), 'Order_Lz'[Order Status] = "delivered")
VAR Sales_SP  = SUM('Order_Sp'[Sales])
VAR Orders_SP = DISTINCTCOUNT('Order_Sp'[Order ID])
RETURN
SWITCH(SelectedPlatform,
    "Shopee", DIVIDE(Sales_SP, Orders_SP, 0),
    "Lazada", DIVIDE(Sales_LZ, Orders_LZ, 0),
              DIVIDE(Sales_SP + Sales_LZ, Orders_SP + Orders_LZ, 0)
)
```
