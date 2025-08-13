<?php

namespace App\Http\Controllers;
use App\Models\BusinessCategory;
use Illuminate\Http\Request;

class BusinessCategoryController extends Controller
{
   // Display a listing of the resource.
   public function index()
   {
       $businessCategories = BusinessCategory::orderBy('created_at', 'desc')->get();
       return view('superadmin.business-category', compact('businessCategories'));
   }

  
   // Store a newly created resource in storage.
   public function store(Request $request)
   {
    try{
        $request->validate([
            'name' => 'required|string|max:255',
        ]);
 
        $BusinessCategory = BusinessCategory::create($request->all());
 
        return redirect()->back()->with('success', 'Business Added successfully.');
       }catch (\Exception $e) {
        return response()->json(['error' => 'Failed to add business.'], 500);
         }
       
   }

   // Display the specified resource.
   public function show($id)
   {
    try{
        $BusinessCategory = BusinessCategory::findOrFail($id);
        return response()->json($BusinessCategory);
    }catch (\Exception $e) {
        return response()->json(['error' => 'Something went wrong. please try again later'], 500);
         }
       
   }

   // Show the form for editing the specified resource.
   public function edit($id)
   {
       $BusinessCategory = BusinessCategory::findOrFail($id);
       return view('businessCategories.edit', compact('BusinessCategory'));
   }

   // Update the specified resource in storage.
   public function update(Request $request, $id)
    {
    $request->validate([
        'name' => 'required|string|max:255',
    ]);

    try {
        $businessCategory = BusinessCategory::findOrFail($id);
        $businessCategory->name = $request->input('name');
        $businessCategory->save();

        return response()->json(['success' => 'Business category updated successfully.']);
         } catch (\Exception $e) {
        return response()->json(['error' => 'Failed to update business category.'], 500);
         }
    }
   public function activate($id)
   {
       try {
           $businessCategory = BusinessCategory::findOrFail($id);
           $businessCategory->status = 1;
           $businessCategory->save();

           return redirect()->back()->with('success', 'Business category activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate business category.');
       }
   }

   // Deactivate the business category
   public function deactivate($id)
   {
       try {
           $businessCategory = BusinessCategory::findOrFail($id);
           $businessCategory->status = 0;
           $businessCategory->save();

           return redirect()->back()->with('success', 'Business category deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate business category.');
       }
   }

   // Remove the specified resource from storage.
   public function destroy($id)
   {
    try {
        $businessCategory = BusinessCategory::findOrFail($id);
        $businessCategory->delete();

        return redirect()->back()->with('success', 'Business category Deleted successfully.');
    } catch (\Exception $e) {
        return redirect()->back()->with('error', 'Failed to Deleting business category.');
    }
   }

   public function getBusinesses(Request $request)
    {
        try {

            $businesses = BusinessCategory::select('id', 'name')->where('status', 1)->where('is_deleted', 0)->get();
    
            return response()->json([
                'businesses' => $businesses
            ], 200);
        }catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong'
            ], 500);
        }
    }
}

