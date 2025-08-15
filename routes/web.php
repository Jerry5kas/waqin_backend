<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Response;
use App\Http\Controllers\PhonePeController;
use App\Http\Controllers\EntFormBuilderController;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "web" middleware group. Make something great!
|
*/

Route::get('/', function () {
    return view('auth/login');
});
Route::get('/phonepe/redirect', [PhonePeController::class, 'redirectHandler']);

    Route::get('/apks/{id}/download', [ApkController::class, 'showDownloadForm'])->name('apks.download.form');
    Route::post('/apks/{id}/download', [ApkController::class, 'download'])->name('apks.download');

Auth::routes();
// Authenticated Routes
Route::middleware('auth')->group(function () {
    Route::get('/business-categories', [BusinessCategoryController::class, 'index'])->name('business-categories');
    Route::post('/AddbusinessCategories', [BusinessCategoryController::class, 'store']);
    Route::get('/businessCategories/{id}/activate', [BusinessCategoryController::class, 'activate'])->name('businessCategories.activate');
    Route::get('/businessCategories/{id}/deactivate', [BusinessCategoryController::class, 'deactivate'])->name('businessCategories.deactivate');
    Route::delete('/business-categories/{id}', [BusinessCategoryController::class, 'destroy'])->name('businessCategories.destroy');
    Route::put('/business-categories/{id}', [BusinessCategoryController::class, 'update'])->name('business-categories.update');

    Route::get('/form-builder', [FormBuilderController::class, 'formBuilder'])->name('form-builder');
    Route::get('/add_builder_form', [FormBuilderController::class, 'addformbuilder'])->name('add_builder_form');
    Route::post('/editformbuilder', [FormBuilderController::class, 'editformbuilder'])->name('editformbuilder');
    Route::post('/saveformbuilder', [FormBuilderController::class, 'saveformbuilder'])->name('saveformbuilder');
    Route::get('/editfrm', [FormBuilderController::class, 'editfrm'])->name('editfrm');
    Route::post('/changeStatus', [FormBuilderController::class, 'changeStatus'])->name('changeStatus');
    Route::post('/deleteMasterData', [FormBuilderController::class, 'deleteMasterData'])->name('deleteMasterData');
    Route::get('/formbuilder/{id}/activate', [FormBuilderController::class, 'activate'])->name('formbuilder.activate');
    Route::get('/formbuilder/{id}/deactivate', [FormBuilderController::class, 'deactivate'])->name('formbuilder.deactivate');


   //tenancy routes
    Route::get('/dashboard', [TenancyController::class, 'dashboardview'])->name('dashboard');
    // Route::get('/tenants', [TenancyController::class, 'index'])->name('tenants');
    // Route::get('/view-tenancy', [TenancyController::class, 'index'])->name('view-tenancy');
    // Route::get('/add_tenancy_form', [TenancyController::class, 'addFormTenancy'])->name('add_tenancy_form');
    // Route::get('/add-tenancy', [TenancyController::class, 'create'])->name('tenancy.create');
    // Route::post('/add-tenancy', [TenancyController::class, 'store'])->name('tenancy.store');
    // Route::post('/getformdatabyid', [TenancyController::class, 'GetFormdataByBusiness'])->name('getformdatabyid');
    // Route::post('/tenancystates', [TenancyController::class, 'getStates'])->name('tenancystates');
    // Route::post('/tenancycities', [TenancyController::class, 'getCities'])->name('tenancycities');
    // Route::get('/services/{businessId}', [TenancyController::class, 'getServicesByBusiness']);
    // Route::post('/submittenanct', [TenancyController::class, 'SubmitTenanct'])->name('submittenanct');


    // services route 
    Route::get('/services', [ServiceController::class, 'index'])->name('services');
    Route::get('/services/{id}/deactivate', [ServiceController::class, 'deactivate'])->name('services.deactivate');
    Route::get('/services/{id}/activate', [ServiceController::class, 'activate'])->name('services.activate');
    Route::delete('services/{id}', [ServiceController::class, 'destroy'])->name('services.destroy');
    Route::post('/AddService', [ServiceController::class, 'store'])->name('services.store');
    Route::put('/services/{id}', [ServiceController::class, 'update'])->name('services.update');
    Route::get('/get-subcategories/{businessId}', [ServiceController::class, 'getSubcategoriesByBusiness']);

    //countries route
    Route::get('/countries', [CountryController::class, 'index'])->name('countries');
    Route::post('/countries', [CountryController::class, 'store'])->name('countries.store');
    Route::put('/countries/{country}', [CountryController::class, 'update'])->name('countries.update');
    Route::delete('/countries/{country}', [CountryController::class, 'destroy'])->name('countries.destroy');
    Route::get('/countries/activate/{country}', [CountryController::class, 'activate'])->name('countries.activate');
    Route::get('/countries/deactivate/{country}', [CountryController::class, 'deactivate'])->name('countries.deactivate');

    //states routes
    Route::get('/states', [StateController::class, 'index'])->name('states');
    Route::post('/states', [StateController::class, 'store'])->name('states.store');
    Route::put('/states/{state}', [StateController::class, 'update'])->name('states.update');
    Route::get('/states/{state}/edit', [StateController::class, 'edit'])->name('states.edit');
    Route::delete('/states/{state}', [StateController::class, 'destroy'])->name('states.destroy');
    Route::get('/states/activate/{state}', [StateController::class, 'activate'])->name('states.activate');
    Route::get('/states/deactivate/{state}', [StateController::class, 'deactivate'])->name('states.deactivate');
    Route::get('/states/{countryId}', [StateController::class, 'getStatesByCountry']);

    //cities route
    Route::get('/cities', [CityController::class, 'index'])->name('cities');
    Route::put('cities/{city}', [CityController::class, 'update'])->name('cities.update');
    Route::get('cities/{city}/edit', [CityController::class, 'edit'])->name('cities.edit');
    Route::post('/cities', [CityController::class, 'store'])->name('cities.store');
    Route::delete('/cities/{city}', [CityController::class, 'destroy'])->name('cities.destroy');
    Route::get('/cities/activate/{city}', [CityController::class, 'activate'])->name('cities.activate');
    Route::get('/cities/deactivate/{city}', [CityController::class, 'deactivate'])->name('cities.deactivate');
    Route::get('/states/{countryId}', [StateController::class, 'getStatesBasedOnCountry']);
    Route::get('/services/{businessId}', [TenancyController::class, 'getServicesByBusiness']);

    // status routes
    Route::get('/status', [StatusController::class, 'index'])->name('status');
    Route::post('/AddStatus', [StatusController::class, 'store']);
    Route::get('/status/{id}/activate', [StatusController::class, 'activate'])->name('status.activate');
    Route::get('/status/{id}/deactivate', [StatusController::class, 'deactivate'])->name('status.deactivate');
    Route::delete('/status/{id}', [StatusController::class, 'destroy'])->name('status.destroy');
    Route::put('/status/{id}', [StatusController::class, 'update'])->name('status.update');
    // Route::post('/getstatusbybusiness', [StatusController::class, 'getstatusbybusiness'])->name('getstatusbybusiness');

    // contact group routes
    Route::get('/contactGroup', [ContactGroupController::class, 'index'])->name('contactGroup');
    Route::post('/AddContactGroup', [ContactGroupController::class, 'store']);
    Route::get('/contactGroup/{id}/activate', [ContactGroupController::class, 'activate'])->name('contactGroup.activate');
    Route::get('/contactGroup/{id}/deactivate', [ContactGroupController::class, 'deactivate'])->name('contactGroup.deactivate');
    Route::delete('/contactGroup/{id}', [ContactGroupController::class, 'destroy'])->name('contactGroup.destroy');
    Route::put('/contactGroup/{id}', [ContactGroupController::class, 'update'])->name('contactGroup.update');

    // tenants routes
    Route::get('/tenants', [TenancyController::class, 'index'])->name('tenants');
    Route::get('/tenants/{id}/activate', [TenancyController::class, 'activate'])->name('tenants.activate');
    Route::get('/tenants/{id}/deactivate', [TenancyController::class, 'deactivate'])->name('tenants.deactivate');
    Route::delete('/tenants/{id}', [TenancyController::class, 'destroy'])->name('tenants.destroy');
    Route::get('/tenant_detail/{id}', [TenancyController::class, 'viewTenantDetail'])->name('tenant_detail');
    Route::get('/admin/login/{tenant_id}', [TenancyController::class, 'adminAutoLogin'])->name('admin.auto.login');

    //query builder routes
    Route::get('/query_builder', [QueryBuilderController::class, 'index'])->name('query_builder');
    Route::get('/add-query-builder', [QueryBuilderController::class, 'addQueryBuilder'])->name('query.builder.add');
    Route::get('/query-builder/get-columns', [QueryBuilderController::class, 'getTableColumns'])->name('query.builder.getColumns');
    Route::post('/query-builder/store', [QueryBuilderController::class, 'store'])->name('query.builder.store');
    Route::get('/query-builder/activate/{id}', [QueryBuilderController::class, 'activate'])->name('query.builder.activate');
    Route::get('/query-builder/deactivate/{id}', [QueryBuilderController::class, 'deactivate'])->name('query.builder.deactivate');
    Route::post('/query-builder/delete/{id}', [QueryBuilderController::class, 'delete'])->name('query.builder.delete');
    Route::get('/query-builder/edit/{id}', [QueryBuilderController::class, 'edit'])->name('query.builder.edit');
    Route::post('/query-builder/update/{id}', [QueryBuilderController::class, 'update'])->name('query.builder.update');

    //marketing routes
    Route::get('/marketing', [MarketingController::class, 'index'])->name('marketing');
    Route::post('/marketing', [MarketingController::class, 'store'])->name('marketing.store');
    Route::get('/marketing/{id}/edit', [MarketingController::class, 'edit']);
    Route::post('/marketing/{id}', [MarketingController::class, 'update']);
    Route::post('/marketing/{id}/update-image', [MarketingController::class, 'updateImage'])->name('admin.update.image');

    //query mapping routes
    Route::get('/query_mapping', [QueryMappingController::class, 'index'])->name('query_mapping');
    Route::post('/query_mapping', [QueryMappingController::class, 'store'])->name('query_mapping.store');
    Route::get('/query_mapping/{id}/activate', [QueryMappingController::class, 'activate'])->name('query_mapping.activate');
    Route::get('/query_mapping/{id}/deactivate', [QueryMappingController::class, 'deactivate'])->name('query_mapping.deactivate');
    Route::post('/query_mapping/{id}', [QueryMappingController::class, 'destroy'])->name('query_mapping.destroy');
    Route::get('/query_mapping/{id}', [QueryMappingController::class, 'edit'])->name('query_mapping.edit');
    Route::put('/query_mapping/{id}', [QueryMappingController::class, 'update'])->name('query_mapping.update');
  
    // sub category routes
    Route::get('/businessSubCategories', [BusinessSubCategoryController::class, 'index'])->name('businessSubCategories');
    Route::post('/AddSubCategory', [BusinessSubCategoryController::class, 'store']);
    Route::get('/SubCategory/{id}/activate', [BusinessSubCategoryController::class, 'activate'])->name('SubCategory.activate');
    Route::get('/SubCategory/{id}/deactivate', [BusinessSubCategoryController::class, 'deactivate'])->name('SubCategory.deactivate');
    Route::delete('/SubCategory/{id}', [BusinessSubCategoryController::class, 'destroy'])->name('SubCategory.destroy');
    Route::put('/SubCategory/{id}', [BusinessSubCategoryController::class, 'update'])->name('SubCategory.update');

    // apks routes
    Route::get('/apks', [ApkController::class, 'index'])->name('apks.index');
    Route::get('/apks/upload', [ApkController::class, 'create'])->name('apks.create');
    Route::post('/upload-apk', [ApkController::class, 'store'])->name('apks.store');
    Route::get('/apks/{id}/generate-link', [ApkController::class, 'generateDownloadLink'])->name('apks.generate');

    // FCM routes
    Route::get('/fcm_notification', [NotificationController::class, 'showForm'])->name('fcm_notification');
    Route::post('/send-notification', [NotificationController::class, 'sendNotification'])->name('send.notification');

    // feature-access routes
    Route::get('/feature-access', [FeatureAccessController::class, 'index'])->name('feature-access');
    Route::post('/feature-access', [FeatureAccessController::class, 'store'])->name('feature-access.store');
    //channel partner routes
    Route::get('/channel-partner', [ChannelPartnerController::class, 'index'])->name('channel-partner');
    Route::post('/add', [ChannelPartnerController::class, 'store']);
    Route::get('/partner/{id}/activate', [ChannelPartnerController::class, 'activate'])->name('partner.activate');
    Route::get('/partner/{id}/deactivate', [ChannelPartnerController::class, 'deactivate'])->name('partner.deactivate');
    Route::delete('/partner/{id}', [ChannelPartnerController::class, 'destroy'])->name('partner.destroy');

    Route::get('/menu-permissions', [MenuPermissionController::class, 'index'])->name('menu-permissions.index');
    Route::get('/menu-permissions/{user}/edit', [MenuPermissionController::class, 'edit'])->name('menu-permissions.edit');
    Route::put('/menu-permissions/{user}', [MenuPermissionController::class, 'update'])->name('menu-permissions.update');

    // Leads Bulk upload routes
    Route::get('/leads-master', [LeadsController::class, 'index'])->name('leads-master');
    Route::get('/leads/download-template', [LeadsController::class, 'downloadTemplate']);
    Route::post('/leads/upload-excel', [LeadsController::class, 'uploadExcel']);
    Route::get('/leads-master/{id}/activate', [LeadsController::class, 'activate'])->name('leads.activate');
    Route::get('/leads-master/{id}/deactivate', [LeadsController::class, 'deactivate'])->name('leads.deactivate');
    Route::delete('/leads-master/{id}/destroy', [LeadsController::class, 'destroy'])->name('leads.destroy');

    // sync routes
    Route::get('/sync', [SyncController::class, 'index'])->name('sync');
    Route::post('/sync', [SyncController::class, 'store'])->name('sync.store');
    Route::get('/sync/toggle-contact/{id}', [SyncController::class, 'toggleContact'])->name('sync.toggleContact');
    Route::get('/sync/toggle-call-history/{id}', [SyncController::class, 'toggleCallHistory'])->name('sync.toggleCallHistory');
    Route::get('/sync/toggle-status/{id}', [SyncController::class, 'toggleStatus'])->name('sync.toggleStatus');
    Route::get('/tenants/search', [SyncController::class, 'search'])->name('tenants.search');

    // Features
    Route::get('manage-package/features', [PackageController::class, 'features'])->name('features');
    Route::post('manage-package/features/store', [PackageController::class, 'storeFeature']);
    Route::post('manage-package/features/delete/{id}', [PackageController::class, 'deleteFeature']);
    Route::get('manage-package/features/activate/{id}', [PackageController::class, 'activateFeature'])->name('featureActivate');
    Route::get('manage-package/features/deactivate/{id}', [PackageController::class, 'deactivateFeature'])->name('featureDeactivate');
    Route::post('manage-package/features/update', [PackageController::class, 'updateFeature']);


    // Packages
    Route::get('manage-package/packages', [PackageController::class, 'packages'])->name('packages');
    Route::post('manage-package/packages/store', [PackageController::class, 'storePackage']);
    Route::post('manage-package/packages/delete/{id}', [PackageController::class, 'deletePackage']);
    Route::post('manage-package/packages/update', [PackageController::class, 'updatePackage']);
    Route::get('manage-package/packages/activate/{id}', [PackageController::class, 'activatePackage']);
    Route::get('manage-package/packages/deactivate/{id}', [PackageController::class, 'deactivatePackage']);

    // Package Duration & Amount
    Route::get('manage-package/durations', [PackageController::class, 'durations'])->name('durations');
    Route::post('manage-package/durations/store', [PackageController::class, 'storeDuration']);
    Route::post('manage-package/durations/update', [PackageController::class, 'updateDuration']);
    Route::post('manage-package/durations/delete/{id}', [PackageController::class, 'deleteDuration']);
    Route::get('manage-package/durations/activate/{id}', [PackageController::class, 'activateDuration']);
    Route::get('manage-package/durations/deactivate/{id}', [PackageController::class, 'deactivateDuration']);

    // Assign Packages
    Route::get('manage-package/assign-packages', [PackageController::class, 'assignPackages'])->name('assign-packages');
    Route::post('manage-package/assign-packages/store', [PackageController::class, 'storeAssignedPackage']);

    // ENT Form Builder Routes
    Route::get('/ent-form-builder', [EntFormBuilderController::class, 'entFormBuilder'])->name('ent-form-builder');
    Route::get('/add_ent_builder_form', [EntFormBuilderController::class, 'addEntFormBuilder'])->name('add_ent_builder_form');
    Route::post('/saveentformbuilder', [EntFormBuilderController::class, 'saveEntFormBuilder'])->name('saveentformbuilder');
    Route::get('/editentfrm', [EntFormBuilderController::class, 'editEntForm'])->name('editentfrm');
    Route::post('/updateentformbuilder', [EntFormBuilderController::class, 'updateEntFormBuilder'])->name('updateentformbuilder');
    Route::get('/entformbuilder/{id}/activate', [EntFormBuilderController::class, 'activate'])->name('entformbuilder.activate');
    Route::get('/entformbuilder/{id}/deactivate', [EntFormBuilderController::class, 'deactivate'])->name('entformbuilder.deactivate');

});


