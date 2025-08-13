@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Query Builder</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Query Builder</li>
            </ol>
        </nav>
    </div>
    <div class="card">
        <div class="card-body">
            <div class="d-flex justify-content-between my-2">
                <h5 class="card-title">Query Builder</h5>
                <a class="btn btn-sm btn-primary" href="{{ route('query.builder.add') }}">Create Query</a>
            </div>
            <table class="table table-bordered formBuilder">
                <thead>
                    <tr>
                        <th>#</th>
                        <th>Method Name</th>
                        <th>Source Name</th>
                        <th>Target</th>
                        <th>Rule</th>
                        <th>Status</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach($queries as $index => $data)
                    <tr>
                        <td>{{ $index + 1 }}</td>
                        <td>{{ $data->method_name }}</td>
                        <td>{{ $data->source_name }}</td>
                        <td>{{ $data->target }}</td>
                        <td class="text-truncate" style="max-width: 300px;" title="{{ $data->rule }}">
                            {{ $data->rule }}
                        </td>
                        <td>
                            @if ($data->status == 0)
                            <span class="badge bg-warning text-white fw-bold">Inactive</span>
                            @elseif ($data->status == 1)
                            <span class="badge bg-success text-white fw-bold">Active</span>
                            @else
                            Unknown Status
                            @endif
                        </td>
                        <td>
                            <div class="d-flex justify-content-center align-items-center">
                                <a class="fs-6 text-decoration-none ms-2"
                                    href="{{ route('query.builder.edit', $data->id) }}">
                                    <i class="bi bi-pencil-square"></i>
                                </a>
                                <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('query.builder.delete', $data->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                </button>
                                @if ($data->status == 1)
                                <a class="icon ms-2" href="{{ route('query.builder.deactivate', $data->id) }}">
                                    <i
                                        class="bi bi-x-circle-fill" data-bs-toggle="tooltip" data-bs-placement="top"
                                        title="Deactivate"></i></a>
                                @else
                                <a class="icon ms-2" href="{{ route('query.builder.activate', $data->id) }}"><i
                                        class="bi bi-check2-circle" data-bs-toggle="tooltip" data-bs-placement="top"
                                        title="Activate"></i></a>
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
@endsection

@section('script')
<script type="text/javascript">
    

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
                            Are you sure you want to ${action} this Query?
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