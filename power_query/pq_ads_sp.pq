// ============================================================
// TABLE  : Ads_Sp
// SOURCE : Shopee Ads — CSV export from Seller Center
// NOTE   : Date is embedded in row 5 (non-standard header)
//          must be extracted before promoting headers
// ============================================================

let
    // ── 1. Load raw CSV ──────────────────────────────────────
    Source = Csv.Document(
        Parameter1,
        [Delimiter=",", Columns=34, Encoding=65001, QuoteStyle=QuoteStyle.Csv]
    ),

    // ── 2. Extract date hidden in row 5 ──────────────────────
    //    Shopee embeds report date inside metadata rows,
    //    not in a standard date column.
    FinalDateValue =
        let
            RawText           = Source{5}[Column2],
            CleanTextRaw      = Text.Select(RawText, {"0".."9", "/", "-"}),
            CleanTextNormalized = Text.Replace(CleanTextRaw, "-", "/"),
            CleanText         = Text.Start(CleanTextNormalized, 10),
            Parts             = Text.Split(CleanText, "/")
        in
            #date(
                Number.From(Parts{2}),  // Year
                Number.From(Parts{1}),  // Month
                Number.From(Parts{0})   // Day
            ),

    // ── 3. Remove metadata rows, promote real headers ────────
    #"Removed Top Rows"  = Table.Skip(Source, 7),
    #"Promoted Headers"  = Table.PromoteHeaders(#"Removed Top Rows", [PromoteAllScalars=true]),

    // ── 4. Add helper columns ────────────────────────────────
    #"Added Date"     = Table.AddColumn(#"Promoted Headers",  "Date",     each FinalDateValue, type date),
    #"Added Platform" = Table.AddColumn(#"Added Date",        "Platform", each "Shopee",       type text),
    #"Added Channels" = Table.AddColumn(#"Added Platform",    "Channels", each "Ads",          type text),

    // ── 5. Keep relevant columns only ───────────────────────
    #"Selected Columns" = Table.SelectColumns(#"Added Channels", {
        "Date", "Platform", "Channels",
        "ชื่อโฆษณา", "สถานะ", "ประเภทโฆษณา",
        "รหัสสินค้า", "กลุ่มผู้ซื้อเป้าหมาย", "ปรับแต่ง",
        "การตั้งราคาประมูล", "ตำแหน่ง", "Keywords/ตำแหน่ง", "Match Type",
        "การมองเห็น", "จำนวนคลิก", "การสั่งซื้อ",
        "สินค้าที่ขายแล้ว", "ยอดขาย", "ค่าโฆษณา",
        "การมองเห็นสินค้า", "จำนวนคลิกสินค้า"
    }),

    // ── 6. Rename to English standard ────────────────────────
    #"Renamed Columns" = Table.RenameColumns(#"Selected Columns", {
        {"ชื่อโฆษณา",          "Ad Name"},
        {"สถานะ",              "Status"},
        {"ประเภทโฆษณา",        "Ad Type"},
        {"รหัสสินค้า",          "Product ID"},
        {"กลุ่มผู้ซื้อเป้าหมาย", "Target Audience"},
        {"ปรับแต่ง",            "Setting"},
        {"การตั้งราคาประมูล",   "Bid Price"},
        {"ตำแหน่ง",            "Placement"},
        {"Keywords/ตำแหน่ง",   "Keywords"},
        {"Match Type",         "Match Type"},
        {"การมองเห็น",          "Impressions"},
        {"จำนวนคลิก",          "Clicks"},
        {"การสั่งซื้อ",          "Orders"},
        {"สินค้าที่ขายแล้ว",    "Items Sold"},
        {"ยอดขาย",             "Sales"},
        {"ค่าโฆษณา",           "Ad Spend"},
        {"การมองเห็นสินค้า",    "Product Impressions"},
        {"จำนวนคลิกสินค้า",     "Product Clicks"}
    }),

    // ── 7. Replace "-" placeholders with 0 ───────────────────
    #"Replaced Nulls" = Table.ReplaceValue(
        #"Renamed Columns", "-", "0", Replacer.ReplaceText,
        {"Impressions", "Clicks", "Orders", "Items Sold",
         "Sales", "Ad Spend", "Product Impressions", "Product Clicks"}
    ),

    // ── 8. Set data types ─────────────────────────────────────
    #"Changed Type" = Table.TransformColumnTypes(#"Replaced Nulls", {
        {"Ad Name",           type text},
        {"Status",            type text},
        {"Ad Type",           type text},
        {"Product ID",        type text},
        {"Target Audience",   type text},
        {"Setting",           type text},
        {"Bid Price",         type text},
        {"Placement",         type text},
        {"Keywords",          type text},
        {"Match Type",        type text},
        {"Impressions",       Int64.Type},
        {"Clicks",            Int64.Type},
        {"Orders",            Int64.Type},
        {"Items Sold",        Int64.Type},
        {"Sales",             Currency.Type},
        {"Ad Spend",          Currency.Type},
        {"Product Impressions", Int64.Type},
        {"Product Clicks",    Int64.Type}
    }),

    // ── 9. Campaign type logic ────────────────────────────────
    //    Mega Day  : day number == month number (e.g. 11/11, 12/12)
    //    Mid-Month : day 15
    //    Payday    : day 25+
    #"Added Campaign Logic" = Table.AddColumn(#"Changed Type", "Campaign Type Logic", each
        if [Date] = null then null else
        let
            D = Date.Day([Date]),
            M = Date.Month([Date])
        in
            if   D = M   then "Mega Day"
            else if D = 15   then "Mid-Month"
            else if D >= 25  then "Payday"
            else "Normal Day"
    , type text),

    // ── 10. Final column order ────────────────────────────────
    #"Final Table" = Table.ReorderColumns(#"Added Campaign Logic", {
        "Date", "Ad Name", "Status", "Ad Type", "Product ID",
        "Target Audience", "Setting", "Bid Price", "Placement", "Keywords", "Match Type",
        "Impressions", "Clicks", "Orders", "Items Sold",
        "Sales", "Ad Spend", "Product Impressions", "Product Clicks",
        "Platform", "Campaign Type Logic", "Channels"
    })

in
    #"Final Table"
