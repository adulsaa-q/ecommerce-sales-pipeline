// ============================================================
// TABLE  : CPAS
// SOURCE : Facebook CPAS — CSV export
//          (Collaborative Performance Ads via Shopee)
// ============================================================

let
    // ── 1. Load CSV ───────────────────────────────────────────
    Source = Csv.Document(
        Parameter1,
        [Delimiter=",", Columns=19, Encoding=65001, QuoteStyle=QuoteStyle.None]
    ),
    #"Promoted Headers" = Table.PromoteHeaders(Source, [PromoteAllScalars=true]),

    // ── 2. Keep raw metrics only ──────────────────────────────
    //    Derived ratios (ROI, CVR, CPC, CTR) are excluded —
    //    calculated in Power BI via DAX for consistency
    #"Selected Columns" = Table.SelectColumns(#"Promoted Headers", {
        "วันที่",
        "ชื่อแคมเปญ",
        "ยอดการมองเห็น",
        "จำนวนคลิก",
        "คำสั่งซื้อ",
        "ยอดขาย(THB)",
        "ใช้จ่าย(THB)"
    }),

    // ── 3. Rename to English standard ────────────────────────
    #"Renamed Columns" = Table.RenameColumns(#"Selected Columns", {
        {"วันที่",          "Date"},
        {"ชื่อแคมเปญ",      "Campaign Name"},
        {"ยอดการมองเห็น",   "Impressions"},
        {"จำนวนคลิก",      "Clicks"},
        {"คำสั่งซื้อ",       "Orders"},
        {"ยอดขาย(THB)",    "Sales"},
        {"ใช้จ่าย(THB)",   "Ad Spend"}
    }),

    // ── 4. Parse date (source format: dd/MM/yyyy → en-GB) ────
    #"Transformed Date" = Table.TransformColumns(#"Renamed Columns", {
        {"Date", each try DateTime.From(_, "en-GB") otherwise null, type datetime}
    }),

    // ── 5. Set data types ─────────────────────────────────────
    #"Changed Type" = Table.TransformColumnTypes(#"Transformed Date", {
        {"Campaign Name", type text},
        {"Sales",         Currency.Type},
        {"Ad Spend",      Currency.Type},
        {"Orders",        Int64.Type},
        {"Impressions",   Int64.Type},
        {"Clicks",        Int64.Type}
    }),

    // ── 6. Campaign type logic ────────────────────────────────
    #"Added Logic" = Table.AddColumn(#"Changed Type", "Campaign Type Logic", each
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

    // ── 7. Add Platform ───────────────────────────────────────
    #"Added Platform" = Table.AddColumn(#"Added Logic", "Platform", each "CPAS", type text),

    // ── 8. Final types ────────────────────────────────────────
    #"Final Table" = Table.TransformColumnTypes(#"Added Platform", {{"Date", type date}})

in
    #"Final Table"
