// ============================================================
// TABLE  : Ads_Lz
// SOURCE : Lazada Ads Overview — Excel export from Seller Center
// NOTE   : Derived ratios (ROI, CVR, CPC, CTR) are excluded —
//          calculated in Power BI via DAX for consistency
// ============================================================

let
    // ── 1. Load Excel ─────────────────────────────────────────
    Source              = Excel.Workbook(Parameter1, null, true),
    #"Raw Sheet"        = Source{[Item="Sheet0", Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(#"Raw Sheet", [PromoteAllScalars=true]),

    // ── 2. Keep raw metrics only ──────────────────────────────
    #"Selected Columns" = Table.SelectColumns(#"Promoted Headers", {
        "วันที่",
        "ค่าใช้จ่าย",
        "รายได้",
        "คำสั่งซื้อ",
        "การแสดงผล",
        "คลิก",
        "สินค้าที่ขายได้",
        "จำนวนสินค้าในตะกร้า"
    }),

    // ── 3. Rename to English standard ────────────────────────
    #"Renamed Columns" = Table.RenameColumns(#"Selected Columns", {
        {"วันที่",                "Date"},
        {"ค่าใช้จ่าย",            "Ad Spend"},
        {"รายได้",               "Sales"},
        {"คำสั่งซื้อ",             "Orders"},
        {"การแสดงผล",            "Impressions"},
        {"คลิก",                 "Clicks"},
        {"สินค้าที่ขายได้",        "Quantity"},
        {"จำนวนสินค้าในตะกร้า",   "Add to Cart"}
    }),

    // ── 4. Parse datetime & set types ────────────────────────
    #"Transformed Date" = Table.TransformColumns(#"Renamed Columns", {
        {"Date", each DateTime.From(_), type datetime}
    }),
    #"Changed Type" = Table.TransformColumnTypes(#"Transformed Date", {
        {"Ad Spend",    Currency.Type},
        {"Sales",       Currency.Type},
        {"Orders",      Int64.Type},
        {"Impressions", Int64.Type},
        {"Clicks",      Int64.Type},
        {"Quantity",    Int64.Type},
        {"Add to Cart", Int64.Type}
    }),

    // ── 5. Campaign type logic ────────────────────────────────
    #"Added Logic" = Table.AddColumn(#"Changed Type", "Campaign", each
        if [Date] = null then null else
        let
            JustDate = DateTime.Date([Date]),
            D        = Date.Day(JustDate),
            M        = Date.Month(JustDate)
        in
            if   D = M   then "Mega Day"
            else if D = 15   then "Mid-Month"
            else if D >= 25  then "Payday"
            else "Normal Day"
    , type text),

    // ── 6. Add Platform ───────────────────────────────────────
    #"Added Platform" = Table.AddColumn(#"Added Logic", "Platform", each "Lazada", type text),

    // ── 7. Final types ────────────────────────────────────────
    #"Final Table" = Table.TransformColumnTypes(#"Added Platform", {{"Date", type date}})

in
    #"Final Table"
