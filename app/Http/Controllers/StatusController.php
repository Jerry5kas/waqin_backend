<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Models\Status;
use App\Models\BusinessCategory;


class StatusController extends Controller
{
    public function index()
    {
        $statuses = Status::orderBy('created_at', 'desc')->get();
        $businessCategories = BusinessCategory::all();
        return view('superadmin.status', compact('statuses', 'businessCategories'));
    }

    public function store(Request $request)
{
    $request->validate([
        'business_id' => 'required',
        'name' => 'required|string|max:255',
    ]);

    $businessIds = $request->input('business_id');

    // Check if "Select All" option is selected
    if (in_array('all', $businessIds)) {
        // If "Select All" is selected, get all business IDs
        $businessIds = BusinessCategory::pluck('id')->toArray();
    }

    // Convert the array of business IDs to a comma-separated string
    $businessIdString = implode(',', $businessIds);

    Status::create([
        'business_id' => $businessIdString,
        'name' => $request->name,
    ]);

    return redirect()->route('status')->with('success', 'Status added successfully.');
}

   public function activate($id)
   {
       try {
           $statuses = Status::findOrFail($id);
           $statuses->status = 1;
           $statuses->save();

           return redirect()->back()->with('success', 'Status activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Status.');
       }
   }

   public function deactivate($id)
   {
       try {
        $statuses = Status::findOrFail($id);
        $statuses->status = 0;
        $statuses->save();

           return redirect()->back()->with('success', 'Status deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate Status.');
       }
   }

   public function destroy($id)
   {
        try {
            $statuses = Status::findOrFail($id);
            $statuses->delete();
    
            return redirect()->back()->with('success', 'Status Deleted successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to Deleting Status.');
        }
   }

   public function update(Request $request, $id)
   {
       $request->validate([
           'name' => 'required|string|max:255',
       ]);
   
       try {
           $status = Status::findOrFail($id);
           $status->name = $request->input('name');
           $status->save();
   
           return response()->json(['success' => 'Status updated successfully.']);
       } catch (\Exception $e) {
           return response()->json(['error' => 'Failed to update Status.'], 500);
       }
   }
   public function getStatusByBusinessId(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'business_id' => 'required',
        ]);


        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first()
            ], 201);
        }

        $business_id = $request->input('business_id');
       
        if (is_array($business_id)) {

           // $business_id = array_column($business_id, 'id');
            $statuses = DB::table('status')
                          ->whereIn('business_id', $business_id)
                          ->where('status', 1)->select('id', 'business_id', 'name')
                          ->get();
                         
        }else{
            $statuses = DB::table('status')
            ->where('business_id', $business_id)
            ->where('status', 1)->select('id', 'business_id', 'name') 
            ->get();
        }
        try {
            if ($statuses->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No active statuses found for the selected business.'
                ], 404);
            }

            return response()->json([
                'success' => true,
                'data' => $statuses
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'An error occurred: ' . $e->getMessage()
            ], 500);
        }
    }

}