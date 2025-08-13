<?php

namespace App\Helpers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use timgws\QueryBuilderParser;
use Illuminate\Support\Facades\Schema;

class QueryHelper
{
    /**
     * Public method to get business categories based on rules.
     */
    public static function GetFormFields($formFields, $businessId, $tenantSchema, $subCategoryId = NULL)
{
    $filteredFormFields = [];

    foreach ($formFields as $key => $value) {
        
        // Process values only if QueryRule exists
        if (!empty($value['QueryRule'])) {
           
            $value['values'] = self::processRule($value['QueryRule'], $businessId, $tenantSchema, $subCategoryId);

            // Hide if values are empty and access is not true
            if (empty($value['values']) && empty($value['access'])) {
                continue;
            }
        }

        $filteredFormFields[] = $value;
    }

    return $filteredFormFields;
}

    /**
     * Public method to get Data based on Query Builder Rules.
     */
    public function GetTenantDBDataByQueryRules($schemaName,$Table,$allowedFields,$Rules){
           
        $table =  DB::connection('tenant')->table($Table)->select();
        $qbp = new QueryBuilderParser($allowedFields);
        // Parse the modified rules and apply them to the query
        $query = $qbp->parse($Rules, $table);    
           
        // Execute the query and get results
        $rows = $query->get();
        return $rows;
    }

    /**
     * Setup the tenant database connection.
     */
    private static function setupTenantConnection($tenantSchema): void
    {
        config(['database.connections.tenant.database' =>$tenantSchema]);
        DB::purge('tenant');
        DB::reconnect('tenant');
        DB::setDefaultConnection('tenant');
    }

    /**
     * Process a initializeConnection.
     */
    public static function initializeConnection($tenantSchema)
    {
        // Call the private method internally
        self::setupTenantConnection($tenantSchema);
    }
    /**
     * Process a query rule and fetch corresponding data.
     */
    public static function processRule($ruleMethod, $businessId, $tenantSchema, $subCategoryId, $fromDate = null, $toDate = null)
{
    // Fetch the query rule based on the provided method
    $QueryRule = self::fetchQueryRule($ruleMethod);

    if (!$QueryRule) {
        return collect(); // Return an empty collection if no query rule is found
    }

    // Check if the rule has a custom query
    if (!empty($QueryRule->query) && $QueryRule->query !== '') {
        // Switch to the tenant's schema dynamically
        QueryHelper::initializeConnection($tenantSchema); // Set the connection to the tenant's database

        // Retrieve the query from the database
        $queryFromDb = $QueryRule->query;
        $fromDate = request('from_date');
		$toDate = request('to_date');
        // Check if the query contains placeholders for from_date and to_date
        $hasFromDate = strpos($queryFromDb, ':from_date') !== false;
        $hasToDate = strpos($queryFromDb, ':to_date') !== false;

        // Build the parameters array dynamically
        $params = [];
        if ($hasFromDate && $fromDate) {
            $params['from_date'] = $fromDate; // Use the provided from_date
        }
        if ($hasToDate && $toDate) {
            $params['to_date'] = $toDate; // Use the provided to_date
        }

        // Execute the query with or without parameters
        return empty($params) ? DB::select($queryFromDb) : DB::select($queryFromDb, $params);
    }

    // Prepare the rules and extract the allowed fields
    $rules = self::prepareRules($QueryRule->rule, $businessId, $subCategoryId);
  
    $allowedFields = self::extractAllowedFields($rules);
  
    // Check the target and fetch data accordingly
    if ($QueryRule->target === 'Tenant') {
        return self::fetchFromTenantDB($QueryRule->source_name, $allowedFields, $rules, $QueryRule->selected_columns, $tenantSchema);
    }

    // If it's not a Tenant target, fetch from the default database
    return self::fetchFromDefaultDB($QueryRule->source_name, $allowedFields, $rules, $QueryRule->selected_columns);
}


    /**
     * Fetch the query rule details from the database.
     */
    private static function fetchQueryRule($methodName)
    {
        return DB::connection('master_db')->table('query_builder')
            ->where('method_name', $methodName)
            ->where('status', 1)
            ->first();
    }

