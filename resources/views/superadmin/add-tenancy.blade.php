@extends('layouts.superadmin')
@section('content')
<div class="container mt-5">
    <div class="card">
        <div class="card-body">
            <div class="pagetitle">
                <h1>Add Tenancy</h1>
                <nav>
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item"><a href="#">Home</a></li>
                        <li class="breadcrumb-item active">Add Tenancy</li>
                    </ol>
                </nav>
            </div>
            <!-- Stepper -->
            <div id="stepper" class="bs-stepper">
                <div class="bs-stepper-header" role="tablist">
                    <div class="step" data-target="#step-1">
                        <button type="button" class="step-trigger" role="tab" id="step-1-trigger"
                            aria-controls="step-1">
                            <span class="bs-stepper-circle">1</span>
                            <span class="bs-stepper-label">Step 1</span>
                        </button>
                    </div>
                    <div class="line"></div>
                    <div class="step" data-target="#step-2">
                        <button type="button" class="step-trigger" role="tab" id="step-2-trigger"
                            aria-controls="step-2">
                            <span class="bs-stepper-circle">2</span>
                            <span class="bs-stepper-label">Step 2</span>
                        </button>
                    </div>
                    <div class="line"></div>
                    <div class="step" data-target="#step-3">
                        <button type="button" class="step-trigger" role="tab" id="step-3-trigger"
                            aria-controls="step-3">
                            <span class="bs-stepper-circle">3</span>
                            <span class="bs-stepper-label">Step 3</span>
                        </button>
                    </div>
                    <div class="line"></div>
                    <div class="step" data-target="#step-4">
                        <button type="button" class="step-trigger" role="tab" id="step-4-trigger"
                            aria-controls="step-4">
                            <span class="bs-stepper-circle">4</span>
                            <span class="bs-stepper-label">Step 4</span>
                        </button>
                    </div>
                </div>
                <div class="bs-stepper-content">
                    <form method="POST" action="{{ route('submittenanct') }}" enctype="multipart/form-data">
                        @csrf
                        <!-- Step 1 -->
                        <div id="step-1" class="content" role="tabpanel" aria-labelledby="step-1-trigger">
                            <div class="row row-cols-md-2 row-cols-1 g-4 d-flex mt-2">
                                <div class="col">
                                    <div class="form-group">
                                        <label for="tenant_name">Firstname</label>
                                        <input type="text" class="form-control" id="tenant_name" name="tenant_name"
                                            required>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="tenant_name">Lastname</label>
                                        <input type="text" class="form-control" id="tenant_name" name="tenant_name"
                                            required>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="email">Email</label>
                                        <input type="email" class="form-control" id="email" name="email" required>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="mobile">Phone No.</label>
                                        <input type="number" class="form-control" id="mobile" name="mobile" required>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="pin">PIN</label>
                                        <input type="password" class="form-control" id="pin" name="pin" required>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="confirm_pin">Confirm PIN</label>
                                        <input type="password" class="form-control" id="confirm_pin" name="confirm_pin"
                                            required>
                                    </div>
                                </div>
                            </div>
                            <button type="button" class="btn btn-primary mt-3" onclick="stepper.next()">Next</button>
                        </div>
                        <!-- Step 2 -->
                        <div id="step-2" class="content" role="tabpanel" aria-labelledby="step-2-trigger">
                            <div class="row row-cols-md-2 row-cols-1 g-4 d-flex mt-2">
                                <div class="col">
                                    <div class="form-group">
                                        <label for="business">Select Business</label>
                                        <select class="form-select" id="business" name="business" required
                                            onchange="fetchServices(this.value)">
                                            <option value="" disabled selected>Select a Business</option>
                                            @foreach($data['businesscategories'] as $business)
                                            <option value="{{ $business->id }}">{{ $business->name }}</option>
                                            @endforeach
                                        </select>
                                    </div>
                                </div>
                                <div class="col">
                                    <div class="form-group">
                                        <label for="service">Select Service</label>
                                        <select class="form-select" id="service" name="service" required>
                                            <option value="" disabled selected>Select a Service</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                            <button type="button" class="btn btn-secondary mt-3"
                                onclick="stepper.previous()">Previous</button>
                            <button type="button" class="btn btn-primary mt-3" onclick="stepper.next()">Next</button>
                        </div>
                        <!-- Step 3 -->
                        <div id="step-3" class="content" role="tabpanel" aria-labelledby="step-3-trigger">
                            <div id="form-container" class="row row-cols-md-2 row-cols-1 g-4 d-flex mt-2"></div>
                            <button type="button" class="btn btn-secondary mt-3"
                                onclick="stepper.previous()">Previous</button>
                            <button type="button" class="btn btn-primary mt-3" onclick="stepper.next()">Next</button>
                        </div>
                        <!-- Step 4 -->
                        <div id="step-4" class="content" role="tabpanel" aria-labelledby="step-4-trigger">
                            <div class="row row-cols-md-2 row-cols-1 g-4 d-flex mt-2">
                                <div class="col">
                                    <label for="country" class="form-label">Country<sup
                                            class="text-danger">*</sup></label>
                                    <select id="country" class="form-select" required name="country">
                                        <option value="">Select Country</option>
                                        @foreach($data['countries'] as $country)
                                        <option value="{{ $country->id }}">{{ $country->country_name }}</option>
                                        @endforeach
                                    </select>
                                </div>
                                <div class="col">
                                    <label for="state" class="form-label">State<sup class="text-danger">*</sup></label>
                                    <select id="state" class="form-select" required name="state">
                                        <option value="">Select State</option>
                                    </select>
                                </div>
                                <div class="col">
                                    <label for="city" class="form-label">City<sup class="text-danger">*</sup></label>
                                    <select id="city" class="form-select" required name="city">
                                        <option value="">Select City</option>
                                    </select>
                                </div>
                                <div class="col">
                                    <label for="place">Place Name</label>
                                    <input type="text" class="form-control" id="place" name="place"
                                        required>
                                </div>
                            </div>
                            <button type="button" class="btn btn-secondary mt-3"
                                onclick="stepper.previous()">Previous</button>
                            <button type="submit" class="btn btn-primary mt-3">Submit</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection
