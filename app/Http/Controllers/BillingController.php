<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Carbon\Carbon;
use Barryvdh\DomPDF\Facade\Pdf;
class BillingController extends Controller
{
    public function createInvoice(Request $request)
    {
        return $this->storeDocument($request, 'invoice');
    }

    public function createOrder(Request $request)
    {
        return $this->storeDocument($request, 'order');
    }

    public function createProposal(Request $request)
    {
        return $this->storeDocument($request, 'proposal');
    }

    public function fetchDocuments(Request $request)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        config(['database.connections.tenant.database' => $tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');

        if (!Schema::connection('tenant')->hasTable('documents')) {
            return response()->json([
                'message' => 'Documents table does not exist.',
                'data' => [],
            ]);
        }

        $query = DB::connection('tenant')->table('documents')->select([
            'id','type','serial_number','ref_order_no','customer_id','description',
            'discount','advance','delivery_date','employee_id','ref_invoice','total_amount',
            'pending_amount','total_items','total_qty',
            'created_at','updated_at'
        ]);

        if ($request->filled('type')) {
            $query->where('type', $request->input('type'));
        }

        if ($request->filled('from_date') && $request->filled('to_date')) {
            $query->whereBetween('created_at', [
                $request->input('from_date').' 00:00:00',
                $request->input('to_date').' 23:59:59'
            ]);
        }

        if ($request->filled('search')) {
            $searchTerm = $request->input('search');
            $matchingCustomerIds = DB::connection('tenant')->table('customers')
                ->where('name', 'like', "%{$searchTerm}%")
                ->orWhere('mobile', 'like', "%{$searchTerm}%")
                ->pluck('id');

            $query->where(function($q) use ($searchTerm, $matchingCustomerIds) {
                $q->where('serial_number', 'like', "%{$searchTerm}%")
                ->orWhere('ref_order_no', 'like', "%{$searchTerm}%")
                ->orWhereIn('customer_id', $matchingCustomerIds);
            });
        }

        // Clone query before pagination for global total calculation
        $clonedQuery = clone $query;

        $limit = intval($request->input('limit', 10));
        $offset = intval($request->input('offset', 0));

        $total = $query->count();
        $documents = $query->offset($offset)
                        ->limit($limit)
                        ->orderBy('created_at', 'desc')
                        ->get();

        $connection = DB::connection('tenant');

        // Calculate grand totals from all filtered records (not limited)
        $allMatchingDocs = $clonedQuery->get();
        $grandTotalAmount = $allMatchingDocs->sum('total_amount');
        $grandPendingAmount = $allMatchingDocs->sum('pending_amount');

        $docs = $documents->map(function($doc) use ($connection) {
            $sourceDocId = $doc->id;
            if (!empty($doc->ref_order_no)) {
                $refDoc = $connection->table('documents')
                    ->where('serial_number', $doc->ref_order_no)
                    ->first();
                if ($refDoc) {
                    $sourceDocId = $refDoc->id;
                }
            }

            $totalAmount = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('total_amount');
            $totalTax = $connection->table('tax_details')->where('document_id', $sourceDocId)->sum('total_gst');
            $totalItems = $connection->table('bill_items')->where('document_id', $sourceDocId)->count();
            $totalQty = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('qty');

            $customer = $connection->table('customers')->where('id', $doc->customer_id)->first();
            $custName = $customer?->name ?? '';
            $custNum = $customer?->mobile ?? '';

            if (Schema::connection('tenant')->hasTable('employees') && $doc->employee_id) {
                $employee = $connection->table('employees')->where('id', $doc->employee_id)->first();
                $empName = $employee?->full_name ?? '';
            } else {
                $empName = 'NA';
            }

            $pending = $doc->pending_amount ?? 0;
            $status = match (true) {
                $pending <= 0 => 'Paid',
                $pending >= $totalAmount => 'Unpaid',
                default => 'Partial',
            };

            return [
                'date' => date('Y-m-d', strtotime($doc->created_at)),
                'doc_id' => $doc->id,
                'serial_number' => $doc->serial_number,
                'employee_id' => $doc->employee_id,
                'employee_name' => $empName,
                'ref_invoice_no' => $doc->ref_invoice,
                'ref_order_no' => $doc->ref_order_no,
                'total_amount' => $doc->total_amount,
                'pending_amount' => $doc->pending_amount,
                'total_gst' => $totalTax,
                'total_items' => $totalItems,
                'total_qty' => "{$totalQty}",
                'customer_name' => $custName,
                'customer_number' => $custNum,
                'status' => $status,
                'type'=> 'MOB'
            ];
        });

        return response()->json([
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'total_amount' => [
                'total' => number_format($grandTotalAmount, 2, '.', ''),
                'pending' => number_format($grandPendingAmount, 2, '.', ''),
            ],
            'data' => $docs,
        ]);
    }


    //     $tenantSchema = $user->tenant_schema;
    //     config(['database.connections.tenant.database' => $tenantSchema]);
    //     DB::purge('tenant');
    //     DB::reconnect('tenant');

    //     if (!Schema::connection('tenant')->hasTable('documents')) {
    //         return response()->json([
    //             'message' => 'Documents table does not exist.',
    //             'data' => [],
    //         ]);
    //     }

    //     $query = DB::connection('tenant')->table('documents')->select([
    //         'id','type','serial_number','ref_order_no','customer_id','description',
    //         'discount','advance','delivery_date','employee_id','ref_invoice','total_amount',
    //         'pending_amount','total_items','total_qty',
    //         'created_at','updated_at'
    //     ]);

    //     if ($request->filled('type')) {
    //         $query->where('type', $request->input('type'));
    //     }

    //     if ($request->filled('from_date') && $request->filled('to_date')) {
    //         $query->whereBetween('created_at', [
    //             $request->input('from_date').' 00:00:00',
    //             $request->input('to_date').' 23:59:59'
    //         ]);
    //     }

    //     if ($request->filled('search')) {
    //         $searchTerm = $request->input('search');
    //         // Find matching customer IDs from customer name or mobile
    //         $matchingCustomerIds = DB::connection('tenant')->table('customers')
    //             ->where('name', 'like', "%{$searchTerm}%")
    //             ->orWhere('mobile', 'like', "%{$searchTerm}%")
    //             ->pluck('id');

    //         $query->where(function($q) use ($searchTerm, $matchingCustomerIds) {
    //             $q->where('serial_number', 'like', "%{$searchTerm}%")
    //             ->orWhere('ref_order_no', 'like', "%{$searchTerm}%")
    //             ->orWhereIn('customer_id', $matchingCustomerIds);
    //         });
    //     }

    //     $limit = intval($request->input('limit',10));
    //     $offset = intval($request->input('offset',0));

    //     $total = $query->count();
    //     $documents = $query->offset($offset)
    //                        ->limit($limit)
    //                        ->orderBy('created_at','desc')
    //                        ->get();

    //     $connection = DB::connection('tenant');

    //     $grandTotalAmount = 0;
    //     $grandPendingAmount = 0;
    //     $docs = $documents->map(function($doc) use($connection, &$grandTotalAmount, &$grandPendingAmount) {
    //         $sourceDocId = $doc->id;
    //         if (!empty($doc->ref_order_no)) {
    //             $refDoc = $connection->table('documents')
    //                 ->where('serial_number', $doc->ref_order_no)
    //                 ->first();
    //             if ($refDoc) {
    //                 $sourceDocId = $refDoc->id;
    //             }
    //         }

    //         $totalAmount = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('total_amount');
    //         $totalTax    = $connection->table('tax_details')->where('document_id', $sourceDocId)->sum('total_gst');
    //         $totalItems  = $connection->table('bill_items')->where('document_id', $sourceDocId)->count();
    //         $totalQty    = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('qty');

    //         $customer = $connection->table('customers')->where('id',$doc->customer_id)->first();
    //         $custName = $customer?->name ?? '';
    //         $custNum  = $customer?->mobile ?? '';

    //         if (Schema::connection('tenant')->hasTable('employees') && $doc->employee_id) {
    //             $employee = $connection->table('employees')->where('id', $doc->employee_id)->first();
    //             $empName = $employee?->full_name ?? '';
    //         } else {
    //             $empName = 'NA';
    //         }

    //       $pending = $doc->pending_amount ?? 0;
    //       $grandTotalAmount += floatval($doc->total_amount ?? 0);
    //       $grandPendingAmount += floatval($doc->pending_amount ?? 0);

    //      $status = match (true) {
    //      $pending <= 0 => 'Paid',
    //      $pending >= $totalAmount => 'Unpaid',
    //      default => 'Partial',
    //      };


    //         return [
    //             'date'=>date('Y-m-d',strtotime($doc->created_at)),
    //             'doc_id'=>$doc->id,
    //             'serial_number'=>$doc->serial_number,
    //             'employee_id'=>$doc->employee_id,
    //             'employee_name'=>$empName,
    //             'ref_invoice_no'=>$doc->ref_invoice,
    //             'ref_order_no'=>$doc->ref_order_no,
    //             'total_amount'=>$doc->total_amount,
    //             'pending_amount'=>$doc->pending_amount,
    //             'total_gst'=>$totalTax,
    //             'total_items'=>$totalItems,
    //             'total_qty'=>"{$totalQty}",
    //             'customer_name'=>$custName,
    //             'customer_number'=>$custNum,
    //             'status'=>$status,
    //         ];
    //     });

    //     return response()->json([
    //         'total' => $total,
    //         'limit' => $limit,
    //         'offset' => $offset,
    //         'total_amount' => [
    //             'total' => number_format($grandTotalAmount, 2, '.', ''),
    //             'pending' => number_format($grandPendingAmount, 2, '.', ''),
    //         ],
    //         'data' => $docs,
    //     ]);
    // }

    private function storeDocument(Request $request, string $type)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message'=>'Tenant schema missing in token'],401);
        }

