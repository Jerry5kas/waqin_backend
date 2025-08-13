<?php

namespace App\Boutique\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Boutique\Services\BoutiqueSetupService;
use Illuminate\Support\Facades\Auth;
use App\Helpers\QueryHelper;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class BoutiqueSetupController extends Controller
{
    public function setup(BoutiqueSetupService $service)
    {
        $service->createTables();
        return response()->json(['message' => 'Boutique tables created successfully!']);
    }
    public function getItemConfiguration($itemId)
    {
    

        $user = Auth::guard('api')->user();
        if (!$user) {
            return response()->json([
                'message' => 'Unauthorized access.',
                'data' => null,
            ], 401);
        }
        
        $tenantSchema = $user->tenant_schema;

        QueryHelper::initializeConnection($tenantSchema);

        try {
            $item = DB::connection('tenant')->table('boutique_items')
                ->where(['id' => $itemId,'is_deleted' => 0,'status' => 1])
                ->first();

            if (!$item) {
                return response()->json([
                    'message' => 'Item not found.',
                    'data' => null,
                ], 200);
            }

        //Fetch all design areas with their options
            $designAreas = DB::connection('tenant')
                ->table('boutique_design_areas as bda')
                ->where(['bda.item_id' => $itemId, 'bda.is_deleted' => 0, 'bda.status' => 1])
                ->get()
                ->map(function ($area) {
                    $options = DB::connection('tenant')
                        ->table('boutique_design_options')
                        ->where('design_area_id', $area->id)
                        ->get()
                        ->map(function ($option) {
                            return [
                                'id' => $option->id,
                                'name' => $option->name,
                                'image_url' => $option->image_url,
                                'price' => $option->price,
                                'is_default' => $option->is_default,
                            ];
                        });
                    return [
                        'area_id' => $area->id,
                        'area_name' => $area->name,
                        'options' => $options,
                     ];
                });
            $totalDefaultPrice = $designAreas
                ->flatMap(fn($area) => $area['options'])
                ->filter(fn($opt) => $opt['is_default'])
                ->sum('price');
            
                

            $patterns = DB::connection('tenant')
                    ->table('boutique_pattern')
                    ->where(['item_id' => $itemId, 'is_deleted' => 0, 'status' => 1])
                    ->get()
                    ->map(function ($pattern) {
                        return [
                            'id' => $pattern->id,
                            'name' => $pattern->name,
                            'image_url' => $pattern->image,
                            'price' => $pattern->price,
                            'is_default' => $pattern->is_default,
                            'stagePrices' => $pattern->stagePrices,
                        ];
                    });
    
            $measurements = DB::connection('tenant')->table('boutique_item_measurements')
                ->where(['item_id'=> $itemId, 'is_deleted' => 0, 'status' => 1])
                ->get();

            return response()->json([
                'message' => 'Boutique form data fetched successfully.',
                'data' => [
                    'item_id' => $item->id,
                    'item_name' => $item->item_name,
                    'design_areas' => $designAreas,
                    'total_default_price' => $totalDefaultPrice,
                    'pattern' => $patterns,
                    'measurements' => $measurements,
                ],
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to fetch form data.',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

public function getAllItems(Request $request)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json([
            'message' => 'Unauthorized access.',
            'data' => null,
        ], 401);
    }

    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);

    try {
        $items = DB::table('boutique_items')
            ->select('id', 'item_name', 'status', 'created_at')
            ->where('is_deleted', 0)
            ->where('status', 1)
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'message' => 'Items fetched successfully.',
            'data' => $items
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to fetch items.',
            'error' => $e->getMessage()
        ], 500);
    }
}

    public function getDesignAreasByItemId($itemId)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json([
            'message' => 'Unauthorized access.',
            'data' => null,
        ], 401);
    }

    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);

    try {
        // Fetch Design Areas and nested Design Options
        $designAreas = DB::connection('tenant')
            ->table('boutique_design_areas as bda')
            ->where(['bda.item_id' => $itemId, 'bda.is_deleted' => 0, 'bda.status' => 1])
            ->get()
            ->map(function ($area) {
                $options = DB::connection('tenant')
                    ->table('boutique_design_options')
                    ->where('design_area_id', $area->id)
                    ->where(['is_deleted' => 0, 'status' => 1])
                    ->get()
                    ->map(function ($option) {
                        return [
                            'id' => $option->id,
                            'name' => $option->name,
                            'image_url' => $option->image_url,
                            'stagePrices' => $option->stagePrices ? json_decode($option->stagePrices, true) : [],
                            'price' => $option->price,
                            'is_default' => $option->is_default,
                        ];
                    });

                return [
                    'area_id' => $area->id,
                    'area_name' => $area->name,
                    'options' => $options,
                ];
            });

        return response()->json([
            'message' => 'Design areas fetched successfully.',
            'data' => $designAreas,
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to fetch design areas.',
            'error' => $e->getMessage(),
        ], 500);
    }
}

