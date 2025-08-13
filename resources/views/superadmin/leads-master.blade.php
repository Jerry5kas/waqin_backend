@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Leads</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Leads</li>
            </ol>
        </nav>
    </div>

        @if ($errors->has('row_error'))
            <div class="alert alert-warning alert-dismissible fade show" role="alert">
                {!! $errors->first('row_error') !!}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        @endif

    <div class="row">
        {{-- Left side: Upload Form --}}
        <div class="col-md-4">
            <div class="card">
                <div class="card-body">
                    <h5 class="card-title">Upload Leads Excel</h5>

                    <form action="{{ url('/leads/upload-excel') }}" method="POST" enctype="multipart/form-data">
                        @csrf

                        <div class="mb-3">
                            <label class="form-label">Download Template</label><br>
                            <a href="{{ url('/leads/download-template') }}" class="btn btn-success">Download Excel Template</a>
                        </div>

                        <div class="mb-3">
                            <label for="excel_file" class="form-label">Upload Excel</label>
                            <input type="file" name="excel_file" class="form-control" required>
                        </div>

                        <div class="text-end">
                            <button type="submit" class="btn btn-primary">Upload</button>
                            <button type="reset" class="btn btn-secondary">Reset</button>
                        </div>
                    </form>

                </div>
            </div>
        </div>

        {{-- Right side: Leads Table --}}
        <div class="col-md-8">
            <div class="card recent-sales overflow-auto">
                <div class="card-body">
                    <div class="d-flex justify-content-between my-2">
                        <h5 class="card-title">Uploaded Leads</h5>
                        <!-- Optional: Add search or filter buttons -->
                    </div>

                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Lead Name</th>
                                <th>Contact</th>
                                <th>Status</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($leads as $index => $lead)
                                <tr>
                                    <td>{{ $index + 1 }}</td>
                                    <td>{{ $lead->name }}</td>
                                    <td>{{ $lead->mobile }}</td>
                                    <td>
                                        @if ($lead->status == 1)
                                            <span class="badge bg-success">Active</span>
                                        @else
                                            <span class="badge bg-danger">Inactive</span>
                                        @endif
                                    </td>
                                    <td>
                                    <div class="d-flex justify-content-center align-items-center">
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('leads.destroy', $lead->id) }}', 'POST')">
                                            <i class="text-danger bi bi-trash3-fill"></i>
                                        </button>
                                        @if ($lead->status == 1)
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                onclick="confirmAction('deactivate', '{{ route('leads.deactivate', $lead->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                        @else
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                onclick="confirmAction('activate', '{{ route('leads.activate', $lead->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                        @endif
                                    </div>
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                    
                </div>
            </div>
        </div>
    </div>
</div>

<script>
function confirmAction(action, url, method) {
    let actionButtonHtml = method === 'POST' ?
        `<form action="${url}" method="POST" style="display:inline;">
            @csrf
            @method('DELETE')
            <button type="submit" class="btn btn-primary">${capitalizeFirstLetter(action)}</button>
        </form>` :
        `<a href="${url}" class="btn btn-primary">${capitalizeFirstLetter(action)}</a>`;

    let modalHtml = `
        <div class="modal fade" id="actionConfirmationModal" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">${capitalizeFirstLetter(action)} Confirmation</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">Are you sure you want to ${action} this lead?</div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                        ${actionButtonHtml}
                    </div>
                </div>
            </div>
        </div>`;

    document.body.insertAdjacentHTML('beforeend', modalHtml);

    let modal = new bootstrap.Modal(document.getElementById('actionConfirmationModal'));
    modal.show();

    document.getElementById('actionConfirmationModal').addEventListener('hidden.bs.modal', function () {
        document.getElementById('actionConfirmationModal').remove();
    });
}

function capitalizeFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}
</script>

@endsection
