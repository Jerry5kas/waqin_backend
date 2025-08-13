<?php

namespace App\Services;

use Illuminate\Support\Facades\DB;

class DatabaseService
{
    /**
     * Create a new database.
     *
     * @param string $dbName The name of the database to create.
     * @return bool Returns true if successful, false otherwise.
     */
    public function createDatabase(string $dbName): bool
    {
        $query = "CREATE DATABASE IF NOT EXISTS `$dbName`";
        try {
            DB::statement($query);
            return true;
        } catch (\Exception $e) {
            // Log error or handle exception
            return false;
        }
    }

    /**
     * Delete a database.
     *
     * @param string $dbName The name of the database to delete.
     * @return bool Returns true if successful, false otherwise.
     */
    public function deleteDatabase(string $dbName): bool
    {
        $query = "DROP DATABASE IF EXISTS `$dbName`";
        try {
            DB::statement($query);
            return true;
        } catch (\Exception $e) {
            // Log error or handle exception
            return false;
        }
    }

    // Add more database-related functions here...
}
