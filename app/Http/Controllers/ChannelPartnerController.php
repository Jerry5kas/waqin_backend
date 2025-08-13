<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\ChannelPartner;
use App\Models\Referral;
use App\Models\Tenant;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;

class ChannelPartnerController extends Controller
{
    public function index()
{
    // For the listing table
    $partners = ChannelPartner::where('is_deleted', 0)
        ->where('status', 1)
        ->orderBy('created_at', 'desc')
        ->get();

    // For the dropdown (only strategic channel partners)
    $strategicPartners = ChannelPartner::where('is_strategic_cp', 1)
        ->where('is_deleted', 0)
        ->where('status', 1)
        ->get();

    return view('superadmin.channel_partner', compact('partners', 'strategicPartners'));
}

public function store(Request $request)
{
    $validator = Validator::make($request->all(), [
        'full_name' => 'required|string|max:255',
        'email' => 'required|email',
        'mobile' => 'required|string|max:15',
        'password' => 'required|string|min:4|max:4',
        'cp_id' => 'nullable|exists:channel_partners,id',
        'is_strategic_cp' => 'nullable|boolean',
    ]);

    if ($validator->fails()) {
        return redirect()->back()->withErrors($validator)->withInput();
    }

    $existingPartner = ChannelPartner::where('mobile', $request->mobile)->first();

    if ($existingPartner) {
        return redirect()->back()->with('info', 'Channel Partner already exists with this Mobile.');
    }

    // Always assign 'admin' to created_by
    $createdBy = 'admin';

    ChannelPartner::create([
        'full_name' => $request->full_name,
        'email' => $request->email,
        'mobile' => $request->mobile,
        'password' => Hash::make($request->password),
        'created_by' => $createdBy,
        'cp_id' => $request->cp_id ?? null,
        'is_strategic_cp' => $request->has('is_strategic_cp') ? 1 : 0,
    ]);

    return redirect()->back()->with('success', 'Channel Partner added successfully!');
}

    public function activate($id)
   {
       try {
           $partners = ChannelPartner::findOrFail($id);
           $partners->status = 1;
           $partners->save();

           return redirect()->back()->with('success', 'Channel Partner activated successfully.');
       } catch (\Exception $e) {
           return redirect()->back()->with('error', 'Failed to activate Channel Partner.');
       }
   }

   // Deactivate the business category
   public function deactivate($id)
   {
        try {
            $partners = ChannelPartner::findOrFail($id);
            $partners->status = 0;
            $partners->save();

            return redirect()->back()->with('success', 'Channel Partner deactivated successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to deactivate Channel Partner.');
        }
   }

   // Remove the specified resource from storage.
   public function destroy($id)
   {
        try {
            $partners = ChannelPartner::findOrFail($id);
            $partners->is_deleted = 1;
            $partners->save();

            return redirect()->back()->with('success', 'Channel Partner deleted successfully.');
        } catch (\Exception $e) {
            return redirect()->back()->with('error', 'Failed to actidelete Channel Partner.');
        }
   }