    /**
     * Prepare rules by replacing placeholders with actual data.
     */
    private static function prepareRules($rules,$businessId,$subCategoryId)
    {

    // If subCategoryId is not null, replace $sID with the subCategoryId
    if (!is_null($subCategoryId)) {
        $rules = str_replace('$bID', $businessId, $rules);
        $rules = str_replace('$sID', $subCategoryId, $rules);
    }else{
    	$rules = str_replace('$bID', $businessId, $rules);
      $rules = json_decode($rules, true); // Decode the JSON string into an array

      // Loop through the rules and remove the one with the id 'sub_category_id'
      foreach ($rules['rules'] as $key => $rule) {
          if ($rule['id'] === 'sub_category_id') {
              unset($rules['rules'][$key]);  // Remove the rule with id 'sub_category_id'
          }
      }
	   // Re-index the array to avoid gaps in the indices after removal
      $rules['rules'] = array_values($rules['rules']);

      // Encode it back into JSON if you need the result as JSON
      $rules = json_encode($rules);
          }
            //dd($rules);
          return $rules;
    }

    /**
     * Extract allowed fields from rules.
     */
    private static function extractAllowedFields($rules)
    {
        // Decode the JSON string into an associative array
        $rulesArray = json_decode($rules, true);
    
        // Initialize an empty array to hold the field names
        $fields = [];
    
        // Recursive function to extract fields from both top-level and nested rules
        $extractFields = function($rules) use (&$fields, &$extractFields) {
            foreach ($rules as $rule) {
                // If a 'field' exists, add it to the fields array
                if (isset($rule['field'])) {
                    $fields[] = $rule['field'];
                }
    
                // If the rule has nested 'rules', recursively process them
                if (isset($rule['rules']) && is_array($rule['rules'])) {
                    $extractFields($rule['rules']);
                }
            }
        };
    
        // Call the recursive function on the top-level rules
        $extractFields($rulesArray['rules'] ?? []);
    
        // Remove duplicates and return the list of allowed fields
        return array_unique($fields);
    }
    
  /**
     * Check if a table exists in the given database connection.
     */
    private static function tableExists($connection, $tableName)
    {
        return Schema::connection($connection)->hasTable($tableName);
    }

    /**
     * Fetch data from the tenant's database.
     */
    private static function fetchFromTenantDB($table, $allowedFields, $rules, $selected_columns, $tenantSchema)
    {
        self::setupTenantConnection($tenantSchema);
    
        if (!self::tableExists('tenant', $table)) {
            Log::error("Table '{$table}' does not exist in tenant schema '{$tenantSchema}'");
            return [];
        }
    
        try {
            $query = DB::connection('tenant')->table($table)->select($selected_columns ? $selected_columns : '*');
            $parser = new QueryBuilderParser($allowedFields);
    
            return $parser->parse($rules, $query)->get()->toArray();
        } catch (\Exception $e) {
            Log::error($e);
            return [];
        }
    }

    /**
     * Fetch data from the default database.
     */
    private static function fetchFromDefaultDB($table, $allowedFields, $rules, $selected_columns)
    {
        
        if (!self::tableExists('master_db', $table)) {
            Log::error("Table '{$table}' does not exist in master_db");
            return [];
        }
    
        try {
            $query = DB::connection('master_db')->table($table)->select($selected_columns ? explode(',', $selected_columns) : '*');
          
            $parser = new QueryBuilderParser($allowedFields);
            $rows = $parser->parse($rules, $query)->get()->toArray();
    
            if ($selected_columns == 'product_category,service') {
                return self::formatRows($rows);
            }
    
            return $rows;
        } catch (\Exception $e) {
            Log::error($e);
            return [];
        }
    }



