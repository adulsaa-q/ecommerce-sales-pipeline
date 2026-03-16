# 📐 DAX Measures — Allnii Marketplace

> Power BI measures used in the Allnii Marketplace dashboard.  
> Data sources: Shopee, Lazada (Order, Ads, AMS, CPAS, SponsorMax), DS_IS (ERP)

---

## 📁 Table Structure

| Table | Purpose |
|---|---|
| `!!Calculator` | Core KPI measures |
| `!MoM%` | Month-over-Month growth |
| `!Mid-Month` | First-half monthly tracking |
| `!Spend` | Ad spend aggregation |
| `!Color` | Conditional color measures |
| `!Icon` | Trend icons (▲▼) |

---

## 1. Revenue

```dax
Revenue = SUM('DS_IS'[Ex VAT])
```
> ยอดขายจริงจาก ERP (excl. VAT) — ใช้เป็น base สำหรับ KPI หลักทั้งหมด

```dax
Revenue LM = CALCULATE([Revenue], DATEADD('DimDate'[Date], -1, MONTH))
```

---

## 2. MoM Growth — Smart Comparison

เทียบ **Same Days** เมื่อดูเดือนปัจจุบัน และ **Full Month** เมื่อดูข้อมูลย้อนหลัง

```dax
% MoM Growth (Smart) =
VAR Today          = TODAY()
VAR SelectedMonth  = MONTH(MAX('DimDate'[Date]))
VAR SelectedYear   = YEAR(MAX('DimDate'[Date]))
VAR IsCurrentMonth = SelectedMonth = MONTH(Today) && SelectedYear = YEAR(Today)
VAR DaysElapsed    = DAY(Today)

VAR CurrentSales      = [Revenue]
VAR LastMonthFull     = CALCULATE([Revenue], DATEADD('DimDate'[Date], -1, MONTH))
VAR LastMonthSameDays =
    CALCULATE(
        [Revenue],
        DATESBETWEEN(
            'DimDate'[Date],
            DATE(YEAR(EOMONTH(Today,-1)), MONTH(EOMONTH(Today,-1)), 1),
            DATE(YEAR(EOMONTH(Today,-1)), MONTH(EOMONTH(Today,-1)), DaysElapsed)
        )
    )

RETURN
    IF(
        ISBLANK(CurrentSales), BLANK(),
        IF(
            IsCurrentMonth,
            DIVIDE(CurrentSales - LastMonthSameDays, LastMonthSameDays),  -- เดือนนี้ → Same Days
            DIVIDE(CurrentSales - LastMonthFull,     LastMonthFull)        -- เดือนอดีต → Full Month
        )
    )
```

> **ปัญหาที่แก้:** เดือนปัจจุบันข้อมูลไม่ครบแต่เดิมเทียบกับเดือนก่อนที่ครบเต็มเดือน ทำให้ % ต่ำเกินจริง

---

## 3. Spend MoM Growth

Logic เดียวกับ Revenue MoM แต่ใช้กับ Ad Spend  
⚠️ สีกลับกัน — spend ลด = ดี (เขียว), spend เพิ่ม = ระวัง (แดง)

```dax
%Spend MoM-GR (Smart) =
VAR Today          = TODAY()
VAR SelectedMonth  = MONTH(MAX('DimDate'[Date]))
VAR SelectedYear   = YEAR(MAX('DimDate'[Date]))
VAR IsCurrentMonth = SelectedMonth = MONTH(Today) && SelectedYear = YEAR(Today)
VAR DaysElapsed    = DAY(Today)

VAR CurrentSpend      = [Total Spend Nomal]
VAR LastMonthFull     = CALCULATE([Total Spend Nomal], DATEADD('DimDate'[Date], -1, MONTH))
VAR LastMonthSameDays =
    CALCULATE(
        [Total Spend Nomal],
        DATESBETWEEN(
            'DimDate'[Date],
            DATE(YEAR(EOMONTH(Today,-1)), MONTH(EOMONTH(Today,-1)), 1),
            DATE(YEAR(EOMONTH(Today,-1)), MONTH(EOMONTH(Today,-1)), DaysElapsed)
        )
    )

RETURN
    IF(
        OR(ISBLANK(CurrentSpend), CurrentSpend = 0), BLANK(),
        IF(
            IsCurrentMonth,
            DIVIDE(CurrentSpend - LastMonthSameDays, LastMonthSameDays),
            DIVIDE(CurrentSpend - LastMonthFull,     LastMonthFull)
        )
    )
```

---

## 4. Campaign Revenue Estimation (Proxy Method)

ไม่มี key เชื่อม Campaign Date กับ ERP โดยตรง  
ใช้ **สัดส่วน Order จาก Platform × ยอด ERP จริง** แทน

```
ยอด ERP จริงทั้งเดือน × % สัดส่วน Order ของ Campaign นั้น = ประมาณการยอด
```

```dax
Est. Campaign Revenue (ERP) =
VAR TotalOrders    = CALCULATE([revenue Total Order], ALL('DimDate'[Campaign Date]))
VAR CampaignOrders = [revenue Total Order]
VAR Pct            = DIVIDE(CampaignOrders, TotalOrders, 0)
VAR TotalERP       = CALCULATE([Revenue], ALL('DimDate'[Campaign Date]))
RETURN TotalERP * Pct
```

