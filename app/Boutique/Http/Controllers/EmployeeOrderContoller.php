<?php

namespace App\Boutique\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use App\Boutique\Services\BoutiqueSetupService;
use App\Boutique\Models\Order;
use Illuminate\Support\Facades\Auth;
use App\Helpers\QueryHelper;
use App\Boutique\Models\EmployeeOrder;
use App\Boutique\Models\Stages;
class EmployeeOrderContoller extends Controller
{

    
    // for Employee
    public function listEmployeeOrders()
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
        if (!Schema::hasTable('employees_orders')) {
            return response()->json([
                'message' => 'Employees Order not found.',
                'orders' => null,
            ], 200);
        }
        $employee = DB::table('employees')->where('mobile', $user->mobile)->first();
        
        if (!$employee) {
            return response()->json(['message' => 'Employee not found'], 404);
        }
        $orderIDs = DB::table('employees_orders')
            ->where('emp_id', $employee->id)
            ->pluck('order_id');

        $orders = DB::table('orders')
            ->whereIn('id', $orderIDs)
            ->get();

        return response()->json([
            'orders' => $orders,
        ]);
    }

    public function updateStatusByEmployee(Request $request)
    {
         $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
        $id = $request->input('id');
        $status = $request->input('status');
        //0=New,1=In Process,2=Done,3=Held,4=Cancel	
        DB::table('employees_orders')
            ->where('id', $id)
            ->update(['status' => $status]);

        return response()->json([
            'message' => 'Order status updated successfully',
        ], 200);
    }

    public function GetItemDetailsBasedOnItem($ItemId,$eoiid){
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }
        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
        $item = DB::table('order_items')
            ->select('id', 'to_whom','pattern', 'measurements', 'quantity', 'note')
            ->where('id', $ItemId)
            ->first();

            if ($item) {
                $decoded = json_decode($item->measurements, true);
                if (is_string($decoded)) {
                    $item->measurements = json_decode($decoded, true); // second decode
                } else {
                    $item->measurements = $decoded;
                }

                $decoded = json_decode($item->pattern, true);
                if (is_string($decoded)) {
                    $item->pattern = json_decode($decoded, true); // second decode
                } else {
                    $item->pattern = $decoded;
                }
              //  $item->measurements = json_decode($item->measurements);
                $item->design_areas = DB::table('order_item_design_areas')
                    ->select('name as design_area_name', 'area_name')
                    ->where('order_item_id', $item->id)
                    ->get();
                $item->EmployeeCurentStage = DB::table('employees_orders')
                    ->where('id', $eoiid)
                    ->value('status');
                $item->add_ons = DB::table('order_item_add_ons')
                    ->select('name as add_on_name')
                    ->where('order_item_id', $item->id)
                    ->get();
            }
            
        
        if (!$item) {
            return response()->json(['message' => 'Item not found'], 404);
        }
        return response()->json([
            'itemDetails' => $item,
        ], 200);
    }

    public function listEmployeeOrdersbyID($eid)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;

        QueryHelper::initializeConnection($tenantSchema);
        if (!Schema::hasTable('employees_orders')) {
            return response()->json([
                'message' => 'Employees Order not found.',
                'orders' => null,
            ], 200);
        }
        $orderIDs = DB::table('employees_orders')
            ->where('emp_id', $eid)
            ->pluck('order_id');

        $orders = DB::table('orders')
            ->whereIn('id', $orderIDs)
            ->get();

        return response()->json([
            'orders' => $orders,
        ]);
    }

    public function asignedEmployeeOrder(Request $request)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
       
        $employeeID = $request->input('employee_id');
        $OrderID = $request->input('order_id');
        $item = $request->input('item');
        $stage = $request->input('stage');
       
        $Type = Stages::where('name', $stage)->value('type');
      
        if (!$employeeID || !$OrderID) {
            return response()->json(['message' => 'Employee ID and Order ID are required'], 400);
        }
        $stagePriceTotal = 0;

        foreach ($item as $key => $value) {
            $qty = (int) $value['qty'];
            for ($i = 0; $i < $qty; $i++) {
                if($Type == 'pattern'){
                    $orderItem = DB::table('order_items')
                        ->select('pattern')
                        ->where('id', $value['id'])
                        ->pluck('pattern');
                    $StagePrice = json_decode($orderItem[0],true);
                  
                    foreach ($StagePrice['stagePrices'] as $stagePrice) {
                        if ($stagePrice['stage'] === $stage) {
                            $stagePriceTotal = $stagePrice['price'];
                            break;
                        }
                    }
                }else{
                    $orderItem = DB::table('order_item_design_areas')
                            ->select('area_option_id')
                            ->where('order_item_id', $value['id'])
                            ->pluck('area_option_id');
                
                    $IDs = $orderItem->toArray();
                    $EmployeePrice = DB::table('boutique_design_options')
                            ->whereIn('id', $IDs)
                            ->pluck('stagePrices');
            
                    $stagePriceTotal = $EmployeePrice->reduce(function ($carry, $item) use ($stage) {
                            $decoded = json_decode($item, true);    
                            if (empty($decoded)) {
                                return $carry; // Skip if decoded is empty
                            }
                            $stageLower = strtolower($stage);
                            // Normalize keys of the JSON array to lowercase
                            $decoded = array_change_key_case($decoded, CASE_LOWER);
                            
                            // Sum the stage price for the given stage
                            return $carry + ($decoded[$stageLower] ?? 0);
                        }, 0);     
                }
                
                DB::table('employees_orders')->insert([
                    'emp_id' => $employeeID,
                    'order_id' => $OrderID,
                    'item_id' => $value['id'],
                    'stage' => $stage, // Assuming 'New' is the initial stage
                    'priceCommision' => round($stagePriceTotal,2), // sum of stage prices,
                    'status' => 0, // Assuming 0 is the initial status
                ]);
            }
        }       
       
        return response()->json(['message' => 'Order assigned successfully'], 200);
    }

    public function GetEmpDashboardData()
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }
        $tenantSchema = $user->tenant_schema;
        QueryHelper::initializeConnection($tenantSchema);
        if (!Schema::hasTable('employees_orders')) {
            return response()->json([
                'message' => 'Employees Order not found.',
                'summary' => null,
            ], 200);
        }
        $employeeId = DB::table('employees')
            ->where('mobile', $user->mobile)
            ->value('id');
        if (!$employeeId) {
            return response()->json(['message' => 'Employee not found'], 404);
        }
        // Aggregated stats
        $totals = DB::table('employees_orders')
                ->selectRaw("
                    SUM(CASE WHEN status = 2 THEN 1 ELSE 0 END) as total_completed,
                    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) as total_pending,
                    SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as total_inprocess,
                    SUM(CASE WHEN status = 2 THEN priceCommision ELSE 0 END) as total_earning,
                    SUM(CASE 
                        WHEN status = 2 AND MONTH(created_at) = MONTH(CURRENT_DATE())
                            AND YEAR(created_at) = YEAR(CURRENT_DATE()) 
                        THEN priceCommision ELSE 0 END) as this_month_earning
                ")
                ->where('emp_id', $employeeId)
                ->first();


        return response()->json([
            'summary' => [
                'total_completed' => $totals->total_completed ?? 0,
                'total_pending' => $totals->total_pending ?? 0,
                'total_inprocess' => $totals->total_inprocess ?? 0,
                'total_earning' => (float) ($totals->total_earning ?? 0),
                'this_month_earning' => (float) ($totals->this_month_earning ?? 0),
            ]
        ]);
    }

    public function getEmployeeItemListByOrder($id)
    {
        $user = Auth::guard('api')->user();
        if (!$user || !isset($user->tenant_schema)) {
            return response()->json(['message' => 'Tenant schema missing in token'], 401);
        }

        $tenantSchema = $user->tenant_schema;

        QueryHelper::initializeConnection($tenantSchema);
        
       $order = DB::table('orders as o')
                    ->select(
                        'o.id as o_id',
                        'o.order_no',
                        'c.name',
                        'c.mobile',
                        'o.created_at as order_date',
                        'o.function_date',
                        'o.trial_date',
                        'o.delivery_time'
                    )
                    ->join('customers as c', 'o.customer_id', '=', 'c.id')
                    ->where('o.id', $id)
                    ->first();

            $employeeOrders = DB::table('employees_orders as eo')
                    ->select(
                        'eo.id as eo_id',
                        'eo.item_id',
                        'eo.stage',
                        'eo.status',
                        'bi.item_name',
                        'oi.id as oi_id',
                    )
                    ->join('order_items as oi', 'eo.item_id', '=', 'oi.id')
                    ->join('boutique_items as bi', 'oi.item_id', '=', 'bi.id')
                    ->where('eo.order_id', $id)
                    ->get();

            $order->employee_orders = $employeeOrders;
        
        return response()->json([
            'order' => $order,
        ], 200);
    }



}