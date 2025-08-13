<?php

namespace App\Helpers;

class InvoiceHelper
{
    // Adjusted mapping to your bill_items keys
    private static $columnLabelMap = [
        'item_name'   => 'Item Name',
        'qty'         => 'Quantity',
        'mrp'         => 'MRP',
        'offer_price' => 'Offer Price',
        'amount'      => 'Amount',
        'total_amount'=> 'Total (Incl. GST)',
    ];

    // Adjusted for your tax_details keys
    private static $requiredTaxFields = [
        'item_name'     => 'Item Name',
        'taxable_value' => 'Taxable Value',
        'cgst_percent'  => 'CGST %',
        'cgst'          => 'CGST Amt',
        'sgst_percent'  => 'SGST %',
        'sgst'          => 'SGST Amt',
        'total_gst'     => 'Total GST',
    ];

    private static $requiredPrescription = [
        'right_sph'        => 'R-SPH',
        'left_sph'         => 'L-SPH',
        'right_cyl'        => 'R-CYL',
        'left_cyl'         => 'L-CYL',
        'right_axis'       => 'R-AXIS',
        'left_axis'        => 'L-AXIS',
        'right_add'        => 'R-ADD',
        'left_add'         => 'L-ADD',
        'right_prism'      => 'R-PRISM',
        'left_prism'       => 'L-PRISM',
        'right_base'       => 'R-BASE',
        'left_base'        => 'L-BASE',
        'wear_type'        => 'Wear',
        'lens_design'      => 'Design',
        'materials_coats'  => 'Material',
        'age'              => 'Age',
    ];

    // Entry point
    public static function buildInvoiceHtml(array $invoice): string
    {
        $html = self::getHtmlHeader();

        // Company info could be passed in $invoice['company'], otherwise skip logo
        $base64Image = self::getCompanyImage($invoice['company'] ?? []);

        $html .= self::getCompanyHeader($invoice, $base64Image);

        if (!empty($invoice['bill_items'])) {
            $html .= self::getBillingItemsSection($invoice['bill_items']);
        }
        if (!empty($invoice['tax_details'])) {
            $html .= self::getTaxDetailsSection($invoice['tax_details']);
        }
        
        if (!empty($invoice['prescription'])) {
            $html .= self::getPrescriptionSection($invoice['prescription'], $invoice['invoice_details']['description'] ?? '');
        }
        if (!empty($invoice['bill_items'])) {
            $html .= self::totalAmountandgst($invoice['bill_items'], $invoice['invoice_details']);
        }
        // if (!empty($invoice['invoice_details'])) {
        //     $html .= self::getSummarySection($invoice['invoice_details']);
        // }
        $html .= self::getFooter();
        $html .= '</div></body></html>';
        return $html;
    }
private static function getHtmlHeader(): string
{
    return '<!DOCTYPE html>
    <html>
    head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Invoice</title>
        <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=DejaVu+Sans:400,700&display=swap">
    </head>    
    <body>
    <style>        

            body {
                font-family: DejaVu Sans, sans-serif;
                font-size: 9pt;
                color: #222;
                margin-Top: 50px;
                padding: 0;
            }

            .invoice-box {
                width: 100%;
                margin: 0 auto;
                padding: 4px;
                box-sizing: border-box;
            }

            .section-title {
                font-size: 10pt;
                margin-bottom: 4pt;
                margin-top: 8pt;
                font-weight: bold;
                color: #333;
                page-break-inside: avoid;
            }

            table {
                width: 100%;
                border-collapse: collapse;
                table-layout: auto;
                margin-bottom: 8pt;
                page-break-inside: auto;
                word-wrap: break-word;
                word-break: break-word;
            }

            th, td {
                border: 1px solid #d0d0d0;
                padding: 5pt;
                text-align: left;
                font-size: 9pt;
                vertical-align: top;
            }

            th {
                background-color: #f1f1f1;
                font-weight: bold;
            }

            .totals-table td {
                border: none;
                padding: 4pt 5pt;
            }

            .totals-table tr td:first-child {
                text-align: left; 
                font-weight: bold;
                width: 60%;
            }

            .totals-table tr td:last-child {
                text-align: right;
                width: 40%;
            }

            .summary-box {
                background: #f9f9f9;
                border: 1px solid #ddd;
                padding: 8pt;
                margin: 8pt 0;
                border-radius: 3pt;
                page-break-inside: avoid;
            }

            .footer {
                margin-top: 20pt;
                text-align: center;
                color: #777;
                font-size: 8pt;
                border-top: 1px solid #ccc;
                padding-top: 8pt;
            }

            .page-break {
                page-break-after: always;
            }

            .avoid-break {
                page-break-inside: avoid;
            }

            img {
                max-width: 100%;
                height: auto;
            }
        </style>
    <div class="invoice-box">';
}


