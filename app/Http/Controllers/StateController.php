<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\State;
use App\Models\Country;

class StateController extends Controller
{
    
    public function index()
    {
        $states = State::with('country')->orderBy('created_at', 'desc')->get();
        $countries = Country::orderBy('country_name')->get();
        return view('superadmin.states', compact('states', 'countries'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'state_name' => 'required|string|max:255',
            'country_id' => 'required|exists:countries,id',
        ]);

        State::create($request->all());

        return redirect()->route('states')->with('success', 'State added successfully.');
    }

    public function update(Request $request, string $id)
    {
        $request->validate([
            'state_name' => 'required|string|max:255',
        ]);

        $state = State::findOrFail($id);
        $state->update($request->all());

        return response()->json(['success' => 'State updated successfully.']);
    }
    public function destroy(string $id)
    {
        $state = State::findOrFail($id);
        $state->delete();

        return redirect()->route('states')->with('success', 'State deleted successfully.');
    }

    public function deactivate($id)
    {
        $state = State::findOrFail($id);
        $state->status = 0;
        $state->save();
        return redirect()->route('states')->with('success', 'State deactivated successfully.');
    }

    public function activate($id)
    {
        $state = State::findOrFail($id);
        $state->status = 1;
        $state->save();
        return redirect()->route('states')->with('success', 'State activated successfully.');
    }

    public function getStatesBasedOnCountry($countryId)//for admin panel
    {
        $states = State::where('country_id', $countryId)->get();
        return response()->json($states);
    }

    public function getStateByCountry(Request $request)//for app
    {
        $request->validate([
            'country_id' => 'required|integer|exists:countries,id'
        ]);

        try {
            $country_id = $request->input('country_id');
            $states = State::where('country_id', $country_id)->where('status', 1)->get();

            if ($states->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No states found for the selected country'
                ], 404);
            }

            return response()->json([
                'success' => true,
                'states' => $states
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong'
            ], 500);
        }
    }
}
