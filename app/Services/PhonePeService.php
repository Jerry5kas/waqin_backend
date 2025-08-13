<?php

namespace App\Services;

use PhonePe\payments\v2\standardCheckout\StandardCheckoutClient;
use PhonePe\Env;
use Illuminate\Support\Str;

class PhonePeService
{
    protected $client;

    public function __construct()
    {
        $this->client = new PhonePe(
            environment: env('PHONEPE_ENV', Environment::PRODUCTION),
            merchantId: env('PHONEPE_MERCHANT_ID'),
            saltKey: env('PHONEPE_SALT_KEY'),
            saltIndex: env('PHONEPE_SALT_INDEX'),
            enableLogging: true
        );
    }

    public function createPayment(array $input)
    {
        $orderId = $input['orderId'];
        $amount = $input['amount']; // in paise
        $redirectUrl = $input['redirectUrl'];
        $callbackUrl = $input['callbackUrl'];

        $request = new StandardCheckoutRequest(
            merchantId: env('PHONEPE_MERCHANT_ID'),
            merchantTransactionId: $orderId,
            amount: $amount,
            merchantUserId: $input['userId'] ?? Str::uuid(),
            redirectUrl: $redirectUrl,
            redirectMode: "POST",
            callbackUrl: $callbackUrl,
            paymentInstrument: [
                "type" => "PAY_PAGE"
            ]
        );

        return $this->client->standardCheckout($request);
    }

    public function checkStatus(string $transactionId)
    {
        $request = new StatusCheckRequest(
            merchantId: env('PHONEPE_MERCHANT_ID'),
            merchantTransactionId: $transactionId
        );

        return $this->client->checkStatus($request);
    }

    public function refund(string $transactionId, int $amount, string $merchantRefundId)
    {
        $request = new RefundPaymentRequest(
            merchantId: env('PHONEPE_MERCHANT_ID'),
            merchantTransactionId: $transactionId,
            merchantUserId: Str::uuid(),
            originalTransactionId: $transactionId,
            amount: $amount,
            merchantRefundId: $merchantRefundId
        );

        return $this->client->refundPayment($request);
    }
}

