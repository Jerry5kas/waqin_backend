@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Manage Package Durations</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Package Durations</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Duration</h5>

          <form class="row g-3" method="POST" action="{{ url('manage-package/durations/store') }}">
            @csrf

            <div class="col-12">
              <label class="form-label">Package</label>
              <select class="form-select" name="package_id" required>
                @foreach ($packages as $package)
                  <option value="{{ $package->id }}">{{ $package->name }}</option>
                @endforeach
              </select>
            </div>

            <div class="col-12">
              <label class="form-label">Duration (Monthly, Quarterly, Yearly)</label>
              <input type="text" class="form-control" name="duration" required>
            </div>

            <div class="col-12">
              <label class="form-label">Amount</label>
              <input type="number" class="form-control" name="amount" required>
            </div>

            <div class="col-12">
              <label class="form-label">Tax %</label>
              <input type="number" class="form-control" name="tax" required>
            </div>

            <div class="text-end">
              <button type="submit" class="btn btn-primary">Add Duration</button>
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
                    <h5 class="card-title">Duration List</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Package</th>
                            <th>Duration</th>
                            <th>Amount</th>
                            <th>Tax</th>
                            <th>Status</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($durations as $index => $duration)
                        <tr>
                            <td>{{ $index + 1 }}</td>
                            <td>{{ $packages->where('id', $duration->package_id)->first()->name }}</td>
                            <td>{{ $duration->duration }}</td>
                            <td>{{ $duration->amount }}</td>
                            <td>{{ $duration->tax }}%</td>
                            <td>{!! $duration->status == 1 ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-danger">Inactive</span>' !!}</td>
                            <td>
                                <div class="d-flex justify-content-center align-items-center">

                                    {{-- Delete Button --}}
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ url('manage-package/durations/delete/'.$duration->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>

                                    {{-- Activate / Deactivate Button --}}
                                    @if ($duration->status == 1)
                                        {{-- Deactivate --}}
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                onclick="confirmAction('deactivate', '{{ url('manage-package/durations/deactivate/'.$duration->id) }}', 'GET')">
                                            <i class="text-danger bi bi-x-circle-fill"></i>
                                        </button>
                                    @else
                                        {{-- Activate --}}
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                onclick="confirmAction('activate', '{{ url('manage-package/durations/activate/'.$duration->id) }}', 'GET')">
                                            <i class="text-success bi bi-check2-circle"></i>
                                        </button>
                                    @endif

                                    {{-- Edit Button --}}
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"
                                            onclick="openEditModal({{ $duration->id }}, {{ $duration->package_id }}, '{{ $duration->duration }}', '{{ $duration->amount }}', '{{ $duration->tax }}')">
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

<!-- Edit Duration Modal -->
<div class="modal fade" id="editDurationModal" tabindex="-1" aria-labelledby="editDurationModalLabel" aria-hidden="true">
  <div class="modal-dialog">
    <form method="POST" action="{{ url('manage-package/durations/update') }}">
      @csrf
      <input type="hidden" name="id" id="editDurationId">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title" id="editDurationModalLabel">Edit Duration</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
        </div>
        <div class="modal-body">
            <div class="mb-3">
                <label class="form-label">Package</label>
                <select class="form-select" name="package_id" id="editPackageId" required>
                  @foreach ($packages as $package)
                    <option value="{{ $package->id }}">{{ $package->name }}</option>
                  @endforeach
                </select>
            </div>

            <div class="mb-3">
                <label class="form-label">Duration</label>
                <input type="text" class="form-control" name="duration" id="editDuration" required>
            </div>

            <div class="mb-3">
                <label class="form-label">Amount</label>
                <input type="number" class="form-control" name="amount" id="editAmount" required>
            </div>

            <div class="mb-3">
                <label class="form-label">Tax %</label>
                <input type="number" class="form-control" name="tax" id="editTax" required>
            </div>

        </div>
        <div class="modal-footer">
          <button type="submit" class="btn btn-primary">Save Changes</button>
        </div>
      </div>
    </form>
  </div>
</div>

{{-- Confirm Action Modal --}}
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
                            Are you sure you want to ${action} this duration?
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            ${actionButtonHtml}
                        </div>
                    </div>
                </div>
            </div>`;

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

    function openEditModal(id, packageId, duration, amount, tax) {
        document.getElementById('editDurationId').value = id;
        document.getElementById('editPackageId').value = packageId;
        document.getElementById('editDuration').value = duration;
        document.getElementById('editAmount').value = amount;
        document.getElementById('editTax').value = tax;

        var editModal = new bootstrap.Modal(document.getElementById('editDurationModal'));
        editModal.show();
    }
</script>

@endsection
