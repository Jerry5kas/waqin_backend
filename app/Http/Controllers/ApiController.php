<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\TableCreationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use App\Models\Tenant;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Str;
use App\Models\QueryBuilder;
use App\Helpers\QueryHelper;
use Illuminate\Database\QueryException; // For catching query errors

use timgws\QueryBuilderParser;
use App\Models\Marketing;
use App\Helpers\FormHelper;
use App\Helpers\DataHelper;
use Carbon\Carbon;
use PhpOffice\PhpSpreadsheet\IOFactory;
// use Illuminate\Support\Facades\Redis;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Support\Facades\Http;
use App\Helpers\InvoiceHelper;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\File;
use ZipArchive;

class ApiController extends Controller
{
    protected $tableCreationService;

    /**
     * Constructor with dependency injection for services and helpers.
     *
     * @param TableCreationService $tableCreationService
     * @param string $schemaName
     */
 public function __construct(TableCreationService $tableCreationService)
{
        // Initialize services and helpers
        $this->tableCreationService = $tableCreationService;
     
    }
/**
     * @OA\Post(
     *     path="/api/import-customers",
     *     summary="Import customers for a specific tenant",
     *     tags={"Tenants"},
     *     security={{ "bearerAuth": {} }},
     *     @OA\RequestBody(
     *         required=true,
     *         @OA\JsonContent(
     *             required={"tenant_schema", "customers"},
     *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
     *             @OA\Property(
     *                 property="customers",
     *                 type="array",
     *                 @OA\Items(
     *                     @OA\Property(property="phone_account_id", type="string", example="12345"),
     *                     @OA\Property(property="name", type="string", example="John Doe"),
     *                     @OA\Property(property="email", type="string", example="john.com"),
     *                     @OA\Property(property="mobile", type="string", example="9876543210"),
     *                     @OA\Property(property="type", type="string", example="Regular"),
     *                     @OA\Property(property="another_mobile", type="string", example="9876543211"),
     *                     @OA\Property(property="company", type="string", example="XYZ Pvt Ltd"),
     *                     @OA\Property(property="gst", type="string", example="22AAAAA0000A1Z5"),
     *                     @OA\Property(property="profile_pic", type="string", example="profile.jpg"),
     *                     @OA\Property(property="location", type="string", example="New York"),
     *                     @OA\Property(property="group", type="string", example="Premium"),
     *                     @OA\Property(property="dob", type="string", format="date", example="1990-01-01"),
     *                     @OA\Property(property="anniversary", type="string", format="date", example="2015-06-15"),
     *                     @OA\Property(property="status", type="integer", example=1),
     *                     @OA\Property(property="contact_status", type="string", example="Active")
     *                 )
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Customers imported successfully",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Customers imported successfully.")
     *         )
     *     ),
     *     @OA\Response(
     *         response=500,
     *         description="Failed to create customers table",
     *         @OA\JsonContent(
     *             @OA\Property(property="message", type="string", example="Failed to create customers table.")
     *         )
     *     )
     * )
     */
    public function importCustomers(Request $request)
    {
        $tenantSchema = $request->input('tenant_schema');
        if (!$tenantSchema) {
            return response()->json(['message' => 'tenant_schema is required'], 422);
        }
    
        $customers = $request->input('customers');
        $empId = $request->filled('emp_id') ? $request->input('emp_id') : null;
    
        // Switch to tenant DB
        QueryHelper::initializeConnection($tenantSchema);
        DB::setDefaultConnection('tenant');
    
        // Table and columns
        $customerTable = 'customers';
        $empContactsTable = 'emp_contacts';
    
        $columns = [
            'id' => 'INT UNSIGNED AUTO_INCREMENT PRIMARY KEY',
            'emp_id' => 'BIGINT DEFAULT NULL',
            'phone_account_id' => 'VARCHAR(50) NULL',
            'name' => 'VARCHAR(255) NOT NULL',
            'email' => 'VARCHAR(255) NULL',
            'mobile' => 'VARCHAR(100) NOT NULL',
            'type' => 'VARCHAR(100) NULL',
            'source' => 'VARCHAR(100) NULL',
            'another_mobile' => 'VARCHAR(100) NULL',
            'company' => 'VARCHAR(255) NULL',
            'gst' => 'VARCHAR(100) NULL',
            'profile_pic' => 'VARCHAR(100) NULL',
            'location' => 'VARCHAR(255) NULL',
            'group' => 'VARCHAR(255) NULL',
            'dob' => 'VARCHAR(255) NULL',
            'anniversary' => 'VARCHAR(255) NULL',
            'created_by' => 'BIGINT DEFAULT NULL',
            'status' => 'INT(11) DEFAULT 1',
            'contact_status' => 'VARCHAR(255) NULL',
            'created_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP',
            'updated_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
            'is_deleted' => 'INT(11) DEFAULT 0',
        ];
    
        // Create customers table if not exists
        $this->tableCreationService->createTable($tenantSchema, $customerTable, $columns);
    
        // Create emp_contacts table only if emp_id is present
        if ($empId) {
            $this->tableCreationService->createTable($tenantSchema, $empContactsTable, $columns);
        }
    
        // Remove duplicate mobiles from payload
        $uniqueCustomers = collect($customers)->unique('mobile')->values();
    
        // Get existing mobiles in customers table
        $existingMobiles = DB::table($customerTable)
            ->whereIn('mobile', $uniqueCustomers->pluck('mobile'))
            ->pluck('mobile')
            ->toArray();
    
        // New customers to insert into customers table
        $filteredCustomers = $uniqueCustomers->reject(function ($customer) use ($existingMobiles) {
            return in_array($customer['mobile'], $existingMobiles);
        })->toArray();
    
        if (!empty($filteredCustomers)) {
            foreach ($filteredCustomers as &$customer) {
                if ($empId) {
                    $customer['created_by'] = $empId;
                }
            }
            DB::table($customerTable)->insert($filteredCustomers);
        }
    
        // Insert into emp_contacts if emp_id exists
        if ($empId) {
            $duplicateCustomers = $uniqueCustomers->filter(function ($customer) use ($existingMobiles) {
                return in_array($customer['mobile'], $existingMobiles);
            })->values();
    
            // Avoid inserting (mobile + created_by) duplicates in emp_contacts
            $existingEmpMobiles = DB::table($empContactsTable)
                ->where('created_by', $empId)
                ->whereIn('mobile', $duplicateCustomers->pluck('mobile'))
                ->pluck('mobile')
                ->toArray();
    
            $empContactsToInsert = $duplicateCustomers->reject(function ($customer) use ($existingEmpMobiles) {
                return in_array($customer['mobile'], $existingEmpMobiles);
            })->toArray();
    
            if (!empty($empContactsToInsert)) {
                foreach ($empContactsToInsert as &$contact) {
                    $contact['created_by'] = $empId;
                }
                DB::table($empContactsTable)->insert($empContactsToInsert);
            }
        }
    
        return response()->json(['message' => 'Customers imported successfully.'], 200);
    }
/**
 * @OA\Post(
 *     path="/api/updateProfile",
 *     summary="Update tenant profile",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"email"},
 *             @OA\Property(property="email", type="string", format="email", example="user@example.com"),
 *             @OA\Property(property="password", type="string", format="password", example="newpassword123"),
 *             @OA\Property(property="image", type="string", format="binary", description="Profile picture"),
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Profile updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Profile updated successfully."),
 *             @OA\Property(
 *                 property="sub_categories",
 *                 type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="sub_category_name", type="string", example="Retail")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Email already exists",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="The email address is already in use.")
 *         )
 *     )
 * )
 */    
public function updateProfile(Request $request)
{
    $user = Auth::user();
    $tenantId = $user->id; // Retrieve tenant ID from authenticated user

    $data = $request->all();

    // Check if the email exists in the tenants table (excluding the current user's email)
    if (isset($data['email'])) {
        $emailExists = DB::table('tenants')
            ->where('email', $data['email'])
            ->where('id', '!=', $tenantId) 
            ->exists();

        if ($emailExists) {
            return response()->json([
                'success' => false,
                'message' => 'The email address is already in use.',
            ], 400);
        }
    }

    // Hash password if it's present in the request
    if (isset($data['password'])) {
        $data['password'] = Hash::make($data['password']);
    }

    // Handle image upload and save in tenant-specific directory if image is provided
    if ($request->hasFile('image')) {
        $path = env('DB_TENANT') . "{$tenantId}/profile"; // Define path with tenant ID and 'profile' folder
        $logo = $request->file('image')->store($path, 'public'); // Store in public disk with custom path
        $data['image'] = $logo; // Save the path to the data array
    }

    // Update user profile with the new data
    $user->update($data);

    $businessId = DB::table('tenants')->where('id', $tenantId)->value('business_id');

    $subCategories = DB::table('business_sub_categories')
        ->where('business_id', $businessId)
        ->select('id', 'sub_category_name')
        ->get();

    return response()->json([
        'success' => true,
        'message' => 'Profile updated successfully.',
        'sub categories' => $subCategories,
    ], 200);
}
/**
 * @OA\Post(
 *     path="/api/update-customer",
 *     summary="Update a customer's details",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\MediaType(
 *             mediaType="multipart/form-data",
 *             @OA\Schema(
 *                 required={"tenant_schema", "id"},
 *                 @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="name", type="string", maxLength=255, example="John Doe"),
 *                 @OA\Property(property="email", type="string", format="email", maxLength=255, example="john@example.com"),
 *                 @OA\Property(property="address", type="string", example="123 Main Street"),
 *                 @OA\Property(property="profile_pic", type="string", format="binary", description="Customer profile picture (JPEG, PNG, GIF, SVG)"),
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Customer updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Customer updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="No data provided for update",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="No data provided for update.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Customer not found or no changes detected",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="No customer found with the provided ID, or no changes detected.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=422,
 *         description="Validation errors",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="object", example={"email": {"The email must be a valid email address."}})
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Error message here")
 *         )
 *     )
 * )
 */
public function updateCustomer(Request $request)
{
    // Validate incoming data
    $validator = Validator::make($request->all(), [
        'tenant_schema' => 'required|string',
        'id' => 'required|integer',
        'profile_pic' => 'nullable|image|mimes:jpeg,png,jpg,gif,svg|max:2048', // Validate the profile picture
        'name' => 'nullable|string|max:255',
        'email' => 'nullable|email|max:255',
        'address' => 'nullable|string',
    ]);

    if ($validator->fails()) {
        return response()->json(['error' => $validator->errors()], 422);
    }

    // Get the tenant schema name and mobile number
    $tenantSchema = $request->input('tenant_schema');
     $id = $request->input('id');

    // Configure the tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Get the data to update, excluding tenant_schema, mobile, and profile_pic
    $updateData = $request->except(['tenant_schema', 'id', 'profile_pic']);

    // Handle the profile picture upload
    if ($request->hasFile('profile_pic')) {
        $file = $request->file('profile_pic');
        $tenantFolder = "{$tenantSchema}/customers"; // Folder structure

        // Store the file in the tenant's folder, creating directories as needed
        $filePath = $file->store($tenantFolder, 'public');
        $updateData['profile_pic'] = $filePath; // Save the file path in the update data
    }

    if (empty($updateData)) {
        return response()->json([
            'success' => true,
            'message' => 'No data provided for update.'
        ], 200);
    }

    try {
        // Update the customer record
        $updated = DB::table('customers')
            ->where('id', $id)
            ->update($updateData);

        // Check if any rows were affected
        if ($updated) {
            return response()->json([
                'success' => true,
                'message' => 'Customer updated successfully.',
            ]);
        } else {
            return response()->json([
                'success' => true,
                'message' => 'No customer found with the provided mobile number, or no changes detected.'
            ], 200);
        }
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => $e->getMessage()
        ], 500);
    }
}

protected function getCustomerId($number)
{
    return DB::table('customers')
        ->where('mobile', $number)
        ->value('id'); // Directly returns the ID or null
}
/**
 * @OA\Post(
 *     path="/api/import-callhistory",
 *     summary="Import call history for a tenant",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "call_history"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(
 *                 property="call_history",
 *                 type="array",
 *                 @OA\Items(
 *                     type="object",
 *                     required={"number", "call_type", "duration", "timestamp"},
 *                     @OA\Property(property="name", type="string", example="John Doe"),
 *                     @OA\Property(property="number", type="string", example="+1234567890"),
 *                     @OA\Property(property="formatted_number", type="string", example="(123) 456-7890"),
 *                     @OA\Property(property="call_type", type="string", example="incoming"),
 *                     @OA\Property(property="duration", type="integer", example=120),
 *                     @OA\Property(property="timestamp", type="string", format="date-time", example="2024-04-07T10:30:00Z"),
 *                     @OA\Property(property="sim_display_name", type="string", example="SIM 1"),
 *                     @OA\Property(property="phone_account_id", type="string", example="account_123"),
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Call history imported successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Call history imported successfully with customer IDs.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Failed to create call history table",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Failed to create call history table.")
 *         )
 *     )
 * )
 */
public function importCallHistory(Request $request)
{
    $tenantSchema = $request->input('tenant_schema');
    $empId = $request->input('emp_id'); // Optional
    $callHistoryData = $request->input('call_history');

    QueryHelper::initializeConnection($tenantSchema);
    DB::setDefaultConnection('tenant');

    // Define table schema
    $tableName = 'call_history';
    $columns = [
        'id' => 'INT UNSIGNED AUTO_INCREMENT PRIMARY KEY',
        'customer_id' => 'INT UNSIGNED NULL',
        'emp_id' => 'BIGINT DEFAULT NULL',
        'name' => 'VARCHAR(255) NULL',
        'number' => 'VARCHAR(100) NULL',
        'formatted_number' => 'VARCHAR(100) NULL',
        'call_type' => 'VARCHAR(100) NULL',
        'duration' => 'INT(11) NULL',
        'timestamp' => 'TIMESTAMP NULL',
        'sim_display_name' => 'VARCHAR(100) NULL',
        'phone_account_id' => 'VARCHAR(100) NULL',
        'status' => 'INT(11) DEFAULT 1',
        'created_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP',
        'updated_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
        'is_deleted' => 'INT(11) DEFAULT 0',
    ];

    $tableCreated = $this->tableCreationService->createTable($tenantSchema, $tableName, $columns);

    if ($tableCreated) {
        try {
            foreach ($callHistoryData as $key => $record) {
                $callHistoryData[$key]['customer_id'] = $this->getCustomerId($record['number']);

                // If emp_id is provided in the payload, add it to each record
                if ($empId) {
                    $callHistoryData[$key]['emp_id'] = $empId;
                }
            }
            DB::table($tableName)->insert($callHistoryData);
            return response()->json(['message' => 'Call history imported successfully.'], 200);
        } catch (\Exception $e) {
            Log::error('Call History Insert Error: ' . $e->getMessage());
            return response()->json(['message' => 'Error inserting data.'], 500);
        }
    } else {
        return response()->json(['message' => 'Failed to create call history table.'], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/get-call-history",
 *     summary="Retrieve call history for a given phone number",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "number"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="number", type="string", example="+1234567890")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Call history retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="call_history", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="customer_id", type="integer", example=101),
 *                     @OA\Property(property="name", type="string", example="John Doe"),
 *                     @OA\Property(property="number", type="string", example="+1234567890"),
 *                     @OA\Property(property="call_type", type="string", example="incoming"),
 *                     @OA\Property(property="duration", type="integer", example=120),
 *                     @OA\Property(property="timestamp", type="string", format="date-time", example="2024-04-07T10:30:00Z")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No call history found",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="No call history found for the provided phone number.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=422,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="The number field is required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Error occurred while fetching call history.")
 *         )
 *     )
 * )
 */
public function getCallHistory(Request $request)
{
    // Validate the incoming request data
    $validator = Validator::make($request->all(), [
        'tenant_schema' => 'required|string',
        'number' => 'required|numeric',
    ]);

    if ($validator->fails()) {
        return response()->json([
            'success' => false,
            'message' => $validator->errors()->first()
        ], 422);
    }

    // Get the tenant schema and phone number from the request body
    $tenantSchema = $request->input('tenant_schema');
    $number = $request->input('number');


    try {
         QueryHelper::initializeConnection($tenantSchema);

            $callHistory = DB::connection('tenant')->table('call_history')
                ->get(); // Get all the call history for the tenant schema

            if ($callHistory->isEmpty()) {
                return response()->json([
                    'success' => true,
                    'message' => 'No call history found for the provided tenant schema.'
                ], 200);
            }
        // Step 4: Filter the call history by phone number (either from database or cache)
        // Convert the callHistory collection to array and filter by the number
        $filteredHistory = collect($callHistory)->filter(function ($item) use ($number) {
            return $item->number == $number; // Access the 'number' property, not an array
        })->values(); // Re-index the collection

        // Step 5: If no data is found for the given number, return an error
        if ($filteredHistory->isEmpty()) {
            return response()->json([
                'success' => true,
                'message' => 'No call history found for the provided phone number.'
            ], 200);
        }
        return response()->json([
            'success' => true,
            'call_history' => $filteredHistory // Return the filtered collection
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Error occurred while fetching call history: ' . $e->getMessage()
        ], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/saveCustomerDetails",
 *     summary="Save customer details for a tenant",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "business_id", "status_id", "mobile", "phone_account_id", "fields"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="business_id", type="integer", example=101),
 *             @OA\Property(property="status_id", type="integer", example=1),
 *             @OA\Property(property="mobile", type="string", example="+1234567890"),
 *             @OA\Property(property="phone_account_id", type="string", example="acc_456"),
 *             @OA\Property(property="fields", type="object",
 *                 example={"first_name": "John", "last_name": "Doe", "email": "john@example.com"}
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Customer details saved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Customers Details Saved successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Failed to create customers details table",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Failed to create customers details table.")
 *         )
 *     )
 * )
 */
public function saveCoustomerDetails(Request $request)
{
 
        $tenantSchema = $request->input('tenant_schema');
        QueryHelper::initializeConnection($tenantSchema);
        $customerDetails = $request->input('fields');
        $data = [];
        $data['fields'] = json_encode($customerDetails);
        $data['business_id'] = $request->input('business_id');
        $data['status_id'] = $request->input('status_id');
        $data['mobile'] = $request->input('mobile');
        $data['phone_account_id'] = $request->input('phone_account_id');
        
   
        DB::setDefaultConnection('tenant');
   
        $tableName = 'customer_details';
        $columns = [
            'id' => 'INT UNSIGNED AUTO_INCREMENT PRIMARY KEY',
            'business_id' => 'INT(100) NULL',
            'status_id' => 'INT(100) NOT NULL',
            'mobile' => 'VARCHAR(100) NOT NULL',
            'phone_account_id' => 'VARCHAR(100) NOT NULL',
            'fields' => 'JSON NULL',
            'status' => 'INT(100) DEFAULT 1',
            'created_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP',
            'updated_at' => 'TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
            'is_deleted' => 'INT(11) DEFAULT 0',
        ];
   
        $tableCreated = $this->tableCreationService->createTable($tenantSchema, $tableName, $columns);
        try {
         if ($tableCreated) {
             DB::table($tableName)->insert($data);
             return response()->json(['message' => 'Customers Details Saved successfully.'], 200);
         } else {
             return response()->json(['message' => 'Failed to create customers details table.'], 500);
         }
        } catch (\Throwable $th) {
         throw $th;
        }   
}
/**
 * @OA\Post(
 *     path="/api/getServiceOrProductCategory",
 *     summary="Get service or product category based on type and business ID",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\Parameter(
 *         name="type",
 *         in="query",
 *         required=true,
 *         description="Type of category (sales or service)",
 *         @OA\Schema(type="string", enum={"sales", "service"})
 *     ),
 *     @OA\Parameter(
 *         name="business_id",
 *         in="query",
 *         required=true,
 *         description="Business ID",
 *         @OA\Schema(type="integer", example=123)
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Category data retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="success"),
 *             @OA\Property(property="data", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="product_category", type="string", example="Electronics"),
 *                     @OA\Property(property="service", type="string", example="Repair")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failure"),
 *             @OA\Property(property="message", type="string", example="Invalid input.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No data found",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="string", example="failure"),
 *             @OA\Property(property="message", type="string", example="No data available for the given input.")
 *         )
 *     )
 * )
 */
public function getServiceOrProductCategory(Request $request)
{
        // Retrieve 'type' and 'business_id' from the request
        $type = $request->input('type');
        $businessID = $request->input('business_id');
         // Determine the column to select based on the type
        $column = ($type === 'sales') ? 'product_category' : 'service';
    
        // Fetch the distinct data based on the selected column and business_id
        $services = DB::table('sales_and_services')
            ->select($column)
            ->distinct()
            ->where('business_id', $businessID)
            ->where('status', 1) // Ensure status is 1
            ->where(function ($query) use ($type) {
                if ($type === 'sales') {
                    $query->where('type', 'sales')
                          ->orWhere('type', 'both'); // Include 'both' for sales
                } elseif ($type === 'service') {
                    $query->where('type', 'service')
                          ->orWhere('type', 'both'); // Include 'both' for service
                }
            })
            ->get();
    
        // Check if the services collection is empty
        if ($services->isEmpty()) {
            return response()->json([
                'status' => 'failure',
                'message' => 'No data available for the given input.'
            ], 200);
        }
        
        // Return the response in JSON format if data is found
        return response()->json([
            'status' => 'success',
            'data' => $services
        ], 200);
}
/**
 * @OA\Post(
 *     path="/api/addCatalog",
 *     summary="Add a new catalog entry",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\MediaType(
 *             mediaType="multipart/form-data",
 *             @OA\Schema(
 *                 required={"form_id", "tenant_schema"},
 *                 @OA\Property(property="form_id", type="integer", example=1),
 *                 @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *                 @OA\Property(property="image", type="string", format="binary", nullable=true)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="Data saved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Data saved successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No form available",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No form available.")
 *         )
 *     )
 * )
 */
