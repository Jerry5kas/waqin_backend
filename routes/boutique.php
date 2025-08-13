<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Auth;
use App\Http\Controllers\BotiqueController;
use App\Boutique\Http\Controllers\OrderController;
use App\Boutique\Http\Controllers\BoutiqueSetupController;
use App\Boutique\Http\Controllers\StageController;
use App\Boutique\Http\Controllers\StatusController;
use App\Boutique\Http\Controllers\EmployeeOrderContoller;


Route::prefix('boutique')->group(function () {
    // public routes
    Route::get('/orders/{id}/{ts}/customerorderdetail', [OrderController::class, 'CustomerOrderDetail']);
    // protected routes
    Route::middleware('auth:boutique')->group(function () {
       // Order routes
        Route::post('/orders', [OrderController::class, 'index']);
        Route::get('/getitemdeatils/{itemId}/config', [BoutiqueSetupController::class, 'getItemConfiguration']);
        Route::post('/create_orders', [OrderController::class, 'store']);
        Route::put('/orders/{id}', [OrderController::class, 'update']);
        Route::put('/updateorders/{orderId}', [OrderController::class, 'updateorders']);
        Route::PUT('/update_order_status', [OrderController::class, 'UpdateOrderStatus']);
        Route::PUT('/update_order_stage', [OrderController::class, 'UpdateOrderStage']);
      	Route::get('/orders/{id}/detail', [OrderController::class, 'getOrderDetail']);

        Route::get('/orders/{id}/items', [OrderController::class, 'getItemListByOrder']);
        // Item routes
        Route::get('/getAllItems', [BoutiqueSetupController::class, 'getAllItems']);

        // Patterns routes
        Route::PUT('/updatePattern/{id}', [BoutiqueSetupController::class, 'updatePattern']);
        Route::get('/getAllPatterns/{itemId}', [BoutiqueSetupController::class, 'getAllPatterns']);
        Route::post('/pattern/add', [BoutiqueSetupController::class, 'addPattern']);
        Route::delete('/deletePattern/{id}', [BoutiqueSetupController::class, 'deletePattern']);

        // Design Areas routes
        Route::get('/getDesignAreasByItemId/{itemId}', [BoutiqueSetupController::class, 'getDesignAreasByItemId']);
        Route::PUT('/updateDesignAreasByItemId/{itemId}', [BoutiqueSetupController::class, 'updateDesignAreasByItemId']);


        //stages route
        Route::get('/getstages', [StageController::class, 'index']); // ?type=design or ?type=pattern
        Route::post('/addStage', [StageController::class, 'store']);
        Route::put('/updatestages/{id}', [StageController::class, 'update']);
        Route::delete('/deletestage/{id}', [StageController::class, 'destroy']);

        //status route
        Route::get('/getstatus', [StatusController::class, 'index']); // ?type=design or ?type=pattern
        Route::post('/addStatus', [StatusController::class, 'store']);
        Route::put('/updatestatus/{id}', [StatusController::class, 'update']);
        Route::delete('/deletestatus/{id}', [StatusController::class, 'destroy']);

        // Tenant employee routes
        Route::get('/employee/orders/{eid}', [EmployeeOrderContoller::class, 'listEmployeeOrdersbyID']);
        Route::post('/employee/asigned', [EmployeeOrderContoller::class, 'asignedEmployeeOrder']);

        //employee App route
        Route::get('/employee/orders', [EmployeeOrderContoller::class, 'listEmployeeOrders']);
        Route::put('/employee/update_status', [EmployeeOrderContoller::class, 'updateStatusByEmployee']);
        Route::get('/employee/item/{id}/{eoiid}', [EmployeeOrderContoller::class, 'GetItemDetailsBasedOnItem']);
        Route::get('/employee/dashboard', [EmployeeOrderContoller::class, 'GetEmpDashboardData']);
        Route::get('/orders/employee/{id}/items', [EmployeeOrderContoller::class, 'getEmployeeItemListByOrder']);

    });

});


