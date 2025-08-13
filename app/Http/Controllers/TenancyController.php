<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;
use App\Models\Tenant;
use App\Models\BusinessCategory;
use App\Models\Service;
use App\Models\Status;
use App\Http\Controllers\ApiController;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;
use ZipArchive;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Tymon\JWTAuth\Facades\JWTAuth;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Str;

class TenancyController extends Controller
{
    public function index()
    {
        $tenancies = Tenant::whereNull('user_type')
        ->orderBy('created_at', 'desc')
        ->get();
        $businessCategories = BusinessCategory::orderBy('name')->get();
        $services = Service::orderBy('service')->get();
        
        return view('superadmin.tenants', compact('tenancies', 'businessCategories', 'services'));
    }

    public function dashboardview()
    {
        return view('superadmin.dashboard');
    }

    public function activate($id)
   {
       try {
           $tenancies = Tenant::findOrFail($id);
           $tenancies->status = 1;
           $tenancies->save();

           return redirect()->back()->with('success', 'Tenant activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Tenant.');
       }
   }

   public function deactivate($id)
   {
       try {
        $tenancies = Tenant::findOrFail($id);
        $tenancies->status = 0;
        $tenancies->save();

           return redirect()->back()->with('success', 'Tenant deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate Tenant.');
       }
   }

   public function destroy($id)
{
    try {
        // Find the tenant
        $tenant = Tenant::findOrFail($id);
        $tenantSchema = $tenant->tenant_schema;

        // Define paths
        $storagePath = storage_path("app/backups");
        $tenantBackupPath = "$storagePath/$tenantSchema";
        $dbBackupFile = "$tenantBackupPath/{$tenantSchema}_db.sql";
        $tenantDataFile = "$tenantBackupPath/{$tenantSchema}_data.sql";
        $zipFilePath = "$storagePath/{$tenantSchema}.zip";
        $tenantFolder = storage_path("app/public/{$tenantSchema}");

        // Create backup directory
        File::makeDirectory($tenantBackupPath, 0777, true, true);

        // Backup the tenant's database (schema and data)
        $tables = DB::select("SHOW TABLES FROM `$tenantSchema`");
        $sqlDump = "";

        foreach ($tables as $table) {
            $tableName = reset($table);

            // Get table schema
            $createTableQuery = DB::select("SHOW CREATE TABLE `$tenantSchema`.`$tableName`");
            $sqlDump .= $createTableQuery[0]->{"Create Table"} . ";\n\n";

            // Get table data
            $rows = DB::select("SELECT * FROM `$tenantSchema`.`$tableName`");
            foreach ($rows as $row) {
                $values = array_map(fn($val) => $val === null ? 'NULL' : "'" . addslashes($val) . "'", (array)$row);
                $sqlDump .= "INSERT INTO `$tableName` VALUES (" . implode(", ", $values) . ");\n";
            }
            $sqlDump .= "\n\n";
        }

        // Save the database dump
        File::put($dbBackupFile, $sqlDump);

        // Backup the tenant's row from the master `tenants` table
        $tenantRow = DB::table('tenants')->where('id', $id)->get()->toArray();
        $tenantSqlDump = "INSERT INTO `tenants` VALUES\n";
        foreach ($tenantRow as $row) {
            $values = array_map(fn($val) => $val === null ? 'NULL' : "'" . addslashes($val) . "'", (array)$row);
            $tenantSqlDump .= "(" . implode(", ", $values) . ");\n";
        }
        File::put($tenantDataFile, $tenantSqlDump);

        // Backup the tenant's folder
        if (File::exists($tenantFolder)) {
            File::copyDirectory($tenantFolder, "$tenantBackupPath/{$tenantSchema}");
        }

        // Create ZIP archive
        $zip = new ZipArchive();
        if ($zip->open($zipFilePath, ZipArchive::CREATE) === true) {
            $files = File::allFiles($tenantBackupPath);
            foreach ($files as $file) {
                $relativePath = substr($file->getRealPath(), strlen($tenantBackupPath) + 1);
                $zip->addFile($file->getRealPath(), $relativePath);
            }
            $zip->close();
        }

        // Delete the backup directory after zipping
        File::deleteDirectory($tenantBackupPath);

        // Drop the tenant database
        DB::statement("DROP DATABASE IF EXISTS `$tenantSchema`");

        // Delete the tenant folder
        File::deleteDirectory($tenantFolder);

        // Delete the tenant record
        $tenant->delete();

        return redirect()->back()->with('success', 'Tenant, database, and folder deleted. Backup saved as ZIP.');
    } catch (\Exception $e) {
        return redirect()->back()->with('error', 'Failed to delete Tenant: ' . $e->getMessage());
    }
}
      
