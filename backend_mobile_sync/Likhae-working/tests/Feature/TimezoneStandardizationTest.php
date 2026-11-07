<?php

namespace Tests\Feature;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TimezoneStandardizationTest extends TestCase
{
    public function test_application_php_and_mysql_use_philippine_time(): void
    {
        $this->assertSame('Asia/Manila', config('app.timezone'));
        $this->assertSame('Asia/Manila', date_default_timezone_get());
        $this->assertSame('+08:00', config('database.connections.mysql.timezone'));

        if (DB::getDriverName() !== 'mysql') {
            $this->markTestSkipped('The timezone session assertion requires MySQL.');
        }

        $this->assertSame('+08:00', DB::selectOne('SELECT @@session.time_zone AS timezone')->timezone);
    }

    public function test_iso_timestamps_include_the_philippine_offset(): void
    {
        $local = CarbonImmutable::create(2026, 10, 8, 17, 30, 0, 'Asia/Manila');

        $this->assertSame('2026-10-08T17:30:00+08:00', $local->toIso8601String());
        $this->assertSame('October 8, 2026, 5:30 PM PHT', $local->format('F j, Y, g:i A').' PHT');
    }

    public function test_api_health_timestamp_contains_the_philippine_offset(): void
    {
        $timestamp = $this->getJson('/api/v1/health')
            ->assertOk()
            ->json('timestamp');

        $this->assertSame(8 * 60 * 60, CarbonImmutable::parse($timestamp)->getOffset());
    }

    public function test_midnight_boundaries_and_gps_ordering_use_instants_not_clock_strings(): void
    {
        $localAfterMidnight = CarbonImmutable::parse('2026-10-08 00:15:00', 'Asia/Manila');
        $sameInstantUtc = CarbonImmutable::parse('2026-10-07 16:15:00', 'UTC');

        $this->assertTrue($localAfterMidnight->equalTo($sameInstantUtc));
        $this->assertSame('2026-10-08', $localAfterMidnight->toDateString());
        $this->assertSame('2026-10-07', $sameInstantUtc->toDateString());
        $this->assertTrue($sameInstantUtc->lt(CarbonImmutable::parse('2026-10-08 00:16:00', 'Asia/Manila')));
    }
}
