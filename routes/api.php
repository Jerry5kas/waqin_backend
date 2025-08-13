<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\Api\CustomerController;
use App\Http\Controllers\TenancyController;
use App\Http\Controllers\BusinessCategoryController;
use App\Http\Controllers\ServiceController;
use App\Http\Controllers\CountryController;
use App\Http\Controllers\StateController;
use App\Http\Controllers\CityController;
use App\Http\Controllers\ApiController;
use App\Http\Controllers\StatusController;
use App\Http\Controllers\FormBuilderController;
use App\Http\Controllers\ContactGroupController;
use App\Http\Controllers\OTPController;
use App\Http\Controllers\CronJobController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\PhonePeController;
use App\Http\Controllers\BillingController;
use App\Http\Controllers\ApiChannelPartner;
use App\Http\Controllers\MultiDBAlterController;
use App\Http\Controllers\TenantSettingController;
use App\Http\Controllers\QrCodeController;


// Public routes
Route::get('/permissions', [ApiController::class, 'AppPermissions']);
Route::post('register', [AuthController::class, 'register']);
Route::post('checkMobile', [AuthController::class, 'checkMobile']);
Route::post('login', [AuthController::class, 'login']);
Route::post('send_otp', [AuthController::class, 'SendOtp']);
Route::post('verify_otp', [AuthController::class, 'VerifyOtp']);
Route::get('getallbusinesslist', [BusinessCategoryController::class, 'getBusinesses']);
Route::delete('delete-tenant', [TenancyController::class, 'deleteTenants']);
Route::post('/getstatus', [StatusController::class, 'getStatusByBusinessId']);
Route::get('getallbusinesslist', [BusinessCategoryController::class, 'getBusinesses']);
Route::get('/storeRecommendedLeads', [CronJobController::class, 'storeRecommendedLeads']);
Route::get('/send-lead-notification', [NotificationController::class, 'sendLeadNotification']);
Route::post('/clearRedisCache', [ApiController::class, 'clearRedisCache']);

Route::post('/phonepe/pay', [PhonePeController::class, 'initiate']);
Route::post('/phonepe/verify', [PhonePeController::class, 'verify']);
// Classic callback (if you use callbackUrl in payload)
Route::post('/phonepe/callback', [PhonePeController::class, 'paymentCallback']);
// Webhook endpoint (set only in PhonePe merchant portal)
Route::post('/phonepe/webhook', [PhonePeController::class, 'webhook']);


//firebase OTP auth routes
Route::post('/send-otp', [OTPController::class, 'sendOtp']);
Route::post('/verify-otp', [OTPController::class, 'verifyOtp']);
Route::post('/multi-db-add-column', [MultiDBAlterController::class, 'addColumnToMultipleDBs']);
Route::post('/generate-qr', [QrCodeController::class, 'generateFromApi']);

