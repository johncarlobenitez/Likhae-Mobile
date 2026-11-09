# Checkout service syntax repair

`app/Services/Marketplace/CheckoutService.php` is copied from
`Likhae-development (1).zip`, the latest Laravel project archive supplied for
the checkout error. It passes `php -l`.

From the Laravel project root, back up the current file and install this copy:

```powershell
Copy-Item .\app\Services\Marketplace\CheckoutService.php .\app\Services\Marketplace\CheckoutService.php.bak
Copy-Item 'C:\Likhae\deploy\checkout_service_syntax_fix\app\Services\Marketplace\CheckoutService.php' .\app\Services\Marketplace\CheckoutService.php -Force
php -l .\app\Services\Marketplace\CheckoutService.php
php artisan optimize:clear
```

Restart the Laravel server after the syntax check passes.
