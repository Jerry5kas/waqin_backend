<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\SyncRequest;
use Illuminate\Support\Facades\DB;
use App\Models\Tenant;

class SyncController extends Controller
{
    public function index()
{
    $tenants = DB::table('tenants')->where('is_deleted', 0)->get();

    $syncRequests = SyncRequest::join('tenants', 'sync_requests.tenant_id', '=', 'tenants.id')
        ->select(
            'sync_requests.*',
            DB::raw("CONCAT(tenants.first_name, ' ', tenants.last_name) as full_name"),
            'tenants.mobile',
            'tenants.tenant_schema'
        )
        ->orderByDesc('sync_requests.id')
        ->get();

    return view('superadmin.sync', compact('tenants', 'syncRequests'));
}

    public function store(Request $request)
    {
        $request->validate([
            'tenant_id' => 'required|exists:tenants,id',
        ]);

        $tenant = DB::table('tenants')->where('id', $request->tenant_id)->first();

        SyncRequest::create([
            'tenant_id' => $tenant->id,
            'tenant_schema' => $tenant->tenant_schema, // optional if you still want to keep it
            'contact' => $request->has('contact') ? 1 : 0,
            'call_history' => $request->has('call_history') ? 1 : 0,
            'status' => 1,
        ]);

        return redirect()->back()->with('success', 'Sync request created successfully.');
    }

    public function toggleContact($id)
    {
        $sync = SyncRequest::findOrFail($id);
        $sync->contact = !$sync->contact;
        $sync->save();
    
        return redirect()->back()->with('success', 'Contact sync update successfully.');
    }
    
    public function toggleCallHistory($id)
    {
        $sync = SyncRequest::findOrFail($id);
        $sync->call_history = !$sync->call_history;
        $sync->save();
    
        return redirect()->back()->with('success', 'Call history sync update successfully.');
    }
    
    public function toggleStatus($id)
    {
        $sync = SyncRequest::findOrFail($id);
        $sync->status = !$sync->status;
        $sync->save();
    
        return redirect()->back()->with('success', 'Status update successfully.');
    }

    public function search(Request $request)
{
    $query = $request->input('q');

    try {
        $tenants = Tenant::whereRaw("CONCAT(first_name, ' ', last_name) LIKE ?", ["%{$query}%"])
            ->orWhere('mobile', 'LIKE', "%{$query}%")
            ->limit(20)
            ->get();

        $results = $tenants->map(function ($tenant) {
            return [
                'id' => $tenant->id,
                'text' => $tenant->first_name . ' ' . $tenant->last_name . ' (' . $tenant->mobile . ')'
            ];
        });

        return response()->json(['results' => $results]);
    } catch (\Exception $e) {
        \Log::error('Error in tenant search: ' . $e->getMessage());
        return response()->json(['error' => 'An error occurred while processing your request.'], 500);
    }
}

}
