<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Service;
use App\Models\BusinessCategory;
use App\Models\BusinessSubCategory;
// use Illuminate\Support\Facades\Redis;

class ServiceController extends Controller
{
    public function index()
    {
        $services = Service::orderBy('created_at', 'desc')->get();
        $businessCategories = BusinessCategory::all();
        $subcategories = BusinessSubCategory::all();
        return view('superadmin.services', compact('services', 'businessCategories', 'subcategories'));

    }

    public function getServicesByBusiness($businessId)
    {
        $services = Service::where('business_id', $businessId)
        ->where('status', 1)
        ->where('is_deleted', 0)
        ->get();
        return response()->json($services);
    }

    public function getSubcategoriesByBusiness($businessId)
    {
        $subcategories = BusinessSubCategory::where('business_id', $businessId)->get();
        return response()->json($subcategories);
    }

    public function create()
    {
        return view('services.create');
    }

    public function store(Request $request)
{
    $data = $request->all();
    $res = array();

    $cacheKey = "service_or_product_category_{$data['type']}_{$data['business_id']}";

    if ($data['type'] == 'both' && count($data['service_name']) === count($data['product_category'])) {
        foreach ($data['service_name'] as $key => $value) {
            $res[] = [
                'service' => $value,
                'business_id' => $data['business_id'],
                'sub_category_id' => $data['sub_category_id'] ?? null,
                'product_category' => $data['product_category'][$key],
                'type' => $data['type'],
            ];
        }
    }

    if ($data['type'] == 'sales') {
        foreach ($data['product_category'] as $key => $value) {
            $res[] = [
                'service' => null,
                'business_id' => $data['business_id'],
                'sub_category_id' => $data['sub_category_id'] ?? null,
                'product_category' => $value,
                'type' => $data['type'],
            ];
        }
    }

    if ($data['type'] == 'service') {
        foreach ($data['service_name'] as $key => $value) {
            $res[] = [
                'service' => $value,
                'business_id' => $data['business_id'],
                'sub_category_id' => $data['sub_category_id'] ?? null,
                'product_category' => null,
                'type' => $data['type'],
            ];
        }
    }

    if (!empty($res)) {
        Service::insert($res);
    }

    // Redis::del($cacheKey);

    return redirect()->back()->with('success', 'Sales and Service added successfully');
}

    public function show($id)
    {
        $service = Service::findOrFail($id);
        return view('services.show', compact('service'));
    }

    public function edit($id)
    {
        $service = Service::findOrFail($id);
        return view('services.edit', compact('service'));
    }

    public function update(Request $request, $id)
    {
        $request->validate([
            'service_name' => 'required|string|max:255',
        ]);
    
        $service = Service::find($id);
        if (!$service) {
            return response()->json(['error' => 'Service not found'], 404);
        }
    
        $service->service_name = $request->service_name;
        $service->save();
    
        return response()->json(['success' => 'Service updated successfully']);
    }

    public function destroy($id)
{
    try {
        $service = Service::findOrFail($id);
        
        // Get the business_id and type from the service data (assuming these are present)
        $businessId = $service->business_id;
        $type = $service->type;
        
        $service->delete();
        
        $cacheKey = "service_or_product_category_{$type}_{$businessId}";
        
        // Redis::del($cacheKey);
        
        return redirect()->back()->with('success', 'Service Deleted successfully.');
    } catch (\Exception $e) {
        return redirect()->back()->with('error', 'Failed to Delete Service: ' . $e->getMessage());
    }
}

   public function deactivate($id)
   {
       try {
           // Fetch the service by ID
           $service = Service::findOrFail($id);
           
           // Get the business_id and type from the service data
           $businessId = $service->business_id;
           $type = $service->type;
           
           // Deactivate the service by setting its status to 0
           $service->status = 0;
           $service->save();
   
           // Construct the cache key for the service/product category data
           $cacheKey = "service_or_product_category_{$type}_{$businessId}";
           
           // Delete the Redis cache for this business and type
        //    Redis::del($cacheKey);
   
           return redirect()->back()->with('success', 'Service deactivated successfully.');
       } catch (\Exception $e) {
           // Return error if an exception occurs
           return redirect()->back()->with('error', 'Failed to deactivate Service: ' . $e->getMessage());
       }
   }

    public function activate($id)
    {
        try {
            $service = Service::findOrFail($id);

            $businessId = $service->business_id;
            $type = $service->type;
            $service->status = 1;
            $service->save();
            // Construct the cache key for the service/product category data
            $cacheKey = "service_or_product_category_{$type}_{$businessId}";
                    
            // Delete the Redis cache for this business and type
            // Redis::del($cacheKey);
           return redirect()->back()->with('success', 'Service Activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to Activate Service.');
       }
    }

    public function getServicesBasedOnBusiness(Request $request)
    {
        try {
            $business_id = $request->input('business_id');

            if (!$business_id) {
                return response()->json([
                    'success' => false,
                    'message' => 'Business ID is required.',
                ], 400);
            }

            $services = Service::where('business_id', $business_id)
                    ->where('status', 1)
                    ->select('id', 'business_id', 'type', 'service', 'product_category')
                    ->get();

            if ($services->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No services found for the given business ID.',
                ], 404);
            }

            return response()->json([
                'success' => true,
                'services_product' => $services,
            ], 200);
        } catch (\Exception $e) {
            Log::error('Error fetching services: ' . $e->getMessage());

            return response()->json([
                'success' => false,
                'message' => 'Something went wrong. Please try again later.',
            ], 500);
        }
    }
}