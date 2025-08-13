<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class CronJobController extends Controller
{
    public function storeRecommendedLeads()
{
    try {
        \Log::info("Starting storeRecommendedLeads API...");

        // Fetch feature
        $feature = DB::connection('master_db')->table('tbl_feature')
            ->where('uid', 'MOD_LEADS')
            ->select('id')
            ->first();

        if (!$feature) {
            \Log::error("Feature not found!");
            return response()->json(['message' => 'Feature not found'], 404);
        }

        \Log::info("Feature found: ", ['module_id' => $feature->id]);

        // Fetch tenant_schemas with access and their limits
        $tenantAccess = DB::connection('master_db')->table('tbl_feat_access')
            ->where('module_id', $feature->id)
            ->select('tenant_schema', 'limit')
            ->get()
            ->keyBy('tenant_schema');

        if ($tenantAccess->isEmpty()) {
            \Log::warning("No tenants have access!");
            return response()->json(['message' => 'No tenants have access'], 404);
        }

        \Log::info("Tenant Access Data: ", $tenantAccess->toArray());

        // Fetch tenant details
        $tenants = DB::connection('master_db')->table('tenants')
            ->whereIn('tenant_schema', $tenantAccess->keys())
            ->select('id as tenant_id', 'business_id', 'sub_category_id', 'full_address', 'tenant_schema')
            ->get();

        if ($tenants->isEmpty()) {
            \Log::warning("No tenants found in the tenants table!");
            return response()->json(['message' => 'No tenants found'], 404);
        }

        \Log::info("Tenants Found: ", $tenants->toArray());

        // Fetch all data from leads_master table
        $leads = DB::connection('master_db')->table('leads_master')->get();

        if ($leads->isEmpty()) {
            \Log::warning("No leads found in leads_master table!");
            return response()->json(['message' => 'No leads found'], 404);
        }

        \Log::info("Leads Found: ", $leads->toArray());

        // Track assigned leads count for each tenant
        $assignedLeadsCount = [];
        $leadsToSave = [];

        // Process each lead
        foreach ($leads as $lead) {
            // Fetch business and category details
            if (!empty($lead->looking_for)) {
                $salesService = DB::connection('master_db')->table('sales_and_services')
                    ->where(function ($query) use ($lead) {
                        $query->where('service', $lead->looking_for)
                            ->orWhere('product_category', $lead->looking_for);
                    })
                    ->select('business_id', 'sub_category_id')
                    ->first();

                if ($salesService) {
                    $lead->business_id = $salesService->business_id;
                    if (!is_null($salesService->sub_category_id)) {
                        $lead->sub_category_id = $salesService->sub_category_id;
                    }
                }
            }

            // Match lead with tenants
            foreach ($tenants as $tenant) {
                if (
                    isset($lead->business_id) && $lead->business_id == $tenant->business_id &&
                    (!isset($lead->sub_category_id) || (isset($lead->sub_category_id) && $lead->sub_category_id == $tenant->sub_category_id))
                ) {
                    // Check tenant's lead limit
                    $limit = $tenantAccess[$tenant->tenant_schema]->limit ?? 0;
                    $assignedLeadsCount[$tenant->tenant_id] = $assignedLeadsCount[$tenant->tenant_id] ?? 0;

                    if ($assignedLeadsCount[$tenant->tenant_id] < $limit) {
                        $leadsToSave[] = [
                            'lead_id' => $lead->id,
                            'tenant_id' => $tenant->tenant_id,
                        ];
                        $assignedLeadsCount[$tenant->tenant_id]++; // Increment count
                    }
                }
            }
        }

        // Insert data into leads_history only if there are leads to save
        if (!empty($leadsToSave)) {
            DB::connection('master_db')->table('leads_history')->insert($leadsToSave);
            \Log::info("Leads saved to leads_history successfully!");
        } else {
            \Log::info("No leads saved as no matched tenants found.");
        }

        return response()->json(['leads' => $leadsToSave]);

    } catch (\Exception $e) {
        \Log::error("Error in storeRecommendedLeads: " . $e->getMessage(), [
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString()
        ]);

        return response()->json(['error' => $e->getMessage()], 500);
    }
}
           
}
