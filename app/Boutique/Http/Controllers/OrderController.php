<?php

namespace App\Boutique\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Boutique\Services\BoutiqueSetupService;
use App\Boutique\Models\Order;
use App\Boutique\Models\OrderItem;
use Illuminate\Support\Facades\Auth;
use App\Helpers\QueryHelper;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\File;
use App\Jobs\SendPushNotification;
use Illuminate\Support\Facades\Validator;
use Illuminate\Http\JsonResponse;

class OrderController extends Controller
{
    protected $setupService;

    public function __construct(BoutiqueSetupService $setupService)
    {
        $this->setupService = $setupService;
    }
    public function index(Request $request)
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

        if (!Schema::hasTable('orders')) {
            return response()->json([
                'message' => 'Orders not found.',
                'data' => null,
            ], 200);
        }

        $limit = (int) $request->input('limit', 10);
        $offset = (int) $request->input('offset', 0);
        $filters = $request->input('filters', []);

        // Subquery to get the latest employee_order
        $latestEmpOrders = DB::table('employees_orders as eo1')
            ->select('eo1.order_id', 'eo1.status', 'eo1.emp_id')
            ->join(
                DB::raw('(SELECT order_id, MAX(id) as max_id FROM employees_orders GROUP BY order_id) as eo2'),
                function ($join) {
                    $join->on('eo1.order_id', '=', 'eo2.order_id')
                        ->on('eo1.id', '=', 'eo2.max_id');
                }
            );

        $query = Order::query()
            ->with([
                'items:id,order_id,quantity',
                'customer:id,name,mobile',
            ])
            ->leftJoinSub($latestEmpOrders, 'latest_eo', function ($join) {
                $join->on('orders.id', '=', 'latest_eo.order_id');
            })
            ->leftJoin('employees', 'employees.id', '=', 'latest_eo.emp_id')
            ->select(
                'orders.*',
                'customers.name as customer_name',
                'customers.mobile as customer_number',
                'latest_eo.status as employee_order_status',
                'latest_eo.emp_id as assigned_emp_id',
                'employees.full_name as assigned_emp_name',
                'employees.mobile as assigned_emp_mobile',
                DB::raw("CASE
                            WHEN EXISTS (
                                SELECT 1 FROM order_items
                                WHERE order_items.order_id = orders.id
                                AND order_items.pattern IS NOT NULL
                            ) THEN 1
                            ELSE 0
                        END as IsPatternAvailable")
            )
            ->leftJoin('customers', 'orders.customer_id', '=', 'customers.id');

        // Apply filters
        if (!empty($filters['status'])) {
            $query->where('orders.status', $filters['status']);
        }

        if (!empty($filters['customer'])) {
            $query->where('customers.name', 'like', '%' . $filters['customer'] . '%');
        }

        if (!empty($filters['employee'])) {
            $query->where('employees.full_name', 'like', '%' . $filters['employee'] . '%');
        }

        if (!empty($filters['dateRange']['start'])) {
            $query->whereDate('orders.created_at', '>=', $filters['dateRange']['start']);
        }

        if (!empty($filters['dateRange']['end'])) {
            $query->whereDate('orders.created_at', '<=', $filters['dateRange']['end']);
        }

        // Clone for count
        $total = (clone $query)->count();

        $orders = $query
            ->orderByDesc('orders.created_at')
            ->offset($offset)
            ->limit($limit)
            ->get();

        return response()->json([
            'status' => 'success',
            'message' => 'Orders loaded',
            'orders' => $orders,
            'pagination' => [
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset,
            ],
            'stats' => [
                'total' => Order::count(),
                'processing' => Order::where('status', 'In Processing')->count(),
                'delivered' => Order::where('status', 'Delivered')->count(),
                'total_earned' => Order::where('status', 'Delivered')->sum('final_total'),
            ],
        ]);
    }
    // public function index(Request $request)
    // {
    //     $user = Auth::guard('api')->user();

    //     if (!$user) {
    //         return response()->json([
    //             'message' => 'Unauthorized access.',
    //             'data' => null,
    //         ], 401);
    //     }