public function addCatalog(Request $request)
{
    // Validate incoming request
    $request->validate([
        'form_id' => 'required|integer',
        'tenant_schema' => 'required|string',
        'image' => 'nullable|image|max:2048',
    ]);

    // Extract form_id and tenant_schema
    $formId = $request->input('form_id');
    $tenantSchema = $request->input('tenant_schema');
    // Dynamically set the tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Retrieve form structure from form_builder table in the master database
    $form = FormHelper::getFormById($formId, $tenantSchema);

    if (!$form) {
        return response()->json(['message' => 'No form available.'], 200);
    }

    // Decode the form JSON structure
    $formStructure = json_decode($form->form, true);

    // Extract the table name from the form name
    $tableName = Str::slug($form->name);
  
    // Check if the table already exists in the tenant's database
    if (!DB::connection('tenant')->getSchemaBuilder()->hasTable($tableName)) {
        // Create the table if it doesn't exist
        DB::connection('tenant')->getSchemaBuilder()->create($tableName, function ($table) use ($formStructure) {
            $table->increments('id');
            foreach ($formStructure as $field) {
                $type = strtolower($field['type'] ?? '');
                $dataType = strtolower($field['DataType'] ?? '');
            
                if ($type === 'number' || strpos($dataType, 'decimal') !== false) {
                    $table->decimal($field['name'], 10, 2)->nullable(); // Default NULL instead of 0
                }
                elseif (strpos($dataType, 'integer') !== false) {
                    $table->integer($field['name'])->default(0);
                }
                elseif ($type === 'string' || $type === 'select') { 
                    $table->string($field['name'], 255)->nullable(); // Treat "select" as string
                } else {
                    $table->text($field['name'])->nullable(); // Default fallback for unknown types
                }
            }
            $table->boolean('status')->default(1);
            $table->boolean('is_deleted')->default(0);
            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
        });
    }

    if ($request->has('brand') && !empty($request->brand)) {
        if (!DB::connection('tenant')->getSchemaBuilder()->hasTable('brand_master')) {
            DB::connection('tenant')->getSchemaBuilder()->create('brand_master', function ($table) {
                $table->bigIncrements('id');
                $table->string('brand_name', 255)->unique();
                $table->boolean('status')->default(1);
                $table->boolean('is_deleted')->default(0);
                $table->timestamps();
            });
        }

        // Insert new brand only if not exists
        $brandName = trim($request->brand);
        $exists = DB::connection('tenant')->table('brand_master')
            ->where('brand_name', $brandName)
            ->exists();

        if (!$exists) {
            DB::connection('tenant')->table('brand_master')->insert([
                'brand_name' => $brandName,
                'status' => 1,
                'is_deleted' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }
    // Handle image upload with tenant-specific folder
    $imagePath = null;
    if ($request->hasFile('image')) {
        $image = $request->file('image');
        
        // Define the path: tenant folder / form-specific subfolder
        $tenantFolder = "{$tenantSchema}/{$tableName}"; // e.g., tenants/{tenant_schema}/{form_name}
        
        // Store the image in the specified tenant and form-specific folder
        $imagePath = $image->store($tenantFolder, 'public');
    }

    // Prepare data to insert into the dynamically created table
    $formData = $request->except(['form_id', 'tenant_schema', 'image']);
    if ($imagePath) {
        $formData['image'] = $imagePath;
    }

    foreach ($formData as $column => $value) {
        if (!Schema::connection('tenant')->hasColumn($tableName, $column)) {
            Schema::connection('tenant')->table($tableName, function (Blueprint $table) use ($column, $value) {
                // Infer column type
                if (is_numeric($value) && strpos((string)$value, '.') !== false) {
                    $table->decimal($column, 10, 2)->nullable();
                } elseif (is_numeric($value)) {
                    $table->integer($column)->nullable();
                } elseif (is_string($value) && strlen($value) <= 255) {
                    $table->string($column)->nullable();
                } else {
                    $table->text($column)->nullable();
                }
            });
        }
    }
    // Insert data into the newly created or existing table
    DB::connection('tenant')->table($tableName)->insert($formData);
    return response()->json(['message' => 'Data saved successfully.'], 201);
}
/**
 * @OA\Post(
 *     path="/api/getCatalog",
 *     summary="Retrieve catalog data",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="tenant_123"
 *     ),
 *     @OA\Parameter(
 *         name="name",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="product_catalog"
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalog data retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="The catalog does not exist or no data found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="The catalog does not exist.")
 *         )
 *     )
 * )
 */
public function getCatalog(Request $request)
{
    // Validate the incoming request
    $request->validate([
        'tenant_schema' => 'required|string',
        'name' => 'required|string',
    ]);

    // Extract tenant_schema and name from the request
    $tenantSchema = $request->input('tenant_schema');
    $catalogName = $request->input('name');
    // Dynamically set the tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Convert the catalog name to a table name using slug format
    $tableName = Str::slug($catalogName);

    // Check if the table exists in the tenant's database
    if (!DB::connection('tenant')->getSchemaBuilder()->hasTable($tableName)) {
        return response()->json(['message' => 'The catalog does not exist.'], 200);
    }

    // Fetch all records from the catalog table
    $catalogData = DB::connection('tenant')->table($tableName)->where('status', 1)->where('is_deleted', 0)->orderBy('id', 'desc')->get();

    // Check if any records were found
    if ($catalogData->isEmpty()) {
        return response()->json(['message' => 'No catalog data found.'], 200);
    }


    // Return the catalog data as a JSON response
    return response()->json(['data' => $catalogData], 200);
}
/**
 * @OA\Post(
 *     path="/api/editCatalog",
 *     summary="Edit a catalog entry",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "catalog_id", "catalog_type"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="catalog_id", type="integer", example=1),
 *             @OA\Property(property="catalog_type", type="string", enum={"product", "service"}, example="product"),
 *             @OA\Property(property="name", type="string", example="Updated Catalog Name"),
 *             @OA\Property(property="description", type="string", example="Updated catalog description"),
 *             @OA\Property(property="image", type="string", format="binary", nullable=true)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalog updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Catalog updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalog not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Catalog not found.")
 *         )
 *     )
 * )
 */
public function editCatalog(Request $request)
{
    // Validate the incoming request
    $request->validate([
        'tenant_schema' => 'required|string',
        'catalog_id' => 'required|integer',
        'catalog_type' => 'required|string|in:product,service', // Ensure the catalog type is provided (either 'product' or 'service')
        'image' => 'nullable|image|max:2048', // Allow image upload
    ]);

    // Extract tenant schema, catalog ID, and catalog type
    $tenantSchema = $request->input('tenant_schema');
    $catalogId = $request->input('catalog_id');
    $catalogType = $request->input('catalog_type');

    // Dynamically set the tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Determine the table name based on the catalog type (product or service)
    $tableName = '';
    if ($catalogType === 'product') {
        $tableName = 'product-catalogs'; // Replace with actual product catalog table name
    } elseif ($catalogType === 'service') {
        $tableName = 'service-catalogs'; // Replace with actual service catalog table name
    }

    // Check if the catalog entry exists in the appropriate table
    $catalog = DB::connection('tenant')->table($tableName)->where('id', $catalogId)->first();
    if (!$catalog) {
        return response()->json(['message' => 'Catalog not found.'], 200);
    }

    // Prepare the fields to update
    $updateData = [];

    // Dynamically loop through all the input data and add fields to updateData
    foreach ($request->all() as $key => $value) {
        // Skip the fields that should not be updated
        if ($key !== 'tenant_schema' && $key !== 'catalog_id' && $key !== 'catalog_type' && $key !== 'image') {
            // You can add more logic to handle specific fields, like image upload, etc.
            // For example, you can handle image upload differently if needed

            // Add each field to the update data
            $updateData[$key] = $value;
        }
    }

    // Handle image upload if provided
    if ($request->hasFile('image')) {
        $image = $request->file('image');
        
        // Define the path: tenant folder / catalog-specific subfolder
        $tenantFolder = "{$tenantSchema}/{$tableName}"; // e.g., tenants/{tenant_schema}/{catalog_name}
        
        // Store the new image in the specified tenant and catalog-specific folder
        $newImagePath = $image->store($tenantFolder, 'public');
        $updateData['image'] = $newImagePath;
    }
    // Update the catalog entry
    DB::connection('tenant')->table($tableName)->where('id', $catalogId)->update($updateData);
    if ($request->filled('available_quantity')) {
        $availableQuantity = $request->input('available_quantity');

        $ocPayload = [
            'tenant_schema' => $tenantSchema,
            'products' => [
                [
                    'waqin_prod_id' => $catalogId,
                    'quantity' => $availableQuantity
                ]
            ]
        ];

        try {
            
            $ocResponse = Http::post(env('OPENCART_API_URL') . "/index.php?route=api/rest/product/updateProductQuantity", $ocPayload);

            if ($ocResponse->successful()) {
                $ocData = $ocResponse->json();
            } else {
                return response()->json([
                    'message' => 'Catalog updated, but OC quantity update failed.',
                    'oc_error' => $ocResponse->body()
                ], 500);
            }
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Catalog updated, but OC quantity update failed.',
                'oc_exception' => $e->getMessage()
            ], 500);
        }
    }

    return response()->json(['message' => 'Catalog updated successfully.'], 200);
}
/**
 * @OA\Post(
 *     path="/api/deleteCatalog",
 *     summary="Delete catalog entries",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "catalog_ids", "catalog_type"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="catalog_ids", type="array",
 *                 @OA\Items(type="integer", example=1)
 *             ),
 *             @OA\Property(property="catalog_type", type="string", enum={"product", "service"}, example="product")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalogs deleted successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Catalogs deleted successfully."),
 *             @OA\Property(property="deleted_catalogs", type="array",
 *                 @OA\Items(type="integer", example=1)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalog(s) not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Catalog(s) not found.")
 *         )
 *     )
 * )
 */
public function deleteCatalog(Request $request)
{
    // Validate the incoming request
    $request->validate([
        'tenant_schema' => 'required|string',
        'catalog_ids' => 'required|array|min:1', // Ensure catalog_ids is an array
        'catalog_ids.*' => 'integer', // Validate each catalog_id as an integer
        'catalog_type' => 'required|string|in:product,service',
    ]);

    // Extract tenant schema, catalog IDs, and catalog type
    $tenantSchema = $request->input('tenant_schema');
    $catalogIds = $request->input('catalog_ids');
    $catalogType = $request->input('catalog_type');

    // Dynamically set the tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Determine the table name based on catalog type
    $tableName = ($catalogType === 'product') ? 'product-catalogs' : 'service-catalogs';

    // Fetch the catalogs to check if they exist
    $existingCatalogs = DB::connection('tenant')->table($tableName)
        ->whereIn('id', $catalogIds)
        ->pluck('id')
        ->toArray();

    // Check if any catalog exists
    if (empty($existingCatalogs)) {
        return response()->json(['message' => 'Catalog(s) not found.'], 200);
    }

    // Update the catalogs to mark them as deleted (soft delete)
    DB::connection('tenant')->table($tableName)
        ->whereIn('id', $existingCatalogs)
        ->update(['status' => 0, 'is_deleted' => 1]);

    return response()->json([
        'message' => 'Catalogs deleted successfully.',
        'deleted_catalogs' => $existingCatalogs
    ], 200);
}
/**
 * @OA\Post(
 *     path="/api/addEmployee",
 *     summary="Add an employee to the tenant database",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "employee_type"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="employee_type", type="string", example="Operational user"),
 *             @OA\Property(property="first_name", type="string", example="John"),
 *             @OA\Property(property="last_name", type="string", example="Doe"),
 *             @OA\Property(property="email", type="string", format="email", example="john.doe.com"),
 *             @OA\Property(property="phone", type="string", example="+1234567890"),
 *             @OA\Property(property="position", type="string", example="Manager"),
 *             @OA\Property(property="image", type="string", format="binary")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Employee added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Employee added successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema is required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tenant not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant not found in master database.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="An error occurred: [error details]")
 *         )
 *     )
 * )
 */
public function addEmployee(Request $request)
{
    try {
        $user = Auth::guard('api')->user();
        $tenantSchema = $user->tenant_schema;
        $employeeType = $request->input('employee_type');
        $mobile = $request->input('mobile');
        $BusinessID = $user->business_id;

        if (empty($tenantSchema)) {
            return response()->json(['message' => 'Tenant schema is required.'], 400);
        }

        // Switch to tenant DB
        QueryHelper::initializeConnection($tenantSchema);

        // Add to employee table
        $this->addEmployeeToTenantDB($request, $tenantSchema, $mobile);

        // Maybe add to master tenants table (silently skip if not allowed)
        $this->maybeAddEmployeeToMasterTenants($request, $tenantSchema, $employeeType, $BusinessID);

        return response()->json(['message' => 'Employee added successfully.'], 200);

    } catch (\Exception $e) {
        return response()->json(['message' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}

private function addEmployeeToTenantDB(Request $request, $tenantSchema, $mobile)
{
    // Ensure 'employees' table exists
    if (!Schema::hasTable('employees')) {
        Schema::create('employees', function (Blueprint $table) {
            $table->id();
            $table->string('full_name')->nullable();
            $table->string('mobile')->unique();
            $table->boolean('status')->default(1);
            $table->boolean('is_deleted')->default(0);
            $table->string('image')->nullable();
            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
        });
    }

    // Check duplicate
    $existingEmployee = DB::table('employees')
        ->where('mobile', $mobile)
        ->where('is_deleted', 0)
        ->first();

    if ($existingEmployee) {
        throw new \Exception('Employee with this mobile number already exists.');
    }

    // Add dynamic columns
    $formFields = array_keys($request->except(['tenant_schema', 'image', 'full_name']));
    Schema::table('employees', function (Blueprint $table) use ($formFields) {
        foreach ($formFields as $field) {
            if (!Schema::hasColumn('employees', $field)) {
                $table->string($field)->nullable();
            }
        }
    });

    // Handle image
    $imagePath = null;
    if ($request->hasFile('image')) {
        $image = $request->file('image');
        $tenantFolder = "{$tenantSchema}/employees";
        $imagePath = $image->store($tenantFolder, 'public');
    }

    // Prepare data
    $tableColumns = Schema::getColumnListing('employees');
    $employeeData = $request->only($tableColumns);
    $firstName = $request->input('first_name', '');
    $lastName = $request->input('last_name', '');
    $employeeData['full_name'] = trim("$firstName $lastName");
    if ($imagePath) {
        $employeeData['image'] = $imagePath;
    }

    DB::table('employees')->insert($employeeData);
}

private function maybeAddEmployeeToMasterTenants(Request $request, $tenantSchema, $employeeType, $BusinessID)
{
    try {
        $setting = DB::connection('master_db')
            ->table('employee_login_setting')
            ->first();

        if (!$setting) return;

        $allowedBusinessIds = explode(',', $setting->business_ids);
        $allowedType = strtolower(trim($setting->type));
        $currentType = strtolower(trim($employeeType));

        // Skip if not matched
        if (!in_array($BusinessID, $allowedBusinessIds)) return;
        if ($allowedType !== 'both' && $allowedType !== $currentType) return;

        // Proceed to insert
        $tenantDetails = DB::connection('master_db')
            ->table('tenants')
            ->where('tenant_schema', $tenantSchema)
            ->first(['business_id', 'sub_category_id']);

        if (!$tenantDetails) return;

        $tenantColumns = Schema::connection('master_db')->getColumnListing('tenants');
        $tenantData = $request->only($tenantColumns);
        $tenantData['tenant_schema'] = $tenantSchema;
        $tenantData['business_id'] = $tenantDetails->business_id;
        $tenantData['sub_category_id'] = $tenantDetails->sub_category_id;
        $tenantData['user_type'] = $employeeType;

        DB::connection('master_db')->table('tenants')->insert($tenantData);
    } catch (\Exception $e) {
        // Silently skip without throwing error
    }
}





// public function addEmployee(Request $request)
// {
//     try {
       
//         $user = Auth::guard('api')->user();
//         $tenantSchema = $user->tenant_schema;
//         $employeeType = $request->input('employee_type');
//         $mobile = $request->input('mobile');
//         $BusinessID = $user->business_id;



//         // Check if tenant schema is provided
//         if (empty($tenantSchema)) {
//             return response()->json(['message' => 'Tenant schema is required.'], 400);
//         }

//         // Switch to the tenant's database connection
//         QueryHelper::initializeConnection($tenantSchema);

//         // Ensure the 'employees' table exists with predefined columns
//         if (!Schema::hasTable('employees')) {
//             Schema::create('employees', function (Blueprint $table) {
//                 $table->id();
//                 $table->string('full_name')->nullable(); // Add full_name column
//                 $table->string('mobile')->unique();
//                 $table->boolean('status')->default(1);
//                 $table->boolean('is_deleted')->default(0);
//                 $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
//             	$table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
//             });
//         }

//         // **Check for duplicate mobile number**
//         $existingEmployee = DB::table('employees')
//             ->where('mobile', $mobile)
//             ->where('is_deleted', 0) // Exclude deleted employees
//             ->first();

//         if ($existingEmployee) {
//             return response()->json(['message' => 'Employee with this mobile number already exists.'], 409);
//         }

//         // Add the 'image' and 'full_name' columns if they do not exist
//         if (!Schema::hasColumn('employees', 'image')) {
//             Schema::table('employees', function (Blueprint $table) {
//                 $table->string('image')->nullable()->after('is_deleted');
//             });
//         }
//         if (!Schema::hasColumn('employees', 'full_name')) {
//             Schema::table('employees', function (Blueprint $table) {
//                 $table->string('full_name')->nullable()->before('status');
//             });
//         }

//         // Dynamically add new columns for any fields in the request (excluding tenant_schema, image, and full_name)
//         $formFields = array_keys($request->except(['tenant_schema', 'image', 'full_name']));
//         Schema::table('employees', function (Blueprint $table) use ($formFields) {
//             foreach ($formFields as $field) {
//                 if (!Schema::hasColumn('employees', $field)) {
//                     $table->string($field)->nullable()->before('status');
//                 }
//             }
//         });

//         // Handle the image upload
//         $imagePath = null;
//         if ($request->hasFile('image')) {
//             $image = $request->file('image');
            
//             // Define the path: tenant folder / employees subfolder
//             $tenantFolder = "{$tenantSchema}/employees"; // e.g., tenants/{tenant_schema}/employees
            
//             // Store the image in the specified tenant's employees folder
//             $imagePath = $image->store($tenantFolder, 'public'); // Save in public/tenants/{tenant_schema}/employees folder
//         }

//         // Prepare employee data for insertion
//         $tableColumns = Schema::getColumnListing('employees'); // Get existing columns in the employees table
//         $employeeData = $request->only($tableColumns); // Filter input data to match table columns

//         // Construct the full_name field
//         $firstName = $request->input('first_name', '');
//         $lastName = $request->input('last_name', '');
//         $employeeData['full_name'] = trim("$firstName $lastName");

//         // Add the image path to the employee data if available
//         if ($imagePath) {
//             $employeeData['image'] = $imagePath;
//         }

//         // Insert the employee data into the employees table
//         DB::table('employees')->insert(array_merge($employeeData));

//         // If employee is an Business user, store in master DB `tenants` table
//         if ($employeeType === 'Business user') {
//             // Ensure master DB connection
//             DB::setDefaultConnection('master_db');
        
//             // Get columns from the master `tenants` table
//             $tenantColumns = Schema::connection('master_db')->getColumnListing('tenants');
//             $tenantData = $request->only($tenantColumns);
        
//             // Fetch the tenant details from the master `tenants` table using tenant_schema
//             $tenantDetails = DB::connection('master_db')
//                 ->table('tenants')
//                 ->where('tenant_schema', $tenantSchema)
//                 ->first(['business_id', 'sub_category_id']);
        
//             if (!$tenantDetails) {
//                 return response()->json(['message' => 'Tenant not found in master database.'], 200);
//             }
        
//             // Ensure `tenant_schema`, `business_id`, and `sub_category_id` are stored correctly
//             $tenantData['tenant_schema'] = $tenantSchema;
//             $tenantData['business_id'] = $tenantDetails->business_id;
//             $tenantData['sub_category_id'] = $tenantDetails->sub_category_id;
//             $tenantData['user_type'] = $employeeType;
        
//             // Insert into master `tenants` table using the master DB connection
//             DB::connection('master_db')->table('tenants')->insert($tenantData);
//         }

//         return response()->json(['message' => 'Employee added successfully.'], 200);
//     } catch (\Exception $e) {
//         return response()->json(['message' => 'An error occurred: ' . $e->getMessage()], 500);
//     }
// }
/**
 * @OA\Post(
 *     path="/api/editEmployee",
 *     summary="Edit employee details",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="id", type="integer", example=1),
 *             @OA\Property(property="first_name", type="string", example="John"),
 *             @OA\Property(property="last_name", type="string", example="Doe"),
 *             @OA\Property(property="email", type="string", example="john.doe@example.com"),
 *             @OA\Property(property="phone", type="string", example="+1234567890"),
 *             @OA\Property(property="status", type="integer", example=1),
 *             @OA\Property(property="image", type="string", format="binary", description="Employee profile image")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Employee data updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Employee data updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema and employee ID are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Employee not found or table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Employee not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error.")
 *         )
 *     )
 * )
 */
public function editEmployee(Request $request)
{
    try {
        // Get tenant schema (database name) and employee ID from the request
        $tenantSchema = $request->input('tenant_schema');
        $employeeId = $request->input('id');

        // Check if tenant schema and employee ID are provided
        if (empty($tenantSchema) || empty($employeeId)) {
            return response()->json(['message' => 'Tenant schema and employee ID are required.'], 400);
        }

        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the 'employees' table exists
        if (!Schema::hasTable('employees')) {
            return response()->json(['message' => 'No customers records available.'], 200);
        }

        // Check if the employee with the given ID exists
        $employee = DB::table('employees')->where('id', $employeeId)->first();
        if (!$employee) {
            return response()->json(['message' => 'Employee not found.'], 200);
        }
        // Handle image update if an image file is provided
        $imagePath = $employee->image; // Retain the current image path
        if ($request->hasFile('image')) {
            $image = $request->file('image');
            
            // Define the path: tenant folder / employees subfolder
            $tenantFolder = "{$tenantSchema}/employees"; // e.g., tenants/{tenant_schema}/employees
            
            // Store the new image and update the path
            $imagePath = $image->store($tenantFolder, 'public'); // Save in public/tenants/{tenant_schema}/employees folder
        }

        // Dynamically add any new columns for fields in the request
        $formFields = array_keys($request->except(['tenant_schema', 'id']));
        Schema::table('employees', function (Blueprint $table) use ($formFields) {
            foreach ($formFields as $field) {
                if (!Schema::hasColumn('employees', $field)) {
                    $table->string($field)->nullable()->before('status');
                }
            }
        });

        // Filter request data to only include fields that exist in the table
        $tableColumns = Schema::getColumnListing('employees');
        $employeeData = $request->only($tableColumns);

        // Add the updated image path to the employee data
        if ($imagePath) {
            $employeeData['image'] = $imagePath;
        }

        // Check if first_name or last_name is being updated
        $firstName = $request->input('first_name', $employee->first_name); // Default to existing value
        $lastName = $request->input('last_name', $employee->last_name);   // Default to existing value

        // Update full_name dynamically
        $employeeData['full_name'] = trim("{$firstName} {$lastName}");

        // Update the employee record with the filtered data
        DB::table('employees')
            ->where('id', $employeeId)
            ->update(array_merge($employeeData));

        return response()->json(['message' => 'Employee data updated successfully.'], 200);
    } catch (\Exception $e) {
        return response()->json(['message' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/deleteEmployee",
 *     summary="Soft delete an employee",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="id", type="integer", example=1)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Employee deleted successfully (soft delete).",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Employee deleted successfully (soft delete).")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema and employee ID are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Employee not found or table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Employee not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error.")
 *         )
 *     )
 * )
 */
public function deleteEmployee(Request $request)
{
        // Get tenant schema (database name) and employee ID from the request
        $tenantSchema = $request->input('tenant_schema');
        $employeeId = $request->input('id');

        // Check if tenant schema and employee ID are provided
        if (empty($tenantSchema) || empty($employeeId)) {
            return response()->json(['message' => 'Tenant schema and employee ID are required.'], 400);
        }

        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);


        // Check if the 'employees' table exists
        if (!Schema::hasTable('employees')) {
            return response()->json(['message' => 'No customers records available.'], 200);
        }

        // Check if the employee with the given ID exists
        $employee = DB::table('employees')->where('id', $employeeId)->first();

        if ($employee) {
            // Update the employee's status to 0 and is_deleted to 1
            DB::table('employees')
                ->where('id', $employeeId)
                ->update([
                    'status' => 0,
                    'is_deleted' => 1,
                ]);

       return response()->json(['message' => 'Employee deleted successfully (soft delete).'], 200);
        } else {
            return response()->json(['message' => 'Employee not found.'], 200);
        }
    }
/**
 * @OA\Post(
 *     path="/api/getEmployees",
 *     summary="Retrieve active employees",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="List of active employees",
 *         @OA\JsonContent(
 *             @OA\Property(property="employees", type="array", @OA\Items(
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="full_name", type="string", example="John Doe"),
 *                 @OA\Property(property="designation", type="string", example="Manager")
 *             ))
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema is required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No employees found or table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No customers records available.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error.")
 *         )
 *     )
 * )
 */
public function getEmployees(Request $request)
{
        // Get tenant schema (database name) from the request
        $user = Auth::guard('api')->user();

        if (!$user || !isset($user->tenant_schema)) {
            abort(response()->json(['message' => 'Tenant schema missing in token'], 401));
        }

        $tenantSchema = $user->tenant_schema;

        // Check if tenant schema is provided
        if (empty($tenantSchema)) {
            return response()->json(['message' => 'Tenant schema is required.'], 400);
        }
        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the 'employees' table exists
        if (!Schema::hasTable('employees')) {
            return response()->json(['message' => 'No customers records available.'], 200);
        }

        $employees = DB::table('employees')
                ->where('is_deleted', 0)
                ->get();

            // Check if employees exist
        if ($employees->isEmpty()) {
            return response()->json(['message' => 'No employees found.'], 200);
        }
       

        return response()->json(['employees' => $employees], 200);
}
/**
 * @OA\Post(
 *     path="/api/saveAppointment",
 *     summary="Save an appointment form submission",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="form_id", type="integer", example=1),
 *             @OA\Property(property="form_data", type="object", example={"patient_name": "John Doe", "appointment_date": "2025-04-10"})
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointment added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointment added successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema, form ID, and form data are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Form not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Form not found in the master database.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error.")
 *         )
 *     )
 * )
 */  
public function saveAppointment(Request $request)
{
    // Get tenant schema and form ID from the request
    $tenantSchema = $request->input('tenant_schema');
    $formId = $request->input('form_id');
    $formData = $request->input('form_data');

    // Check if tenant schema, form ID, and form data are provided
    if (empty($tenantSchema) || empty($formId) || empty($formData)) {
        return response()->json(['message' => 'Tenant schema, form ID, and form data are required.'], 400);
    }

    // Retrieve the form from the master database ('master_db')
    $form = DB::connection('master_db')->table('form_builder')->where('id', $formId)->first();

    if (!$form) {
        return response()->json(['message' => 'Form not found in the master database.'], 200);
    }

    // Get table name from the form 'name' field
    $tableName = $form->name;

    // Switch to the tenant's database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Check if the table exists, if not, create it
    if (!Schema::hasTable($tableName)) {
        Schema::create($tableName, function (Blueprint $table) {
            $table->id();
            $table->boolean('status')->default(1);
            $table->boolean('is_deleted')->default(0);
            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
        });
    }

    // Ensure all columns in the form data exist in the table
    $existingColumns = Schema::getColumnListing($tableName); // Get all existing columns

    Schema::table($tableName, function (Blueprint $table) use ($formData, $existingColumns) {
        foreach ($formData as $columnName => $value) {
            if (!in_array($columnName, $existingColumns)) {
                // Dynamically add missing columns as varchar
                $table->string($columnName)->nullable();
            }
        }
    });

    // Insert form data into the table
    $insertData = array_merge($formData, [
        'status' => 1,
        'is_deleted' => 0,
    ]);

    // Insert the data
    DB::table($tableName)->insert($insertData);


    // Handle the date format for cache deletion
    if (isset($formData['date'])) {
        // Parse the date to ensure it matches the expected "d M Y" format
        $parsedDate = Carbon::parse($formData['date']);
        $formattedDate = $parsedDate->format('d M Y'); // "24 Apr 2025"
    }

    return response()->json(['message' => 'Appointment added successfully.'], 200);
}
/**
 * @OA\Post(
 *     path="/api/editAppointment",
 *     summary="Edit an existing appointment",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="appointment_id", type="integer", example=1),
 *             @OA\Property(property="form_data", type="object", example={"date": "2025-04-15", "status": "confirmed"})
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointment updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointment updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema, appointment ID, and form data are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointment not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointment not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Failed to update appointment.")
 *         )
 *     )
 * )
 */
public function editAppointment(Request $request)
{
    // Get tenant schema, appointment ID, and form data from the request
    $tenantSchema = $request->input('tenant_schema');
    $appointmentId = $request->input('appointment_id');
    $formData = $request->input('form_data');
    // Check if tenant schema, appointment ID, and form data are provided
    if (empty($tenantSchema) || empty($appointmentId) || empty($formData)) {
        return response()->json(['message' => 'Tenant schema, appointment ID, and form data are required.'], 400);
    }
    // Switch to the tenant's database connection
    QueryHelper::initializeConnection($tenantSchema);
    // Define table names
    $appointmentTable = 'appointment';
    $businessHistoryTable = 'business_history';
    // Retrieve appointment details from the appointment table
    $appointment = DB::table($appointmentTable)->where('id', $appointmentId)->first();
    // Extract customer_id and date from the appointment record
    $customerId = $appointment->customer_id;
    $AppointmentDate = $appointment->date;
    // Check if the business_history table exists
    $businessHistoryExists = Schema::hasTable($businessHistoryTable);
    // If business_history table exists, proceed with the update
    if ($businessHistoryExists) {
         try {
                // Update schedule_on in business_history with the new date from formData
                DB::table($businessHistoryTable)
                    ->where('customer_id', $customerId)
                    ->where('current_status', 'Schedule')
                    ->where('schedule_on', '=', $AppointmentDate)
                    ->update([
                        'schedule_on' => $formData['date'], // Update schedule_on with the new date
                    ]);
            } catch (\Exception $e) {
                return Log::error($e);
            }
    }
    // If business_history table doesn't exist or no matching record found, just update the appointment table
    try {
       // Dynamically check and add missing columns in the appointment table
        foreach ($formData as $column => $value) {
            if (!Schema::hasColumn($appointmentTable, $column)) {
                Schema::table($appointmentTable, function ($table) use ($column) {
                    $table->string($column)->nullable(); // Add the missing column with a default type
                });
            }
        }
        // Update appointment table
        DB::table($appointmentTable)
            ->where('id', $appointmentId)
            ->update($formData);

        // Clear the cache for both appointment APIs (with and without date)
        // Handle the date format for cache deletion
        if (isset($formData['date'])) {
            // Parse the date to ensure it matches the expected "d M Y" format
            $parsedDate = Carbon::parse($formData['date']);
            $formattedDate = $parsedDate->format('d M Y'); // "24 Apr 2025"
        }    

        return response()->json(['message' => 'Appointment updated successfully.'], 200);
    } catch (\Exception $e) {
      
        return response()->json(['message' => 'Failed to update appointment.'], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/deleteAppointment",
 *     summary="Mark an appointment as deleted",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="appointment_id", type="integer", example=1)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointment marked as deleted successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointment marked as deleted successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema and appointment ID are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointment not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointment not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Failed to delete appointment.")
 *         )
 *     )
 * )
 */
public function deleteAppointment(Request $request)
{
    // Get tenant schema and appointment ID from the request
    $tenantSchema = $request->input('tenant_schema');
    $appointmentId = $request->input('appointment_id');

    // Check if tenant schema and appointment ID are provided
    if (empty($tenantSchema) || empty($appointmentId)) {
        return response()->json(['message' => 'Tenant schema and appointment ID are required.'], 400);
    }

    // Switch to the tenant's database connection
    QueryHelper::initializeConnection($tenantSchema);


    // Define the appointment table name (assuming a consistent table naming convention)
    $tableName = 'appointment';

    // Check if the table exists
    if (!Schema::hasTable($tableName)) {
        return response()->json(['message' => 'Appointment table does not exist.'], 200);
    }

    // Check if the appointment with the given ID exists
    $appointment = DB::table($tableName)->where('id', $appointmentId)->first();
    if (!$appointment) {
        return response()->json(['message' => 'Appointment not found.'], 200);
    }

    // Update status and is_deleted fields to mark the appointment as deleted
    DB::table($tableName)
        ->where('id', $appointmentId)
        ->update([
            'status' => 0,
            'is_deleted' => 1,
        ]);
    if (!empty($appointment->date)) {
        // Format the date properly (since date in DB is stored as YYYY-MM-DD)
        $parsedDate = Carbon::parse($appointment->date);
        $formattedDate = $parsedDate->format('d M Y'); // "24 Apr 2025"
        
    }

    return response()->json(['message' => 'Appointment marked as deleted successfully.'], 200);
}
/**
 * @OA\Post(
 *     path="/api/getAppointments",
 *     summary="Retrieve today's appointments",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="List of today's appointments",
 *         @OA\JsonContent(
 *             @OA\Property(property="appointments", type="array", @OA\Items(type="object"))
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Tenant schema is required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointments table not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Appointments table does not exist.")
 *         )
 *     )
 * )
 */
public function getAppointments(Request $request)
{
    // Get tenant schema from the request
    $tenantSchema = $request->input('tenant_schema');

    // Check if tenant schema is provided
    if (empty($tenantSchema)) {
        return response()->json(['message' => 'Tenant schema is required.'], 400);
    }

    // Switch to the tenant's database connection
    QueryHelper::initializeConnection($tenantSchema);
    $tableName = 'appointment';

    // Check if the table exists
    if (!Schema::hasTable($tableName)) {
        return response()->json(['message' => 'Appointments table does not exist.'], 200);
    }

    // Fetch appointments
    $appointments = DB::table($tableName)
        ->where('is_deleted', 0)
        ->orderBy('status', 'desc')
        ->orderBy('date', 'asc')
        ->get();


    if ($appointments->isEmpty()) {
        return response()->json(['message' => 'No appointments.'], 200);
    }

    return response()->json(['appointments' => $appointments], 200);
}

/**
 * @OA\Post(
 *     path="/api/getAppointmentsByDate",
 *     summary="Retrieve appointments by a specific date",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *             @OA\Property(property="date", type="string", example="25 Dec 2024")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="List of appointments for the given date",
 *         @OA\JsonContent(
 *             @OA\Property(property="appointments", type="array", @OA\Items(type="object"))
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error or incorrect date format",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Invalid date format. Please use '25 Dec 2024' format.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Appointments table not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No appointments found for the selected date.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred.")
 *         )
 *     )
 * )
 */
public function getAppointmentsByDate(Request $request)
{
    // Validate the tenant schema and date input
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'date' => 'required|string', // Accept date in the format "25 Dec 2024"
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $inputDate = $validated['date'];

    try {
        // Define the expected date format for parsing
        $expectedFormat = 'd M Y'; // Format: "25 Dec 2024"

        // Parse the input date to ensure it matches the expected format
        try {
            $parsedDate = Carbon::createFromFormat($expectedFormat, $inputDate);
        } catch (\Exception $e) {
            return response()->json(['error' => 'Invalid date format. Please use "25 Dec 2024" format.'], 400);
        }

        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);
        // Define the appointment table name
        $appointmentTable = 'appointment';

        // Format the parsed date to match the stored date format in the database
        $formattedDate = $parsedDate->format('Y-m-d'); // Format: "2024-12-25"

        // Initialize an empty collection to hold the results
        $appointments = collect();

        // Check if the appointment table exists
        if (Schema::hasTable($appointmentTable)) {
            // Fetch appointments based on the date
            $appointments = DB::table($appointmentTable)
                ->where('is_deleted', 0) // Fetch non-deleted appointments
                ->whereDate('date', $formattedDate) // Match only the date part
                ->orderBy('status', 'desc') // Order by status, showing active (status = 1) first
                ->get();
        }

        // If no appointments found, return the message
        if ($appointments->isEmpty()) {
            return response()->json(['message' => 'No appointments found for the selected date.'], 200);
        }
        // Return the appointments response
        return response()->json(['appointments' => $appointments], 200);

    } catch (\Exception $e) {
        // Return error if unexpected issues occur
        return response()->json(['error' => 'An error occurred.', 'details' => $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/tenant/marketing",
 *     summary="Retrieve marketing items for a business",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             @OA\Property(property="business_id", type="integer", example=123),
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="List of marketing items",
 *         @OA\JsonContent(
 *             @OA\Property(property="data", type="array", @OA\Items(type="object"))
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Business ID and tenant schema are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred.")
 *         )
 *     )
 * )
 */
public function getMarketingItems(Request $request)
{
    $request->validate([
        'business_id' => 'required|integer',
        'tenant_schema' => 'required|string',
    ]);

    $businessId = $request->input('business_id');
    $tenantSchema = $request->input('tenant_schema');
    try {
        QueryHelper::initializeConnection($tenantSchema);
        if (!Schema::connection('tenant')->hasTable('marketing')) {
            // Fetch from master
            $marketings = DB::connection('master_db')->table('marketings')
                ->where('status', 1)
                ->where('is_deleted', 0)
                ->get();

            // Create marketing table
            Schema::connection('tenant')->create('marketing', function (Blueprint $table) {
                $masterColumns = DB::connection('master_db')->getSchemaBuilder()->getColumnListing('marketings');
                foreach ($masterColumns as $column) {
                    $columnType = DB::connection('master_db')->getSchemaBuilder()->getColumnType('marketings', $column);
                    if ($column === 'id') {
                        $table->bigIncrements('id');
                    } elseif ($column === 'offer_list') {
                        $table->json('offer_list')->nullable();
                    } elseif ($column !== 'created_at' && $column !== 'updated_at' && $column !== 'business_id') {
                        $type = $this->mapColumnType($columnType);
                        $table->$type($column)->nullable();
                    }
                }
                $table->timestamps();
            });

            // Insert matching business_id
            foreach ($marketings as $marketing) {
                $associatedBusinessIds = explode(',', $marketing->business_id);
                if (in_array($businessId, array_map('trim', $associatedBusinessIds))) {
                    DB::connection('tenant')->table('marketing')->insert([
                        'title' => $marketing->title,
                        'subtitle' => $marketing->subtitle,
                        'description' => $marketing->description,
                        'image' => $marketing->image,
                        'offer_list' => $marketing->offer_list,
                        'summary' => $marketing->summary,
                        'location' => $marketing->location,
                        'status' => $marketing->status,
                        'is_deleted' => $marketing->is_deleted,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        // 3. After table check and insert, fetch data
        $marketings = DB::connection('tenant')->table('marketing')
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->orderBy('id', 'desc')
            ->get();

        return response()->json($marketings);

    } catch (\Exception $e) {
        return response()->json([
            'error' => 'An error occurred while retrieving marketing items.',
            'message' => $e->getMessage(),
        ], 500);
    }
}

// Helper function to map MySQL types to Laravel types
private function mapColumnType($type)
{
    switch ($type) {
        case 'varchar':
            return 'string';
        case 'text':
            return 'text';
        case 'int':
        case 'bigint':
            return 'integer';
        case 'boolean':
            return 'boolean';
        case 'json':
            return 'json';
        // Add other type mappings as necessary
        default:
            return 'string'; // Default to string if unknown
    }
}
/**
 * @OA\Post(
 *     path="/api/addMarketingItem",
 *     summary="Add a new marketing item",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\MediaType(
 *             mediaType="multipart/form-data",
 *             @OA\Schema(
 *                 required={"tenant_schema", "title"},
 *                 @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *                 @OA\Property(property="title", type="string", example="Special Offer"),
 *                 @OA\Property(property="subtitle", type="string", example="Limited Time Only", nullable=true),
 *                 @OA\Property(property="description", type="string", example="Get 50% off on all products.", nullable=true),
 *                 @OA\Property(property="image", type="string", format="binary", nullable=true),
 *                 @OA\Property(property="offer_list", type="array", @OA\Items(type="string"), example={"Buy 1 Get 1", "20% Cashback"}, nullable=true),
 *                 @OA\Property(property="summary", type="string", example="A great deal you can't miss!", nullable=true),
 *                 @OA\Property(property="location", type="string", example="New York", nullable=true)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Marketing item added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Marketing item added successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Validation failed.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred.")
 *         )
 *     )
 * )
 */
public function addMarketingItem(Request $request)
{
    // Validate incoming request
    $request->validate([
        'tenant_schema' => 'required|string',
        'title' => 'required|string',
        'subtitle' => 'nullable|string',
        'description' => 'nullable|string',
        'image' => 'nullable|image|max:2048', // Adjust max size as needed
        'offer_list' => 'nullable|array', // Validate offer_list as an array
        'summary' => 'nullable|string',
        'location' => 'nullable|string',
    ]);

    $tenantSchema = $request->input('tenant_schema');

    // Set the tenant database connection dynamically
    QueryHelper::initializeConnection($tenantSchema);

    // Check if the tenant's marketing table exists
    if (!Schema::connection('tenant')->hasTable('marketing')) {
        // Create the marketing table if it does not exist
        Schema::connection('tenant')->create('marketing', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->string('title');
            $table->string('subtitle')->nullable();
            $table->text('description')->nullable();
            $table->string('image')->nullable();
            $table->json('offer_list')->nullable(); // Store as JSON
            $table->text('summary')->nullable();
            $table->string('location')->nullable();
            $table->boolean('status')->default(1);
            $table->boolean('is_deleted')->default(0);
            $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
        });
    }

    // Handle image upload if there is an image
    $imagePath = null;
    if ($request->hasFile('image')) {
        $image = $request->file('image');
        
        // Define the path: tenant folder / marketing subfolder
        $tenantFolder = "{$tenantSchema}/marketing"; // e.g., tenants/{tenant_schema}/marketing
        
        // Store the image in the specified tenant's marketing folder
        $imagePath = $image->store($tenantFolder, 'public'); // Save in the public/tenants/{tenant_schema}/marketing folder
    }

    // Prepare the data to be inserted
    $marketingData = [
        'title' => $request->input('title'),
        'subtitle' => $request->input('subtitle'),
        'description' => $request->input('description'),
        'image' => $imagePath, // Store the path
        'offer_list' => json_encode($request->input('offer_list')), // Convert array to JSON
        'summary' => $request->input('summary'),
        'location' => $request->input('location'),
        'status' => 1, // Set default status
        'is_deleted' => 0,
    ];

    // Insert the data into the tenant's marketing table
    DB::connection('tenant')->table('marketing')->insert($marketingData);

    return response()->json(['message' => 'Marketing item added successfully.']);
}
/**
 * @OA\Post(
 *     path="/api/editMarketingItem",
 *     summary="Edit an existing marketing item",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\MediaType(
 *             mediaType="multipart/form-data",
 *             @OA\Schema(
 *                 required={"id", "tenant_schema"},
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="tenant_schema", type="string", example="tenant_123"),
 *                 @OA\Property(property="title", type="string", example="Updated Special Offer", nullable=true),
 *                 @OA\Property(property="subtitle", type="string", example="Updated Limited Time", nullable=true),
 *                 @OA\Property(property="description", type="string", example="Get 60% off on all products.", nullable=true),
 *                 @OA\Property(property="image", type="string", format="binary", nullable=true),
 *                 @OA\Property(property="offer_list", type="array", @OA\Items(type="string"), example={"Buy 2 Get 1", "30% Cashback"}, nullable=true),
 *                 @OA\Property(property="summary", type="string", example="An even better deal!", nullable=true),
 *                 @OA\Property(property="location", type="string", example="Los Angeles", nullable=true)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Marketing item updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Marketing item updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Marketing item not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Marketing item not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Validation failed.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred.")
 *         )
 *     )
 * )
 */
public function editMarketingItem(Request $request)
{
    // Validate incoming request
    $request->validate([
        'id' => 'required|integer', // Ensure ID is included in the body
        'tenant_schema' => 'required|string',
        'title' => 'nullable|string',
        'subtitle' => 'nullable|string',
        'description' => 'nullable|string',
        'image' => 'nullable|image|max:2048', // Adjust max size as needed
        'offer_list' => 'nullable|array', // Validate offer_list as an array, if provided
        'summary' => 'nullable|string',
        'location' => 'nullable|string',
    ]);

    $id = $request->input('id'); // Get the ID from the body
    $tenantSchema = $request->input('tenant_schema');

    // Set the tenant database connection dynamically
    QueryHelper::initializeConnection($tenantSchema);

    // Check if the tenant's marketing table exists
    if (!Schema::connection('tenant')->hasTable('marketing')) {
        return response()->json(['message' => 'Marketing table does not exist for this tenant.'], 200);
    }

    // Find the marketing item by ID
    $marketingItem = DB::connection('tenant')->table('marketing')->where('id', $id)->first();

    // Check if the item exists
    if (!$marketingItem) {
        return response()->json(['message' => 'Marketing item not found.'], 200);
    }

    // Prepare the data to be updated
    $marketingData = [];

    // Update only the fields that are provided in the request
    if ($request->filled('title')) {
        $marketingData['title'] = $request->input('title');
    }
    if ($request->filled('subtitle')) {
        $marketingData['subtitle'] = $request->input('subtitle');
    }
    if ($request->filled('description')) {
        $marketingData['description'] = $request->input('description');
    }
    if ($request->hasFile('image')) {
        $image = $request->file('image');
        $tenantFolder = "{$tenantSchema}/marketing";
        $marketingData['image'] = $image->store($tenantFolder, 'public');
    }
    if ($request->filled('offer_list')) {
        $marketingData['offer_list'] = json_encode($request->input('offer_list')); // Convert array to JSON
    }
    if ($request->filled('summary')) {
        $marketingData['summary'] = $request->input('summary');
    }
    if ($request->filled('location')) {
        $marketingData['location'] = $request->input('location');
    }
  // Update the marketing item in the tenant's marketing table
    DB::connection('tenant')->table('marketing')->where('id', $id)->update($marketingData);

    return response()->json(['message' => 'Marketing item updated successfully.']);
}
/**
 * @OA\Post(
 *     path="/api/deleteMarketingItem",
 *     summary="Soft delete a marketing item",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"id", "tenant_schema"},
 *             @OA\Property(property="id", type="integer", example=1),
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_123")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Marketing item deleted successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Marketing item deleted successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Validation failed.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Marketing item not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Marketing item not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred.")
 *         )
 *     )
 * )
 */
public function deleteMarketingItem(Request $request)
{
    // Validate incoming request
    $request->validate([
        'id' => 'required|integer', // Ensure ID is included in the body
        'tenant_schema' => 'required|string',
    ]);

    $id = $request->input('id'); // Get the ID from the body
    $tenantSchema = $request->input('tenant_schema');

    // Set the tenant database connection dynamically
    QueryHelper::initializeConnection($tenantSchema);

    // Update the is_deleted column to 1
    DB::connection('tenant')->table('marketing')->where('id', $id)->update(['is_deleted' => 1]);
    return response()->json(['message' => 'Marketing item deleted successfully.']);
}
/**
 * @OA\Get(
 *     path="/api/get_form",
 *     summary="Retrieve form details by name",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"business_id", "tenant_schema", "form_name"},
 *             @OA\Property(property="business_id", type="integer", example=123),
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="form_name", type="string", example="Customer Feedback"),
 *             @OA\Property(property="sub_category_id", type="integer", example=10, nullable=true),
 *             @OA\Property(property="status", type="integer", example=1, nullable=true)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Form details retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="form_name", type="string", example="Customer Feedback"),
 *             @OA\Property(property="fields", type="array", @OA\Items(
 *                 @OA\Property(property="label", type="string", example="Customer Name"),
 *                 @OA\Property(property="type", type="string", example="text"),
 *                 @OA\Property(property="values", type="array", @OA\Items(
 *                     @OA\Property(property="value", type="string", example="john doe")
 *                 ))
 *             ))
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Validation failed.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Form not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Form not found in the master database for the specified business.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="An error occurred while fetching the form data."),
 *             @OA\Property(property="error", type="string", example="Internal Server Error")
 *         )
 *     )
 * )
 */
public function getFormByName(Request $request)
{
    $validated = $request->validate([
        'business_id' => 'required|integer',
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
    ]);

    $businessId = $validated['business_id'];
    $subCategoryId = $request->input('sub_category_id');
    $tenantSchema = $validated['tenant_schema'];
    $formName = $validated['form_name'];
    $status = $request->input('status');

    try {
        // Get form details by name
        $form = FormHelper::GetFormByName($formName, $businessId, $status);
      
        if (!$form) {
            return response()->json([
                'success' => true,
                'message' => 'Form not found in the master database for the specified business.',
            ], 200);
        }

        // Process form fields
        $formFields = QueryHelper::GetFormFields(json_decode($form->form, true), $businessId, $tenantSchema, $subCategoryId);
  
        // Ensure all fields are arrays
        $formFields = json_decode(json_encode($formFields), true);

        // Transform 'values' for select fields
        $formFields = array_map(function ($field) {

            if (in_array($field['type'], ['select', 'autocomplete']) && !empty($field['values'])) {
                $field['values'] = array_map(function ($value) {
                   
                    if (isset($value['service'])) {
                        return ['value' => strtolower($value['service'])];
                    } elseif (isset($value['product_category'])) {
                        return ['value' => strtolower($value['product_category'])];
                    } elseif (isset($value['full_name'])) {
                        return ['value' => strtolower($value['full_name'])];
                    } elseif (isset($value['job_title'])) {
                        return ['value' => strtolower($value['job_title'])];
                    } elseif (isset($value['state_name'])) {
                        return ['value' => strtolower($value['state_name'])];
                    } elseif (isset($value['color_name'])) {
                        return ['value' => strtolower($value['color_name'])];
                    } elseif (isset($value['size'])) {
                        return ['value' => strtolower($value['size'])];
                    } elseif (isset($value['brand_name'])) {
                        return ['value' => strtolower($value['brand_name'])];
                    } elseif (isset($value['item_name'])) {
                        return ['value' => strtolower($value['item_name'])];
                    }
                    return $value; // Keep the structure for other cases
                }, $field['values']);
            }
            return $field;
        }, $formFields);

        // Clean form field labels
        $cleanedData = array_map(function ($item) {
            if (isset($item['label'])) {
                $item['label'] = preg_replace('/[^a-zA-Z0-9\s\/]/', '', strip_tags($item['label']));
                $item['label'] = preg_replace('/\s+/', ' ', $item['label']);
                $item['label'] = trim($item['label']);
            }
            return $item;
        }, $formFields);

        return response()->json([
            'success' => true,
            'form_name' => $formName,
            'fields' => $cleanedData,
        ]);
    } catch (\Exception $e) {
        Log::error('Error fetching form data: ' . $e->getMessage());

        return response()->json([
            'success' => false,
            'message' => 'An error occurred while fetching the form data.',
            'error' => $e->getMessage(),
        ], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/saveNote",
 *     summary="Save a customer note",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "customer_id", "customer_no"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="customer_id", type="string", example="CUST123"),
 *             @OA\Property(property="customer_no", type="string", example="9876543210"),
 *             @OA\Property(property="note", type="string", example="Customer prefers email communication.", nullable=true),
 *             @OA\Property(property="tag_list", type="string", example="vip, urgent", nullable=true)
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="Note saved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Note saved successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Validation failed.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tenant not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Tenant not found")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while saving the note. Please try again."),
 *             @OA\Property(property="details", type="string", example="SQLSTATE[...]: Error message")
 *         )
 *     )
 * )
 */
public function saveNote(Request $request)
{
    // Validate the required inputs
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'customer_id' => 'required|string',
        'customer_no' => 'required|string',
        'note' => 'nullable|string',
        'tag_list' => 'nullable|string', // New field validation
    ]);

    // Retrieve tenant schema from validated data
    $tenantSchema = $validated['tenant_schema'];

    try {
        // Check if the provided tenant schema exists in the database
        $schemaExists = DB::select("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = ?", [$tenantSchema]);

        if (empty($schemaExists)) {
            return response()->json(['error' => 'Tenant not found'], 200);
        }

        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the `customer_note` table exists, and create it if not
        if (!Schema::hasTable('customer_note')) {
            Schema::create('customer_note', function ($table) {
                $table->id();
                $table->string('customer_id');
                $table->string('customer_no');
                $table->text('note')->nullable();
                $table->text('tag_list')->nullable(); // New field
                $table->boolean('status')->default(1);
                $table->boolean('is_deleted')->default(0);
                $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            	$table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
            });
        }

        // Prepare data to insert into the `customer_note` table
        $noteData = [
            'customer_id' => $validated['customer_id'],
            'customer_no' => $validated['customer_no'],
            'note' => $validated['note'] ?? null,  // If note is not provided, set it to null
            'tag_list' => $validated['tag_list'] ?? null, // If tag_list is not provided, set it to null
            'status' => 1,
            'is_deleted' => 0,
        ];
        // Insert the note into the `customer_note` table
        DB::table('customer_note')->insert($noteData);
        return response()->json(['message' => 'Note saved successfully.'], 201);
    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred while saving the note. Please try again.', 'details' => $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/getNotes",
 *     summary="Retrieve notes for a customer",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="tenant_abc"
 *     ),
 *     @OA\Parameter(
 *         name="customer_id",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="CUST123"
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Successful retrieval of customer notes",
 *         @OA\JsonContent(
 *             @OA\Property(property="notes", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="customer_id", type="string", example="CUST123"),
 *                     @OA\Property(property="note", type="string", example="Customer prefers email communication."),
 *                     @OA\Property(property="customer_no", type="string", example="9876543210")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No notes found or tenant does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Tenant not found."),
 *             @OA\Property(property="message", type="string", example="No notes found for this customer.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while retrieving notes. Please try again.")
 *         )
 *     )
 * )
 */
public function getNotes(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'customer_id' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $customerId = $validated['customer_id'];

    try {
        QueryHelper::initializeConnection($tenantSchema);

        if (!Schema::hasTable('customer_note')) {
            return response()->json(['error' => 'Customer note table does not exist.'], 200);
        }

        // Fetch **ALL notes** for the tenant (NOT only customer)
        $allNotes = DB::table('customer_note')
            ->select('id', 'customer_id', 'note', 'customer_no')
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->get();

        if ($allNotes->isEmpty()) {
            return response()->json(['message' => 'No notes found for this tenant.'], 200);
        }
        // Step 4: Now filter by customer_id
        $filteredNotes = $allNotes->filter(function ($note) use ($customerId) {
            return $note->customer_id == $customerId;
        })->values();

        if ($filteredNotes->isEmpty()) {
            return response()->json(['message' => 'No notes found for this customer.'], 200);
        }

        return response()->json(['notes' => $filteredNotes], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred while retrieving notes. Please try again.'], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/editNote",
 *     summary="Edit an existing customer note",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "note_id"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="note_id", type="integer", example=1),
 *             @OA\Property(property="note", type="string", example="Updated note content."),
 *             @OA\Property(property="tag_list", type="string", example="important, follow-up")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Note updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Note updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="No data to update",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Nothing to update.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No matching note found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No matching note found to update.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while updating the note. Please try again."),
 *             @OA\Property(property="details", type="string", example="Exception message here")
 *         )
 *     )
 * )
 */
public function editNote(Request $request)
{
    // Validate the required fields in the request
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'note_id' => 'required|integer',
        'note' => 'nullable|string',
        'tag_list' => 'nullable|string', // `tag_list` validation, it can be null
    ]);

    // Get the tenant schema and note ID
    $tenantSchema = $validated['tenant_schema'];
    $noteId = $validated['note_id'];

    // Initialize the update data array
    $updateData = [];

    // Add fields to the update array only if they are provided
    if (isset($validated['note'])) {
        $updateData['note'] = $validated['note'];
    }

    if (isset($validated['tag_list'])) {
        $updateData['tag_list'] = $validated['tag_list'];
    }

    // Ensure there is something to update
    if (empty($updateData)) {
        return response()->json(['message' => 'Nothing to update.'], 400);
    }

    try {
        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);

        // Update the note content and/or tag_list based on the note ID
        $updatedRows = DB::table('customer_note')
            ->where('id', $noteId)
            ->update($updateData);

        // Check if the update was successful
        if ($updatedRows === 0) {
            return response()->json(['message' => 'No matching note found to update.'], 200);
        }
        // Return success response
        return response()->json(['message' => 'Note updated successfully.'], 200);

    } catch (\Exception $e) {
        // Handle errors
        return response()->json(['error' => 'An error occurred while updating the note. Please try again.', 'details' => $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/deleteNote",
 *     summary="Soft delete a customer note",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "note_id"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="note_id", type="integer", example=1)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Note deleted successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Note deleted successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while deleting the note. Please try again.")
 *         )
 *     )
 * )
 */