// Protected routes
Route::middleware('auth:api')->group(function () {
    Route::get('getTenantSetting', [TenantSettingController::class, 'getTeantSetting']);
    Route::post('updateTenantSetting', [TenantSettingController::class, 'updateTenantSetting']);


    Route::post('logout', [AuthController::class, 'logout']);
    Route::post('refresh', [AuthController::class, 'refresh']);
    Route::get('me', [AuthController::class, 'me']);
    Route::post('/getServicesBasedOnBusiness', [ServiceController::class, 'getServicesBasedOnBusiness']);
    Route::post('import-customers', [ApiController::class, 'importCustomers']);
    Route::post('/updateProfile', [ApiController::class, 'updateProfile']);
    Route::post('update-customer', [ApiController::class, 'updateCustomer']);
    Route::post('import-callhistory', [ApiController::class, 'importCallHistory']);
    Route::post('/get-call-history', [ApiController::class, 'getCallHistory']);
    Route::post('/saveCustomerDetails', [ApiController::class, 'saveCoustomerDetails']);
    Route::post('/getGroupsByBusinessId', [ContactGroupController::class, 'getGroupsByBusinessId']);
    Route::post('/getServiceOrProductCategory', [ApiController::class, 'getServiceOrProductCategory']);
    Route::post('/addCatalog', [ApiController::class, 'addCatalog']);
    Route::post('/getCatalog', [ApiController::class, 'getCatalog']);
    Route::post('/editCatalog', [ApiController::class, 'editCatalog']);
    Route::post('/deleteCatalog', [ApiController::class, 'deleteCatalog']);

    Route::post('/addEmployee', [ApiController::class, 'addEmployee']);
    Route::post('/editEmployee', [ApiController::class, 'editEmployee']);
    Route::post('/deleteEmployee', [ApiController::class, 'deleteEmployee']);
    Route::get('/getEmployees', [ApiController::class, 'getEmployees']);
    Route::post('/saveAppointment', [ApiController::class, 'saveAppointment']);
    Route::post('/editAppointment', [ApiController::class, 'editAppointment']);
    Route::post('/deleteAppointment', [ApiController::class, 'deleteAppointment']);
    Route::post('/getAppointments', [ApiController::class, 'getAppointments']);
    Route::post('/getAppointmentsByDate', [ApiController::class, 'getAppointmentsByDate']);
    Route::post('/tenant/marketing', [ApiController::class, 'getMarketingItems']);
    Route::post('/addMarketingItem', [ApiController::class, 'addMarketingItem']);
    Route::post('/editMarketingItem', [ApiController::class, 'editMarketingItem']);
    Route::post('/deleteMarketingItem', [ApiController::class, 'deleteMarketingItem']);
    Route::get('/get_form', [ApiController::class, 'getFormByName']);
    Route::post('/saveNote', [ApiController::class, 'saveNote']);
    Route::post('/getNotes', [ApiController::class, 'getNotes']);
    Route::post('/editNote', [ApiController::class, 'editNote']);
    Route::post('/deleteNote', [ApiController::class, 'deleteNote']);
    Route::post('/saveBusinessHistory', [ApiController::class, 'saveBusinessHistory']);
    Route::post('/getBusinessHistory', [ApiController::class, 'getBusinessHistory']);
    Route::get('/getPurchasedItems', [ApiController::class, 'getPurchasedItems']);
    Route::get('/getPurchasedServices', [ApiController::class, 'getPurchasedServices']);
    Route::post('/getDashboardData', [ApiController::class, 'getDashboardData']);
    Route::post('/getCustomerProfileCompletion', [ApiController::class, 'getCustomerProfileCompletion']);
    Route::post('/createInvoiceOrProposal', [ApiController::class, 'createInvoiceOrProposal']);
    Route::post('/getAllInvoiceOrProposals', [ApiController::class, 'getAllInvoiceOrProposals']);
    Route::post('/getInvoiceAndProposal', [ApiController::class, 'getInvoiceAndProposal']);
    Route::post('/updateInvoiceOrProposal', [ApiController::class, 'updateInvoiceOrProposal']);
    Route::post('/addTask', [ApiController::class, 'addTask']);
    Route::post('/editTask', [ApiController::class, 'editTask']);
    Route::get('/getTask', [ApiController::class, 'getTask']);
    Route::post('/markTaskDone', [ApiController::class, 'markTaskDone']);
    Route::post('/deleteTask', [ApiController::class, 'deleteTask']);
    Route::post('/assignGroupToCustomers', [ApiController::class, 'assignGroupToCustomers']);
    Route::post('/addAccountDetails', [ApiController::class, 'addAccountDetails']);
    Route::post('/getAccountDetails', [ApiController::class, 'getAccountDetails']);
    Route::post('/editAccountDetail', [ApiController::class, 'editAccountDetail']);
    Route::get('/getProductsAndServices', [ApiController::class, 'getProductsAndServices']);
    Route::post('/addContact', [ApiController::class, 'addContact']);
    Route::post('/createQuickBilling', [ApiController::class, 'createQuickBilling']);
    Route::get('/getAllQuickBilling', [ApiController::class, 'getAllQuickBilling']);
    Route::post('/importCatalogXlsx', [ApiController::class, 'importCatalogXlsx']);
    Route::post('/downloadCatalogXlsx', [ApiController::class, 'downloadCatalogXlsx']);
    Route::post('/checkAccess', [ApiController::class, 'checkAccess']);
    Route::post('/importContactXlsx', [ApiController::class, 'importContactXlsx']);
    Route::get('/getColumnName', [ApiController::class, 'getColumnName']);
    Route::post('/getRecomendedLeads', [ApiController::class, 'getRecomendedLeads']);
    Route::get('/getFormsByBusiness', [ApiController::class, 'getFormsByBusiness']);
    Route::post('/addCustomerBankDetail', [ApiController::class, 'addCustomerBankDetail']);
    Route::post('/editCustomerBankDetail', [ApiController::class, 'editCustomerBankDetail']);
    Route::get('/getCustomerBankDetail', [ApiController::class, 'getCustomerBankDetail']);
    Route::get('/getAllCustomers', [ApiController::class, 'getAllCustomers']);
    Route::post('/getMostLikelyCustomers', [ApiController::class, 'getMostLikelyCustomers']);
    Route::post('/syncStatus', [ApiController::class, 'syncStatus']);
    Route::get('/getPackages', [ApiController::class, 'getPackages']);
    Route::get('/getInvoiceOrProposalPdfBase64', [ApiController::class, 'getInvoiceOrProposalPdfBase64']);

    Route::post('/savePrescription', [ApiController::class, 'savePrescription']);
    Route::get('/getPrescription', [ApiController::class, 'getPrescription']);
    Route::post('/syncData', [ApiController::class, 'syncData']);
    Route::post('/addSelectedProduct', [ApiController::class, 'addSelectedProduct']);
    Route::post('/updateProductStatus', [ApiController::class, 'updateProductStatus']);
    Route::post('/deleteTenant', [ApiController::class, 'deleteTenant']);
    Route::get('/getLatestApkVersion', [ApiController::class, 'getLatestApkVersion']);
    Route::get('/getAttachmentsByCustomer', [ApiController::class, 'getAttachmentsByCustomer']);
    Route::post('/deleteAttachment', [ApiController::class, 'deleteAttachment']);

    Route::get('/get_marketplace_order', [ApiController::class, 'getMarketplaceOrder']);

    Route::middleware(['auth:api', 'checkFeatureAccess'])
    ->post('/getBusinessHistoryList', [ApiController::class, 'getBusinessHistoryList']);

    // Add more protected routes here
    Route::get('user', function () {
        return auth()->user();
    });

    // Example of a protected route
    Route::get('protected-route', function () {
        return response()->json(['message' => 'This is a protected route']);
    });


});


Route::prefix('billing')->group(function () {
     Route::post('/create-invoice', [BillingController::class, 'createInvoice']);
     Route::post('/create-order', [BillingController::class, 'createOrder']);
     Route::post('/create-proposal', [BillingController::class, 'createProposal']);
     Route::post('/fetch-documents', [BillingController::class, 'fetchDocuments']);
     Route::get('/getdocumentbyid/{id}', [BillingController::class, 'getDocumentById']);
     Route::get('/generatePdf/{id}', [BillingController::class, 'generatePdf']);
     Route::patch('/updateDocumentById/{id}', [BillingController::class, 'updateDocumentById']);
     Route::post('/employee-comission', [BillingController::class, 'employeeComission']);

});

Route::prefix('cp')->group(function () {
     Route::get('/getcplist', [ApiChannelPartner::class, 'index']);
});

