<?php

namespace App\Services\Ai;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Server-side Gemini gateway. Callers must prepare a minimal, sanitized prompt
 * before invoking this service; credentials never leave Laravel.
 */
class GeminiService
{
    public function configured(): bool
    {
        return filled(config('services.gemini.key'));
    }

    public function generate(string $systemInstruction, string $prompt): string
    {
        $key = (string) config('services.gemini.key');
        $model = (string) config('services.gemini.model', 'gemini-flash-lite-latest');

        if ($key === '') {
            throw new RuntimeException('Gemini is not configured.');
        }

        try {
            $response = Http::acceptJson()
                ->withHeaders(['x-goog-api-key' => $key])
                ->timeout(18)
                ->post("https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent", [
                    'systemInstruction' => ['parts' => [['text' => $systemInstruction]]],
                    'contents' => [['role' => 'user', 'parts' => [['text' => $prompt]]]],
                    'generationConfig' => ['temperature' => 0.25, 'maxOutputTokens' => 350],
                ]);
        } catch (ConnectionException $exception) {
            throw new RuntimeException('Gemini request failed.', previous: $exception);
        }

        if (! $response->successful()) {
            throw new RuntimeException('Gemini request failed.');
        }

        $text = trim((string) data_get($response->json(), 'candidates.0.content.parts.0.text'));

        if ($text === '') {
            throw new RuntimeException('Gemini returned no response.');
        }

        return $text;
    }
}
