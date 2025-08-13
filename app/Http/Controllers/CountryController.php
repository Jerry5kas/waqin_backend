<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Country;

class CountryController extends Controller
{
    public function index()
    {
        $countries = Country::orderBy('id', 'desc')->get();
        return view('superadmin.countries', compact('countries'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'country_code' => 'required|string|max:255',
            'country_name' => 'required|string|max:255',
            'time_zone' => 'required|string|max:255',
            'standard_time_zone' => 'required|string|max:255',
        ]);

        Country::create($request->all());
        return redirect()->back()->with('success', 'Country added successfully');
    }

    public function update(Request $request, $id)
    {
        $country = Country::findOrFail($id);
        $country->update($request->all());
        return response()->json(['success' => 'Country updated successfully.']);
    }

    public function destroy($id)
    {
        $country = Country::findOrFail($id);
        $country->delete();
        return redirect()->route('countries')->with('success', 'Country deleted successfully.');
    }

    public function deactivate($id)
    {
        $country = Country::findOrFail($id);
        $country->status = 0;
        $country->save();
        return redirect()->route('countries')->with('success', 'Country deactivated successfully.');
    }

    public function activate($id)
    {
        $country = Country::findOrFail($id);
        $country->status = 1;
        $country->save();
        return redirect()->route('countries')->with('success', 'Country activated successfully.');
    }

    public function getCountry()
    {
        try {
            $countries = Country::where('status', 1)->get();

            return response()->json([
                'success' => true,
                'countries' => $countries
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Something went wrong'
            ], 500);
        }
    }
}
