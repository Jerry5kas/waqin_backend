<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>{{ $document->serial_number }}</title>
    <style>
        body {
            font-family: DejaVu Sans, sans-serif;
            font-size: 11px;
            margin: 10px;
            background: #f8f9fa;
        }
        .header, .footer {
            width: 100%;
            margin-bottom: 15px;
        }
        .left, .right {
            width: 48%;
            display: inline-block;
            vertical-align: top;
        }
        .right {
            text-align: right;
        }
        .logo {
            max-height: 50px;
            margin-bottom: 8px;
        }
        .company-header {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;           
            background: white;
            padding: 12px;
            border-radius: 6px;
            /* border-left: 4px solid #667eea; */
            /* box-shadow: 0 2px 4px rgba(0,0,0,0.05); */
        }
        .company-info {
            flex: 1;
        }
        .company-logo {
            width: 100px;
            text-align: left;
        }
        .company-logo img {
            max-width: 80px;
            max-height: 60px;
            border-radius: 4px;
            border: 2px solid #e9ecef;
        }
        .company-name {            
            font-weight: bold;
            margin-bottom: 4px;
            color: #333;
        }
        .company-details {
            font-size: 10px;
            line-height: 1.3;
            color: #666;
        }
        .invoice-header {
            text-align: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 4px 15px;
            border-radius: 8px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .invoice-title {
            font-size: 22px;
            color: #000;
            font-weight: bold;
            margin-bottom: 3px;
            text-shadow: 0 2px 4px rgba(0,0,0,0.3);
        }
        .invoice-number {
            font-size: 14px;
            color: black;
        }
        .info-section {            
            background: white;
            padding: 12px;
            border-radius: 6px;
            /* border-left: 4px solid #28a745;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05); */
        }
        .info-title {
            font-weight: bold;
            font-size: 10px;
            margin-bottom: 8px;
            color: #333;
            text-transform: uppercase;
            padding: 4px 8px;
            background: #e3f2fd;
            border-radius: 4px;
            border-left: 3px solid #2196f3;
            vertical-align: top;
        }
        /* .info-content {
            margin-bottom: 8px;
        } */
        .info-row {
            display: flex;
            margin-bottom: 6px;
            border-bottom: 1px solid #f0f0f0;
            padding-bottom: 4px;
        }
        .info-row:last-child {
            border-bottom: none;
            margin-bottom: 0;
        }
        .info-label {
            font-weight: bold;
            width: 120px;
            color: #495057;
            font-size: 10px;
        }
        .info-value {
            flex: 1;
            color: #333;
            font-size: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 12px;
            background: white;
            border-radius: 6px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        table th, table td {
            border: 1px solid #dee2e6;
            padding: 6px;
            text-align: left;
            font-size: 10px;
        }
        table th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: black;
            font-weight: bold;
            font-size: 10px;
        }
        .section-title {
            font-weight: bold;
            font-size: 16px;
            margin-top: 15px;
            margin-bottom: 8px;
            color: #333;
            padding: 6px 10px;
            background: #f8f9fa;
            border-radius: 4px;
            border-left: 4px solid #ffc107;
        }
        .summary-table {
            width: 50%;
            margin-left: auto;
            background: white;
            border-radius: 6px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .summary-table td {
            text-align: left;
            padding: 4px 8px;
            border-bottom: 1px solid #f0f0f0;
            font-size: 10px;
        }
        .summary-table .label {
            font-weight: bold;
            color: #495057;
        }
        .summary-table tr:last-child td {
            border-bottom: none;
            background: #e8f5e8;
            font-weight: bold;
        }
        .watermark {
            position: fixed;
            align-items: center;
            bottom: 5px;
            left: 50%;
            transform: translate(-50%, -50%);
            font-size: 14px;
            color: rgba(102, 126, 234, 0.1);
            font-weight: bold;
        }
        .status-paid {
            color: #28a745;
            font-weight: bold;
        }
        .status-partial {
            color: #ffc107;
            font-weight: bold;
        }
        .status-pending {
            color: #dc3545;
            font-weight: bold;
        }
    </style>
</head>
<body>

<div class="invoice-header">
    <div class="invoice-title">
        {{ $document->type == 'invoice' ? 'INVOICE' : ($document->type == 'order' ? 'Order' : 'Proposal') }}
    </div>
    <div class="invoice-number">{{ $document->serial_number }}</div>
</div>
<table>
    <tr>
        <td style="width: 33%; padding-right: 10px; vertical-align: top;">
            <div class="company-header">
                <div class="company-info">
                    <div class="info-title">Company Information</div>
                    <div class="company-name">{{ $user->first_name }} {{ $user->last_name }}</div>
                    <div class="company-logo">
                        @if($user->image)
                      	
                      	    <img src="{{ public_path('storage/' . $user->image) }}">
                        @endif
                    </div>
                    <div class="company-details">
                        @if($user->company_name)
                            <div class="info-row">
                                <span class="info-label">Company:</span>
                                <span class="info-value">{{ $user->company_name }}</span>
                            </div>
                        @endif
                        @if($user->full_address)
                            <div class="info-row">
                                <span class="info-label">Address:</span>
                                <span class="info-value">{{ $user->full_address }}</span>
                            </div>
                        @endif
                        @if($user->mobile)
                            <div class="info-row">
                                <span class="info-label">Phone:</span>
                                <span class="info-value">{{ $user->mobile }}</span>
                            </div>
                        @endif
                        @if($user->email)
                            <div class="info-row">
                                <span class="info-label">Email:</span>
                                <span class="info-value">{{ $user->email }}</span>
                            </div>
                        @endif
                        @if($user->gst)
                            <div class="info-row">
                                <span class="info-label">GST:</span>
                                <span class="info-value">{{ $user->gst }}</span>
                            </div>
                        @endif
                        @if($user->pan)
                            <div class="info-row">
                                <span class="info-label">PAN:</span>
                                <span class="info-value">{{ $user->pan }}</span>
                            </div>
                        @endif
                       
                        @if($user->user_type)
                            <div class="info-row">
                                <span class="info-label">Type:</span>
                                <span class="info-value">{{ $user->user_type }}</span>
                            </div>
                        @endif
                    </div>
                </div>
            </div>
        </td>
        <td style="width: 33%; vertical-align: top;">
            <div class="info-section">
                <div class="info-title">Customer Information</div>
                <div class="info-content">
                    <div class="info-row">
                        <span class="info-label">Name:</span>
                        <span class="info-value">{{ $customer->name }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Mobile:</span>
                        <span class="info-value">{{ $customer->mobile }}</span>
                    </div>
                    @if($customer->email)
                    <div class="info-row">
                        <span class="info-label">Email:</span>
                        <span class="info-value">{{ $customer->email }}</span>
                    </div>
                    @endif
                </div>
            </div>
        </td>
        <td style="width: 33%; padding-left: 10px; vertical-align: top;">
            <div class="info-section">
                <div class="info-title">Order Information</div>
                <div class="info-content">
                    <div class="info-row">
                        <span class="info-label">Order Date:</span>
                        <span class="info-value">{{ \Carbon\Carbon::parse($document->created_at)->format('d/m/Y') }}</span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Order Ref. No:</span>
                        <span class="info-value">
                            {{ $document->ref_order_no ?? 'NA' }}
                        </span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Payment Mode:</span>
                        <span class="info-value">{{ $document->payment_mode }}</span>
                    </div>
                    @if($document->delivery_date)
                    <div class="info-row">
                        <span class="info-label">Delivery Date:</span>
                        <span class="info-value">{{ \Carbon\Carbon::parse($document->delivery_date)->format('d/m/Y') }}</span>
                    </div>
                    @endif
                    @if($document->ref_invoice)
                    <div class="info-row">
                        <span class="info-label">Reference:</span>
                        <span class="info-value">{{ $document->ref_invoice }}</span>
                    </div>
                    @endif
                    <div class="info-row">
                        <span class="info-label">Status:</span>
                        <span class="info-value">
                            @if($document->pending_amount == 0)
                                <span class="status-paid">Paid</span>
                            @elseif($document->advance > 0)
                                <span class="status-partial">Partial</span>
                            @else
                                <span class="status-pending">Pending</span>
                            @endif
                        </span>
                    </div>
                </div>
            </div>
        </td>
    </tr>
</table>

@if($document->description)
<div class="info-section">
    <div class="info-title">Description</div>
    <div class="info-content">{{ $document->description }}</div>
</div>
@endif

<div class="section-title">Order Details</div>
<table>
    <thead>
        <tr>
            <th>Item Name</th>
            <th>Qty</th>
            <th>MRP</th>
            <th>Offer</th>
            <th>Amount</th>
            <th>Total Amount</th>
        </tr>
    </thead>
    <tbody>
        @foreach($billItems as $item)
            <tr>
                <td>{{ $item->item_name }}</td>
                <td>{{ $item->qty }}</td>
                <td>₹{{ number_format($item->mrp, 2) }}</td>
                <td>₹{{ number_format($item->offer, 2) }}</td>
                <td>₹{{ number_format($item->amount, 2) }}</td>
                <td>₹{{ number_format($item->total_amount, 2) }}</td>
            </tr>
        @endforeach
    </tbody>
</table>

@if(isset($taxDetails) && $taxDetails->count())
    <div class="section-title">Tax Details</div>
    <table>
        <thead>
            <tr>
                <th>Item</th><th>Taxable</th><th>CGST</th><th>CGST %</th>
                <th>SGST</th><th>SGST %</th><th>Total GST</th>
            </tr>
        </thead>
        <tbody>
            @foreach($taxDetails as $tax)
                <tr>
                    <td>{{ $tax->item_name }}</td>
                    <td>₹{{ number_format($tax->taxable_value, 2) }}</td>
                    <td>₹{{ number_format($tax->cgst, 2) }}</td>
                    <td>{{ $tax->cgst_percent }}%</td>
                    <td>₹{{ number_format($tax->sgst, 2) }}</td>
                    <td>{{ $tax->sgst_percent }}%</td>
                    <td>₹{{ number_format($tax->total_gst, 2) }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endif
  @php
  	$decoded = [];

     if (isset($prescription)) {
        // Case 3: Direct array with keys (not nested in 'prescription')
        $allKeys = ['wear_type', 'lens_design', 'materials_coats', 'right_sph', 'right_cyl', 'right_axis', 'right_add', 'right_prism', 'right_base'];
        $isDirect = is_array($prescription) && count(array_intersect(array_keys($prescription), $allKeys)) > 0;

        if ($isDirect) {
            $decoded = $prescription;
        } else {
            $rawData = is_array($prescription) 
                ? ($prescription['prescription'] ?? null)
                : ($prescription->prescription ?? null);

            $decoded = is_array($rawData)
                ? $rawData
                : (is_string($rawData) ? json_decode($rawData, true) ?? [] : []);
        }
    }
  
    $generalFields = [
        'age' => 'Age',
        'priscription' => 'Prescription',
        'wear_type' => 'Wear Type',
        'lens_design' => 'Lens Design',
        'materials_coats' => 'Materials Coats'
    ];
    $eyeFields = [
        'right_sph' => 'Right Sph',
        'right_cyl' => 'Right Cyl',
        'right_axis' => 'Right Axis',
        'right_add' => 'Right Add',
        'right_prism' => 'Right Prism',
        'left_sph' => 'Left Sph',
        'left_cyl' => 'Left Cyl',
        'left_axis' => 'Left Axis',
        'left_add' => 'Left Add',
        'left_prism' => 'Left Prism',
       
    ];

    $generalData = [];
    $tableRow = [];

    foreach ($generalFields as $key => $label) {
        if (isset($decoded[$key])) {
            $generalData[$label] = $decoded[$key];
        }
    }

    foreach ($eyeFields as $key => $label) {
        $tableRow[$label] = $decoded[$key] ?? '';
    }
@endphp

@if(!empty($generalData) || !empty($tableRow))
    <div class="section-title">Prescription</div>

    {{-- General Info Table --}}
    @if(!empty($generalData))
    <table style="margin-bottom: 10px;">
        <tr>
            @foreach($generalData as $key => $value)
                <td><strong>{{ $key }}:</strong> {{ $value }}</td>
            @endforeach
        </tr>
    </table>
    @endif

    {{-- Eye Prescription Table --}}
    @if(!empty($tableRow))
    <table>
        <thead>
            <tr>
                @foreach($tableRow as $label => $val)
                    <th>{{ $label }}</th>
                @endforeach
            </tr>
        </thead>
        <tbody>
            <tr>
                @foreach($tableRow as $val)
                    <td>{{ $val }}</td>
                @endforeach
            </tr>
        </tbody>
    </table>
    @endif
@endif

<div class="section-title">Order Summary</div>
<table class="summary-table">
    <tr>
        <td class="label">Total Items:</td>
        <td>{{ $document->total_items }}</td>
    </tr>
    <tr>
        <td class="label">Total Quantity:</td>
        <td>{{ $document->total_qty }}</td>
    </tr>
    @if($document->total_gst > 0)
    <tr>
        <td class="label">Total GST:</td>
        <td>₹{{ number_format($document->total_gst, 2) }}</td>
    </tr>
    @endif
    @if($document->advance > 0)
    <tr>
        <td class="label">Advance Paid:</td>
        <td>₹{{ number_format($document->advance, 2) }}</td>
    </tr>
    @endif
    @if($document->pending_amount > 0)
    <tr>
        <td class="label"><strong>Pending Amount:</strong></td>
        <td><strong>₹{{ number_format($document->pending_amount, 2) }}</strong></td>
    </tr>
    @endif
    @php
        $discountValue = $document->discount_type === 'percentage'
            ? $document->discount_precentage . '%'
            : '₹' . number_format($document->discount_amount, 2);
    @endphp
    <tr>
        <td class="label">Discount:</td>
        <td>{{ $discountValue }}</td>
    </tr>
    <tr>
        <td class="label"><strong>Total Amount:</strong></td>
        <td><strong>₹{{ number_format($document->total_amount, 2) }}</strong></td>
    </tr>
</table>

<div class="watermark">
    <img src="{{ public_path('img/logo.png') }}" alt="Waqin CRM" style="width: 100px; opacity: 0.3;">
</div>
</body>
</html>

