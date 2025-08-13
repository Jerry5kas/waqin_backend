<?php

namespace App\Helpers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use timgws\QueryBuilderParser;

class FormHelper
{
    
    // public static function GetFormByName($name,$businessId,$status)
    // {
    //   $formQuery = DB::connection('master_db')
    //   ->table('form_builder')
    //   ->where('name', $name)
    //   ->whereRaw('FIND_IN_SET(?, bussiness_ids)', [$businessId])
    //   ->where('status', 1)
    //   ->where('is_deleted', 0);
      
    //   if (isset($status)) {
    //       $formQuery->where('status_master',(int) $status);
    //   }
      
    //   $form = $formQuery->first();
      
    // }
    public static function GetFormByName($name, $businessId, $status)
    {
        // Get the tenant schema from the request
         $tenantSchema = request()->input('tenant_schema');

        // Get IDs for MOD_EMP and MOD_BOUTIQUE
        $moduleIds = DB::connection('master_db')
            ->table('tbl_feature')
            ->whereIn('uid', ['MOD_EMP', 'MOD_BOUTIQUE'])
            ->pluck('id')
            ->toArray();

        // Check if user has access to any of the modules
        $hasAccess = DB::connection('master_db')
            ->table('tbl_feat_access')
            ->where('tenant_schema', $tenantSchema)
            ->whereIn('module_id', $moduleIds)
            ->where('status', 1)
            ->exists();

        // Choose the correct table based on feature access
        $tableName = $hasAccess ? 'ent_form_builder' : 'form_builder';

        // Build the query
        $formQuery = DB::connection('master_db')
            ->table($tableName)
            ->where('name', $name)
            ->whereRaw('FIND_IN_SET(?, bussiness_ids)', [$businessId])
            ->where('status', 1)
            ->where('is_deleted', 0);

        // Optional filter
        if (isset($status)) {
            $formQuery->where('status_master', $status);
        }

        return $formQuery->first();
    }
  
  public static function getFormById($formId, $tenantSchema)
{
    $moduleIds = DB::connection('master_db')
        ->table('tbl_feature')
        ->whereIn('uid', ['MOD_EMP', 'MOD_BOUTIQUE'])
        ->pluck('id')
        ->toArray();

    $hasAccess = DB::connection('master_db')
        ->table('tbl_feat_access')
        ->where('tenant_schema', $tenantSchema)
        ->whereIn('module_id', $moduleIds)
        ->where('status', 1)
        ->exists();

    $tableName = $hasAccess ? 'ent_form_builder' : 'form_builder';

    return DB::connection('master_db')->table($tableName)->where('id', $formId)->first();
}


}




