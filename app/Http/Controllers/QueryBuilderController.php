<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
use App\Models\FormBuilder;
use App\Models\QueryBuilder;

class QueryBuilderController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
    }

    public function index()
    {
        $queries = QueryBuilder::where('is_deleted', 0)->get();
        return view('superadmin.query_builder', compact('queries'));
    }

    public function addQueryBuilder()
    {
        $tables = DB::select('SHOW TABLES');
        $tableNames = array_map(function($table) {
            return $table->{key($table)};
        }, $tables);

        $TenantTables = FormBuilder::where('status', 1)->where('is_deleted', 0)->get();

        $res = [
            'tableNames' => $tableNames,
            'TenantTables' => $TenantTables
        ];

        return view('superadmin.add-query-builder', compact('res'));
    }

    public function getTableColumns(Request $request)
    {
        $table = $request->input('table');
        $target = $request->input('target');

        if ($target === 'Master') {
            $columns = DB::getSchemaBuilder()->getColumnListing($table);
        } elseif ($target === 'Tenant') {
            $JsonColList = FormBuilder::select('form')->where('name', $table)->where('status', 1)->where('is_deleted', 0)->pluck('form')->first();
            $columns = collect(json_decode($JsonColList))->pluck('name')->all();
            $StanderdCol = ['status', 'created_at', 'updated_at', 'is_deleted'];
            $columns = array_merge($columns, $StanderdCol);
        } else {
            return response()->json(['error' => 'Source not found'], 400);
        }

        return response()->json(['columns' => $columns]);
    }

    public function store(Request $request)
    {
      //  dd('tgbhnjmk,');
        // Validate request
        // $request->validate([
        //     'source_name' => 'required|string',
        //     'method_name' => 'required|string',
        //     'rules' => 'required|string',
        //     'selected_columns' => 'nullable|array', // Validate as an array if present
        //     'target' => 'nullable|string',
        // ]);
        // Convert selected_columns to a comma-separated string if it exists
        $selectedColumns = isset($request->selected_columns) && is_array($request->selected_columns)
            ? implode(',', $request->selected_columns)
            : null;
        // Save the query to the database
        DB::table('query_builder')->insert([
            'business_id' => null,  // Optional field
            'source_name' => $request->source_name,
            'method_name' => $request->method_name,
            'target' => $request->target,
            'selected_columns' => $selectedColumns, // Save as a comma-separated string
            'rule' => $request->rules,  // JSON-encoded rules
            'status' => 1,
            'is_deleted' => 0,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        
        return view ('superadmin.add-query-builder', compact('res'))->with('success', 'Query saved successfully.');
    }


    public function activate($id)
    {
        QueryBuilder::where('id', $id)->update(['status' => 1]);
        return redirect()->route('query_builder')->with('success', 'Query activated successfully.');
    }

    public function deactivate($id)
    {
        QueryBuilder::where('id', $id)->update(['status' => 0]);
        return redirect()->route('query_builder')->with('success', 'Query deactivated successfully.');
    }

    public function delete($id)
    {
        QueryBuilder::where('id', $id)->update(['status' => 0, 'is_deleted' => 1]);
        return redirect()->route('query_builder')->with('success', 'Query deleted successfully.');
    }

    public function edit($id)
    {
         // Fetch the query with the given ID
    $query = QueryBuilder::findOrFail($id);

    // Fetch tables for dropdowns
    $tables = DB::select('SHOW TABLES');
    $tableNames = array_map(function($table) {
        return $table->{key($table)};
    }, $tables);
    $TenantTables = FormBuilder::where('status', 1)->where('is_deleted', 0)->get();

    $res = [
        'tableNames' => $tableNames,
        'TenantTables' => $TenantTables
    ];

        return view('superadmin.edit_query_builder', compact('query', 'res'));
    }

    public function update(Request $request, $id)
    {
        $request->validate([
            'source_name' => 'required|string',
            'method_name' => 'required|string',
            'rule' => 'required|string',
        ]);

        QueryBuilder::where('id', $id)->update([
            'source_name' => $request->source_name,
            'target' => $request->target,
            'method_name' => $request->method_name,
            'rule' => $request->rule,
            'updated_at' => now(),
        ]);

        return redirect()->route('query_builder')->with('success', 'Query updated successfully.');
    }
}
