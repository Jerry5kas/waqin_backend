@extends('layouts.superadmin')

@section('content')
<div class="container">
    <h2>APK List</h2>
    <!-- Show generated link and password with close button -->
    @if(session('downloadLink') && session('password'))
        <div id="generated-info" class="alert alert-info">
        <button id="close-btn" class="btn-close position-absolute top-0 end-0" aria-label="Close"></button> 
            <p><strong>Generated Download Link:</strong> <span id="download-link">{{ session('downloadLink') }}</span></p>
            <p><strong>Password:</strong> <span id="download-password">{{ session('password') }}</span></p>
            <button id="copy-button" class="btn btn-outline-secondary">Copy Both</button>
        </div>

        <script>
            // Auto remove after 1 minute
            setTimeout(function() {
                var generatedInfoDiv = document.getElementById('generated-info');
                generatedInfoDiv.style.display = 'none'; // Hide the div after 1 minute
            }, 60000); // 60000 ms = 1 minute

            // Close the div manually when the close button is clicked
            document.getElementById('close-btn').addEventListener('click', function() {
                document.getElementById('generated-info').style.display = 'none';
            });
        </script>
    @endif

    <!-- APK Upload Button -->
    <div class="mb-3">
        <a href="{{ route('apks.create') }}" class="btn btn-primary">Upload APK</a> <!-- Button for uploading APK -->
    </div>

    <table class="table">
        <thead>
            <tr>
                <th>#</th>
                <th>Version</th>
                <th>Type</th>
                <th>Actions</th>
            </tr>
        </thead>
        <tbody>
            @foreach($apks as $index => $apk)
            <tr>
                <td>{{ $index + 1 }}</td>
                <td>{{ $apk->version }}</td>
                <td>{{ $apk->type }}</td>
                <td>
                    <a href="{{ route('apks.generate', $apk->id) }}" class="btn btn-warning" data-bs-toggle="tooltip" data-bs-placement="top" title="Generate Download Link">
                        <i class="bi bi-link"></i> <!-- Link icon -->
                    </a>

                    <a href="{{ route('apks.download.form', $apk->id) }}" class="btn btn-primary" data-bs-toggle="tooltip" data-bs-placement="top" title="Download APK">
                        <i class="bi bi-download"></i> <!-- Download icon -->
                    </a>
                </td>
            </tr>
            @endforeach
        </tbody>
    </table>
</div>

<script>
    // Copy both link and password to clipboard
    document.getElementById('copy-button').addEventListener('click', function() {
        // Combine the link and password into a single string
        var link = document.getElementById('download-link').textContent;
        var password = document.getElementById('download-password').textContent;
        var textToCopy = "Download Link: " + link + "\nPassword: " + password;

        // Create a temporary textarea element to select the text
        var textarea = document.createElement('textarea');
        textarea.value = textToCopy;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);

        // Show toaster notification
        toastr.success('Link and password copied to clipboard!');
    });
</script>

@endsection