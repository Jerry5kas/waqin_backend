<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use DB;

class PackageController extends Controller
{
    // Manage Features Page
    public function features() {
        $features = DB::table('tbl_feature')->orderBy('id','desc')->get();
        return view('superadmin.manage_package.features', compact('features'));
    }

    // Store Feature
    public function storeFeature(Request $request) {
        $request->validate([
            'module_name' => 'required|string',
            'uid' => 'required|string|unique:tbl_feature,uid',
        ]);

        DB::table('tbl_feature')->insert([
            'module_name' => $request->module_name,
            'uid' => $request->uid,
            'status' => 1,
            'is_deleted' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return redirect()->back()->with('success', 'Feature added successfully.');
    }

    // Delete Feature
    public function deleteFeature($id) {
        DB::table('tbl_feature')->where('id', $id)->delete();
        return redirect()->back()->with('success', 'Feature deleted successfully.');
    }

    // Activate Feature
    public function activateFeature($id)
    {
        DB::table('tbl_feature')->where('id', $id)->update(['status' => 1]);
        return redirect()->back()->with('success', 'Feature activated successfully.');
    }

    public function deactivateFeature($id)
    {
        DB::table('tbl_feature')->where('id', $id)->update(['status' => 0]);
        return redirect()->back()->with('success', 'Feature deactivated successfully.');
    }

    public function updateFeature(Request $request)
    {
        $request->validate([
            'id' => 'required|integer',
            'module_name' => 'required|string',
            'uid' => 'required|string',
        ]);

        DB::table('tbl_feature')->where('id', $request->id)->update([
            'module_name' => $request->module_name,
            'uid' => $request->uid
        ]);

        return redirect()->back()->with('success', 'Feature updated successfully.');
    }

    // Manage Packages
    public function packages() {
        $features = DB::table('tbl_feature')->where('is_deleted', 0)->get();
        $packages = DB::table('tbl_package')->get();
        return view('superadmin.manage_package.packages', compact('packages', 'features'));
    }

    public function storePackage(Request $request) {
        $request->validate([
            'name' => 'required',
            'modules' => 'required|array',
            'feature_list' => 'required|array',
        ]);

        DB::table('tbl_package')->insert([
            'name' => $request->name,
            'modules' => json_encode($request->modules),
            'feature_list' => json_encode($request->feature_list),
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return redirect()->back()->with('success', 'Package Added Successfully');
    }

    public function deletePackage($id) {
        DB::table('tbl_package')->where('id', $id)->delete();
        return redirect()->back()->with('success', 'Package Deleted Successfully');
    }

    public function updatePackage(Request $request) {
        $request->validate([
            'id' => 'required',
            'name' => 'required',
            'modules' => 'required|array',
            'feature_list' => 'required|array', // change validation here
        ]);
    
        DB::table('tbl_package')->where('id', $request->id)->update([
            'name' => $request->name,
            'modules' => json_encode($request->modules),
            'feature_list' => json_encode($request->feature_list), // directly encode array
            'updated_at' => now(),
        ]);
    
        return redirect()->back()->with('success', 'Package Updated Successfully');
    }
    
    public function activatePackage($id) {
        DB::table('tbl_package')->where('id', $id)->update(['status' => 1]);
        return redirect()->back()->with('success', 'Package Activated Successfully');
    }
    
    public function deactivatePackage($id) {
        DB::table('tbl_package')->where('id', $id)->update(['status' => 0]);
        return redirect()->back()->with('success', 'Package Deactivated Successfully');
    }

    // Manage Package Duration
    public function durations() {
        $packages = DB::table('tbl_package')->get();
        $durations = DB::table('tbl_package_duration_amount')->get();
        return view('superadmin.manage_package.durations', compact('durations', 'packages'));
    }
    
    // Store duration
    public function storeDuration(Request $request) {
        $request->validate([
            'duration' => 'required',
            'amount' => 'required|numeric',
            'tax' => 'required|numeric',
            'package_id' => 'required|numeric',
        ]);
    
        DB::table('tbl_package_duration_amount')->insert([
            'duration' => $request->duration,
            'amount' => $request->amount,
            'tax' => $request->tax,
            'package_id' => $request->package_id,
            'status' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    
        return redirect()->back()->with('success', 'Duration Added Successfully');
    }
    
    // Update duration
    public function updateDuration(Request $request) {
        $request->validate([
            'id' => 'required',
            'duration' => 'required',
            'amount' => 'required|numeric',
            'tax' => 'required|numeric',
            'package_id' => 'required|numeric',
        ]);
    
        DB::table('tbl_package_duration_amount')->where('id', $request->id)->update([
            'duration' => $request->duration,
            'amount' => $request->amount,
            'tax' => $request->tax,
            'package_id' => $request->package_id,
            'updated_at' => now(),
        ]);
    
        return redirect()->back()->with('success', 'Duration Updated Successfully');
    }
    
    // Delete duration
    public function deleteDuration($id) {
        DB::table('tbl_package_duration_amount')->where('id', $id)->delete();
        return redirect()->back()->with('success', 'Duration Deleted Successfully');
    }
    
    // Activate duration
    public function activateDuration($id) {
        DB::table('tbl_package_duration_amount')->where('id', $id)->update(['status' => 1]);
        return redirect()->back()->with('success', 'Duration Activated Successfully');
    }
    
    // Deactivate duration
    public function deactivateDuration($id) {
        DB::table('tbl_package_duration_amount')->where('id', $id)->update(['status' => 0]);
        return redirect()->back()->with('success', 'Duration Deactivated Successfully');
    }

    // Assign Packages - Direct feature assignment to tenants
    public function assignPackages() {
        $tenants = DB::table('tenants')->get();
        $features = DB::table('tbl_feature')->where('status', 1)->where('is_deleted', 0)->get();
        
        // Get current access list (same as FeatureAccessController)
        $accessList = DB::table('tbl_feat_access as fa')
            ->join('tbl_feature as f', 'fa.module_id', '=', 'f.id')
            ->join('tenants as t', 'fa.tenant_schema', '=', 't.tenant_schema')
            ->select(
                'fa.id',
                DB::raw("CONCAT(t.first_name, ' ', t.last_name) as full_name"),
                't.company_name',
                't.tenant_schema',
                'f.module_name',
                'f.uid',
                'fa.limit',
                'fa.status'
            )
            ->orderByDesc('fa.id')
            ->get();
            
        return view('superadmin.manage_package.assign_packages', compact('tenants', 'features', 'accessList'));
    }

    // Store assigned packages
    public function storeAssignedPackage(Request $request) {
        $request->validate([
            'tenant_id' => 'required|exists:tenants,id',
            'module_ids' => 'required|array',
            'module_ids.*' => 'exists:tbl_feature,id',
            'limit' => 'nullable|integer|min:1',
        ]);

        $tenant = DB::table('tenants')->where('id', $request->tenant_id)->first();
        if (!$tenant || empty($tenant->tenant_schema)) {
            return redirect()->back()->with('error', 'Invalid tenant or missing tenant schema.');
        }

        $limit = $request->limit ?? null;
        $insertedCount = 0;
        $moduleUids = [];

        foreach ($request->module_ids as $moduleId) {
            // Get module details to check for boutique handling
            $module = DB::table('tbl_feature')->where('id', $moduleId)->first();
            if ($module) {
                $moduleUids[] = $module->uid;
            }

            // Check if access already exists
            $exists = DB::table('tbl_feat_access')
                ->where('tenant_schema', $tenant->tenant_schema)
                ->where('module_id', $moduleId)
                ->exists();

            if (!$exists) {
                DB::table('tbl_feat_access')->insert([
                    'tenant_schema' => $tenant->tenant_schema,
                    'module_id' => $moduleId,
                    'limit' => $limit,
                    // Note: status is not set here to match existing FeatureAccessController behavior
                ]);
                $insertedCount++;
            }
        }

        // ✅ Clone boutique tables from master if MOD_BOUTIQUE is part of assignment
        if (in_array('MOD_BOUTIQUE', $moduleUids) && $tenant->business_id == 2) {
            $boutiqueTables = [
                'boutique_items',
                'boutique_design_areas',
                'boutique_design_options',
                'boutique_item_measurements',
                'boutique_pattern',
                'stages',
                'statuses',
            ];

            $tenantSchema = $tenant->tenant_schema;

            // Step 1: Set tenant connection
            config(['database.connections.tenant.database' => $tenantSchema]);
            DB::purge('tenant');
            DB::reconnect('tenant');

            $masterConn = DB::connection('master_db');
            $tenantConn = DB::connection('tenant');

            foreach ($boutiqueTables as $table) {
                // Check if table already exists in tenant DB
                if (!Schema::connection('tenant')->hasTable($table)) {
                    // Get CREATE TABLE SQL from master
                    $createTableSQL = $masterConn->selectOne("SHOW CREATE TABLE `$table`");
                    $rawSQL = $createTableSQL->{'Create Table'};

                    // Remove AUTO_INCREMENT to avoid ID clashes
                    $rawSQL = preg_replace('/AUTO_INCREMENT=\d+ /', '', $rawSQL);

                    // Execute raw SQL on tenant DB
                    $tenantConn->unprepared($rawSQL);

                    // Copy data from master to tenant
                    $data = $masterConn->table($table)->get();
                    foreach ($data as $row) {
                        $tenantConn->table($table)->insert((array) $row);
                    }
                }
            }
        }

        if ($insertedCount > 0) {
            return redirect()->back()->with('success', "Successfully assigned {$insertedCount} features to {$tenant->first_name} {$tenant->last_name}.");
        } else {
            return redirect()->back()->with('info', 'All selected features are already assigned to this tenant.');
        }
    }
}
