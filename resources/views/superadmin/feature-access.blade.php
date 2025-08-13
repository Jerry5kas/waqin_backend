@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Feature Access</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Feature Access</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Feature Access</h5>

          <form class="row g-3" action="{{ route('feature-access.store') }}" method="POST">
                @csrf
                <label class="form-label" for="tenant">Select Tenant:</label>
                <select name="tenant_id" class="form-control" required>
                <option value="" disabled selected>Select Tenant</option>
                    @foreach($tenants as $tenant)
                        <option value="{{ $tenant->id }}">{{ $tenant->first_name }} {{ $tenant->last_name }}</option>
                    @endforeach
                </select>

                <label class="form-label" for="package">Select Package:</label>
                <select name="package_name" class="form-control" required>
                    <option value="" disabled selected>Select Package</option>
                    @foreach(DB::table('tbl_package')->get() as $package)
                        <option value="{{ $package->name }}">{{ $package->name }}</option>
                    @endforeach
                </select>

                <label class="form-label" for="limit">Usage Limit (Optional):</label>
                <input type="number" name="limit" class="form-control" min="1" placeholder="Leave blank for no limit" />

                <button class="btn btn-primary" type="submit">Grant Access</button>
            </form>

        </div>
    </div>
  </div>  
  <div class="col-8">
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <div class="d-flex justify-content-between my-2">
                    <h5 class="card-title">Feature Access</h5>
                </div>
                
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th>#</th>
                            <th>Full Name</th>
                            <th>Company</th>
                            <th>Schema</th>
                            <th>Module</th>
                            <th>UID</th>
                            <th>Limit</th>
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
                            </tr>
                        @empty
                            <tr>
                                <td colspan="7">No access records found.</td>
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

@endsection