   public function login(Request $request)
{
    $validator = Validator::make($request->all(), [
        'mobile' => 'required|string|max:15',
        'password' => 'required|string|min:4|max:4',
    ]);

    if ($validator->fails()) {
        return response()->json(['status' => 'failed', 'errors' => $validator->errors()], 400);
    }

    $credentials = $request->only('mobile', 'password');

    if (!$token = auth('channel_partner')->attempt($credentials)) {
        return response()->json(['status' => 'failed', 'message' => 'Invalid credentials'], 401);
    }

    return response()->json([
        'status' => 'success',
        'token' => $token,
        'channel_partner' => auth('channel_partner')->user(),
    ]);
}

public function logout()
{
    auth('channel_partner')->logout();
    return response()->json(['status' => 'success', 'message' => 'Logged out successfully']);
}

public function createReferral(Request $request)
{
    $request->validate([
        'cust_name' => 'required|string|max:255',
        'cust_mobile' => 'required|string|max:20',
        'referral_code' => 'required|string|unique:referrals,referral_code',
        'cust_email' => 'nullable|email',
    ]);

    $referral = new Referral();
    $referral->cust_name = $request->cust_name;
    $referral->cust_mobile = $request->cust_mobile;
    $referral->cust_email = $request->cust_email;
    $referral->referral_code = $request->referral_code;
    $referral->partner_id = Auth::guard('channel_partner')->id(); // this saves the logged-in user's ID
    $referral->save();

    return response()->json([
        'message' => 'Referral created successfully.',
        'data' => $referral,
    ], 201);
}
   
public function getAllReferrals()
{
    $partnerId = Auth::guard('channel_partner')->id();

    // Fetch all referrals created by the logged-in partner
    $referrals = Referral::where('partner_id', $partnerId)->get();

    // Format the response
    $allReferralsFormatted = $referrals->map(function($referral) {
        return [
            'cust_name' => $referral->cust_name,
            'cust_email' => $referral->cust_email,
            'cust_mobile' => $referral->cust_mobile,
            'referral_code' => $referral->referral_code,
        ];
    });

    return response()->json([
        'referrals' => $allReferralsFormatted,
    ]);
}

public function getUsedReferrals()
{
    $partnerId = Auth::guard('channel_partner')->id();

    // Fetch all referrals created by the logged-in partner
    $referrals = Referral::where('partner_id', $partnerId)->get();

    // Get referral codes from those referrals
    $referralCodes = $referrals->pluck('referral_code');

    // Fetch tenants who used those codes
    $tenantsWithReferrals = Tenant::whereIn('refferal_code', $referralCodes)->get();

    // Format the data
    $referralsInUse = $tenantsWithReferrals->map(function($tenant) {
        return [
            'tenant_name' => $tenant->first_name,
            'tenant_email' => $tenant->email,
            'tenant_mobile' => $tenant->mobile,
            'referral_code' => $tenant->refferal_code,
        ];
    });

    return response()->json([
        'referrals' => $referralsInUse,
    ]);
}

public function getChannelPartnerByUser(Request $request)
    {
        $userId = Auth::id(); // Get logged-in user ID

        $channelPartners = ChannelPartner::where('cp_id', $userId)
            ->where('status', 1)
            ->where('is_deleted', 0)
            ->get();

        return response()->json([
            'success' => true,
            'channel_partners' => $channelPartners,
        ]);
    }

    public function createChannelPartner(Request $request)
{
    $validator = Validator::make($request->all(), [
        'full_name' => 'required|string|max:255',
        'email' => 'required|email|unique:channel_partners,email',
        'mobile' => 'required|string|max:15',
        'password' => 'required|string|min:4|max:4',
        'created_by' => 'nullable|string|max:255', // Store full_name here
        'cp_id' => 'nullable|integer|exists:channel_partners,id', // Creator's ID
    ]);

    if ($validator->fails()) {
        \Log::error('Channel Partner Validation Errors', $validator->errors()->toArray());

        return response()->json([
            'success' => false,
            'errors' => $validator->errors()
        ], 422);
    }

    // Check for duplicate mobile
    $existingPartner = ChannelPartner::where('mobile', $request->mobile)->first();
    if ($existingPartner) {
        return response()->json([
            'success' => false,
            'message' => 'Channel Partner already exists with this mobile.'
        ], 409);
    }

    // Create new Channel Partner
    $channelPartner = ChannelPartner::create([
        'full_name'   => $request->full_name,
        'email'       => $request->email,
        'mobile'      => $request->mobile,
        'password'    => Hash::make($request->password),
        'created_by'  => $request->created_by, // full_name of creator
        'cp_id'       => $request->cp_id,      // ID of creator
        'status'      => 1,
        'is_deleted'  => 0,
    ]);

    return response()->json([
        'success' => true,
        'message' => 'Channel Partner added successfully!',
        'cp_id' => $channelPartner->id,
        'data' => $channelPartner
    ]);
}  

}
