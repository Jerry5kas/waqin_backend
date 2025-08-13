@extends('layouts.superadmin')

@section('content')

<div class="col-xl-12">
            
            <div class="card">
              <div class="card-body pt-3">
                <!-- Bordered Tabs -->
                <ul class="nav nav-tabs nav-tabs-bordered" role="tablist" style="overflow-x: auto; overflow-y: hidden; white-space: nowrap; display: flex; flex-wrap: nowrap; scrollbar-width: thin;">
    
                  <li class="nav-item" role="presentation">
                    <button class="nav-link active" data-bs-toggle="tab" data-bs-target="#profile-overview" aria-selected="true" role="tab">Overview</button>
                  </li>
    
                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#profile-edit" aria-selected="false" tabindex="-1" role="tab">Edit Profile</button>
                  </li>
    
                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#profile-settings" aria-selected="false" tabindex="-1" role="tab">Settings</button>
                  </li>
    
                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#profile-change-password" aria-selected="false" tabindex="-1" role="tab">Change Password</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#employees" aria-selected="false" tabindex="-1" role="tab">Employees</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customers" aria-selected="false" tabindex="-1" role="tab">Customers</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#call_history" aria-selected="false" tabindex="-1" role="tab">Call History</button>
                  </li>

                  <!-- <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li>

                  <li class="nav-item" role="presentation">
                    <button class="nav-link" data-bs-toggle="tab" data-bs-target="#customer_details" aria-selected="false" tabindex="-1" role="tab">Customer Details</button>
                  </li> -->
    
                </ul>
                <div class="tab-content pt-2 profile">
    
                  <div class="tab-pane fade show active profile-overview" id="profile-overview" role="tabpanel">
            
                            <img src="{{ asset('storage/' . $tenant->image) }}" alt="Profile" class="mt-2 rounded-circle" style="height: 100px; width: 100px">
                          {{-- <h2>{{ $tenant->name }}</h2> --}}
    
                    <h5 class="card-title mt-3">Profile Details</h5>
    
                    <div class="row">
                      <div class="col-lg-3 col-md-4 label ">Full Name</div>
                      <div class="col-lg-9 col-md-8">{{ $tenant->first_name }} {{ $tenant->last_name }}</div>
                    </div>
    
                    <div class="row">
                      <div class="col-lg-3 col-md-4 label">Business</div>
                      <div class="col-lg-9 col-md-8">@foreach($businessCategories as $business)
                        @if($tenant->business_id == $business->id)
                            {{ $business->name }}
                        @endif
                    @endforeach</div>
                    </div>
                    <div class="row">
                      <div class="col-lg-3 col-md-4 label">Company</div>
                      <div class="col-lg-9 col-md-8">{{ $tenant->company_name }}</div>
                    </div>
                    
                    <div class="row">
                      <div class="col-lg-3 col-md-4 label">Phone</div>
                      <div class="col-lg-9 col-md-8">{{ $tenant->mobile }}</div>
                    </div>
                    
                    <div class="row">
                      <div class="col-lg-3 col-md-4 label">Email</div>
                      <div class="col-lg-9 col-md-8">{{ $tenant->email }}</div>
                    </div>

                    <div class="row">
                      <div class="col-lg-3 col-md-4 label">Address</div>
                      <div class="col-lg-9 col-md-8">{{ $tenant->full_address }}</div>
                    </div>

                  </div>
    
                  <div class="tab-pane fade profile-edit pt-3" id="profile-edit" role="tabpanel">
                        <h1>pending</h1>
                    <!-- Profile Edit Form -->
                  
                    <!-- End Profile Edit Form --> 
    
                  </div>
    
                  <div class="tab-pane fade pt-3" id="profile-settings" role="tabpanel">
    
                    <!-- Settings Form -->
                    <form>
    
                      <div class="row mb-3">
                        <label for="fullName" class="col-md-4 col-lg-3 col-form-label">Email Notifications</label>
                        <div class="col-md-8 col-lg-9">
                          <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="changesMade" checked="">
                            <label class="form-check-label" for="changesMade">
                              Changes made to your account
                            </label>
                          </div>
                          <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="newProducts" checked="">
                            <label class="form-check-label" for="newProducts">
                              Information on new products and services
                            </label>
                          </div>
                          <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="proOffers">
                            <label class="form-check-label" for="proOffers">
                              Marketing and promo offers
                            </label>
                          </div>
                          <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="securityNotify" checked="" disabled="">
                            <label class="form-check-label" for="securityNotify">
                              Security alerts
                            </label>
                          </div>
                        </div>
                      </div>
    
                      <div class="text-center">
                        <button type="submit" class="btn btn-primary">Save Changes</button>
                      </div>
                    </form><!-- End settings Form -->
    
                  </div>
    
                  <div class="tab-pane fade pt-3" id="profile-change-password" role="tabpanel">
                    <!-- Change Password Form -->
                    <form>
    
                      <div class="row mb-3">
                        <label for="currentPassword" class="col-md-4 col-lg-3 col-form-label">Current Password</label>
                        <div class="col-md-8 col-lg-9">
                          <input name="password" type="password" class="form-control" id="currentPassword">
                        </div>
                      </div>
    
                      <div class="row mb-3">
                        <label for="newPassword" class="col-md-4 col-lg-3 col-form-label">New Password</label>
                        <div class="col-md-8 col-lg-9">
                          <input name="newpassword" type="password" class="form-control" id="newPassword">
                        </div>
                      </div>
    
                      <div class="row mb-3">
                        <label for="renewPassword" class="col-md-4 col-lg-3 col-form-label">Re-enter New Password</label>
                        <div class="col-md-8 col-lg-9">
                          <input name="renewpassword" type="password" class="form-control" id="renewPassword">
                        </div>
                      </div>
    
                      <div class="text-center">
                        <button type="submit" class="btn btn-primary">Change Password</button>
                      </div>
                    </form><!-- End Change Password Form -->
    
                  </div>

                  <div class="tab-pane fade pt-3" id="employees" role="tabpanel">
                    @if (!empty($employees))
                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th scope="col">#</th>
                                <th scope="col">Name</th>
                                <th scope="col">Mobile No.</th>
                                <th scope="col">Type</th>
                                <th scope="col">Status</th>
                                <th scope="col">Action</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($employees as $index => $employee)
                            <tr>
                                <td>{{$index + 1}}</td>
                                <td>{{ $employee->full_name }}</td>
                                <td>
                                    {{ $employee->mobile }}
                                </td>
                                <td>{{ $employee->employee_type }}</td>
                                @if ($employee->status == 1)
                                <td> <span class="badge bg-success">Active</span> </td>
                                @else
                                <td> <span class="badge bg-danger">Inactive</span> </td>
                                @endif
                                <td>
                                    @if ($employee->employee_type === 'Business user')
                                        <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" title="Login as Tenant"
                                            onclick="window.open('{{ route('admin.auto.login', $tenant->id) }}', '_blank')">
                                            <i class="text-primary bi bi-box-arrow-in-right"></i>
                                        </button>
                                        @else
                                        N/A
                                    @endif
                                </td>   
                                
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                    @else
                        <p>No customer data available.</p>
                    @endif
                  </div>

                  <div class="tab-pane fade pt-3" id="customers" role="tabpanel">
                    @if (!empty($customers))
                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th scope="col">#</th>
                                <th scope="col">Name</th>
                                <th scope="col">Phone</th>
                                <th scope="col">Email</th>
                                <th scope="col">Company</th>
                                <th scope="col">Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($customers as $index => $customer)
                            <tr>
                                <td>{{$index + 1}}</td>
                                <td>{{ $customer->name }}</td>
                                <td>
                                    {{ $customer->mobile }}
                                </td>
                                <td>{{ $customer->email }}</td>
                                <td>{{ $customer->company }}</td>
                                @if ($customer->status == 1)
                                <td> <span class="badge bg-success">Active</span> </td>
                                @else
                                <td> <span class="badge bg-danger">Inactive</span> </td>
                                @endif
                                
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                    @else
                        <p>No customer data available.</p>
                    @endif
                  </div>

                  <div class="tab-pane fade pt-3" id="call_history" role="tabpanel">
                    @if (!empty($callHistory ))
                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th scope="col">#</th>
                                <th scope="col">Name</th>
                                <th scope="col">Number</th>
                                <th scope="col">Call Type</th>
                                <th scope="col">Call Duration</th>
                                <th scope="col">Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($callHistory as $index => $callH)
                            <tr>
                                <td>{{$index + 1}}</td>
                                <td>{{ $callH->name }}</td>
                                <td>
                                    {{ $callH->number }}
                                </td>
                                <td>{{ $callH->call_type }}</td>
                                <td>{{ $callH->duration }}</td>
                                @if ($callH->status == 1)
                                <td> <span class="badge bg-success">Active</span> </td>
                                @else
                                <td> <span class="badge bg-danger">Inactive</span> </td>
                                @endif
                                
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                    @else
                        <p>No call history data available.</p>
                    @endif
                  </div>

                  <div class="tab-pane fade pt-3" id="customer_details" role="tabpanel">
                    @if (!empty($customerDetails ))
                    <table class="table table-bordered table-striped datatable">
                        <thead>
                            <tr>
                                <th scope="col">#</th>
                                <th scope="col">Business</th>
                                <th scope="col">Status Name</th>
                                <th scope="col">Mobile</th>
                                <th scope="col">Status</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($customerDetails as $index => $data)
                            <tr>
                                <td>{{$index + 1}}</td>
                                <td>
                                    @foreach($businessCategories as $business)
                                    @if($data->business_id == $business->id)
                                        {{ $business->name }}
                                    @endif
                                    @endforeach
                               </td>
                                <td>
                                    @foreach($statuses as $status)
                                    @if($data->status_id == $status->id)
                                        {{ $status->name }}
                                    @endif
                                    @endforeach
                                </td>
                                <!-- <td>@php
                                        $maskedNumber = isset($data->mobile)
                                            ? str_repeat('x', strlen($data->mobile) - 4) . substr($data->mobile, -4)
                                            : 'N/A';
                                    @endphp -->
                                    {{ $data->mobile }}
                                </td>
                                @if ($data->status == 1)
                                <td> <span class="badge bg-success">Active</span> </td>
                                @else
                                <td> <span class="badge bg-danger">Inactive</span> </td>
                                @endif
                                
                            </tr>
                            @endforeach
                        </tbody>
                    </table>
                    @else
                        <p>No customer details available.</p>
                    @endif
                  </div>
    
                </div><!-- End Bordered Tabs -->
    
              </div>
            </div>
    
          </div>
@endsection