<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ContactGroup;
use App\Models\BusinessCategory;
use Illuminate\Support\Facades\DB;
use App\Helpers\QueryHelper;

class ContactGroupController extends Controller
{
    public function index()
    {
        $contactGroup = ContactGroup::where('is_deleted', 0)->orderBy('created_at', 'desc')->get();
        $businessCategories = BusinessCategory::all();
        return view('superadmin.contactGroup', compact('contactGroup', 'businessCategories'));
    }

    public function store(Request $request)
   {
    $request->validate([
        'business_id' => 'required|exists:business_categories,id',
        'name' => 'required|string|max:255',
    ]);

    ContactGroup::create([
        'business_id' => $request->business_id,
        'name' => $request->name,
    ]);

    return redirect()->route('contactGroup')->with('success', 'Contact Group added successfully.');
   }

   public function activate($id)
   {
       try {
           $contactGroup = ContactGroup::findOrFail($id);
           $contactGroup->status = 1;
           $contactGroup->save();

           return redirect()->back()->with('success', 'Contact Group activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Contact Group.');
       }
   }

   public function deactivate($id)
   {
       try {
        $contactGroup = ContactGroup::findOrFail($id);
        $contactGroup->status = 0;
        $contactGroup->save();

           return redirect()->back()->with('success', 'Contact Group deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate Contact Group.');
       }
   }

   public function destroy($id)
   {
        try {
            $contactGroup = ContactGroup::findOrFail($id);
            $contactGroup->is_deleted = 1;
            $contactGroup->save();
    
            return redirect()->back()->with('success', 'Contact Group Deleted successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to Deleting Contact Group.');
        }
   }

   public function update(Request $request, $id)
{
    $request->validate([
        'name' => 'required|string|max:255',
    ]);

    try {
        $ContactGroup = ContactGroup::findOrFail($id);
        $ContactGroup->name = $request->input('name');
        $ContactGroup->save();

        return response()->json(['success' => 'Contact Group updated successfully.']);
    } catch (\Exception $e) {
        return response()->json(['error' => 'Failed to update Contact Group.'], 500);
    }
}

public function getGroupsByBusinessId(Request $request)
{
    // Validate the request to ensure 'business_id' and 'tenant_schema' are present
    $request->validate([
        'business_id' => 'required|exists:business_categories,id',
        'tenant_schema' => 'required|string', // Ensure tenant schema is passed
    ]);

    // Retrieve inputs
    $business_id = $request->input('business_id');
    $tenantSchema = $request->input('tenant_schema');

    // Set tenant database dynamically
    QueryHelper::initializeConnection($tenantSchema);

    // Fetch groups from the master database
    $groups = DB::connection('master_db')->table('contact_groups')
    ->select('id', 'business_id', 'name', 'type') // Explicitly use the master connection
        ->where(function ($query) use ($business_id) {
            $query->whereRaw("FIND_IN_SET(?, business_id)", [$business_id])
                ->orWhere('business_id', 'all');
        })
        ->get();
    // Return the final result as a JSON response
    return response()->json($groups);
}


}
