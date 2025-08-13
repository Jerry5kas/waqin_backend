<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Marketing;
use App\Models\BusinessCategory;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class MarketingController extends Controller
{
    
    public function index()
    {
        $businesses = BusinessCategory::where('status', 1)->where('is_deleted', 0)->get();
        $marketings = Marketing::where('status', 1)->where('is_deleted', 0)->get();
        return view('superadmin.marketing', compact('marketings', 'businesses'));
    }

    public function store(Request $request)
{
    $request->validate([
        'title' => 'required|string|max:255',
        'subtitle' => 'required|string|max:255',
        'description' => 'required|string',
        'image' => 'nullable|image|mimes:jpeg,png,jpg,gif|max:2048',
        'offer_list' => 'nullable|array',
        'summary' => 'nullable|string',
        'location' => 'required|string|max:255',
        'business_id' => 'required|array', // Validate as an array
    ]);

    $marketing = new Marketing();
    $marketing->title = $request->title;
    $marketing->subtitle = $request->subtitle;
    $marketing->description = $request->description;

    // Handle file upload
    if ($request->hasFile('image')) {
        $path = $request->file('image')->store('marketings', 'public');
        $marketing->image = 'storage/' . $path;
    }

    $marketing->offer_list = $request->offer_list ? json_encode($request->offer_list) : null;
    $marketing->summary = $request->summary;
    $marketing->location = $request->location;
    $marketing->business_id = implode(',', $request->business_id);

    $marketing->status = 1;
    $marketing->is_deleted = 0;
    $marketing->save();

    return redirect()->route('marketing')->with('success', 'Marketing item created successfully.');
}

public function edit($id)
{
    $marketing = Marketing::findOrFail($id);
    return response()->json($marketing);
}

public function update(Request $request, $id)
{
    $marketing = Marketing::findOrFail($id);

    $marketing->title = $request->title;
    $marketing->subtitle = $request->subtitle;
    $marketing->description = $request->description;
    $marketing->location = $request->location;
    $marketing->business_id = implode(',', $request->business_id);
    $marketing->offer_list = $request->offer_list ? json_encode($request->offer_list) : null;

    if ($request->hasFile('image')) {
        $path = $request->file('image')->store('marketings', 'public');
        $marketing->image = 'storage/' . $path;
    }

    $marketing->save();

    return redirect()->back()->with('success', 'Marketing item updated successfully.');
}

public function updateImage(Request $request, $id)
{
    $request->validate([
        'image' => 'required|image|mimes:jpeg,png,jpg,gif|max:2048'
    ]);

    $marketing = Marketing::findOrFail($id);

    // Delete old image if it exists
    if (!empty($marketing->image)) {
        $oldImagePath = str_replace('storage/', 'public/', $marketing->image);
        if (Storage::exists($oldImagePath)) {
            Storage::delete($oldImagePath);
        }
    }

    // Store new image
    $path = $request->file('image')->store('marketings', 'public');
    $marketing->image = 'storage/' . $path;
    $marketing->save();

    return redirect()->route('marketing')->with('success', 'Image updated successfully.');
}

}
