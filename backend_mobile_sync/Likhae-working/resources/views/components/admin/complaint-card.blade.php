@props(['complaint','href'=>null])
@php($status=strtolower(str_replace(' ','-',(string)data_get($complaint,'status',''))))
<article class="ad-complaint-card" data-filter-item>
    <div class="ad-complaint-head"><div>@if(data_get($complaint,'id'))<span class="ad-overline">{{ data_get($complaint,'id') }}</span>@endif<h3>{{ data_get($complaint,'title','Case') }}</h3></div>@if(data_get($complaint,'priority'))<span class="ad-priority">{{ data_get($complaint,'priority') }}</span>@endif</div>
    @if(data_get($complaint,'summary'))<p>{{ data_get($complaint,'summary') }}</p>@endif
    @if($href)<div class="ad-card-actions"><a class="ad-btn ad-btn-secondary ad-btn-sm" href="{{ $href }}">View</a></div>@endif
</article>
