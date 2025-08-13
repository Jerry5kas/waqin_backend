<?php

namespace App\Http\Controllers\Api;

use App\Models\Customer;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CustomerController extends Controller
{
    /**
     * Store a newly created resource in storage.
     */
    public function store(Request $request)
    {
        // Check if the 'customers' table exists
        if (!Schema::hasTable('customers')) {
            // Create the 'customers' table if it doesn't exist
            DB::statement("
                CREATE TABLE customers (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255),
                    email VARCHAR(255) UNIQUE,
                    mobile VARCHAR(15),
                    another_mobile VARCHAR(15) NULL,
                    company VARCHAR(255) NULL,
                    gst VARCHAR(50) NULL,
                    profile_pic VARCHAR(255) NULL,
                    location VARCHAR(255) NULL,
                    dob DATE NULL,
                    status VARCHAR(50) DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    is_deleted TINYINT(1) DEFAULT 0
                )
            ");
        }

        // Validate the incoming request data
        // $validatedData = $request->validate([
        //     'name' => 'required|string|max:255',
        //     'email' => 'required|string|email|max:255|unique:customers',
        //     'mobile' => 'required|string|max:15',
        //     'another_mobile' => 'nullable|string|max:15',
        //     'company' => 'nullable|string|max:255',
        //     'gst' => 'nullable|string|max:50',
        //     'profile_pic' => 'nullable|string|max:255',
        //     'location' => 'nullable|string|max:255',
        //     'dob' => 'nullable|date',
        //     'status' => 'nullable|string|max:50',
        // ]);

        // Insert the validated data into the 'customers' table
        $customer = Customer::create([
            'name' => $request->input('name'),
            'email' => $request->input('email'),
            'mobile' => $request->input('mobile'),
            'another_mobile' => $request->input('another_mobile'),
            'company' => $request->input('company'),
            'gst' => $request->input('gst'),
            'profile_pic' => $request->input('profile_pic'),
            'location' => $request->input('location'),
            'dob' => $request->input('dob'),
            'status' => $request->input('status', 'active'), // default to 'active' if not provided
            'created_at' => now(),
            'updated_at' => now(),
            'is_deleted' => 0, // default to 0 (not deleted)
        ]);
        

        // Return a response
        return response()->json([
            'success' => true,
            'message' => 'Customer added successfully',
            'data' => $customer
        ], 201);
    }
}
