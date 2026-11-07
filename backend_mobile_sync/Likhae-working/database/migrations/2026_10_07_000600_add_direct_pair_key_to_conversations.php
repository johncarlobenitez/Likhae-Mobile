<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->string('direct_pair_key', 100)->nullable()->after('type');
        });

        DB::transaction(function (): void {
            DB::table('conversations')
                ->orderBy('id')
                ->pluck('id')
                ->each(function (int $conversationId): void {
                    $userIds = DB::table('conversation_participants')
                        ->where('conversation_id', $conversationId)
                        ->orderBy('user_id')
                        ->pluck('user_id')
                        ->map(fn ($id): int => (int) $id)
                        ->values();

                    if ($userIds->count() !== 2 || $userIds->unique()->count() !== 2) {
                        return;
                    }

                    $pairKey = $userIds->implode(':');
                    $canonicalId = DB::table('conversations')
                        ->where('direct_pair_key', $pairKey)
                        ->value('id');

                    if ($canonicalId) {
                        DB::table('messages')
                            ->where('conversation_id', $conversationId)
                            ->update(['conversation_id' => $canonicalId]);
                        DB::table('conversation_participants')
                            ->where('conversation_id', $conversationId)
                            ->delete();
                        DB::table('conversations')
                            ->where('id', $conversationId)
                            ->delete();

                        return;
                    }

                    DB::table('conversations')
                        ->where('id', $conversationId)
                        ->update(['direct_pair_key' => $pairKey]);
                });
        });

        Schema::table('conversations', function (Blueprint $table): void {
            $table->unique('direct_pair_key');
        });
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table): void {
            $table->dropUnique('conversations_direct_pair_key_unique');
            $table->dropColumn('direct_pair_key');
        });
    }
};
