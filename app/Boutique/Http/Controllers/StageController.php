<?php

namespace App\Boutique\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use App\Boutique\Models\Stages;

class StageController extends Controller
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
        if (!Schema::connection('tenant')->hasTable('stages')) {
            Artisan::call('migrate', [
               '--path' => 'database/migrations/tenant/create_stages_table.php',
               '--database' => 'tenant',
            ]);
           Artisan::call('db:seed', [
                '--class' => 'StageSeeder',
                '--database' => 'tenant',
            ]);
        }
    }

    public function index(Request $request)
    {
         $this->connectToTenant();
        $query = Stages::on('tenant');
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
         $this->connectToTenant();
        $validated = $request->validate([
            'name' => 'required|string',
            'type' => 'required|string|in:design,pattern',
            'status' => 'boolean'
        ]);

        $exists = Stages::on('tenant')
            ->where('name', $validated['name'])
            ->where('type', $validated['type'])
            ->exists();

        if ($exists) {
            return response()->json(['message' => 'Stage already exists for this type'], 409);
        }

        $stage = Stages::on('tenant')->create($validated);
        return response()->json($stage, 201);
    }

    public function update(Request $request, $id)
    {
        $this->connectToTenant();
       

        $stage = Stages::on('tenant')->findOrFail($id);

        $validated = $request->validate([
            'name' => 'sometimes|string',
            'type' => 'required|string|in:design,pattern',
            'status' => 'sometimes|boolean',
        ]);

        $stage->update($validated);
        return response()->json($stage);
    }
    public function destroy($id)
    {   
        $this->connectToTenant();
        $stage = Stages::on('tenant')->find($id);

        if (!$stage) {
            return response()->json(['message' => 'Stage not found'], 404);
        }

        $stage->delete();

        return response()->json(['message' => 'Stage deleted successfully'], 200);
    }
}