public function deleteNote(Request $request)
{
    // Validate the required fields in the request
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'note_id' => 'required|integer',
    ]);

    // Get the tenant schema and note ID from the validated request
    $tenantSchema = $validated['tenant_schema'];
    $noteId = $validated['note_id'];

    try {
        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);


        // Update the note to mark it as deleted (set status=0, is_deleted=1)
        DB::table('customer_note')
            ->where('id', $noteId)
            ->update([
                'status' => 0,  // Mark as inactive
                'is_deleted' => 1,
            ]);
        // Return success response
        return response()->json(['message' => 'Note deleted successfully.'], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred while deleting the note. Please try again.'], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/saveBusinessHistory",
 *     summary="Save business history and dynamically create/update tables",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "form_name"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="form_name", type="string", example="business_form"),
 *             @OA\Property(property="current_status", type="string", example="Schedule"),
 *             @OA\Property(property="schedule_on", type="string", format="date", example="2025-04-10"),
 *             @OA\Property(property="customer_no", type="string", example="9876543210"),
 *             @OA\Property(property="customer_id", type="integer", example=101)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Status saved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Status saved successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred: Table already exists.")
 *         )
 *     )
 * )
 */
public function saveBusinessHistory(Request $request)
{
    // Validate form_name and tenant_schema
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
    ]);

    // Get the tenant schema and sanitize form name
    $tenantSchema = $validated['tenant_schema'];
    $formName = $validated['form_name'];

    // Replace spaces with underscores and convert to lowercase
    $tableName = strtolower(Str::slug($formName, '_'));

    try {
        // Switch to the tenant's database connection
        QueryHelper::initializeConnection($tenantSchema);

        // Get the form fields from the request (excluding standard keys)
        $formFields = array_keys($request->except(['tenant_schema', 'form_name']));

        if (!Schema::hasTable($tableName)) {
            // Create the table with dynamic columns before standard columns
            Schema::create($tableName, function (Blueprint $table) use ($formFields) {
                $table->id();

                // Add dynamic columns first
                foreach ($formFields as $field) {
                    $table->string($field)->nullable();
                }

                // Add standard columns last
                $table->boolean('status')->default(1);
                $table->boolean('is_deleted')->default(0);
                $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            	$table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
            });

        } else {
            // Add new columns dynamically if the table exists
            $existingColumns = Schema::getColumnListing($tableName);
            Schema::table($tableName, function (Blueprint $table) use ($formFields, $existingColumns) {
                foreach ($formFields as $field) {
                    if (!in_array($field, $existingColumns)) {
                        $table->string($field)->nullable()->before('status'); // Position new columns before 'status'
                    }
                }
            });
        }

        // Insert the form data into the table
        $tableColumns = Schema::getColumnListing($tableName);
        $formData = $request->only($tableColumns);
        DB::table($tableName)->insert(array_merge($formData));

        // If current_status is "Schedule," handle the appointment table
        if ($request->input('current_status') === 'Schedule') {
            $appointmentTableName = 'appointment'; // Define the table name explicitly

            // Extract payload data for the appointment table
            $payloadData = $request->except(['tenant_schema', 'form_name']);

            // Map specific payload fields to existing columns
            if (isset($payloadData['schedule_on'])) {
                $payloadData['date'] = $payloadData['schedule_on'];
                unset($payloadData['schedule_on']);
            }

            if (isset($payloadData['customer_no'])) {
                $payloadData['phone'] = $payloadData['customer_no'];
                unset($payloadData['customer_no']);
            }

            // Check if the appointment table exists, if not, create it
            if (!Schema::hasTable($appointmentTableName)) {
                Schema::create($appointmentTableName, function (Blueprint $table) {
                    $table->id();
                    $table->string('name')->nullable();
                    $table->string('phone')->nullable();
                    $table->string('date')->nullable();
                    $table->boolean('status')->default(1);
                    $table->boolean('is_deleted')->default(0);
                    $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
            		$table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
                });
            }

            // Add missing columns dynamically if the table already exists
            $existingColumns = Schema::getColumnListing($appointmentTableName);
            Schema::table($appointmentTableName, function (Blueprint $table) use ($payloadData, $existingColumns) {
                foreach (array_keys($payloadData) as $field) {
                    if (!in_array($field, $existingColumns)) {
                        $table->string($field)->nullable();
                    }
                }
            });

            // Insert the payload data into the appointment table
            DB::table($appointmentTableName)->insert(array_merge($payloadData));
        }
            // If current_status is "Service" or "ProductPurchased," update the customers table
              if ($request->input('current_status') === 'Service/ProductPurchased') {
                  $customerId = $request->input('customer_id');
                  $customersTable = 'customers'; // Define the table name explicitly

                  // Check if the customers table exists
                  if (Schema::hasTable($customersTable)) {
                      // Update the 'group' column for the matching customer ID
                      DB::table($customersTable)
                          ->where('id', $customerId)
                          ->update(['group' => 'Customer']);
                  }
              }

        return response()->json(['message' => 'Status saved successfully.'], 200);
    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/getBusinessHistory",
 *     summary="Retrieve business history and related data",
 *     tags={"Tenants"},
 *     security={{ "bearerAuth": {} }},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "customer_id", "customer_no", "business_id"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_abc"),
 *             @OA\Property(property="customer_id", type="string", example="101"),
 *             @OA\Property(property="customer_no", type="string", example="9876543210"),
 *             @OA\Property(property="business_id", type="string", example="B12345")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Business history and related data retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Business history and related data retrieved successfully."),
 *             @OA\Property(property="notes", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="customer_id", type="string", example="101"),
 *                     @OA\Property(property="note", type="string", example="Follow-up scheduled."),
 *                     @OA\Property(property="tag_list", type="string", example="Follow-up, Important"),
 *                     @OA\Property(property="customer_no", type="string", example="9876543210"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-05 10:30:00")
 *                 )
 *             ),
 *             @OA\Property(property="business_history", type="object",
 *                 @OA\Property(property="current_status", type="object",
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="current_status", type="string", example="Scheduled"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-01 15:00:00")
 *                 ),
 *                 @OA\Property(property="previous_status", type="object",
 *                     @OA\Property(property="id", type="integer", example=2),
 *                     @OA\Property(property="current_status", type="string", example="Pending"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-03-30 14:00:00")
 *                 )
 *             ),
 *             @OA\Property(property="customer", type="object",
 *                 @OA\Property(property="id", type="integer", example=101),
 *                 @OA\Property(property="name", type="string", example="John Doe"),
 *                 @OA\Property(property="mobile", type="string", example="9876543210")
 *             ),
 *             @OA\Property(property="purchased_items_services", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=5),
 *                     @OA\Property(property="visited_for", type="string", example="Product A"),
 *                     @OA\Property(property="current_status", type="string", example="Service/ProductPurchased"),
 *                     @OA\Property(property="purchased_on", type="string", format="date", example="2025-03-28"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-03-28 16:00:00"),
 *                     @OA\Property(property="type", type="string", example="item")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Unexpected server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred: Table does not exist.")
 *         )
 *     )
 * )
 */
