<?php
namespace App\Http\Controllers;

use Yogeshgupta\PhonepeLaravel\Facades\PhonePe;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

class PhonePeController extends Controller
{
    /**
     * Initiate a PhonePe payment.
     *
     * @param Request $request
     * @return \Illuminate\Http\RedirectResponse
     */
    public function initiate(Request $request)
{
    // ✅ Validate only necessary fields
    $validator = Validator::make($request->all(), [
        'order_id' => 'required|string|max:255',
        'tenant_schema' => 'required|string',
        'package_id' => 'required|integer',
        'duration_id' => 'required|integer',
    ]);

    if ($validator->fails()) {
        Log::error('Payment initiation failed: Invalid request data', ['errors' => $validator->errors()]);
        return response()->json(['error' => $validator->errors()], 422);
    }

    $orderId = (string) $request->input('order_id');
    $durationId = (int) $request->input('duration_id');

    // ✅ Get amount & tax % from master DB
    $durationData = DB::connection('master_db')->table('tbl_package_duration_amount')->where('id', $durationId)->where('status', 1)->first();

    if (!$durationData) {
        Log::error("Duration not found for ID: $durationId");
        return response()->json(['error' => 'Invalid duration selected'], 400);
    }

    $baseAmount = (float) $durationData->amount; // base amount (e.g. 1000)
    $taxPercent = (float) $durationData->tax;    // tax percentage (e.g. 18)

    // ✅ Calculate tax & total amount
    $taxAmount = ($baseAmount * $taxPercent) / 100;
    $totalAmount = $baseAmount + $taxAmount;

    // ✅ Convert to paisa
    $amountInPaisa = (int) round($totalAmount * 100);

    // ✅ Prepare payload
    $payload = [
        'merchantOrderId' => $orderId,
        'amount' => $amountInPaisa, 
        'expireAfter' => 1200,
        'metaInfo' => [
            'udf1' => 'subscription_payment',
            'udf2' => 'sub_id_' . $orderId,
            'udf3' => 'student_checkout',
            'udf4' => '',
            'udf5' => '',
        ],
        'paymentFlow' => [
            'type' => 'PG_CHECKOUT',
            'message' => 'Payment for subscription ID: ' . $orderId,
            'merchantUrls' => [
                'callbackUrl' => env('PHONEPE_REDIRECT_URL'), 
            ],
        ],
    ];

    try {
        // ✅ Detect app type from header
        $appType = $request->header('X-App-Type');
        if ($appType === 'mobileApp') {
            $result = PhonePe::initiateMobilePayment($amountInPaisa, $orderId, $payload);
        } else {
            $result = PhonePe::initiatePayment($amountInPaisa, $orderId, $payload);
        }
      	
        if ($result['success']) {
          $existingTransaction = \App\Models\Transaction::where('transaction_id', $orderId)->first();

            if ($existingTransaction) {
                return response()->json([
                    'success' => false,
                    'message' => 'Order ID already exists',
                ], 200);
            }
            if(isset($result['data']['orderId'])){
				$OrderID = $result['data']['orderId'];
            }else{
              	$OrderID = $result['orderId'];
            }
            $PaymentStatus = 'PENDING';
          	if(isset($result['data']['state'])){
                $PaymentStatus = $result['data']['state'];
            }
            // ✅ Store record in DB
            \App\Models\Transaction::create([
                'transaction_id' => $orderId,
                'order_id' => $OrderID,
                'tenant_schema' => $request->tenant_schema,
                'name' => $request->name,
                'mobile_number' => $request->mobile_number,
                'package_id' => $request->package_id,
                'duration_id' => $durationId,
                'amount' => $amountInPaisa,
                'payment_status' => $PaymentStatus,
                'status' => 1,
                'payload' => $payload,
                'gateway_response' => $result,
            ]);

			return response()->json($result);
        }

        Log::error('Payment initiation failed', ['order_id' => $orderId, 'error' => $result['error']]);
        return response()->json(['error' => 'Payment initiation failed: ' . $result['error']]);

    } catch (\Exception $e) {
        Log::error('Unexpected error during payment initiation', [
            'order_id' => $orderId,
            'error' => $e->getMessage(),
        ]);
        return response()->json([
            'success' => false,
            'message' => 'Unexpected error: ' . $e->getMessage(),
        ], 500);
    }
}

  
    public function paymentCallback(Request $request)
    {
        Log::info('PhonePe Callback:', [$request->all()]);
        $username = env('PHONEPE_WEBHOOK_USER');
        $password = env('PHONEPE_WEBHOOK_PASS');
        $authHeader = $request->header('authorization'); // Not 'Authorization'
        if (!$authHeader) {
            \Log::error('Missing Authorization header');
            return response('Unauthorized', 401);
        }
        $expectedHash = hash('sha256', $username . ':' . $password);
        if (!hash_equals($expectedHash, $authHeader)) {
            \Log::error('Hash mismatch for webhook auth');
            return response('Unauthorized', 401);
        }
        // Now process as before...
       $data = $request->all();
   	 if (is_array($data)) {
        if ($this->isAssoc($data)) {
            // Associative array (single event)
            $event = $data;
        } else {
            // Numeric array (multiple events)
            $event = isset($data[0]) ? $data[0] : null;
        }
    } else {
        $event = null;
    }

    if ($event && isset($event['payload']['merchantOrderId'])) {
    
        $merchantOrderId = $event['payload']['merchantOrderId'];
        $paymentStatus = $event['payload']['state'] ?? 'UNKNOWN';
        $paymentDetails = $event['payload']['paymentDetails'][0] ?? null;
        $phonepeTransactionId = $paymentDetails['transactionId'] ?? null;

        $payment =  \App\Models\Transaction::where('transaction_id', $merchantOrderId)->first();

        if ($payment) {
            $payment->payment_status = $paymentStatus;
            $payment->phonepe_transaction_id = $phonepeTransactionId; 
            $payment->gateway_response = json_encode($data);

            $durationId = $payment->duration_id;
            $durationData = DB::connection('master_db')->table('tbl_package_duration_amount')->where('id', $durationId)->where('status', 1)->first();

            if ($durationData) {
                $payment->duration = $durationData->duration;
            } else {
                \Log::warning("Duration not found for duration_id: $durationId");
            }

            $payment->save();

            if ($paymentStatus == 'COMPLETED') {
                $this->assignModulesAfterPayment($payment->transaction_id);
            }
        } else {
            \Log::error("No payment record found for: $merchantOrderId");
        }

    } else {
        \Log::error('Invalid PhonePe webhook payload', ['data' => $data, 'event' => $event]);
        return response()->json(['error' => 'Invalid payload'], 400);
    }

        return response()->json(['res' => $request->all()]);
    }


  
 public function isAssoc(array $arr) {
    if ([] === $arr) return false;
    return array_keys($arr) !== range(0, count($arr) - 1);
}
  
public function assignModulesAfterPayment($merchantOrderId)
{
    // Always use master DB connection
    $masterDB = DB::connection('master_db');

    $payment = $masterDB->table('transaction_history')->where('transaction_id', $merchantOrderId)->first();

    if (!$payment) {
        \Log::error("assignModulesAfterPayment(): No transaction found for $merchantOrderId");
        return;
    }

    $tenantSchema = $payment->tenant_schema;
    $packageId = $payment->package_id;

    $package = $masterDB->table('tbl_package')->where('id', $packageId)->first();

    if (!$package) {
        \Log::error("Package not found for package_id: $packageId");
        return;
    }

    // Handle the JSON properly (clean)
    $cleanedJson = preg_replace('/\s+/', '', $package->modules);
    $moduleUIDs = json_decode($cleanedJson, true);

    if (empty($moduleUIDs)) {
        \Log::error("No modules found in package");
        return;
    }

    \Log::info("Decoded Modules", ['package_modules' => $package->modules, 'decoded' => $moduleUIDs]);

    foreach ($moduleUIDs as $uid) {
        $feature = $masterDB->table('tbl_feature')->where('uid', $uid)->first();

        if (!$feature) {
            \Log::error("Feature not found for UID: $uid");
            continue;
        }
		$moduleId = $feature->id;
		$exists = $masterDB->table('tbl_feat_access')
            ->where('tenant_schema', $tenantSchema)
            ->where('module_id', $moduleId)
            ->exists();

        if (!$exists) {
            $limitValue = null;

            if ($uid == 'MOD_LEADS') {
                $limitValue = 5;
            }

            $masterDB->table('tbl_feat_access')->insert([
                'module_id' => $moduleId,
                'tenant_schema' => $tenantSchema,
                'limit' => $limitValue,
                'status' => 1,
                'is_deleted' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    \Log::info("Module access assigned successfully for tenant: $tenantSchema");
}
  
    /**
     * Verify a PhonePe payment status.
     *
     * @param Request $request
     * @return \Illuminate\Http\JsonResponse
     */
    public function verify(Request $request)
    {
        // Validate request data
        $validator = Validator::make($request->all(), [
            'merchantOrderId' => 'required|string|min:1|max:255',
        ]);

        if ($validator->fails()) {
            Log::error('Payment verification failed: Invalid merchantOrderId', [
                'errors' => $validator->errors()->toArray(),
                'request' => $request->all(),
            ]);
            return response()->json([
                'error' => 'Invalid merchantOrderId',
                'details' => $validator->errors()->toArray(),
            ], 400);
        }

        $merchantOrderId = $request->input('merchantOrderId');

        try {
            $result = PhonePe::verifyPhonePePayment($merchantOrderId);
			if ($result['success']) {
            
              	$merchantOrderId = $merchantOrderId;
                $paymentStatus = $result['data']['state'] ?? 'UNKNOWN';
                $paymentDetails = $result['payload']['paymentDetails'] ?? null;
                $phonepeTransactionId = $paymentDetails[0]['transactionId'] ?? null;

            	$payment =  \App\Models\Transaction::where('transaction_id', $merchantOrderId)->first();

            if ($payment) {
                $payment->payment_status = $paymentStatus;
                $payment->phonepe_transaction_id = $phonepeTransactionId; 
                $payment->gateway_response = json_encode($result);

                $durationId = $payment->duration_id;
                $durationData = DB::connection('master_db')->table('tbl_package_duration_amount')->where('id', $durationId)->where('status', 1)->first();

                if ($durationData) {
                    $payment->duration = $durationData->duration;
                } else {
                    \Log::warning("Duration not found for duration_id: $durationId");
                }

                $payment->save();

                if ($paymentStatus == 'COMPLETED') {
                    $this->assignModulesAfterPayment($payment->transaction_id);
                }
              } else {
                  \Log::error("No payment record found for: $merchantOrderId");
              }
              return response()->json($result['data']);
            }

            Log::error('Payment verification failed', [
                'merchantOrderId' => $merchantOrderId,
                'error' => $result['error'],
            ]);
            return response()->json([
                'error' => 'Payment verification failed',
                'details' => $result['error'],
            ], 400);
        } catch (\Exception $e) {
            Log::error('Unexpected error during payment verification', [
                'merchantOrderId' => $merchantOrderId,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'error' => 'An unexpected error occurred',
                'details' => $e->getMessage(),
            ], 500);
        }
    }
}