    private static function getCompanyImage(array $company): string
    {
        $base64Image = '';
        if (!empty($company['image'])) {
            $imagePath = public_path($company['image']);
            if (file_exists($imagePath)) {
                $imageType = pathinfo($imagePath, PATHINFO_EXTENSION);
                $imageData = base64_encode(file_get_contents($imagePath));
                $base64Image = 'data:image/' . $imageType . ';base64,' . $imageData;
            }
        }
        return $base64Image;
    }
    private static function getCompanyHeader(array $invoice, string $base64Image): string
{
    $company = $invoice['company'] ?? [
        'first_name' => 'n/a',
        'company_name' => 'n/a',
        'full_address' => 'n/a',
        'mobile' => 'n/a',
    ];
    $customer = $invoice['customer'] ?? [];
    $customerName = $customer['name'] ?? '';
    $customerPhone = $customer['mobile'] ?? '';
    $deliveryDate = $invoice['invoice_details']['delivery_date'] ?? '';

    // Use a flexbox-like layout for the table to avoid text squishing
    $html = "
                     <div style='margin-bottom:2px; text-align:center;'><span style='font-size:24px;font-weight:900;color:#50429B'>" .mb_strtoupper(htmlspecialchars($company['company_name'] ?? '', ENT_QUOTES, 'UTF-8'))
 . "</span></div>

<table style='width:100%; margin-bottom:20px; border:none; table-layout:fixed;'>
    <tr>
        <!-- Left: Logo and From Details -->
        <td style='width:46%; vertical-align:top; border:none; padding-right:4px;'>
            <div style='display:flex; align-items:flex-start;'>
                ";
    if ($base64Image) {
        $html .= "<div style='flex-shrink:0;'><img src='{$base64Image}' alt='Logo' style='width: 70px; height: 70px; border-radius: 12px; object-fit: cover; margin-right:4px;'></div>";
    }
    $html .= "
                <div style='flex:1; min-width:0;'>
                   
                    <div style='font-weight:bold; color:#444; margin-bottom:3px;'>From</div>
                    <div class='company-details' style='font-weight:bold; margin-bottom:2px;'>" . htmlspecialchars($company['first_name'] ?? '') . "</div>
                    
                    <div style='margin-bottom:2px;'>Address: <span style='font-weight:500;'>" . htmlspecialchars($company['full_address'] ?? '') . "</span></div>
                    <div>Phone: <span style='font-weight:500;'>" . htmlspecialchars($company['mobile'] ?? '') . "</span></div>
                </div>
            </div>
        </td>
       <!-- Right: Invoice & Customer Details -->
        <td style='width:54%; vertical-align:top; border:none; text-align:right; padding-left:4px; font-family: DejaVu Sans, sans-serif;'>

            <!-- Invoice No -->
            <div style='color:#000000; font-size:8pt; font-weight:600; margin-bottom:4pt;'>INV No : <span style='color:#50429B;'>" . htmlspecialchars($invoice['invoice_no'] ?? '') . "<span> </div>
           

            <!-- Invoice Date -->
            <div style='font-size:8pt; color:#666; margin-bottom:6pt;'>
                <span style='font-weight:500;'>Date:</span>
                <span style='color:#222; font-weight:600; margin-left:5pt;'>
                    " . htmlspecialchars($invoice['date'] ?? date('Y-m-d')) . "
                </span>
            </div>

            <!-- Delivery Date (if any) -->
            " . ($deliveryDate ? "
            <div style='font-size:8pt; color:#666; margin-bottom:6pt;'>
                <span style='font-weight:500;'>Delivery Date:</span>
                <span style='color:#222; font-weight:600; margin-left:5pt;'>
                    " . htmlspecialchars($deliveryDate) . "
                </span>
            </div>" : "") . "

            <!-- Customer Details -->
            <div style='font-weight:bold; font-size:11pt; color:#333; margin-top:12pt; margin-bottom:4pt;'>To</div>
            <div style='font-size:8pt; font-weight:500; color:#111; margin-bottom:2pt;'>
                " . ($customerName ?: '-') . "
            </div>
            <div style='font-size:8pt; color:#444;'>Ph: " . ($customerPhone ?: '-') . "</div>

        </td>

    </tr>
</table>
";

    return $html;
}

