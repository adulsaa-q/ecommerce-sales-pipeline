// ============================================================
// TABLE  : Order_Lz
// SOURCE : Lazada Orders — Excel export from Seller Center
// NOTE   : Payment method uses Lazada codes (e.g. MIXEDCARD,
//          PROMPTPAY) — mapped to match Shopee payment groups
// ============================================================

let
    // ── 1. Load Excel ─────────────────────────────────────────
    Source              = Excel.Workbook(Parameter4, null, true),
    #"Raw Sheet"        = Source{[Item="sheet1", Kind="Sheet"]}[Data],
    #"Promoted Headers" = Table.PromoteHeaders(#"Raw Sheet", [PromoteAllScalars=true]),

    // ── 2. Keep relevant columns only ────────────────────────
    #"Selected Columns" = Table.SelectColumns(#"Promoted Headers", {
        "orderNumber",
        "status",
        "createTime",
        "sellerSku",
        "itemName",
        "variation",
        "paidPrice",
        "shippingFee",
        "sellerDiscountTotal",
        "shippingPostCode",
        "payMethod"
    }),

    // ── 3. Rename to English standard ────────────────────────
    #"Renamed Columns" = Table.RenameColumns(#"Selected Columns", {
        {"orderNumber",          "Order ID"},
        {"status",               "Order Status"},
        {"createTime",           "Order Date"},
        {"sellerSku",            "Product ID"},
        {"itemName",             "Product Name"},
        {"variation",            "Variation"},
        {"paidPrice",            "Sales"},
        {"shippingFee",          "Shipping Paid by Buyer"},
        {"sellerDiscountTotal",  "Seller Voucher Cost"},
        {"payMethod",            "Payment Method"},
        {"shippingPostCode",     "Postcode"}
    }),

    // ── 4. Standardize Payment Method ────────────────────────
    //    Lazada uses internal codes — mapped to match Shopee groups
    //    so both platforms can be compared in the same slicer
    #"Standardized Payment" = Table.TransformColumns(#"Renamed Columns", {{
        "Payment Method", each
            if   _ = "COD"                                                      then "COD"
            else if _ = "MIXEDCARD"
              or Text.Contains(_, "CREDIT")
              or Text.Contains(_, "DEBIT")                                      then "Credit Card"
            else if _ = "PROMPTPAY"
              or Text.Contains(_, "BANK")
              or Text.Contains(_, "DEEPLINK")                                   then "Bank Transfer"
            else if _ = "PAYMENT_ACCOUNT"
              or Text.Contains(_, "WALLET")                                     then "E-Wallet"
            else if _ = "PAY_LATER"                                             then "PayLater"
            else "Other"
        , type text
    }}),

    // ── 5. Clean Postcode & Variation ────────────────────────
    #"Cleaned Data" = Table.TransformColumns(#"Standardized Payment", {
        {"Postcode",  each Text.From(_), type text},
        {"Variation", each if _ = "" or _ = null then null else Text.Replace(_, "Variation:", ""), type text}
    }),

    // ── 6. Fill empty Variation with "Standard" ───────────────
    #"Filled Variation" = Table.ReplaceValue(#"Cleaned Data", null, "Standard", Replacer.ReplaceValue, {"Variation"}),

    // ── 7. Normalize Lazada order status → English ────────────
    //    Lazada uses English but different terms from Shopee.
    //    Standardized so both platforms share the same status values.
    #"Translated Status" = Table.TransformColumns(#"Filled Variation", {{
        "Order Status", each
            if   Text.Contains(_, "delivered",  Comparer.OrdinalIgnoreCase)  then "Completed"
            else if Text.Contains(_, "confirmed", Comparer.OrdinalIgnoreCase) then "Completed"
            else if Text.Contains(_, "shipped",   Comparer.OrdinalIgnoreCase) then "Shipping"
            else if Text.Contains(_, "canceled",  Comparer.OrdinalIgnoreCase) then "Cancelled"
            else _
        , type text
    }}),

    // ── 8. Parse datetime & set types ────────────────────────
    #"Transformed Date" = Table.TransformColumns(#"Translated Status", {
        {"Order Date", each DateTime.From(_), type datetime}
    }),
    #"Changed Type" = Table.TransformColumnTypes(#"Transformed Date", {
        {"Sales",                  Currency.Type},
        {"Shipping Paid by Buyer", Currency.Type},
        {"Seller Voucher Cost",    Currency.Type},
        {"Postcode",               type text}
    }),

    // ── 9. Add Platform ───────────────────────────────────────
    #"Added Platform" = Table.AddColumn(#"Changed Type", "Platform", each "Lazada", type text),

    // ── 10. Split Order Date → Date + Time ───────────────────
    #"Duplicated Column" = Table.DuplicateColumn(#"Added Platform", "Order Date", "Order Time"),
    #"Extracted Date"    = Table.TransformColumns(#"Duplicated Column", {{"Order Date", DateTime.Date, type date}}),
    #"Extracted Time"    = Table.TransformColumns(#"Extracted Date",    {{"Order Time", DateTime.Time, type time}}),

    // ── 11. Final types ───────────────────────────────────────
    #"Final Table" = Table.TransformColumnTypes(#"Extracted Time", {
        {"Order ID",               Int64.Type},
        {"Order Status",           type text},
        {"Order Date",             type date},
        {"Order Time",             type time},
        {"Product ID",             type text},
        {"Product Name",           type text},
        {"Variation",              type text},
        {"Sales",                  type number},
        {"Shipping Paid by Buyer", type number},
        {"Seller Voucher Cost",    type number},
        {"Postcode",               type text},
        {"Payment Method",         type text},
        {"Platform",               type text}
    })

in
    #"Final Table"