public function updateDesignAreasByItemId(Request $request, $itemId)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $tenantSchema = $user->tenant_schema;
    QueryHelper::initializeConnection($tenantSchema);

    $validated = $request->validate([
        'design_areas' => 'required|array',
        'design_areas.*.area_id' => 'nullable|integer',
        'design_areas.*.options' => 'required|array',
        'design_areas.*.options.*.id' => 'nullable|integer',
        'design_areas.*.options.*.price' => 'nullable|numeric',
        'design_areas.*.options.*.is_default' => 'nullable|boolean',
        'design_areas.*.options.*.stagePrices' => 'nullable|array',
    ]);

    try {
        $conn = DB::connection('tenant');

        foreach ($validated['design_areas'] as $areaData) {
            $areaId = $areaData['area_id'] ?? null;
            foreach ($areaData['options'] as $index => $opt) {
                $optionData = [
                    'design_area_id' => $areaId,
                    'price' => $opt['price'] ?? 0,
                    'is_default' => $opt['is_default'] ?? 0,
                    'stagePrices' => isset($opt['stagePrices']) ? json_encode($opt['stagePrices']) : null,
                ];

                if (!empty($opt['id'])) {
                    // Update existing
                    $conn->table('boutique_design_options')
                        ->where('id', $opt['id'])
                        ->update($optionData);
                } else {
                   return response()->json([
                        'message' => 'Design Option Id Not Found.'
                    ]);
                }
            }
        }

        return response()->json([
            'message' => 'Design areas and options updated successfully.'
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'message' => 'Failed to update design data.',
            'error' => $e->getMessage(),
        ], 500);
    }
}


public function getAllPatterns($itemID)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $tenantSchema = $user->tenant_schema;

    try {
        QueryHelper::initializeConnection($tenantSchema);

        $patterns = DB::connection('tenant')
            ->table('boutique_pattern')
            ->where('is_deleted', 0)
            ->where('status', 1)
            ->where('item_id', $itemID)
            ->orderBy('id', 'desc')
            ->get([
                'id',
                'name as pattern_name',
                'image',
                'price',
                'created_at',
                'item_id',
                'stagePrices'
            ]);
       
        // Get base URL from .env
        $baseUrl = config('app.url'); // uses APP_URL

        // Append full image URL
        $patterns->transform(function ($pattern) use ($baseUrl) {
            if ($pattern->image) {
                $pattern->image = "{$baseUrl}/storage/{$pattern->image}";
            }
            return $pattern;
        });

        return response()->json([
            'success' => true,
            'patterns' => $patterns
        ], 200);

    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Failed to fetch patterns.',
            'error' => $e->getMessage()
        ], 500);
    }
}


public function addPattern(Request $request)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $request->validate([
        'item_id' => 'required|integer',
        'name' => 'required|string|max:50',
        'price' => 'required|numeric',
        'stagePrices' => 'nullable|string', // JSON string
        'image' => 'nullable|string' // base64 image string
    ]);
        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
    try {
        $imagePath = null;

        if ($request->image) {
            $base64Image = $request->image;

            if (preg_match('/^data:image\/(\w+);base64,/', $base64Image, $matches)) {
                $extension = $matches[1];
                $base64Image = substr($base64Image, strpos($base64Image, ',') + 1);
                $base64Image = str_replace(' ', '+', $base64Image);
                $imageData = base64_decode($base64Image);

                if ($imageData === false) {
                    return response()->json(['message' => 'Invalid base64 image data'], 400);
                }

                $tenantSchema = $user->tenant_schema; // e.g., non_prod_tenant_19
                $imageName = Str::random(10) . '.' . $extension;
                $relativePath = "patterns/{$tenantSchema}/patterns/{$imageName}";
                $storagePath = "public/{$relativePath}";

                // Store the image
                Storage::put($storagePath, $imageData);

                // Save just the relative path in DB
                $imagePath = $relativePath;
            } else {
                return response()->json(['message' => 'Invalid image format'], 400);
            }
        }
        DB::table('boutique_pattern')->insert([
            'item_id'      => $request->item_id,
            'name'         => $request->name,
            'price'        => $request->price,
            'image'        => $imagePath,
            'stagePrices'  => $request->stagePrices,
        ]);

       
        return response()->json(['message' => 'Pattern added successfully'], 200);
    } catch (\Exception $e) {
         dd($e->getMessage());
        \Log::error('Failed to add pattern: ' . $e->getMessage());
        return response()->json(['message' => 'Failed to add pattern'], 500);
    }
}