> ⚠️ ค่านี้เป็น **ประมาณการ (Est.)** ไม่ใช่ยอดจริง  
> Assumption: AOV ของทุก Campaign Type เท่ากัน

---

## 5. Daily Revenue Estimation

ERP มีแค่ยอดรายเดือน — ใช้สัดส่วน Order รายวันจาก Platform แทน

```dax
Est. Daily Revenue (ERP) =
VAR DailyOrders      = [revenue Total Order]
VAR TotalMonthOrders = CALCULATE([revenue Total Order], ALL('DimDate'[DayOfMonth]))
VAR Pct              = DIVIDE(DailyOrders, TotalMonthOrders, 0)
VAR TotalERP         = CALCULATE([Revenue], ALL('DimDate'[DayOfMonth]))
RETURN TotalERP * Pct
```

```dax
-- เดือนก่อน (ล้าง slicer filter ก่อนแล้วค่อยใส่ IsLastMonth)
Est. Daily Revenue LM (ERP) =
VAR DailyOrders =
    CALCULATE(
        [revenue Total Order],
        REMOVEFILTERS('DimDate'),
        'DimDate'[IsLastMonth] = TRUE(),
        VALUES('DimDate'[DayOfMonth])
    )
VAR TotalMonthOrders =
    CALCULATE(
        [revenue Total Order],
        REMOVEFILTERS('DimDate'),
        'DimDate'[IsLastMonth] = TRUE()
    )
VAR Pct = DIVIDE(DailyOrders, TotalMonthOrders, 0)
VAR TotalERP_LM =
    CALCULATE(
        [Revenue],
        REMOVEFILTERS('DimDate'),
        'DimDate'[IsLastMonth] = TRUE()
    )
RETURN TotalERP_LM * Pct
```

---

## 6. Forecast

### Weighted Moving Average 3 เดือน (แนะนำ)

เดือนล่าสุดมีน้ำหนักมากกว่า — เหมาะกับ trend ที่กำลังเปลี่ยน

| เดือน | Weight | สัดส่วน |
|---|---|---|
| ล่าสุด (M1) | 3 | 50% |
| กลาง (M2) | 2 | 33% |
| เก่าสุด (M3) | 1 | 17% |

```dax
Forecast Qty (WMA 3M) =
VAR CurrentDate = TODAY()
VAR EndDate     = EOMONTH(CurrentDate, -1)

VAR M1 = CALCULATE(SUM('DS_IS'[Sales]), DATESBETWEEN('DimDate'[Date], EOMONTH(EndDate,-1)+1, EndDate))
VAR M2 = CALCULATE(SUM('DS_IS'[Sales]), DATESBETWEEN('DimDate'[Date], EOMONTH(EndDate,-2)+1, EOMONTH(EndDate,-1)))
VAR M3 = CALCULATE(SUM('DS_IS'[Sales]), DATESBETWEEN('DimDate'[Date], EOMONTH(EndDate,-3)+1, EOMONTH(EndDate,-2)))

RETURN DIVIDE(M1*3 + M2*2 + M3*1, 6, 0) * 1.1
```

### Simple Moving Average 6 เดือน

เหมาะกับสินค้า stable ไม่ได้ trend เร็ว

```dax
Forecast Qty (Avg 6 Months) =
VAR CurrentDate = TODAY()
VAR EndDate     = EOMONTH(CurrentDate, -1)
VAR StartDate   = EOMONTH(CurrentDate, -7) + 1
VAR TotalQty    = CALCULATE(SUM('DS_IS'[Sales]), DATESBETWEEN('DimDate'[Date], StartDate, EndDate))
VAR AvgQty      = DIVIDE(TotalQty, 6, 0)
RETURN AvgQty * 1.1
```

> `* 1.1` = growth buffer 10% — ปรับได้ตาม business context  
> เมื่อมีข้อมูลปีที่แล้วครบ แนะนำเปลี่ยนเป็น YoY Adjusted แทน

---

## 7. Campaign Date Classification

จัดกลุ่มวันตาม campaign type อัตโนมัติจาก DimDate

```dax
Campaign Date =
VAR D = DAY('DimDate'[Date])
VAR M = MONTH('DimDate'[Date])
RETURN
    IF(D = M,   "Mega Day",
    IF(D = 15,  "Mid-Month",
    IF(D >= 25, "Payday",
    "Normal Day")))
```

> Mega Day = วันที่ตรงกับเดือน (1.1, 2.2 ... 12.12)  
> ไม่มีทางทับกับ Payday เพราะ month สูงสุดแค่ 12

---

## 8. Total Spend

```dax
Total Spend Nomal =
    [Total Ad Lz] + [Total Ad Sp] +
    [Total AMS Lz] + [Total AMS Sp] +
    [Total CPAS] + [Total SponsorMax]
```

| Measure | Source |
|---|---|
| `Total Ad Sp` | Shopee Ads |
| `Total Ad Lz` | Lazada Ads |
| `Total AMS Sp` | Shopee Affiliate |
| `Total AMS Lz` | Lazada Affiliate |
| `Total CPAS` | Facebook CPAS (Shopee) |
| `Total SponsorMax` | SponsorMax (Lazada) |

---

## Notes

- `Revenue` มาจาก ERP (`DS_IS`) ≠ ยอดจาก Platform Order
- `Est.` measures ทุกตัวเป็นประมาณการจาก Proxy Method

