<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Tenant;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Tymon\JWTAuth\Facades\JWTAuth;
use App\Models\BusinessCategory; 
use App\Models\Service; 
use App\Models\Country; 
use App\Models\State; 
use App\Models\City; 
use App\Services\DatabaseService;
use App\Helpers\QueryHelper;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;
use App\Jobs\SendPushNotification;
/**
 * @OA\Info(
 *      version="1.0.0",
 *      title="Waqin Api Documentation",
 *      description="API documentation for Waqin project",
 * )
 *
 * @OA\Tag(
 *     name="Tenants",
 *     description="API Endpoints for Tenants"
 * )
 */
class AuthController extends Controller
{
    protected $dbService;

    public function __construct(DatabaseService $dbService)
    {
        $this->dbService = $dbService;
    }
/**
 * @OA\Post(
 *      path="/api/register",
 *      operationId="registerUser",
 *      tags={"Authentication"},
 *      summary="Register a new user",
 *      description="Registers a new user and sends an OTP for verification.",
 *      @OA\RequestBody(
 *          required=true,
 *          @OA\JsonContent(
 *              required={"first_name", "device_id", "mobile"},
 *              @OA\Property(property="first_name", type="string", example="John"),
 *              @OA\Property(property="last_name", type="string", example="Doe"),
 *              @OA\Property(property="device_id", type="string", example="abc123xyz"),
 *              @OA\Property(property="mobile", type="string", example="+1234567890"),
 *              @OA\Property(property="refferal_code", type="string", example="REF123", nullable=true),
 *              @OA\Property(property="fcm_token", type="string", maxLength=255)
 *          )
 *      ),
 *      @OA\Response(
 *          response=201,
 *          description="Registration successful. Please verify OTP.",
 *          @OA\JsonContent(
 *              @OA\Property(property="status", type="string", example="Success"),
 *              @OA\Property(property="message", type="string", example="Registration successful. Please verify OTP."),
 *              @OA\Property(property="user", type="object",
 *                  @OA\Property(property="id", type="integer", example=1),
 *                  @OA\Property(property="first_name", type="string", example="John"),
 *                  @OA\Property(property="last_name", type="string", example="Doe"),
 *                  @OA\Property(property="mobile", type="string", example="+1234567890"),
 *                  @OA\Property(property="tenant_schema", type="string", example="tenant_1"),
 *                  @OA\Property(property="mobile_verify", type="integer", example=0)
 *              ),
 *              @OA\Property(property="token", type="string", example="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
 *          )
 *      ),
 *      @OA\Response(
 *          response=400,
 *          description="Validation failed or mobile number already registered",
 *          @OA\JsonContent(
 *              @OA\Property(property="message", type="string", example="Mobile number already registered."),
 *              @OA\Property(property="mobile_verify", type="integer", example=0)
 *          )
 *      ),
 *      @OA\Response(
 *          response=500,
 *          description="Database creation failed",
 *          @OA\JsonContent(
 *              @OA\Property(property="error", type="string", example="Database creation failed: error message")
 *          )
 *      )
 * )
 */
    public function register(Request $request)
{
    // Validate the request without the unique rule for mobile
    $validator = Validator::make($request->all(), [
        'first_name' => 'required|string|max:255',
        'last_name' => 'nullable|string|max:255',
        'device_id' => 'required|string|max:255',
        'mobile' => 'required|regex:/^\+?[0-9]{10}$/',
        'refferal_code' => 'required|string|max:255',
    ]);

    if ($validator->fails()) {
        return response()->json($validator->errors(), 400);
    }

    // Check if the mobile number is already registered
    $existingUser = Tenant::where('mobile', $request->mobile)->first();
    if ($existingUser) {
        if ($existingUser->mobile_verify == 0) {
            return response()->json([
                'message' => 'Mobile number already registered. Please verify OTP.',
                'mobile_verify' => $existingUser->mobile_verify
            ], 400);
        } else {
            return response()->json([
                'message' => 'Mobile number already registered.',
                'mobile_verify' => $existingUser->mobile_verify
            ], 400);
        }
    }
    $RefferalCheck = DB::table('referrals')->where('referral_code', $request->refferal_code)
                                            ->where('cust_mobile', $request->mobile)
                                            ->where('status', 1)
                                            ->first();
    if (!$RefferalCheck) {
        return response()->json(['message' => 'Invalid referral code'], 400);
    }


    try {
        $otp = sprintf('%04d', rand(0, 9999));
        $user = Tenant::create([
            'first_name' => $request->first_name,
            'last_name' => $request->last_name,
            'device_id' => $request->device_id,
            'mobile' => $request->mobile,
            'refferal_code' => $request->refferal_code,
            'otp' => $otp,
            'tenant_schema' => null, 
            'mobile_verify' => 0,
            'fcm_token' => $request->fcm_token,
            'cp_id' => $RefferalCheck->partner_id,
        ]);

        // $databaseName = 'tenant_' . $user->id;
        $databaseName = env('DB_TENANT') . $user->id;
        // Update tenant table with schema name
        $user->tenant_schema = $databaseName;
        $user->save();

        $this->dbService->createDatabase($databaseName);
    } catch (\Exception $e) {
        return response()->json(['error' => 'Database creation failed: ' . $e->getMessage()], 500);
    }

    $token = JWTAuth::fromUser($user);

    return response()->json([
        'status' => 'Success',
        'message' => 'Registration successful. Please verify OTP.',
        'user' => $user,
        'token' => $token,
        'mobile_verify' => $user->mobile_verify
    ], 201);
}

/**
 * @OA\Post(
 *     path="/api/verify-otp",
 *     summary="Verify OTP",
 *     description="Verifies OTP for a tenant. If successful, it marks the mobile as verified and generates a JWT token.",
 *     tags={"Authentication"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"mobile", "otp"},
 *             @OA\Property(property="mobile", type="string", example="+911234567890"),
 *             @OA\Property(property="otp", type="string", example="1234")
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="OTP VERIFIED",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="OTP VERIFIED"),
 *             @OA\Property(property="token", type="string", example="jwt_token_here"),
 *             @OA\Property(property="user", type="object",
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="first_name", type="string", example="John"),
 *                 @OA\Property(property="last_name", type="string", example="Doe"),
 *                 @OA\Property(property="mobile", type="string", example="+911234567890"),
 *                 @OA\Property(property="user_type", type="string", example="tenant")
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Invalid OTP",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Invalid OTP")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tenant not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant not found")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unable to generate token",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Unable to generate token")
 *         )
 *     )
 * )
 */

public function VerifyOtp(Request $request)
{
    $mobile = $request->input('mobile');
    $mobileVerify = $request->input('mobile_verify');
    $fcm_token = $request->input('fcm_token');
    
    
    $tenant = Tenant::where('mobile', $mobile)->first();
    
    if ($tenant) {

        if ($mobileVerify) {
            // Update the mobile_verify column to 1
            $tenant->mobile_verify = 1;
            $tenant->fcm_token = $fcm_token;
            $tenant->save();

            if ($fcm_token) {
                dispatch(new SendPushNotification(
                    [$tenant->fcm_token],
                    'Welcome to WAQIN!',
                    'Thanks for verifying your mobile number. We’re glad to have you onboard.',
                    '', // optional image
                    ['route' => '/dashboard']
                ));
            }
            // Generate JWT token for the tenant
            if (!$token = Auth::guard('tenant')->login($tenant)) {
                return response()->json(['message' => 'Unable to generate token'], 500);
            }
          try{
            QueryHelper::initializeConnection($tenant->tenant_schema);
            DB::unprepared(QueryHelper::createGetCustomerList());
          
            DB::unprepared(QueryHelper::createGetLeadsList());
          
            DB::unprepared(QueryHelper::createGetScheduleList());
           
            DB::unprepared(QueryHelper::createGetFollowUpList());

            DB::unprepared(QueryHelper::createGetMostLiklyList());
                                             
            DB::unprepared(QueryHelper::createStatusNotUpdated());
          } catch (\Exception $e) {
            Log::error($e);
          };
          
            $res = [
                'message' => "OTP VERIFIED",
                'token' => $token,
                'user' => [
                    'id' => $tenant->id,
                    'first_name' => $tenant->first_name,
                    'last_name' => $tenant->last_name,
                    'mobile' => $tenant->mobile,
                    'user_type' => $tenant->user_type,
                ]
            ];

            return response()->json($res, 201);
        } else {
            return response()->json(['message' => 'Invalid OTP'], 400);
        }
    } else {
        return response()->json(['message' => 'Tenant not found'], 200);
    }
}
/**
 * @OA\Post(
 *     path="/api/send-otp",
 *     summary="Send OTP to registered mobile number",
 *     tags={"Authentication"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"mobile"},
 *             @OA\Property(property="mobile", type="string", example="+911234567890", description="Registered mobile number")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="OTP sent successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="otp", type="string", example="1234"),
 *             @OA\Property(property="message", type="string", example="OTP sent successfully")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Mobile number not registered",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Mobile number not registered")
 *         )
 *     )
 * )
 */
public function SendOtp(Request $request)
{
    $request->validate([
        'mobile' => 'required'
    ]);

    $mobile = $request->mobile;
    $tenant = Tenant::where('mobile', $mobile)->first();

    if (!$tenant) {
        return response()->json(['error' => 'Mobile number not registered'], 200);
    }

    $otp = str_pad(rand(0, 9999), 4, '0', STR_PAD_LEFT);

    $tenant->otp = $otp;
    $tenant->save();

    return response()->json([
        'otp' => $otp, 
        'message' => 'OTP sent successfully'
    ], 200);
}

    
//     public function SendOtp(Request $request){
//         $mobile = $request->mobile;
//         $otp = rand(0001,9999);
//         $result = Tenant::where('mobile', $mobile)->first('otp');
//         print_r($result->otp);
//         echo "<br>";
//                 print_r($otp);
// die();
//         return 'jittu';

//     }

// public function loginwith(Request $request)
// {
//     // $credentials = $request->only('email', 'password');

//     $user = User::where('email', $request->email)->orWhere('mobile', $request->mobile)->first();

//     if (!$user || !Hash::check($request->password, $user->password)) {
//         return response()->json(['error' => 'Unauthorized'], 401);
//     }

//     if (!$token = Auth::guard('api')->login($user)) {
//         return response()->json(['error' => 'Unauthorized'], 401);
//     }

//     return $this->respondWithToken($token);
// }

/**
 * @OA\Post(
 *     path="/api/check-mobile",
 *     summary="Check if mobile number is registered",
 *     tags={"Authentication"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"mobile"},
 *             @OA\Property(property="mobile", type="string", example="+911234567890", description="Mobile number to check")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Mobile number is registered",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="success"),
 *             @OA\Property(property="message", type="string", example="Mobile number is registered"),
 *             @OA\Property(property="mobile_verify", type="integer", example=1, description="Mobile verification status"),
 *             @OA\Property(property="is_employee", type="integer", example=1, description="Whether the user is an employee (1 = Yes, 0 = No)"),
 *             @OA\Property(property="password", type="integer", example=1, description="Whether the user has set a password (1 = Yes, 0 = No)")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Invalid request data",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="errors", type="object", description="Validation errors")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Mobile number not registered",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="message", type="string", example="Mobile number not registered")
 *         )
 *     )
 * )
 */
public function checkMobile(Request $request) 
{
    // Validate the mobile number input
    $validator = Validator::make($request->all(), [
        'mobile' => 'required|regex:/^\+?[0-9]{10}$/',
    ]);

    if ($validator->fails()) {
        return response()->json(['status' => 'failed', 'errors' => $validator->errors()], 400);
    }

    // Retrieve the mobile number from the request
    $mobile = $request->input('mobile');

    // Check if the mobile number exists in the database
    $user = Tenant::where('mobile', $mobile)->first();

    if (!$user) {
        return response()->json(['status' => 'failed', 'message' => 'Mobile number not registered'], 200);
    }

    // Determine is_employee based on user_type
    $is_employee = ($user->user_type === 'Business user') ? 1 : 0;
    $employee_user_type = $user->user_type;
    $password = !is_null($user->password) ? 1 : 0;

    // Mobile number exists, return success response with mobile_verify and is_employee
    return response()->json([
        'status' => 'success',
        'message' => 'Mobile number is registered',
        'mobile_verify' => $user->mobile_verify,
        'is_employee' => $is_employee,
        'employee_user_type' => $employee_user_type,
        'password' => $password,
    ]);
}
/**
 * @OA\Post(
 *     path="/api/login",
 *     summary="User login with mobile and password",
 *     tags={"Authentication"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"mobile", "password"},
 *             @OA\Property(property="mobile", type="string", example="+911234567890", description="User's registered mobile number"),
 *             @OA\Property(property="password", type="string", example="123456", description="User's login password")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Successful login",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="success"),
 *             @OA\Property(property="access_token", type="string", example="eyJhbGciOiJIUzI1N..."),
 *             @OA\Property(property="token_type", type="string", example="bearer"),
 *             @OA\Property(property="expires_in", type="integer", example=3600),
 *             @OA\Property(property="mobile_verify", type="integer", example=1, description="Mobile verification status"),
 *             @OA\Property(property="user_type", type="string", example="Operational user", description="User type")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="errors", type="object", description="Validation errors")
 *         )
 *     ),
 *     @OA\Response(
 *         response=401,
 *         description="Incorrect password",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="message", type="string", example="Incorrect PIN")
 *         )
 *     ),
 *     @OA\Response(
 *         response=403,
 *         description="OTP not verified or password not set",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="message", type="string", example="OTP not verified. Please verify your mobile number."),
 *             @OA\Property(property="mobile_verify", type="integer", example=0)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Mobile number not registered",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="message", type="string", example="Mobile number not registered")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Token generation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failed"),
 *             @OA\Property(property="message", type="string", example="Could not generate token")
 *         )
 *     )
 * )
 */  
public function login(Request $request)
{
    // Validate the request
    $validator = Validator::make($request->all(), [
        'mobile' => 'required|regex:/^\+?[0-9]{10}$/',
        'password' => 'required|string',
    ]);

    if ($validator->fails()) {
        return response()->json(['status' => 'failed', 'errors' => $validator->errors()], 400);
    }

    // Extract mobile and password
    $mobile = $request->mobile;
    $password = $request->password;
    $fcmToken = $request->fcm_token;

    // Check if the mobile number exists
    $user = Tenant::where('mobile', $mobile)->first();

    if (!$user) {
        return response()->json(['status' => 'failed', 'message' => 'Mobile number not registered'], 200);
    }

    // Check if the password column is null
    if (is_null($user->password)) {
        return response()->json(['status' => 'failed', 'message' => 'Password not set. Please reset your password.'], 403);
    }

    // Check if the password matches
    if (!Hash::check($password, $user->password)) {
        return response()->json(['status' => 'failed', 'message' => 'Incorrect PIN'], 401);
    }

    // Check if the mobile number has been verified
    if (!$user->mobile_verify) {
        return response()->json(['status' => 'failed', 'message' => 'OTP not verified. Please verify your mobile number.', 'mobile_verify' => $user->mobile_verify], 403);
    }

    $user->update(['fcm_token' => $fcmToken]);

    // Generate a token
    $credentials = ['mobile' => $mobile, 'password' => $password];
    if (!$token = Auth::guard('api')->attempt($credentials)) {
        return response()->json(['status' => 'failed', 'message' => 'Could not generate token'], 500);
    }

    // Prepare the response with the token
    $tokenResponse = $this->respondWithToken($token)->getData(true);
    $tokenResponse['status'] = 'success';
    $tokenResponse['mobile_verify'] = $user->mobile_verify;
    $tokenResponse['user_type'] = $user->user_type;

    // Return the token response
    return response()->json($tokenResponse);
}
/**
 * @OA\Get(
 *     path="/api/me",
 *     summary="Get authenticated user details",
 *     tags={"Authentication"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Response(
 *         response=200,
 *         description="Authenticated user details",
 *         @OA\JsonContent(
 *             @OA\Property(property="id", type="integer", example=1),
 *             @OA\Property(property="name", type="string", example="John Doe"),
 *             @OA\Property(property="email", type="string", example="john@example.com"),
 *             @OA\Property(property="mobile", type="string", example="+911234567890"),
 *             @OA\Property(property="business_id", type="integer", example=2),
 *             @OA\Property(property="business_name", type="string", example="Retail Store"),
 *             @OA\Property(property="sub_category_id", type="integer", example=5),
 *             @OA\Property(property="sub_category_name", type="string", example="Grocery"),
 *             @OA\Property(property="user_type", type="string", example="Operational user")
 *         )
 *     ),
 *     @OA\Response(
 *         response=401,
 *         description="User not authenticated",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="User not authenticated")
 *         )
 *     )
 * )
 */
public function me()
{
    // Get the authenticated user
    $user = Auth::guard('api')->user();

    if (!$user) {
        return response()->json(['message' => 'User not authenticated'], 401);
    }

    $businessName = DB::table('business_categories')
        ->where('id', $user->business_id)
        ->value('name');

    $subCategoryName = DB::table('business_sub_categories')
        ->where('id', $user->sub_category_id)
        ->value('sub_category_name');

    // Initialize empId
    $empId = null;

    // Fetch the tenant schema from master DB (assuming tenant schema is stored in 'tenants' table)
    $tenantSchema = DB::table('tenants')
        ->where('id', $user->id)
        ->value('tenant_schema');

    $paymentStatus = DB::table('transaction_history')
        ->where('tenant_schema', $tenantSchema)  // filter by tenant_schema
        ->orderBy('id', 'desc')
        ->value('payment_status','transaction_id'); 
    if ($tenantSchema) {
        // Switch to tenant database
        QueryHelper::initializeConnection($tenantSchema);

        if (Schema::connection('tenant')->hasTable('employees')) {
            $empId = DB::connection('tenant')->table('employees')
                ->where('mobile', $user->mobile)
                ->value('id');
        }
    }

    // Convert the user's data to an array
    $userData = $user->toArray();

    // Reorder data while maintaining structure
    $reorderedData = [];
    foreach ($userData as $key => $value) {
        $reorderedData[$key] = $value;

        if ($key === 'user_type' && $empId) {
            $reorderedData['emp_id'] = $empId;
        }

        if ($key === 'business_id') {
            $reorderedData['business_name'] = $businessName;
        }

        if ($key === 'sub_category_id') {
            $reorderedData['sub_category_name'] = $subCategoryName;
        }
    }

    $reorderedData['payment_status'] = $paymentStatus->payment_status?? 'NOT_FOUND';
    $reorderedData['transaction_id'] = $paymentStatus->transaction_id?? 'NOT_FOUND';


    return response()->json($reorderedData);
}
/**
 * @OA\Post(
 *     path="/api/logout",
 *     summary="Logout the authenticated user",
 *     tags={"Authentication"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Response(
 *         response=200,
 *         description="Successfully logged out",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Successfully logged out")
 *         )
 *     )
 * )
 */
    public function logout()
    {
        $user = Auth::guard('api')->user(); // Get the authenticated user

        if ($user) { 
            $user->update(['fcm_token' => null]); // Clear FCM token only if the user is authenticated
        }
        Auth::guard('api')->logout();

        return response()->json(['message' => 'Successfully logged out']);
    }
/**
 * @OA\Post(
 *     path="/api/refresh",
 *     summary="Refresh authentication token",
 *     tags={"Authentication"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Response(
 *         response=200,
 *         description="Token refreshed successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="access_token", type="string", example="newly_generated_token"),
 *             @OA\Property(property="token_type", type="string", example="bearer"),
 *             @OA\Property(property="expires_in", type="integer", example=3600)
 *         )
 *     )
 * )
 */
    public function refresh()
    {
        return $this->respondWithToken(Auth::guard('api')->refresh());
    }

    protected function respondWithToken($token)
    {
        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60
        ]);
    }
  
}





