<?php

namespace App\Models\Seller;

use App\Models\Communication\Message as ConversationMessage;

/** @deprecated Use App\Models\Communication\Message. */
class Message extends ConversationMessage
{
    protected $table = 'messages';
}
