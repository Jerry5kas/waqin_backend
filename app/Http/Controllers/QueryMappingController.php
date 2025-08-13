<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ContactGroup;
use App\Models\QueryBuilder;
use App\Models\QueryMapping;

class QueryMappingController extends Controller
{
    public function index()
{
    $queryMappings = QueryMapping::where('is_deleted', 0)->orderBy('created_at', 'desc')->get();
    $contactGroups = ContactGroup::all(); // Fetch all contact groups
    $methodNames = QueryBuilder::all(); // Fetch all query builder methods

    return view('superadmin.query_mapping', compact('queryMappings', 'contactGroups', 'methodNames'));
}

public function store(Request $request)
{
    $request->validate([
        'group_name' => 'required|string|max:250',
        'method_name' => 'required|string|max:250',
    ]);

    QueryMapping::create([
        'group_name' => $request->group_name,
        'method_name' => $request->method_name,
        'status' => 1, // Default status
        'is_deleted' => 0, // Default value for non-deleted records
    ]);

    return redirect()->route('query_mapping')->with('success', 'Query mapping created successfully!');
}

public function activate($id)
   {
       try {
           $queryMappings = QueryMapping::findOrFail($id);
           $queryMappings->status = 1;
           $queryMappings->save();

           return redirect()->back()->with('success', 'Query Mapping activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Query Mapping.');
       }
   }

   public function deactivate($id)
   {
       try {
        $queryMappings = QueryMapping::findOrFail($id);
        $queryMappings->status = 0;
        $queryMappings->save();

           return redirect()->back()->with('success', 'Query Mapping deactivated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to deactivate Query Mapping.');
       }
   }

   public function destroy($id)
   {
        try {
            $queryMappings = QueryMapping::findOrFail($id);
            $queryMappings->is_deleted = 1;
            $queryMappings->save();
    
            return redirect()->back()->with('success', 'Query Mapping Deleted successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to Deleting Query Mapping.');
        }
   }

   public function edit($id)
    {
        $queryMapping = QueryMapping::findOrFail($id);
        return response()->json($queryMapping);
    }

    public function update(Request $request, $id)
{
    $validated = $request->validate([
        'group_name' => 'required|string',
        'method_name' => 'required|string',
    ]);

    $queryMapping = QueryMapping::findOrFail($id);
    $queryMapping->group_name = $validated['group_name'];
    $queryMapping->method_name = $validated['method_name'];
    $queryMapping->save();

    return redirect()->route('query_mapping')->with('success', 'Query Mapping updated successfully.');
}


}
