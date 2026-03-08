# 🛒 Allnii Marketplace — E-Commerce Performance Dashboard

A end-to-end data pipeline and Power BI dashboard for monitoring 
sales performance across Shopee and Lazada platforms.

---

## 📌 Overview

Built for a health supplement brand (Allnii) to consolidate 
multi-platform e-commerce data into a single real-time dashboard, 
replacing manual Excel reporting.

**Business Impact:**
- Reduced manual reporting time by ~80%
- Enabled daily monitoring of ROAS, Revenue, and Ad Spend
- Supported budget decisions across Shopee & Lazada campaigns

---

## 🗂️ Data Sources

| File | Description |
|---|---|
| Order_Sp / Order_Lz | Order transactions from Shopee & Lazada |
| Ads_Sp / Ads_Lz | Advertising performance data |
| AMS_Sp / AMS_Lz | Affiliate & channel attribution |
| CPAS | Cross-Platform Advertising Solution data |
| Overview_Ps / Overview_Lz | Platform summary reports |

---

## ⚙️ Pipeline
```
Raw Export (Shopee/Lazada Seller Center)
        ↓
Power Query ETL
(clean, merge, normalize date/platform)
        ↓
Data Model (Star Schema in Power BI)
(DimDate, DimPlatform, DimTime, PostalCode)
        ↓
Power BI Dashboard (4 pages)
```

---

## 📊 Dashboard Pages

| Page | KPIs |
|---|---|
| Overview | Revenue, Spend, ROAS, CVR, AOV, Revenue by Product |
| Mid Month | H1 comparison, Daily Sales, Platform split |
| Health | Hourly order pattern, Weekend vs Weekday |
| Details | Geographic distribution, Order cancel analysis |

---

## 🧱 Data Model

Star schema with fact tables (Orders, Ads) connected 
to dimension tables (Date, Platform, Time, PostalCode)

![Data Model](semantic-model.png)

---

## 🛠️ Tech Stack

- **ETL:** Power Query (M Language)
- **Data Model:** Power BI (Star Schema)
- **Visualization:** Power BI Desktop
- **Source:** Shopee & Lazada Seller Center exports

---

## 📸 Dashboard Preview

![Overview](dashboard-overview.png)