public function getBusinessHistory(Request $request)
{
    // Validate required inputs
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'customer_id' => 'required|string',
        'customer_no' => 'required|string',
        'business_id' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $customerId = $validated['customer_id'];
    $customerNo = $validated['customer_no'];
    $businessId = $validated['business_id'];

    try {
        // Step 1: Switch to the tenant's schema
        QueryHelper::initializeConnection($tenantSchema);

        // Step 2: Check if necessary tables exist
        $customerNoteExists = Schema::hasTable('customer_note');
        $businessHistoryExists = Schema::hasTable('business_history');
        $customersTableExists = Schema::hasTable('customers');

        // Initialize response data
        $notes = [];
        $currentStatus = null;
        $previousStatus = null;
        $customer = null;
        $purchasedItemsServices = [];

        // Step 3: Fetch Notes if table exists
        if ($customerNoteExists) {
            $notes = DB::table('customer_note')
                ->select('id', 'customer_id', 'note', 'tag_list', 'customer_no', 'created_at')
                ->where('customer_id', $customerId)
                ->where('status', 1)
                ->where('is_deleted', 0)
                ->get();
        }

        // Step 4: Fetch Business History if table exists
        if ($businessHistoryExists) {
            $businessHistory = DB::table('business_history')
                ->where('customer_id', $customerId)
                ->where('status', 1)
                ->where('is_deleted', 0)
                ->orderBy('created_at', 'desc')
                ->limit(2)
                ->get();

            $currentStatus = $businessHistory->first();
            $previousStatus = $businessHistory->count() > 1 ? $businessHistory->get(1) : null;

            // Transform current and previous statuses
            if ($currentStatus) {
                $currentStatus = $this->transformStatus($currentStatus);
            }
            if ($previousStatus) {
                $previousStatus = $this->transformStatus($previousStatus);
            }
        }

        // Step 5: Fetch Customer Details if table exists
        if ($customersTableExists) {
            $customer = DB::table('customers')
                ->where('mobile', $customerNo)
                ->where('status', 1)
                ->where('is_deleted', 0)
                ->first();
        }

        // Step 6: Fetch Purchased Items and Services if business_history exists
        if ($businessHistoryExists) {
            // Check if the 'visited_for' column exists in the 'business_history' table
            $visitedForExists = Schema::hasColumn('business_history', 'visited_for');

            if ($visitedForExists) {
                // Fetch product categories from 'visited_for' column
                $productCategories = DB::table('business_history')
                    ->where('current_status', 'Service/ProductPurchased')
                    ->where('customer_id', $customerId)
                    ->pluck('visited_for')
                    ->unique();

                foreach ($productCategories as $productCategory) {
                    DB::setDefaultConnection('master_db');
                    $type = DB::table('sales_and_services')
                        ->where('business_id', $businessId)
                        ->where('product_category', $productCategory)
                        ->value('type');

                    DB::setDefaultConnection('tenant');
                    if (!$type) continue;

                    // Fetch purchased items
                    $items = DB::table('business_history')
                        ->select('id', 'visited_for', 'current_status', 'purchased_on', 'created_at')
                        ->where('current_status', 'Service/ProductPurchased')
                        ->where('visited_for', $productCategory)
                        ->where('customer_id', $customerId)
                        ->get()
                        ->map(function ($item) use ($type) {
                            $item->type = 'item';
                            return $item;
                        });

                    $purchasedItemsServices = array_merge($purchasedItemsServices, $items->toArray());
                }
            } else {
                // If the column does not exist, set purchased items and services data to null
                $purchasedItemsServices = [];
            }

            // Fetch purchased services if the 'visited_for' column exists
            if ($visitedForExists) {
                $services = DB::table('business_history')
                    ->where('current_status', 'Service/ProductPurchased')
                    ->where('customer_id', $customerId)
                    ->pluck('visited_for')
                    ->unique();

                foreach ($services as $service) {
                    DB::setDefaultConnection('master_db');
                    $type = DB::table('sales_and_services')
                        ->where('business_id', $businessId)
                        ->where('service', $service)
                        ->value('type');

                    DB::setDefaultConnection('tenant');
                    if (!$type) continue;

                    // Fetch purchased services
                    $serviceData = DB::table('business_history')
                        ->select('id', 'visited_for', 'current_status', 'purchased_on', 'created_at')
                        ->where('current_status', 'Service/ProductPurchased')
                        ->where('visited_for', $service)
                        ->where('customer_id', $customerId)
                        ->get()
                        ->map(function ($serviceItem) {
                            $serviceItem->type = 'service';
                            return $serviceItem;
                        });

                    $purchasedItemsServices = array_merge($purchasedItemsServices, $serviceData->toArray());
                }
            }
        }

        // Step 7: Compile All Data
        return response()->json([
            'message' => 'Business history and related data retrieved successfully.',
            'notes' => $notes,
            'business_history' => [
                'current_status' => $currentStatus,
                'previous_status' => $previousStatus,
            ],
            'customer' => $customer,
            'purchased_items_services' => $purchasedItemsServices,
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}

/**
 * Transform Status to replace specific date fields with 'date'.
 */
private function transformStatus($status)
{
    // List of date fields to check
    $dateFields = ['hold_till', 'purchased_on', 'follow_up_on', 'schedule_on'];

    foreach ($dateFields as $field) {
        if (!empty($status->$field)) {
            // Replace the field with 'date'
            $status->date = $status->$field;
            unset($status->$field);
            break; // Only one date field will be replaced
        }
    }

    return $status;
}
/**
 * @OA\Post(
 *     path="/api/getBusinessHistoryList",
 *     summary="Retrieve business history list",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema"},
 *              @OA\Property(property="tenant_schema", type="string", example="testing_tenant", description="Schema name of the tenant"),
 *         @OA\Property(property="is_filter", type="integer", nullable=true, example=1, description="Optional: 1 to filter employee-specific contacts, 0 otherwise"),
 *         @OA\Property(property="emp_id", type="integer", nullable=true, example=1, description="Optional: Employee ID when filtering employee-specific data, else 0"),
 *         @OA\Property(property="from_date", type="string", format="date", example="2025-04-05", description="Start date for filtering business history"),
 *         @OA\Property(property="to_date", type="string", format="date", example="2025-04-05", description="End date for filtering business history")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Successful retrieval of business history",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Data retrieved successfully."),
 *             @OA\Property(
 *                 property="business_history",
 *                 type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="group_name", type="array", @OA\Items(
 *                         @OA\Property(property="customer_id", type="integer", example=123),
 *                         @OA\Property(property="mobile", type="string", example="9876543210"),
 *                         @OA\Property(property="name", type="string", example="John Doe"),
 *                         @OA\Property(property="profile_pic", type="string", example="profile.jpg"),
 *                         @OA\Property(property="current_status", type="string", example="Active"),
 *                         @OA\Property(property="last_visit", type="string", format="date", example="2024-01-15"),
 *                         @OA\Property(property="last_connected", type="string", format="datetime", example="2024-01-20 10:30:00"),
 *                         @OA\Property(property="follow_up_time", type="integer", example=12)
 *                     ))
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(response=400, description="Bad request"),
 *     @OA\Response(response=500, description="Server error")
 * )
 */
// public function getBusinessHistoryList(Request $request)
// {
  	
//     if ($request->attributes->get('useEnterpriseMethod')) {
//         return $this->getEnterpriseBusinessHistoryList($request);
//     }

//     $validated = $request->validate([
//         'tenant_schema' => 'required|string',
//         'from_date' => 'nullable|date_format:Y-m-d',
//         'to_date' => 'nullable|date_format:Y-m-d',
//     ]);

//     $tenantSchema = $validated['tenant_schema'];
 	
//     $fromDate = $request->input('from_date', null);
//     $toDate = $request->input('to_date', null);

//     if (!$request->input('group_name')) {
//         $groupNames = DB::table('contact_groups')
//             ->select('name')
//             ->where('status', 1)
//             ->where('is_deleted', 0)
//             ->pluck('name');
//     } else {
//         $groupNames = collect($request->input('group_name'));
//     }

//     $results = [];

//     foreach ($groupNames as $name) {
//         $methodName = DB::connection('master_db')->table('query_mapping')
//             ->where('group_name', $name)
//             ->value('method_name');

//         $customerIds = [];

//         try {
//             $result = QueryHelper::processRule($methodName, $name, $tenantSchema, $fromDate, $toDate);

//             if (is_array($result)) {
//                 $customerIds = array_map(fn($item) => $item->customer_id ?? $item->id ?? null, $result);
//             } elseif ($result instanceof \Illuminate\Support\Collection) {
//                 $customerIds = $result->pluck('customer_id')->toArray();
//             } elseif ($result instanceof \stdClass && (property_exists($result, 'customer_id') || property_exists($result, 'id'))) {
//                 $customerIds = [$result->customer_id ?? $result->id];
//             }

//             $customerIds = array_filter($customerIds);
//         } catch (\Exception $e) {
//             $customerIds = [];
//         }

//         try {
//             QueryHelper::initializeConnection($tenantSchema);

//             if (empty($customerIds)) {
//                 $results[] = [$name => []];
//                 continue;
//             }

//             $businessHistoryTableExists = Schema::hasTable('business_history');
//             $callHistoryTableExists = Schema::hasTable('call_history');

//             $businessHistoryQuery = $businessHistoryTableExists ? "
//                 WITH ranked_business_history AS (
//                     SELECT
//                         bh.customer_id,
//                         bh.current_status,
//                         " . (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'NULL AS purchased_on') . ",
//                         ROW_NUMBER() OVER (PARTITION BY bh.customer_id ORDER BY " .
//                         (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'bh.id') . " DESC) AS rn
//                     FROM {$tenantSchema}.business_history bh
//                     WHERE bh.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 )
//             " : "WITH ranked_business_history AS (SELECT NULL AS customer_id, NULL AS current_status, NULL AS purchased_on, 1 AS rn)";

//             $callHistoryQuery = $callHistoryTableExists ? "
//                 , ranked_call_history AS (
//                     SELECT
//                         ch.customer_id,
//                         ch.call_type as callType,
//                         ch.timestamp AS call_timestamp,
//                         ROW_NUMBER() OVER (PARTITION BY ch.customer_id ORDER BY ch.timestamp DESC) AS rn
//                     FROM {$tenantSchema}.call_history ch
//                     WHERE ch.call_type IN ('CallType.incoming', 'CallType.outgoing', 'callType.wifiIncoming', 'CallType.wifiOutgoing') 
//                     AND ch.duration > 0
//                     AND ch.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 )
//             " : ", ranked_call_history AS (SELECT NULL AS customer_id, NULL AS call_type, NULL AS call_timestamp, 1 AS rn)";
//             $query = "
//                 $businessHistoryQuery
//                 $callHistoryQuery
//                 SELECT DISTINCT
//                     c.id AS customer_id,
//                     c.mobile AS mobile,
//                     c.name AS name,
//                     c.source AS source,
//                     rch.callType,
//                     c.profile_pic AS profile_pic,
//                     COALESCE(rbh.current_status, NULL) AS current_status,
//                     COALESCE(rbh.purchased_on, NULL) AS last_visit,
//                     COALESCE(rch.call_timestamp, NULL) AS last_connected,
//                     COALESCE(rch.call_type, NULL) AS call_type,
//                     CASE 
//                         WHEN rch.call_timestamp IS NOT NULL THEN TIMESTAMPDIFF(hour, rch.call_timestamp, NOW())
//                         ELSE NULL
//                     END AS follow_up_time
//                 FROM {$tenantSchema}.customers c
//                 LEFT JOIN ranked_business_history rbh
//                     ON c.id = rbh.customer_id AND rbh.rn = 1
//                 LEFT JOIN ranked_call_history rch
//                     ON c.id = rch.customer_id AND rch.rn = 1
//                 WHERE c.id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 ORDER BY follow_up_time DESC;
//             ";

//             $groupResults = DB::select($query);
//         } catch (\Exception $e) {
//             $groupResults = [];
//         }

//         $results[] = [$name => $groupResults ?: []];
//     }

   

//    foreach ($results as $key => $value) {
//         foreach ($value as $category => $data) {
//             if($category == "Status Not Updated"){
//                 unset($results[$key]);
//                 break; // exit inner loop after unsetting
//             }
//         }
//     }
//     $results = collect($results)
//         ->partition(fn($group) => !empty(array_values($group)[0]))
//         ->flatten(1)
//         ->all();
//     return response()->json([
//         'message' => 'Data retrieved successfully.',
//         'business_history' => $results,
//     ], 200);
// }

public function getBusinessHistoryList(Request $request)
{
    if ($request->attributes->get('useEnterpriseMethod')) {
        return $this->getEnterpriseBusinessHistoryList($request);
    }

    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'from_date' => 'nullable|date_format:Y-m-d',
        'to_date' => 'nullable|date_format:Y-m-d',
    ]);

    $tenantSchema = $validated['tenant_schema'];

    $fromDate = $request->input('from_date', null);
    $toDate = $request->input('to_date', null);

    if (!$request->input('group_name')) {
        $groupNames = DB::table('contact_groups')
            ->select('name')
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->pluck('name');
    } else {
        $groupNames = collect($request->input('group_name'));
    }

    $results = [];

    foreach ($groupNames as $name) {
        $methodName = DB::connection('master_db')->table('query_mapping')
            ->where('group_name', $name)
            ->value('method_name');

        $customerIds = [];

        try {
            $result = QueryHelper::processRule($methodName, $name, $tenantSchema, $fromDate, $toDate);

            if (is_array($result)) {
                $customerIds = array_map(fn($item) => $item->customer_id ?? $item->id ?? null, $result);
            } elseif ($result instanceof \Illuminate\Support\Collection) {
                $customerIds = $result->pluck('customer_id')->toArray();
            } elseif ($result instanceof \stdClass && (property_exists($result, 'customer_id') || property_exists($result, 'id'))) {
                $customerIds = [$result->customer_id ?? $result->id];
            }

            $customerIds = array_filter($customerIds);
        } catch (\Exception $e) {
            $customerIds = [];
        }

        try {
            QueryHelper::initializeConnection($tenantSchema);

            if (empty($customerIds)) {
                $results[] = [$name => []];
                continue;
            }

            $businessHistoryTableExists = Schema::hasTable('business_history');

            $businessHistoryQuery = $businessHistoryTableExists ? "
                WITH ranked_business_history AS (
                    SELECT
                        bh.customer_id,
                        bh.current_status,
                        " . (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'NULL AS purchased_on') . ",
                        ROW_NUMBER() OVER (PARTITION BY bh.customer_id ORDER BY " .
                        (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'bh.id') . " DESC) AS rn
                    FROM {$tenantSchema}.business_history bh
                    WHERE bh.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
                )
            " : "WITH ranked_business_history AS (SELECT NULL AS customer_id, NULL AS current_status, NULL AS purchased_on, 1 AS rn)";

            // Removed callHistoryQuery completely
            $query = "
                $businessHistoryQuery
                SELECT DISTINCT
                    c.id AS customer_id,
                    c.mobile AS mobile,
                    c.name AS name,
                    c.source AS source,
                    c.profile_pic AS profile_pic,
                    COALESCE(rbh.current_status, NULL) AS current_status,
                    COALESCE(rbh.purchased_on, NULL) AS last_visit
                FROM {$tenantSchema}.customers c
                LEFT JOIN ranked_business_history rbh
                    ON c.id = rbh.customer_id AND rbh.rn = 1
                WHERE c.id IN (" . implode(',', array_map('intval', $customerIds)) . ")
                ORDER BY c.id DESC;
            ";

            $groupResults = DB::select($query);
        } catch (\Exception $e) {
            $groupResults = [];
        }

        $results[] = [$name => $groupResults ?: []];
    }

    // Remove "Status Not Updated" groups
    foreach ($results as $key => $value) {
        foreach ($value as $category => $data) {
            if ($category === "Status Not Updated") {
                unset($results[$key]);
                break;
            }
        }
    }

    // Remove empty groups and reindex
    $results = collect($results)
        ->partition(fn($group) => !empty(array_values($group)[0]))
        ->flatten(1)
        ->all();

    return response()->json([
        'message' => 'Data retrieved successfully.',
        'business_history' => $results,
    ], 200);
}
public function getEnterpriseBusinessHistoryList(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'from_date' => 'nullable|date_format:Y-m-d',
        'to_date' => 'nullable|date_format:Y-m-d', 
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $fromDate = $request->input('from_date', null);
    $toDate = $request->input('to_date', null); 
    $empIdFilter = $request->input('emp_id');
    $isFilter = $request->input('is_filter');

    // Get all group names
    if (!$request->input('group_name')) {
        $groupNames = DB::table('contact_groups')
            ->select('name')
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->pluck('name');
    } else {
        $groupNames = collect($request->input('group_name'));
    }

    // Exclude 'Family' and 'Friend' if emp_id is provided
    if ($empIdFilter) {
        $groupNames = $groupNames->reject(fn($name) => in_array($name, ['Family', 'Friend']));
    }

    $results = [];

    foreach ($groupNames as $name) {
        $methodName = DB::connection('master_db')->table('query_mapping')
            ->where('group_name', $name)
            ->value('method_name');

        $customerIds = [];

        try {
            $result = QueryHelper::processRule($methodName, $name, $tenantSchema, $fromDate, $toDate);

            if (is_array($result)) {
                $customerIds = array_map(fn($item) => $item->customer_id ?? $item->id ?? null, $result);
            } elseif ($result instanceof \Illuminate\Support\Collection) {
                $customerIds = $result->pluck('customer_id')->toArray();
            } elseif ($result instanceof \stdClass && (property_exists($result, 'customer_id') || property_exists($result, 'id'))) {
                $customerIds = [$result->customer_id ?? $result->id];
            }

            $customerIds = array_filter($customerIds);
        } catch (\Exception $e) {
            $customerIds = [];
        }

        try {
            QueryHelper::initializeConnection($tenantSchema);

            if (empty($customerIds)) {
                $results[] = [
                    $name => []
                ];
                continue;
            }

            $businessHistoryTableExists = Schema::hasTable('business_history');

            $businessHistoryQuery = $businessHistoryTableExists ? "
                WITH ranked_business_history AS (
                    SELECT
                        bh.customer_id,
                        bh.current_status,
                        " . (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'NULL AS purchased_on') . ",
                        ROW_NUMBER() OVER (PARTITION BY bh.customer_id ORDER BY " .
                        (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'bh.id') . " DESC) AS rn
                    FROM {$tenantSchema}.business_history bh
                    WHERE bh.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
                )
            " : "WITH ranked_business_history AS (SELECT NULL AS customer_id, NULL AS current_status, NULL AS purchased_on, 1 AS rn)";

            $query = "
                $businessHistoryQuery
                SELECT DISTINCT
                    c.id AS customer_id,
                    c.mobile AS mobile,
                    c.name AS name,
                    c.profile_pic AS profile_pic,
                    COALESCE(rbh.current_status, NULL) AS current_status,
                    COALESCE(rbh.purchased_on, NULL) AS last_visit
                FROM {$tenantSchema}.customers c
                LEFT JOIN ranked_business_history rbh
                    ON c.id = rbh.customer_id AND rbh.rn = 1
                WHERE c.id IN (" . implode(',', array_map('intval', $customerIds)) . ")
                ORDER BY c.id DESC;
            ";

            $groupResults = DB::select($query);
        } catch (\Exception $e) {
            $groupResults = [];
        }

        $results[] = [
            $name => $groupResults ?: []
        ];
    }

    // Enrich customers if needed
    DataHelper::enrichCustomersWithEmpDetails($results, $empIdFilter, $isFilter);

    // Remove "Status Not Updated" groups
    foreach ($results as $key => $value) {
        foreach ($value as $category => $data) {
            if ($category === "Status Not Updated") {
                unset($results[$key]);
                break;
            }
        }
    }

    // Remove empty groups and reindex
    $results = collect($results)
        ->partition(fn($group) => !empty(array_values($group)[0]))
        ->flatten(1)
        ->all();

    return response()->json([
        'message' => 'Data retrieved successfully.',
        'business_history' => $results,
    ], 200);
}

// public function getEnterpriseBusinessHistoryList(Request $request)
// {
//     $validated = $request->validate([
//         'tenant_schema' => 'required|string',
//         'from_date' => 'nullable|date_format:Y-m-d', // Validate the from_date
//         'to_date' => 'nullable|date_format:Y-m-d', 
//     ]);

//     $tenantSchema = $validated['tenant_schema'];
//     $fromDate = $request->input('from_date', null);
//     $toDate = $request->input('to_date', null); 
//     $empIdFilter = $request->input('emp_id');
//     $isFilter = $request->input('is_filter');

//     // Get all group names
//     if (!$request->input('group_name')) {
//         $groupNames = DB::table('contact_groups')
//             ->select('name')
//             ->where('status', 1)
//             ->where('is_deleted', 0)
//             ->pluck('name'); // Get only names as a collection
//     } else {
//         $groupNames = collect($request->input('group_name')); // Ensure it's a collection
//     }
  
//     // Exclude 'Family' and 'Friend' if emp_id is provided
//     if ($empIdFilter) {
//         $groupNames = $groupNames->reject(fn($name) => in_array($name, ['Family', 'Friend']));
//     }

//     $results = [];

//     foreach ($groupNames as $name) {
//         // Get method name for the group
//         $methodName = DB::connection('master_db')->table('query_mapping')
//             ->where('group_name', $name)
//             ->value('method_name');

//         $customerIds = [];

//         try { 
//           // Process rules and fetch customer IDs
          
//             $result = QueryHelper::processRule($methodName, $name, $tenantSchema, $fromDate, $toDate);

//             if (is_array($result)) {
//                 $customerIds = array_map(fn($item) => $item->customer_id ?? $item->id ?? null, $result);
//             } elseif ($result instanceof \Illuminate\Support\Collection) {
//                 $customerIds = $result->pluck('customer_id')->toArray();
//             } elseif ($result instanceof \stdClass && (property_exists($result, 'customer_id') || property_exists($result, 'id'))) {
//                 $customerIds = [$result->customer_id ?? $result->id];
//             }

//             // Remove null values from IDs
//             $customerIds = array_filter($customerIds);

//         } catch (\Exception $e) {
//             // Handle exceptions for rule processing
//             $customerIds = []; // Default to empty if rule fails
//         }

//         try {
//             // Initialize tenant schema connection
//             QueryHelper::initializeConnection($tenantSchema);

//             // If no customer IDs are found for the group, return an empty array
//             if (empty($customerIds)) {
//                 $results[] = [
//                     $name => []
//                 ];
//                 continue;
//             }

//             // Check table existence
//             $businessHistoryTableExists = Schema::hasTable('business_history');
//             $callHistoryTableExists = Schema::hasTable('call_history');

//             // Build the queries conditionally
//             $businessHistoryQuery = $businessHistoryTableExists ? "
//                 WITH ranked_business_history AS (
//                     SELECT
//                         bh.customer_id,
//                         bh.current_status,
//                         " . (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'NULL AS purchased_on') . ",
//                         ROW_NUMBER() OVER (PARTITION BY bh.customer_id ORDER BY " . 
//                         (Schema::hasColumn('business_history', 'purchased_on') ? 'bh.purchased_on' : 'bh.id') . " DESC) AS rn
//                     FROM {$tenantSchema}.business_history bh
//                     WHERE bh.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 )
//             " : "WITH ranked_business_history AS (SELECT NULL AS customer_id, NULL AS current_status, NULL AS purchased_on, 1 AS rn)";

//             $callHistoryQuery = $callHistoryTableExists ? "
//                 ranked_call_history AS (
//                     SELECT
//                         ch.customer_id,
//                         ch.call_type as callType,
//                         ch.timestamp AS call_timestamp,
//                         ROW_NUMBER() OVER (PARTITION BY ch.customer_id ORDER BY ch.timestamp DESC) AS rn
//                     FROM {$tenantSchema}.call_history ch
//                     WHERE ch.call_type IN ('CallType.incoming', 'CallType.outgoing', 'callType.wifiIncoming', 'CallType.wifiOutgoing') AND ch.duration > 0
//                     AND ch.customer_id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 )
//             " : "ranked_call_history AS (SELECT NULL AS customer_id, NULL AS call_type, NULL AS call_timestamp, 1 AS rn)";
 
//             $query = "
//                 $businessHistoryQuery,
//                 $callHistoryQuery
//                 SELECT DISTINCT
//                     c.id AS customer_id,
//                     c.mobile AS mobile,
//                     c.name AS name,
//                     c.profile_pic AS profile_pic,
//                     rch.callType,
//                     COALESCE(rbh.current_status, NULL) AS current_status,
//                     COALESCE(rbh.purchased_on, NULL) AS last_visit,
//                     COALESCE(rch.call_timestamp, NULL) AS last_connected,

//                     CASE 
//                         WHEN rch.call_timestamp IS NOT NULL THEN TIMESTAMPDIFF(hour, rch.call_timestamp, NOW())
//                         ELSE NULL
//                     END AS follow_up_time
//                 FROM {$tenantSchema}.customers c
//                 LEFT JOIN ranked_business_history rbh
//                     ON c.id = rbh.customer_id AND rbh.rn = 1
//                 LEFT JOIN ranked_call_history rch
//                     ON c.id = rch.customer_id AND rch.rn = 1
//                 WHERE c.id IN (" . implode(',', array_map('intval', $customerIds)) . ")
//                 ORDER BY follow_up_time DESC;
//             ";
//             // Execute query and store results
//             $groupResults = DB::select($query);
//         } catch (\Exception $e) {
//             // Handle exceptions for query execution
//             $groupResults = []; // Return empty result for the group
//         }

//         // Add group results to the response format
//         $results[] = [
//             $name => $groupResults ?: []
//         ];
//     }
//     DataHelper::enrichCustomersWithEmpDetails($results, $empIdFilter, $isFilter);
//     // Prioritize the first non-empty group
    
//     // Return final results
//    foreach ($results as $key => $value) {
//         foreach ($value as $category => $data) {
          
//             if($category == "Status Not Updated"){
//                  unset($results[$key]);
//                  break; // exit inner loop after unsetting
//             }
//         }
//     }
//      $results = collect($results)
//           ->partition(fn($group) => !empty(array_values($group)[0]))
//           ->flatten(1)
//           ->all();
//     return response()->json([
//         'message' => 'Data retrieved successfully.',
//         'business_history' => $results,
//     ], 200);
// }
/**
 * @OA\Get(
 *     path="/api/getPurchasedItems",
 *     summary="Retrieve purchased items for a customer",
 *     description="Fetches all purchased items for a given customer based on their purchase history.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"business_id", "tenant_schema", "customer_id"},
 *             @OA\Property(property="business_id", type="integer", example=1, description="Business ID"),
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db", description="Tenant database schema"),
 *             @OA\Property(property="customer_id", type="integer", example=123, description="Customer ID")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Purchased items retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Purchased items retrieved successfully."),
 *             @OA\Property(property="data", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="visited_for", type="string", example="Product A"),
 *                     @OA\Property(property="current_status", type="string", example="Service/ProductPurchased"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-07T12:00:00Z")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Business ID, Tenant Schema, and Customer Number are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No purchased items found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No purchased items found for the given customer.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal Server Error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while retrieving purchased items.")
 *         )
 *     )
 * )
 */
public function getPurchasedItems(Request $request)
{
    $businessId = $request->input('business_id');
    $tenantSchema = $request->input('tenant_schema');
    $customerId = $request->input('customer_id'); // Customer number as required input

    // Validate required inputs
    if (empty($businessId) || empty($tenantSchema) || empty($customerId)) {
        return response()->json([
            'message' => 'Business ID, Tenant Schema, and Customer Number are required.'
        ], 400);
    }

    // Step 1: Switch to the tenant's schema
    QueryHelper::initializeConnection($tenantSchema);

    // Step 2: Fetch all unique product categories from visited_for where current_status = 'Service/ProductPurchased'
    $productCategories = DB::table('business_history')
        ->where('current_status', 'Service/ProductPurchased')
        ->where('customer_id', $customerId) // Include customer_no in the query
        ->pluck('visited_for')
        ->unique();

    if ($productCategories->isEmpty()) {
        return response()->json(['message' => 'No purchased items found for the given customer.'], 200);
    }

    // Step 3: Prepare the result data
    $result = [];
    foreach ($productCategories as $productCategory) {
        // Switch to master database to fetch the type
        DB::setDefaultConnection('master_db');
        $type = DB::table('sales_and_services')
            ->where('business_id', $businessId)
            ->where('product_category', $productCategory)
            ->value('type');

        // Return to tenant database
        DB::setDefaultConnection('tenant');

        // Skip if type is not found
        if (!$type) {
            continue;
        }

        // Fetch purchased items for this product category
        $purchasedItems = DB::table('business_history')
            ->select('id', 'visited_for', 'current_status', 'created_at')
            ->where('current_status', 'Service/ProductPurchased')
            ->where('visited_for', $productCategory)
            ->where('customer_id', $customerId) // Include customer_no in the query
            ->get();

        // Add the items to the result
        $result = array_merge($result, $purchasedItems->toArray());
    }

    // If no valid items are found
    if (empty($result)) {
        return response()->json(['message' => 'No purchased items found for the given customer.'], 200);
    }

    // Return the response with only the items
    return response()->json([
        'message' => 'Purchased items retrieved successfully.',
        'data' => $result
    ], 200);
}
/**
 * @OA\Get(
 *     path="/api/getPurchasedServices",
 *     summary="Retrieve purchased services for a customer",
 *     description="Fetches all purchased services for a given customer based on their purchase history.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"business_id", "tenant_schema", "customer_id"},
 *             @OA\Property(property="business_id", type="integer", example=1, description="Business ID"),
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db", description="Tenant database schema"),
 *             @OA\Property(property="customer_id", type="integer", example=123, description="Customer ID")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Purchased services retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Purchased services retrieved successfully."),
 *             @OA\Property(property="data", type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="visited_for", type="string", example="Service A"),
 *                     @OA\Property(property="current_status", type="string", example="Service/ProductPurchased"),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-07T12:00:00Z")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Business ID, Tenant Schema, and Customer Number are required.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No purchased services found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="No purchased service found for the given customer.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal Server Error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred while retrieving purchased services.")
 *         )
 *     )
 * )
 */
public function getPurchasedServices(Request $request)
{
    $businessId = $request->input('business_id');
    $tenantSchema = $request->input('tenant_schema');
    $customerId = $request->input('customer_id'); // Customer number as required input

    // Validate required inputs
    if (empty($businessId) || empty($tenantSchema) || empty($customerId)) {
        return response()->json([
            'message' => 'Business ID, Tenant Schema, and Customer Number are required.'
        ], 400);
    }

    // Step 1: Switch to the tenant's schema
    QueryHelper::initializeConnection($tenantSchema);

    // Step 2: Fetch all unique product categories from visited_for where current_status = 'Service/ProductPurchased'
    $services = DB::table('business_history')
        ->where('current_status', 'Service/ProductPurchased')
        ->where('customer_id', $customerId) // Include customer_no in the query
        ->pluck('visited_for')
        ->unique();

    if ($services->isEmpty()) {
        return response()->json(['message' => 'No purchased service found for the given customer.'], 200);
    }

    // Step 3: Prepare the result data
    $result = [];
    foreach ($services as $service) {
        // Switch to master database to fetch the type
        DB::setDefaultConnection('master_db');
        $type = DB::table('sales_and_services')
            ->where('business_id', $businessId)
            ->where('service', $service)
            ->value('type');

        // Return to tenant database
        DB::setDefaultConnection('tenant');

        // Skip if type is not found
        if (!$type) {
            continue;
        }

        // Fetch purchased items for this product category
        $purchasedServices = DB::table('business_history')
            ->select('id', 'visited_for', 'current_status', 'created_at')
            ->where('current_status', 'Service/ProductPurchased')
            ->where('visited_for', $services)
            ->where('customer_id', $customerId) // Include customer_no in the query
            ->get();

        // Add the items to the result
        $result = array_merge($result, $purchasedServices->toArray());
    }

    // If no valid items are found
    if (empty($result)) {
        return response()->json(['message' => 'No purchased service found for the given customer.'], 200);
    }

    // Return the response with only the items
    return response()->json([
        'message' => 'Purchased services retrieved successfully.',
        'data' => $result
    ], 200);
}
/**
 * @OA\Post(
 *     path="/api/getDashboardData",
 *     summary="Get dashboard data for a specific tenant",
 *     description="Fetches various metrics related to contacts, customers, opportunities, schedules, follow-ups, and statuses for a given tenant.",
 *     tags={"Tenants"},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         description="Tenant database schema name",
 *         @OA\Schema(type="string", example="tenant_db")
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Successful response",
 *         @OA\JsonContent(
 *             @OA\Property(property="dashboard_data", type="object",
 *                 @OA\Property(property="profile_completed", type="integer", example=80),
 *                 @OA\Property(property="total_contacts", type="integer", example=100),
 *                 @OA\Property(property="total_customers", type="integer", example=50),
 *                 @OA\Property(property="total_opportunities", type="integer", example=10),
 *                 @OA\Property(property="total_schedules", type="integer", example=5),
 *                 @OA\Property(property="total_follow_up", type="integer", example=8),
 *                 @OA\Property(property="follow_up_done", type="integer", example=4),
 *                 @OA\Property(property="total_pending_status", type="integer", example=3),
 *                 @OA\Property(property="total_status_done", type="integer", example=6)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Validation error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Validation failed")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function getDashboardData(Request $request)
{
    // Validate tenant schema
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $today = now()->format('Y-m-d'); // Get today's date

    try {
        // Exclude unnecessary columns from tenants table
        $excludedColumns = ['id', 'status', 'created_at', 'updated_at', 'is_deleted', 'refferal_code', 'email_verified_at', 'adhaar', 'otp', 'tenant_schema', 'device_id', 'remember_token'];
        $allColumns = DB::connection('master_db')
            ->getSchemaBuilder()
            ->getColumnListing('tenants');
        $selectedColumns = array_diff($allColumns, $excludedColumns);

        // Get tenant data
        $tenantData = DB::connection('master_db')
            ->table('tenants')
            ->select($selectedColumns)
            ->where('tenant_schema', $tenantSchema)
            ->first();

        // Calculate profile completion percentage
        $profileFields = collect((array) $tenantData);
        $profileCompleted = round(($profileFields->filter()->count() / $profileFields->count()) * 100);

        // Switch to tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Initialize dashboard data
        $dashboardData = [
            'profile_completed' => $profileCompleted,
            'total_contacts' => null,
            'total_customers' => null,
            'total_opportunities' => 0,
            'total_schedules' => 0,
            'total_follow_up' => 0,
            'follow_up_done' => 0,
            'total_pending_status' => 0,
            'total_status_done' => 0,
        ];

        // Fetch data for each metric
        try {
            // Total Contacts
            $dashboardData['total_contacts'] = DB::table('customers')
                ->where('is_deleted', 0)
                ->count();
        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Total Customers
            $businessHistoryTableExists = Schema::hasTable('business_history');

            if ($businessHistoryTableExists) {
                $dashboardData['total_customers'] = DB::table(function ($query) {
                    $query->select('id as customer_id')
                        ->from('customers')
                        ->where('group', 'Customer')
                        ->union(
                            DB::table('business_history')
                                ->select('customer_id')
                                ->where('current_status', 'Service/ProductPurchased')
                        );
                }, 'combined')
                    ->distinct()
                    ->count('customer_id');
            } else {
                $dashboardData['total_customers'] = DB::table('customers')
                    ->where('group', 'Customer')
                    ->distinct()
                    ->count('id');
            }

        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Total Opportunities
            $dashboardData['total_opportunities'] = DB::table('business_history')
                ->whereDate('tentative_revisit', $today)
                ->distinct()
                ->count('customer_id');
        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Total Schedules
            $dashboardData['total_schedules'] = DB::table('appointment')
                ->where('is_deleted', 0)
                ->whereDate('date', $today)
                ->count();
        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Total Follow-Up
            $dashboardData['total_follow_up'] = DB::table('business_history as bh1')
                ->where('bh1.current_status', 'Followup')
                ->whereDate('bh1.follow_up_on', $today)
                ->whereNotIn('bh1.customer_id', function ($query) use ($today) {
                    $query->select('bh2.customer_id')
                        ->from('business_history as bh2')
                        ->where('bh2.current_status', 'Followup')
                        ->whereDate('bh2.follow_up_on', '>', $today);
                })
                ->distinct()
                ->count('bh1.customer_id');
        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Follow-Up Done
            $dashboardData['follow_up_done'] = DB::table('call_history')
                ->whereIn('customer_id', function ($query) use ($today) {
                    $query->select('bh1.customer_id')
                        ->from('business_history as bh1')
                        ->where('bh1.current_status', 'Followup')
                        ->whereDate('bh1.follow_up_on', $today)
                        ->whereNotIn('bh1.customer_id', function ($subQuery) use ($today) {
                            $subQuery->select('bh2.customer_id')
                                ->from('business_history as bh2')
                                ->where('bh2.current_status', 'Followup')
                                ->whereDate('bh2.follow_up_on', '>', $today);
                        });
                })
                ->where('duration', '>', 0)
                ->whereDate('timestamp', $today)
                ->distinct()
                ->count('customer_id');
        } catch (\Exception $e) {
            Log::error($e);
        }

        try {
            // Pending Status and Status Done
           $conditions = [
                ['column' => 'follow_up_on', 'current_status' => 'Followup'],
                ['column' => 'schedule_on', 'current_status' => 'Schedule'],
                ['column' => 'hold_till', 'current_status' => 'Hold'],
            ];

            // 1. Fetch customer_ids from business_history (if the table exists)
            if (Schema::hasTable('business_history')) {
                $pendingCustomerIdsFromBusinessHistory = DB::table('business_history as bh')
                    ->join(
                        DB::raw('(SELECT customer_id, MAX(timestamp) as latest_timestamp FROM call_history WHERE duration > 0 AND DATE(timestamp) = "' . $today . '" GROUP BY customer_id) as ch'),
                        'bh.customer_id', '=', 'ch.customer_id'
                    )
                    ->where(function ($query) use ($conditions, $today) {
                        foreach ($conditions as $condition) {
                            if (Schema::hasColumn('business_history', $condition['column'])) {
                                $query->orWhere(function ($subQuery) use ($condition, $today) {
                                    $subQuery->where('bh.current_status', $condition['current_status'])
                                        ->whereDate('bh.' . $condition['column'], $today);
                                });
                            }
                        }
                    })
                    ->distinct()
                    ->pluck('bh.customer_id');
            } else {
                $pendingCustomerIdsFromBusinessHistory = collect(); // Empty collection if table doesn't exist
            }

            // 2. Fetch customer_ids from call_history and customers (without depending on business_history)
            $pendingCustomerIdsFromCallHistory = DB::table('call_history as ch')
                ->join('customers as c', 'ch.customer_id', '=', 'c.id')
                ->where('ch.duration', '>', 0)
                ->whereDate('ch.timestamp', '=', $today)
                ->whereIn('c.group', ['Leads', 'Customer'])
                ->distinct()
                ->pluck('ch.customer_id');

            // Combine both sets of customer_ids
            $allPendingCustomerIds = $pendingCustomerIdsFromBusinessHistory->merge($pendingCustomerIdsFromCallHistory)->unique();

            $dashboardData['total_pending_status'] = $allPendingCustomerIds->count();

            // Status Done
            $dashboardData['total_status_done'] = DB::table('business_history as bh')
                ->join(DB::raw('(SELECT customer_id, MAX(timestamp) as latest_timestamp FROM call_history WHERE duration > 0 AND DATE(timestamp) = "' . $today . '" GROUP BY customer_id) as ch'),
                    'bh.customer_id', '=', 'ch.customer_id'
                )
                ->whereIn('bh.customer_id', $allPendingCustomerIds)
                ->whereNotNull('bh.current_status')
                ->whereDate('bh.created_at', $today)
                ->whereRaw('bh.created_at > ch.latest_timestamp')
                ->distinct()
                ->count('bh.customer_id');
        } catch (\Exception $e) {
            Log::error($e);
        }

        return response()->json([
            'dashboard_data' => $dashboardData,
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/getCustomerProfileCompletion",
 *     summary="Get customer profile completion percentage",
 *     description="Calculates the profile completion percentage based on non-empty fields for a given customer.",
 *     tags={"Tenants"},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         description="Tenant database schema name",
 *         @OA\Schema(type="string", example="tenant_db")
 *     ),
 *     @OA\Parameter(
 *         name="customer_no",
 *         in="query",
 *         required=true,
 *         description="Customer mobile number",
 *         @OA\Schema(type="string", example="9876543210")
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Profile completion percentage",
 *         @OA\JsonContent(
 *             @OA\Property(property="profile_completed", type="integer", example=80)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Customer not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Customer not found."),
 *             @OA\Property(property="profile_completed", type="integer", example=0)
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function getCustomerProfileCompletion(Request $request)
{
    // Validate request inputs
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'customer_no' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $customerNo = $validated['customer_no'];

    try {
        // Switch to tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Fetch all column names except excluded ones
        $excludedColumns = ['id', 'status', 'created_at', 'updated_at', 'is_deleted'];
        $allColumns = DB::getSchemaBuilder()->getColumnListing('customers');
        $selectedColumns = array_diff($allColumns, $excludedColumns);

        // Fetch customer data with selected columns
        $customerData = DB::table('customers')
            ->select($selectedColumns)
            ->where('mobile', $customerNo)
            ->first();

        // Check if the customer exists
        if (!$customerData) {
            return response()->json([
                'message' => 'Customer not found.',
                'profile_completed' => 0,
            ], 200);
        }

        // Calculate profile completion percentage
        $profileFields = collect((array) $customerData);
        $profileCompleted = round(($profileFields->filter()->count() / $profileFields->count()) * 100);

        // Response
        return response()->json([
            'profile_completed' => $profileCompleted,
        ], 200);
    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/addTask",
 *     summary="Add a new task",
 *     description="Dynamically creates the 'tasks' table if not exists, adds necessary columns, and inserts task data.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "form_data"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(
 *                 property="form_data",
 *                 type="object",
 *                 example={"title": "New Task", "description": "Task details", "priority": 1}
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="Task added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Task added successfully"),
 *             @OA\Property(property="task_id", type="integer", example=1)
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function addTask(Request $request)
{
    // Validate tenant schema and form data
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'form_data' => 'required|array', // The form data should be an associative array
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $formData = $validated['form_data'];

    try {
        // Switch to tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the "tasks" table exists, and create it if it doesn't
        if (!Schema::hasTable('tasks')) {
            Schema::create('tasks', function (Blueprint $table) {
                $table->bigIncrements('id'); // Primary key
            });
        }

        // Ensure the required columns exist
        if (!Schema::hasColumn('tasks', 'status')) {
            Schema::table('tasks', function (Blueprint $table) {
                $table->tinyInteger('status')->default(1)->after('id'); // Default status = 1
            });
        }
        if (!Schema::hasColumn('tasks', 'is_deleted')) {
            Schema::table('tasks', function (Blueprint $table) {
                $table->boolean('is_deleted')->default(0)->after('status'); // Default is_deleted = 0
            });
        }
        if (!Schema::hasColumn('tasks', 'created_at') || !Schema::hasColumn('tasks', 'updated_at')) {
            Schema::table('tasks', function (Blueprint $table) {
                $table->timestamps(); // Includes `created_at` and `updated_at`
            });
        }

        // Add form_data columns dynamically right after `id`
        foreach ($formData as $key => $value) {
            if (!Schema::hasColumn('tasks', $key)) {
                Schema::table('tasks', function (Blueprint $table) use ($key, $value) {
                    // Determine column type based on value type
                    if (is_int($value)) {
                        $table->integer($key)->nullable()->after('id');
                    } elseif (is_float($value)) {
                        $table->decimal($key, 10, 2)->nullable()->after('id');
                    } elseif (is_bool($value)) {
                        $table->boolean($key)->nullable()->after('id');
                    } elseif ($key == 'created_at' || $key == 'updated_at') {
                        $table->timestamp($key)->nullable()->after('id');
                    } else {
                        $table->string($key)->nullable()->after('id');
                    }
                });
            }
        }

        // Insert data into the "tasks" table
        $taskId = DB::table('tasks')->insertGetId(array_merge($formData, [
            'status' => 1,
            'is_deleted' => 0,
        ]));
        // Return success response with the inserted task ID
        return response()->json([
            'success' => true,
            'message' => 'Task added successfully',
            'task_id' => $taskId,
        ], 201);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/editTask",
 *     summary="Edit an existing task",
 *     description="Updates an existing task by dynamically adding new columns if necessary.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "task_id", "form_data"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="task_id", type="integer", example=1),
 *             @OA\Property(
 *                 property="form_data",
 *                 type="object",
 *                 example={"title": "Updated Task", "description": "Updated details"}
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Task updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Task updated successfully")
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Task not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Task not found")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function editTask(Request $request)
{
    // Validate tenant schema, task ID, and form data
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'task_id' => 'required|integer', // Task ID to identify the task
        'form_data' => 'required|array', // Form data for updating the task
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $taskId = $validated['task_id'];
    $formData = $validated['form_data'];

    try {
        // Switch to tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the "tasks" table exists
        if (!Schema::hasTable('tasks')) {
            return response()->json([
                'success' => true,
                'message' => 'Tasks table does not exist',
            ], 200);
        }

        // Check if the task exists
        $task = DB::table('tasks')->where('id', $taskId)->first();
        if (!$task) {
            return response()->json([
                'success' => true,
                'message' => 'Task not found',
            ], 200);
        }
        // Dynamically add new columns from form_data if they don't exist
        foreach ($formData as $key => $value) {
            if (!Schema::hasColumn('tasks', $key)) {
                Schema::table('tasks', function (Blueprint $table) use ($key, $value) {
                    // Determine column type based on value type
                    if (is_int($value)) {
                        $table->integer($key)->nullable()->after('id');
                    } elseif (is_float($value)) {
                        $table->decimal($key, 10, 2)->nullable()->after('id');
                    } elseif (is_bool($value)) {
                        $table->boolean($key)->nullable()->after('id');
                    } elseif ($key == 'created_at' || $key == 'updated_at') {
                        $table->timestamp($key)->nullable()->after('id');
                    } else {
                        $table->string($key)->nullable()->after('id');
                    }
                });
            }
        }
        DB::table('tasks')
            ->where('id', $taskId)
            ->update(array_merge(
                $formData,
                ['updated_at' => now()] // Always update the updated_at field
            ));
        // Return success response
        return response()->json([
            'success' => true,
            'message' => 'Task updated successfully',
        ], 200);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Get(
 *     path="/api/getTask",
 *     summary="Retrieve tasks",
 *     description="Fetches tasks from the tenant schema, applying optional filters.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(
 *                 property="filters",
 *                 type="object",
 *                 example={"status": 1, "priority": "high"},
 *                 description="Optional filters to retrieve specific tasks"
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tasks retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="tasks", type="array", @OA\Items(type="object"))
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tasks table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Tasks table does not exist")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function getTask(Request $request)
{
    // Validate tenant schema and optional filters
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'filters' => 'nullable|array', // Optional filters for retrieving tasks
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $filters = $validated['filters'] ?? [];

    try {
        // Switch to tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Check if the "tasks" table exists
        if (!Schema::hasTable('tasks')) {
            return response()->json([
                'success' => true,
                'message' => 'No tasks found',
                'data' => []
            ], 200);
        }

        $tasks = DB::table('tasks')
                ->where('is_deleted', 0)
                ->get();


        // Apply filters in PHP (Collection filtering)
        if (!empty($filters)) {
            $tasks = collect($tasks)->filter(function ($task) use ($filters) {
                foreach ($filters as $key => $value) {
                    if (!property_exists($task, $key) || $task->$key != $value) {
                        return false;
                    }
                }
                return true;
            })->values(); // Re-index the collection
        }

        // Return the filtered tasks
        return response()->json([
            'success' => true,
            'tasks' => $tasks,
        ], 200);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/markTaskDone",
 *     summary="Mark a task as completed",
 *     description="Updates the status of a task to mark it as done.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "task_id"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="task_id", type="integer", example=123)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Task marked as completed",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Task completed successfully"),
 *             @OA\Property(property="task_id", type="integer", example=123)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Task not found or table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Task not found")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */
public function markTaskDone(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'task_id' => 'required|integer',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $taskId = $validated['task_id'];

    try {
        QueryHelper::initializeConnection($tenantSchema);
        if (!Schema::hasTable('tasks')) {
            return response()->json(['error' => 'Tasks table does not exist'], 200);
        }
        $task = DB::table('tasks')->where('id', $taskId)->first();

        if (!$task) {
            return response()->json(['error' => 'Task not found'], 200);
        }
        DB::table('tasks')
            ->where('id', $taskId)
            ->update([
                'status' => 0,
                'updated_at' => now(),
            ]);

        return response()->json([
            'success' => true,
            'message' => 'Task completed successfully',
            'task_id' => $taskId,
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/deleteTask",
 *     summary="Delete tasks",
 *     description="Marks tasks as deleted by updating the is_deleted flag.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "task_ids"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="task_ids", type="array", @OA\Items(type="integer"), example={1, 2, 3})
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Tasks deleted successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Tasks deleted successfully"),
 *             @OA\Property(property="task_ids", type="array", @OA\Items(type="integer"), example={1, 2, 3})
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="No matching tasks found or table does not exist",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="No matching tasks found")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred")
 *         )
 *     )
 * )
 */ 
public function deleteTask(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'task_ids' => 'required|array',
        'task_ids.*' => 'integer',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $taskIds = $validated['task_ids'];

    try {
        QueryHelper::initializeConnection($tenantSchema);

        if (!Schema::hasTable('tasks')) {
            return response()->json(['error' => 'Tasks table does not exist'], 200);
        }

        $existingTasks = DB::table('tasks')->whereIn('id', $taskIds)->pluck('id')->toArray();

        if (empty($existingTasks)) {
            return response()->json(['error' => 'No matching tasks found'], 200);
        }

        DB::table('tasks')
            ->whereIn('id', $existingTasks)
            ->update([
                'is_deleted' => 1,
                'updated_at' => now(),
            ]);
        return response()->json([
            'success' => true,
            'message' => 'Tasks deleted successfully',
            'task_ids' => $existingTasks,
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}


  
private function ensureTableAndColumnsExist($table, $data, $connection = 'tenant')
{
    if (!Schema::connection($connection)->hasTable($table)) {
        Schema::connection($connection)->create($table, function ($t) {
            $t->bigIncrements('id');
        });
    }

    foreach ($data as $column => $value) {
        if (!Schema::connection($connection)->hasColumn($table, $column)) {
            Schema::connection($connection)->table($table, function ($t) use ($column, $value) {
                if (in_array($column, ['created_at', 'updated_at'])) {
                    $t->timestamp($column)->nullable();
                } elseif (in_array($column, ['is_deleted', 'status'])) {
                    $t->boolean($column)->default(0);
                } elseif (is_int($value)) {
                    $t->integer($column)->nullable();
                } elseif (is_float($value)) {
                    $t->decimal($column, 10, 2)->nullable();
                } elseif (is_array($value)) {
                    $t->json($column)->nullable();
                } else {
                    $t->text($column)->nullable();
                }
            });
        }
    }
}
  

/**
 * @OA\Post(
 *     path="/api/assignGroupToCustomers",
 *     summary="Assign a group to multiple customers",
 *     description="Assigns a specified group to a list of customer IDs.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "group", "customer_ids"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="group", type="string", example="Premium"),
 *             @OA\Property(
 *                 property="customer_ids",
 *                 type="array",
 *                 @OA\Items(type="integer", example=1)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Group assigned successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Group assigned successfully."),
 *             @OA\Property(property="group", type="string", example="Premium"),
 *             @OA\Property(
 *                 property="customer_ids",
 *                 type="array",
 *                 @OA\Items(type="integer", example=1)
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Failed to assign group",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Failed to assign group."),
 *             @OA\Property(property="error", type="string", example="Database error")
 *         )
 *     )
 * )
 */
public function assignGroupToCustomers(Request $request)
{
    // Validate input data
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'group' => 'nullable|string',
        'customer_ids' => 'required|array|min:1', // Ensure customer_ids is an array
        'customer_ids.*' => 'integer', // Validate each customer_id as an integer
        'emp_id' => 'nullable|integer', // emp_id is optional but must be an integer if provided
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $group = $validated['group'] ?? null;
    $customerIds = $validated['customer_ids'];
    $empId = $validated['emp_id'] ?? null; // Get emp_id if provided

    // Initialize tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    try {
        // Define customers table
        $customersTable = "{$tenantSchema}.customers";

        // Prepare update data
        $updateData = ['group' => $group];

        // If emp_id is provided, add it to the update array
        if (!is_null($empId)) {
            $updateData['emp_id'] = $empId;
        }

        // Update group (and emp_id if provided) for selected customers
        DB::table($customersTable)
            ->whereIn('id', $customerIds)
            ->update($updateData);

        // Return success response
        return response()->json([
            'message' => 'Group assigned successfully.',
            'group' => $group,
            'customer_ids' => $customerIds,
            'emp_id' => $empId, // Include emp_id in response if provided
        ], 200);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json([
            'message' => 'Failed to assign group.',
            'error' => $e->getMessage(),
        ], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/addAccountDetails",
 *     summary="Add account details for a tenant",
 *     description="Adds UPI account details to the tenant's database. If a UPI already exists, it prevents duplicate entries.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "form_data"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(
 *                 property="form_data",
 *                 type="object",
 *                 required={"upi_name", "upi_id"},
 *                 @OA\Property(property="upi_name", type="string", example="John Doe"),
 *                 @OA\Property(property="upi_id", type="string", example="johndoe@upi")
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="UPI added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="UPI added successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="UPI is already added",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="UPI is already added, edit existing UPI to add new.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
public function addAccountDetails(Request $request)
{
    // Validate tenant schema and form data
    $validatedData = $request->validate([
        'tenant_schema' => 'required|string',
        'form_data' => 'required|array', // The form data should be an associative array
    ]);

    $tenantSchema = $validatedData['tenant_schema'];
    $formData = $validatedData['form_data'];

    // Initialize tenant schema connection
    QueryHelper::initializeConnection($tenantSchema);

    try {
        // Check if the "account_details" table exists under the tenant schema, and create it if it doesn't
        if (!Schema::connection('tenant')->hasTable('account_details')) {
            Schema::connection('tenant')->create('account_details', function (Blueprint $table) {
                $table->id(); // Primary key
                $table->string('upi_name')->nullable();
                $table->string('upi_id')->unique()->nullable();
                $table->tinyInteger('status')->default(1);
                $table->tinyInteger('is_deleted')->default(0);
                $table->timestamps();
            });
        }

        // Check if there is at least one existing record in the table
        $accountExists = DB::connection('tenant')
            ->table('account_details')
            ->exists();

        if ($accountExists) {
            return response()->json([
                'success' => true,
                'message' => 'UPI is already added, edit existing UPI to add new.',
            ], 400);
        }

        // Insert data into the tenant's account_details table
        DB::connection('tenant')->table('account_details')->insert([
            'upi_name' => $formData['upi_name'],
            'upi_id' => $formData['upi_id'],
            'status' => 1,
            'is_deleted' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        // Return success response
        return response()->json([
            'success' => true,
            'message' => 'UPI added successfully.',
        ], 201);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/editAccountDetail",
 *     summary="Edit UPI account details",
 *     description="Updates an existing UPI account detail in the tenant's database.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "id", "form_data"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="id", type="integer", example=1),
 *             @OA\Property(
 *                 property="form_data",
 *                 type="object",
 *                 required={"upi_name", "upi_id"},
 *                 @OA\Property(property="upi_name", type="string", example="John Doe"),
 *                 @OA\Property(property="upi_id", type="string", example="johndoe@upi")
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="UPI details updated successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="UPI details updated successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
public function editAccountDetail(Request $request)
{
    // Validate request data
    $validatedData = $request->validate([
        'tenant_schema' => 'required|string',
        'id' => 'required|integer', // ID of the UPI record to edit
        'form_data' => 'required|array',
    ]);

    $tenantSchema = $validatedData['tenant_schema'];
    $id = $validatedData['id'];
    $formData = $validatedData['form_data'];

    // Initialize tenant schema connection
    QueryHelper::initializeConnection($tenantSchema);

    try {
        // Update UPI details
        DB::connection('tenant')->table('account_details')
            ->where('id', $id)
            ->update([
                'upi_name' => $formData['upi_name'],
                'upi_id' => $formData['upi_id'],
                'updated_at' => now(),
            ]);
    
        return response()->json([
            'success' => true,
            'message' => 'UPI details updated successfully.',
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/getAccountDetails",
 *     summary="Fetch UPI account details",
 *     description="Retrieves account details from the tenant's database.",
 *     tags={"Tenants"},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="tenant_db"
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Account details retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(
 *                 property="account_details",
 *                 type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="upi_name", type="string", example="John Doe"),
 *                     @OA\Property(property="upi_id", type="string", example="johndoe@upi"),
 *                     @OA\Property(property="status", type="integer", example=1),
 *                     @OA\Property(property="is_deleted", type="integer", example=0),
 *                     @OA\Property(property="created_at", type="string", format="date-time", example="2024-04-07T12:34:56Z"),
 *                     @OA\Property(property="updated_at", type="string", format="date-time", example="2024-04-07T12:34:56Z")
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Account details not found",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Account details not found.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
  public function getAccountDetails(Request $request)
{
    // Validate tenant schema and form data
    $validatedData = $request->validate([
        'tenant_schema' => 'required|string',
    ]);
    $tenantSchema = $validatedData['tenant_schema'];
    QueryHelper::initializeConnection($tenantSchema);
    try {
        // Fetch account details based on the tenant schema and provided UPI ID
        $accountDetails = DB::connection('tenant')
            ->table('account_details')
            ->where('is_deleted', 0) // Optional: ensure the record is not marked as deleted
            ->select('upi_name', 'upi_id')  
            ->get();

        // Check if the account details exist
        if (!$accountDetails) {
            return response()->json([
                'success' => true,
                'message' => 'Account details not found.',
            ], 200);
        }
        return response()->json([
            'success' => true,
            'account_details' => $accountDetails,
        ], 200);

    } catch (\Exception $e) {
        // Handle exceptions
        return response()->json(['error' => 'An error occurred: ' . $e->getMessage()], 500);
    }
}
/**
 * @OA\Get(
 *     path="/api/getProductsAndServices",
 *     summary="Fetch active products and services",
 *     description="Retrieves active products and services from the tenant's database.",
 *     tags={"Tenants"},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         @OA\Schema(type="string"),
 *         example="tenant_db"
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Products and services retrieved successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Data retrieved successfully"),
 *             @OA\Property(
 *                 property="products",
 *                 type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="name", type="string", example="Product A"),
 *                     @OA\Property(property="status", type="integer", example=1),
 *                     @OA\Property(property="is_deleted", type="integer", example=0)
 *                 )
 *             ),
 *             @OA\Property(
 *                 property="services",
 *                 type="array",
 *                 @OA\Items(
 *                     @OA\Property(property="id", type="integer", example=1),
 *                     @OA\Property(property="name", type="string", example="Service A"),
 *                     @OA\Property(property="status", type="integer", example=1),
 *                     @OA\Property(property="is_deleted", type="integer", example=0)
 *                 )
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
public function getProductsAndServices(Request $request)
{
    // Validate tenant schema
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];

    try {
        // Switch to the correct tenant schema
        QueryHelper::initializeConnection($tenantSchema);

        // Check if tables exist before querying
        $products = Schema::hasTable('product-catalogs') ?
            DB::table('product-catalogs')->where('status', 1)->where('is_deleted', 0)->orderBy('id', 'desc')->get() : [];

        $services = Schema::hasTable('service-catalogs') ?
            DB::table('service-catalogs')->where('status', 1)->where('is_deleted', 0)->orderBy('id', 'desc')->get() : [];

        return response()->json([
            'success' => true,
            'products' => $products,
            'services' => $services,
            'message' => (empty($products) && empty($services)) ? 'No data available' : 'Data retrieved successfully',
        ], 200);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'An error occurred: ' . $e->getMessage(),
        ], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/addContact",
 *     summary="Add a new contact",
 *     description="Adds a new contact to the customers table under the tenant schema.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "name", "mobile"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="name", type="string", example="John Doe"),
 *             @OA\Property(property="mobile", type="string", example="9876543210"),
 *             @OA\Property(property="email", type="string", example="john@example.com"),
 *             @OA\Property(property="profile_pic", type="string", format="binary", example=null)
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Contact added successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="message", type="string", example="Contact added successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="error", type="string", example="Database error")
 *         )
 *     )
 * )
 */
public function addContact(Request $request)
{
    try {
        // Validate required fields except unique constraint
        $request->validate([
            'tenant_schema' => 'required|string',
            'name' => 'required|string|max:255',
            'mobile' => 'required|string|max:15',
        ]);

        // Switch to tenant DB
        $tenantSchema = $request->input('tenant_schema');
        QueryHelper::initializeConnection($tenantSchema);

        // Check if mobile already exists in the tenant DB
        $exists = DB::table('customers')->where('mobile', $request->mobile)->exists();
        if ($exists) {
            return response()->json(['error' => 'The mobile number is already existing.'], 422);
        }

        // Fetch all column names from the customers table
        $columns = DB::getSchemaBuilder()->getColumnListing('customers');

        // Get form data and filter only existing columns
        $customerData = $request->only($columns);

        // Store profile picture if provided
        if ($request->hasFile('profile_pic')) {
            $file = $request->file('profile_pic');
            $customerData['profile_pic'] = $file->store("{$tenantSchema}/customers", 'public');
        }

        // Insert customer data
        DB::table('customers')->insert($customerData);

        return response()->json(['message' => 'Contact added successfully.'], 200);
    } catch (\Exception $e) {
        return response()->json(['error' => $e->getMessage()], 500);
    }
}
/**
 * @OA\Post(
 *     path="/api/createQuickBilling",
 *     summary="Create a quick billing entry",
 *     description="Creates a new quick billing entry under the tenant schema.",
 *     tags={"Tenants"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(
 *             required={"tenant_schema", "customer_id", "phone", "amount"},
 *             @OA\Property(property="tenant_schema", type="string", example="tenant_db"),
 *             @OA\Property(property="customer_id", type="integer", example=123),
 *             @OA\Property(property="phone", type="string", example="9876543210"),
 *             @OA\Property(property="amount", type="number", format="float", example=500.75)
 *         )
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="Quick billing entry created successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Quick billing entry created successfully."),
 *             @OA\Property(property="data", type="object",
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="tid", type="string", example="TID1234567"),
 *                 @OA\Property(property="customer_id", type="integer", example=123),
 *                 @OA\Property(property="phone", type="string", example="9876543210"),
 *                 @OA\Property(property="amount", type="number", format="float", example=500.75),
 *                 @OA\Property(property="status", type="integer", example=1),
 *                 @OA\Property(property="is_deleted", type="integer", example=0),
 *                 @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-07T12:00:00Z"),
 *                 @OA\Property(property="updated_at", type="string", format="date-time", example="2025-04-07T12:00:00Z")
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
public function createQuickBilling(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
        'customer_id' => 'required|integer',
        'phone' => 'required|digits_between:7,15',
        'amount' => 'required|numeric',
    ]);

    // Get tenant schema from request
    $tenantSchema = $request->tenant_schema;

    // Switch to the correct tenant schema using QueryHelper
    QueryHelper::initializeConnection($tenantSchema);
    
    // Table name
    $tableName = 'quick_billing';

    // Check if the table exists
    if (!DB::connection('tenant')->getSchemaBuilder()->hasTable($tableName)) {
        DB::connection('tenant')->statement("
            CREATE TABLE $tableName (
                id BIGINT AUTO_INCREMENT PRIMARY KEY,
                tid VARCHAR(20) UNIQUE NOT NULL,
                customer_id BIGINT NOT NULL,
                phone BIGINT NOT NULL,
                amount DECIMAL(10,2) NOT NULL,
                status TINYINT(1) DEFAULT 1,
                is_deleted TINYINT(1) DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ");
    }

    // Generate Unique TID
    $tid = 'TID' . rand(1000000, 9999999);

    // Insert new record
    $id = DB::connection('tenant')->table($tableName)->insertGetId([
        'tid' => $tid,
        'customer_id' => $request->customer_id,
        'phone' => $request->phone,
        'amount' => $request->amount,
    ]);
    return response()->json([
        'success' => true,
        'message' => 'Quick billing entry created successfully.',
        'data' => DB::connection('tenant')->table($tableName)->where('id', $id)->first()
    ], 201);
}
/**
 * @OA\Get(
 *     path="/api/getAllQuickBilling",
 *     summary="Get all quick billing entries",
 *     description="Retrieves all quick billing entries for the given tenant schema.",
 *     tags={"Tenants"},
 *     @OA\Parameter(
 *         name="tenant_schema",
 *         in="query",
 *         required=true,
 *         description="Tenant schema to fetch billing data from",
 *         @OA\Schema(type="string", example="tenant_db")
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="List of quick billing entries",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="data", type="array", @OA\Items(
 *                 @OA\Property(property="id", type="integer", example=1),
 *                 @OA\Property(property="tid", type="string", example="TID1234567"),
 *                 @OA\Property(property="customer_id", type="integer", example=123),
 *                 @OA\Property(property="phone", type="string", example="9876543210"),
 *                 @OA\Property(property="amount", type="number", format="float", example=500.75),
 *                 @OA\Property(property="status", type="integer", example=1),
 *                 @OA\Property(property="is_deleted", type="integer", example=0),
 *                 @OA\Property(property="customer_name", type="string", example="John Doe"),
 *                 @OA\Property(property="created_at", type="string", format="date-time", example="2025-04-07T12:00:00Z"),
 *                 @OA\Property(property="updated_at", type="string", format="date-time", example="2025-04-07T12:00:00Z")
 *             ))
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="An error occurred: Database error")
 *         )
 *     )
 * )
 */
public function getAllQuickBilling(Request $request)
{
    $tenantSchema = $request->input('tenant_schema');
    QueryHelper::initializeConnection($tenantSchema);
    // Check if the quick_billing table exists
    if (!Schema::hasTable('quick_billing')) {
        return response()->json([
            'success' => true,
            'data' => []
        ]);
    }
    $quickBillings = DB::table('quick_billing as qb')
        ->leftJoin('customers as c', 'qb.customer_id', '=', 'c.id')
        ->where('qb.is_deleted', 0)
        ->orderBy('qb.id', 'desc')
        ->select('qb.*', 'c.name as customer_name')
        ->get();
    
    return response()->json([
        'success' => true,
        'data' => $quickBillings
    ]);
}
/**
 * @OA\Post(
 *     path="/api/importCatalogXlsx",
 *     summary="Import catalog from an Excel file",
 *     description="Uploads an Excel (XLSX/CSV) file to import product or service catalog data.",
 *     tags={"Web App"},
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\MediaType(
 *             mediaType="multipart/form-data",
 *             @OA\Schema(
 *                 required={"tenant_schema", "category_type", "file"},
 *                 @OA\Property(property="tenant_schema", type="string", description="Tenant schema name", example="tenant_db"),
 *                 @OA\Property(property="category_type", type="string", enum={"product", "service"}, description="Catalog type", example="product"),
 *                 @OA\Property(property="file", type="string", format="binary", description="Excel file (.xlsx or .csv) containing catalog data")
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Catalog uploaded successfully",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Catalog uploaded successfully.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=400,
 *         description="Invalid input or file errors",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Invalid product catalog file.")
 *         )
 *     ),
 *     @OA\Response(
 *         response=500,
 *         description="Internal server error",
 *         @OA\JsonContent(
 *             @OA\Property(property="status", type="boolean", example=false),
 *             @OA\Property(property="message", type="string", example="Error uploading catalog: Database error")
 *         )
 *     )
 * )
 */
public function importCatalogXlsx(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
        'category_type' => 'required|in:product,service',
        'file' => 'required|file|mimes:xlsx,csv',
    ]);

    $tenantSchema = $request->tenant_schema;
    $categoryType = $request->category_type;
    $tableName = $categoryType === 'product' ? 'product-catalogs' : 'service-catalogs';

    QueryHelper::initializeConnection($tenantSchema);

    try {
        $file = $request->file('file');
        $spreadsheet = IOFactory::load($file->getPathname());
        $sheet = $spreadsheet->getActiveSheet();
        $rows = $sheet->toArray();

        if (empty($rows) || count($rows) < 2) {
            return response()->json([
                'status' => false,
                'message' => 'No data found in the file.'
            ], 400);
        }

        // Format headers
        $header = array_map(function ($item) {
            return strtolower(str_replace([' ', '*'], ['_', ''], trim($item)));
        }, $rows[0]);
        unset($rows[0]);

        // Build table if not exists
        $schemaBuilder = DB::connection('tenant')->getSchemaBuilder();
        if (!$schemaBuilder->hasTable($tableName)) {
            $schemaBuilder->create($tableName, function ($table) use ($header) {
                $table->increments('id');

                foreach ($header as $column) {
                    if (str_contains($column, 'amount') || str_contains($column, 'price')) {
                        $table->decimal($column, 10, 2)->nullable();
                    } elseif (str_contains($column, 'qty') || str_contains($column, 'count') || str_contains($column, 'number')) {
                        $table->integer($column)->default(0);
                    } elseif ($column === 'is_inventory') {
                        $table->boolean($column)->default(0);
                    } else {
                        $table->string($column)->nullable();
                    }
                }

                // Prevent duplicate brand column
                if (!in_array('brand', $header)) {
                    $table->string('brand')->nullable();
                }

                $table->string('image')->nullable();
                $table->boolean('status')->default(1);
                $table->boolean('is_deleted')->default(0);
                $table->timestamps();
            });
        }

        // Add brand column if missing
        $tableColumns = Schema::connection('tenant')->getColumnListing($tableName);
        if (!in_array('brand', $tableColumns)) {
            Schema::connection('tenant')->table($tableName, function ($table) {
                $table->string('brand')->nullable()->after('id');
            });
        }

        // Create brand_master table if not exists
        if (!$schemaBuilder->hasTable('brand_master')) {
            Schema::connection('tenant')->create('brand_master', function ($table) {
                $table->bigIncrements('id');
                $table->string('brand_name')->unique();
                $table->boolean('status')->default(1);
                $table->boolean('is_deleted')->default(0);
                $table->timestamps();
            });
        }

        // Extract brand column index
        $brandColIndex = array_search('brand', $header);
        $hasTitle = in_array('title', $header);

        $insertRows = [];
        $brandList = [];

        foreach ($rows as $row) {
            $data = [];

            foreach ($header as $i => $col) {
                $value = $row[$i] ?? null;

                if ($col === 'title') {
                    $value = str_replace('*', '', trim($value));
                }

                if ($col === 'is_inventory') {
                    $value = strtolower(trim($value)) === 'yes' ? 1 : 0;
                }

                $data[$col] = $value;
            }

            if ($hasTitle && empty($data['title'])) continue;

            if ($brandColIndex !== false && !empty($row[$brandColIndex])) {
                $originalBrand = trim($row[$brandColIndex]);
                $data['brand'] = $originalBrand;
                $brandList[] = $originalBrand;
            }

            $data['created_at'] = now();
            $data['updated_at'] = now();

            $insertRows[] = $data;
        }

        if (empty($insertRows)) {
            return response()->json(['status' => false, 'message' => 'No valid data found.'], 400);
        }

        // Insert into product/service table
        DB::connection('tenant')->table($tableName)->insert($insertRows);

        // Insert into brand_master (ensure uniqueness)
        $uniqueBrands = array_unique($brandList);
        foreach ($uniqueBrands as $brandName) {
            $brandName = trim($brandName);
            if (!DB::connection('tenant')->table('brand_master')->where('brand_name', $brandName)->exists()) {
                DB::connection('tenant')->table('brand_master')->insert([
                    'brand_name' => $brandName,
                    'status' => 1,
                    'is_deleted' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }
        return response()->json(['status' => true, 'message' => 'Data saved successfully.'], 200);

    } catch (\Exception $e) {
        return response()->json([
            'status' => false,
            'message' => 'Error: ' . $e->getMessage(),
        ], 500);
    }
}

public function checkAccess(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string'
    ]);

    $tenantSchema = $request->input('tenant_schema');

    $accessibleIds = DB::connection('master_db')
        ->table('tbl_feat_access')
        ->where('tenant_schema', $tenantSchema)
        ->where('status', 1)
        ->where('is_deleted', 0)
        ->pluck('module_id')
        ->toArray();

    $features = DB::connection('master_db')
        ->table('tbl_feature')
        ->where('status', 1)
        ->where('is_deleted', 0)
        ->get();

    $grouped = $features->groupBy('module_name');
    $response = [];

    foreach ($grouped as $moduleName => $items) {
        $subModules = [];
        $hasAccess = false;
        $moduleId = null;
        $moduleUid = null;

        foreach ($items as $item) {
            if (is_null($item->sub_module_name)) {
                $moduleId = $item->id;
                $moduleUid = $item->uid;
                $hasAccess = in_array($item->id, $accessibleIds);
            } else {
                $isSubAccess = in_array($item->id, $accessibleIds);
                $hasAccess = $hasAccess || $isSubAccess;

                $subModules[] = [
                    'id' => $item->id,
                    'name' => $item->sub_module_name,
                    'uid' => $item->uid,
                    'is_access' => $isSubAccess ? 1 : 0
                ];
            }
        }

        if ($hasAccess) {
            $response[] = [
                'module_name' => $moduleName,
                'id' => $moduleId,
                'uid' => $moduleUid,
                'is_access' => 1,
                'sub_modules' => $subModules
            ];
        }
    }

    return response()->json(['modules' => $response]);
}

public function importContactXlsx(Request $request)
{
    try {
        // Validate file upload
        $request->validate([
            'file' => 'required|mimes:xlsx',
            'tenant_schema' => 'required|string'
        ]);

        $file = $request->file('file');
        $tenantSchema = $request->input('tenant_schema');

        // Switch to tenant DB
        QueryHelper::initializeConnection($tenantSchema);
        DB::setDefaultConnection('tenant');

        // Load spreadsheet
        $spreadsheet = IOFactory::load($file->getPathname());
        $sheet = $spreadsheet->getActiveSheet();
        $rows = $sheet->toArray();

        if (empty($rows) || count($rows) < 2) {
            return response()->json(['error' => 'The file is empty or has no data.'], 400);
        }

        // Get column names from the first row
        $headers = array_map('strtolower', array_map('trim', $rows[0]));

        // Fetch table columns from DB
        $dbColumns = DB::getSchemaBuilder()->getColumnListing('customers');

        // Validate required fields
        if (!in_array('name', $headers) || !in_array('mobile', $headers)) {
            return response()->json(['error' => 'Required columns (name, mobile) are missing.'], 400);
        }

        $importedData = [];
        for ($i = 1; $i < count($rows); $i++) {
            $row = array_combine($headers, $rows[$i]);

            // Check if mobile exists
            $exists = DB::table('customers')
                ->where('mobile', $row['mobile'])
                ->exists();

            if (!$exists) {
                $filteredRow = array_intersect_key($row, array_flip($dbColumns));
                $importedData[] = $filteredRow;
            }
        }

        if (!empty($importedData)) {
            DB::table('customers')->insert($importedData);
        }

        return response()->json([
            'message' => count($importedData) . ' contacts imported successfully.',
            'skipped' => count($rows) - 1 - count($importedData)
        ], 200);

    } catch (\Exception $e) {
        return response()->json(['error' => $e->getMessage()], 500);
    }

}

public function getColumnName(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
        'table_name' => 'required|string',
    ]);

    $tenantSchema = $request->input('tenant_schema');
    $tableName = $request->input('table_name');

    // Switch to tenant database connection
    QueryHelper::initializeConnection($tenantSchema);

    // Check if table exists
    if (!Schema::connection('tenant')->hasTable($tableName)) {
        return response()->json(['message' => 'Table does not exist'], 200);
    }

    // Get column names
    $columns = Schema::connection('tenant')->getColumnListing($tableName);

    return response()->json(['columns' => $columns]);
}

public function getRecomendedLeads(Request $request)
{
    try {
        $request->validate([
            'tenant_id' => 'required|integer|exists:master_db.tenants,id',
        ]);

        $tenant_id = $request->tenant_id;
        $today = now()->toDateString(); // today's date in 'YYYY-MM-DD'

        // Get today's lead IDs assigned to this tenant
        $leadIds = DB::connection('master_db')->table('leads_history')
            ->where('tenant_id', $tenant_id)
            ->whereDate('created_at', $today)
            ->where('is_deleted', 0)
            ->pluck('lead_id')
            ->toArray();

        if (empty($leadIds)) {
            return response()->json(['message' => 'No leads found'], 200);
        }

        // Fetch full lead details, excluding unnecessary columns
        $leads = DB::connection('master_db')->table('leads_master')
            ->select('*')
            ->whereIn('id', $leadIds)
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->get()
            ->map(function ($lead) {
                unset($lead->status, $lead->is_deleted, $lead->created_at, $lead->updated_at);
                return $lead;
            });

        return response()->json([
            'tenant_id' => $tenant_id,
            'leads' => $leads,
        ]);

    } catch (\Exception $e) {
        Log::error($e->getMessage());

        return response()->json(['error' => 'Internal server error'], 500);
    }
}

public function getFormsByBusiness(Request $request)
{
    $businessId = $request->input('business_id');
    $tenantSchema = $request->input('tenant_schema');

    if (!$businessId || !$tenantSchema) {
        return response()->json(['error' => 'Missing required parameters.'], 400);
    }

    $empModuleId = DB:: connection('master_db')
            ->table('tbl_feature')
            ->where('uid', 'MOD_EMP')
            ->value('id');
    
        // Check feature access from `tbl_feat_access`
        $hasAccess = DB::connection('master_db')
            ->table('tbl_feat_access')
            ->where('tenant_schema', $tenantSchema)
            ->where('module_id', $empModuleId)
            ->where('status', 1)
            ->exists();
      
        // Choose the correct table based on feature access
        $tableName = $hasAccess ? 'ent_form_builder' : 'form_builder';

    // Get all matching forms
    $forms = DB::connection('master_db')
        ->table($tableName)
        ->select('id', 'name', 'status as is_access')
        ->whereRaw('FIND_IN_SET(?, bussiness_ids)', [$businessId])
        ->where('status', 1)
        ->where('is_deleted', 0)
        ->get();

    return response()->json(['forms' => $forms]);
}

public function addCustomerBankDetail(Request $request)
{
    // Validate incoming request
    $request->validate([
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
        'customer_id' => 'required|integer',
        'fields' => 'required|array|min:1'
    ]);

    $tenantSchema = $request->input('tenant_schema');
    $formName = $request->input('form_name');
    $customerId = $request->input('customer_id');
    $fields = $request->input('fields');

    // Initialize tenant DB connection
    QueryHelper::initializeConnection($tenantSchema);

    // If table doesn't exist, create it dynamically
    if (!Schema::connection('tenant')->hasTable($formName)) {
        Schema::connection('tenant')->create($formName, function ($table) use ($fields) {
            $table->id();
            $table->unsignedBigInteger('customer_id')->nullable();

            // Dynamically add columns based on field keys
            foreach ($fields as $key => $value) {
                $table->string($key)->nullable();
            }

            $table->tinyInteger('status')->default(1);
            $table->boolean('is_deleted')->default(0);
            $table->timestamps();
        });
    } else {
        // Optional: add new columns if not already present
        foreach ($fields as $key => $value) {
            if (!Schema::connection('tenant')->hasColumn($formName, $key)) {
                Schema::connection('tenant')->table($formName, function ($table) use ($key) {
                    $table->string($key)->nullable();
                });
            }
        }
    }

    // Build insert payload
    $insertData = $fields;
    $insertData['customer_id'] = $customerId;
    $insertData['status'] = 1;
    $insertData['is_deleted'] = 0;
    $insertData['created_at'] = now();
    $insertData['updated_at'] = now();

    // Insert into tenant table
    DB::connection('tenant')->table($formName)->insert($insertData);

    return response()->json([
        'message' => 'Form data saved successfully.',
        'form' => $formName,
        'data' => $insertData
    ], 200);
}

public function editCustomerBankDetail(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
        'record_id' => 'required|integer',
        'fields' => 'required|array|min:1'
    ]);

    $tenantSchema = $request->input('tenant_schema');
    $formName = $request->input('form_name');
    $recordId = $request->input('record_id');
    $fields = $request->input('fields');

    // Initialize tenant DB connection
    QueryHelper::initializeConnection($tenantSchema);

    // Check if table exists
    if (!Schema::connection('tenant')->hasTable($formName)) {
        return response()->json([
            'status' => false,
            'message' => "Table '{$formName}' does not exist."
        ], 400);
    }

    // Optionally add new columns if missing
    foreach ($fields as $key => $value) {
        if (!Schema::connection('tenant')->hasColumn($formName, $key)) {
            Schema::connection('tenant')->table($formName, function ($table) use ($key) {
                $table->string($key)->nullable();
            });
        }
    }

    // Add updated_at timestamp
    $fields['updated_at'] = now();

    // Update the record
    $affected = DB::connection('tenant')
        ->table($formName)
        ->where('id', $recordId)
        ->update($fields);

    if ($affected === 0) {
        return response()->json([
            'status' => 200,
            'message' => "Record not found or no changes made."
        ], 200);
    }

    return response()->json([
        'status' => true,
        'message' => "Form data updated successfully.",
        'record_id' => $recordId,
        'data' => $fields
    ], 200);
}

public function getCustomerBankDetail(Request $request)
{
    // Validate the request
    $request->validate([
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
        'customer_id' => 'required|integer'
    ]);
    
    $tenantSchema = $request->input('tenant_schema');
    $formName = $request->input('form_name');
    $customerId = $request->input('customer_id');

    // Initialize tenant DB connection
    QueryHelper::initializeConnection($tenantSchema);
    
    // Check if table exists
    if (!Schema::connection('tenant')->hasTable($formName)) {
        return response()->json([
            'message' => 'Form/table not found.'
        ], 200);
    }

    // Get the form data
    $accountDetails = DB::connection('tenant')->table($formName)
        ->where('customer_id', $customerId)
        ->where('is_deleted', 0)
        ->get();

    return response()->json([
        'success' => true,
        'account_details' => $accountDetails,
    ]);
}

public function getAllCustomers(Request $request)
{
    // Validate input
        $user = Auth::guard('api')->user();
      
        if (!$user) {
            return response()->json([
                'message' => 'Unauthorized access.',
                'data' => null,
            ], 401);
        }
        
        $tenantSchema = $user->tenant_schema;
    // Initialize tenant DB connection
    QueryHelper::initializeConnection($tenantSchema);

    try {
        $customersTable = "{$tenantSchema}.customers";

        // Fetch customers
        $customers = DB::connection('tenant')->table($customersTable)
            ->select('id as customer_id', 'name', 'mobile')
            ->get();

        return response()->json([
            'message' => 'Customer list fetched successfully.',
            'data' => $customers,
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to retrieve customers.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function getMostLikelyCustomers(Request $request)
{
    $user = Auth::guard('api')->user();

    if (!$user || !isset($user->tenant_schema)) {
        return response()->json(['message' => 'Tenant schema missing in token'], 401);
    }

    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);

    $today = now()->format('Y-m-d');

    $historyResults = DB::connection('tenant')->select(
        "CALL getMostLiklyList(?, ?)",
        [$today, $today]
    );

    if (empty($historyResults)) {
        return response()->json([]);
    }

    $results = [];

    // Check available columns in business_history
    $columns = Schema::connection('tenant')->getColumnListing('business_history');
    $hasHoldTill = in_array('hold_till', $columns);
    $hasTentativeRevisit = in_array('tentative_revisit', $columns);
    $hasReason = in_array('reason', $columns);
    $hasVisitedFor = in_array('visited_for', $columns);

    foreach ($historyResults as $result) {
        $customerId = $result->customer_id;

        $customer = DB::connection('tenant')->table('customers')
            ->where('id', $customerId)
            ->select('name', 'email', 'mobile', 'source', 'company', 'group', 'dob', 'anniversary')
            ->first();

        if (!$customer) continue;

        // Dynamically build select and order by
        $selectColumns = [];
        if ($hasHoldTill) $selectColumns[] = 'hold_till';
        if ($hasTentativeRevisit) $selectColumns[] = 'tentative_revisit';
        if ($hasReason) $selectColumns[] = 'reason';
        if ($hasVisitedFor) $selectColumns[] = 'visited_for';

        $query = DB::connection('tenant')->table('business_history')
            ->where('customer_id', $customerId)
            ->where('is_deleted', 0)
            ->limit(1);

        foreach ($selectColumns as $col) {
            $query->addSelect($col);
        }

        // Add a dynamic order by using available columns
        if ($hasHoldTill || $hasTentativeRevisit) {
            $orderExpr = $hasHoldTill && $hasTentativeRevisit
                ? DB::raw('COALESCE(hold_till, tentative_revisit, created_at)')
                : ($hasHoldTill ? 'hold_till' : ($hasTentativeRevisit ? 'tentative_revisit' : 'created_at'));

            $query->orderByDesc($orderExpr);
        } else {
            $query->orderByDesc('created_at');
        }

        $latestBusinessHistory = $query->first();

        $businessHistoryData = [];

        if ($latestBusinessHistory) {
            if ($hasHoldTill && !empty($latestBusinessHistory->hold_till)) {
                $businessHistoryData['hold_till'] = is_string($latestBusinessHistory->hold_till)
                    ? date('d-m-Y', strtotime($latestBusinessHistory->hold_till))
                    : $latestBusinessHistory->hold_till->format('d-m-Y');
                $businessHistoryData['reason'] = $hasReason ? ($latestBusinessHistory->reason ?? null) : null;
            }

            if ($hasTentativeRevisit && !empty($latestBusinessHistory->tentative_revisit)) {
                $businessHistoryData['tentative_revisit'] = is_string($latestBusinessHistory->tentative_revisit)
                    ? date('d-m-Y', strtotime($latestBusinessHistory->tentative_revisit))
                    : $latestBusinessHistory->tentative_revisit->format('d-m-Y');
                $businessHistoryData['visited_for'] = $hasVisitedFor ? ($latestBusinessHistory->visited_for ?? null) : null;
            }
        }

        // Call history
        $lastCall = DB::connection('tenant')->table('call_history')
            ->where('customer_id', $customerId)
            ->orderByDesc('timestamp')
            ->value('timestamp');

        $results[] = [
            'customer_id' => $customerId,
            'customer_info' => (array) $customer,
            'business_history' => !empty($businessHistoryData) ? [$businessHistoryData] : [],
            'call_history' => [
                'last_connected' => $lastCall
            ],
        ];
    }

    $results = QueryHelper::replaceNullWithNA($results);
    return response()->json($results);
}

public function syncStatus(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
    ]);

    $tenantSchema = $request->input('tenant_schema');

    // Query from master DB
    $sync = DB::connection('master_db')
        ->table('sync_requests')
        ->where('tenant_schema', $tenantSchema)
        ->where('status', 1)
        ->select('tenant_schema', 'contact', 'call_history')
        ->first();

    if (!$sync) {
        return response()->json([
            'success' => true,
            'data' => [
                'tenant_schema' => $tenantSchema,
                'contact' => 0,
                'call_history' => 0,
            ],
        ], 200);
    }

    return response()->json([
        'success' => true,
        'data' => $sync,
    ]);
}

public function getPackages()
{
    $packages = DB::table('tbl_package')
        ->where('status', 1)
        ->get();

    $response = [];

    foreach ($packages as $package) {
        // Decode JSON fields
        $features = json_decode($package->feature_list, true);

        // Fetch durations for this package
        $durations = DB::table('tbl_package_duration_amount')
            ->where('package_id', $package->id)
            ->where('status', 1)
            ->select('id', 'duration', 'amount', 'tax')
            ->get();

        $response[] = [
            'id' => $package->id,
            'name' => $package->name,
            'feature_list' => $features,
            'durations' => $durations
        ];
    }

    return response()->json($response);
}

public function savePrescription(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'form_name' => 'required|string',
        'form_data' => 'required|array',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $formName = $validated['form_name'];
    $formData = $validated['form_data'];

    // Switch to tenant DB
    QueryHelper::initializeConnection($tenantSchema);

    try {
        // Create table if not exists
        if (!Schema::hasTable($formName)) {
            Schema::create($formName, function ($table) use ($formData) {
                $table->id();

                foreach ($formData as $column => $value) {
                    $table->text($column)->nullable(); // all columns as text
                }

                $table->timestamps();
            });
        } else {
            // Add any missing columns
            foreach ($formData as $column => $value) {
                if (!Schema::hasColumn($formName, $column)) {
                    Schema::table($formName, function ($table) use ($column) {
                        $table->text($column)->nullable(); // add missing column
                    });
                }
            }
        }

        // Insert and get ID
        $insertData = array_merge($formData, [
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $prescriptionId = DB::table($formName)->insertGetId($insertData);

        return response()->json([
            'message' => 'Prescription saved successfully.',
            'id' => $prescriptionId,
        ], 201);

    } catch (\Exception $e) {
        Log::error('Error saving prescription: ' . $e->getMessage());
        return response()->json([
            'message' => 'Failed to save prescription.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function getPrescription(Request $request)
{
    $request->validate([
        'tenant_schema' => 'required|string',
        'prescription_id' => 'required|integer',
    ]);

    $tenantSchema = $request->tenant_schema;
    $prescriptionId = $request->prescription_id;

    // Connect to tenant DB
    QueryHelper::initializeConnection($tenantSchema);

    try {
        if (!Schema::hasTable('prescription')) {
            return response()->json([
                'message' => 'Prescription table does not exist.',
                'data' => []
            ], 200);
        }

        $prescription = DB::table('prescription')->where('id', $prescriptionId)->first();

        if (!$prescription) {
            return response()->json([
                'message' => 'Prescription not found.',
                'data' => []
            ], 200);
        }

        return response()->json([
            'message' => 'Prescription data retrieved successfully.',
            'data' => $prescription
        ], 200);

    } catch (\Exception $e) {
        Log::error('Error fetching prescription: ' . $e->getMessage());
        return response()->json([
            'message' => 'Failed to fetch prescription.',
            'error' => $e->getMessage()
        ], 500);
    }
}
public function getAllInvoiceOrProposals(Request $request)
{
        $validated = $request->validate([
            'tenant_schema' => 'required|string',
            'type' => 'nullable|string|in:invoice,proposal',
            'date' => 'nullable|date',
        ]);

        $tenantSchema = $validated['tenant_schema'];
        $type = $validated['type'] ?? null;
        $date = $validated['date'] ?? null;


        // Proceed with normal query if no cache exists
        QueryHelper::initializeConnection($tenantSchema);

        try {
            $billsTable = 'invoice_or_proposals';
            $taxTable = 'tax';
            $customersTable = "{$tenantSchema}.customers";
            $employeesTable = "{$tenantSchema}.employees";

            // Check if employees table exists in the tenant schema
            $employeeExists = Schema::connection('tenant')->hasTable('employees');

            $query = DB::connection('tenant')->table($billsTable)
                ->leftJoin($taxTable, "{$billsTable}.id", '=', "{$taxTable}.id")
                ->leftJoin($customersTable, "{$billsTable}.customer_id", '=', "{$customersTable}.id");

            if ($employeeExists) {
                $query->leftJoin($employeesTable, "{$billsTable}.emp_id", '=', "{$employeesTable}.id");
            }

            $selectFields = [
                "{$billsTable}.*",
                "{$customersTable}.name AS customer_name",
                "{$customersTable}.mobile AS customer_no",
                "{$taxTable}.*"
            ];

            if ($employeeExists) {
                $selectFields[] = "{$employeesTable}.full_name AS emp_name";
            }

            $query->select($selectFields);

            if ($type) {
                $query->where("{$billsTable}.type", $type);
            }
            if ($date) {
                $query->whereDate("{$billsTable}.created_at", $date);
            }

            $results = $query->get();

            $data = $results->groupBy('uid')->map(function ($group) use ($employeeExists) {
                $firstRow = $group->first();
            
                $totalQuantity = $group->sum(function ($item) {
                    return isset($item->Qty) ? (float) $item->Qty : 0;
                });
            
                $totalAmount = $group->sum(function ($item) {
                    return isset($item->totalamt) ? (float) $item->totalamt : 0;
                });
            
                return [
                    'uid' => $firstRow->uid,
                    'type' => $firstRow->type,
                    'billing_details' => [
                        [
                            'uid' => $firstRow->uid,
                            'customer_name' => $firstRow->customer_name ?? null,
                            'customer_no' => $firstRow->customer_no ?? null,
                            'discount' => $firstRow->discount ?? null,
                            'emp_name' => $employeeExists ? ($firstRow->emp_name ?? null) : null,
                            'total_item' => (string) $group->count(),
                            'total_quantity' => (string) $totalQuantity,
                            'total_amount' => (string) $totalAmount,
                            'date' => \Carbon\Carbon::parse($firstRow->created_at)->format('Y-m-d'),
                        ]
                    ],
                    'tax_details' => $group->map(function ($item) {
                        return json_decode(json_encode($item), true);
                    })->toArray(),
                ];
            })->values()->toArray();

            return response()->json([
                'message' => 'Bills and Proposals fetched successfully.',
                'data' => $data,
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to retrieve data.',
                'error' => $e->getMessage(),
            ], 500);
        }
}
public function getInvoiceAndProposal(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'uid' => 'required|string',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $uid = $validated['uid'];

    QueryHelper::initializeConnection($tenantSchema);

    try {
        $billsTable = 'invoice_or_proposals';
        $taxTable = 'tax';
        $customersTable = "{$tenantSchema}.customers";
        $employeesTable = "{$tenantSchema}.employees";
        $prescriptionTable = 'prescription';

        // Check optional tables
        $customerExists = Schema::connection('tenant')->hasTable('customers');
        $employeeExists = Schema::connection('tenant')->hasTable('employees');
        $prescriptionExists = Schema::connection('tenant')->hasTable($prescriptionTable);

        // Main Query
        $query = DB::connection('tenant')->table($billsTable)
            ->leftJoin($taxTable, "{$billsTable}.id", '=', "{$taxTable}.id");

        if ($customerExists) {
            $query->leftJoin($customersTable, "{$billsTable}.customer_id", '=', "{$customersTable}.id");
        }

        if ($employeeExists) {
            $query->leftJoin($employeesTable, "{$billsTable}.emp_id", '=', "{$employeesTable}.id");
        }

        $selectFields = [
            "{$billsTable}.*",
            "{$taxTable}.*"
        ];

        if ($customerExists) {
            $selectFields[] = "{$customersTable}.name AS customer_name";
        }

        if ($employeeExists) {
            $selectFields[] = "{$employeesTable}.full_name AS emp_name";
        }

        $query->select($selectFields)->where("{$billsTable}.uid", $uid);

        $results = $query->get();

        if ($results->isEmpty()) {
            return response()->json([
                'message' => 'No invoice or proposal found for the provided UID.',
            ], 404);
        }

        $data = $results->groupBy('uid')->map(function ($group) use ($customerExists, $employeeExists, $prescriptionExists, $prescriptionTable, $uid) {
            $firstRow = $group->first();

            // Get all prescriptions by UID
            $prescriptionData = null;
            if ($prescriptionExists) {
                $prescriptions = DB::connection('tenant')->table($prescriptionTable)
                    ->where('uid', $uid)
                    ->get();

                $prescriptionData = $prescriptions->isEmpty() ? null : $prescriptions->toArray();
            }

            return [
                'uid' => $firstRow->uid,
                'type' => $firstRow->type,
                'customer_name' => $customerExists ? $firstRow->customer_name : null,
                'emp_name' => $employeeExists ? $firstRow->emp_name : null,
                'date' => \Carbon\Carbon::parse($firstRow->created_at)->format('Y-m-d'),
                'billing_details' => $group->map(fn($item) => json_decode(json_encode($item), true))->toArray(),
                'tax_details' => $group->map(fn($item) => json_decode(json_encode($item), true))->toArray(),
                'prescription' => $prescriptionData,
            ];
        })->values()->toArray();

        return response()->json([
            'message' => 'Invoice or Proposal fetched successfully.',
            'data' => $data,
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to retrieve invoice or proposal.',
            'error' => $e->getMessage(),
        ], 500);
    }
}
public function getInvoiceOrProposalPdfBase64(Request $request)
{

    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'invoice_id' => 'required|integer',
    ]);

    $tenantSchema = $validated['tenant_schema'];

    $invoiceResponse = $this->getInvoiceAndProposal($request);
    
    $invoiceData = json_decode($invoiceResponse->getContent(), true);
    if (empty($invoiceData['data'])) {
        return response()->json([
            'message' => 'No invoice or proposal found for the provided UID.',
        ], 200);
    }

    $invoice = $invoiceData['data'];

    $tenant = DB::connection('master_db')
        ->table('tenants')
        ->where('tenant_schema', $tenantSchema)
        ->first();

    if (!$tenant) {
        return response()->json([
            'message' => 'Tenant not found.',
        ], 200);
    }
    $imagePath = $tenant->image ? 'storage/' . ltrim($tenant->image, '/') : null;

    $invoice['company'] = [
        'first_name'    => $tenant->first_name ?? '',
        'full_address'  => $tenant->full_address ?? '',
        'mobile'        => $tenant->mobile ?? '',
        'company_name'  => $tenant->company_name ?? '',
        'image'         => $imagePath,
    ];

    $html = InvoiceHelper::buildInvoiceHtml($invoice);
   
    $pdf = Pdf::loadHTML($html);
     
    $pdf->setPaper('a4', 'portrait');
    $pdf->setOption('dpi', 200); 
    $pdf->setOption('isHtml5ParserEnabled', true);
    $pdf->setOption('isRemoteEnabled', true);


    $base64Pdf = base64_encode($pdf->output());

    return response()->json([
        'message' => 'PDF generated successfully',
        'data' => [
            'base64_pdf' => $base64Pdf,
            'file_name' => "{$invoice['type']}_{$invoice['invoice_no']}.pdf",
        ],
    ]);
}

public function syncData(Request $request)
{
    $user = Auth::guard('api')->user();
    if (!$user || !isset($user->tenant_schema)) {
        return response()->json(['message' => 'Tenant schema missing in token'], 401);
    }

    $apiBaseUrl = env('OPENCART_API_URL');
    $tenantId = $user->id;
    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);

    $databaseName = DB::connection('master_db')->getDatabaseName();
    $productCatalogTable = 'product-catalogs';

    if (!Schema::hasColumn($productCatalogTable, 'market_place')) {
        Schema::table($productCatalogTable, function (Blueprint $table) {
            $table->tinyInteger('market_place')->default(0)->after('status');
        });
    }
    
    $alreadySynced = DB::connection('master_db')->table('tenants')->where('id', $tenantId)
        ->where('market_place', 1)
        ->exists();

    if ($alreadySynced) {
        return response()->json(['message' => 'User already exists'], 409);
    }

    $customer = DB::connection('master_db')->table('tenants')->where('id', $tenantId)->first();
    $businessId = $customer->business_id;
    if (!$customer) {
        return response()->json(['message' => 'Tenant not found'], 200);
    }

    $password = $customer->first_name . substr($customer->mobile ?? '', -4);
    $customerId = (int) substr(strrchr($tenantSchema, '_'), 1);
    $email = !empty($customer->email) ? $customer->email : "$tenantSchema@waqin.ai";
    $customerPayload = [
        'customer_id' => $customerId,
        'firstname' => $customer->first_name ?? '',
        'lastname' => $customer->last_name ?? '',
        'email' => $email,
        'telephone' => $customer->mobile ?? '',
        'password' => $password,
        'store_id' => 0,
    ];

    $customerResponse = Http::asForm()->post("{$apiBaseUrl}/index.php?route=api/rest/customer/addCustomer", $customerPayload);
    if (!$customerResponse->ok()) {
        return response()->json(['message' => 'Failed to add customer', 'details' => $customerResponse->body()], 500);
    }

    $customerId = $customerResponse->json()['customer_id'] ?? null;
    if (!$customerId) {
        return response()->json(['message' => 'Failed to retrieve customer ID from OpenCart'], 500);
    }

    $vendorPayload = [
        'meta_title' => $customer->first_name ?? 'demo',
        'meta_description' => $customer->company_name ?? 'demo description',
        'meta_keyword' => 'Demo Keyword',
        'store_owner' => $customer->first_name ?? '',
        'store_name' => $customer->company_name ?? 'Default Store',
        'address' => $customer->full_address ?? 'Default Address',
        'email' => $customer->email ?? '',
        'telephone' => $customer->mobile ?? '',
        'customer_id' => $customerId,
        'country_id' => 99,
    ];

    $vendorResponse = Http::asForm()->post("{$apiBaseUrl}/index.php?route=api/rest/vendor/addVendor", $vendorPayload);
    if (!$vendorResponse->ok()) {
        return response()->json(['message' => 'Failed to add vendor', 'details' => $vendorResponse->body()], 500);
    }

    $vendorId = $vendorResponse->json()['vendor_id'] ?? null;

    $products = DB::table('product-catalogs as pc')
        ->join("{$databaseName}.sales_and_services as ss", 'pc.category_name', '=', 'ss.product_category')
        ->select('pc.*', 'ss.id as category_id')
        ->where([
            ['ss.business_id', '=', $businessId],
            ['pc.status', '=', 1],
            ['pc.is_deleted', '=', 0],
        ])
        ->get();

    $addedOpenCartProductIds = [];
    $productUpdates = [];

    foreach ($products as $product) {
        $productPayload = [
            'waqin_prod_id' => $product->id ?? '',
            'tenant_schema' => $tenantSchema,
            'product_description' => [
                1 => [
                    'name' => $product->title ?? '',
                    'description' => $product->description ?? 'description',
                    'meta_title' => $product->category_name ?? 'title',
                ]
            ],
            'product_category' => [
                'category_id' => $product->category_id ?? '',
            ],
            'language_id' => 1,
            'vendor_id' => $vendorId,
            'model' => $product->category_name ?? 'demo model',
            'price' => $product->price ?? '0.00',
            'tax_class_id' => 0,
            'quantity' => $product->available_quantity ?? 1,
            'minimum' => 1,
            'subtract' => 1,
            'stock_status_id' => 6,
            'shipping' => 1,
            'length_class_id' => 1,
            'weight_class_id' => 1,
            'sort_order' => 1,
            'status' => 1,
            'image' => $product->image ? asset('storage/' . $product->image) : asset('storage/default.jpg'),
        ];

        $productResponse = Http::asJson()->post("{$apiBaseUrl}/index.php?route=api/rest/product/addProduct", $productPayload);

        if ($productResponse->ok() && isset($productResponse->json()['product_id'])) {
            $ocProductId = $productResponse->json()['product_id'];
            $addedOpenCartProductIds[] = $ocProductId;
            $productUpdates[] = [
                'id' => $product->id,
                'oc_product_id' => $ocProductId
            ];
        }
    }

    // Add columns if they don't exist
    $ocStatusColumn = DB::select("SHOW COLUMNS FROM `$productCatalogTable` LIKE 'oc_status'");
    if (empty($ocStatusColumn)) {
        DB::statement("ALTER TABLE `$productCatalogTable` ADD COLUMN `oc_status` TINYINT(1) NOT NULL DEFAULT 0");
    }

    $ocProductIdColumn = DB::select("SHOW COLUMNS FROM `$productCatalogTable` LIKE 'oc_product_id'");
    if (empty($ocProductIdColumn)) {
        DB::statement("ALTER TABLE `$productCatalogTable` ADD COLUMN `oc_product_id` BIGINT NULL DEFAULT NULL");
    }
  
    $ocProductUrlColumn = DB::select("SHOW COLUMNS FROM `$productCatalogTable` LIKE 'oc_product_url'");
      if (empty($ocProductUrlColumn)) {
          DB::statement("ALTER TABLE `$productCatalogTable` ADD COLUMN `oc_product_url` VARCHAR(250) NULL DEFAULT NULL");
      }
    
    // Update all products with their OpenCart IDs
    foreach ($productUpdates as $update) {
        DB::table($productCatalogTable)
            ->where('id', $update['id'])
            ->update([
                'market_place' => 1,
                'oc_status' => 1,
                'oc_product_id' => $update['oc_product_id'],
                'oc_product_url' => 'https://env-1383057.cloudjiffy.net/index.php?route=product/product&product_id='.$update['oc_product_id']
            ]);
    }
  
  $customer = DB::connection('master_db')->table('tenants')->where('id', $tenantId)->update([
                'market_place' => 1,
    			'market_place_url' => 'https://env-1383057.cloudjiffy.net/index.php?route=vendor/lts_visit&vendor_id='.$vendorId
            ]);;


    $storeResponse = null;
    if (!empty($addedOpenCartProductIds)) {
        $storeResponse = Http::asJson()->post("{$apiBaseUrl}/index.php?route=api/rest/product/addProductToStore", [
            'product_ids' => $addedOpenCartProductIds
        ]);
    }

    return response()->json([
        'message' => "You're in! Start growing your business on your marketplace."
       
    ]);
}

public function addSelectedProduct(Request $request)
{
    $user = Auth::guard('api')->user();
    if (!$user || !isset($user->tenant_schema)) {
        return response()->json(['message' => 'Tenant schema missing in token'], 401);
    }

    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);
    $masterDb = DB::connection('master_db');

    $telephone = $user->mobile ?? '';
    if (empty($telephone)) {
        return response()->json(['message' => 'User mobile is missing'], 400);
    }

    $products = $request->input('products', []);
    if (empty($products)) {
        return response()->json(['message' => 'No products selected'], 400);
    }

    $payload = [
        'telephone' => $telephone,
        'products' => []
    ];

    $localProductIds = [];

    foreach ($products as $product) {
        $categoryName = $product['category_name'] ?? null;
        if (!$categoryName) {
            return response()->json(['message' => 'Product category_name missing'], 400);
        }

        $category = $masterDb->table('sales_and_services')
            ->where('product_category', $categoryName)
            ->select('id')
            ->first();

        if (!$category) {
            return response()->json(['message' => 'Category not found: ' . $categoryName], 400);
        }

        if (isset($product['id'])) {
            $localProductIds[] = $product['id'];
        }

        $productPayload = [
            'waqin_prod_id' => $product['id'],
            'product_description' => [
                1 => [
                    'name' => $product['title'] ?? 'Untitled',
                    'description' => $product['description'] ?? 'No description',
                    'meta_title' => $product['title'] ?? 'Meta Title'
                ]
            ],
            'product_category' => [
                'category_id' => $category->id,
            ],
            'model' => $categoryName,
            'price' => $product['price'] ?? '0.00',
            'tax_class_id' => 0,
            'quantity' => $product['available_quantity'] ?? 1,
            'minimum' => 1,
            'subtract' => 1,
            'stock_status_id' => 6,
            'shipping' => 1,
            'length_class_id' => 1,
            'weight_class_id' => 1,
            'sort_order' => 1,
            'status' => 1,
            'image' => isset($product['image']) ? asset('storage/' . ltrim($product['image'], '/')) : asset('storage/default.jpg'),
            'tenant_schema' => $tenantSchema,
        ];
        
        $payload['products'][] = $productPayload;
    }
    
    $response = Http::asJson()->post(env('OPENCART_API_URL') . "/index.php?route=api/rest/product/addSelectedProduct", $payload);

    if ($response->ok()) {
        $responseData = $response->json();

        $addedProductIds = [];
        if (!empty($responseData['added_products'])) {
            foreach ($responseData['added_products'] as $addedProduct) {
                if (!empty($addedProduct['product_id'])) {
                    $addedProductIds[] = $addedProduct['product_id'];
                }
            }
        }

        $tableName = 'product-catalogs';

        $ocColumn = DB::select("SHOW COLUMNS FROM `$tableName` LIKE 'oc_status'");
        if (empty($ocColumn)) {
            DB::statement("ALTER TABLE `$tableName` ADD COLUMN `oc_status` TINYINT(1) NOT NULL DEFAULT 0");
        }
        
        if (!empty($localProductIds)) {
                DB::table($tableName)
                    ->whereIn('id', $localProductIds)
                    ->update([
                        'market_place' => 1,
                        'oc_status' => 1
                    ]);
            }

        if (!empty($addedProductIds)) {
            $storeResponse = Http::asJson()->post(env('OPENCART_API_URL') . "/index.php?route=api/rest/product/addProductToStore", [
                'product_ids' => $addedProductIds
            ]);

            return response()->json([
                'message' => 'Selected products synced and assigned to store successfully',
                'response' => $responseData,
                'store_response' => $storeResponse->json()
            ]);
        }
    }

    return response()->json([
        'message' => 'Failed to sync products',
        'response' => $response->json()
    ], 500);
}

public function updateProductStatus(Request $request)
{
    $products = $request->input('products');
    $tenant_schema = Auth::user()->tenant_schema; // Or from token

    if (!$products || !is_array($products)) {
        return response()->json(['error' => 'No products provided'], 400);
    }

    // Add tenant_schema to each product
    foreach ($products as &$product) {
        $product['tenant_schema'] = $tenant_schema;
    }

    $ocApiUrl = env('OPENCART_API_URL') . '/index.php?route=api/rest/product/updateProductStatus';

    $response = Http::post($ocApiUrl, [
        'products' => $products
    ]);

    if ($response->failed()) {
        return response()->json(['error' => 'Failed to update product status in OpenCart', 'details' => $response->body()], 500);
    }

    $data = $response->json();

    QueryHelper::initializeConnection($tenant_schema);

        $tableName = 'product-catalogs'; // Use underscores and no schema prefix
        $columnExists = DB::select("SHOW COLUMNS FROM `$tableName` LIKE 'oc_status'");
        if (empty($columnExists)) {
            DB::statement("ALTER TABLE `$tableName` ADD COLUMN `oc_status` TINYINT(1) NOT NULL DEFAULT 0");
        }

        // Update oc_status for each product based on waqin_prod_id and status
        foreach ($products as $product) {
            $waqin_prod_id = $product['waqin_prod_id'] ?? null;
            $status = isset($product['status']) && $product['status'] == 1 ? 1 : 0;

            if ($waqin_prod_id) {
                DB::table($tableName)
                    ->where('id', $waqin_prod_id)
                    ->update(['oc_status' => $status]);
            }
        }
   
    return response()->json([
        'success' => true,
        'message' => 'Product status updated successfully!',
        'updated' => array_column($data['updated'] ?? [], 'waqin_prod_id'),
    ]);
}

public function deleteTenant(Request $request)
{
    try {
        // Authenticate user from Bearer Token
        $user = Auth::guard('api')->user();

        if (!$user || !$user->tenant_schema) {
            return response()->json(['message' => 'Unauthorized or tenant schema not found.'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        $tenant = Tenant::where('tenant_schema', $tenantSchema)->firstOrFail();
        $tenantId = $tenant->id;

        // Paths
        $storagePath = storage_path("app/backups");
        $tenantBackupPath = "$storagePath/$tenantSchema";
        $dbBackupFile = "$tenantBackupPath/{$tenantSchema}_db.sql";
        $tenantDataFile = "$tenantBackupPath/{$tenantSchema}_data.sql";
        $zipFilePath = "$storagePath/{$tenantSchema}.zip";
        $tenantFolder = storage_path("app/public/{$tenantSchema}");

        File::makeDirectory($tenantBackupPath, 0777, true, true);

        // Backup the tenant's database
        $tables = DB::select("SHOW TABLES FROM `$tenantSchema`");
        $tableKey = 'Tables_in_' . $tenantSchema;
        $sqlDump = "";

        foreach ($tables as $table) {
            $tableName = $table->$tableKey;

            // Table schema
            $createTableQuery = DB::select("SHOW CREATE TABLE `$tenantSchema`.`$tableName`");
            $sqlDump .= $createTableQuery[0]->{"Create Table"} . ";\n\n";

            // Table data
            $rows = DB::select("SELECT * FROM `$tenantSchema`.`$tableName`");
            foreach ($rows as $row) {
                $values = array_map(fn($val) => $val === null ? 'NULL' : "'" . addslashes($val) . "'", (array)$row);
                $sqlDump .= "INSERT INTO `$tableName` VALUES (" . implode(", ", $values) . ");\n";
            }
            $sqlDump .= "\n\n";
        }

        File::put($dbBackupFile, $sqlDump);

        // Backup tenant record from master DB
        $tenantRow = DB::table('tenants')->where('id', $tenantId)->get()->toArray();
        $tenantSqlDump = "INSERT INTO `tenants` VALUES\n";
        foreach ($tenantRow as $row) {
            $values = array_map(fn($val) => $val === null ? 'NULL' : "'" . addslashes($val) . "'", (array)$row);
            $tenantSqlDump .= "(" . implode(", ", $values) . ");\n";
        }
        File::put($tenantDataFile, $tenantSqlDump);

        // Backup storage folder
        if (File::exists($tenantFolder)) {
            File::copyDirectory($tenantFolder, "$tenantBackupPath/public_files");
        }

        // ZIP it
        $zip = new ZipArchive();
        if ($zip->open($zipFilePath, ZipArchive::CREATE) === true) {
            $files = File::allFiles($tenantBackupPath);
            foreach ($files as $file) {
                $relativePath = substr($file->getRealPath(), strlen($tenantBackupPath) + 1);
                $zip->addFile($file->getRealPath(), $relativePath);
            }
            $zip->close();
        }

        // Delete temp
        File::deleteDirectory($tenantBackupPath);

        // Drop DB
        DB::statement("DROP DATABASE IF EXISTS `$tenantSchema`");

        // Delete folder
        File::deleteDirectory($tenantFolder);

        // Delete tenant record
        $tenant->delete();

        return response()->json([
            'message' => 'Tenant deleted successfully. Backup created.',
            'backup_path' => $zipFilePath,
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Error while deleting tenant.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function getLatestApkVersion()
{
    try {
        // Get the latest APK entry from master DB
        $apk = DB::connection('master_db')
            ->table('apks')
            ->orderByDesc('id')
            ->select('version', 'message', 'force_update')
            ->first();

        if (!$apk) {
            return response()->json([
                'success' => true,
                'message' => 'No version found.',
                'data' => null
            ], 200);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'version' => $apk->version,
                'message' => $apk->message,
                'force_update' => (bool) $apk->force_update,
            ]
        ], 200);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Error fetching latest APK: ' . $e->getMessage()
        ], 500); // Only actual system errors get 500
    }
}

public function getAttachmentsByCustomer(Request $request)
{
    try {
        // Validate the incoming request
        $validated = $request->validate([
            'customer_id' => 'required|integer',
        ]);

        $customerId = $validated['customer_id'];

        // Step 1: Get tenant schema from authenticated user
        $tenantSchema = auth()->user()->tenant_schema;

        // Step 2: Initialize DB connection for tenant
        QueryHelper::initializeConnection($tenantSchema);

        $attachmentTable = 'attachments';

        // Step 3: Check if the table exists
        if (!Schema::hasTable($attachmentTable)) {
            return response()->json([
                'message' => 'No attachments.',
                'data' => [],
            ], 200);
        }

        // Step 4: Fetch attachments for the customer
        $attachments = DB::table($attachmentTable)
            ->where('customer_id', $customerId)
            ->where('status', 1)
            ->orderBy('created_at', 'desc')
            ->get();

        if ($attachments->isEmpty()) {
            return response()->json([
                'message' => 'No attachments.',
                'data' => [],
            ], 200);
        }

        return response()->json([
            'message' => 'Attachments fetched successfully.',
            'data' => $attachments,
        ]);

    } catch (\Exception $e) {
        Log::error("Error fetching attachments: " . $e->getMessage());
        return response()->json([
            'message' => 'Failed to fetch attachments.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function deleteAttachment(Request $request)
{
    try {
        // Step 1: Validate request input
        $validated = $request->validate([
            'id' => 'required|integer',
        ]);

        $attachmentId = $validated['id'];

        // Step 2: Get tenant schema from authenticated user
        $tenantSchema = auth()->user()->tenant_schema;

        // Step 3: Initialize tenant connection
        QueryHelper::initializeConnection($tenantSchema);

        $attachmentTable = 'attachments';
        // Step 5: Fetch attachment
        $attachment = DB::table($attachmentTable)->where('id', $attachmentId)->first();
        // Step 6: Delete file from storage if it exists
        if ($attachment->path && Storage::disk('public')->exists($attachment->path)) {
            Storage::disk('public')->delete($attachment->path);
        }

        // Step 7: Delete from DB
        DB::table($attachmentTable)->where('id', $attachmentId)->delete();

        return response()->json([
            'message' => 'Attachment deleted successfully.',
        ], 200);

    } catch (\Exception $e) {
        Log::error("Delete attachment error: " . $e->getMessage());
        return response()->json([
            'message' => 'Failed to delete attachment.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function updateInvoiceOrProposal(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
        'uid' => 'required|string',
        'type' => 'required|string|in:invoice,proposal',
        'form_data' => 'nullable|array',
        'bill_items' => 'required|array',
        'tax_details' => 'required|array',
        'prescription_detail' => 'nullable|array',
    ]);

    $tenantSchema = $validated['tenant_schema'];
    $uid = $validated['uid'];
    $type = $validated['type'];
    $formData = $validated['form_data'] ?? [];
    $billItems = $validated['bill_items'];
    $taxDetails = $validated['tax_details'];
    $prescriptionDetail = $validated['prescription_detail'] ?? null;

    $billsTable = 'invoice_or_proposals';
    $taxTable = 'tax';
    $prescriptionTable = 'prescription';

    try {
        QueryHelper::initializeConnection($tenantSchema);

        // Handle dynamic columns for bills table
        $combinedKeys = array_unique(array_merge(
            array_keys($formData),
            array_keys($billItems[0])
        ));

        foreach ($combinedKeys as $key) {
            if (!Schema::hasColumn($billsTable, $key)) {
                Schema::table($billsTable, function ($table) use ($key) {
                    $table->text($key)->nullable();
                });
            }
        }

        // Handle dynamic columns for tax table
        $taxKeys = array_keys($taxDetails[0]);
        foreach ($taxKeys as $key) {
            if (!Schema::hasColumn($taxTable, $key)) {
                Schema::table($taxTable, function ($table) use ($key) {
                    $table->text($key)->nullable();
                });
            }
        }

        // Handle dynamic columns for prescription table if prescription provided
        if ($prescriptionDetail) {
            if (!Schema::hasTable($prescriptionTable)) {
                Schema::create($prescriptionTable, function ($table) use ($prescriptionDetail) {
                    $table->id();
                    foreach ($prescriptionDetail as $key => $value) {
                        $table->text($key)->nullable();
                    }
                    $table->string('uid')->nullable();
                    $table->timestamps();
                });
            } else {
                foreach ($prescriptionDetail as $key => $value) {
                    if (!Schema::hasColumn($prescriptionTable, $key)) {
                        Schema::table($prescriptionTable, function ($table) use ($key) {
                            $table->text($key)->nullable();
                        });
                    }
                }
            }
        }

        // ✅ UPDATE bills table
        $existingBillRows = DB::table($billsTable)->where('uid', $uid)->get();

        if ($existingBillRows->count() > 0) {
            $existingRowsCount = $existingBillRows->count();
            $incomingRowsCount = count($billItems);

            // Loop for existing rows update
            for ($i = 0; $i < min($existingRowsCount, $incomingRowsCount); $i++) {
                $existingRow = $existingBillRows[$i];
                $item = $billItems[$i];
                $merged = array_merge($formData, $item);

                $updateData = [];
                foreach ($merged as $col => $val) {
                    $updateData[$col] = $val;
                }
                $updateData['type'] = $type;
                $updateData['updated_at'] = now();

                DB::table($billsTable)->where('id', $existingRow->id)->update($updateData);
            }

            // Insert remaining new bill items if any
            if ($incomingRowsCount > $existingRowsCount) {
                for ($i = $existingRowsCount; $i < $incomingRowsCount; $i++) {
                    $item = $billItems[$i];
                    $merged = array_merge($formData, $item);
                    $data = [
                        'uid' => $uid,
                        'type' => $type,
                        'status' => 1,
                        'is_deleted' => 0,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                    foreach ($merged as $col => $val) {
                        $data[$col] = $val;
                    }
                    DB::table($billsTable)->insert($data);
                }
            }
        } else {
            // No existing rows: insert all
            foreach ($billItems as $item) {
                $merged = array_merge($formData, $item);
                $data = [
                    'uid' => $uid,
                    'type' => $type,
                    'status' => 1,
                    'is_deleted' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
                foreach ($merged as $col => $val) {
                    $data[$col] = $val;
                }
                DB::table($billsTable)->insert($data);
            }
        }

        // ✅ Similar logic for tax table
        $existingTaxRows = DB::table($taxTable)->where('uid', $uid)->get();

        if ($existingTaxRows->count() > 0) {
            $existingRowsCount = $existingTaxRows->count();
            $incomingRowsCount = count($taxDetails);

            for ($i = 0; $i < min($existingRowsCount, $incomingRowsCount); $i++) {
                $existingRow = $existingTaxRows[$i];
                $tax = $taxDetails[$i];

                $updateData = [];
                foreach ($tax as $col => $val) {
                    $updateData[$col] = $val;
                }
                $updateData['type'] = $type;
                $updateData['updated_at'] = now();

                DB::table($taxTable)->where('id', $existingRow->id)->update($updateData);
            }

            if ($incomingRowsCount > $existingRowsCount) {
                for ($i = $existingRowsCount; $i < $incomingRowsCount; $i++) {
                    $tax = $taxDetails[$i];
                    $taxData = [
                        'uid' => $uid,
                        'type' => $type,
                        'status' => 1,
                        'is_deleted' => 0,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                    foreach ($tax as $col => $val) {
                        $taxData[$col] = $val;
                    }
                    DB::table($taxTable)->insert($taxData);
                }
            }
        } else {
            foreach ($taxDetails as $tax) {
                $taxData = [
                    'uid' => $uid,
                    'type' => $type,
                    'status' => 1,
                    'is_deleted' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
                foreach ($tax as $col => $val) {
                    $taxData[$col] = $val;
                }
                DB::table($taxTable)->insert($taxData);
            }
        }

        // ✅ Update prescription if exists
        if ($prescriptionDetail) {
            $existingPrescription = DB::table($prescriptionTable)->where('uid', $uid)->first();

            $prescriptionData = array_merge($prescriptionDetail, [
                'updated_at' => now(),
            ]);

            if ($existingPrescription) {
                DB::table($prescriptionTable)->where('uid', $uid)->update($prescriptionData);
            } else {
                $prescriptionData['uid'] = $uid;
                $prescriptionData['created_at'] = now();
                DB::table($prescriptionTable)->insert($prescriptionData);
            }
        }
        return response()->json([
            'message' => 'Invoice/Proposal updated successfully.',
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to update invoice/proposal.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

//   public function clearRedisCache()
//     {
//         try {
//             Redis::flushall(); // ⚠️ This deletes all keys from all Redis databases!
//             return response()->json(['message' => 'All Redis keys flushed successfully.']);
//         } catch (\Exception $e) {
//             return response()->json([
//                 'message' => 'Failed to flush Redis keys.',
//                 'error' => $e->getMessage(),
//             ], 500);
//         }
//     }



    public function getMarketplaceOrder(Request $request)
{
    $validated = $request->validate([
        'tenant_schema' => 'required|string',
    ]);

    QueryHelper::initializeConnection($validated['tenant_schema']);

    $orders = DB::table('oc_order')->get();

    if ($orders->isEmpty()) {
        return response()->json(['message' => 'Order not found'], 200);
    }

    // List of fields to decode
    $jsonFields = [
        'customer_data',
        'payment_data',
        'shipping_data',
        'products',
        'totals',
        'vouchers'
    ];

    // Map & decode for each order
    $orders = $orders->map(function($order) use ($jsonFields) {
        foreach ($jsonFields as $field) {
            if (isset($order->$field) && $order->$field !== null) {
                $decoded = json_decode($order->$field, true);
                $order->$field = $decoded === null ? $order->$field : $decoded;
            }
        }
        return $order;
    });

    return response()->json(['data' => $orders], 200);
}

  
   public function AppPermissions()
    {
        $permissions = DB::table('app_permissions')
            ->select('permission_group', 'android_permissions', 'purpose', 'usage_description', 'user_control', 'is_optional')
            ->orderBy('permission_group')
            ->get();
 
        return response()->json([
            'status' => true,
            'data' => $permissions
        ]);
    }

}






