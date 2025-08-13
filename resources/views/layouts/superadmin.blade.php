<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="utf-8">
    <meta content="width=device-width, initial-scale=1.0" name="viewport">
    <title>CRM</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <meta content="" name="description">
    <meta content="" name="keywords">
    <!-- Favicons -->
    <link href="{{ asset('img/favicon.png')}}" rel="icon">
    <link href="{{ asset('img/apple-touch-icon.png')}}" rel="apple-touch-icon">
    <!-- Google Fonts -->
    <link href="https://fonts.gstatic.com" rel="preconnect">
    <link href="https://fonts.bunny.net/css?family=Nunito" rel="stylesheet">
    <!-- Vendor CSS Files -->
    <link rel="stylesheet" href="{{ asset('vendor/bootstrap/css/bootstrap.min.css') }}">
    <link rel="stylesheet" href="{{ asset('vendor/bootstrap-icons/bootstrap-icons.css')}}">
    <link rel="stylesheet" href="{{ asset('vendor/boxicons/css/boxicons.min.css')}}">
    <link rel="stylesheet" href="{{ asset('vendor/quill/quill.snow.css')}}">
    <link rel="stylesheet" href="{{ asset('vendor/quill/quill.bubble.css')}}">
    <link rel="stylesheet" href="{{ asset('vendor/remixicon/remixicon.css')}}">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery-confirm/3.3.2/jquery-confirm.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" />
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.7/css/dataTables.bootstrap5.min.css')}}">
    <link href="{{ asset('css/style.css')}}" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bs-stepper/dist/css/bs-stepper.min.css" rel="stylesheet">
    {{-- <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/simple-datatables@latest/dist/style.css"> --}}
    <link href="{{ asset('css/toastr.min.css')}}" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.7.0.js"></script>
</head>

<body>
    <!-- ======= Header ======= -->
    <header id="header" class="header fixed-top d-flex align-items-center">
        <div class="d-flex align-items-center justify-content-between">
            <a href="index.html" class="logo d-flex align-items-center">
                <img src="{{ asset('img/logo.png')}}" alt="">
                {{-- <span class="d-none d-lg-block">NiceAdmins</span> --}}
            </a>
            <i class="bi bi-list toggle-sidebar-btn"></i>
        </div><!-- End Logo -->
        <div class="search-bar">
            <form class="search-form d-flex align-items-center" method="POST" action="#">
                <input type="text" name="query" placeholder="Search" title="Enter search keyword">
                <button type="submit" title="Search"><i class="bi bi-search"></i></button>
            </form>
        </div><!-- End Search Bar -->
        <nav class="header-nav ms-auto">
            <ul class="d-flex align-items-center">
                <li class="nav-item dropdown pe-3">
                    <a class="nav-link nav-profile d-flex align-items-center pe-0" href="#" data-bs-toggle="dropdown">
                        <i class="bi bi-person"></i>
                        <span class="d-none d-md-block dropdown-toggle ps-2">{{ Auth::user()->name }}</span>
                    </a><!-- End Profile Iamge Icon -->

                    <ul class="dropdown-menu dropdown-menu-end dropdown-menu-arrow profile">
                        <li>
                        <a class="dropdown-item d-flex align-items-center" href="{{ route('apks.index') }}">
                            <i class="bi bi-list-stars"></i>
                            <span>APK Lists</span>
                        </a>
                            <a class="dropdown-item d-flex align-items-center" href="#">
                                <a class="dropdown-item" href="{{ route('logout') }}" onclick="event.preventDefault();
                   document.getElementById('logout-form').submit();"><i class="bi bi-box-arrow-right"></i>
                                    {{ __('Logout') }}
                                </a>
                                <form id="logout-form" action="{{ route('logout') }}" method="POST" class="d-none">
                                    @csrf
                                </form>
                            </a>
                        </li>
                    </ul><!-- End Profile Dropdown Items -->
                </li><!-- End Profile Nav -->
            </ul>
        </nav><!-- End Icons Navigation -->

    </header><!-- End Header -->

    <!-- ======= Sidebar ======= -->
<aside id="sidebar" class="sidebar d-flex flex-column justify-content-between">
    <ul class="sidebar-nav" id="sidebar-nav">

        @if(Auth::user()->role == 2 || ($menuPermissions['Dashboard'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('dashboard') ? 'active' : 'collapsed' }}" href="{{ route('dashboard') }}">
                <i class="bi bi-grid"></i>
                <span>Dashboard</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Tenants'] ?? false))
        <li class="nav-item">
            <a class="nav-link" data-bs-toggle="collapse" href="#tables-nav" aria-expanded="{{ request()->routeIs('tenants') ? 'true' : 'false' }}">
                <i class="bi bi-people"></i><span>Tenants</span><i class="bi bi-chevron-down ms-auto"></i>
            </a>
            <ul id="tables-nav" class="nav-content collapse {{ request()->routeIs('tenants') ? 'show' : '' }}" data-bs-parent="#sidebar-nav">
                <li>
                    <a class="nav-link {{ request()->routeIs('tenants') ? 'active' : '' }}" href="{{ route('tenants') }}">
                        <i class="bi bi-circle"></i><span>Tenants List</span>
                    </a>
                </li>
            </ul>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Channel Partners'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('channel-partner') ? 'active' : 'collapsed' }}" href="{{ route('channel-partner') }}">
                <i class="bi bi-people"></i>
                <span>Channel Partners</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Businesses'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('business-categories') ? 'active' : 'collapsed' }}" href="{{ route('business-categories') }}">
                <i class="bi bi-list-stars"></i>
                <span>Businesses</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Business Sub Categories'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('businessSubCategories') ? 'active' : 'collapsed' }}" href="{{ route('businessSubCategories') }}">
                <i class="bi bi-list-stars"></i>
                <span>Business Sub Categories</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Marketings'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('marketing') ? 'active' : 'collapsed' }}" href="{{ route('marketing') }}">
                <i class="bi bi-megaphone"></i>
                <span>Marketings</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Sales and Services'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('services') ? 'active' : 'collapsed' }}" href="{{ route('services') }}">
                <i class="bi bi-list-stars"></i>
                <span>Sales and Services</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Status'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('status') ? 'active' : 'collapsed' }}" href="{{ route('status') }}">
                <i class="bi bi-list-stars"></i>
                <span>Status</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Contact Group'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('contactGroup') ? 'active' : 'collapsed' }}" href="{{ route('contactGroup') }}">
                <i class="bi bi-diagram-3"></i>
                <span>Contact Group</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Form Builder'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('form-builder') || request()->routeIs('ent-form-builder') ? '' : 'collapsed' }}" data-bs-toggle="collapse" href="#form-builder-nav" aria-expanded="{{ request()->routeIs('form-builder') || request()->routeIs('ent-form-builder') ? 'true' : 'false' }}">
                <i class="bi bi-code-square"></i><span>Form Builder</span><i class="bi bi-chevron-down ms-auto"></i>
            </a>
            <ul id="form-builder-nav" class="nav-content collapse {{ request()->routeIs('form-builder') || request()->routeIs('ent-form-builder') ? 'show' : '' }}" data-bs-parent="#sidebar-nav">
                <li>
                    <a class="nav-link {{ request()->routeIs('form-builder') ? 'active' : '' }}" href="{{ route('form-builder') }}">
                        <i class="bi bi-circle"></i><span>Basic Form</span>
                    </a>
                </li>
                <li>
                    <a class="nav-link {{ request()->routeIs('ent-form-builder') ? 'active' : '' }}" href="{{ route('ent-form-builder') }}">
                        <i class="bi bi-circle"></i><span>ENT Form</span>
                    </a>
                </li>
            </ul>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Query Builder'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('query_builder') ? 'active' : 'collapsed' }}" href="{{ route('query_builder') }}">
                <i class="bi bi-code-square"></i>
                <span>Query Builder</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Query Mapping'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('query_mapping') ? 'active' : 'collapsed' }}" href="{{ route('query_mapping') }}">
                <i class="bi bi-code-square"></i>
                <span>Query Mapping</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['FCM Notification'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('fcm_notification') ? 'active' : 'collapsed' }}" href="{{ route('fcm_notification') }}">
                <i class="bi bi-bell"></i>
                <span>FCM Notification</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['User Permission'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('menu-permissions.index') ? 'active' : 'collapsed' }}" href="{{ route('menu-permissions.index') }}">
                <i class="bi bi-people"></i>
                <span>User Permission</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Feature Access'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('feature-access') ? 'active' : 'collapsed' }}" href="{{ route('feature-access') }}">
                <i class="bi bi-shield-lock"></i>
                <span>Feature Access</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Leads Master'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('leads-master') ? 'active' : 'collapsed' }}" href="{{ route('leads-master') }}">
                <i class="bi bi-person-lines-fill"></i>
                <span>Leads Master</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Sync Request'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('sync') ? 'active' : 'collapsed' }}" href="{{ route('sync') }}">
                <i class="bi bi-arrow-repeat"></i>
                <span>Sync Request</span>
            </a>
        </li>
        @endif

        @if(Auth::user()->role == 2 || ($menuPermissions['Manage Packages'] ?? false))
        <li class="nav-item">
            <a class="nav-link {{ request()->routeIs('features') || request()->routeIs('packages') || request()->routeIs('durations') ? 'active' : 'collapsed' }}" data-bs-toggle="collapse" href="#package-nav" aria-expanded="{{ request()->routeIs('features') || request()->routeIs('packages') || request()->routeIs('durations') ? 'true' : 'false' }}">
                <i class="bi bi-box-seam"></i><span>Manage Packages</span><i class="bi bi-chevron-down ms-auto"></i>
            </a>
            <ul id="package-nav" class="nav-content collapse {{ request()->routeIs('features') || request()->routeIs('packages') || request()->routeIs('durations') ? 'show' : '' }}" data-bs-parent="#sidebar-nav">
                <li>
                    <a class="nav-link {{ request()->routeIs('features') ? 'active' : '' }}" href="{{ route('features') }}">
                        <i class="bi bi-circle"></i><span>Features</span>
                    </a>
                </li>
                <li>
                    <a class="nav-link {{ request()->routeIs('packages') ? 'active' : '' }}" href="{{ route('packages') }}">
                        <i class="bi bi-circle"></i><span>Packages</span>
                    </a>
                </li>
                <li>
                    <a class="nav-link {{ request()->routeIs('durations') ? 'active' : '' }}" href="{{ route('durations') }}">
                        <i class="bi bi-circle"></i><span>Durations</span>
                    </a>
                </li>
            </ul>
        </li>
        @endif

    </ul>

    <div class="text-center py-3 small text-muted border-top">
        V {{ env('APP_VERSION') }}
    </div>
</aside>
<!-- End Sidebar-->

    <main id="main" class="main">
        @yield('content')
    </main>

    <a href="#" class="back-to-top d-flex align-items-center justify-content-center"><i
            class="bi bi-arrow-up-short"></i></a>
    <!-- Vendor JS Files -->
    
    <script src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.11.2/jquery-ui.min.js"></script>
    <script src="{{ asset('vendor/formBuilder/dist/form-builder.min.js')}}"></script>
    <script src="{{ asset('vendor/formBuilder/dist/form-render.min.js')}}"></script>
    <script src="{{ asset('vendor/bootstrap/js/bootstrap.bundle.min.js')}}"></script>
    <script src="{{ asset('vendor/quill/quill.min.js')}}"></script>
    <script src="https://cdn.jsdelivr.net/npm/bs-stepper/dist/js/bs-stepper.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery-confirm/3.3.2/jquery-confirm.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.7/js/dataTables.bootstrap5.min.js"></script>
    <!-- Template Main JS File -->
    <script src="{{ asset('js/main.js')}}"></script>
    <script src="{{ asset('js/toastr.min.js')}}"></script>
    <script>
        toastr.options = {
            "closeButton": true,  
            "debug": false,
            "newestOnTop": true,
            "progressBar": true,
            "positionClass": "toast-top-right",
            "preventDuplicates": false,
            "onclick": null,
            "showDuration": "300",
            "hideDuration": "1000",
            "timeOut": "5000",
            "extendedTimeOut": "1000",
            "showEasing": "swing",
            "hideEasing": "linear",
            "showMethod": "fadeIn",
            "hideMethod": "fadeOut"
        };
    
        @if (session('success'))
        toastr.success("{{ session('success') }}");
    @elseif (session('error'))
        toastr.error("{{ session('error') }}");
    @elseif (session('info'))
        toastr.info("{{ session('info') }}");
    @elseif (session('warning'))
        toastr.warning("{{ session('warning') }}");
    @endif
    function showMessage(type, message) {
        switch (type) {
            case 'success':
                toastr.success(message);
                break;
            case 'error':
                toastr.error(message);
                break;
            default:
                console.warn('Unknown message type:', type);
                break;
        }
    }
    </script>
    <script>
        $(document).ready(function() {
            new DataTable('.datatable');
        });

        function getSecureURL() {
            var hostname = window.location.hostname;
            var port = '8000';
            return 'https://' + hostname + ':' + port;
        }
    </script>
    <script>
         document.addEventListener('DOMContentLoaded', function () {
        var collapseElement = document.getElementById('tables-nav');
        if (collapseElement) {
            var bsCollapse = new bootstrap.Collapse(collapseElement, {
                toggle: false
            });
        }
    });
    </script>
    @yield('script');
    @stack('scripts')
</body>

</html>
