<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;
use App\Services\DatabaseService;


class TableCreationService
{

    protected $dbService;

    public function __construct(DatabaseService $dbService)
    {
        $this->dbService = $dbService;
    }
    public function configDB($tenantDbName){
        config(['database.connections.tenant' => [
            'driver' => 'mysql',
            'host' => env('DB_HOST', '127.0.0.1'),
            'port' => env('DB_PORT', '3306'),
            'database' => $tenantDbName,
            'username' => env('DB_USERNAME', 'root'),
            'password' => env('DB_PASSWORD', ''),
            'charset' => 'utf8mb4',
            'collation' => 'utf8mb4_general_ci',
            'prefix' => '',
            'strict' => true,
            'engine' => null,
        ]]);
    }

    /**
     * Create a new table.
     *
     * @param string $dbName The name of the database to create the table in.
     * @param string $tableName The name of the table to create.
     * @param array $columns An associative array where keys are column names and values are column definitions.
     * @return bool Returns true if successful, false otherwise.
     */
    public function createTable(string $dbName, string $tableName, array $columns): bool
    {
        // Build the columns SQL definition
        $columnsDefinition = implode(', ', array_map(function($name, $definition) {
            return "`$name` $definition";
        }, array_keys($columns), $columns));

        // SQL query to create the table
        $query = "CREATE TABLE IF NOT EXISTS `$dbName`.`$tableName` ($columnsDefinition)";

        try {
            DB::statement($query);
            return true;
        } catch (\Exception $e) {
            // Log error or handle exception
            // You can use Log::error($e->getMessage()) to log the exception message
            return false;
        }
    }
}
