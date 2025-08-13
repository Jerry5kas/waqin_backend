<?php

namespace App\Boutique\Services;

use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use App\Helpers\QueryHelper;
use Illuminate\Support\Facades\Artisan;

class BoutiqueSetupService
{
    public function createTables($tenantSchema)
    {
        QueryHelper::initializeConnection($tenantSchema);
        require_once database_path('migrations/tenant/create_orders_module_tables.php');

        if (class_exists('CreateOrdersModuleTables')) {
            (new \CreateOrdersModuleTables())->up();
        }

    }
}
