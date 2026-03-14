// ============================================================
// TABLE  : Order_Sp
// SOURCE : Shopee Orders — Excel export from Seller Center
// NOTE   : Status column is in Thai — normalized to English
//          to align with Lazada for cross-platform analysis
// ============================================================

let
    // ── 1. Load Excel ─────────────────────────────────────────
    Source             = Excel.Workbook(Parameter9, null, true),
    #"Raw Sheet"       = Source{0}[Data],
    #"Promoted Headers"= Table.PromoteHeaders(#"Raw Sheet", [PromoteAllScalars=true]),

    // ── 2. Keep relevant columns only ────────────────────────
    #"Selected Columns" = Table.SelectColumns(#"Promoted Headers", {
        "หมายเลขคำสั่งซื้อ",
        "สถานะการสั่งซื้อ",
        "วันที่ทำการสั่งซื้อ",
        "เลขอ้างอิง SKU (SKU Reference No.)",
        "ชื่อสินค้า",
        "ชื่อตัวเลือก",
        "จำนวน",
        "ราคาขายสุทธิ",
        "จำนวนเงินทั้งหมด",
        "ค่าคอมมิชชั่น",
        "Transaction Fee",
        "ค่าบริการ",
        "ค่าจัดส่งที่ชำระโดยผู้ซื้อ",
        "โค้ดส่วนลดชำระโดยผู้ขาย",
        "จังหวัด",
        "รหัสไปรษณีย์",
        "ช่องทางการชำระเงิน",
        "แผนการผ่อนชำระ",
        "ค่าธรรมเนียม (%)"
    }),

    // ── 3. Rename to English standard ────────────────────────
    #"Renamed Columns" = Table.RenameColumns(#"Selected Columns", {
        {"หมายเลขคำสั่งซื้อ",                    "Order ID"},
        {"สถานะการสั่งซื้อ",                      "Order Status"},
        {"วันที่ทำการสั่งซื้อ",                    "Order Date"},
        {"เลขอ้างอิง SKU (SKU Reference No.)",    "Product ID"},
        {"ชื่อสินค้า",                             "Product Name"},
        {"ชื่อตัวเลือก",                           "Variation"},
        {"จำนวน",                                 "Quantity"},
        {"ราคาขายสุทธิ",                           "Sales"},
        {"จำนวนเงินทั้งหมด",                       "Net Payout"},
        {"ค่าคอมมิชชั่น",                          "Commission Fee"},
        {"Transaction Fee",                       "Transaction Fee"},
        {"ค่าบริการ",                              "Service Fee"},
        {"ค่าจัดส่งที่ชำระโดยผู้ซื้อ",              "Shipping Paid by Buyer"},
        {"โค้ดส่วนลดชำระโดยผู้ขาย",               "Seller Voucher Cost"},
        {"จังหวัด",                                "Province"},
        {"รหัสไปรษณีย์",                           "Postcode"},
        {"ช่องทางการชำระเงิน",                     "Payment Method"},
        {"แผนการผ่อนชำระ",                        "Installment Plan"},
        {"ค่าธรรมเนียม (%)",                       "Fee Percentage"}
    }),

    // ── 4. Fill empty Variation with "Standard" ───────────────
    #"Filled Variation" = Table.TransformColumns(#"Renamed Columns", {
        {"Variation", each if _ = "" or _ = null then "Standard" else _, type text}
    }),

    // ── 5. Clean Fee % → decimal number ──────────────────────
    #"Cleaned Fee %" = Table.TransformColumns(#"Filled Variation", {
        {"Fee Percentage", each
            if _ = null or _ = "" then 0
            else Number.From(Text.Replace(Text.From(_), "%", "")) / 100
        , type number}
    }),

    // ── 6. Group Payment Method ───────────────────────────────
    #"Grouped Payment" = Table.AddColumn(#"Cleaned Fee %", "Payment Group", each
        if   Text.Contains([Payment Method], "ปลายทาง") or Text.Contains([Payment Method], "COD")    then "COD"
        else if Text.Contains([Payment Method], "บัตรเครดิต")                                         then "Credit Card"
        else if Text.Contains([Payment Method], "Wallet") or Text.Contains([Payment Method], "AirPay") then "E-Wallet"
        else if Text.Contains([Payment Method], "โอน") or Text.Contains([Payment Method], "Bank")      then "Bank Transfer"
        else if Text.Contains([Payment Method], "SPayLater")                                           then "SPayLater"
        else "Other"
    , type text),

    // ── 7. Normalize Thai order status → English ──────────────
    //    Shopee returns status in Thai text.
    //    Standardized to match Lazada for cross-platform joins.
    #"Translated Status" = Table.TransformColumns(#"Grouped Payment", {{
        "Order Status", each
            if   Text.Contains(_, "ยังไม่ชำระ")      then "Pending Payment"
            else if Text.Contains(_, "ที่ต้องจัดส่ง") then "Pending Shipment"
            else if Text.Contains(_, "การจัดส่ง")    then "Shipping"
            else if Text.Contains(_, "ผู้ซื้อได้รับสินค้า")
              or Text.Contains(_, "สำเร็จ")
              or Text.Contains(_, "Completed")       then "Completed"
            else if Text.Contains(_, "ยกเลิก")
              or Text.Contains(_, "Cancelled")       then "Cancelled"
            else _
        , type text
    }}),

    // ── 8. Parse datetime & set types ────────────────────────
    #"Transformed Date" = Table.TransformColumns(#"Translated Status", {
        {"Order Date", each DateTime.From(_), type datetime}
    }),
    #"Changed Type" = Table.TransformColumnTypes(#"Transformed Date", {
        {"Sales",                 Currency.Type},
        {"Net Payout",            Currency.Type},
        {"Commission Fee",        Currency.Type},
        {"Transaction Fee",       Currency.Type},
        {"Service Fee",           Currency.Type},
        {"Shipping Paid by Buyer",Currency.Type},
        {"Seller Voucher Cost",   Currency.Type},
        {"Quantity",              Int64.Type},
        {"Province",              type text},
        {"Postcode",              type text},
        {"Payment Method",        type text},
        {"Payment Group",         type text},
        {"Installment Plan",      type text},
        {"Fee Percentage",        type number}
    }),

    // ── 9. Campaign type logic ────────────────────────────────
    #"Added Logic" = Table.AddColumn(#"Changed Type", "Campaign Type Logic", each
        if [Order Date] = null then null else
        let
            JustDate = DateTime.Date([Order Date]),
            D        = Date.Day(JustDate),
            M        = Date.Month(JustDate)
        in
            if   D = M   then "Mega Day"
            else if D = 15   then "Mid-Month"
            else if D >= 25  then "Payday"
            else "Normal Day"
    , type text),

    // ── 10. Add Platform ──────────────────────────────────────
    #"Added Platform" = Table.AddColumn(#"Added Logic", "Platform", each "Shopee", type text),

    // ── 11. Reorder columns ───────────────────────────────────
    #"Reordered Columns" = Table.ReorderColumns(#"Added Platform", {
        "Order Date", "Order ID", "Order Status",
        "Product ID", "Product Name", "Variation",
        "Quantity", "Sales", "Net Payout",
        "Commission Fee", "Transaction Fee", "Service Fee", "Fee Percentage",
        "Shipping Paid by Buyer", "Seller Voucher Cost",
        "Province", "Postcode",
        "Payment Method", "Payment Group", "Installment Plan",
        "Campaign Type Logic", "Platform"
    }),

    // ── 12. Split Order Date → Date + Time ───────────────────
    #"Duplicated Column"  = Table.DuplicateColumn(#"Reordered Columns", "Order Date", "Order Time"),
    #"Extracted Date"     = Table.TransformColumns(#"Duplicated Column",  {{"Order Date", DateTime.Date, type date}}),
    #"Extracted Time"     = Table.TransformColumns(#"Extracted Date",     {{"Order Time", DateTime.Time, type time}}),

    // ── 13. Final types ───────────────────────────────────────
    #"Final Table" = Table.TransformColumnTypes(#"Extracted Time", {
        {"Order Date",    type date},
        {"Order ID",      type text},
        {"Order Status",  type text},
        {"Product ID",    type text},
        {"Product Name",  type text},
        {"Variation",     type text},
        {"Quantity",      Int64.Type},
        {"Sales",         Int64.Type},
        {"Net Payout",    Int64.Type},
        {"Postcode",      type text},
        {"Order Time",    type time}
    })

in
    #"Final Table"
