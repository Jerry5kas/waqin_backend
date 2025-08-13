@extends('layouts.superadmin')

@section('content')
<style>
    .select2-container--bootstrap-5 .select2-selection {
        border: 1px solid #ced4da !important;
        border-radius: 0.375rem; /* same as .form-select */
        min-height: 38px;
        padding: 0.375rem 0.75rem;
    }

    .select2-container--bootstrap-5 .select2-selection__rendered {
        line-height: normal;
    }

    .select2-container--bootstrap-5 .select2-selection--single {
        height: auto !important;
    }
</style>
<div class="container">
    <div class="pagetitle">
        <h1>Sync</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Sync</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Sync</h5>

          <form action="{{ route('sync.store') }}" method="POST">
                @csrf

                <div class="mb-3">
                    <label for="tenant_id" class="form-label">Select Tenant</label>
                    <select name="tenant_id" id="tenant_id" class="form-select select2" required style="width: 100%">
                        <option value="">-- Choose --</option>
                        @foreach ($tenants as $tenant)
                            <option value="{{ $tenant->id }}">{{ $tenant->first_name }} {{ $tenant->last_name }} ({{ $tenant->mobile }})</option>
                        @endforeach
                    </select>
                </div>

                <div class="form-check">
                    <input class="form-check-input" type="checkbox" name="contact" id="contact">
                    <label class="form-check-label" for="contact">Contact</label>
                </div>

                <div class="form-check">
                    <input class="form-check-input" type="checkbox" name="call_history" id="call_history">
                    <label class="form-check-label" for="call_history">Call History</label>
                </div>

                <button type="submit" class="btn btn-primary mt-3">Submit</button>
            </form>

        </div>
    </div>
  </div>  
  <div class="col-8">
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <div class="d-flex justify-content-between my-2">
                    <h5 class="card-title">Business Categories</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th scope="col">#</th>
                            <th scope="col">Name</th>
                            <th scope="col">Mobile</th>
                            <th scope="col">Schema</th>
                            <th scope="col">Contact</th>
                            <th scope="col">Call History</th>
                            <th scope="col">status</th>
                            <th scope="col">Action</th>
                        </tr>
                    </thead>

                    <tbody>
                            @foreach ($syncRequests as $index => $data)
                            <tr>
                                <td>{{ $index + 1 }}</td>
                                <td><span id="category-name-{{ $data->id }}">{{ $data->full_name }}</span></td>
                                <td>{{ $data->mobile }}</td>
                                <td>{{ $data->tenant_schema }}</td>

                                {{-- Contact --}}
                                <td>
                                    @if ($data->contact == 1)
                                        <span class="badge bg-success">True</span>
                                        <button type="button" class="icon btn btn-link" title="Deactivate Contact"
                                            onclick="confirmAction('deactivate contact', '{{ route('sync.toggleContact', $data->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        <span class="badge bg-danger">False</span>
                                        <button type="button" class="icon btn btn-link" title="Activate Contact"
                                            onclick="confirmAction('activate contact', '{{ route('sync.toggleContact', $data->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                    @endif
                                </td>

                                {{-- Call History --}}
                                <td>
                                    @if ($data->call_history == 1)
                                        <span class="badge bg-success">True</span>
                                        <button type="button" class="icon btn btn-link" title="Deactivate Call History"
                                            onclick="confirmAction('deactivate call history', '{{ route('sync.toggleCallHistory', $data->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        <span class="badge bg-danger">False</span>
                                        <button type="button" class="icon btn btn-link" title="Activate Call History"
                                            onclick="confirmAction('activate call history', '{{ route('sync.toggleCallHistory', $data->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                    @endif
                                </td>

                                {{-- Status --}}
                                <td>
                                    @if ($data->status == 1)
                                        <span class="badge bg-success">Active</span>
                                    @else
                                        <span class="badge bg-danger">Inactive</span>
                                    @endif
                                </td>

                                {{-- Action --}}
                                <td>
                                    @if ($data->status == 1)
                                        <button type="button" class="btn btn-sm btn-outline-danger" title="Deactivate"
                                            onclick="confirmAction('deactivate', '{{ route('sync.toggleStatus', $data->id) }}', 'GET')">
                                            <i class="bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        <button type="button" class="btn btn-sm btn-outline-success" title="Activate"
                                            onclick="confirmAction('activate', '{{ route('sync.toggleStatus', $data->id) }}', 'GET')">
                                            <i class="bi bi-check2-circle"></i>
                                        </button>
                                    @endif
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
            <div class="modal fade" id="actionConfirmationModal" tabindex="-1" aria-labelledby="actionConfirmationModalLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title" id="actionConfirmationModalLabel">${capitalizeFirstLetter(action)} Confirmation</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body">
                            Are you sure you want to ${action} this business category?
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            ${actionButtonHtml}
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Append the modal to the body
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        // Show the modal
        var actionConfirmationModal = new bootstrap.Modal(document.getElementById('actionConfirmationModal'));
        actionConfirmationModal.show();

        // Remove the modal from the DOM after it is closed
        document.getElementById('actionConfirmationModal').addEventListener('hidden.bs.modal', function () {
            document.getElementById('actionConfirmationModal').remove();
        });
    }

    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

</script>

@push('scripts')
<script>
$(document).ready(function() {
    $('#tenant_id').select2({
        theme: 'bootstrap-5',
        placeholder: "-- Choose --",
        minimumInputLength: 0,
        width: '100%',
        ajax: {
            url: '{{ route('tenants.search') }}',
            dataType: 'json',
            delay: 250,
            data: function(params) {
                return {
                    q: params.term || ''
                };
            },
            processResults: function(data) {
                return {
                    results: data.results
                };
            },
            cache: true
        }
    }).on('select2:open', function() {
        $('.select2-search__field').trigger('input');
    });
});
</script>
@endpush

@endsection