   private static function getBillingItemsSection(array $billItems): string
{
    $html = "<div class='section-title'>Billing Items</div>";
    $html .= "<table style='width:100%; border-collapse:collapse; margin-bottom:4px; table-layout:fixed;'>";
    $html .= "<thead><tr>";
    foreach (self::$columnLabelMap as $key => $label) {
        $html .= "<th style='padding:4px;background:#f8f8f8; min-width:80px; word-break:break-word;'>" . htmlspecialchars($label) . "</th>";
    }
    $html .= "</tr></thead><tbody>";
    foreach ($billItems as $item) {
        $html .= "<tr>";
        foreach (self::$columnLabelMap as $key => $label) {
            $value = $item[$key] ?? '';
            $html .= "<td style='padding:4px;min-width:80px; word-break:break-word;'>" . htmlspecialchars($value) . "</td>";
        }
        $html .= "</tr>";
    }
    $html .= "</tbody></table>";
    return $html;
}

    private static function getTaxDetailsSection(array $taxDetails): string
{
    $html = "<div class='section-title'>Tax Details</div>";
    $headers = array_keys(self::$requiredTaxFields);
    $html .= "<div style='overflow-x:auto;'>";
    $html .= "<table style='width:100%; border-collapse:collapse; margin-bottom:4px; table-layout:fixed;'>";
    $html .= "<thead><tr>";
    foreach ($headers as $key) {
        $label = self::$requiredTaxFields[$key];
        $html .= "<th style='padding:4px; background:#f8f8f8; min-width:80px; word-break:break-word;'>" . htmlspecialchars($label) . "</th>";
    }
    $html .= "</tr></thead><tbody>";
    foreach ($taxDetails as $item) {
        $html .= "<tr>";
        foreach ($headers as $key) {
            $val = $item[$key] ?? '';
            $html .= "<td style='padding:4px; min-width:80px; word-break:break-word;'>" . htmlspecialchars($val) . "</td>";
        }
        $html .= "</tr>";
    }
    $html .= "</tbody></table>";
    $html .= "</div>";
    return $html;
}

