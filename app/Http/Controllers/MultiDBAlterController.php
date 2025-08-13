<?php 

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MultiDBAlterController extends Controller
{
    public function addColumnToMultipleDBs(Request $request)
    {
        $request->validate([
            'column_name' => 'required|string',
            'column_type' => 'required|string',
            'table_names' => 'required|array',
        ]);

        $columnName = $request->input('column_name');
        $columnType = $request->input('column_type'); // e.g. "INT NULL", "VARCHAR(255) DEFAULT ''"
        $tables = $request->input('table_names');

        // Fetch all databases starting with prod_tenant_
        $prefix = env('DB_TENANT'); // e.g., 'staging_tenant_'
        $databases = DB::select("SHOW DATABASES LIKE '" . $prefix . "%'");
        $results = [];

        foreach ($databases as $db) {
            $dbName = array_values((array) $db)[0];
            DB::statement("USE `$dbName`");

            foreach ($tables as $table) {
                $columnExists = DB::select("
                    SELECT COLUMN_NAME 
                    FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?
                ", [$dbName, $table, $columnName]);

                if (empty($columnExists)) {
                    try {
                        DB::statement("ALTER TABLE `$dbName`.`$table` ADD COLUMN `$columnName` $columnType");
                        $results[] = "$dbName.$table -> column `$columnName` added.";
                    } catch (\Exception $e) {
                        $results[] = "$dbName.$table -> ERROR: " . $e->getMessage();
                    }
                } else {
                    $results[] = "$dbName.$table -> column `$columnName` already exists.";
                }
            }
        }

        return response()->json([
            'status' => 'completed',
            'results' => $results,
        ]);
    }
}
