<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\MenuPermission;
use Illuminate\Http\Request;

class MenuPermissionController extends Controller
{
    //
    public function index()
    {
        $users = User::where('role', '!=', 2)->get(); // Exclude superadmin
        return view('menu_permissions.index', compact('users'));
    }
    
    public function edit($userId)
    {
        $user = User::findOrFail($userId);
        $permission = MenuPermission::where('user_id', $userId)->first();
        
        $menus = [
            'Dashboard' => false,
            'Tenants' => ['List' => false],
            'Channel Partners' => false,
            'Businesses' => false,
            'Business Sub Categories' => false,
            'Marketings' => false,
            'Sales and Services' => false,
            'Status' => false,
            'Contact Group' => false,
            'Form Builder' => false,
            'Query Builder' => false,
            'Query Mapping' => false,
            'FCM Notification' => false,
            'User Permission' => false,
            'Feature Access' => false,
            'Leads Master' => false,
            'Sync Request' => false,
            'Manage Packages' => false,
        ];
    
        $permissions = $permission ? $permission->permissions : [];
    
        return view('menu_permissions.form', compact('user', 'menus', 'permissions'));
    }
    
    public function update(Request $request, $userId)
    {
        $validated = $request->validate([
            'permissions' => 'required|array',
        ]);
    
        MenuPermission::updateOrCreate(
            ['user_id' => $userId],
            ['permissions' => $validated['permissions']]
        );
    
        return redirect()->route('menu-permissions.index')->with('success', 'Permissions updated.');
    }

}