@section('script')
<script>
    window.stepper = new Stepper(document.querySelector('.bs-stepper'));

    function fetchServices(businessId) {
        fetch(`/services/${businessId}`)
            .then(response => {
                if (!response.ok) {
                    throw new Error('Network response was not ok');
                }
                return response.json();
            })
            .then(data => {
                const serviceSelect = document.getElementById('service');
                serviceSelect.innerHTML = '<option value="" disabled selected>Select a Service</option>';
                data.forEach(service => {
                    const option = document.createElement('option');
                    option.value = service.id;
                    option.textContent = service.service_name;
                    serviceSelect.appendChild(option);
                });
            })
            .catch(error => console.error('Error fetching services:', error));
    }

$(document).on('change', '#business', function() {
    var districtId = $(this).val();

    if (districtId) {
        $.post(
            'getformdatabyid',
            {
                id: districtId,
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function(data) {
                console.log("Data received:", data); // Log the received data
                
                // Check if data is an object and has a data key
                if (data && Array.isArray(data.data)) {
                    // Clear previous form elements
                    $('#form-container').empty();
                    // Call the function to append form elements
                    appendFormElements(data.data, 'form-container');
                } else {
                    console.error("Unexpected data format:", data); // Log an error if the data format is unexpected
                }
            }
        ).fail(function(jqXHR, textStatus, errorThrown) {
            console.error('Error:', textStatus, errorThrown); // Log any errors
        });
    }
});

function appendFormElements(data, containerId) {
    var container = $('#' + containerId);
    var formBuilder = {};

    container.empty(); // Clear any existing content

    data.forEach(function(item) {
        var formGroup = $('<div class="form-group"></div>');
        var label = $('<label></label>').attr('for', item.name).text(item.label);

        var input;
        switch (item.type) {
            case 'text':
            case 'email':
            case 'password':
            case 'number':
            case 'date':
                input = $('<input>')
                    .attr('type', item.type)
                    .attr('class', item.className || 'form-control')
                    .attr('id', item.name)
                    .attr('name', 'formBuilder[' + item.name + ']')
                    .attr('value', item.value || '')
                    .attr('required', item.required ? 'required' : false)
                    .attr('readonly', item.access ? 'readonly' : false); // Handle access attribute
                break;
            case 'textarea':
                input = $('<textarea>')
                    .attr('class', item.className || 'form-control')
                    .attr('id', item.name)
                    .attr('name', 'formBuilder[' + item.name + ']')
                    .attr('required', item.required ? 'required' : false)
                    .val(item.value || '');
                break;
            case 'select':
                input = $('<select>')
                    .attr('class', item.className || 'form-control')
                    .attr('id', item.name)
                    .attr('name', 'formBuilder[' + item.name + ']')
                    .attr('required', item.required ? 'required' : false)
                    .attr('multiple', item.multiple ? 'multiple' : false);

                if (item.values && Array.isArray(item.values)) {
                    item.values.forEach(function(option) {
                        var optionElement = $('<option>')
                            .attr('value', option.value)
                            .text(option.label)
                            .prop('selected', option.selected);
                        input.append(optionElement);
                    });
                } else {
                    console.error('No values provided for select input:', item); // Log missing values
                }
                break;           
            default:
                console.error('Unsupported input type:', item.type);
                return;
        }

        formGroup.append(label).append(input);
        container.append(formGroup);

        formBuilder[item.name] = item;
    });

    console.log("FormBuilder Array:", formBuilder);
}


$('#tenantForm').on('submit', function(event) {
    event.preventDefault();

    var formData = $(this).serializeArray();
    var jsonData = {};

    $.each(formData, function() {
        jsonData[this.name] = this.value || '';
    });

    console.log(JSON.stringify(jsonData)); // Output the JSON data to console

    // Perform the AJAX request with the JSON data
    $.ajax({
        url: $(this).attr('action'),
        method: 'POST',
        contentType: 'application/json',
        data: JSON.stringify(jsonData),
        headers: {
            'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
        },
        success: function(response) {
            console.log('Form submitted successfully:', response);
        },
        error: function(jqXHR, textStatus, errorThrown) {
            console.error('Form submission error:', textStatus, errorThrown);
        }
    });
});


$(document).on("change", "#country", function () {
    var countryId = $(this).val();
    if (countryId) {
        $.post(
            'tenancystates',
            {
                country_id: countryId,
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function (data) {
                $("#state").empty().append('<option value="">Select State</option>');
                $("#city").empty().append('<option value="">Select City</option>');

                $.each(data, function (key, value) {
                    $("#state").append(
                        '<option value="' + value.id + '">' + value.state_name + "</option>"
                    );
                });
            }
        ).fail(function (jqXHR, textStatus, errorThrown) {
            console.error('Error:', textStatus, errorThrown);
        });
    } else {
        $("#state").empty().append('<option value="">Select State</option>');
        $("#city").empty().append('<option value="">Select City</option>');
    }
});

$(document).on("change", "#state", function () {
    var stateId = $(this).val();

    if (stateId) {
        $.post(
            'tenancycities',
            {
                state_id: stateId,
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function (data) {
                $("#city").empty().append('<option value="">Select City</option>');

                $.each(data, function (key, value) {
                    $("#city").append(
                        '<option value="' + value.id + '">' + value.city_name + "</option>"
                    );
                });
            }
        ).fail(function (jqXHR, textStatus, errorThrown) {
            console.error('Error:', textStatus, errorThrown);
        });
    } else {
        $("#city").empty().append('<option value="">Select City</option>');
    }
});
           
</script>
@endsection