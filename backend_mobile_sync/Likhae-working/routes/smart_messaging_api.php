<?php

// Loaded from routes/api.php inside the v1 bearer-token and policy middleware.
use App\Http\Controllers\Communication\SmartMessagingController;
use App\Http\Middleware\EnsureWorkspaceRole;
use Illuminate\Support\Facades\Route;

foreach (['buyer', 'rider'] as $role) {
    Route::prefix($role.'/messages/{conversation}')
        ->name('api.v1.'.$role.'.messages.')
        ->middleware(EnsureWorkspaceRole::class.':'.$role)
        ->group(function (): void {
            Route::get('smart-help', [SmartMessagingController::class, 'bootstrap'])
                ->whereNumber('conversation')->middleware('throttle:60,1')->name('smart-help.show');
            Route::post('smart-help/answer', [SmartMessagingController::class, 'answer'])
                ->whereNumber('conversation')->middleware('throttle:120,1')->name('smart-help.answer');
            Route::post('smart-help/feedback', [SmartMessagingController::class, 'feedback'])
                ->whereNumber('conversation')->middleware('throttle:60,1')->name('smart-help.feedback');
            Route::post('smart-help/handoff', [SmartMessagingController::class, 'handoff'])
                ->whereNumber('conversation')->middleware('throttle:20,1')->name('smart-help.handoff');
        });
}
