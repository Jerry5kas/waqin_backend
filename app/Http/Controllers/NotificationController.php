<?php

namespace App\Http\Controllers;

use App\Jobs\SendPushNotification;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

class NotificationController extends Controller
{
    public function showForm()
    {
        $tenants = DB::table('tenants')
        ->select('id', DB::raw("CONCAT(first_name, ' ', last_name) AS name"))
        ->whereNotNull('fcm_token')
        ->get();

        $routes = DB::table('fcm_routes')
        ->where('status', 1)
        ->where('is_deleted', 0)
        ->get();

        return view('superadmin.fcm_notification', compact('tenants', 'routes'));
    }

    public function sendNotification(Request $request)
    {
         $request->validate([
            'title'   => 'required|string',
            'message' => 'required|string',
            'image'    => 'nullable|string',
            'tenants' => 'required|array',
        ]);

        // Fetch FCM tokens from selected tenants
        $tokens = DB::table('tenants')
            ->whereIn('id', $request->tenants)
            ->whereNotNull('fcm_token')
            ->pluck('fcm_token')
            ->toArray();
        if (empty($tokens)) {
            return redirect()->back()->with('error', 'No valid FCM tokens found.');
        }

        $notificationData = [
        'extra_data' => 'Custom data',
        'route' => $request->route_name // Send route with notification
        ];

        dispatch(new SendPushNotification(
            $tokens,
            $request->title,
            $request->message,
            $request->image ?? '',
            $notificationData
        ));

        return redirect()->back()->with('success', 'Notification queued successfully!');
    }

    public function sendLeadNotification()
{
    // Fetch FCM tokens from tenants associated with leads
    $tokens = DB::table('tenants')
    ->whereIn('id', function ($query) {
        $query->select('tenant_id')
            ->from('leads_history')
            ->whereDate('created_at', Carbon::today()) // only today's leads
            ->groupBy('tenant_id');
        })
        ->whereNotNull('fcm_token')
        ->distinct()
        ->pluck('fcm_token')
        ->toArray();

    if (empty($tokens)) {
        return redirect()->back()->with('error', 'No valid FCM tokens found.');
    }

    $title = 'New Leads';
    $message = 'Got new leads, click to check';
    $route = '/lead';

    $notificationData = [
        'extra_data' => 'Custom data',
        'route'      => $route,
    ];
    
    dispatch(new SendPushNotification($tokens, $title, $message, '', $notificationData));

    return response()->json(['success' => 'Lead notifications queued successfully!']);
}

}