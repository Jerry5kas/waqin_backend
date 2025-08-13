<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;

class FeatureAccess
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
{

    $tenantSchema = Auth::user()->tenant_schema; // Get tenant schema
    

    // Check access in `tbl_feat_access` table from master database
    $hasAccess = DB::connection('master_db') // Use master DB connection
                    ->table('tbl_feat_access')
                    ->where('tenant_schema', $tenantSchema)
                    ->where('status', 1)
                    ->exists();

    if ($hasAccess) {
        
    $request->attributes->set('useEnterpriseMethod', true);
    
    }
    
    return $next($request); // Continue to the controller
}

}
