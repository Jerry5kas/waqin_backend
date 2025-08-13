<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class OTPController extends Controller
{
    public function sendOtp(Request $request)
    {
        $request->validate([
            'phone_number' => 'required|string|max:15', // Validate the phone number
        ]);

        try {
            $phoneNumber = $request->input('phone_number');

            // Firebase Authentication REST API endpoint
            $url = 'https://identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode?key=' . env('FIREBASE_API_KEY');

            // Make the request to Firebase REST API
            $response = Http::post($url, [
                'phoneNumber' => $phoneNumber,
            ]);
            dd($response);

            if ($response->successful()) {
                return response()->json([
                    'success' => true,
                    'message' => 'OTP sent successfully.',
                    'sessionInfo' => $response->json('sessionInfo'), // Save this for OTP verification
                ]);
            }

            return response()->json([
                'success' => false,
                'message' => 'Failed to send OTP.',
                'error' => $response->json(),
            ], 400);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'An error occurred: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function verifyOtp(Request $request)
{
    $request->validate([
        'verification_id' => 'required|string',
        'verification_code' => 'required|string',
    ]);

    try {
        // Get verification details from the request
        $verificationId = $request->input('verification_id');
        $verificationCode = $request->input('verification_code');

        // Create Firebase Auth instance
        $auth = FirebaseController::createFirebaseAuth();

        // Verify the OTP
        $verifiedPhoneNumber = $auth->verifyPhoneNumber($verificationId, $verificationCode);

        return response()->json([
            'success' => true,
            'message' => 'Phone number verified successfully.',
            'phone_number' => $verifiedPhoneNumber,
        ]);
    } catch (PhoneNumberVerificationFailed $e) {
        return response()->json([
            'success' => false,
            'message' => 'Failed to verify OTP: ' . $e->getMessage(),
        ], 500);
    }
}

}
