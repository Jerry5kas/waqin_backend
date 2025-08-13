<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;
use Exception;

class EntFormBuilderController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth');
    }

    public function entFormBuilder(Request $request)
    {
        $data['forms'] = DB::table('ent_form_builder')->get();

        foreach ($data['forms'] as $key => $value) {
            $businessIds = explode(',', $value->bussiness_ids);
            $businessNames = DB::table('business_categories')
                ->select('name')
                ->whereIn('id', $businessIds)
                ->pluck('name')
                ->toArray();

            $data['forms'][$key]->BussinessName = implode(',', $businessNames);
        }

        return view('superadmin.ent_form_builder.index')->with(['result' => $data]);
    }

    public function addEntFormBuilder()
    {
        $data['bussiness'] = DB::table('business_categories')->get();

        $data['rules'] = DB::table('query_builder')
            ->where('status', 1)
            ->pluck('method_name')
            ->toArray();

        return view('superadmin.ent_form_builder.add')->with(['result' => $data]);
    }

    public function editEntForm(Request $request)
    {
        $input = $request->input('frm');
        $formId = base64_decode($input);

        $bids = DB::table('ent_form_builder')->pluck('bussiness_ids')->toArray();
        $business_ids = [];
        foreach ($bids as $ids) {
            $business_ids = array_merge($business_ids, explode(',', $ids));
        }
        $business_ids = array_unique($business_ids);

        $form_data = DB::table('ent_form_builder')->where('id', $formId)->first();

        $form_business_ids = explode(',', $form_data->bussiness_ids);
        $business_categories = DB::table('business_categories')->where('status',1)->where('is_deleted',0)->get();

        $rules = DB::table('query_builder')
            ->where('status', 1)
            ->pluck('method_name')
            ->toArray();

        return view('superadmin.ent_form_builder.edit')->with([
            'result' => [
                'bussiness' => $business_categories,
                'FrmData' => $form_data,
                'rules' => $rules,
            ],
            'form_business_ids' => $form_business_ids,
        ]);
    }

    public function saveEntFormBuilder(Request $request)
    {
        try {
            $input = $request->input();
            $data['name'] = $input['FormName'];
            $data['bussiness_ids'] = implode(',', $input['Bussiness']);
            $data['form'] = $input['FormData'];
            $data['status_master'] = $input['status_master'];

            DB::table('ent_form_builder')->insert($data);

            return response()->json([
                'success' => true,
                'msg' => 'ENT Form Added Successfully',
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'msg' => $e->getMessage(),
            ]);
        }
    }

    public function updateEntFormBuilder(Request $request)
    {
        try {
            $input = $request->input();
            $data['name'] = $input['FormName'];
            $data['bussiness_ids'] = implode(',', $input['Business']);
            $data['form'] = $input['FormData'];

            DB::table('ent_form_builder')->where('id', $input['id'])->update($data);

            return response()->json([
                'success' => true,
                'msg' => 'ENT Form Updated Successfully',
            ]);
        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'msg' => $e->getMessage(),
            ]);
        }
    }

    public function activate($id)
    {
        try {
            DB::table('ent_form_builder')->where('id', $id)->update(['status' => 1]);
            return redirect()->back()->with('success', 'ENT Form activated successfully.');
        } catch (Exception $e) {
            return redirect()->back()->with('error', 'Failed to activate: ' . $e->getMessage());
        }
    }

    public function deactivate($id)
    {
        try {
            DB::table('ent_form_builder')->where('id', $id)->update(['status' => 0]);
            return redirect()->back()->with('success', 'ENT Form deactivated successfully.');
        } catch (Exception $e) {
            return redirect()->back()->with('error', 'Failed to deactivate: ' . $e->getMessage());
        }
    }
}
