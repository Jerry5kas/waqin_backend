<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\City;
use App\Models\State;
use App\Models\Country;

class CityController extends Controller
{
    public function index()
    {
        $cities = City::with(['state', 'country'])->orderBy('id', 'desc')->get();
        $states = State::orderBy('state_name')->get();
        $countries = Country::orderBy('country_name')->get();
        return view('superadmin.cities', compact('cities', 'states', 'countries'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'city_name' => 'required|string|max:255',
            'state_id' => 'required|exists:states,id',
            'country_id' => 'required|exists:countries,id',
        ]);

        City::create($request->all());

        return redirect()->route('cities')->with('success', 'City added successfully.');
    }

    public function update(Request $request, $id)
    {
        $request->validate([
            'city_name' => 'required|string|max:255',
        ]);

        $city = City::findOrFail($id);
        $city->update($request->all());

        return response()->json(['success' => 'City updated successfully.']);
    }

    public function destroy($id)
    {
        $city = City::findOrFail($id);
        $city->delete();

        return redirect()->route('cities')->with('success', 'City deleted successfully.');
    }

    public function deactivate($id)
    {
        $city = City::findOrFail($id);
        $city->status = 0;
        $city->save();
        return redirect()->route('cities')->with('success', 'City deactivated successfully.');
    }

    public function activate($id)
    {
        $city = City::findOrFail($id);
        $city->status = 1;
        $city->save();
        return redirect()->route('cities')->with('success', 'City activated successfully.');
    }

    public function getCityByState(Request $request)
    {
        $request->validate([
            'state_id' => 'required|integer|exists:states,id'
        ]);

        try {
            $state_id = $request->input('state_id');
            $cities = City::where('state_id', $state_id)->where('status', 1)->get();

            if ($cities->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No cities found for the selected state'
                ], 404);
            }

            return response()->json([
                'success' => true,
                'cities' => $cities
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong'
            ], 500);
        }
    }
    
}

