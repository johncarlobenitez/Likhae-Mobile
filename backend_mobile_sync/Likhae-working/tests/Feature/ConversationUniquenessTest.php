<?php

namespace Tests\Feature;

use App\Models\Communication\Conversation;
use App\Models\User;
use App\Services\Communication\ConversationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ConversationUniquenessTest extends TestCase
{
    use RefreshDatabase;

    public function test_two_accounts_reuse_one_conversation_across_contexts_and_directions(): void
    {
        $first = User::factory()->create();
        $second = User::factory()->create();
        $service = app(ConversationService::class);

        $conversation = $service->start($first, $second->id, ['type' => 'PRODUCT_SELLER']);
        $sameConversation = $service->start($second, $first->id, ['type' => 'SUPPORT']);

        $this->assertSame($conversation->id, $sameConversation->id);
        $this->assertSame(1, Conversation::query()->count());
        $this->assertDatabaseHas('conversations', [
            'id' => $conversation->id,
            'direct_pair_key' => collect([$first->id, $second->id])->sort()->implode(':'),
        ]);
    }

    public function test_a_different_account_pair_gets_a_separate_conversation(): void
    {
        $first = User::factory()->create();
        $secondAccount = User::factory()->create();
        $thirdAccount = User::factory()->create();
        $service = app(ConversationService::class);

        $firstConversation = $service->start($first, $secondAccount->id);
        $secondConversation = $service->start($first, $thirdAccount->id);

        $this->assertNotSame($firstConversation->id, $secondConversation->id);
        $this->assertSame(2, Conversation::query()->count());
    }
}