    //     $tenantSchema = $user->tenant_schema;
    //     QueryHelper::initializeConnection($tenantSchema);
    //     if (!Schema::hasTable('orders')) {
    //         return response()->json([
    //             'message' => 'Orders not found.',
    //             'data' => null,
    //         ], 200);
    //     }

    //     $limit = (int) $request->input('limit', 10);
    //     $offset = (int) $request->input('offset', 0);
    //     $filters = $request->input('filters', []);
    //     $latestEmpOrders = \DB::table('employees_orders as eo1')
    //             ->select('eo1.order_id', 'eo1.status', 'eo1.emp_id')
    //             ->join(
    //                 \DB::raw('(SELECT order_id, MAX(id) as max_id FROM employees_orders GROUP BY order_id) as eo2'),
    //                 function ($join) {
    //                     $join->on('eo1.order_id', '=', 'eo2.order_id')
    //                         ->on('eo1.id', '=', 'eo2.max_id');
    //                 }
    //             );

    //     $query = \DB::table('orders')
    //         ->leftJoin('customers', 'orders.customer_id', '=', 'customers.id')
    //         ->leftJoinSub($latestEmpOrders, 'latest_eo', function ($join) {
    //             $join->on('orders.id', '=', 'latest_eo.order_id');
    //         })
    //         ->leftJoin('employees', 'employees.id', '=', 'latest_eo.emp_id')
    //         ->select(
    //             'orders.id',
    //             'orders.order_no',
    //             'orders.quantity',
    //             'orders.order_type',
    //             'orders.customer_id',
    //             'customers.name as customer_name',
    //             'customers.mobile as customer_number',
    //             'orders.delivery_time',
    //             'orders.final_total',
    //             'orders.created_at',
    //             'orders.status',
    //             'orders.stage',
    //             'latest_eo.status as employee_order_status',
    //             'latest_eo.emp_id as assigned_emp_id',
    //             'employees.full_name as assigned_emp_name',
    //             'employees.mobile as assigned_emp_mobile',
    //             \DB::raw("CASE
    //                         WHEN EXISTS (
    //                             SELECT 1 FROM order_items
    //                             WHERE order_items.order_id = orders.id
    //                             AND order_items.pattern IS NOT NULL
    //                         ) THEN 1
    //                         ELSE 0
    //                     END as IsPatternAvailable")
    //         );
    //     if (isset($filters['status']) && $filters['status'] !== '') {
    //         $query->where('orders.status', $filters['status']);
    //     }

    //     if (isset($filters['customer']) && $filters['customer'] !== '') {
    //         $query->where('customers.name', 'like', '%' . $filters['customer'] . '%');
    //     }

    //     if (isset($filters['employee']) && $filters['employee'] !== '') {
    //         $query->where('employees.full_name', 'like', '%' . $filters['employee'] . '%');
    //     }

    //     if (isset($filters['dateRange']['start']) && $filters['dateRange']['start'] !== '') {
    //         $query->whereDate('orders.created_at', '>=', $filters['dateRange']['start']);
    //     }

    //     if (isset($filters['dateRange']['end']) && $filters['dateRange']['end'] !== '') {
    //         $query->whereDate('orders.created_at', '<=', $filters['dateRange']['end']);
    //     }

    //     // Clone query for stats
    //     $countQuery = clone $query;

    //     $total = $countQuery->count();

    //     // Fetch paginated data
    //     $orders = $query
    //         ->orderByDesc('orders.created_at')
    //         ->offset($offset)
    //         ->limit($limit)
    //         ->get();

    //     return response()->json([
    //         'status' => 'success',
    //         'message' => 'Orders loaded',
    //         'orders' => $orders,
    //         'pagination' => [
    //             'total' => $total,
    //             'limit' => $limit,
    //             'offset' => $offset,
    //         ],
    //         'stats' => [
    //             'total' => Order::count(),
    //             'processing' =>Order::where('status', 'In Processing')->count(),
    //             'delivered' =>Order::where('status', 'Delivered')->count(),
    //             'total_earned' => Order::where('status', 'Delivered')->sum('final_total'),
    //         ],
    //     ]);
    // }