    // This will show key invoice summary values from invoice_details array
  private static function getSummarySection(array $invoiceDetails): string
{
    $html = "<div class='section-title'>Summary</div>";
    $summaryMap = [
        'description'     => 'Description',
        'discount'        => 'Discount (%)',
        'advance'         => 'Advance',
        'total_amount'    => 'Total Amount',
        'pending_amount'  => 'Pending Amount',
        'total_gst'       => 'Total GST',
        'total_items'     => 'Total Items',
        'total_qty'       => 'Total Quantity',
    ];
    $html .= "<div class='summary-box' style='padding:14px 4px;'>";
    $html .= "<table class='totals-table' style='width:100%; border-collapse:collapse;'>";
    foreach ($summaryMap as $key => $label) {
        if (isset($invoiceDetails[$key]) && $invoiceDetails[$key] !== '') {
            $html .= "<tr>
                <td style='text-align:left; padding:4px; font-weight:500; width:60%; border:none;'>" . htmlspecialchars($label) . "</td>
                <td style='text-align:right; padding:4px; width:40%; border:none;'>" . htmlspecialchars($invoiceDetails[$key]) . "</td>
            </tr>";
        }
    }
    $html .= "</table></div><div style='clear:both;'></div>";
    return $html;
}


    // Prescription logic stays similar
private static function getPrescriptionSection(array $prescriptions, string $description): string
{
    $html = "<div class='section-title'>Prescription</div>";
    if (empty($prescriptions)) return $html;

    $firstPrescription = $prescriptions[0];

    // Section 1: Age, Wear, Design, Material
    $section1Keys = [
        'age'             => 'Age',
        'wear_type'       => 'Wear',
        'lens_design'     => 'Design',
        'materials_coats' => 'Material',
    ];

    // Section 2: Left Eye
    $section2Keys = [
        'left_sph'    => 'L-SPH',
        'left_cyl'    => 'L-CYL',
        'left_axis'   => 'L-AXIS',
        'left_add'    => 'L-ADD',
        'left_prism'  => 'L-PRISM',
        'left_base'   => 'L-BASE',
    ];

    // Section 3: Right Eye
    $section3Keys = [
        'right_sph'   => 'R-SPH',
        'right_cyl'   => 'R-CYL',
        'right_axis'  => 'R-AXIS',
        'right_add'   => 'R-ADD',
        'right_prism' => 'R-PRISM',
        'right_base'  => 'R-BASE',
    ];

    // Section 1 Table
    $html .= '<div style="overflow-x:auto; margin-bottom:4px;">';
    $html .= '<table style="border-collapse:collapse; width:auto; min-width:100%;word-break:break-word;">';
    $html .= '<thead><tr style="background-color:#f8f8f8;">';
    foreach ($section1Keys as $key => $label) {
        $html .= '<th style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($label).'</th>';
    }
    $html .= '</tr></thead><tbody><tr>';
    foreach ($section1Keys as $key => $label) {
        $raw = $firstPrescription[$key] ?? '';
        $html .= '<td style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($raw).'</td>';
    }
    $html .= '</tr></tbody></table></div>';

    // Section 2 Table (Left Eye)
    $html .= '<div class="section-title">Left Eye</div>';
    $html .= '<div style="overflow-x:auto; margin-bottom:4px;">';
    $html .= '<table style="border-collapse:collapse; width:auto; min-width:100%; word-break:break-word;">';
    $html .= '<thead><tr style="background-color:#f8f8f8;">';
    foreach ($section2Keys as $key => $label) {
        $html .= '<th style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($label).'</th>';
    }
    $html .= '</tr></thead><tbody><tr>';
    foreach ($section2Keys as $key => $label) {
        $raw = $firstPrescription[$key] ?? '';
        $html .= '<td style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($raw).'</td>';
    }
    $html .= '</tr></tbody></table></div>';

    // Section 3 Table (Right Eye)
    $html .= '<div class="section-title">Right Eye</div>';
    $html .= '<div style="overflow-x:auto; margin-bottom:4px;">';
    $html .= '<table style="border-collapse:collapse; width:auto; min-width:100%; word-break:break-word;">';
    $html .= '<thead><tr style="background-color:#f8f8f8;">';
    foreach ($section3Keys as $key => $label) {
        $html .= '<th style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($label).'</th>';
    }
    $html .= '</tr></thead><tbody><tr>';
    foreach ($section3Keys as $key => $label) {
        $raw = $firstPrescription[$key] ?? '';
        $html .= '<td style="padding:4px; border:1px solid #ccc; min-width:80px;">'.htmlspecialchars($raw).'</td>';
    }
    $html .= '</tr></tbody></table></div>';

    // Prescription Note
    if (!empty($firstPrescription['priscription'])) {
        $html .= '<div style="margin-top: 4px; padding: 4px; border: 1px solid #eee; background-color: #f9f9f9;">
                    <strong>Prescription Note:</strong> ' . htmlspecialchars($firstPrescription['priscription'], ENT_QUOTES) . '
                 </div>';
    }
    // Description Note
    if (!empty($description)) {
        $html .= '<div style="margin-top: 4px; padding: 4px; border: 1px solid #eee; background-color: #f9f9f9;">
                    <strong>Description Note:</strong> ' . htmlspecialchars($description, ENT_QUOTES) . '
                 </div>';
    }

    return $html;
}



