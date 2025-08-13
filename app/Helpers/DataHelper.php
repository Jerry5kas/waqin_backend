<?php

namespace App\Helpers;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Log;

class DataHelper
{
    public static function enrichCustomersWithEmpDetails(array &$results, $empIdFilter = null, $isFilter = 0)
{
    // Extract all customer_ids from the nested $results
    $customerIds = [];
    foreach ($results as $group) {
        foreach ($group as $category => $customers) {
            foreach ($customers as $customer) {
                $customerIds[] = $customer->customer_id;
            }
        }
    }

    if (empty($customerIds)) {
        return;
    }

    // Fetch emp_id for all customer_ids
    $empMappings = DB::table('customers')
        ->whereIn('id', $customerIds)
        ->pluck('emp_id', 'id') // Creates [customer_id => emp_id]
        ->toArray();

    $empNames = [];

    // Check if the employees table exists before querying
    if (Schema::hasTable('employees')) {
        $empNames = DB::table('employees')
            ->whereIn('id', array_values($empMappings))
            ->pluck('full_name', 'id') // Creates [emp_id => full_name]
            ->toArray();
    }

    // If is_filter=0 and empIdFilter is provided, sort results to show related emp_id data first
    if ($isFilter == 0 && $empIdFilter !== null) {
        foreach ($results as &$group) {
            foreach ($group as &$categoryData) {
                usort($categoryData, function ($a, $b) use ($empMappings, $empIdFilter) {
                    $aEmpId = $empMappings[$a->customer_id] ?? null;
                    $bEmpId = $empMappings[$b->customer_id] ?? null;

                    // Move matching emp_id customers to the top
                    if ($aEmpId == $empIdFilter && $bEmpId != $empIdFilter) {
                        return -1;
                    } elseif ($aEmpId != $empIdFilter && $bEmpId == $empIdFilter) {
                        return 1;
                    }
                    return 0;
                });
            }
        }
    }

    // If emp_id is provided in payload and is_filter=1, filter customers to show only related emp_id
    if ($isFilter == 1 && $empIdFilter !== null) {
        foreach ($results as &$group) {
            foreach ($group as &$categoryData) {
                $categoryData = array_filter($categoryData, function ($customer) use ($empMappings, $empIdFilter) {
                    return ($empMappings[$customer->customer_id] ?? null) == $empIdFilter;
                });

                // Reset array keys after filtering
                $categoryData = array_values($categoryData);
            }
        }
    }

    // Add is_assigned and emp_name to each customer
    foreach ($results as &$group) {
        foreach ($group as &$categoryData) {
            foreach ($categoryData as &$customer) {
                $customerEmpId = $empMappings[$customer->customer_id] ?? null;
                $customer->emp_id = $customerEmpId;
                $customer->emp_name = $customerEmpId ? ($empNames[$customerEmpId] ?? null) : null;
            }
        }
    }
}

}
