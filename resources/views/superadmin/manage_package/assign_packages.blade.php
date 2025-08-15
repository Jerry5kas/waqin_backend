@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Assign Packages</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Assign Packages</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-lg-4 col-md-6">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Assign Features to Tenant</h5>

          <form class="row g-3" method="POST" action="{{ url('manage-package/assign-packages/store') }}">
            @csrf
            <div class="col-12">
              <label class="form-label">Select Tenant</label>
              <select name="tenant_id" class="form-select select2-tenant" required>
                <option value="" disabled selected>Choose Tenant</option>
                @foreach($tenants as $tenant)
                    <option value="{{ $tenant->id }}">{{ $tenant->first_name }} {{ $tenant->last_name }} ({{ $tenant->company_name }})</option>
                @endforeach
              </select>
            </div>

            <div class="col-12">
              <label class="form-label">Select Modules</label>
              <select name="module_ids[]" class="form-select select2-modules" multiple="multiple" required>
                @foreach($features as $feature)
                    <option value="{{ $feature->id }}">{{ $feature->module_name }} ({{ $feature->uid }})</option>
                @endforeach
              </select>
            </div>

            <div class="col-12" style="display: none;">
              <label class="form-label">Usage Limit (Optional)</label>
              <input type="number" class="form-control" name="limit" min="1" placeholder="Leave blank for no limit">
            </div>

            <div class="text-end">
              <button type="submit" class="btn btn-success">Assign Features</button>
            </div>
          </form>
        </div>
    </div>
  </div>  

  <div class="col-lg-8 col-md-6">
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <div class="d-flex justify-content-between my-2">
                    <h5 class="card-title">Current Feature Assignments</h5>
                </div>
                <div class="table-responsive">
                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Tenant Name</th>
                                <th>Company</th>
                                <th>Schema</th>
                                <th>Module</th>
                                <th>UID</th>
                                <th>Limit</th>
                                <th>Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            @forelse ($accessList as $index => $access)
                            <tr>
                                <td>{{ $index + 1 }}</td>
                                <td>{{ $access->full_name }}</td>
                                <td>{{ $access->company_name }}</td>
                                <td>{{ $access->tenant_schema }}</td>
                                <td>{{ $access->module_name }}</td>
                                <td>{{ $access->uid }}</td>
                                <td>{{ $access->limit ?? 'N/A' }}</td>
                                <td>{!! $access->status == 1 ? '<span class="badge bg-success">Active</span>' : '<span class="badge bg-warning">Pending</span>' !!}</td>
                            </tr>
                            @empty
                            <tr>
                                <td colspan="8" class="text-center">No feature assignments found.</td>
                            </tr>
                            @endforelse
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
  </div>
</div>  
</div>

{{-- Scripts --}}
<script>
    $(document).ready(function() {
        // Initialize Select2 for tenant selection
        $('.select2-tenant').select2({
            placeholder: "Choose Tenant",
            allowClear: true,
            width: '100%'
        });

        // Initialize Select2 for modules selection
        $('.select2-modules').select2({
            placeholder: "Select Modules",
            allowClear: true,
            width: '100%',
            closeOnSelect: false
        });
    });
</script>

@endsection