public function updatePattern(Request $request, $id)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $tenantSchema = $user->tenant_schema;

    $validated = $request->validate([
        'name'         => 'nullable|string',
        'price'        => 'nullable|numeric',
        'image'        => 'nullable|string', // base64 image string
        'stagePrices'  => 'nullable|string',
    ]);

    try {
        QueryHelper::initializeConnection($tenantSchema);
        $connection = DB::connection('tenant');

        $pattern = $connection->table('boutique_pattern')->where('id', $id)->first();
        if (!$pattern) {
            return response()->json(['message' => 'Pattern not found'], 404);
        }

        $imagePath = $pattern->image; // Keep existing

        // If a new base64 image is provided, replace it
        if (!empty($request->image)) {
            if (preg_match('/^data:image\/(\w+);base64,/', $request->image, $matches)) {
                $extension = $matches[1];
                $base64Data = substr($request->image, strpos($request->image, ',') + 1);
                $base64Data = str_replace(' ', '+', $base64Data);
                $decodedImage = base64_decode($base64Data);

                if ($decodedImage === false) {
                    return response()->json(['message' => 'Invalid base64 image data'], 400);
                }

                // Delete old image if exists
                if ($pattern->image) {
                    Storage::disk('public')->delete($pattern->image);
                }

                $fileName = uniqid() . '.' . $extension;
                $relativePath = "patterns/{$tenantSchema}/patterns/{$fileName}";
                Storage::put("public/{$relativePath}", $decodedImage);
                $imagePath = $relativePath;
            } else {
                return response()->json(['message' => 'Invalid image format'], 400);
            }
        }

        // Update the pattern
        $connection->table('boutique_pattern')->where('id', $id)->update([
            'name'         => $validated['name'] ?? $pattern->name,
            'price'        => $validated['price'] ?? $pattern->price,
            'image'        => $imagePath,
            'stagePrices'  => $validated['stagePrices'] ?? $pattern->stagePrices,
            'updated_at'   => now(),
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Pattern updated successfully.',
            'pattern' => [
                'id'         => $id,
                'name'       => $validated['name'] ?? $pattern->name,
                'price'      => $validated['price'] ?? $pattern->price,
                'image'      => $imagePath ? asset("storage/{$imagePath}") : null,
                'stagePrices'=> $validated['stagePrices'] ?? $pattern->stagePrices,
                'updated_at' => now()->toDateTimeString(),
            ],
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Failed to update pattern.',
            'error'   => $e->getMessage(),
        ], 500);
    }
}


public function deletePattern(Request $request, $id)
{
    $user = Auth::guard('api')->user();
    if (!$user) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    $tenantSchema = $user->tenant_schema;

    try {
        // Connect to tenant DB
        QueryHelper::initializeConnection($tenantSchema);
        $connection = DB::connection('tenant');

        $pattern = $connection->table('boutique_pattern')->where('id', $id)->first();
        // Delete image file from storage if it exists
        if (!empty($pattern->image)) {
            $imagePath = str_replace(url('/storage'), 'public', $pattern->image); // Convert URL to storage path
            if (Storage::exists($imagePath)) {
                Storage::delete($imagePath);
            }
        }

        // Hard delete the pattern record
        $connection->table('boutique_pattern')->where('id', $id)->delete();

        return response()->json([
            'success' => true,
            'message' => 'Pattern and image deleted successfully.'
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Failed to delete pattern.',
            'error' => $e->getMessage()
        ], 500);
    }
}

}