   public function deleteTenants()
   {
       try {
           $tenants = DB::table('tenants')->get();
   
           DB::table('tenants')->truncate();
   
           foreach ($tenants as $tenant) {
               $tenantSchema = $tenant->tenant_schema;
   
               DB::statement("DROP DATABASE IF EXISTS `$tenantSchema`");
           }
   
           return response()->json([
               'success' => true,
               'message' => 'All tenants and their databases have been successfully deleted.',
           ], 200);
       } catch (\Exception $e) {
           return response()->json([
               'success' => false,
               'message' => 'Error occurred while deleting tenants: ' . $e->getMessage(),
           ], 500);
       }
   }

   public function viewTenantDetail($encryptedId)
{
    try {
        // Find the tenant by ID
        $id = Crypt::decryptString(base64_decode($encryptedId));
        $tenant = Tenant::findOrFail($id);
        $tenantSchema = $tenant->tenant_schema;

        // Fetch general data
        $businessCategories = BusinessCategory::orderBy('name')->get();
        $statuses = Status::orderBy('name')->get();

        // Initialize empty arrays for tenant-specific data
        $customers = [];
        $customerDetails = [];
        $callHistory = [];
        $employees = [];

        // Check if the tables exist in the tenant's schema
        $tables = DB::select("SELECT table_name FROM information_schema.tables WHERE table_schema = ?", [$tenantSchema]);

        if (!empty($tables)) {
            // Fetch data only if the tables exist
            if ($this->tableExists($tenantSchema, 'customers')) {
                $customers = DB::select("SELECT * FROM `{$tenantSchema}`.customers");
            }
            if ($this->tableExists($tenantSchema, 'customer_details')) {
                $customerDetails = DB::select("SELECT * FROM `{$tenantSchema}`.customer_details");
            }
            if ($this->tableExists($tenantSchema, 'call_history')) {
                $callHistory = DB::select("SELECT * FROM `{$tenantSchema}`.call_history");
            }
            if ($this->tableExists($tenantSchema, 'employees')) {
                $employees = DB::select("SELECT * FROM `{$tenantSchema}`.employees");
            }
            
            // Get business user employee's mobile number
            $businessUser = DB::table("{$tenantSchema}.employees")
                ->where('employee_type', 'Business user')
                ->select('mobile', 'id')
                ->first();
            
            if ($businessUser) {
                // Fetch the tenant ID where the mobile matches AND ensure it's from the same tenant
                $matchedTenant = Tenant::where('mobile', $businessUser->mobile)
                    ->where('id', $tenant->id) // Ensure it belongs to the same tenant
                    ->first();
            
                if ($matchedTenant) {
                    $tenant->id = $matchedTenant->id;
                }
            }
            
        }

        // Pass the data to the view, even if they are empty
        return view('superadmin.tenants_detail_view', compact('tenant', 'businessCategories', 'customers', 'statuses', 'customerDetails', 'callHistory', 'employees'));

    } catch (\Exception $e) {
        return back()->withErrors(['error' => $e->getMessage()]);
    }
}

private function tableExists($tenantSchema, $tableName)
{
    $result = DB::select("SELECT COUNT(*) as count FROM information_schema.tables WHERE table_schema = ? AND table_name = ?", [$tenantSchema, $tableName]);
    return $result[0]->count > 0;
}

public function adminAutoLogin($id)
{
    $user = Tenant::findOrFail($id);

    if (!$user->mobile_verify) {
        return response()->json(['status' => 'failed', 'message' => 'Mobile not verified.'], 403);
    }

    if (!$user->password) {
        return response()->json(['status' => 'failed', 'message' => 'PIN not created, please create one.'], 403);
    }

    $token = Auth::guard('api')->login($user);
    
    if (!$token) {
        return response()->json(['status' => 'failed', 'message' => 'Could not generate token'], 500);
    }

    $tenantWebAppUrl = env('TENANT_WEBAPP_URL', 'http://localhost:5173');

    return redirect()->away("$tenantWebAppUrl?access_token=$token");
}

}
