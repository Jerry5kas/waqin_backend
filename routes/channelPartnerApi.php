<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Auth;
use App\Http\Controllers\ChannelPartnerController;

Route::prefix('channel-partner')->group(function () {
    Route::post('login', [ChannelPartnerController::class, 'login']);

    Route::middleware(['auth:channel_partner'])->group(function () {
        Route::post('/create-referral', [ChannelPartnerController::class, 'createReferral']);
        Route::get('/get-all-referrals', [ChannelPartnerController::class, 'getAllReferrals']);
        Route::get('/get-used-referrals', [ChannelPartnerController::class, 'getUsedReferrals']);
        Route::get('/list-by-user', [ChannelPartnerController::class, 'getChannelPartnerByUser']);
        Route::post('/create', [ChannelPartnerController::class, 'createChannelPartner']);

        // Add more protected routes here
    });
});