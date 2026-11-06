
local transfer_set = {
{% for skinid, attrs in  skin_prefabs %}
{% for asset in attrs.assets %}
{% if asset.ext == ".dyn" or asset.ext == ".tex" %}
    "{{asset.path}}|{{asset.originName}}|{{asset.name}}|{{asset.ext}}",
{% endif %}
{% endfor %}
{% endfor %}
{% for skinid, attrs in  clothing %}
{% for asset in attrs.assets %}
{% if asset.ext == ".dyn" or asset.ext == ".tex" %}
    "{{asset.path}}|{{asset.originName}}|{{asset.name}}|{{asset.ext}}",
{% endif %}
{% endfor %}
{% endfor %}
}

function string:split(delimiter)
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    self:gsub(pattern, function(c) table.insert(result, c) end)
    return result
end

local io = GLOBAL.io

function transferInternal()
    -- 注意：mod 的脚本环境是沙箱，pcall / error 不在环境里，必须从 GLOBAL 取
    local pcall = GLOBAL.pcall
    local error = GLOBAL.error
    local ok_count, fail_count = 0, 0
    for _, v in ipairs(transfer_set) do
        local assets = v:split("|")
        local path = assets[1]
        local origin = assets[2]
        local dest = assets[3]
        local ext = assets[4]

        local src = path .. origin .. ext
        local dst = MODROOT .. path .. dest .. ext

        -- 必须用 rb/wb：Windows 下 "w" 是文本模式，会把 .dyn 里的 0x0A 改成 0x0D 0x0A，文件直接坏掉
        local ok, err = pcall(function()
            local ifs = io.open(src, "rb")
            if not ifs then error("source missing: " .. src) end
            local byte = ifs:read("*a")
            ifs:close()

            local ofs = io.open(dst, "wb")
            if not ofs then error("write failed: " .. dst) end
            ofs:write(byte)
            ofs:close()
        end)

        if ok then
            ok_count = ok_count + 1
        else
            fail_count = fail_count + 1
            print("[ Local Skin Collection ] transfer failed:", err)
        end
    end
    print("[ Local Skin Collection ] transfer done:", ok_count, "ok,", fail_count, "failed")
end

function processIfNecessary()
    print("MODROOT:", MODROOT)
    print("io :", io)
    local p = MODROOT .. "install.txt";
    local fs = io.open(MODROOT .. "install.txt", "r")
    local c = fs and fs:read() or "";
    print("[ Local Skin Collection ] processIfNecessary:", p, c)
    if fs then fs:close() end;
    c = c and c:gsub("%s", "") or c
    if not c or c == "" or c == "0" then
        print("[ Local Skin Collection ] first running  ... ")
        transferInternal()
        fs = io.open(p, "w")
        fs:write("3");
        fs:close()
    end
end

processIfNecessary()

GLOBAL.setfenv(1, GLOBAL)

function abigail_flower_init_fn (inst, build_name)
    if not TheWorld.ismastersim then
        return
    end
    if inst.flower_skin_id and inst.skin_id then
        inst.flower_skin_id:set(inst.skin_id)
    end
    inst.AnimState:SetSkin(build_name, "abigail_flower_rework")
    inst.components.inventoryitem:ChangeImageName(inst:GetSkinName())
    inst.linked_skinname = string.gsub(build_name, "_flower", "")
end
