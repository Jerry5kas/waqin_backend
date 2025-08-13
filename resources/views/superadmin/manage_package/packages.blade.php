@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Manage Packages</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Manage Packages</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Package</h5>

          <form class="row g-3" method="POST" action="{{ url('manage-package/packages/store') }}">
            @csrf
            <div class="col-12">
              <label class="form-label">Package Name</label>
              <input type="text" class="form-control" name="name" required>
            </div>

            <div class="col-12">
                <label class="form-label">Select Modules</label>
                <select class="form-select select2" name="modules[]" multiple="multiple" required>
                    @foreach($features as $feature)
                    <option value="{{ $feature->uid }}">{{ $feature->module_name }}</option>
                    @endforeach
                </select>
            </div>

            <div class="col-12">
              <label class="form-label">Feature List</label>
              <div id="featureListWrapper">
                <div class="input-group mb-2 feature-item">
                  <input type="text" name="feature_list[]" class="form-control" placeholder="Enter feature" required>
                  <button type="button" class="btn btn-danger remove-feature-btn">Remove</button>
                </div>
              </div>
              <button type="button" id="addFeatureBtn" class="btn btn-primary btn-sm">Add Feature</button>
            </div>

            <div class="text-end">
              <button type="submit" class="btn btn-success">Save Package</button>
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
                    <h5 class="card-title">Package List</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Package Name</th>
                            <th>Modules</th>
                            <th>Feature List</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($packages as $index => $package)
                        <tr>
                            <td>{{ $index + 1 }}</td>
                            <td>{{ $package->name }}</td>
                            <td>
                                @php 
                                    $modules = json_decode($package->modules, true); 
                                @endphp
                                @if(!empty($modules))
                                    <ul>
                                        @foreach($modules as $mod)
                                            @php
                                                $moduleName = $features->firstWhere('uid', $mod)->module_name ?? $mod;
                                            @endphp
                                            <li>{{ $moduleName }}</li>
                                        @endforeach
                                    </ul>
                                @endif
                            </td>
                            <td>
                                @php $featuresList = json_decode($package->feature_list, true); @endphp
                                @if(!empty($featuresList))
                                    <ul>
                                        @foreach($featuresList as $feat)
                                            <li>{{ $feat }}</li>
                                        @endforeach
                                    </ul>
                                @endif
                            </td>
                            <td>
                                {!! $package->status == 1 ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-danger">Inactive</span>' !!}
                            </td>
                            <td>
                                <div class="d-flex justify-content-center align-items-center">

                                    {{-- Delete Button --}}
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" title="Delete"
                                            onclick="confirmAction('delete', '{{ url('manage-package/packages/delete/'.$package->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>

                                    {{-- Activate / Deactivate Button --}}
                                    @if ($package->status == 1)
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" title="Deactivate"
                                                onclick="confirmAction('deactivate', '{{ url('manage-package/packages/deactivate/'.$package->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" title="Activate"
                                                onclick="confirmAction('activate', '{{ url('manage-package/packages/activate/'.$package->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                    @endif

                                    {{-- Edit Button --}}
                                    <button type="button" class="icon btn btn-link"
                                            data-id="{{ $package->id }}"
                                            data-name="{{ $package->name }}"
                                            data-modules='@json(json_decode($package->modules))'
                                            data-features='@json(json_decode($package->feature_list))'
                                            onclick="openEditModal(this)">
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

<!-- Edit Package Modal -->
<div class="modal fade" id="editPackageModal" tabindex="-1" aria-labelledby="editPackageModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <form method="POST" action="{{ url('manage-package/packages/update') }}">
      @csrf
      <input type="hidden" name="id" id="editPackageId">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">Edit Package</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">
            <div class="mb-3">
                <label>Package Name</label>
                <input type="text" class="form-control" name="name" id="editPackageName" required>
            </div>
            <div class="mb-3">
                <label>Select Modules</label>
                <select class="form-select select2-modal" name="modules[]" multiple id="editModules" required>
                    @foreach($features as $feature)
                        <option value="{{ $feature->uid }}">{{ $feature->module_name }}</option>
                    @endforeach
                </select>
            </div>
            <div class="mb-3">
                <label>Feature List</label>
                <div id="editFeatureListWrapper"></div>
                <button type="button" id="addEditFeatureBtn" class="btn btn-primary btn-sm">Add Feature</button>
            </div>
        </div>
        <div class="modal-footer">
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </div>
    </form>
  </div>
</div>

{{-- Scripts --}}
<script>
    $(document).ready(function() {
        $('.select2, .select2-modal').select2({
            placeholder: "Select Modules",
            allowClear: true,
            width: '100%'
        });
    });
</script>
<script>
    // Feature add/remove in Add form
    document.getElementById('addFeatureBtn').addEventListener('click', function() {
        const wrapper = document.getElementById('featureListWrapper');
        const newFeature = document.createElement('div');
        newFeature.className = 'input-group mb-2 feature-item';
        newFeature.innerHTML = `
            <input type="text" name="feature_list[]" class="form-control" placeholder="Enter feature" required>
            <button type="button" class="btn btn-danger remove-feature-btn">Remove</button>`;
        wrapper.appendChild(newFeature);
    });

    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('remove-feature-btn')) {
            e.target.closest('.feature-item').remove();
        }
    });

    // Feature add/remove in Edit form
    document.getElementById('addEditFeatureBtn').addEventListener('click', function() {
        const wrapper = document.getElementById('editFeatureListWrapper');
        const newFeature = document.createElement('div');
        newFeature.className = 'input-group mb-2 edit-feature-item';
        newFeature.innerHTML = `
            <input type="text" name="feature_list[]" class="form-control" placeholder="Enter feature" required>
            <button type="button" class="btn btn-danger remove-edit-feature-btn">Remove</button>`;
        wrapper.appendChild(newFeature);
    });

    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('remove-edit-feature-btn')) {
            e.target.closest('.edit-feature-item').remove();
        }
    });

    // Edit Modal open
    function openEditModal(button) {
        const id = button.dataset.id;
        const name = button.dataset.name;
        const modules = JSON.parse(button.dataset.modules);
        const features = JSON.parse(button.dataset.features);

        document.getElementById('editPackageId').value = id;
        document.getElementById('editPackageName').value = name;

        // Set Select2 selected values correctly
        $('#editModules').val(null).trigger('change'); // Clear previous selection
        $('#editModules').val(modules).trigger('change');

        const wrapper = document.getElementById('editFeatureListWrapper');
        wrapper.innerHTML = '';
        features.forEach(feature => {
            const newFeature = document.createElement('div');
            newFeature.className = 'input-group mb-2 edit-feature-item';
            newFeature.innerHTML = `
                <input type="text" name="feature_list[]" class="form-control" value="${feature}" required>
                <button type="button" class="btn btn-danger remove-edit-feature-btn">Remove</button>`;
            wrapper.appendChild(newFeature);
        });

        new bootstrap.Modal(document.getElementById('editPackageModal')).show();
    }

    // Confirm Action Modal
    function confirmAction(action, url, method) {
        let actionButtonHtml = method === 'POST' ? 
            `<form action="${url}" method="POST" style="display:inline;"> @csrf <button type="submit" class="btn btn-primary">${capitalizeFirstLetter(action)}</button></form>` : 
            `<a href="${url}" class="btn btn-primary">${capitalizeFirstLetter(action)}</a>`;

        let modalHtml = `<div class="modal fade" id="actionConfirmationModal" tabindex="-1">
            <div class="modal-dialog"><div class="modal-content">
                <div class="modal-header"><h5>${capitalizeFirstLetter(action)} Confirmation</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
                <div class="modal-body">Are you sure you want to ${action} this package?</div>
                <div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>${actionButtonHtml}</div>
            </div></div></div>`;

        document.body.insertAdjacentHTML('beforeend', modalHtml);
        const confirmModal = new bootstrap.Modal(document.getElementById('actionConfirmationModal'));
        confirmModal.show();

        document.getElementById('actionConfirmationModal').addEventListener('hidden.bs.modal', function () {
            document.getElementById('actionConfirmationModal').remove();
        });
    }

    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }
</script>

@endsection
