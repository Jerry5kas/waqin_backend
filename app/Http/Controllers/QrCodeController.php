<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\File;
use BaconQrCode\Renderer\ImageRenderer;
use BaconQrCode\Renderer\Image\SvgImageBackEnd;
use BaconQrCode\Renderer\RendererStyle\RendererStyle;
use BaconQrCode\Writer;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use SimpleSoftwareIO\QrCode\Facades\QrCode;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class QrCodeController extends Controller
{
    public function generateFromApi(Request $request)
    {
        $validated = $request->validate([
            'link' => 'required|url'
        ]);

        $fileName = 'qr_' . time() . '.svg';
        $filePath = public_path('qr/' . $fileName);

        // Ensure the directory exists
        if (!File::exists(public_path('qr'))) {
            File::makeDirectory(public_path('qr'), 0755, true);
        }

        // Create SVG renderer (no Imagick needed)
        $renderer = new ImageRenderer(
            new RendererStyle(300),
            new SvgImageBackEnd()
        );

        $writer = new Writer($renderer);
        $qrSvg = $writer->writeString($validated['link']);

        // Save the SVG
        file_put_contents($filePath, $qrSvg);

        return response()->json([
            'message' => 'QR Code generated successfully (SVG backend)',
            'url' => asset('qr/' . $fileName)
        ]);
    }
}
