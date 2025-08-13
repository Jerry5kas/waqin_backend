<?php
namespace App\Http\Controllers;

use App\Helpers\QueryHelper;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class TenantSettingController extends Controller
{

    public function getTeantSetting(Request $request){
        $user = Auth::guard('api')->user();
        QueryHelper::initializeConnection($user->tenant_schema);
        DB::setDefaultConnection('tenant');
        if (!Schema::hasTable('setting_master')) {
            Schema::create('setting_master', function (Blueprint $table) {
                $table->id(); // Auto-increment primary key
                $table->integer('emp_view_contact')->default(0);
                $table->integer('emp_create_contact')->default(0);
                $table->integer('emp_view_customer')->default(0);
                $table->integer('gst_persantage')->default(0);
                $table->timestamp('created_at')->default(DB::raw('CURRENT_TIMESTAMP'));
                $table->timestamp('updated_at')->default(DB::raw('CURRENT_TIMESTAMP'))->onUpdate(DB::raw('CURRENT_TIMESTAMP'));
            });

            DB::table('setting_master')->insert([
                'emp_view_contact' => 0,
                'emp_create_contact' => 0,
                'emp_view_customer' => 0,
                'gst_persantage' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $tenantSetting = DB::table('setting_master')->get();
        return response()->json($tenantSetting, 200);
    }

    public function updateTenantSetting(Request $request)
    {
        $user = Auth::guard('api')->user();
        QueryHelper::initializeConnection($user->tenant_schema);
        DB::setDefaultConnection('tenant');

        // Validate request
        $validated = $request->validate([
            'emp_view_contact' => 'required|integer',
            'emp_create_contact' => 'required|integer',
            'emp_view_customer' => 'required|integer',
            'gst_persantage' => 'required|integer',
        ]);

        // Update the only row in setting_master (assuming only one row exists)
        DB::table('setting_master')->update([
            'emp_view_contact' => $validated['emp_view_contact'],
            'emp_create_contact' => $validated['emp_create_contact'],
            'emp_view_customer' => $validated['emp_view_customer'],
            'gst_persantage' => $validated['gst_persantage'],
            'updated_at' => now(),
        ]);

        return response()->json(['message' => 'Tenant setting updated successfully'], 200);
    }

}
