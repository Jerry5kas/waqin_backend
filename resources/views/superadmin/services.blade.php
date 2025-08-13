@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Sales And Services</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Sales And Services</li>
            </ol>
        </nav>
    </div>

    {{-- modal for add sales and services start --}}
    <div class="modal fade" id="addSalesServiceModal" tabindex="-1" aria-labelledby="addSalesServiceModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="addSalesServiceModalLabel">Add Sales/Service</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <form class="row g-3" method="POST" action="{{ route('services.store') }}" id="salesServiceForm">
                        @csrf
                        <div class="col-12">
                            <label for="businessId" class="form-label">Business</label>
                            <select class="form-select" name="business_id" id="businessId" required>
                                <option value="" disabled selected>Select a Business</option>
                                @foreach($businessCategories as $business)
                                    <option value="{{ $business->id }}">{{ $business->name }}</option>
                                @endforeach
                            </select>
                        </div>

                        <div class="col-12">
                            <label for="subCategoryId" class="form-label">Subcategory</label>
                            <select class="form-select" name="id" id="subCategoryId" disabled required>
                                <option value="" disabled selected>Select a Subcategory</option>
                            </select>
                        </div>
    
                        <div class="col-12">
                            <label class="form-label">Type</label><br>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="radio" name="type" id="typeSales" value="sales" disabled>
                                <label class="form-check-label" for="typeSales">Sales</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="radio" name="type" id="typeService" value="service" disabled>
                                <label class="form-check-label" for="typeService">Service</label>
                            </div>
                            <div class="form-check form-check-inline">
                                <input class="form-check-input" type="radio" name="type" id="typeBoth" value="both" disabled>
                                <label class="form-check-label" for="typeBoth">Both</label>
                            </div>
                        </div>
    
                        <div id="salesFields" class="col-12 d-none">
                            <label for="productCategory" class="form-label">Product Category</label>
                            <div class="input-group mb-2">
                                <input type="text" class="form-control" name="product_category[]" id="productCategory">
                                <button type="button" class="btn btn-link text-danger removeField" style="display: none;">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                            <button type="button" class="btn btn-sm btn-link" id="addMoreSales">Add More Sales</button>
                        </div>
    
                        <div id="serviceFields" class="col-12 d-none">
                            <label for="serviceName" class="form-label">Service Name</label>
                            <div class="input-group mb-2">
                                <input type="text" class="form-control" name="service_name[]" id="serviceName">
                                <button type="button" class="btn btn-link text-danger removeField" style="display: none;">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                            <button type="button" class="btn btn-sm btn-link" id="addMoreService">Add More Services</button>
                        </div>
    
                        <div class="text-end mt-3">
                            <div id="validationError" class="text-start text-danger mt-2 d-none">Service and Product Category counts must match when "Both" is selected.</div>
                            <button type="submit" class="btn btn-primary" id="submitButton">Submit</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
    
    {{-- modal for add sales and services end --}}

    <div class="row">
        <div class="col-12">
            <div class="dashboard">
                <div class="card recent-sales overflow-auto">
                    <div class="card-body">
                        <div class="d-flex justify-content-between my-2">
                            <h5 class="card-title">Sales And Services</h5>
                            <button type="button" class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addSalesServiceModal">
                                Add Sales/Service
                            </button>
                        </div>
                        <table class="table table-bordered table-striped datatable">
                            <thead>
                                <tr>
                                    <th scope="col">#</th>
                                    <th scope="col">Business Name</th>
                                    <th scope="col">Sub Category Name</th>
                                    <th scope="col">Type</th>
                                    <th scope="col">Service</th>
                                    <th scope="col">Sales</th>
                                    <th scope="col">Status</th>
                                    <th scope="col">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($services as $index => $data)
                                <tr>
                                    <td>{{ $index + 1 }}</td>
                                    <td>
                                        @foreach($businessCategories as $business)
                                            @if($data->business_id == $business->id)
                                                {{ $business->name }}
                                            @endif
                                        @endforeach
                                    </td>
                                    <td>
                                        @php $found = false; @endphp
                                        @foreach($subcategories as $subcategory)
                                            @if($data->sub_category_id == $subcategory->id)
                                                {{ $subcategory->sub_category_name }}
                                                @php $found = true; @endphp
                                            @endif
                                        @endforeach
                                        @if(!$found)
                                            N/A
                                        @endif
                                    </td>

                                    <td>
                                        <span class="service-name" id="service-name-{{ $data->id }}">{{ $data->type }}</span>
                                    </td>
                                    <td>
                                        <span class="service-name" id="service-name-{{ $data->id }}">
                                            {{ $data->service ?? 'N/A' }}
                                        </span>
                                    </td>
                                    <td>
                                        <span class="service-name" id="service-name-{{ $data->id }}">
                                            {{ $data->product_category ?? 'N/A' }}</span>
                                    </td>
                                    @if ($data->status == 1)
                                    <td><span class="badge bg-success">Active</span></td>
                                    @else
                                    <td><span class="badge bg-danger">Inactive</span></td>
                                    @endif
                                    <td>
                                        <div class="d-flex justify-content-center align-items-center">
                                            <a class="icon edit-icon m-2" href="#" data-id="{{ $data->id }}" data-action="edit" title="Edit">
                                                <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                            </a>
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                                    onclick="confirmAction('delete', '{{ route('services.destroy', $data->id) }}', 'POST')">
                                                <i class="text-danger bi bi-trash3-fill"></i>
                                            </button>
                                            @if ($data->status == 1)
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                    onclick="confirmAction('deactivate', '{{ route('services.deactivate', $data->id) }}', 'GET')">
                                                <i class="text-danger bi bi-x-circle-fill"></i>
                                            </button>
                                            @else
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                    onclick="confirmAction('activate', '{{ route('services.activate', $data->id) }}', 'GET')">
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
</div>
<script>
    $(document).ready(function () {
    $('#businessId').change(function () {
        var businessId = $(this).val();
        $('#subCategoryId').prop('disabled', true).html('<option value="" selected disabled>Loading...</option>');

        if (businessId) {
            $.ajax({
                url: '/get-subcategories/' + businessId,
                type: 'GET',
                success: function (response) {
                    $('#subCategoryId').html('<option value="" selected disabled>Select a Subcategory</option>');
                    if (response.length > 0) {
                        $.each(response, function (key, subcategory) {
                            $('#subCategoryId').append('<option value="' + subcategory.id + '">' + subcategory.sub_category_name + '</option>');
                        });
                        $('#subCategoryId').prop('disabled', false);
                    } else {
                        $('#subCategoryId').html('<option value="0" selected>No Subcategories</option>');
                        $('#subCategoryId').prop('disabled', false);
                    }
                }
            });
        } else {
            $('#subCategoryId').html('<option value="" selected disabled>Select a Subcategory</option>').prop('disabled', true);
        }
    });
});
</script>
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
                            Are you sure you want to ${action} this service?
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

    // script for add sales/service dynamic form handling

    document.addEventListener('DOMContentLoaded', function () {
    const businessSelect = document.getElementById('businessId');
    const typeRadioButtons = document.querySelectorAll('input[name="type"]');
    const salesFields = document.getElementById('salesFields');
    const serviceFields = document.getElementById('serviceFields');
    const validationError = document.getElementById('validationError');
    const submitButton = document.getElementById('submitButton');

    function updateDeleteButtons(container) {
        const deleteButtons = container.querySelectorAll('.removeField');
        deleteButtons.forEach(button => {
            button.style.display = deleteButtons.length > 1 ? 'inline-block' : 'none';
        });
    }

    function attachEventListeners() {
        document.getElementById('addMoreSales').addEventListener('click', function () {
            const newField = document.createElement('div');
            newField.className = 'input-group mb-2';
            newField.innerHTML = `
                <input type="text" class="form-control" name="product_category[]" id="productCategory">
                <button type="button" class="btn btn-link text-danger removeField">
                    <i class="bi bi-trash"></i>
                </button>
            `;
            salesFields.insertBefore(newField, this);
            updateDeleteButtons(salesFields);
            attachRemoveFieldListeners(salesFields);
        });

        document.getElementById('addMoreService').addEventListener('click', function () {
            const newField = document.createElement('div');
            newField.className = 'input-group mb-2';
            newField.innerHTML = `
                <input type="text" class="form-control" name="service_name[]" id="serviceName">
                <button type="button" class="btn btn-link text-danger removeField">
                    <i class="bi bi-trash"></i>
                </button>
            `;
            serviceFields.insertBefore(newField, this);
            updateDeleteButtons(serviceFields);
            attachRemoveFieldListeners(serviceFields);
        });

        typeRadioButtons.forEach(radio => {
            radio.addEventListener('change', function () {
                salesFields.classList.add('d-none');
                serviceFields.classList.add('d-none');
                validationError.classList.add('d-none');

                if (this.value === 'sales') {
                    salesFields.classList.remove('d-none');
                } else if (this.value === 'service') {
                    serviceFields.classList.remove('d-none');
                } else if (this.value === 'both') {
                    salesFields.classList.remove('d-none');
                    serviceFields.classList.remove('d-none');
                }
            });
        });
    }

    function attachRemoveFieldListeners(container) {
        container.querySelectorAll('.removeField').forEach(button => {
            button.addEventListener('click', function () {
                this.closest('.input-group').remove();
                updateDeleteButtons(container);
            });
        });
    }

    function validateForm() {
        const selectedType = document.querySelector('input[name="type"]:checked');
        if (selectedType && selectedType.value === 'both') {
            const serviceCount = serviceFields.querySelectorAll('input[name="service_name[]"]').length;
            const productCount = salesFields.querySelectorAll('input[name="product_category[]"]').length;
            if (serviceCount !== productCount) {
                validationError.classList.remove('d-none');
                return false;
            } else {
                validationError.classList.add('d-none');
            }
        }
        return true;
    }

    businessSelect.addEventListener('change', function () {
        if (this.value) {
            typeRadioButtons.forEach(radio => {
                radio.disabled = false;
            });
        } else {
            typeRadioButtons.forEach(radio => {
                radio.checked = false;
                radio.disabled = true;
            });
            salesFields.classList.add('d-none');
            serviceFields.classList.add('d-none');
        }
    });

    document.getElementById('salesServiceForm').addEventListener('submit', function (e) {
        if (!validateForm()) {
            e.preventDefault();
        }
    });

    attachEventListeners();
});

</script>

@endsection
