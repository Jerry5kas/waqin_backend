@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Tenants</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="index.html">Home</a></li>
                <li class="breadcrumb-item active">Tenants</li>
            </ol>
        </nav>
    </div>
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th scope="col">#</th>
                            <th scope="col">Business</th>
                            <th scope="col">Name</th>
                            <th scope="col">Phone</th>
                            <th scope="col">Email</th>
                            <th scope="col">Full Address</th>
                            <th scope="col">Status</th>
                            <th scope="col">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($tenancies as $index => $tenancy)
                        <tr>
                            <td>{{$index + 1}}</td>
                            <td>@foreach($businessCategories as $business)
                                @if($tenancy->business_id == $business->id)
                                    {{ $business->name }}
                                @endif
                            @endforeach</td>
                            <td>
                                <a href="{{ route('tenant_detail', ['id' => base64_encode(Crypt::encryptString($tenancy->id))]) }}">{{ $tenancy->first_name }} {{ $tenancy->last_name }}</a>
                            </td>
                            <td>{{ $tenancy->mobile }}</td>
                            <td>{{ $tenancy->email }}</td>
                            <td>{{ $tenancy->full_address }}</td>
                            @if ($tenancy->status == 1)
                            <td> <span class="badge bg-success">Active</span> </td>
                            @else
                            <td> <span class="badge bg-danger">Inactive</span> </td>
                            @endif
                            <td>
                                <div class="d-flex justify-content-center align-items-center">
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('tenants.destroy', $tenancy->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>
                                    @if ($tenancy->status == 1)
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                            onclick="confirmAction('deactivate', '{{ route('tenants.deactivate', $tenancy->id) }}', 'GET')">
                                        <i class="text-danger bi bi-x-circle-fill"></i>
                                    </button>
                                    @else
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                            onclick="confirmAction('activate', '{{ route('tenants.activate', $tenancy->id) }}', 'GET')">
                                        <i class="text-success bi bi-check2-circle"></i>
                                    </button>
                                    @endif
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" title="Login as Tenant"
                                            onclick="window.open('{{ route('admin.auto.login', $tenancy->id) }}', '_blank')">
                                        <i class="text-primary bi bi-box-arrow-in-right"></i>
                                    </button>
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
                            Are you sure you want to ${action} this tenant?
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
@endsection