@extends('layouts.superadmin')

@section('content')
<div class="container">
    <h2>Upload APK</h2>

    <form id="apk-upload-form" method="POST" action="{{ route('apks.store') }}" enctype="multipart/form-data">
        @csrf

        <div class="mb-3">
            <label for="version" class="form-label">Version</label>
            <input type="text" class="form-control" id="version" name="version" required>
        </div>

        <div class="mb-3">
            <label for="type" class="form-label">Type</label>
            <input type="text" class="form-control" id="type" name="type" required>
        </div>

        <div class="mb-3">
            <label for="message" class="form-label">Update Message</label>
            <textarea class="form-control" id="message" name="message" rows="2" required></textarea>
        </div>

        <div class="mb-3">
            <label for="force_update" class="form-label">Force Update?</label>
            <select class="form-control" id="force_update" name="force_update">
                <option value="0" selected>No</option>
                <option value="1">Yes</option>
            </select>
        </div>

        <div class="mb-3">
            <label for="apk_file" class="form-label">APK File (optional)</label>
            <input type="file" class="form-control" id="apk_file" name="apk_file" accept=".apk">
        </div>

        <button type="submit" class="btn btn-primary">Upload</button>
    </form>

    <div id="message-container"></div>
    <div id="progress-container" style="display: none;">
        <progress id="progress-bar" value="0" max="100"></progress>
        <span id="progress-text">0%</span>
    </div>
</div>

<p id="message"></p>

<script>
document.getElementById('apk-upload-form').addEventListener('submit', function (event) {
    event.preventDefault(); // Prevent default form submission

    const form = this;
    const formData = new FormData(form);

    // ✅ APK file is optional — no manual check
    // const fileInput = document.getElementById('apk_file');
    // const file = fileInput.files[0];
    // if (!file) {
    //     alert("Please select an APK file to upload.");
    //     return;
    // }

    // Show progress bar
    document.getElementById('progress-container').style.display = 'block';
    
    const xhr = new XMLHttpRequest();
    xhr.open('POST', form.action, true);

    xhr.upload.addEventListener('progress', function (event) {
        if (event.lengthComputable) {
            const percent = (event.loaded / event.total) * 100;
            document.getElementById('progress-bar').value = percent;
            document.getElementById('progress-text').textContent = Math.round(percent) + '%';
        }
    });

    xhr.onload = function () {
        try {
            const response = JSON.parse(xhr.responseText);
            const messageContainer = document.getElementById('message-container');
            
            if (xhr.status === 200) {
                const message = response?.message ?? response?.error ?? "Upload completed.";
                messageContainer.innerHTML = `<p style="color: green;">${message}</p>`;
                form.reset();
                setTimeout(() => {
                    location.reload();
                }, 2000);
            } else {
                const errorMessage = response?.message ?? response?.error ?? "An error occurred.";
                messageContainer.innerHTML = `<p style="color: red;">${errorMessage}</p>`;
            }

        } catch (error) {
            document.getElementById('message-container').innerHTML = '<p style="color: red;">Unexpected response from server.</p>';
        }

        document.getElementById('progress-container').style.display = 'none';
    };

    xhr.onerror = function () {
        document.getElementById('message-container').innerHTML = '<p style="color: red;">An error occurred during the upload.</p>';
        document.getElementById('progress-container').style.display = 'none';
    };

    xhr.send(formData);
});
</script>

@endsection
