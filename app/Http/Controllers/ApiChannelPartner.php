<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\SyncRequest;
use Illuminate\Support\Facades\DB;

class ApiChannelPartner extends Controller
{
    public function index()
    {
        $cplist = DB::table('channel_partners')->select('full_name','mobile','location')->where('is_deleted', 0)->get();

        return response()->json([
            'status' => 'success',
            'data' => $cplist
        ]);
    }
}

