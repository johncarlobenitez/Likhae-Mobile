document.addEventListener('DOMContentLoaded', () => {
    const form = document.querySelector('form[action*="/delivery-areas"]');

    if (!form || form.dataset.deliveryAreaAddress) {
        return;
    }

    const addressBase = `${window.location.origin}/address/philippines`;
    const field = name => form.querySelector(`[name="${name}"]`);
    const labelFor = name => field(name)?.closest('label');
    const optionCode = item => String(item?.code ?? item?.value ?? item?.id ?? item?.key ?? '');
    const optionName = item => String(item?.name ?? item?.label ?? item?.description ?? item?.title ?? '');

    const createHiddenCode = (name, currentValue = '') => {
        const input = field(name);

        if (!input) {
            return null;
        }

        input.type = 'hidden';
        input.value = currentValue || input.value || '';
        input.dataset.addressCode = 'true';

        const parent = input.closest('label');
        if (parent) {
            parent.remove();
        }

        return input;
    };

    const createSelect = (name, labelText, codeName) => {
        const input = field(name);
        const label = labelFor(name);

        if (!input || !label) {
            return null;
        }

        const currentName = input.value || '';
        const codeInput = createHiddenCode(codeName);
        const select = document.createElement('select');
        select.name = name;
        select.required = true;
        select.disabled = name !== 'region_name';
        select.className = input.className;
        select.dataset.addressSelect = name;
        select.innerHTML = `<option value="">Select ${labelText.toLowerCase()}</option>`;
        input.replaceWith(select);

        label.firstChild.textContent = labelText;
        if (codeInput) {
            label.appendChild(codeInput);
        }

        return { select, codeInput, currentName };
    };

    const regionLabel = document.createElement('label');
    regionLabel.className = 'text-sm';
    regionLabel.innerHTML = '<span>Region</span><input type="hidden" name="region_code" value=""><select name="region_name" required class="mt-1 w-full border border-line p-2"><option value="">Select region</option></select>';
    const provinceLabel = labelFor('province_name');
    provinceLabel?.before(regionLabel);

    const regionSelect = regionLabel.querySelector('select');
    const regionCode = regionLabel.querySelector('input[name="region_code"]');
    const province = createSelect('province_name', 'Province', 'province_code');
    const municipality = createSelect('municipality_name', 'Municipality', 'municipality_code');
    const barangay = createSelect('barangay_name', 'Barangay', 'barangay_code');

    if (!regionSelect || !province || !municipality || !barangay) {
        return;
    }

    form.dataset.deliveryAreaAddress = 'true';
    form.dataset.addressBase = addressBase;

    const readList = payload => {
        if (Array.isArray(payload)) {
            return payload;
        }

        return payload?.data || payload?.results || payload?.regions || payload?.provinces || payload?.municipalities || payload?.barangays || [];
    };

    const request = async path => {
        const response = await fetch(`${addressBase}${path}`, {
            headers: { Accept: 'application/json' },
            credentials: 'same-origin',
        });

        if (!response.ok) {
            throw new Error(`Address request failed with ${response.status}`);
        }

        return readList(await response.json());
    };

    const setOptions = (target, items, selectedName = '', selectedCode = '') => {
        target.innerHTML = `<option value="">Select ${target.name.replace('_name', '').toLowerCase()}</option>`;

        items.forEach(item => {
            const code = optionCode(item);
            const name = optionName(item);

            if (!code || !name) {
                return;
            }

            const option = new Option(name, name);
            option.dataset.code = code;
            target.add(option);

            if ((selectedCode && code === selectedCode) || (!selectedCode && selectedName === name)) {
                option.selected = true;
            }
        });

        target.disabled = false;
    };

    const reset = (entry, label) => {
        entry.select.innerHTML = `<option value="">Select ${label}</option>`;
        entry.select.disabled = true;
        if (entry.codeInput) {
            entry.codeInput.value = '';
        }
    };

    const load = async (target, path, selectedName = '', selectedCode = '') => {
        target.select.disabled = true;
        target.select.innerHTML = '<option value="">Loading...</option>';

        try {
            setOptions(target.select, await request(path), selectedName, selectedCode);
        } catch (error) {
            target.select.innerHTML = '<option value="">Unable to load options</option>';
            target.select.disabled = true;
            console.error(error);
        }
    };

    const syncCode = entry => {
        const selected = entry.select.selectedOptions[0];
        if (entry.codeInput) {
            entry.codeInput.value = selected?.dataset.code || '';
        }
    };

    const loadRegions = async () => {
        regionSelect.disabled = true;
        regionSelect.innerHTML = '<option value="">Loading regions...</option>';

        try {
            setOptions(regionSelect, await request('/regions'));
            regionSelect.addEventListener('change', async () => {
                regionCode.value = regionSelect.selectedOptions[0]?.dataset.code || '';
                reset(province, 'province');
                reset(municipality, 'municipality');
                reset(barangay, 'barangay');

                if (regionCode.value) {
                    await load(province, `/regions/${encodeURIComponent(regionCode.value)}/provinces`);
                }
            });
            province.select.addEventListener('change', async () => {
                syncCode(province);
                reset(municipality, 'municipality');
                reset(barangay, 'barangay');

                if (province.codeInput.value) {
                    await load(municipality, `/provinces/${encodeURIComponent(province.codeInput.value)}/municipalities`);
                }
            });
            municipality.select.addEventListener('change', async () => {
                syncCode(municipality);
                reset(barangay, 'barangay');

                if (municipality.codeInput.value) {
                    await load(barangay, `/municipalities/${encodeURIComponent(municipality.codeInput.value)}/barangays`);
                }
            });
            barangay.select.addEventListener('change', () => syncCode(barangay));
        } catch (error) {
            regionSelect.innerHTML = '<option value="">Unable to load regions</option>';
            regionSelect.disabled = true;
            console.error(error);
        }
    };

    loadRegions();
});
