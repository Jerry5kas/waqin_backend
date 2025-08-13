<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Apk;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class ApkController extends Controller
{
    // Show upload form
    public function create()
    {
        return view('apks.upload');
    }

    public function store(Request $request)
{
    try {
        // Validate the incoming data
        $request->validate([
            'version' => 'required|string|max:255',
            'type' => 'required|string|max:255',
            'apk_file' => 'nullable|file|max:200000',
            'message' => 'required|string|max:1000',
            'force_update' => 'nullable|in:0,1',
        ]);

        $filePath = null;

        // Handle file upload if file is present
        if ($request->hasFile('apk_file')) {
            $file = $request->file('apk_file');
            $originalFileName = pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME);
            $extension = $file->getClientOriginalExtension();

            $baseFileName = 'APK_' . str_replace(' ', '_', $request->version) . '_' . str_replace(' ', '_', $request->type) . '_' . $originalFileName;

            $counter = 1;
            $fileName = $baseFileName . '.' . $extension;
            while (Storage::exists('public/apks/' . $fileName)) {
                $fileName = $baseFileName . '_' . $counter . '.' . $extension;
                $counter++;
            }

            $filePath = $file->storeAs('public/apks', $fileName);
        }

        // Save details in the database
        Apk::create([
            'version' => $request->version,
            'type' => $request->type,
            'file_path' => $filePath,
            'message' => $request->message,
            'force_update' => $request->force_update ?? 0,
        ]);

        return response()->json(['success' => true, 'message' => 'APK uploaded successfully!']);
    } catch (\Exception $e) {
        return response()->json(['success' => false, 'message' => 'File upload failed: ' . $e->getMessage()], 500);
    }
}
    
    public function index()
    {
        $apks = Apk::all();
        return view('apks.index', compact('apks'));
    }

    public function generateDownloadLink($id)
    {
        $apk = Apk::findOrFail($id);
        $password = Str::random(8); // Generate random password
    
        // Save password to database
        $apk->update(['download_password' => $password]);
    
        // Generate the download link
        $downloadLink = route('apks.download.form', $apk->id);
    
        // Return to the APK index page with the success message and generated data
        return redirect()->route('apks.index')->with([
            'success' => 'Download link and password generated.',
            'apkId' => $apk->id,
            'downloadLink' => $downloadLink,
            'password' => $password
        ]);
    }
    
    // Show password input form before downloading
    public function showDownloadForm($id)
    {
        $apk = Apk::findOrFail($id);
        return view('apks.download', compact('apk'));
    }

    // Handle download after password verification
    public function download(Request $request, $id)
    {
        $apk = Apk::findOrFail($id);

        if ($request->password !== $apk->download_password) {
            return back()->with('error', 'Incorrect password.');
        }

        $filePath = storage_path("app/{$apk->file_path}");
        $fileName = basename($filePath);

        return response()->streamDownload(function () use ($filePath) {
            readfile($filePath);
        }, $fileName, [
            'Content-Type' => 'application/vnd.android.package-archive', // Force correct MIME type
            'Content-Disposition' => 'attachment; filename="' . $fileName . '"',
        ]);
    }
}