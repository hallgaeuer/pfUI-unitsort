pfUI:UpdateConfig("unitsort", nil, "raidEnable", "1")
pfUI:UpdateConfig("unitsort", nil, "raidSort", "asc")
pfUI:UpdateConfig("unitsort", nil, "raidSortBy", "name")

-- add unitsort module to pfUI
pfUI:RegisterModule("unitsort", function ()
  local CreateGUIEntry = pfUI.gui.CreateGUIEntry
  local CreateConfig = pfUI.gui.CreateConfig

  -- create gui entries for each option
  CreateGUIEntry(T["Thirdparty"], T["Unit frame sorting"], function()
    CreateConfig(nil, "Raid sorting: Enable", C.unitsort, "raidEnable", "checkbox")
    CreateConfig(nil, "Raid sorting: Direction", C.unitsort, "raidSort", "dropdown", {
      "asc:" .. T["Ascending"],
      "desc:" .. T["Descending"]
    })
    CreateConfig(nil, "Raid sorting: Sort by", C.unitsort, "raidSortBy", "dropdown", {
      "name:" .. T["Name"],
      "class:" .. T["Class"]
    })
  end)

  -- make sure that all required modules are loaded. otherwise break and print a message
  if not pfUI.uf or not pfUI.uf.raid
  then
    message("|cff33aa88unitsort|r has been disabled. Not all required pfUI modules were loaded (pfUI.uf or pfUI.uf.raid)")
    return
  end

  -- Copied from the original pfUI raid.lua. Used to reset existing raid frames
  local function SetRaidIndex(frame, id)
    frame.id = id
    frame.label = "raid"
    frame:UpdateVisibility()
  end

  -- https://wowpedia.fandom.com/wiki/Orderedpairs
  local function orderedNext(t, n)
    local key = t[t.__next]
    if not key then return end
    t.__next = t.__next + 1
    return key, t.__source[key]
  end

  -- https://wowpedia.fandom.com/wiki/Orderedpairs
  local function orderedPairs(t, f)
    local keys, kn = {__source = t, __next = 1}, 1
    for k in pairs(t) do
    keys[kn], kn = k, kn + 1
    end
    table.sort(keys, f)
    return orderedNext, keys
  end

  local function sortUnitsCallback(units, a, b)
    local sortBy = C.unitsort.raidSortBy or "name"
    local direction = C.unitsort.raidSort or "asc"

    if (direction == "asc") then
      return units[a][sortBy] > units[b][sortBy]
    else
      return units[a][sortBy] < units[b][sortBy]
    end
  end

  if C.unitsort.raidEnable == "1" then
    -- Completely override the original OnUpdate function since we pretty much have to redo everything the original does anyway
    pfUI.uf.raid:SetScript("OnUpdate", function()
      -- don't proceed without raid or during combat
      if not UnitInRaid("player") or (InCombatLockdown and InCombatLockdown()) then return end
  
      -- clear all existing frames
      local maxraid = tonumber(C.unitframes.maxraid)
      for i=1, maxraid do SetRaidIndex(pfUI.uf.raid[i], 0) end
  
      -- Collect unit information (by which we can sort later) and group them by subgroup
      local groups = {}
  
      for i=1, GetNumRaidMembers() do
        local name, _, subgroup, level, class  = GetRaidRosterInfo(i)
  
        if name then
          if (not groups[subgroup]) then
            groups[subgroup] = {}
          end
  
          local unit = {}
          unit["index"] = i
          unit["name"] = name
          unit["level"] = level
          unit["class"] = class

          table.insert(groups[subgroup], unit)
        end
      end
  
      -- Iterate over subgroups and sort units before adding them back
      for subgroup, units in pairs(groups) do
        for k, unit in orderedPairs(units, function(a,b) return sortUnitsCallback(units, a, b) end) do
          pfUI.uf.raid:AddUnitToGroup(unit.index, subgroup)
        end
      end    
  
      this:Hide()
    end)
  end
end)