    // Use invoice_details for totals (pass as $invoiceDetails)
   private static function totalAmountandgst(array $billItems, ?array $invoiceDetails = null): string
{
    $totalGst      = $invoiceDetails['total_gst']      ?? 0;
    $totalAmount   = $invoiceDetails['total_amount']   ?? 0;
    $totalDiscount = $invoiceDetails['discount']       ?? 0;
    $advance       = $invoiceDetails['advance']        ?? 0;
    $pendingAmount = $invoiceDetails['pending_amount'] ?? 0;

    $html = "<div class='section-title'>Total Amount & GST</div>";
    $html .= "<table class='totals-table' style='width:100%; border-collapse:collapse; margin-bottom:4px;'>";

    if ($totalDiscount > 0) {
        $html .= "<tr>
            <td style='text-align:left; padding:4px;'>Discount</td>
            <td style='text-align:right; padding:4px;'>" . number_format($totalDiscount, 2) . "</td>
        </tr>";
    }
    if ($advance > 0) {
        $html .= "<tr>
            <td style='text-align:left; padding:4px;'>Advance Amount</td>
            <td style='text-align:right; padding:4px;'>" . number_format($advance, 2) . "</td>
        </tr>";
    }
    if ($pendingAmount > 0) {
        $html .= "<tr>
            <td style='text-align:left; padding:4px;'>Pending Amount</td>
            <td style='text-align:right; padding:4px;'>" . number_format($pendingAmount, 2) . "</td>
        </tr>";
    }
    $html .= "<tr>
        <td style='text-align:left; padding:4px; font-weight:600;'><strong>Total GST Amount</strong></td>
        <td style='text-align:right; padding:4px; font-weight:600;'><strong>" . number_format($totalGst, 2) . "</strong></td>
    </tr>
    <tr>
        <td style='text-align:left; padding:4px; font-weight:600;'><strong>Total Amount (Incl. GST)</strong></td>
        <td style='text-align:right; padding:4px; font-weight:600;'><strong>" . number_format($totalAmount, 2) . "</strong></td>
    </tr>";

    $html .= "</table>";
    return $html;
}


    // Footer stays as is
   private static function getFooter(): string
{
    return "
    <div style='
        margin-top: 36px;
        padding: 16px 0 8px 0;
        font-family: Arial, sans-serif;
        color: #444;
        border-top: 1px solid #ccc;
        min-height: 52px;
        position: relative;
        box-sizing: border-box;
    '>
        <div style='text-align:center; font-weight:500; margin-bottom:6px;'>
            Thank you for your business!
        </div>
        <div style=\"
            width:100%;
            height:30px;
            position:relative;
        \">
            <img src='https://waqin.ai/img/logo.png' alt='Logo' style='
                position:absolute;
                right:0;
                bottom:0;
                height:30px;
                opacity:0.8;
                z-index:2;
            '>
        </div>
    </div>
    ";
}
}