    public function store(Request $request)
    {
        $user = Auth::guard('api')->user();
        if (!$user) {
            return response()->json([
                'message' => 'Unauthorized access.',
                'data' => null,
            ], 401);
        }
        $tenantSchema = $user->tenant_schema;
        $patternJson = NULL;
        QueryHelper::initializeConnection($tenantSchema);
        // Step 1: Ensure tables exist
        if (
            !Schema::hasTable('orders') ||
            !Schema::hasTable('order_items') ||
            !Schema::hasTable('order_item_design_areas') ||
            !Schema::hasTable('order_item_add_ons')
        ) {
            $this->setupService->createTables($tenantSchema);
        }
       $validator = Validator::make($request->all(), [
            'order_type' => 'required|string',
            'customer_id' => 'required|integer',
            'delivery_time' => 'required|date',
            'function_date' => 'nullable|date',
            'trial_date' => 'nullable|date',
            'urgent_status' => 'nullable|string',
            'quantity' => 'required|integer',
            'subtotal' => 'required|numeric',
            'discount' => 'required|numeric',
            'final_total' => 'required|numeric',
            'item' => 'required|array'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422); // Prevents 302
        }

        $data = $validator->validated();
        DB::beginTransaction();
        try {
            $order = Order::create([
                'order_type'    => $data['order_type'],
                'customer_id'   => $data['customer_id'],
                'delivery_time' => $data['delivery_time'],
                'employee_id'   => $data['employee_id'] ?? null,
                'function_date' => $data['function_date'] ?? null,
                'trial_date'    => $data['trial_date'] ?? null,
                'urgent_status' => $data['urgent_status'] ?? null,
                'quantity'      => $data['quantity'],
                'subtotal'      => $data['subtotal'],
                'discount'      => $data['discount'],
                'final_total'   => $data['final_total'],
                'stage' => count($data['item']) === 1 ? $data['item'][0]['stage_name'] : null,// Default stage
                'created_by' => $user->id
            ]);
            // Step 2: Generate order_no
            $orderCount = Order::whereMonth('created_at', now()->month)
                ->whereYear('created_at', now()->year)
                ->count();
            $orderNo = 'ORD/' . now()->format('m/y') . '/' . str_pad($orderCount, 3, '0', STR_PAD_LEFT);
            // Step 3: Save order_no to the order
            $order->order_no = $orderNo;
            $order->save();
            foreach ($data['item'] as  $itemKey => $item) {
                    $uploadedUrls = [];
                // Check if there are base64 images in measurements
                if (!empty($item['measurements']['measurementImages']) && is_array($item['measurements']['measurementImages'])) {
                    foreach ($item['measurements']['measurementImages'] as $base64Image) {
                        // Extract base64 data
                        if (preg_match('/^data:image\/(\w+);base64,/', $base64Image, $type)) {
                            $dataPart = substr($base64Image, strpos($base64Image, ',') + 1);
                            $dataPart = base64_decode($dataPart);
                            if ($dataPart === false) {
                                continue;
                            }
                            $extension = strtolower($type[1]); // jpg, png, gif, etc.
                            $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
                            if (!in_array($extension, $allowedExtensions)) {
                                continue;
                            }
                            $fileName = 'measurement_' . uniqid() . '.' . $extension;
                            Storage::disk('public')->put("{$tenantSchema}/measurements/" . $fileName, $dataPart);
                            $uploadedUrls[] ="{$tenantSchema}/measurements/" . $fileName;
                         }
                    }
                     $item['measurements']['measurementImages'] = $uploadedUrls;
                }

                if (isset($item['pattern'])) {
                           if (preg_match('/^data:image\/(\w+);base64,/', $item['pattern']['image'], $type)) {
                                $dataPart = substr($item['pattern']['image'], strpos($item['pattern']['image'], ',') + 1);
                                $dataPart = base64_decode($dataPart);
                                if ($dataPart === false) {
                                    continue;
                                }
                                $extension = strtolower($type[1]); // jpg, png, gif, etc.
                                $allowedExtensions = ['jpg', 'jpeg', 'png', 'gif'];
                                if (!in_array($extension, $allowedExtensions)) {
                                    continue;
                                }
                                $fileName = 'pattern_' . uniqid() . '.' . $extension;
                                Storage::disk('public')->put("{$tenantSchema}/pattern/" . $fileName, $dataPart);
                                $item['pattern']['image'] = "{$tenantSchema}/pattern/" . $fileName;
                            }

                            $patternJson = [
                                'name' => $item['pattern']['name'] ?? null,
                                'price' => $item['pattern']['price'] ?? null,
                                'image' => $item['pattern']['image'] ?? null, // can be base64
                                'stagePrices' => $item['pattern']['stage_prices'] ?? [],
                            ];

                        }
                $item['pattern'] = $patternJson ? json_encode($patternJson) : null;

                $orderItem = $order->items()->create([
                    'item_id'       => $item['item_id'],
                    'to_whom'       => $item['to_whom'] ?? null,
                    'pattern'       => $item['pattern'],
                    'measurements'  => json_encode($item['measurements'] ?? []),
                    'quantity'      => $item['quantity'] ?? 1,
                    'total_price'   => $item['total_price'],
                    'employee_id'   => $item['employee_id'] ?? null,
                    'note'          => $item['note'] ?? null,
                ]);

                // Design Areas
                if (!empty($item['design']['design_areas'])) {
                    foreach ($item['design']['design_areas'] as $k => $area) {
                        $DesginAreaOpyionsIDs[$k] = $area['id'];
                        $orderItem->designAreas()->create([
                            'name'       => $area['name'],
                            'area_price' => $area['area_price'],
                            'area_name'  => $area['area_name'],
                            'area_option_id' => $area['id'],
                        ]);
                    }
                }
                // Add-ons
                if (!empty($item['add_ons'])) {
                    foreach ($item['add_ons'] as $addon) {
                        $orderItem->addOns()->create([
                            'name'  => $addon['name'],
                            'price' => $addon['price'],
                        ]);
                    }
                }


                $ItemID =  $item['item_id'];
                if (isset($item['employee_id']) && $item['employee_id'] && !is_null($item['stage_name'])) {
                      // Ensure quantity is set
                  	$stage = $item['stage_name'];
                    $ItemQty = $item['quantity'] ?? 1;
                    $EmployeePrice = DB::table('boutique_design_options')
                        ->whereIn('id', $DesginAreaOpyionsIDs)
                         ->pluck('stagePrices');

                   $stagePriceTotal = $EmployeePrice->reduce(function ($carry, $item) use ($stage) {
                            $decoded = json_decode($item, true);
                            $stageLower = strtolower($stage);

                            if(empty($decoded)) {
                                return $carry;
                            }
                            $decodedLower = array_change_key_case($decoded, CASE_LOWER);

                            return $carry + ($decodedLower[$stageLower] ?? 0);
                        }, 0);

                    for( $i = 0; $i < $ItemQty; $i++) {
                       $EmpinsertedId = DB::table('employees_orders')->insertGetId([
                            'emp_id' => $item['employee_id'],
                            'order_id' => $order->id,
                            'item_id' => $orderItem->id,
                            'stage' => $item['stage_name'] ?? null,
                            'priceCommision' => round($stagePriceTotal, 2), // sum of stage prices
                            'status' => 0, // Assuming 0 is the initial status
                        ]);

                    }
                    $order->status = 'In Process'; // or any other status like 'processing', 'cancelled'
                    $order->save();

                    $employee_mobile = DB::table('employees')->where('id', $item['employee_id'])->value('mobile');
                    $FcmToken = DB::connection('master_db')->table('tenants')->where('mobile', $employee_mobile)->value('fcm_token');
                    if(!is_null($FcmToken)) {
                        dispatch(new SendPushNotification(
                            [$FcmToken], // array of FCM tokens (employee’s device token)
                            'New Order Assigned!',
                            'A new order has been created. Please check your task list.',
                            'https://cdn-icons-png.freepik.com/512/8980/8980628.png', // optional image
                            [
                                'route' => '/order-item-details',
                                'item_id' => (string) $orderItem->id,
                                'employee_order_id' => (string) $EmpinsertedId,
                            ]
                        ));
                    }
                }
                $orderItemList[$itemKey]['emp_key'] = $EmpinsertedId ?? null;
                $orderItemList[$itemKey]['Item_key'] = $orderItem->id;
                $orderItemList[$itemKey]['quantity'] = $item['quantity'];


            }
             DB::commit();

             return response()->json([
                'status' => 'success',
                'order_id' => $order->id,
                'order_no' => $order->order_no,
                'orderItemList' => $orderItemList,
                'message' => 'Order created successfully.',
            ], 201);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function UpdateOrderStatus(Request $request)
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
        $data = $request->validate([
            'OrderID' => 'required|integer',
            'status' => 'required|string',
        ]);
        try {
            $order = Order::findOrFail($data['OrderID']);
            $order->status = $data['status'];
            $order->save();

            return response()->json([
                'status' => 'success',

            ],201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

    public function UpdateOrderStage(Request $request)
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
        $data = $request->validate([
            'OrderID' => 'required|integer',
            'stage' => 'required|string',
        ]);
        try {
            $order = Order::findOrFail($data['OrderID']);
            $order->stage = $data['stage'];
            $order->save();

            return response()->json([
                'status' => 'success',

            ],201);
        } catch (\Exception $e) {
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }

  public function getOrderDetail($id)
    {
        $user = Auth::guard('api')->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        try {
            // Connect to tenant schema
            QueryHelper::initializeConnection($user->tenant_schema);
            $connection = DB::connection('tenant');

            // Get the main order
            $order = $connection->table('orders')->where('id', $id)->first();
            $order = $connection->table('orders as o')
                        ->select(
                            'o.*',
                            'c.name as customer_name',
                            'c.mobile as customer_mobile',
                        )
                        ->join('customers as c', 'o.customer_id', '=', 'c.id')
                        ->where('o.id', $id)
                        ->first();
            // Get all order_items
            $orderItems = $connection->table('order_items')->where('order_id', $id)->get();

            // For each order_item, get add_ons and design_areas
            $orderItemsWithDetails = $orderItems->map(function ($item) use ($connection) {
                // Double decoding if needed
                $measurements = $item->measurements;

                // Try decoding once
                $decoded = json_decode($measurements, true);

                // If it's still a string after decoding, decode again
                if (is_string($decoded)) {
                    $decoded = json_decode($decoded, true);
                }

                $item->measurements = $decoded;

                // Add-ons
                $item->add_ons = $connection->table('order_item_add_ons')
                    ->where('order_item_id', $item->id)
                    ->get();

                // Design areas
                $item->design_areas = $connection->table('order_item_design_areas')
                    ->where('order_item_id', $item->id)
                    ->get();

                $employess = $connection->table('employees_orders')
                    ->join('employees', 'employees_orders.emp_id', '=', 'employees.id')
                    ->select('employees.full_name','employees_orders.status as current_status',
                        'employees_orders.stage')
                    ->where('item_id', $item->id)
                    ->get();

                    $statusLabels = [
                            0 => 'New',
                            1 => 'In Process',
                            2 => 'Done',
                            3 => 'Held',
                            4 => 'Cancelled',
                        ];
                     //0=New,1=In Process,2=Done,3=Held,4=Cancel	current status
                $item->employees = $employess->map(function ($emp) use ($statusLabels) {
                $statusKey = (int) $emp->current_status; // cast string to int
                    return [
                        'full_name' => $emp->full_name,
                        'current_status' => $statusKey,
                        'status_label' => $statusLabels[$statusKey] ?? 'Unknown',
                        'stage' => $emp->stage,
                    ];
                });

                return $item;
            });

            return response()->json([
                'success' => true,
                'order' => $order,
                'order_items' => $orderItemsWithDetails
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong.',
                'error' => $e->getMessage()
            ], 500);
        }
    }
   public function getItemListByOrder($id)
    {
        $user = Auth::guard('api')->user();
        if (!$user) {
            return response()->json(['message' => 'Unauthorized'], 401);
        }

        // try {
        //     // Connect to tenant schema
        //     QueryHelper::initializeConnection($user->tenant_schema);
        //     $connection = DB::connection('tenant');
        //     // Get the main order item

        //     $orderItems = $connection->table('order_items')
        //                 ->select('boutique_items.item_name as item_name','order_items.id')
        //                 ->join('boutique_items', 'order_items.item_id', '=', 'boutique_items.id')
        //                 ->where('order_items.order_id', $id)->get();

        //     return response()->json([
        //         'success' => true,
        //         'order_items' => $orderItems
        //     ]);
        // } catch (\Exception $e) {
        //     return response()->json([
        //         'success' => false,
        //         'message' => 'Something went wrong.',
        //         'error' => $e->getMessage()
        //     ], 500);
        // }

        try {
    // Connect to tenant schema
            QueryHelper::initializeConnection($user->tenant_schema);
            $connection = DB::connection('tenant');

            // Fetch order items along with their status from employees_orders
            $orderItems = $connection->table('order_items')
                ->select(
                    'boutique_items.item_name as item_name','order_items.id',
                    'employees_orders.status as employee_status',
                    'employees_orders.stage as employee_stage')
                ->join('boutique_items', 'order_items.item_id', '=', 'boutique_items.id')
                ->leftJoin('employees_orders', 'order_items.id', '=', 'employees_orders.item_id') // assuming relation via `order_item_id`
                ->where('order_items.order_id', $id)
                ->get();
            $statusLabels = [
                       0 => 'New',
                       1 => 'In Process',
                       2 => 'Done',
                       3 => 'Held',
                       4 => 'Cancelled',
              ];

               // Append status_label to each item
                $orderItems = $orderItems->map(function ($item) use ($statusLabels) {
                    $item->status_label = isset($statusLabels[$item->employee_status])
                        ? $statusLabels[$item->employee_status]
                        : 'Unknown';
                    return $item;
                });
            return response()->json([
                'success' => true,
                'order_items' => $orderItems
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong.',
                'error' => $e->getMessage()
            ], 500);
        }

    }

    public function update(Request $request, $id)
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
//        dd($tenantSchema, DB::connection()->getDatabaseName(), Order::all()->pluck('id'));


        // Ensure tables exist
        if (
            !Schema::hasTable('orders') ||
            !Schema::hasTable('order_items') ||
            !Schema::hasTable('order_item_design_areas') ||
            !Schema::hasTable('order_item_add_ons')
        ) {
            $this->setupService->createTables($tenantSchema);
        }

        $validator = Validator::make($request->all(), [
            'order_type' => 'required|string',
            'customer_id' => 'required|integer',
            'delivery_time' => 'required|date',
            'function_date' => 'nullable|date',
            'trial_date' => 'nullable|date',
            'urgent_status' => 'nullable|string',
            'quantity' => 'required|integer',
            'subtotal' => 'required|numeric',
            'discount' => 'required|numeric',
            'final_total' => 'required|numeric',
            'item' => 'required|array'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $data = $validator->validated();

        QueryHelper::initializeConnection($tenantSchema);
        DB::beginTransaction();
        try {
            $order = Order::findOrFail($id);
            $order->update([
                'order_type'    => $data['order_type'],
                'customer_id'   => $data['customer_id'],
                'delivery_time' => $data['delivery_time'],
                'employee_id'   => $data['employee_id'] ?? null,
                'function_date' => $data['function_date'] ?? null,
                'trial_date'    => $data['trial_date'] ?? null,
                'urgent_status' => $data['urgent_status'] ?? null,
                'quantity'      => $data['quantity'],
                'subtotal'      => $data['subtotal'],
                'discount'      => $data['discount'],
                'final_total'   => $data['final_total'],
                'stage' => count($data['item']) === 1 ? $data['item'][0]['stage_name'] : null,
                'updated_by' => $user->id
            ]);

            // Remove old related records before inserting new
            $order->items()->delete();

            $orderItemList = [];

            foreach ($data['item'] as $itemKey => $item) {
                $uploadedUrls = [];

                // Handle measurement images
                if (!empty($item['measurements']['measurementImages']) && is_array($item['measurements']['measurementImages'])) {
                    foreach ($item['measurements']['measurementImages'] as $base64Image) {
                        if (preg_match('/^data:image\/(\w+);base64,/', $base64Image, $type)) {
                            $dataPart = base64_decode(substr($base64Image, strpos($base64Image, ',') + 1));
                            if ($dataPart === false) continue;
                            $extension = strtolower($type[1]);
                            if (!in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) continue;
                            $fileName = 'measurement_' . uniqid() . '.' . $extension;
                            Storage::disk('public')->put("{$tenantSchema}/measurements/" . $fileName, $dataPart);
                            $uploadedUrls[] = "{$tenantSchema}/measurements/" . $fileName;
                        }
                    }
                    $item['measurements']['measurementImages'] = $uploadedUrls;
                }

                // Handle pattern image
                $patternJson = null;
                if (isset($item['pattern'])) {
                    if (preg_match('/^data:image\/(\w+);base64,/', $item['pattern']['image'], $type)) {
                        $dataPart = base64_decode(substr($item['pattern']['image'], strpos($item['pattern']['image'], ',') + 1));
                        if ($dataPart !== false) {
                            $extension = strtolower($type[1]);
                            if (in_array($extension, ['jpg', 'jpeg', 'png', 'gif'])) {
                                $fileName = 'pattern_' . uniqid() . '.' . $extension;
                                Storage::disk('public')->put("{$tenantSchema}/pattern/" . $fileName, $dataPart);
                                $item['pattern']['image'] = "{$tenantSchema}/pattern/" . $fileName;
                            }
                        }
                    }
                    $patternJson = [
                        'name' => $item['pattern']['name'] ?? null,
                        'price' => $item['pattern']['price'] ?? null,
                        'image' => $item['pattern']['image'] ?? null,
                        'stagePrices' => $item['pattern']['stage_prices'] ?? [],
                    ];
                }
                $item['pattern'] = $patternJson ? json_encode($patternJson) : null;

                // Create order item
                $orderItem = $order->items()->create([
                    'item_id'       => $item['item_id'],
                    'to_whom'       => $item['to_whom'] ?? null,
                    'pattern'       => $item['pattern'],
                    'measurements'  => json_encode($item['measurements'] ?? []),
                    'quantity'      => $item['quantity'] ?? 1,
                    'total_price'   => $item['total_price'],
                    'employee_id'   => $item['employee_id'] ?? null,
                    'note'          => $item['note'] ?? null,
                ]);

                // Add design areas
                if (!empty($item['design']['design_areas'])) {
                    foreach ($item['design']['design_areas'] as $area) {
                        $orderItem->designAreas()->create([
                            'name'       => $area['name'],
                            'area_price' => $area['area_price'],
                            'area_name'  => $area['area_name'],
                            'area_option_id' => $area['id'],
                        ]);
                    }
                }

                // Add-ons
                if (!empty($item['add_ons'])) {
                    foreach ($item['add_ons'] as $addon) {
                        $orderItem->addOns()->create([
                            'name'  => $addon['name'],
                            'price' => $addon['price'],
                        ]);
                    }
                }

                // Assign employee and send notification
                if (isset($item['employee_id']) && $item['employee_id'] && !is_null($item['stage_name'])) {
                    $stage = $item['stage_name'];
                    $ItemQty = $item['quantity'] ?? 1;
                    $EmployeePrice = DB::table('boutique_design_options')
                        ->whereIn('id', array_column($item['design']['design_areas'], 'id'))
                        ->pluck('stagePrices');

                    $stagePriceTotal = $EmployeePrice->reduce(function ($carry, $val) use ($stage) {
                        $decoded = json_decode($val, true);
                        if (!$decoded) return $carry;
                        return $carry + ($decoded[strtolower($stage)] ?? 0);
                    }, 0);

                    for ($i = 0; $i < $ItemQty; $i++) {
                        $EmpinsertedId = DB::table('employees_orders')->insertGetId([
                            'emp_id' => $item['employee_id'],
                            'order_id' => $order->id,
                            'item_id' => $orderItem->id,
                            'stage' => $item['stage_name'],
                            'priceCommision' => round($stagePriceTotal, 2),
                            'status' => 0,
                        ]);
                    }

                    $employee_mobile = DB::table('employees')->where('id', $item['employee_id'])->value('mobile');
                    $FcmToken = DB::connection('master_db')->table('tenants')->where('mobile', $employee_mobile)->value('fcm_token');
                    if (!is_null($FcmToken)) {
                        dispatch(new SendPushNotification(
                            [$FcmToken],
                            'Order Updated!',
                            'An order has been updated. Please check your task list.',
                            'https://cdn-icons-png.freepik.com/512/8980/8980628.png',
                            [
                                'route' => '/order-item-details',
                                'item_id' => (string) $orderItem->id,
                                'employee_order_id' => (string) $EmpinsertedId,
                            ]
                        ));
                    }
                }

                $orderItemList[$itemKey] = [
                    'emp_key' => $EmpinsertedId ?? null,
                    'Item_key' => $orderItem->id,
                    'quantity' => $item['quantity']
                ];
            }

            DB::commit();

            return response()->json([
                'status' => 'success',
                'order_id' => $order->id,
                'order_no' => $order->order_no,
                'orderItemList' => $orderItemList,
                'message' => 'Order updated successfully.',
            ], 200);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 'error', 'message' => $e->getMessage()], 500);
        }
    }



    public function CustomerOrderDetail($id, $ts)
    {
        $tenant_schema = base64_decode($ts);

        try {
            // Connect to tenant schema
            QueryHelper::initializeConnection($tenant_schema);
            $connection = DB::connection('tenant');

            // Get the main order
            $order = $connection->table('orders')->where('id', $id)->first();
            $order = $connection->table('orders as o')
                        ->select(
                            'o.*',
                            'c.name as customer_name',
                            'c.mobile as customer_mobile',
                        )
                        ->join('customers as c', 'o.customer_id', '=', 'c.id')
                        ->where('o.id', $id)
                        ->first();
            // Get all order_items
            $orderItems = $connection->table('order_items')->where('order_id', $id)->get();

            // For each order_item, get add_ons and design_areas
            $orderItemsWithDetails = $orderItems->map(function ($item) use ($connection) {
                // Double decoding if needed
                $measurements = $item->measurements;

                // Try decoding once
                $decoded = json_decode($measurements, true);

                // If it's still a string after decoding, decode again
                if (is_string($decoded)) {
                    $decoded = json_decode($decoded, true);
                }

                $item->measurements = $decoded;

                // Add-ons
                $item->add_ons = $connection->table('order_item_add_ons')
                    ->where('order_item_id', $item->id)
                    ->get();

                // Design areas
                $item->design_areas = $connection->table('order_item_design_areas')
                    ->where('order_item_id', $item->id)
                    ->get();

                $employess = $connection->table('employees_orders')
                    ->join('employees', 'employees_orders.emp_id', '=', 'employees.id')
                    ->select('employees.full_name','employees_orders.status as current_status',
                        'employees_orders.stage')
                    ->where('item_id', $item->id)
                    ->get();

                    $statusLabels = [
                            0 => 'New',
                            1 => 'In Process',
                            2 => 'Done',
                            3 => 'Held',
                            4 => 'Cancelled',
                        ];
                     //0=New,1=In Process,2=Done,3=Held,4=Cancel	current status
                $item->employees = $employess->map(function ($emp) use ($statusLabels) {
                $statusKey = (int) $emp->current_status; // cast string to int
                    return [
                        'full_name' => $emp->full_name,
                        'current_status' => $statusKey,
                        'status_label' => $statusLabels[$statusKey] ?? 'Unknown',
                        'stage' => $emp->stage,
                    ];
                });

                return $item;
            });

            return response()->json([
                'success' => true,
                'order' => $order,
                'order_items' => $orderItemsWithDetails
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong.',
                'error' => $e->getMessage()
            ], 500);
        }
    }


}



