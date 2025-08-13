<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Kreait\Firebase\Factory;

class FirebaseController extends Controller
{
    public static function createFirebaseAuth()
    {
        // Initialize Firebase with Service Account
        $firebase = (new Factory)
            ->withServiceAccount(base_path('config/waqinapp-firebase-adminsdk-vp2sz-0af4e26437.json'))
            ->createAuth();

        return $firebase;
    }
}
