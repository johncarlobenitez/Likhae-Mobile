document.addEventListener('DOMContentLoaded', () => {
    const form = document.querySelector('[data-delivery-area-address]');
    if (!form) return;

    const base = form.dataset.addressBase;
    const region = form.querySelector('[data-delivery-region]');
    const province = form.querySelector('[data-delivery-province]');
    const municipality = form.querySelector('[data-delivery-municipality]');
    const barangay = form.querySelector('[data-delivery-barangay]');
    const regionCode = form.querySelector('[data-delivery-region-code]');
    const provinceCode = form.querySelector('[data-delivery-province-code]');
    const municipalityCode = form.querySelector('[data-delivery-municipality-code]');
    const barangayCode = form.querySelector('[data-delivery-barangay-code]');
    if (!base || !region || !province || !municipality || !barangay) return;

    const old = {
        region: region.dataset.oldValue || '',
        regionCode: region.dataset.oldCode || '',
        province: province.dataset.oldValue || '',
        provinceCode: province.dataset.oldCode || '',
        municipality: municipality.dataset.oldValue || '',
        municipalityCode: municipality.dataset.oldCode || '',
        barangay: barangay.dataset.oldValue || '',
        barangayCode: barangay.dataset.oldCode || '',
    };

    const records = (payload) => Array.isArray(payload)
        ? payload
        : (payload?.data || payload?.results || payload?.provinces || payload?.municipalities || payload?.barangays || []);

    const fill = (select, rows, placeholder) => {
        select.innerHTML = `<option value="">${placeholder}</option>`;
        records(rows).forEach((row) => {
            if (!row?.code || !row?.name) return;
            const option = new Option(row.name, row.name);
            option.dataset.code = row.code;
            if (row.prv !== undefined) option.dataset.prv = row.prv;
            if (row.mun !== undefined) option.dataset.mun = row.mun;
            select.add(option);
        });
        select.disabled = select.options.length <= 1;
    };

    const reset = (select, placeholder) => {
        select.innerHTML = `<option value="">${placeholder}</option>`;
        select.disabled = true;
    };

    const load = async (url) => {
        const response = await fetch(url, { headers: { Accept: 'application/json' } });
        if (!response.ok) throw new Error('Address list unavailable.');
        return response.json();
    };

    const selectOld = (select, value, code) => {
        if (!value && !code) return false;
        const match = [...select.options].find((option) => option.dataset.code === code || option.value === value);
        if (!match) return false;
        select.value = match.value;
        return true;
    };

    const loadRegions = async () => {
        try {
            fill(region, await load(`${base}/regions`), 'Select region');
            if (selectOld(region, old.region, old.regionCode)) region.dispatchEvent(new Event('change'));
        } catch {
            region.innerHTML = '<option value="">Unable to load regions</option>';
            region.disabled = true;
        }
    };

    region.addEventListener('change', async () => {
        const selected = region.selectedOptions[0];
        if (regionCode) regionCode.value = selected?.dataset.code || '';
        reset(province, 'Select province');
        reset(municipality, 'Select municipality / city');
        reset(barangay, 'Select barangay');
        if (provinceCode) provinceCode.value = '';
        if (municipalityCode) municipalityCode.value = '';
        if (barangayCode) barangayCode.value = '';
        if (!selected?.dataset.code) return;

        try {
            fill(province, await load(`${base}/regions/${encodeURIComponent(selected.dataset.code)}/provinces`), 'Select province');
            if (selectOld(province, old.province, old.provinceCode)) province.dispatchEvent(new Event('change'));
        } catch {
            province.innerHTML = '<option value="">Unable to load provinces</option>';
        }
    });

    province.addEventListener('change', async () => {
        const selected = province.selectedOptions[0];
        if (provinceCode) provinceCode.value = selected?.dataset.code || '';
        reset(municipality, 'Select municipality / city');
        reset(barangay, 'Select barangay');
        if (municipalityCode) municipalityCode.value = '';
        if (barangayCode) barangayCode.value = '';
        if (!selected?.dataset.code) return;

        try {
            fill(municipality, await load(`${base}/provinces/${encodeURIComponent(selected.dataset.code)}/municipalities`), 'Select municipality / city');
            if (selectOld(municipality, old.municipality, old.municipalityCode)) municipality.dispatchEvent(new Event('change'));
        } catch {
            municipality.innerHTML = '<option value="">Unable to load municipalities</option>';
        }
    });

    municipality.addEventListener('change', async () => {
        const selected = municipality.selectedOptions[0];
        if (municipalityCode) municipalityCode.value = selected?.dataset.code || '';
        reset(barangay, 'Select barangay');
        if (barangayCode) barangayCode.value = '';
        if (!selected?.dataset.code) return;

        try {
            fill(barangay, await load(`${base}/municipalities/${encodeURIComponent(selected.dataset.code)}/barangays`), 'Select barangay');
            selectOld(barangay, old.barangay, old.barangayCode);
            if (barangayCode) barangayCode.value = barangay.selectedOptions[0]?.dataset.code || '';
        } catch {
            barangay.innerHTML = '<option value="">Unable to load barangays</option>';
        }
    });

    barangay.addEventListener('change', () => {
        if (barangayCode) barangayCode.value = barangay.selectedOptions[0]?.dataset.code || '';
    });

    loadRegions();
});
