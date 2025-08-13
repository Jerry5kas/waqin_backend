<?php

namespace App\Http\Controllers;

use GrahamCampbell\ResultType\Success;
use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
use App\Models\FormBuilder;
use Exception;


class FormBuilderController extends Controller
{
    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        $this->middleware('auth');
    }

    /**
     * Show the application dashboard.
     *
     * @return \Illuminate\Contracts\Support\Renderable
     */
    public function index()
    {
        return view('dashboard');
    }

    public function tenanciesList()
    {
        $tenancies = DB::table('tenants')->get();
        return view('superadmin.dashboard', compact('tenancies'));
    }

    public function businessCategories()
    {
        $businesscategories = DB::table('business_categories')->get();
        return view('superadmin.business-category', compact('businesscategories'));
    }

    public function subCategories()
    {
        $subcategories = DB::table('subcategory_services')->get();
        return view('superadmin.subcategory-services', compact('subcategories'));
    }

    public function countriesList()
    {
        $countries = DB::table('countries')->get();
        return view('superadmin.countries', compact('countries'));
    }

    public function statesList()
    {
        $states = DB::table('states')->get();
        return view('superadmin.states', compact('states'));
    }


    public function citiesList()
    {
        $cities = DB::table('cities')->get();
        return view('superadmin.cities', compact('cities'));
    }
    public function formbuilder(Request $request)
    {
        $data['forms'] = DB::table('form_builder')->get();
        foreach ($data['forms'] as $key => $value) {
            $Bussiness = explode(',', $value->bussiness_ids);
            $BussinessName = DB::table('business_categories')->select('name')->whereIn('id', $Bussiness)->pluck('name')->toArray();
            $data['forms'][$key]->BussinessName = implode(',', $BussinessName);
        }
        return view('superadmin.form-builder')->with(['result' => $data]);
    }

    public function addformbuilder()
    {
        $data['bussiness'] = DB::table('business_categories')->get(); // Fetch all businesses
    
        $data['rules'] = DB::table('query_builder')
            ->where('status', 1)
            ->pluck('method_name')
            ->toArray();
    
        return view('superadmin.add-form-builder')->with(['result' => $data]);
    }

    public function editfrm(Request $request)
    {
        $input = $request->input('frm');
        $Frm_id = base64_decode($input);
        $bids = DB::table('form_builder')->pluck('bussiness_ids')->toArray();
        $business_ids = [];
        foreach ($bids as $ids) {
            $business_ids = array_merge($business_ids, explode(',', $ids));
        }
        $business_ids = array_unique($business_ids);
       
        $form_data = DB::table('form_builder')->where('id', $Frm_id)->first();

        $form_business_ids = explode(',', $form_data->bussiness_ids);
        $business_categories = DB::table('business_categories')->where('status',1)->where('is_deleted',0)->get();
         $rules = DB::table('query_builder')
            ->where('status', 1)
            ->pluck('method_name')
            ->toArray();
        return view('superadmin.edit_formbuilder')->with([
            'result' => [
                'bussiness' => $business_categories,
                'FrmData' => $form_data,
                'rules' => $rules,
            ],
            'form_business_ids' => $form_business_ids,
        ]);
    }

    public function saveformbuilder(Request $request)
    {
        
        try {
            $input = $request->input();
            $data['name'] = $input['FormName'];
            $data['bussiness_ids'] = implode(',', $input['Bussiness']);
            $data['form'] = $input['FormData'];
            $data['status_master'] = $input['status_master'];
            DB::table('form_builder')->insert($data);
            $res['success'] = true;
            $res['msg'] = 'Form Added Successfully';
        } catch (Exception $exc) {
            $res['msg'] = $exc->getTraceAsString();
            $res['success'] = false;
        }
        return response()->json($res);
    }

    public function editformbuilder(Request $request)
    {
        try {
            $input = $request->input();
            $data['name'] = $input['FormName'];
            $data['bussiness_ids'] = implode(',', $input['Business']);
            $data['form'] = $input['FormData'];
            DB::table('form_builder')->where('id', $input['id'])->update($data);
            $res['success'] = true;
            $res['msg'] = 'Form Updated Successfully';
        } catch (Exception $exc) {
            $res['msg'] = $exc->getTraceAsString();
            $res['success'] = false;
        }
        return response()->json($res);
    }

    public function deleteMasterData(Request $request)
    {
        $input = $request->input();
        try {
            DB::table($input['tbl_name'])->where('id', $input['id'])->delete();
            $res['success'] = true;
            $res['msg'] = 'Deleted Succesfully';
        } catch (Exception $exc) {
            $res['msg'] = $exc->getTraceAsString();
            $res['success'] = false;
        }
        return response()->json($res);
    }

    public function activate($id)
    {
        try {
            $form_builder = FormBuilder::findOrFail($id);
            $form_builder->status = 1;
            $form_builder->save();

            return redirect()->back()->with('success', 'Form Builder activated successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to activate Form Builder: ' . $e->getMessage());
        }
    }


    public function deactivate($id)
    {
        try {
            $form_builder = FormBuilder::findOrFail($id);
            $form_builder->status = 0;
            $form_builder->save();

            return redirect()->back()->with('success', 'Form Builder deactivated successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to deactivate Form Builder: ' . $e->getMessage());
        }
    }


    public function activateForm(Request $request)
    {
        $input = $request->input();
        try {
            DB::table($input['tbl_name'])->where('id', $input['id'])->update(['status' => 1]);
            $res['success'] = true;
            $res['msg'] = 'Activated Successfully';
        } catch (Exception $exc) {
            $res['msg'] = $exc->getTraceAsString();
            $res['success'] = false;
        }
        return response()->json($res);
    }

    public function deactivateForm(Request $request)
    {
        $input = $request->input();
        try {
            DB::table($input['tbl_name'])->where('id', $input['id'])->update(['status' => 0]);
            $res['success'] = true;
            $res['msg'] = 'Deactivated Successfully';
        } catch (Exception $exc) {
            $res['msg'] = $exc->getTraceAsString();
            $res['success'] = false;
        }
        return response()->json($res);
    }

}