        $tenantSchema = $user->tenant_schema;
        config(['database.connections.tenant.database'=>$tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');

        $this->ensureTablesExist();
        DB::connection('tenant')->beginTransaction();

        try {
            $serial     = $this->generateSerial($type);
            $now        = now();
            $data       =  $request->json()->all();

            $documentId = DB::connection('tenant')->table('documents')->insertGetId([
                'type'=>$type,
                'serial_number'=>$serial,
                'customer_id'=>$data['customer_id']??null,
                'employee_id'=>$data['employee_id']??null,
                'ref_invoice'=>$data['ref_invoice']??null,
                'ref_order_no'=>$data['ref_order_no']??null,
                'description'=>$data['form_data']['description']??null,
                'total_amount'=>$data['total_amount']??0.00,
                'discount_precentage'=>$data['discount_precentage']??0.00,
                'pending_amount'=>$data['pending_amount']??0.00,
                'discount'=>$data['form_data']['discount']??0.00,
                'advance'=>$data['form_data']['advance']??0.00,
                'delivery_date' => isset($data['form_data']['delivery_date'])
                 ? date('Y-m-d H:i:s', strtotime($data['form_data']['delivery_date']))
                 : null,
                'payment_mode'=>$data['payment_mode']??null,
                'discount_type'=>$data['discount_type']??null,
                'total_items'=>$data['total_items']??0.00,
                'net_amount'=>$data['net_amount']??0.00,
                'total_qty'=>$data['total_qty']??0,
                'total_gst'=>$data['total_gst']??0.00,
                'discount_amount'=>$data['discount_amount']??0,
                'created_at'=>$now,'updated_at'=>$now,
                'created_by'=>$user->id
            ]);

            if (!empty($data['ref_order_no'])) {
                DB::connection('tenant')->commit();

                return response()->json([
                    'message' => ucfirst($type) . ' created successfully with reference order.',
                    'document_id' => $documentId,
                    'serial_number' => $serial
                ]);
            }
            // Attachments
            $attachmentRows=[];
            foreach($data['form_data']['attachment']??[] as $base64){
                if(preg_match('/^data:image\/(\w+);base64,/',$base64,$m)){
                    $ext=strtolower($m[1]);
                    $imgData=base64_decode(substr($base64,strpos($base64,',')+1));
                    $name='IMG_'.uniqid().".{$ext}";
                    $path="{$tenantSchema}/newattachments/{$name}";
                    Storage::disk('public')->put($path,$imgData);
                    $attachmentRows[]=[
                        'document_id'=>$documentId,
                        'customer_id'=>$data['form_data']['customer_id']??null,
                        'path'=>$path,'status'=>1,'is_deleted'=>0,
                        'created_at'=>$now,'updated_at'=>$now
                    ];
                }
            }
            $this->insertData('newattachments',$attachmentRows);

            // Bill items + commission calculation
            $itemRows=[];
            $commissionRows=[];
            foreach($data['bill_items']??[] as $item){
                $price = (isset($item['offer_price']) && $item['offer_price'] != 0) ? (float) $item['offer_price'] : (float) $item['mrp'];
                $percent = (float) ($item['employee_percentage'] ?? 0);
                $commissionAmount = $percent > 0 ? ($price * ($percent / 100)) : 0;

                // Prepare bill_items insert
                $itemRows[]=[
                    'document_id'=>$documentId,
                    'item_name'=>$item['item_name'],
                    'qty'=>$item['qty'],
                    'mrp'=>$item['mrp'],
                    'offer'=>$price,
                    'amount'=>$item['amount'],
                    'total_amount'=>$item['total_amount'],
                    'employee_percentage'=>$percent,
                    'product_id'=>$item['product_id']??null,
                    'service_id'=>$item['service_id']??null,
                    'created_at'=>$now,'updated_at'=>$now
                ];

                // Prepare employee_commission insert
                $commissionRows[]=[
                    'employee_id'=>$data['employee_id']??null,
                    'doc_id'=>$documentId,
                    'product'=>$item['product_id'] ? json_encode($item) : null,
                    'service'=>$item['service_id'] ? json_encode($item) : null,
                    'total_amount'=>$commissionAmount,
                    'status'=>1,'is_deleted'=>0,
                    'created_at'=>$now,'updated_at'=>$now
                ];
                if ($type == 'invoice' && !empty($item['product_id'])) {
                        $product = DB::connection('tenant')->table('product-catalogs')
                            ->where('id', $item['product_id'])
                            ->where('is_inventory', 1)
                            ->first();
                        if ($product) {
                            $qty = (int) $item['qty'];
                            if ($product->available_quantity < $qty) {
                                return response()->json([
                                    'message' => "Insufficient stock for product: {$product->title}",
                                ], 200);
                            }
                            // Deduct available quantity
                            DB::connection('tenant')->table('product-catalogs')
                                ->where('id', $item['product_id'])
                                ->decrement('available_quantity', $qty);
                        }
                    }
            }

            $this->insertData('bill_items',$itemRows);
            if(!is_null($data['employee_id'])) {
                 $this->insertData('employee_commission',$commissionRows);
            }


            // Tax details
            $taxRows=[];
            foreach($data['tax_details']??[] as $tax){
                $taxRows[]=[
                    'document_id'=>$documentId,
                    'item_name'=>$tax['item_name'],
                    'taxable_value'=>$tax['taxable_value'],
                    'cgst'=>$tax['cgst'],
                    'cgst_percent'=>$tax['cgst_percent'],
                    'sgst'=>$tax['sgst'],
                    'sgst_percent'=>$tax['sgst_percent'],
                    'total_gst'=>$tax['total_gst'],
                    'product_id'=>$tax['product_id']??null,
                    'service_id'=>$tax['service_id']??null,
                    'created_at'=>$now,'updated_at'=>$now
                ];
            }
            $this->insertData('tax_details',$taxRows);

            // Prescription
            if(!empty($data['prescription_detail'])){
                $this->insertData('prescription',[[
                    'document_id'=>$documentId,
                    'prescription'=>json_encode($data['prescription_detail']),
                    'is_deleted'=>0,
                    'created_at'=>$now,'updated_at'=>$now
                ]]);
            }

            DB::connection('tenant')->commit();

            return response()->json([
                'message'=>ucfirst($type).' created successfully.',
                'document_id'=>$documentId,
                'serial_number'=>$serial
            ]);
        }catch(\Exception $e){
            DB::connection('tenant')->rollBack();
            return response()->json([
                'message'=>'Failed to create '.$type,
                'error'=>$e->getMessage()
            ],500);
        }
    }

    private function ensureTable(string $table, \Closure $definition): void
    {
        $schema = Schema::connection('tenant');
        if(!$schema->hasTable($table)){
            $schema->create($table,$definition);
        }
    }

    private function insertData(string $table, array $rows): void
    {
        if(empty($rows)){
            return;
        }
        DB::connection('tenant')->table($table)->insert($rows);
    }

    private function ensureTablesExist(): void
    {
        $this->ensureTable('documents', function(Blueprint $table){
            $table->id();
            $table->string('type');
            $table->string('serial_number');
            $table->unsignedBigInteger('customer_id')->nullable();
            $table->unsignedBigInteger('employee_id')->nullable();
            $table->string('ref_invoice')->nullable();
            $table->string('ref_order_no', 100)->nullable();
            $table->text('description')->nullable();
            $table->decimal('total_amount',10,2)->default(0);
            $table->decimal('net_amount',10,2)->default(0);
            $table->decimal('pending_amount',10,2)->default(0);
            $table->decimal('discount',10,2)->default(0);
            $table->decimal('advance',10,2)->default(0);
            $table->timestamp('delivery_date')->nullable();
            $table->decimal('discount_precentage', 5, 2)->default(0);
            $table->string('payment_mode')->nullable();
            $table->string('discount_type')->nullable();
            $table->integer('total_items')->default(0);
            $table->integer('total_qty')->default(0);
            $table->decimal('total_gst',10,2)->default(0);
            $table->decimal('discount_amount',10,2)->default(0);
            $table->integer('created_by')->default(0);
            $table->integer('updated_by')->default(0);
            $table->timestamps();
        });

        $this->ensureTable('bill_items', function(Blueprint $table){
            $table->id();
            $table->unsignedBigInteger('document_id');
            $table->string('item_name');
            $table->integer('qty');
            $table->decimal('mrp',10,2);
            $table->decimal('offer',10,2);
            $table->decimal('amount',10,2);
            $table->decimal('total_amount',10,2);
            $table->decimal('employee_percentage',5,2)->nullable();
            $table->unsignedBigInteger('product_id')->nullable();
            $table->unsignedBigInteger('service_id')->nullable();
            $table->timestamps();
        });

        $this->ensureTable('tax_details', function(Blueprint $table){
            $table->id();
            $table->unsignedBigInteger('document_id');
            $table->string('item_name');
            $table->decimal('taxable_value',10,2);
            $table->decimal('cgst',10,2);
            $table->decimal('cgst_percent',5,2);
            $table->decimal('sgst',10,2);
            $table->decimal('sgst_percent',5,2);
            $table->decimal('total_gst',10,2);
            $table->unsignedBigInteger('product_id')->nullable();
            $table->unsignedBigInteger('service_id')->nullable();
            $table->timestamps();
        });

        $this->ensureTable('newattachments', function(Blueprint $table){
            $table->id();
            $table->unsignedBigInteger('document_id');
            $table->unsignedBigInteger('customer_id')->nullable();
            $table->string('path');
            $table->boolean('status')->default(true);
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
        });

        $this->ensureTable('prescription', function(Blueprint $table){
            $table->id();
            $table->unsignedBigInteger('document_id');
            $table->json('prescription')->nullable();
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
        });

        $this->ensureTable('employee_commission', function(Blueprint $table){
            $table->id();
            $table->unsignedBigInteger('employee_id');
            $table->unsignedBigInteger('doc_id');
            $table->json('product')->nullable();
            $table->json('service')->nullable();
            $table->decimal('total_amount',12,2)->default(0);
            $table->boolean('status')->default(true);
            $table->boolean('is_deleted')->default(false);
            $table->timestamps();
        });
    }

    private function generateSerial(string $type): string
    {
        $map=['invoice'=>'INV','order'=>'ORD','proposal'=>'PRO'];
        $prefix=$map[$type]??'DOC';
        $now=Carbon::now();
        $fy=Carbon::create($now->year,4,1);
        if($now->lt($fy)) $fy->subYear();
        $year=$fy->year; $month=str_pad($now->month,2,'0',STR_PAD_LEFT);
        $last=DB::connection('tenant')->table('documents')
                ->where('type',$type)
                ->where('created_at','>=',$fy)
                ->orderBy('id','desc')
                ->value('serial_number');
        if($last && preg_match('/(\d+)$/',$last,$m)){
            $num=str_pad((int)$m[1]+1,3,'0',STR_PAD_LEFT);
        }else{ $num='001'; }
        return "{$prefix}-{$year}-{$month}-{$num}";
    }

    public function getDocumentById(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
       // dd($user);
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        config(['database.connections.tenant.database' => $tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');

        if (!Schema::connection('tenant')->hasTable('documents')) {
            return response()->json(['message' => 'Documents table does not exist.'], 404);
        }

        $connection = DB::connection('tenant');
        $doc = $connection->table('documents')->where('id', $id)->first();
        if (!$doc) {
            return response()->json(['message' => 'Document not found.'], 404);
        }
        $sourceDocId = $doc->id;
        if (!empty($doc->ref_order_no)) {
            $refDoc = $connection->table('documents')
                ->where('serial_number', $doc->ref_order_no)
                ->first();

            if ($refDoc) {
                $sourceDocId = $refDoc->id;
            }
        }

        // Summary calculations
        $totalAmount = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('total_amount');
        $totalTax    = $connection->table('tax_details')->where('document_id', $sourceDocId)->sum('total_gst');
        $totalItems  = $connection->table('bill_items')->where('document_id', $sourceDocId)->count();
        $totalQty    = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('qty');

        $customer    = $connection->table('customers')->where('id', $doc->customer_id)->first();
        if ($doc->employee_id && Schema::connection('tenant')->hasTable('employees')) {
            $emp = $connection->table('employees')->where('id', $doc->employee_id)->first();
            $empId = $doc->employee_id;
            $empName = $emp?->full_name ?? 'NA';
        } else {
            $empId = 'NA';
            $empName = 'NA';
        }

        $pending     = $totalAmount - ($doc->advance ?? 0);
        $status      = match(true) {
            $pending <= 0 => 'Paid',
            $pending >= $totalAmount => 'Unpaid',
            default => 'Partial',
        };

        // Related collections
        $items       = $connection->table('bill_items')->where('document_id', $sourceDocId)->get();
        $taxDetails  = $connection->table('tax_details')->where('document_id', $sourceDocId)->get();
        $attachments = [];
        if (Schema::connection('tenant')->hasTable('newattachments')) {
            $attachments = $connection->table('newattachments')->where('document_id', $sourceDocId)->where('is_deleted',0)->get();
        }
        if (Schema::connection('tenant')->hasTable('prescription')) {
            $prescEntry  = $connection->table('prescription')->where('document_id', $sourceDocId)->first();
            $prescription= $prescEntry?->prescription ? json_decode($prescEntry->prescription, true) : null;
        }else {
            $prescription = null;
        }

        return response()->json([
            'data' => [
                'document' => [
                    'id' => $doc->id,
                    'type' => $doc->type,
                    'serial_number' => $doc->serial_number,
                  	'is_invoice_avl' => $connection->table('documents')
                      ->where('ref_order_no', $doc->serial_number)
                      ->exists(),
                    'customer_id' => $doc->customer_id,
                    'customer_name' => $customer?->name,
                    'customer_phone'=>$customer?->mobile,
                    'employee_id' => $empId,
                    'discount_amount'=>$doc->discount_amount,
                    'discount_type'=>$doc->discount_type,
                    'employee_name' => $empName,
                    'description' => $doc->description,
                    'discount' => $doc->discount,
                    'advance' => $doc->advance,
                    'discount_precentage'=> $doc->discount_precentage,
                    'delivery_date' => $doc->delivery_date,
                    'ref_invoice' => $doc->ref_invoice,
                    'total_amount' =>$doc-> total_amount,
                    'net_amount'=>$doc->net_amount,
                    'pending_amount' => $doc->pending_amount,
                    'payment_mode'=>$doc->payment_mode,
                    'total_gst' => $totalTax,
                    'total_items' => $totalItems,
                    'total_qty' => $totalQty,
                    'status' => $status,
                    'created_at' => $doc->created_at,
                    'updated_at' => $doc->updated_at,
                ],
                'items' => $items,
                'tax_details' => $taxDetails,
                'attachments' => $attachments,
                'prescription' => $prescription,
            ]
        ]);
    }

     public function generatePdf($id)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        config(['database.connections.tenant.database' => $tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');

        $connection = DB::connection('tenant');
        $document = $connection->table('documents')->where('id', $id)->first();

        if (!$document) {
            return response()->json(['message' => 'Document not found.'], 404);
        }

        // Check for ref_order_no and get correct document_id for related tables
        $sourceDocId = $document->id;
        if (!empty($document->ref_order_no)) {
            $refDoc = $connection->table('documents')
                ->where('serial_number', $document->ref_order_no)
                ->first();
            if ($refDoc) {
                $sourceDocId = $refDoc->id;
            }
        }

        $customer = $connection->table('customers')->where('id', $document->customer_id)->first();

        $employee = null;
        $empId = 'NA';
        $empName = 'NA';
        if (Schema::connection('tenant')->hasTable('employees') && $document->employee_id) {
            $employee = $connection->table('employees')->where('id', $document->employee_id)->first();
            $empId = $document->employee_id;
            $empName = $employee?->full_name ?? 'NA';
        }

        $billItems = $connection->table('bill_items')->where('document_id', $sourceDocId)->get();
        $taxDetails = $connection->table('tax_details')->where('document_id', $sourceDocId)->get();
        $attachments = [];
        if (Schema::connection('tenant')->hasTable('newattachments')) {
                $attachments = $connection->table('newattachments')->where('document_id', $sourceDocId)->where('is_deleted', 0)->get();
        }


        $prescription = null;
        if (Schema::connection('tenant')->hasTable('prescription')) {
            $presc = $connection->table('prescription')->where('document_id', $sourceDocId)->first();
            $prescription = $presc?->prescription ? json_decode($presc->prescription, true) : null;
        }

        // Summary Calculations
        $totalAmount = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('total_amount');
        $totalTax = $connection->table('tax_details')->where('document_id', $sourceDocId)->sum('total_gst');
        $totalItems = $connection->table('bill_items')->where('document_id', $sourceDocId)->count();
        $totalQty = $connection->table('bill_items')->where('document_id', $sourceDocId)->sum('qty');

        $pending = $totalAmount - ($document->advance ?? 0);
        $status = match (true) {
            $pending <= 0 => 'Paid',
            $pending >= $totalAmount => 'Unpaid',
            default => 'Partial',
        };

        // Pass everything to PDF view
        $pdf = Pdf::loadView('pdf.invoice', [
            'user' => $user,
            'document' => $document,
            'customer' => $customer,
            'employee' => $employee,
            'billItems' => $billItems,
            'taxDetails' => $taxDetails,
            'prescription' => $prescription,
            'attachments' => $attachments,
            'summary' => [
                'total_amount' => $totalAmount,
                'total_tax' => $totalTax,
                'total_items' => $totalItems,
                'total_qty' => $totalQty,
                'pending_amount' => $pending,
                'status' => $status,
            ]
        ]);

        return $pdf->stream('document_'.$document->serial_number.'.pdf');
    }

    public function updateDocumentById(Request $request, $id)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $validated = $request->validate([
            'pending_amount' => 'required|numeric|min:0',
        ]);

        $tenantSchema = $user->tenant_schema;
        config(['database.connections.tenant.database' => $tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');

        if (!Schema::connection('tenant')->hasTable('documents')) {
            return response()->json(['message' => 'Documents table does not exist.'], 404);
        }

        $connection = DB::connection('tenant');
        $doc = $connection->table('documents')->where('id', $id)->first();

        if (!$doc) {
            return response()->json(['message' => 'Document not found.'], 404);
        }

        $connection->table('documents')->where('id', $id)->update([
            'pending_amount' => $validated['pending_amount'],
            'updated_at' => now(),
        ]);

        return response()->json([
            'message' => 'Pending amount updated successfully.',
            'document_id' => $id,
            'pending_amount' => $validated['pending_amount'],
        ]);
    }


    public function employeeComission(Request $request)
    {
        $user = Auth::guard('api')->user();

        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        // Switch to tenant DB
        config(['database.connections.tenant.database' => $user->tenant_schema]);
        DB::setDefaultConnection('tenant');

        // Validation
        $request->validate([
            'employee_id' => 'required|integer'
        ]);

        // Get total commission for given employee_id
        $totalAmount = DB::table('employee_comission')
            ->where('employee_id', $request->employee_id)
            ->where('is_deleted', 0) // optional, if you want to skip deleted
            ->sum('total_amount');

        return response()->json([
            'message'      => 'Commission fetched successfully.',
            'employee_id'  => $request->employee_id,
            'total_amount' => $totalAmount
        ]);
    }



}








