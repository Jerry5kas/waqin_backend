<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class FeatureAccessController extends Controller
{
 
    public function index()
{
    $tenants = DB::table('tenants')->get();
    $modules = DB::table('tbl_feature')->select('id', 'module_name')->get();

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
            'fa.limit'
        )
        ->orderByDesc('fa.id')
        ->get();

    return view('superadmin.feature-access', compact('tenants', 'modules', 'accessList'));
}

    public function store(Request $request)
{
    $validated = $request->validate([
        'tenant_id'    => 'required|exists:tenants,id',
        'package_name' => 'required|string|exists:tbl_package,name',
        'limit'        => 'nullable|integer|min:1',
    ]);

    $tenant = DB::table('tenants')->where('id', $validated['tenant_id'])->first();
    if (!$tenant || empty($tenant->tenant_schema)) {
        return redirect()->back()->with('error', 'Invalid tenant.');
    }
    
       
    $limit = $validated['limit'] ?? null;

    // Load module UIDs from package
    $package = DB::table('tbl_package')->where('name', $validated['package_name'])->first();
    $moduleUids = json_decode($package->modules, true);

    if (empty($moduleUids)) {
        return redirect()->back()->with('error', 'Package has no modules defined.');
    }

    // Get actual module IDs from UIDs
    $moduleIds = DB::table('tbl_feature')
        ->whereIn('uid', $moduleUids)
        ->pluck('id')
        ->toArray();

    foreach ($moduleIds as $modId) {
        // Avoid duplicate access entry
        $exists = DB::table('tbl_feat_access')
            ->where('tenant_schema', $tenant->tenant_schema)
            ->where('module_id', $modId)
            ->exists();

        if (!$exists) {
            DB::table('tbl_feat_access')->insert([
                'tenant_schema' => $tenant->tenant_schema,
                'module_id'     => $modId,
                'limit'         => $limit,
            ]);
        }
    }
    // ✅ Clone boutique tables from master if MOD_BOUTIQUE is part of package
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

    return redirect()->back()->with('success', 'Feature access granted via package successfully.');
}

}
