<?php

namespace App\Http\Controllers\Api;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use App\Models\User; // Don't forget to import the User model

class UsersController extends Controller
{
    public function index()
    {
        $response = User::all();
        $users = $response->json();
        return view('dashboard', compact('users'));
    }
}
