<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reviews', function (Blueprint $table): void {
            $table->unsignedTinyInteger('rating')->nullable()->change();
            $table->foreignId('rider_profile_id')->nullable()->after('rating')->constrained('rider_profiles')->nullOnDelete();
            $table->unsignedTinyInteger('rider_rating')->nullable()->after('rider_profile_id');
            $table->text('rider_comment')->nullable()->after('comment');
        });
    }

    public function down(): void
    {
        DB::table('reviews')->whereNull('rating')->delete();

        Schema::table('reviews', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('rider_profile_id');
            $table->dropColumn(['rider_rating', 'rider_comment']);
            $table->unsignedTinyInteger('rating')->nullable(false)->change();
        });
    }
};