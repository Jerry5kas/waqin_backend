<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use App\Models\BusinessSubCategory;
use App\Models\BusinessCategory;

class BusinessSubCategoryController extends Controller
{
    public function index()
    {
        $subCategories = BusinessSubCategory::orderBy('created_at', 'desc')->where('is_deleted', 0)->get();
        $businessCategories = BusinessCategory::all();
        return view('superadmin.businessSubCategories', compact('subCategories', 'businessCategories'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'business_id' => 'required|exists:business_categories,id',
            'sub_category_name' => 'required|string|max:255',
        ]);
    
        BusinessSubCategory::create([
            'business_id' => $request->business_id,
            'sub_category_name' => $request->sub_category_name,
        ]);
    
        return redirect()->back()->with('success', 'Sub Category added successfully.');
    }

    public function activate($id)
   {
       try {
           $subCategories = BusinessSubCategory::findOrFail($id);
           $subCategories->status = 1;
           $subCategories->save();

           return redirect()->back()->with('success', 'Sub Category activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Sub Category.');
       }
   }

   public function deactivate($id)
   {
       try {
        $subCategories = BusinessSubCategory::findOrFail($id);
        $subCategories->status = 0;
        $subCategories->save();

           return redirect()->back()->with('success', 'Sub Category deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate Sub Category.');
       }
   }

   public function destroy($id)
   {
        try {
            $subCategories = BusinessSubCategory::findOrFail($id);
            $subCategories->status = 0;
            $subCategories->is_deleted = 1;
            $subCategories->save();
    
            return redirect()->back()->with('success', 'Sub Category Deleted successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to Deleting Status.');
        }
   }

   public function update(Request $request, $id)
   {
       $request->validate([
           'sub_category_name' => 'required|string|max:255',
       ]);
   
       try {
           $subCategories = BusinessSubCategory::findOrFail($id);

           $business_id = $subCategories->business_id;

           $subCategories->sub_category_name = $request->input('sub_category_name');
           $subCategories->save();
   
           return response()->json(['success' => 'Sub Category updated successfully.']);
       } catch (\Exception $e) {
           return response()->json(['error' => 'Failed to update Sub Category.'], 500);
       }
   }

}
