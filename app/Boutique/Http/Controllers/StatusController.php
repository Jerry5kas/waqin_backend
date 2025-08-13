<?php

namespace App\Boutique\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use App\Boutique\Models\Status;

class StatusController extends Controller
{
    private function connectToTenant()
    {
        $user = Auth::guard('api')->user();

        if (!$user || !isset($user->tenant_schema)) {
            abort(response()->json(['message' => 'Tenant schema missing in token'], 401));
        }

        config(['database.connections.tenant.database' => $user->tenant_schema]);
        DB::purge('tenant');
        DB::reconnect('tenant');
    }

    private function ensureTableExists()
    {
        if (!Schema::connection('tenant')->hasTable('statuses')) {
            Artisan::call('migrate', [
               '--path' => 'database/migrations/tenant/create_statuses_table.php',
               '--database' => 'tenant',
            ]);
            Artisan::call('db:seed', [
                '--class' => 'StatusSeeder',
                '--database' => 'tenant',
            ]);
        }
    }

    public function index(Request $request)
    {
        $this->connectToTenant();
        //$this->ensureTableExists();

        $query = Status::on('tenant');
        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $this->connectToTenant();
        //$this->ensureTableExists();

        $validated = $request->validate([
            'name' => 'required|string',
        ]);

        $exists = Status::on('tenant')
            ->where('name', $validated['name'])
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Status already exists for this type'], 409);
        }

        $Status = Status::on('tenant')->create($validated);
        return response()->json($Status, 201);
    }

    public function update(Request $request, $id)
    {
        $this->connectToTenant();
       // $this->ensureTableExists();

        $Status = Status::on('tenant')->findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string',
        ]);

        $Status->update($validated);
        return response()->json($Status);
    }
    public function destroy($id)
    {   
        $this->connectToTenant();
        $Status = Status::on('tenant')->find($id);

        if (!$Status) {
            return response()->json(['message' => 'Status not found'], 404);
        }

        $Status->delete();

        return response()->json(['message' => 'Status deleted successfully'], 200);
    }
}
