@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Manage Features</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Manage Features</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Feature</h5>

          <form class="row g-3" method="POST" action="{{ url('manage-package/features/store') }}">
            @csrf
            <div class="col-12">
              <label class="form-label">Feature Name (Module Name)</label>
              <input type="text" class="form-control" name="module_name" required>
            </div>

            <div class="col-12">
              <label class="form-label">UID (Unique Code)</label>
              <input type="text" class="form-control" name="uid" required placeholder="Ex: MOD_EMP">
            </div>

            <div class="text-end">
              <button type="submit" class="btn btn-primary">Add Feature</button>
            </div>
          </form>

        </div>
    </div>
  </div>  

  <div class="col-8">
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <div class="d-flex justify-content-between my-2">
                    <h5 class="card-title">Feature List</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Feature Name</th>
                            <th>UID</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($features as $index => $feature)
                        <tr>
                            <td>{{ $index + 1 }}</td>
                            <td>{{ $feature->module_name }}</td>
                            <td>{{ $feature->uid }}</td>
                            <td>{!! $feature->status == 1 ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-danger">Inactive</span>' !!}</td>
                            <td>
                                <div class="d-flex justify-content-center align-items-center">

                                    {{-- Delete Button --}}
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ url('manage-package/features/delete/'.$feature->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>

                                    {{-- Activate / Deactivate Button --}}
                                    @if ($feature->status == 1)
                                        {{-- Deactivate --}}
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                onclick="confirmAction('deactivate', '{{ url('manage-package/features/deactivate/'.$feature->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        {{-- Activate --}}
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                onclick="confirmAction('activate', '{{ url('manage-package/features/activate/'.$feature->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                    @endif

                                    {{-- Edit Button --}}
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"
                                            onclick="openEditModal({{ $feature->id }}, '{{ $feature->module_name }}', '{{ $feature->uid }}')">
                                        <i class="bi bi-pencil-square"></i>
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
</div>
</div>
<!-- Edit Feature Modal -->
<div class="modal fade" id="editFeatureModal" tabindex="-1" aria-labelledby="editFeatureModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <form method="POST" action="{{ url('manage-package/features/update') }}">
      @csrf
      <input type="hidden" name="id" id="editFeatureId">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title" id="editFeatureModalLabel">Edit Feature</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
            <div class="mb-3">
                <label class="form-label">Feature Name (Module Name)</label>
                <input type="text" class="form-control" name="module_name" id="editModuleName" required>
            </div>
            <div class="mb-3">
                <label class="form-label">UID (Unique Code)</label>
                <input type="text" class="form-control" name="uid" id="editUid" required>
            </div>
        </div>
        <div class="modal-footer">
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </div>
    </form>
  </div>
</div>
<script>
    function confirmAction(action, url, method) {
        let actionButtonHtml = method === 'POST' ? 
            `<form action="${url}" method="POST" style="display:inline;">
                @csrf
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
                            Are you sure you want to ${action} this feature?
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            ${actionButtonHtml}
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.body.insertAdjacentHTML('beforeend', modalHtml);
        var actionConfirmationModal = new bootstrap.Modal(document.getElementById('actionConfirmationModal'));
        actionConfirmationModal.show();

        document.getElementById('actionConfirmationModal').addEventListener('hidden.bs.modal', function () {
            document.getElementById('actionConfirmationModal').remove();
        });
    }

    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

    function openEditModal(id, moduleName, uid) {
        document.getElementById('editFeatureId').value = id;
        document.getElementById('editModuleName').value = moduleName;
        document.getElementById('editUid').value = uid;

        var editModal = new bootstrap.Modal(document.getElementById('editFeatureModal'));
        editModal.show();
    }
</script>

@endsection
