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
}