    /**
     * Format rows to handle different data structures.
     */
private static function formatRows($rows)
    {
        $output = []; 
        foreach ($rows as $row) {
            if (!empty($row->product_category)) {
                $output[] = ['value' => $row->product_category];
            } elseif (!empty($row->service)) {
                $output[] = ['value' => $row->service];
            }
        }

        return $output;
    }
private static function extractFieldsFromRules($rules)
{
    $fields = [];
// dd($rules);
    // Iterate over each rule in the rules array
    if(isset($rules['rules'])){
      
        foreach ($rules['rules'] as $rule) {
            // Check if the rule has a 'field' key
        if(isset($rule['rules'])){
            foreach ($rule['rules'] as $rule) {
                if (isset($rule['field'])) {
                    // If it has a 'field', add it to the fields array
                    $fields[] = $rule['field'];
                }
                // If the rule has a 'rules' key, this indicates a nested condition (e.g., 'AND' or 'OR')
                if (isset($rule['rules']) && is_array($rule['rules'])) {
                    // Recursively process the nested rules
                    $fields = array_merge($fields, self::extractFieldsFromRules($rule['rules']));
                }
    
            }
        }
            if (isset($rule['field'])) {
                // If it has a 'field', add it to the fields array
                $fields[] = $rule['field'];
            }
           
            // If the rule has a 'rules' key, this indicates a nested condition (e.g., 'AND' or 'OR')
            if (isset($rule['rules']) && is_array($rule['rules'])) {
                // Recursively process the nested rules
                $fields = array_merge($fields, self::extractFieldsFromRules($rule['rules']));
            }

        }
    }
 
    return $fields;
}

public static function replaceNullWithNA($data)
    {
        foreach ($data as $key => $value) {
            if (is_array($value)) {
                $data[$key] = self::replaceNullWithNA($value); // Recursion if it's an array
            } else {
                if (is_null($value) || $value === '') {
                    $data[$key] = 'N/A'; // Replace null or empty with 'N/A'
                }
            }
        }
        return $data;
    }

public static function createGetMostLiklyList()
{
    $mostlikely = "
        DROP PROCEDURE IF EXISTS `getMostLiklyList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getMostLiklyList`(
            IN from_date DATE,
            IN to_date DATE
        )
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
              -- Start building the SELECT query
              SET @query = 'SELECT DISTINCT bh.customer_id, bh.current_status';

              -- Variable to track if any columns exist
              SET @columns_exist = FALSE;

              -- Check and add columns dynamically
              IF EXISTS (
                  SELECT 1 
                  FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'business_history' 
                  AND COLUMN_NAME = 'hold_till' 
                  AND TABLE_SCHEMA = DATABASE()
              ) THEN
                  SET @query = CONCAT(@query, ', bh.hold_till');
                  SET @columns_exist = TRUE;
              END IF;

              IF EXISTS (
                  SELECT 1 
                  FROM INFORMATION_SCHEMA.COLUMNS 
                  WHERE TABLE_NAME = 'business_history' 
                  AND COLUMN_NAME = 'tentative_revisit' 
                  AND TABLE_SCHEMA = DATABASE()
              ) THEN
                  SET @query = CONCAT(@query, ', bh.tentative_revisit');
                  SET @columns_exist = TRUE;
              END IF;

              -- Check if no relevant columns exist
              IF @columns_exist = FALSE THEN
                  -- No columns to include, return an empty result set
                  SET @query = 'SELECT NULL AS customer_id, NULL AS current_status, NULL AS hold_till, NULL AS tentative_revisit WHERE FALSE';
              ELSE
                  -- Add the FROM clause
                  SET @query = CONCAT(@query, ' FROM business_history bh WHERE bh.is_deleted = 0');

                  -- Add conditions dynamically
                  SET @condition = '';

                  -- Adjust from_date and to_date with ±2 days
                  IF from_date IS NOT NULL AND to_date IS NOT NULL THEN
                      SET @adjusted_from_date = DATE_SUB(from_date, INTERVAL 2 DAY);
                      SET @adjusted_to_date = DATE_ADD(to_date, INTERVAL 2 DAY);
                  ELSE
                      SET @adjusted_from_date = DATE_SUB(CURRENT_DATE, INTERVAL 2 DAY);
                      SET @adjusted_to_date = DATE_ADD(CURRENT_DATE, INTERVAL 2 DAY);
                  END IF;

                  -- Check if `hold_till` exists before adding the condition
                  IF EXISTS (
                      SELECT 1
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME = 'business_history'
                      AND COLUMN_NAME = 'hold_till'
                      AND TABLE_SCHEMA = DATABASE()
                  ) THEN
                      SET @condition = CONCAT(@condition, ' DATE(bh.hold_till) BETWEEN ''', @adjusted_from_date, ''' AND ''', @adjusted_to_date, '''');
                  END IF;

                  -- Check if `tentative_revisit` exists before adding the condition
                  IF EXISTS (
                      SELECT 1
                      FROM INFORMATION_SCHEMA.COLUMNS
                      WHERE TABLE_NAME = 'business_history'
                      AND COLUMN_NAME = 'tentative_revisit'
                      AND TABLE_SCHEMA = DATABASE()
                  ) THEN
                      SET @condition = CONCAT(@condition, 
                          IF(@condition != '', ' OR ', ''), 
                          ' DATE(bh.tentative_revisit) BETWEEN ''', @adjusted_from_date, ''' AND ''', @adjusted_to_date, ''''
                      );
                  END IF;

                  -- If there is any condition, wrap it in parentheses and append it
                  IF @condition != '' THEN
                      SET @query = CONCAT(@query, ' AND (', @condition, ')');
                  END IF;

                  -- Add the condition for `current_status`
                  SET @query = CONCAT(@query, ' AND bh.current_status IN (''Hold'', ''Service/ProductPurchased'')');
              END IF;

              -- Execute the dynamically constructed query
              PREPARE stmt FROM @query;
              EXECUTE stmt;
              DEALLOCATE PREPARE stmt;
          END;

    ";

    return $mostlikely;
}
  
public static function createStatusNotUpdated()
{
    $statusNotUpdated = "
        DROP PROCEDURE IF EXISTS `getStatusNotUpdatedList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getStatusNotUpdatedList`(
            IN `from_date` DATE, 
            IN `to_date` DATE
        ) 
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
          -- Declare variables
          DECLARE business_history_exists INT DEFAULT 0;
          DECLARE sql_query TEXT;

          -- Check if `business_history` table exists
          SET business_history_exists = (SELECT COUNT(*)
                                         FROM information_schema.tables
                                         WHERE table_schema = DATABASE()
                                         AND table_name = 'business_history');

          -- Start building the query
          IF business_history_exists = 1 THEN
              -- If `business_history` exists, apply the full logic
              SET sql_query = 'SELECT DISTINCT bh.customer_id
                               FROM business_history bh
                               INNER JOIN (
                                   SELECT ch.customer_id, MAX(ch.timestamp) AS latest_call
                                   FROM call_history ch
                                   WHERE ch.duration > 0
                                   AND DATE(ch.timestamp) BETWEEN '''; 

              -- Add date range dynamically
              SET sql_query = CONCAT(sql_query, from_date, ''' AND ''', to_date, ''' 
                                   GROUP BY ch.customer_id
                               ) latest_calls
                               ON bh.customer_id = latest_calls.customer_id
                               WHERE bh.current_status IN (''Hold'', ''Schedule'', ''Followup'')');

              -- Check if created_at or updated_at is greater than latest call timestamp
              SET sql_query = CONCAT(sql_query, ' AND NOT EXISTS (
                                                    SELECT 1
                                                    FROM business_history bh2
                                                    WHERE bh2.customer_id = bh.customer_id
                                                    AND (
                                                        bh2.created_at > latest_calls.latest_call
                                                        OR bh2.updated_at > latest_calls.latest_call
                                                    )
                                                    AND (DATE(bh2.created_at) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                    OR DATE(bh2.updated_at) BETWEEN ''', from_date, ''' AND ''', to_date, ''')
                                                  )');

              -- Now, also check for customers with `group` as `Leads` or `Customer`
              SET sql_query = CONCAT(sql_query, ' UNION 
                                                  SELECT DISTINCT c.id AS customer_id
                                                  FROM call_history ch
                                                  INNER JOIN customers c ON ch.customer_id = c.id
                                                  WHERE ch.duration > 0
                                                  AND c.group IN (''Leads'', ''Customer'')
                                                  AND DATE(ch.timestamp) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                  AND NOT EXISTS (
                                                      SELECT 1
                                                      FROM business_history bh3
                                                      WHERE bh3.customer_id = c.id
                                                      AND (
                                                          bh3.created_at > ch.timestamp
                                                          OR bh3.updated_at > ch.timestamp
                                                      )
                                                      AND (DATE(bh3.created_at) BETWEEN ''', from_date, ''' AND ''', to_date, '''
                                                      OR DATE(bh3.updated_at) BETWEEN ''', from_date, ''' AND ''', to_date, ''')
                                                  )');
          ELSE
              -- If `business_history` does not exist, fetch only from `call_history` and `customers`
              SET sql_query = 'SELECT DISTINCT c.id AS customer_id
                               FROM call_history ch
                               INNER JOIN customers c ON ch.customer_id = c.id
                               WHERE ch.duration > 0
                               AND c.group IN (''Leads'', ''Customer'')
                               AND DATE(ch.timestamp) BETWEEN '''; 

              -- Add date range dynamically
              SET sql_query = CONCAT(sql_query, from_date, ''' AND ''', to_date, '''');
          END IF;

          -- Prepare and execute the query
          PREPARE dynamic_query FROM sql_query;
          EXECUTE dynamic_query;
          DEALLOCATE PREPARE dynamic_query;
      END;
    ";

    return $statusNotUpdated;
}

public static function createGetCustomerList()
{
    $getCustomerList = "
        DROP PROCEDURE IF EXISTS `getCustomerList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getCustomerList`()
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
              -- Start building the SELECT query
              SET @query = 'SELECT DISTINCT c.id AS customer_id';

              -- Check if business_history table exists
              SET @business_history_exists = (
                  SELECT COUNT(*)
                  FROM INFORMATION_SCHEMA.TABLES
                  WHERE TABLE_NAME = 'business_history' 
                  AND TABLE_SCHEMA = DATABASE()
              );

              -- If business_history exists, join with it
              IF @business_history_exists > 0 THEN
                  -- If the table exists, the query should select from both tables
                  SET @query = CONCAT(@query, ' FROM customers c');
                  SET @query = CONCAT(@query, ' LEFT JOIN business_history bh ON bh.customer_id = c.id');
                  SET @query = CONCAT(@query, ' WHERE (bh.current_status = ''Service/ProductPurchased'' OR c.`group` = ''Customer'')');
              ELSE
                  -- If business_history does not exist, select only from customers
                  SET @query = CONCAT(@query, ' FROM customers c');
                  SET @query = CONCAT(@query, ' WHERE c.`group` = ''Customer''');
              END IF;

              -- Finalize the query
              SET @query = CONCAT(@query, ' ORDER BY c.id');

              -- Debug: Output the query for debugging purposes (in production, this can be removed)
              -- SELECT @query; -- Uncomment for debugging the query

              -- Execute the dynamically constructed query
              PREPARE stmt FROM @query;
              EXECUTE stmt;
              DEALLOCATE PREPARE stmt;
          END;
    ";

    return $getCustomerList;
}
  
public static function createGetLeadsList()
{
    $getLeadsList = "
        DROP PROCEDURE IF EXISTS `getLeadsList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getLeadsList`(
            IN from_date DATE,
            IN to_date DATE
        )
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
            -- Initialize query parts
            SET @query1 = NULL;
            SET @query2 = NULL;
            SET @date_conditions = '';

            -- Check if business_history table exists
            SET @business_history_exists = (
                SELECT COUNT(*)
                FROM INFORMATION_SCHEMA.TABLES
                WHERE TABLE_NAME = 'business_history'
                AND TABLE_SCHEMA = DATABASE()
            );

            -- Query to get customers from business_history within date range
            IF @business_history_exists > 0 THEN
                -- Start constructing query1
                SET @query1 = 'SELECT DISTINCT bh.customer_id FROM business_history bh WHERE ';

                -- Check and add date range conditions dynamically
                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'hold_till'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.hold_till) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'schedule_on'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.schedule_on) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                IF EXISTS (
                    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS 
                    WHERE TABLE_SCHEMA = DATABASE() 
                    AND TABLE_NAME = 'business_history' 
                    AND COLUMN_NAME = 'follow_up_on'
                ) THEN
                    SET @date_conditions = CONCAT(@date_conditions, ' DATE(bh.follow_up_on) BETWEEN ''', from_date, ''' AND ''', to_date, ''' OR');
                END IF;

                -- Remove trailing OR and finalize query1
                IF LENGTH(@date_conditions) > 0 THEN
                    SET @date_conditions = LEFT(@date_conditions, LENGTH(@date_conditions) - 3);
                    SET @query1 = CONCAT(@query1, @date_conditions);
                ELSE
                    -- If no valid date columns exist, do not use business_history query
                    SET @query1 = NULL;
                END IF;
            END IF;

            -- Query to get customers from customers table where group = 'Leads'
            SET @query2 = 'SELECT DISTINCT c.id AS customer_id FROM customers c WHERE c.`group` = ''Leads''';

            -- Final query: Combine both queries with UNION to get distinct customer_id
            SET @final_query = '';

            IF @query1 IS NOT NULL THEN
                SET @final_query = CONCAT('(', @query1, ') UNION ALL (', @query2, ')');
            ELSE
                SET @final_query = @query2; -- If business_history does not exist or no valid date columns exist, use only customers query
            END IF;

            -- Finalizing with DISTINCT to remove duplicates
            SET @final_query = CONCAT('SELECT DISTINCT customer_id FROM (', @final_query, ') AS combined_result ORDER BY customer_id');

            -- Debug: Uncomment to check query output
            -- SELECT @final_query;

            -- Execute the dynamically constructed query
            PREPARE stmt FROM @final_query;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        END;
    ";

    return $getLeadsList;
}
  
public static function createGetScheduleList()
{
    $getScheduleList = "
        DROP PROCEDURE IF EXISTS `getScheduleList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getScheduleList`(
            IN from_date DATE,
            IN to_date DATE
        )
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
          SELECT DISTINCT a1.customer_id
          FROM appointment a1
          WHERE a1.is_deleted = 0
            AND (
              -- Apply date range filter if provided
              (
                from_date IS NOT NULL AND to_date IS NOT NULL 
                AND DATE(STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')) 
                    BETWEEN STR_TO_DATE(from_date, '%Y-%m-%d') 
                    AND STR_TO_DATE(to_date, '%Y-%m-%d')
              )
              OR 
              -- If no date range is provided, default to today
              (
                (from_date IS NULL OR from_date = '') 
                AND (to_date IS NULL OR to_date = '') 
                AND DATE(STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')) = CURDATE()
              )
            )
            AND NOT EXISTS (
              SELECT 1
              FROM appointment a2
              WHERE a2.customer_id = a1.customer_id
                AND STR_TO_DATE(a2.date, '%Y-%m-%d %H:%i:%s') > STR_TO_DATE(a1.date, '%Y-%m-%d %H:%i:%s')
                AND a2.is_deleted = 0
            );
      END;
    ";

    return $getScheduleList;
}  

  public static function createGetFollowUpList()
{
    $getFollowUpList = "
        DROP PROCEDURE IF EXISTS `getFollowUpList`;
        CREATE DEFINER=`root`@`localhost` PROCEDURE `getFollowUpList`(
            IN from_date DATE,
            IN to_date DATE
        )
        NOT DETERMINISTIC 
        CONTAINS SQL 
        SQL SECURITY DEFINER 
        BEGIN
        DECLARE column_exists BOOLEAN DEFAULT FALSE;

        -- Check if the column `follow_up_on` exists in the table `business_history`
        SELECT COUNT(1) INTO column_exists
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = 'business_history'
          AND COLUMN_NAME = 'follow_up_on'
          AND TABLE_SCHEMA = DATABASE();

        -- If the column exists, proceed with the query
        IF column_exists THEN
            SET @query = CONCAT(
                'SELECT DISTINCT bh.customer_id
                 FROM business_history bh
                 WHERE bh.current_status = \"Followup\"
                   AND DATE(bh.follow_up_on) BETWEEN \"', from_date, '\" AND \"', to_date, '\"
                   AND NOT EXISTS (
                       SELECT 1
                       FROM business_history bh_future
                       WHERE bh_future.customer_id = bh.customer_id
                         AND DATE(bh_future.follow_up_on) > \"', to_date, '\"
                   )'
            );

            -- Prepare and execute the dynamic query
            PREPARE stmt FROM @query;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;
        ELSE
            -- If the column doesn't exist, return an empty result set
            SELECT NULL WHERE FALSE;
        END IF;
    END;
    ";

    return $getFollowUpList;
}  
  
}










