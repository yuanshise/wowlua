-- Hekili.lua
-- April 2014

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, ...)
    ZHIYE=select(2, GetSpecializationInfo(GetSpecialization()))
    print(ZHIYE)
    -- 获取职业的技能信息
    


    local trinketSpellNames = GetTrinketSpellNames()
    for _, spellName in ipairs(trinketSpellNames) do
        print("饰品主动技能名字:", spellName)
    end
    
    
    

    local className, classFileName, classID = UnitClass("player")
    local function GetClassSpells(classID)
        local spells = {}
        for i = 1, GetNumSpellTabs() do
            local name, texture, offset, numSpells = GetSpellTabInfo(i)
            if name==className or name==ZHIYE then
                print("标签名称:", name)
                for j = 1, numSpells do
                    local spellID = offset + j
                    --print(spellID)
                    local spellName = GetSpellBookItemName(spellID, BOOKTYPE_SPELL)
                    local spellDescription = GetSpellDescription(spellID)
                    
                    local jnid=GetSpellIDByName(spellName)
                    --local spellDescription = GetSpellDescription(jnid)---法术描述
                   -- print(spellName,"法术描述:", spellDescription)
                   
                
                   
                   local isPassive = C_Spell.IsSpellPassive(jnid)
                   
                   if isPassive then
                       --print("技能是被动技能")
                   else
                        --print(spellName)
                        table.insert(spells, spellName)
                   end
                   
                    --print("结束")
                   
                end
            end
           
        end
        return spells
    end
    
    -- 打印所有技能
    local spells = GetClassSpells(classID)
    for _, spell in ipairs(spells) do
     --rint(spell)
    end
    
end)


local frame = CreateFrame("Frame", "MyColorBlockFrame", UIParent)
frame:SetSize(5, 5) -- 设置色块的大小
frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 1) -- 设置色块的位置 BOTTOMLEFT TOPLEFT--下
-- 设置色块的背景颜色
frame.texture = frame:CreateTexture(nil, "BACKGROUND")
frame.texture:SetAllPoints(frame)


--local frame2 = CreateFrame("Frame", "MyColorBlockFrame2", UIParent)
--frame2:SetSize(2, 2) -- 设置色块的大小
--frame2:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",0, 2.5) -- 设置色块的位置 BOTTOMLEFT TOPLEFT--上
-- 设置色块的背景颜色
--frame2.texture = frame2:CreateTexture(nil, "BACKGROUND")
--frame2.texture:SetAllPoints(frame2)

--local frame3 = CreateFrame("Frame", "MyColorBlockFrame3", UIParent)
--frame3:SetSize(2, 1) -- 设置色块的大小 2 1
--frame3:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",0, 1) -- 设置色块的位置 BOTTOMLEFT TOPLEFT--上
-- 设置色块的背景颜色
--frame3.texture = frame3:CreateTexture(nil, "BACKGROUND")
--frame3.texture:SetAllPoints(frame3)


local addon, ns = ...
local Hekili = _G[ addon ]

local class = Hekili.Class
local state = Hekili.State
local scripts = Hekili.Scripts

local callHook = ns.callHook
local clashOffset = ns.clashOffset
local formatKey = ns.formatKey
local getSpecializationID = ns.getSpecializationID
local getResourceName = ns.getResourceName
local orderedPairs = ns.orderedPairs
local tableCopy = ns.tableCopy
local timeToReady = ns.timeToReady

local GetItemInfo = ns.CachedGetItemInfo

local trim = string.trim


local tcopy = ns.tableCopy
local tinsert, tremove, twipe = table.insert, table.remove, table.wipe


-- checkImports()
-- Remove any displays or action lists that were unsuccessfully imported.
local function checkImports()
end
ns.checkImports = checkImports


local function EmbedBlizOptions()
    local panel = CreateFrame( "Frame", "HekiliDummyPanel", UIParent )
    panel.name = "Hekili"

    local open = CreateFrame( "Button", "HekiliOptionsButton", panel, "UIPanelButtonTemplate" )
    open:SetPoint( "CENTER", panel, "CENTER", 0, 0 )
    open:SetWidth( 250 )
    open:SetHeight( 25 )
    open:SetText( "打开Hekili设置界面" )

    open:SetScript( "OnClick", function ()
        ns.StartConfiguration()
    end )

    Hekili:ProfileFrame( "OptionsEmbedFrame", open )

    InterfaceOptions_AddCategory( panel )
end


-- OnInitialize()
-- Addon has been loaded by the WoW client (1x).
function Hekili:OnInitialize()
    self.DB = LibStub( "AceDB-3.0" ):New( "HekiliDB", self:GetDefaults(), true )

    self.Options = self:GetOptions()
    self.Options.args.profiles = LibStub( "AceDBOptions-3.0" ):GetOptionsTable( self.DB )

    -- Reimplement LibDualSpec; some folks want different layouts w/ specs of the same class.
    local LDS = LibStub( "LibDualSpec-1.0" )
    LDS:EnhanceDatabase( self.DB, "Hekili" )
    LDS:EnhanceOptions( self.Options.args.profiles, self.DB )

    self.DB.RegisterCallback( self, "OnProfileChanged", "TotalRefresh" )
    self.DB.RegisterCallback( self, "OnProfileCopied", "TotalRefresh" )
    self.DB.RegisterCallback( self, "OnProfileReset", "TotalRefresh" )

    local AceConfig = LibStub( "AceConfig-3.0" )
    AceConfig:RegisterOptionsTable( "Hekili", self.Options )

    local AceConfigDialog = LibStub( "AceConfigDialog-3.0" )
    -- EmbedBlizOptions()

    self:RegisterChatCommand( "hekili", "CmdLine" )
    self:RegisterChatCommand( "hek", "CmdLine" )

    local LDB = LibStub( "LibDataBroker-1.1", true )
    local LDBIcon = LDB and LibStub( "LibDBIcon-1.0", true )

    Hekili_OnAddonCompartmentClick = function( btn, arg1, arg2, checked, button )
        button = button or arg1
        if button == "RightButton" then ns.StartConfiguration()
        else
            ToggleDropDownMenu( 1, nil, ns.UI.Menu, "cursor", 8, 5 )
        end
        GameTooltip:Hide()
    end

    local function GetDataText()
        local p = Hekili.DB.profile
        local m = p.toggles.mode.value
        local color = "FFFFD100"

        if p.toggles.essences.override then
            -- Don't show Essences here if it's overridden by CDs anyway?
            return format( "|c%s%s|r %s爆发|r %s打断|r %s防御|r", color,
                m == "single" and "单体" or ( m == "aoe" and "AOE" or ( m == "dual" and "双显" or ( m == "reactive" and "响应" or "自动" ) ) ),
                p.toggles.cooldowns.value and "|cFF00FF00" or "|cFFFF0000",
                p.toggles.interrupts.value and "|cFF00FF00" or "|cFFFF0000",
                p.toggles.defensives.value and "|cFF00FF00" or "|cFFFF0000" )
        else
            return format( "|c%s%s|r %s主爆|r %s次爆|r %s打断|r",
                color,
                m == "single" and "单体" or ( m == "aoe" and "AOE" or ( m == "dual" and "双显" or ( m == "reactive" and "响应" or "自动" ) ) ),
                p.toggles.cooldowns.value and "|cFF00FF00" or "|cFFFF0000",
                p.toggles.essences.value and "|cFF00FF00" or "|cFFFF0000",
                p.toggles.interrupts.value and "|cFF00FF00" or "|cFFFF0000" )
        end
    end

    Hekili_OnAddonCompartmentEnter = function( addonName, button )
        GameTooltip:SetOwner( AddonCompartmentFrame )
        GameTooltip:AddDoubleLine( "Hekili", GetDataText() )
        GameTooltip:AddLine( "|cFFFFFFFF单击左键可进行快速调整。|r" )
        GameTooltip:AddLine( "|cFFFFFFFF单击右键单开选项界面。|r" )
        GameTooltip:Show()
    end

    Hekili_OnAddonCompartmentLeave = function( addonName, button )
        GameTooltip:Hide()
    end

    AddonCompartmentFrame:RegisterAddon({
        text = "Hekili",
        icon = "Interface\\AddOns\\Hekili\\Textures\\LOGO-ORANGE.blp",
        registerForAnyClick = true,
        notCheckable = true,
        func = Hekili_OnAddonCompartmentClick,
        funcOnEnter = Hekili_OnAddonCompartmentEnter,
        funcOnLeave = Hekili_OnAddonCompartmentLeave
    } )

    if LDB then
        ns.UI.Minimap = ns.UI.Minimap or LDB:NewDataObject( "Hekili", {
            type = "data source",
            text = "Hekili",
            icon = "Interface\\ICONS\\spell_nature_bloodlust",
            OnClick = Hekili_OnAddonCompartmentClick,
            OnEnter = function( self )
                GameTooltip:SetOwner( self )
                GameTooltip:AddDoubleLine( "Hekili", ns.UI.Minimap.text )
                GameTooltip:AddLine( "|cFFFFFFFF单击左键可进行快速调整。|r" )
                GameTooltip:AddLine( "|cFFFFFFFF单击右键单开选项界面。|r" )
                GameTooltip:Show()
            end,
            OnLeave = Hekili_OnAddonCompartmentLeave
        } )

        function ns.UI.Minimap:RefreshDataText()
            self.text = GetDataText()
        end

        ns.UI.Minimap:RefreshDataText()

        if LDBIcon then
            LDBIcon:Register( "Hekili", ns.UI.Minimap, self.DB.profile.iconStore )
        end
    end

    self:RestoreDefaults()
    self:RunOneTimeFixes()

    checkImports()
    ns.primeTooltipColors()

    self.PendingSpecializationChange = true
    callHook( "onInitialize" )
end


function Hekili:ReInitialize()
    self:OverrideBinds()
    self:RestoreDefaults()

    checkImports()
    self:RunOneTimeFixes()

    self.PendingSpecializationChange = true

    callHook( "onInitialize" )

    if self.DB.profile.enabled == false and self.DB.profile.AutoDisabled then
        self.DB.profile.AutoDisabled = nil
        self.DB.profile.enabled = true
        self:Enable()
    end
end


function Hekili:OnEnable()
    ns.StartEventHandler()
    self:TotalRefresh( true )

    ns.ReadKeybindings()

    self.PendingSpecializationChange = true
    self:ForceUpdate( "ADDON_ENABLED" )

    if self.BuiltFor > self.CurrentBuild then
        self:Notify( "|cFFFF0000WARNING|r: 当前版本的Hekili是为WOW的未来版本准备的。你应该重新安装 " .. self.GameBuild .. "。" )
    end
end


Hekili:ProfileCPU( "StartEventHandler", ns.StartEventHandler )
Hekili:ProfileCPU( "BuildUI", Hekili.BuildUI )
Hekili:ProfileCPU( "SpecializationChanged", Hekili.SpecializationChanged )
Hekili:ProfileCPU( "OverrideBinds", Hekili.OverrideBinds )
Hekili:ProfileCPU( "TotalRefresh", Hekili.TotalRefresh )


function Hekili:OnDisable()
    self:UpdateDisplayVisibility()
    self:BuildUI()

    ns.StopEventHandler()
end


function Hekili:Toggle()
    self.DB.profile.enabled = not self.DB.profile.enabled

    if self.DB.profile.enabled then
        self:Enable()
    else
        self:Disable()
    end

    self:UpdateDisplayVisibility()
end


local z_PVP = {
    arena = true,
    pvp = true
}


local listStack = {}    -- listStack for a given index returns the scriptID of its caller (or 0 if called by a display).

local listCache = {}    -- listCache is a table of return values for a given scriptID at various times.
local listValue = {}    -- listValue shows the cached values from the listCache.

local lcPool = {}
local lvPool = {}

local Stack = {}
local Block = {}
local InUse = {}

local StackPool = {}


function Hekili:AddToStack( script, list, parent, run )
    local entry = tremove( StackPool ) or {}

    entry.script   = script
    entry.list     = list
    entry.parent   = parent
    entry.run      = run
    entry.priorMin = nil

    tinsert( Stack, entry )

    if self.ActiveDebug then
        local path = "+"

        for n, entry in ipairs( Stack ) do
            if entry.run then
                path = format( "%s%s [%s]", path, ( n > 1 and "," or "" ), entry.list )
            else
                path = format( "%s%s %s", path,( n > 1 and "," or "" ), entry.list )
            end
        end

        self:Debug( path )
    end

    -- if self.ActiveDebug then self:Debug( "Adding " .. list .. " to stack, parent is " .. ( parent or "(none)" ) .. " (RAL = " .. tostring( run ) .. ".") end

    InUse[ list ] = true
end


local blockValues = {}
local inTable = {}

local function blockHelper( ... )
    local n = select( "#", ... )
    twipe( inTable )

    for i = 1, n do
        local val = select( i, ... )

        if val > 0 and val >= state.delayMin and not inTable[ val ] then
            blockValues[ #blockValues + 1 ] = val
            inTable[ val ] = true
        end
    end

    table.sort( blockValues )
end


function Hekili:PopStack()
    local x = tremove( Stack, #Stack )
    if not x then return end

    if self.ActiveDebug then
        if x.run then
            self:Debug( "- [%s]", x.list )
        else
            self:Debug( "- %s", x.list )
        end
    end

    -- if self.ActiveDebug then self:Debug( "Removed " .. x.list .. " from stack." ) end
    if x.priorMin then
        if self.ActiveDebug then Hekili:Debug( "Resetting delayMin to %.2f from %.2f.", x.priorMin, state.delayMin ) end
        state.delayMin = x.priorMin
    end

    for i = #Block, 1, -1 do
        if Block[ i ].parent == x.script then
            if self.ActiveDebug then self:Debug( "Removed " .. Block[ i ].list .. " from blocklist as " .. x.list .. " was its parent." ) end
            tinsert( StackPool, tremove( Block, i ) )
        end
    end

    if x.run then
        -- This was called via Run Action List; we have to make sure it DOESN'T PASS until we exit this list.
        if self.ActiveDebug then self:Debug( "Added " .. x.list .. " to blocklist as it was called via RAL." ) end
        state:PurgeListVariables( x.list )
        tinsert( Block, x )

        -- Set up new delayMin.
        x.priorMin = state.delayMin
        local actualDelay = state.delay

        -- If the script would block at the present time, find when it wouldn't block.
        if scripts:CheckScript( x.script ) then
            local script = scripts:GetScript( x.script )

            if script.Recheck then
                if #blockValues > 0 then twipe( blockValues ) end
                blockHelper( script.Recheck() )

                local firstFail

                if Hekili.ActiveDebug then Hekili:Debug( " - blocking script did not immediately block; will attempt to tune it." ) end
                for i, check in ipairs( blockValues ) do
                    state.delay = actualDelay + check

                    if not scripts:CheckScript( x.script ) then
                        firstFail = check
                        break
                    end
                end

                if firstFail and firstFail > 0 then
                    state.delayMin = actualDelay + firstFail

                    local subFail

                    -- May want to try to tune even better?
                    for i = 1, 10 do
                        if subFail then subFail = firstFail - ( firstFail - subFail ) / 2
                        else subFail = firstFail / 2 end

                        state.delay = actualDelay + subFail
                        if not scripts:CheckScript( x.script ) then
                            firstFail = subFail
                            subFail = nil
                        end
                    end

                    state.delayMin = actualDelay + firstFail
                    if Hekili.ActiveDebug then Hekili:Debug( " - setting delayMin to " .. state.delayMin .. " based on recheck and brute force." ) end
                else
                    state.delayMin = x.priorMin
                    -- Leave it alone.
                    if Hekili.ActiveDebug then Hekili:Debug( " - leaving delayMin at " .. state.delayMin .. "." ) end
                end
            end
        end

        state.delay = actualDelay
    end

    InUse[ x.list ] = nil
end


function Hekili:CheckStack()
    local t = state.query_time

    for i, b in ipairs( Block ) do
        listCache[ b.script ] = listCache[ b.script ] or tremove( lcPool ) or {}
        local cache = listCache[ b.script ]

        if cache[ t ] == nil then cache[ t ] = scripts:CheckScript( b.script ) end

        if self.ActiveDebug then
            listValue[ b.script ] = listValue[ b.script ] or tremove( lvPool ) or {}
            local values = listValue[ b.script ]

            values[ t ] = values[ t ] or scripts:GetConditionsAndValues( b.script )
            self:Debug( "Blocking list ( %s ) called from ( %s ) would %s at %.2f.", b.list, b.script, cache[ t ] and "BLOCK" or "NOT BLOCK", state.delay )
            self:Debug( values[ t ] )
        end

        if cache[ t ] then
            return false
        end
    end


    for i, s in ipairs( Stack ) do
        listCache[ s.script ] = listCache[ s.script ] or tremove( lcPool ) or {}
        local cache = listCache[ s.script ]

        if cache[ t ] == nil then cache[ t ] = scripts:CheckScript( s.script ) end

        if self.ActiveDebug then
            listValue[ s.script ] = listValue[ s.script ] or tremove( lvPool ) or {}
            local values = listValue[ s.script ]

            values[ t ] = values[ t ] or scripts:GetConditionsAndValues( s.script )
            self:Debug( "List ( %s ) called from ( %s ) would %s at %.2f.", s.list, s.script, cache[ t ] and "PASS" or "FAIL", state.delay )
            self:Debug( values[ t ]:gsub( "%%", "%%%%" ) )
        end

        if not cache[ t ] then
            return false
        end
    end

    return true
end



local function return_false() return false end

local default_modifiers = {
    early_chain_if = return_false,
    chain = return_false,
    interrupt_if = return_false,
    interrupt = return_false
}

function Hekili:CheckChannel( ability, prio )
    if not state.channeling then
        if self.ActiveDebug then self:Debug( "CC: We aren't channeling; CheckChannel is false." ) end
        return false
    end

    local channel = state.buff.casting.up and ( state.buff.casting.v3 == 1 ) and state.buff.casting.v1 or nil

    if not channel then
        if self.ActiveDebug then self:Debug( "CC: We are not channeling per buff.casting.v3; CheckChannel is false." ) end
        return false
    end

    local a = class.abilities[ channel ]

    if not a then
        if self.ActiveDebug then self:Debug( "CC: We don't recognize the channeled spell; CheckChannel is false." ) end
        return false
    end

    channel = a.key
    local aura = class.auras[ a.aura or channel ]

    if a.break_any and channel ~= ability then
        if self.ActiveDebug then self:Debug( "CC: %s.break_any is true; break it.", channel ) end
        return true
    end

    if not a.tick_time and ( not aura or not aura.tick_time ) then
        if self.ActiveDebug then self:Debug( "CC: No aura / no aura.tick_time to forecast channel breaktimes; don't break it." ) end
        return false
    end

    local modifiers = scripts.Channels[ state.system.packName ]
    modifiers = modifiers and modifiers[ channel ] or default_modifiers

    --[[ if self.ActiveDebug then
        if default_modifiers == modifiers then
            self:Debug( "Using default modifiers." )
        else
            local vals = ""
            for k, v in pairs( modifiers ) do
                vals = format( "%s%s = %s - ", vals, tostring( k ), tostring( type(v) == "function" and v() or v ) )
            end

            self:Debug( "Channel modifiers: %s", vals )
        end
    end ]]

    local tick_time = a.tick_time or aura.tick_time
    local remains = state.channel_remains

    if channel == ability then
        if prio <= remains + 0.01 then
            if self.ActiveDebug then self:Debug( "CC: ...looks like chaining, not breaking channel.", ability ) end
            return false
        end
        if modifiers.early_chain_if then
            local eci = state.cooldown.global_cooldown.ready and ( remains < tick_time or ( ( remains - state.delay ) / tick_time ) % 1 <= 0.5 ) and modifiers.early_chain_if()
            if self.ActiveDebug then self:Debug( "CC: early_chain_if returns %s...", tostring( eci ) ) end
            return eci
        end
        if modifiers.chain then
            local chain = state.cooldown.global_cooldown.ready and ( remains < tick_time ) and modifiers.chain()
            if self.ActiveDebug then self:Debug( "CC: chain returns %s...", tostring( chain ) ) end
            return chain
        end

        if self.ActiveDebug then self:Debug( "CC: channel == ability, not breaking." ) end
        return false

    else
        -- If interrupt_global is flagged, we interrupt for any potential cast.  Don't bother with additional testing.
        -- REVISIT THIS:  Interrupt Global allows entries from any action list rather than just the current (sub) list.
        -- That means interrupt / interrupt_if should narrow their scope to the current APL (at some point, anyway).
        --[[ if modifiers.interrupt_global and modifiers.interrupt_global() then
            if self.ActiveDebug then self:Debug( "CC:  Interrupt Global is true." ) end
            return true
        end ]]

        local act = state.this_action
        state.this_action = channel

        -- We are concerned with chain and early_chain_if.
        if modifiers.interrupt_if and modifiers.interrupt_if() then
            local imm = modifiers.interrupt_immediate and modifiers.interrupt_immediate() or nil
            local val = state.cooldown.global_cooldown.ready and ( imm or remains < tick_time or ( state.query_time - state.buff.casting.applied ) % tick_time < 0.25 )
            if self.ActiveDebug then
                self:Debug( "CC:  Interrupt_If is %s.", tostring( val ) )
            end
            state.this_action = act
            return val
        end

        if modifiers.interrupt and modifiers.interrupt() then
            local val = state.cooldown.global_cooldown.ready and ( remains < tick_time or ( ( remains - state.delay ) / tick_time ) % 1 <= 0.5 )
            if self.ActiveDebug then self:Debug( "CC:  Interrupt is %s.", tostring( val ) ) end
            state.this_action = act
            return val
        end

        state.this_action = act
    end

    if self.ActiveDebug then self:Debug( "CC:  No result; defaulting to false." ) end
    return false
end


do
    local knownCache = {}
    local reasonCache = {}

    function Hekili:IsSpellKnown( spell )
        return state:IsKnown( spell )
        --[[ local id = class.abilities[ spell ] and class.abilities[ spell ].id or spell

        if knownCache[ id ] ~= nil then return knownCache[ id ], reasonCache[ id ] end
        knownCache[ id ], reasonCache[ id ] = state:IsKnown( spell )
        return knownCache[ id ], reasonCache[ id ] ]]
    end


    local disabledCache = {}
    local disabledReasonCache = {}

    function Hekili:IsSpellEnabled( spell )
        local disabled, reason = state:IsDisabled( spell )
        return not disabled, reason
    end


    function Hekili:ResetSpellCaches()
        twipe( knownCache )
        twipe( reasonCache )

        twipe( disabledCache )
        twipe( disabledReasonCache )
    end
end


local Timer = {
    start = 0,
    n = {},
    v = {},

    Reset = function( self )
        if not Hekili.ActiveDebug then return end

        twipe( self.n )
        twipe( self.v )

        self.start = debugprofilestop()
        self.n[1] = "Start"
        self.v[1] = self.start
    end,

    Track = function( self, key )
        if not Hekili.ActiveDebug then return end
        tinsert( self.n, key )
        tinsert( self.v, debugprofilestop() )
    end,

    Output = function( self )
        if not Hekili.ActiveDebug then return "" end

        local o = ""

        for i = 2, #self.n do
            o = string.format( "%s:%s(%.2f)", o, self.n[i], ( self.v[i] - self.v[i-1] ) )
        end

        return o
    end,

    Total = function( self )
        if not Hekili.ActiveDebug then return "" end
        return string.format("%.2f", self.v[#self.v] - self.start )
    end,
}


do
    local function DoYield( self, msg, time, force )
        if not coroutine.running() then return end
        time = time or debugprofilestop()

        if msg then
            self.Engine.lastYieldReason = msg
        end

        if force or self.maxFrameTime > 0 and time - self.activeFrameStart > self.maxFrameTime then
            coroutine.yield()
        end
    end

    local function FirstYield( self, msg, time )
        if Hekili.PLAYER_ENTERING_WORLD and not Hekili.LoadingScripts then
            self.Yield = DoYield
        end
    end

    Hekili.Yield = FirstYield
end


local invalidActionWarnings = {}

function Hekili:GetPredictionFromAPL( dispName, packName, listName, slot, action, wait, depth, caller )
    local specID = state.spec.id
    local spec = rawget( self.DB.profile.specs, specID )
    local module = class.specs[ specID ]

    packName = packName or spec and spec.package

    if not packName then return end

    local pack
    if ( packName == "UseItems" ) then pack = class.itemPack
    else pack = self.DB.profile.packs[ packName ] end

    local packInfo = scripts.PackInfo[ spec.package ]
    local list = pack.lists[ listName ]

    local debug = self.ActiveDebug

    -- if debug then self:Debug( "ListCheck: Success(%s-%s)", packName, listName ) end

    local precombatFilter = listName == "precombat" and state.time > 0

    local rAction = action
    local rWait = wait or 15
    local rDepth = depth or 0

    local strict = false -- disabled for now.
    local force_channel = false
    local stop = false

    if debug then self:Debug( "Current recommendation was %s at +%.2fs.", action or "NO ACTION", wait or state.delayMax ) end

    if self:IsListActive( packName, listName ) then
        local actID = 1

        while actID <= #list do
            self:Yield( "GetPrediction... " .. dispName .. "-" .. packName .. ":" .. actID )

            if rWait < state.delayMax then state.delayMax = rWait end

            --[[ Watch this section, may impact usage of off-GCD abilities.
            if rWait <= state.cooldown.global_cooldown.remains and not state.spec.can_dual_cast then
                if debug then self:Debug( "The recommended action (%s) would be ready before the next GCD (%.2f < %.2f); exiting list (%s).", rAction, rWait, state.cooldown.global_cooldown.remains, listName ) end
                break

            else ]]
            if rWait <= 0.2 then
                if debug then self:Debug( "The recommended action (%s) is ready in less than 0.2s; exiting list (%s).", rAction, listName ) end
                break

            elseif state.delayMin > state.delayMax then
                if debug then self:Debug( "The current minimum delay (%.2f) is greater than the current maximum delay (%.2f). Exiting list (%s).", state.delayMin, state.delayMax, listName ) end
                break

            elseif rAction and not packInfo.hasOffGCD and rWait <= state.cooldown.global_cooldown.remains then -- and state.settings.gcdSync then
                if debug then self:Debug( "The recommended action (%s) is ready within the active GCD; exiting list (%s).", rAction, listName ) end
                break

            elseif rAction and state.empowering[ rAction ] then
                if debug then self:Debug( "The recommended action (%s) is currently empowering; exiting list (%s).", rAction, listName ) end
                break

            elseif stop then
                if debug then self:Debug( "The action list reached a stopping point; exiting list (%s).", listName ) end
                break

            end

            Timer:Reset()

            local entry = list[ actID ]

            if self:IsActionActive( packName, listName, actID ) then
                -- Check for commands before checking actual actions.
                local scriptID = packName .. ":" .. listName .. ":" .. actID
                local action = entry.action

                state.this_action = action
                state.delay = nil

                local ability = class.abilities[ action ]

                if not ability then
                    if not invalidActionWarnings[ scriptID ] then
                        Hekili:Error( "Priority '%s' uses action '%s' ( %s - %d ) that is not found in the abilities table.", packName, action or "unknown", listName, actID )
                        invalidActionWarnings[ scriptID ] = true
                    end

                elseif state.whitelist and not state.whitelist[ action ] and ( ability.id < -99 or ability.id > 0 ) then
                    if debug then self:Debug( "[---] %s ( %s - %d) not castable while casting a spell; skipping...", action, listName, actID ) end

                elseif rWait <= state.cooldown.global_cooldown.remains and not state.spec.can_dual_cast and ability.gcd ~= "off" then
                    if debug then self:Debug( "Only off-GCD abilities would be usable before the currently selected ability; skipping..." ) end

                else
                    local entryReplaced = false

                    if action == "heart_essence" and class.essence_unscripted and class.active_essence then
                        action = class.active_essence
                        ability = class.abilities[ action ]
                        state.this_action = action
                        entryReplaced = true
                    elseif action == "trinket1" then
                        if state.trinket.t1.usable and state.trinket.t1.ability and not Hekili:IsItemScripted( state.trinket.t1.ability, true ) then
                            action = state.trinket.t1.ability
                            ability = class.abilities[ action ]
                            state.this_action = action
                            entryReplaced = true
                        else
                            if debug then
                                self:Debug( "\nBypassing 'trinket1' action because %s.", state.trinket.t1.usable and state.trinket.t1.ability and ( state.trinket.t1.ability .. " is used elsewhere in this priority" ) or "the equipped trinket #1 is not usable" )
                            end
                            ability = nil
                        end
                    elseif action == "trinket2" then
                        if state.trinket.t2.usable and state.trinket.t2.ability and not Hekili:IsItemScripted( state.trinket.t2.ability, true ) then
                            action = state.trinket.t2.ability
                            ability = class.abilities[ action ]
                            state.this_action = action
                            entryReplaced = true
                        else
                            if debug then
                                self:Debug( "\nBypassing 'trinket2' action because %s.", state.trinket.t2.usable and state.trinket.t2.ability and ( state.trinket.t2.ability .. " is used elsewhere in this priority" ) or "the equipped trinket #2 is not usable" )
                            end
                            ability = nil
                        end
                    elseif action == "main_hand" and class.abilities[ action ].key ~= action and not Hekili:IsItemScripted( action, true ) then
                        action = class.abilities[ action ].key
                        state.this_action = action
                        entryReplaced = true
                    end

                    rDepth = rDepth + 1
                    -- if debug then self:Debug( "[%03d] %s ( %s - %d )", rDepth, action, listName, actID ) end

                    local wait_time = state.delayMax or 15
                    local clash = 0

                    local known, reason = self:IsSpellKnown( action )
                    local enabled, enReason = self:IsSpellEnabled( action )

                    local scriptID = packName .. ":" .. listName .. ":" .. actID
                    state.scriptID = scriptID

                    if debug then
                        local d = ""
                        if entryReplaced then d = format( "\nSubstituting %s for %s action; it is otherwise not included in the priority.", action, class.abilities[ entry.action ].name ) end

                        if action == "call_action_list" or action == "run_action_list" then
                            d = d .. format( "\n%-4s %s ( %s - %d )", rDepth .. ".", ( action .. ":" .. ( state.args.list_name or "unknown" ) ), listName, actID )
                        elseif action == "cancel_buff" then
                            d = d .. format( "\n%-4s %s ( %s - %d )", rDepth .. ".", ( action .. ":" .. ( state.args.buff_name or "unknown" ) ), listName, actID )
                        elseif action == "cancel_action" then
                            d = d .. format( "\n%-4s %s ( %s - %d )", rDepth .. ".", ( action .. ":" .. ( state.args.action_name or "unknown" ) ), listName, actID )
                        else
                            d = d .. format( "\n%-4s %s ( %s - %d )", rDepth .. ".", action, listName, actID )
                        end

                        if not known then d = d .. " - " .. ( reason or "ability unknown" )
                        elseif not enabled then d = d .. " - ability disabled ( " .. ( enReason or "unknown" ) .. " )" end

                        self:Debug( d )
                    end

                    Timer:Track( "Ability Known, Enabled" )

                    if ability and known and enabled then
                        local script = scripts:GetScript( scriptID )

                        wait_time = state:TimeToReady()
                        clash = state.ClashOffset()

                        state.delay = wait_time

                        if not script then
                            if debug then self:Debug( "There is no script ( " .. scriptID .. " ).  Skipping." ) end
                        elseif script.Error then
                            if debug then self:Debug( "The conditions for this entry contain an error.  Skipping." ) end
                        elseif wait_time > state.delayMax then
                            if debug then self:Debug( "The action is not ready ( %.2f ) before our maximum delay window ( %.2f ) for this query.", wait_time, state.delayMax ) end
                        elseif ( rWait - state.ClashOffset( rAction ) ) - ( wait_time - clash ) <= 0.05 then
                            if debug then self:Debug( "The action is not ready in time ( %.2f vs. %.2f ) [ Clash: %.2f vs. %.2f ] - padded by 0.05s.", wait_time, rWait, clash, state.ClashOffset( rAction ) ) end
                        else
                            -- APL checks.
                            if precombatFilter and not ability.essential then
                                if debug then self:Debug( "We are already in-combat and this pre-combat action is not essential.  Skipping." ) end
                            else
                                Timer:Track("Post-TTR and Essential")
                                if action == "call_action_list" or action == "run_action_list" or action == "use_items" then
                                    -- We handle these here to avoid early forking between starkly different APLs.
                                    local aScriptPass = true
                                    local ts = not strict and entry.strict ~= 1 and scripts:IsTimeSensitive( scriptID )

                                    if not entry.criteria or entry.criteria == "" then
                                        if debug then self:Debug( "There is no criteria for %s.", action == "use_items" and "Use Items" or state.args.list_name or "this action list" ) end
                                        -- aScriptPass = ts or self:CheckStack()
                                    else
                                        aScriptPass = scripts:CheckScript( scriptID ) -- and self:CheckStack() -- we'll check the stack with the list's entries.

                                        if not aScriptPass and ts then
                                            -- Time-sensitive criteria, let's see if we have rechecks that would pass.
                                            state.recheck( action, script, Stack, Block )

                                            if #state.recheckTimes == 0 then
                                                if debug then self:Debug( "Time-sensitive Criteria FAIL at +%.2f with no valid rechecks - %s", state.offset, scripts:GetConditionsAndValues( scriptID ) ) end
                                                ts = false
                                            elseif state.delayMax and state.recheckTimes[ 1 ] > state.delayMax then
                                                if debug then self:Debug( "Time-sensitive Criteria FAIL at +%.2f with rechecks outside of max delay ( %.2f > %.2f ) - %s", state.offset, state.recheckTimes[ 1 ], state.delayMax, scripts:GetConditionsAndValues( scriptID ) ) end
                                                ts = false
                                            elseif state.recheckTimes[ 1 ] > rWait then
                                                if debug then self:Debug( "Time-sensitive Criteria FAIL at +%.2f with rechecks greater than wait time ( %.2f > %.2f ) - %s", state.offset, state.recheckTimes[ 1 ], rWait, scripts:GetConditionsAndValues( scriptID ) ) end
                                                ts = false
                                            end
                                        else
                                            if debug then
                                                self:Debug( "%sCriteria for %s %s at +%.2f - %s", ts and "Time-sensitive " or "", state.args.list_name or "???", ts and "deferred" or ( aScriptPass and "PASS" or "FAIL" ), state.offset, scripts:GetConditionsAndValues( scriptID ) )
                                            end
                                        end

                                        aScriptPass = ts or aScriptPass
                                    end

                                    if aScriptPass then
                                        if action == "use_items" then
                                            self:AddToStack( scriptID, "items", caller )
                                            rAction, rWait, rDepth = self:GetPredictionFromAPL( dispName, "UseItems", "items", slot, rAction, rWait, rDepth, scriptID )
                                            if debug then self:Debug( "Returned from Use Items; current recommendation is %s (+%.2f).", rAction or "NO ACTION", rWait ) end
                                            self:PopStack()
                                        else
                                            local name = state.args.list_name

                                            if InUse[ name ] then
                                                if debug then self:Debug( "Action list (%s) was found, but would cause a loop.", name ) end

                                            elseif name and pack.lists[ name ] then
                                                if debug then self:Debug( "Action list (%s) was found.", name ) end
                                                self:AddToStack( scriptID, name, caller, action == "run_action_list" )

                                                rAction, rWait, rDepth = self:GetPredictionFromAPL( dispName, packName, name, slot, rAction, rWait, rDepth, scriptID )
                                                if debug then self:Debug( "Returned from list (%s), current recommendation is %s (+%.2f).", name, rAction or "NO ACTION", rWait ) end

                                                self:PopStack()

                                                -- REVISIT THIS:  IF A RUN_ACTION_LIST CALLER IS NOT TIME SENSITIVE, DON'T BOTHER LOOPING THROUGH IT IF ITS CONDITIONS DON'T PASS.
                                                -- if action == "run_action_list" and not ts then
                                                --    if debug then self:Debug( "This entry was not time-sensitive; exiting loop." ) end
                                                --    break
                                                -- end

                                            else
                                                if debug then self:Debug( "Action list (%s) not found.  Skipping.", name or "no name" ) end

                                            end
                                        end
                                    end

                                elseif action == "variable" then
                                    local name = state.args.var_name

                                    if class.variables[ name ] then
                                        if debug then self:Debug( " - variable.%s references a hardcoded variable and this entry will be ignored.", name ) end
                                    elseif name ~= nil then
                                        state:RegisterVariable( name, scriptID, listName, Stack )
                                        if debug then self:Debug( " - variable.%s[%s] will check this script entry ( %s )", name, tostring( state.variable[ name ] ), scriptID ) end
                                    else
                                        if debug then self:Debug( " - variable name not provided, skipping." ) end
                                    end

                                else
                                    -- Target Cycling.
                                    -- We have to determine *here* whether the ability would be used on the current target or a different target.
                                    if state.args.cycle_targets == 1 and state.settings.cycle and state.active_enemies > 1 then
                                        state.SetupCycle( ability )

                                        if state.cycle_enemies == 1 then
                                            if debug then Hekili:Debug( "There is only 1 valid enemy for target cycling; canceling cycle." ) end
                                            state.ClearCycle()
                                        end
                                    else
                                        state.ClearCycle()
                                    end

                                    Timer:Track("Post Cycle")

                                    local usable, why = state:IsUsable()

                                    Timer:Track("Post Usable")

                                    if debug then
                                        if usable then
                                            local cost = state.action[ action ].cost
                                            local costType = state.action[ action ].cost_type

                                            if cost and cost > 0 then
                                                self:Debug( "The action (%s) is usable at (%.2f + %.2f) with cost of %d %s (have %d).", action, state.offset, state.delay, cost or 0, costType or "unknown", costType and state[ costType ] and state[ costType ].current or -1 )
                                            else
                                                self:Debug( "The action (%s) is usable at (%.2f + %.2f).", action, state.offset, state.delay )
                                            end
                                        else
                                            self:Debug( "The action (%s) is unusable at (%.2f + %.2f) because %s.", action, state.offset, state.delay, why or "IsUsable returned false" )
                                        end
                                    end


                                    if usable then
                                        local waitValue = max( 0, rWait - state:ClashOffset( rAction ) )
                                        local readyFirst = state.delay - clash < waitValue

                                        if debug then self:Debug( " - the action is %sready before the current recommendation (at +%.2f vs. +%.2f).", readyFirst and "" or "NOT ", state.delay, waitValue ) end

                                        if readyFirst then
                                            local hasResources = true

                                            Timer:Track("Post Ready/Clash")

                                            if hasResources then
                                                local channelPass = not state.channeling or ( action ~= state.channel ) or self:CheckChannel( action, rWait )
                                                local aScriptPass = channelPass and self:CheckStack()

                                                Timer:Track("Post Stack")

                                                if not channelPass then
                                                    if debug then self:Debug( " - this entry cannot break the channeled spell." ) end
                                                    if action == state.channel then
                                                        stop = scripts:CheckScript( scriptID )
                                                    end

                                                elseif not aScriptPass then
                                                    if debug then self:Debug( " - this entry would not be reached at the current time via the current action list path (%.2f).", state.delay ) end

                                                else
                                                    if not entry.criteria or entry.criteria == '' then
                                                        if debug then
                                                            self:Debug( " - this entry has no criteria to test." )
                                                            if not channelPass then self:Debug( "   - however, criteria not met to break current channeled spell." )  end
                                                        end
                                                    else
                                                        Timer:Track("Pre-Script")
                                                        aScriptPass = scripts:CheckScript( scriptID )
                                                        Timer:Track("Post-Script")

                                                        if debug then
                                                            self:Debug( " - this entry's criteria %s: %s", aScriptPass and "PASSES" or "FAILS", scripts:GetConditionsAndValues( scriptID ) )
                                                        end
                                                    end
                                                end

                                                Timer:Track("Pre-Recheck")

                                                -- NEW:  If the ability's conditions didn't pass, but the ability can report on times when it should recheck, let's try that now.
                                                if not aScriptPass then
                                                    state.recheck( action, script, Stack, Block )

                                                    Timer:Track("Post-Recheck Times")

                                                    if #state.recheckTimes == 0 then
                                                        if debug then self:Debug( "There were no recheck events to check." ) end
                                                    else
                                                        local base_delay = state.delay

                                                        if debug then self:Debug( "There are " .. #state.recheckTimes .. " recheck events." ) end

                                                        local first_rechannel = 0

                                                        Timer:Track("Pre-Recheck Loop")

                                                        for i, step in pairs( state.recheckTimes ) do
                                                            local new_wait = base_delay + step

                                                            Timer:Track("Recheck Loop Start")

                                                            if new_wait >= 10 then
                                                                if debug then self:Debug( "Rechecking stopped at step #%d.  The recheck ( %.2f ) isn't ready within a reasonable time frame ( 10s ).", i, new_wait ) end
                                                                break
                                                            elseif ( action ~= state.channel ) and waitValue <= base_delay + step + 0.05 then
                                                                if debug then self:Debug( "Rechecking stopped at step #%d.  The previously chosen ability is ready before this recheck would occur ( %.2f <= %.2f + 0.05 ).", i, waitValue, new_wait ) end
                                                                break
                                                            end

                                                            state.delay = base_delay + step

                                                            local usable, why = state:IsUsable()
                                                            if debug then
                                                                if not usable then
                                                                    self:Debug( "The action (%s) is no longer usable at (%.2f + %.2f) because %s.", action, state.offset, state.delay, why or "IsUsable returned false" )
                                                                    state.delay = base_delay
                                                                    break
                                                                end
                                                            end

                                                            Timer:Track("Recheck Post-Usable")

                                                            if self:CheckStack() then
                                                                Timer:Track("Recheck Post-Stack")

                                                                aScriptPass = scripts:CheckScript( scriptID )

                                                                Timer:Track("Recheck Post-Script")

                                                                channelPass = not state.channeling or ( action ~= state.channel ) or self:CheckChannel( action, rWait )

                                                                Timer:Track("Recheck Post-Channel")

                                                                if debug then
                                                                    self:Debug( "Recheck #%d ( +%.2f ) %s: %s", i, state.delay, aScriptPass and "MET" or "NOT MET", scripts:GetConditionsAndValues( scriptID ) )
                                                                    if not channelPass then self:Debug( " - however, criteria not met to break current channeled spell." ) end
                                                                end

                                                                aScriptPass = aScriptPass and channelPass
                                                            else
                                                                if debug then self:Debug( "Unable to recheck #%d at %.2f, as APL conditions would not pass.", i, state.delay ) end
                                                            end

                                                            Timer:Track("Recheck Loop End")

                                                            if aScriptPass then
                                                                if first_rechannel == 0 and state.channel and action == state.channel then
                                                                    first_rechannel = state.delay
                                                                    if debug then self:Debug( "This is the currently channeled spell; it would be rechanneled at this time, will check end of channel.  " .. state.channel_remains ) end
                                                                elseif first_rechannel > 0 and ( not state.channel or state.channel_remains < 0.05 ) then
                                                                    if debug then self:Debug( "Appears that the ability would be cast again at the end of the channel, stepping back to first rechannel point.  " .. state.channel_remains ) end
                                                                    state.delay = first_rechannel
                                                                    waitValue = first_rechannel
                                                                    break
                                                                else break end
                                                            else state.delay = base_delay end
                                                        end
                                                        Timer:Track("Post Recheck Loop")
                                                    end
                                                end

                                                Timer:Track("Post Recheck")

                                                if aScriptPass then
                                                    if action == "potion" then
                                                        local item = class.abilities.potion.item

                                                        slot.scriptType = "simc"
                                                        slot.script = scriptID
                                                        slot.hook = caller

                                                        slot.display = dispName
                                                        slot.pack = packName
                                                        slot.list = listName
                                                        slot.listName = listName
                                                        slot.action = actID
                                                        slot.actionName = state.this_action
                                                        slot.actionID = -1 * item

                                                        slot.texture = select( 10, GetItemInfo( item ) )
                                                        slot.caption = ability.caption or entry.caption
                                                        slot.item = item

                                                        slot.wait = state.delay
                                                        slot.resource = state.GetResourceType( rAction )

                                                        rAction = state.this_action
                                                        rWait = state.delay

                                                        if debug then
                                                            -- scripts:ImplantDebugData( slot )
                                                            self:Debug( "Action chosen:  %s at %.2f!", rAction, rWait )
                                                        end

                                                        -- slot.indicator = ( entry.Indicator and entry.Indicator ~= "none" ) and entry.Indicator

                                                        state.selection_time = state.delay
                                                        state.selected_action = rAction

                                                    elseif action == "wait" then
                                                        local sec = state.args.sec or 0.5

                                                        if sec <= 0 then
                                                            if debug then self:Debug( "Invalid wait value ( %.2f ); skipping...", sec ) end
                                                        else
                                                            slot.scriptType = "simc"
                                                            slot.script = scriptID
                                                            slot.hook = caller

                                                            slot.display = dispName
                                                            slot.pack = packName
                                                            slot.list = listName
                                                            slot.listName = listName
                                                            slot.action = actID
                                                            slot.actionName = state.this_action
                                                            slot.actionID = ability.id

                                                            slot.caption = ability.caption or entry.caption
                                                            slot.texture = ability.texture
                                                            slot.indicator = ability.indicator

                                                            if ability.interrupt and state.buff.casting.up then
                                                                slot.interrupt = true
                                                                slot.castStart = state.buff.casting.applied
                                                            else
                                                                slot.interrupt = nil
                                                                slot.castStart = nil
                                                            end

                                                            slot.wait = state.delay
                                                            slot.waitSec = sec

                                                            slot.resource = state.GetResourceType( rAction )

                                                            rAction = state.this_action
                                                            rWait = state.delay

                                                            state.selection_time = state.delay
                                                            state.selected_action = rAction

                                                            if debug then
                                                                self:Debug( "Action chosen:  %s at %.2f!", rAction, state.delay )
                                                            end
                                                        end

                                                    elseif action == "cancel_action" then
                                                        if state.args.action_name and state:IsChanneling( state.args.action_name ) then state.channel_breakable = true end

                                                    elseif action == "pool_resource" then
                                                        if state.args.for_next == 1 then
                                                            -- Pooling for the next entry in the list.
                                                            local next_entry  = list[ actID + 1 ]
                                                            local next_action = next_entry and next_entry.action
                                                            local next_id     = next_action and class.abilities[ next_action ] and class.abilities[ next_action ].id

                                                            local extra_amt   = state.args.extra_amount or 0

                                                            local next_known  = next_action and state:IsKnown( next_action )
                                                            local next_usable, next_why = next_action and state:IsUsable( next_action )
                                                            local next_cost   = next_action and state.action[ next_action ] and state.action[ next_action ].cost or 0
                                                            local next_res    = next_action and state.GetResourceType( next_action ) or class.primaryResource

                                                            if not next_entry then
                                                                if debug then self:Debug( "Attempted to Pool Resources for non-existent next entry in the APL.  Skipping." ) end
                                                            elseif not next_action or not next_id or next_id < 0 then
                                                                if debug then self:Debug( "Attempted to Pool Resources for invalid next entry in the APL.  Skipping." ) end
                                                            elseif not next_known then
                                                                if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but the next entry is not known.  Skipping.", next_action ) end
                                                            elseif not next_usable then
                                                                if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but the next entry is not usable because %s.  Skipping.", next_action, next_why or "of an unknown reason" ) end
                                                            elseif state.cooldown[ next_action ].remains > 0 then
                                                                if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but the next entry is on cooldown.  Skipping.", next_action ) end
                                                            elseif state[ next_res ].current >= next_cost + extra_amt then
                                                                if debut then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but we already have all the resources needed ( %.2f > %.2f + %.2f ).  Skipping.", next_ation, state[ next_res ].current, next_cost, extra_amt ) end
                                                            else
                                                                -- Oops.  We only want to wait if
                                                                local next_wait = state[ next_res ][ "time_to_" .. ( next_cost + extra_amt ) ]

                                                                --[[ if next_wait > 0 then
                                                                    if debug then self:Debug( "Next Wait: %.2f; TTR: %.2f, Resource(%.2f): %.2f", next_wait, state:TimeToReady( next_action, true ), next_cost + extra_amt, state[ next_res ][ "time_to_" .. ( next_cost + extra_amt ) ] ) end
                                                                end ]]

                                                                if next_wait <= 0 then
                                                                    if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but there is no need to wait.  Skipping.", next_action ) end
                                                                elseif next_wait >= rWait then
                                                                    if debug then self:Debug( "The currently chosen action ( %s ) is ready at or before the next action ( %.2fs <= %.2fs ).  Skipping.", ( rAction or "???" ), rWait, next_wait ) end
                                                                elseif state.delayMax and next_wait >= state.delayMax then
                                                                    if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but we would exceed our time ceiling in %.2fs.  Skipping.", next_action, next_wait ) end
                                                                elseif next_wait >= 10 then
                                                                    if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but we'd have to wait much too long ( %.2f ).  Skipping.", next_action, next_wait ) end
                                                                else
                                                                    -- Pad the wait value slightly, to make sure the resource is actually generated.
                                                                    next_wait = next_wait + 0.01
                                                                    state.offset = state.offset + next_wait

                                                                    state.this_action = next_action
                                                                    aScriptPass = not next_entry.criteria or next_entry.criteria == '' or scripts:CheckScript( packName .. ':' .. listName .. ':' .. ( actID + 1 ) )
                                                                    state.this_action = "pool_resource"

                                                                    if not aScriptPass then
                                                                        if debug then self:Debug( "Attempted to Pool Resources for Next Entry ( %s ), but its conditions would not be met.  Skipping.", next_action ) end
                                                                        state.offset = state.offset - next_wait
                                                                    else
                                                                        if debug then self:Debug( "Pooling Resources for Next Entry ( %s ), delaying by %.2f ( extra %d ).", next_action, next_wait, extra_amt ) end
                                                                        state.offset = state.offset - next_wait
                                                                        state.advance( next_wait )
                                                                    end
                                                                end
                                                            end

                                                        else
                                                            -- Pooling for a Wait Value.
                                                            -- NYI.
                                                            -- if debug then self:Debug( "Pooling for a specified period of time is not supported yet.  Skipping." ) end
                                                            if debug then self:Debug( "pool_resource is disabled as pooling is automatically accounted for by the forecasting engine." ) end
                                                        end

                                                        -- if entry.PoolForNext or state.args.for_next == 1 then
                                                        --    if debug then self:Debug( "Pool Resource is not used in the Predictive Engine; ignored." ) end
                                                        -- end

                                                    else
                                                        slot.scriptType = "simc"
                                                        slot.script = scriptID
                                                        slot.hook = caller

                                                        slot.display = dispName
                                                        slot.pack = packName
                                                        slot.list = listName
                                                        slot.listName = listName
                                                        slot.action = actID
                                                        slot.actionName = ability.key
                                                        slot.actionID = ability.id

                                                        slot.caption = not ability.empowered and ( ability.caption or entry.caption )
                                                        slot.texture = ability.texture
                                                        slot.indicator = ability.indicator

                                                        if ability.interrupt and state.buff.casting.up then
                                                            slot.interrupt = true
                                                            slot.castStart = state.buff.casting.applied
                                                        else
                                                            slot.interrupt = nil
                                                            slot.castStart = nil
                                                        end

                                                        slot.wait = state.delay
                                                        slot.waitSec = nil

                                                        slot.resource = state.GetResourceType( rAction )

                                                        rAction = state.this_action
                                                        rWait = state.delay

                                                        state.selection_time = state.delay
                                                        state.selected_action = rAction

                                                        slot.empower_to = ability.empowered and ( ability.caption or state.args.empower_to or state.max_empower ) or nil

                                                        if debug then
                                                            -- scripts:ImplantDebugData( slot )
                                                            self:Debug( "Action chosen:  %s at %.2f!", rAction, state.delay )
                                                        end

                                                        if state.IsCycling( nil, true ) then
                                                            slot.indicator = "cycle"
                                                        elseif module and module.cycle then
                                                            slot.indicator = module.cycle()
                                                        end
                                                        Timer:Track( "Action Stored" )
                                                    end
                                                end

                                                state.ClearCycle()
                                            end
                                        end
                                    end

                                    if rWait == 0 or force_channel then break end
                                end
                            end
                        end
                    end

                    if debug and action ~= "call_action_list" and action ~= "run_action_list" and action ~= "use_items" then
                        self:Debug( "Time spent on this action:  %.2fms\nTimeData:%s-%s-%d:%s:%.2f%s", Timer:Total(), packName, listName, actID, action, Timer:Total(), Timer:Output() )
                    end
                end
            else
                if debug then self:Debug( "\nEntry #%d in list ( %s ) is not set or not enabled.  Skipping.", actID, listName ) end
            end

            actID = actID + 1

        end

    else
        if debug then self:Debug( "ListActive: N (%s-%s)", packName, listName ) end
    end

    if debug then self:Debug( "Exiting %s with recommendation of %s at +%.2fs.", listName or "UNKNOWN", action or "NO ACTION", wait or state.delayMax ) end


    local scriptID = listStack[ listName ]
    listStack[ listName ] = nil

    if listCache[ scriptID ] then twipe( listCache[ scriptID ] ) end
    if listValue[ scriptID ] then twipe( listValue[ scriptID ] ) end

    return rAction, rWait, rDepth
end

Hekili:ProfileCPU( "GetPredictionFromAPL", Hekili.GetPredictionFromAPL )


function Hekili:GetNextPrediction( dispName, packName, slot )
    local debug = self.ActiveDebug

    -- This is the entry point for the prediction engine.
    -- Any cache-wiping should happen here.
    twipe( Stack )
    twipe( Block )
    twipe( InUse )

    twipe( listStack )

    for k, v in pairs( listCache ) do tinsert( lcPool, v ); twipe( v ); listCache[ k ] = nil end
    for k, v in pairs( listValue ) do tinsert( lvPool, v ); twipe( v ); listValue[ k ] = nil end

    self:ResetSpellCaches()
    state:ResetVariables()

    local display = rawget( self.DB.profile.displays, dispName )
    local pack = rawget( self.DB.profile.packs, packName )

    if not pack then return end

    local action, wait, depth = nil, 10, 0

    state.this_action = nil

    state.selection_time = 10
    state.selected_action = nil

    if self.ActiveDebug then
        self:Debug( "Checking if I'm casting ( %s ) and if it is a channel ( %s ).", state.buff.casting.up and "Yes" or "No", state.buff.casting.v3 == 1 and "Yes" or "No" )
        if state.buff.casting.up then
            if state.buff.casting.v3 == 1 then self:Debug( " - Is criteria met to break channel?  %s.", state.channel_breakable and "Yes" or "No" ) end
            self:Debug( " - Can I cast while casting/channeling?  %s.", state.spec.can_dual_cast and "Yes" or "No" )
        end
    end

    if not state.channel_breakable and state.buff.casting.up and state.spec.can_dual_cast then
        self:Debug( "Whitelist of castable-while-casting spells applied [ %d, %.2f ]", state.buff.casting.v1, state.buff.casting.remains )
        state:SetWhitelist( state.spec.dual_cast )
    else
        self:Debug( "No whitelist." )
        state:SetWhitelist( nil )
    end

    if pack.lists.precombat then
        local listName = "precombat"

        if debug then self:Debug( 1, "\nProcessing precombat action list [ %s - %s ].", packName, listName ); self:Debug( 2, "" ) end
        action, wait, depth = self:GetPredictionFromAPL( dispName, packName, "precombat", slot, action, wait, depth )
        if debug then self:Debug( 1, "\nCompleted precombat action list [ %s - %s ].", packName, listName ) end
    else
        if debug then
            if state.time > 0 then
                self:Debug( "Precombat APL not processed because combat time is %.2f.", state.time )
            end
        end
    end

    if pack.lists.default and wait > 0 then
        local listName = "default"

        if debug then self:Debug( 1, "\nProcessing default action list [ %s - %s ].", packName, listName ); self:Debug( 2, "" ) end
        action, wait, depth = self:GetPredictionFromAPL( dispName, packName, "default", slot, action, wait, depth )
        if debug then self:Debug( 1, "\nCompleted default action list [ %s - %s ].", packName, listName ) end
    end

    state:SetWhitelist( nil )
    if debug then self:Debug( "Recommendation is %s at %.2f + %.2f.", action or "NO ACTION", state.offset, wait ) end

    return action, wait, depth
end

Hekili:ProfileCPU( "GetNextPrediction", Hekili.GetNextPrediction )


local pvpZones = {
    arena = true,
    pvp = true
}


function Hekili:GetDisplayByName( name )
    return rawget( self.DB.profile.displays, name ) and name or nil
end


local aoeDisplayRule = function( p )
    local spec = rawget( p.specs, state.spec.id )
    if not spec or not class.specs[ state.spec.id ] then return false end

    if Hekili:GetToggleState( "mode" ) == "reactive" and ns.getNumberTargets() < ( spec.aoe or 3 ) then
        if HekiliDisplayAOE.RecommendationsStr then
            HekiliDisplayAOE.RecommendationsStr = nil
            HekiliDisplayAOE.NewRecommendations = true
        end
        return false
    end

    return true
end

local displayRules = {
    Interrupts = { function( p ) return p.toggles.interrupts.value and p.toggles.interrupts.separate end, false, "Defensives" },
    Defensives = { function( p ) return p.toggles.defensives.value and p.toggles.defensives.separate end, false, "Cooldowns"  },
    Cooldowns  = { function( p ) return p.toggles.cooldowns.value  and p.toggles.cooldowns.separate  end, false, "Primary"    },
    Primary    = { function(   ) return true                                                         end, true , "AOE"        },
    AOE        = { aoeDisplayRule                                                                       , true , "Interrupts" }
}
local lastDisplay = "AOE"

local hasSnapped

function Hekili.Update( initial )
    if not Hekili:ScriptsLoaded() then
        Hekili:LoadScripts()
        return
    end

    if not Hekili:IsValidSpec() then
        return
    end

    local profile = Hekili.DB.profile

    local specID = state.spec.id
    if not specID then return end

    local spec = rawget( profile.specs, specID )
    if not spec then return end

    local packName = spec.package
    if not packName then return end

    local pack = rawget( profile.packs, packName )
    if not pack then return end

    local debug = Hekili.ActiveDebug

    Hekili:GetNumTargets( true )

    local snaps

    local dispName = initial or displayRules[ lastDisplay ][ 3 ]
    state.display = dispName

    for round = 1, 5 do
        local rule, fullReset, nextDisplay = unpack( displayRules[ dispName ] )
        local display = rawget( profile.displays, dispName )

        fullReset = fullReset or state.offset > 0

        if debug then
            Hekili:SetupDebug( dispName )
            Hekili:Debug( "*** START OF NEW DISPLAY: %s ***", dispName )
        end

        local UI = ns.UI.Displays[ dispName ]
        local Queue = UI.Recommendations

        UI:SetThreadLocked( true )

        if Queue then
            for k, v in pairs( Queue ) do
                for l, w in pairs( v ) do
                    if type( Queue[ k ][ l ] ) ~= "table" then
                        Queue[ k ][ l ] = nil
                    end
                end
            end
        end

        local checkstr = ""

        if UI.Active and UI.alpha > 0 and rule( profile ) then
            for i = #Stack, 1, -1 do tinsert( StackPool, tremove( Stack, i ) ) end
            for i = #Block, 1, -1 do tinsert( StackPool, tremove( Block, i ) ) end

            state.reset( dispName, fullReset )

            -- Clear the stack in case we interrupted ourselves.
            wipe( InUse )

            state.system.specID   = specID
            state.system.specInfo = spec
            state.system.packName = packName
            state.system.packInfo = pack
            state.system.display  = dispName
            state.system.dispInfo = display

            local actualStartTime = debugprofilestop()

            local numRecs = display.numIcons or 4

            if display.flash.enabled and display.flash.suppress then
                numRecs = 1
            end

            for i = 1, numRecs do
                local chosen_depth = 0

                Queue[ i ] = Queue[ i ] or {}

                local slot = Queue[ i ]
                slot.index = i
                state.index = i

                if debug then Hekili:Debug( 0, "\nRECOMMENDATION #%d ( Offset: %.2f, GCD: %.2f, %s: %.2f ).\n", i, state.offset, state.cooldown.global_cooldown.remains, ( state.buff.casting.v3 == 1 and "Channeling" or "Casting" ), state.buff.casting.remains ) end

                local action, wait, depth

                state.delay = 0
                state.delayMin = 0
                state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                local hadProj = false

                local events = state:GetQueue()
                local event = events[ 1 ]
                local n = 1

                if debug and #events > 0 then
                    Hekili:Debug( 1, "There are %d queued events to review.", #events )
                end

                while( event ) do
                    local eStart

                    if debug then
                        eStart = debugprofilestop()

                        local resources

                        for k in orderedPairs( class.resources ) do
                            resources = ( resources and ( resources .. ", " ) or "" ) .. string.format( "%s[ %.2f / %.2f ]", k, state[ k ].current, state[ k ].max )
                        end
                        Hekili:Debug( 1, "Resources: %s\n", resources )

                        if state.channeling then
                            Hekili:Debug( 1, "Currently channeling ( %s ) until ( %.2f ).\n", state.channel, state.channel_remains )
                        end
                    end

                    ns.callHook( "step" )

                    local t = event.time - state.now - state.offset

                    if t < 0 then
                        state.offset = state.offset - t
                        if debug then Hekili:Debug( 1, "Finishing queued event #%d ( %s of %s ) due at %.2f because the event should've already occurred.\n", n, event.type, event.action, t ) end
                        state:HandleEvent( event )
                        state.offset = state.offset + t
                        event = events[ 1 ]
                    --[[ elseif t < 0.2 then
                        if debug then Hekili:Debug( 1, "Finishing queued event #%d ( %s of %s ) due at %.2f because the event occurs w/in 0.2 seconds.\n", n, event.type, event.action, t ) end
                        state.advance( t )
                        if event == events[ 1 ] then
                            state:HandleEvent( event )
                        end
                        event = events[ 1 ] ]]
                    else
                        --[[
                            Okay, new paradigm.  We're checking whether we should break channeled spells before we worry about casting while casting.
                            Are we channeling?
                                a.  If yes, check whether conditions are met to break the channel.
                                    i.  If yes, allow the channel to be broken by anything but the channeled spell itself.
                                        If we get a condition-pass for the channeled spell, stop seeking recommendations and move on.
                                    ii. If no, move on to checking whether we can cast while casting (old code).
                                b.  If no, move on to checking whether we can cast while casting (old code).
                            ]]

                        local channeling, shouldBreak = state:IsChanneling(), false

                        if channeling then
                            if debug then Hekili:Debug( "We are channeling, checking if we should break the channel..." ) end
                            shouldBreak = Hekili:CheckChannel( nil, 0 )
                            state.channel_breakable = shouldBreak
                        else
                            state.channel_breakable = false
                        end

                        local casting, shouldCheck = state:IsCasting(), false

                        if ( casting or ( channeling and not shouldBreak ) ) and state.spec.can_dual_cast then
                            shouldCheck = false

                            for spell in pairs( state.spec.dual_cast ) do
                                if debug then Hekili:Debug( "CWC: %s | %s | %s | %s | %.2f | %s | %.2f | %.2f", spell, tostring( state:IsKnown( spell ) ), tostring( state:IsUsable( spell ) ), tostring( class.abilities[ spell ].dual_cast ), state:TimeToReady( spell ), tostring( state:TimeToReady( spell ) <= t ), state.offset, state.delay ) end
                                if class.abilities[ spell ].dual_cast and state:IsKnown( spell ) and state:IsUsable( spell ) and state:TimeToReady( spell ) <= t then
                                    shouldCheck = true
                                    break
                                end
                            end
                        end


                        local overrideIndex, overrideAction, overrideType, overrideTime

                        if channeling and ( shouldBreak or shouldCheck ) and event.type == "CHANNEL_TICK" then

                            local eventAbility = class.abilities[ event.action ]
                            if eventAbility and not eventAbility.tick then
                                -- The ability doesn't actually do anything at any tick times, so let's use the time of the next non-channel tick event instead.
                                for i = 1, #events do
                                    local e = events[ i ]

                                    if e.type ~= "CHANNEL_TICK" then
                                        overrideIndex = i
                                        overrideAction = e.action
                                        overrideType = e.type
                                        overrideTime = e.time - state.now - state.offset
                                        if debug then Hekili:Debug( "As %s's channel has no tick function, we will check between now and %s's %s event in %.2f seconds.", event.action, overrideAction, overrideType, overrideTime ) end
                                        break
                                    end
                                end
                            end
                        end

                        if ( casting or channeling ) and not shouldBreak and not shouldCheck then
                            if debug then Hekili:Debug( 1, "Finishing queued event #%d ( %s of %s ) due at %.2f as player is casting and castable spells are not ready.\nCasting: %s, Channeling: %s, Break: %s, Check: %s", n, event.type, event.action, t, casting and "Yes" or "No", channeling and "Yes" or "No", shouldBreak and "Yes" or "No", shouldCheck and "Yes" or "No" ) end
                            if t >= 0 then
                                state.advance( t )

                                local resources

                                for k in orderedPairs( class.resources ) do
                                    resources = ( resources and ( resources .. ", " ) or "" ) .. string.format( "%s[ %.2f / %.2f ]", k, state[ k ].current, state[ k ].max )
                                end
                                Hekili:Debug( 1, "Resources: %s\n", resources )
                            end
                            event = events[ 1 ]
                        else
                            state:SetConstraint( 0, ( overrideTime or t ) - 0.01 )

                            hadProj = true

                            if debug then Hekili:Debug( 1, "Queued event #%d (%s %s) due at %.2f; checking pre-event recommendations.\n", overrideIndex or n, overrideAction or event.action, overrideType or event.type, overrideTime or t ) end

                            if casting or channeling then
                                state:ApplyCastingAuraFromQueue()
                                if debug then Hekili:Debug( 2, "Player is casting for %.2f seconds.  %s.", state.buff.casting.remains, shouldBreak and "We can break the channel" or "Only spells castable while casting will be used" ) end
                            else
                                state.removeBuff( "casting" )
                            end

                            local waitLoop = 0

                            repeat
                                action, wait, depth = Hekili:GetNextPrediction( dispName, packName, slot )

                                if action == "wait" then
                                    if debug then Hekili:Debug( "EXECUTING WAIT ( %.2f ) EVENT AT ( +%.2f ) AND RECHECKING RECOMMENDATIONS...", slot.waitSec, wait ) end
                                    state.advance( wait + slot.waitSec )

                                    slot.action = nil
                                    slot.actionName = nil
                                    slot.actionID = nil

                                    state.delay = 0
                                    state.delayMin = 0
                                    state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                                    action, wait = nil, 10

                                    action, wait, depth = Hekili:GetNextPrediction( dispName, packName, slot )
                                end

                                waitLoop = waitLoop + 1

                                if waitLoop > 2 then
                                    if debug then Hekili:Debug( "BREAKING WAIT LOOP!" ) end
                                    slot.action = nil
                                    slot.actionName = nil
                                    slot.actionID = nil

                                    state.delay = 0
                                    state.delayMin = 0
                                    state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                                    action, wait = nil, 10
                                    break
                                end
                            until action ~= "wait"

                            if action == "wait" then
                                action, wait = nil, 10
                            end

                            if not action then
                                if debug then Hekili:Debug( "Time spent on event #%d PREADVANCE: %.2fms...", n, debugprofilestop() - eStart ) end
                                if debug then Hekili:Debug( 1, "No recommendation found before event #%d (%s %s) at %.2f; triggering event and continuing ( %.2f ).\n", n, event.action or "NO ACTION", event.type or "NO TYPE", t, state.offset + state.delay ) end

                                state.advance( overrideTime or t )
                                if debug then Hekili:Debug( "Time spent on event #%d POSTADVANCE: %.2fms...", n, debugprofilestop() - eStart ) end

                                event = events[ 1 ]
                            else
                                break
                            end
                        end
                    end

                    n = n + 1

                    if n > 10 then
                        if debug then Hekili:Debug( "WARNING:  Attempted to process 10+ events; breaking to avoid CPU wastage." ) end
                        break
                    end

                    Hekili.ThreadStatus = "Processed event #" .. n .. " for " .. dispName .. "."
                end

                if not action then
                    state.delay = 0
                    state.delayMin = 0
                    state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                    if class.file == "DEATHKNIGHT" then
                        state:SetConstraint( 0, min( state.delayMax, max( 0.01 + state.rune.cooldown * 2, 10 ) ) )
                    else
                        state:SetConstraint( 0, min( state.delayMax, 10 ) )
                    end

                    if hadProj and debug then Hekili:Debug( "[ ** ] No recommendation before queued event(s), checking recommendations after %.2f.", state.offset ) end

                    if debug then
                        local resources

                        for k in orderedPairs( class.resources ) do
                            resources = ( resources and ( resources .. ", " ) or "" ) .. string.format( "%s[ %.2f / %.2f ]", k, state[ k ].current, state[ k ].max )
                        end
                        Hekili:Debug( 1, "Resources: %s", resources or "none" )
                        ns.callHook( "step" )

                        if state.channeling then
                            Hekili:Debug( " - Channeling ( %s ) until ( %.2f ).", state.channel, state.channel_remains )
                        end
                    end

                    local waitLoop = 0

                    repeat
                        action, wait, depth = Hekili:GetNextPrediction( dispName, packName, slot )

                        if action == "wait" then
                            if debug then Hekili:Debug( "EXECUTING WAIT ( %.2f ) EVENT AT ( +%.2f ) AND RECHECKING RECOMMENDATIONS...", slot.waitSec, wait ) end
                            state.advance( wait + slot.waitSec )

                            slot.action = nil
                            slot.actionName = nil
                            slot.actionID = nil

                            state.delay = 0
                            state.delayMin = 0
                            state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                            action, wait = nil, 10

                            action, wait, depth = Hekili:GetNextPrediction( dispName, packName, slot )
                        end

                        waitLoop = waitLoop + 1

                        if waitLoop > 2 then
                            if debug then Hekili:Debug( "BREAKING WAIT LOOP!" ) end

                            slot.action = nil
                            slot.actionName = nil
                            slot.actionID = nil

                            state.delay = 0
                            state.delayMin = 0
                            state.delayMax = dispName ~= "Primary" and dispName ~= "AOE" and display.forecastPeriod or 15

                            action, wait = nil, 10

                            break
                        end
                    until action ~= "wait"

                    if action == "wait" then
                        action, wait = nil, 10
                    end
                end

                state.delay = wait

                if debug then
                    Hekili:Debug( "Recommendation #%d is %s at %.2fs (%.2fs).", i, action or "NO ACTION", wait or state.delayMax, state.offset + state.delay )
                end

                if action then
                    slot.time = state.offset + wait
                    slot.exact_time = state.now + state.offset + wait
                    slot.delay = i > 1 and wait or ( state.offset + wait )
                    slot.since = i > 1 and slot.time - Queue[ i - 1 ].time or 0
                    slot.resources = slot.resources or {}
                    slot.depth = chosen_depth

                    state.scriptID = slot.script

                    local ability = class.abilities[ action ]
                    local cast_target = i == 1 and state.cast_target ~= "nobody" and state.cast_target or state.target.unit

                    if slot.indicator == "cycle" then
                        state.SetupCycle( ability )
                        cast_target = cast_target .. "c"
                    end

                    if debug then scripts:ImplantDebugData( slot ) end

                    checkstr = checkstr and ( checkstr .. ':' .. action ) or action

                    slot.keybind, slot.keybindFrom = Hekili:GetBindingForAction( action, display, i )--------------------------------------aaaaaaaaaaaaaaaaaaa
                    --print(ZHIYE)
                    DK(ZHIYE)

                    Pd(ability.name)
                    slot.resource_type = state.GetResourceType( action )

                    for k,v in pairs( class.resources ) do
                        slot.resources[ k ] = state[ k ].current
                    end

                    if i < display.numIcons then
                        -- Advance through the wait time.
                        state.this_action = action

                        if state.delay > 0 then state.advance( state.delay ) end

                        local cast = ability.cast or 0

                        if ability.gcd ~= "off" and state.cooldown.global_cooldown.remains == 0 then
                            state.setCooldown( "global_cooldown", state.gcd.execute )
                        end

                        if state.buff.casting.up and not ability.dual_cast then
                            state.stopChanneling( false, action )
                            state.removeBuff( "casting" )
                        end

                        if cast > 0 then
                            if not ability.channeled then
                                if debug then Hekili:Debug( "Queueing %s cast finish at %.2f [+%.2f] on %s.", action, state.query_time + cast, state.offset + cast, cast_target ) end

                                state.applyBuff( "casting", ability.cast, nil, ability.id, nil, false )
                                state:QueueEvent( action, state.query_time, state.query_time + cast, "CAST_FINISH", cast_target )
                            else
                                if ability.charges and ability.charges > 1 and ability.recharge > 0 then
                                    state.spendCharges( action, 1 )

                                elseif action ~= "global_cooldown" and ability.cooldown > 0 then
                                    state.setCooldown( action, ability.cooldown )

                                end

                                if debug then Hekili:Debug( "Queueing %s channel finish at %.2f [%.2f+%.2f].", action, state.query_time + cast, state.offset, cast, cast_target ) end
                                state:QueueEvent( action, state.query_time, state.query_time + cast, "CHANNEL_FINISH", cast_target )

                                -- Queue ticks because we may not have an ability.tick function, but may have resources tied to an aura.
                                if ability.tick_time then
                                    local ticks = floor( cast / ability.tick_time )
                                    for i = 1, ticks do
                                        state:QueueEvent( action, state.query_time, state.query_time + ( i * ability.tick_time ), "CHANNEL_TICK", cast_target )
                                    end
                                    if debug then Hekili:Debug( "Queued %d ticks of channel %s.", ticks, action ) end
                                end

                                if Hekili.Scripts.Channels and Hekili.Scripts.Channels[ packName ] and Hekili.Scripts.Channels[ packName ][ action ] then
                                    state:QueueEvent( action, state.query_time, state.cooldown.global_cooldown.expires, "GCD_FINISH", cast_target )
                                end

                                state:RunHandler( action )
                                ns.spendResources( action )
                            end
                        else
                            -- Instants.
                            if ability.charges and ability.charges > 1 and ability.recharge > 0 then
                                state.spendCharges( action, 1 )

                            elseif action ~= "global_cooldown" and ability.cooldown > 0 then
                                state.setCooldown( action, ability.cooldown )

                            end

                            ns.spendResources( action )
                            state:RunHandler( action )
                        end

                        -- Projectile spells have two handlers, effectively.  A handler (run on cast/channel finish), and then an impact handler.
                        if ability.isProjectile then
                            state:QueueEvent( action, state.query_time + cast, nil, "PROJECTILE_IMPACT", cast_target )
                        end

                        if state.trinket.t1.is[ action ] and state.trinket.t2.has_cooldown then
                            local t2 = state.trinket.t2.cooldown.key
                            local duration = ability.cooldown / 6
                            if state.cooldown[ t2 ].remains < duration then
                                state.setCooldown( t2, duration )
                            end
                        elseif state.trinket.t2.is[ action ] and state.trinket.t1.has_cooldown then
                            local t1 = state.trinket.t1.cooldown.key
                            local duration = ability.cooldown / 6
                            if state.cooldown[ t1 ].remains < duration then
                                state.setCooldown( t1, duration )
                            end
                        end
                    end

                else
                    for s = i, numRecs do
                        action = action or ''
                        checkstr = checkstr and ( checkstr .. ':' .. action ) or action
                        slot[s] = nil
                    end

                    state.delay = 0

                    if debug then
                        local resInfo

                        for k in orderedPairs( class.resources ) do
                            local res = rawget( state, k )

                            if res then
                                local forecast = res.forecast and res.fcount and res.forecast[ res.fcount ]
                                local final = "N/A"

                                if forecast then
                                    final = string.format( "%.2f @ [%d - %s] %.2f", forecast.v, res.fcount, forecast.e or "none", forecast.t - state.now - state.offset )
                                end

                                resInfo = ( resInfo and ( resInfo .. ", " ) or "" ) .. string.format( "%s[ %.2f / %.2f || %s ]", k, res.current, res.max, final )
                            end

                            if resInfo then resInfo = "Resources: " .. resInfo end
                        end

                        if resInfo then
                            Hekili:Debug( resInfo )
                        end
                    else
                        if not hasSnapped and profile.autoSnapshot and InCombatLockdown() and state.level >= 50 and ( dispName == "Primary" or dispName == "AOE" ) then
                            Hekili:Print( "Unable to make recommendation for " .. dispName .. " #" .. i .. "; triggering auto-snapshot..." )
                            hasSnapped = dispName
                            UI:SetThreadLocked( false )
                            return "AutoSnapshot"
                        end
                    end
                    break
                end
            end

            UI.NewRecommendations = true
            UI.RecommendationsStr = checkstr

            UI:SetThreadLocked( false )

            if WeakAuras and WeakAuras.ScanEvents then
                if not UI.EventPayload then
                    UI.EventPayload = {
                        {}, -- [1]
                    }
                    setmetatable( UI.EventPayload, {
                        __index = UI.EventPayload[ 1 ],
                        __mode  = "kv"
                    } )
                end

                for i = 1, numRecs do
                    if UI.EventPayload[ i ] then wipe( UI.EventPayload[ i ] )
                    else UI.EventPayload[ i ] = {} end

                    for k, v in pairs( Queue[ i ] ) do
                        UI.EventPayload[ i ][ k ] = v
                    end
                end

                WeakAuras.ScanEvents( "HEKILI_RECOMMENDATION_UPDATE", dispName, Queue[ 1 ].actionID, Queue[ 1 ].indicator, Queue[ 1 ].empower_to, UI.EventPayload )
            end

            if debug then
                Hekili:Debug( "Time spent generating recommendations:  %.2fms",  debugprofilestop() - actualStartTime )

                if Hekili:SaveDebugSnapshot( dispName ) then
                    if snaps then
                        snaps = snaps .. ", " .. dispName
                    else
                        snaps = dispName
                    end

                    if Hekili.Config then LibStub( "AceConfigDialog-3.0" ):SelectGroup( "Hekili", "snapshots" ) end
                end
            end

            lastDisplay = dispName
            dispName = nextDisplay
            state.display = dispName

            if round < 5 then Hekili:Yield( "Recommendations finished for " .. lastDisplay .. ".", nil, true ) end
        else
            if UI.RecommendationsStr then
                UI.RecommendationsStr = nil
                UI.NewRecommendations = true
            end

            lastDisplay = dispName
            dispName = nextDisplay
            state.display = dispName
        end
    end

    if snaps then
        Hekili:Print( "Snapshots saved:  " .. snaps .. "." )
    end
end
Hekili:ProfileCPU( "ThreadedUpdate", Hekili.Update )


function Hekili_GetRecommendedAbility( display, entry )
    entry = entry or 1

    if not rawget( Hekili.DB.profile.displays, display ) then
        return nil, "Display not found."
    end

    if not ns.queue[ display ] then
        return nil, "No queue for that display."
    end

    local slot = ns.queue[ display ][ entry ]

    if not slot or not slot.actionID then
        return nil, "No entry #" .. entry .. " for that display."
    end

    local payload = Hekili.DisplayPool[ display ].EventPayload

    return slot.actionID, slot.empower_to, payload and payload[ entry ]
end

local usedCPU = {}

function Hekili:DumpFrameInfo()
    wipe( usedCPU )
    for k, v in orderedPairs( ns.frameProfile ) do
        local usage, calls = GetFrameCPUUsage( v, true )

        -- calls = self.ECount[ k ] or calls

        if usage and calls > 0 then
            local db = {}

            db.name  = k or v:GetName()
            db.calls = calls
            db.usage = usage
            db.average = usage / calls

            db.peak = v.peakUsage

            table.insert( usedCPU, db )
        end
    end

    table.sort( usedCPU, function( a, b ) return a.usage < b.usage end )

    print( "Frame CPU Usage Data" )
    for i, v in ipairs( usedCPU ) do
        if v.peak and type( v.peak ) == "number" then
            print( format( "%-40s %6.2fms (%6d calls, %6.2fms average, %6.2fms peak)", v.name, v.usage, v.calls, v.average, v.peak ) )
        else
            print( format( "%-40s %6.2fms (%6d calls, %6.2fms average)", v.name, v.usage, v.calls, v.average ) )
            if v.peak then
                for k, info in pairs( v.peak ) do
                    print( " - " .. k .. ": " .. info )
                end
            end
        end
    end
end









function Pd(name)

    --print(ZHIYE)
    --local key = GetBindingKey("SPELL "..name)
   -- print(key)

    if key == "ALT-CTRL-SHIFT-1" then
        frame.texture:SetColorTexture(1, 0, 0, 1) -- 红色
    elseif key == "ALT-CTRL-SHIFT-2" then
        frame.texture:SetColorTexture(0, 1, 0, 1) -- 绿色
    elseif key == "ALT-CTRL-SHIFT-3" then
        frame.texture:SetColorTexture(0, 0, 1, 1) -- 蓝色
    elseif key == "ALT-CTRL-SHIFT-4" then
        frame.texture:SetColorTexture(1, 1, 0, 1) -- 黄色
    elseif key == "ALT-CTRL-SHIFT-5" then
        frame.texture:SetColorTexture(1, 0, 1, 1) -- 紫色
    elseif key == "ALT-CTRL-SHIFT-6" then
        frame.texture:SetColorTexture(0, 1, 1, 1) -- 青色
    elseif key == "ALT-CTRL-SHIFT-7" then
        frame.texture:SetColorTexture(0.5, 0, 0, 1) -- 深红色
    elseif key == "ALT-CTRL-SHIFT-8" then
        frame.texture:SetColorTexture(0, 0.5, 0, 1) -- 深绿色
    elseif key == "ALT-CTRL-SHIFT-9" then
        frame.texture:SetColorTexture(0, 0.5, 0.5, 1) -- 深青色
    elseif key == "ALT-CTRL-SHIFT-0" then
        frame.texture:SetColorTexture(0.5, 0.5, 0, 1) -- 橄榄色
    elseif key == "ALT-CTRL-1" then
        frame.texture:SetColorTexture(0.5, 0, 0.5, 1) -- 深紫色
    elseif key == "ALT-CTRL-2" then
        frame.texture:SetColorTexture(0.5, 0.5, 0.5, 1) -- 灰色
    elseif key == "ALT-CTRL-3" then
        frame.texture:SetColorTexture(1, 0.5, 0, 1) -- 橙色
    elseif key == "ALT-CTRL-4" then
        frame.texture:SetColorTexture(0.5, 1, 0, 1) -- 黄绿色
    elseif key == "ALT-CTRL-5" then
        frame.texture:SetColorTexture(0, 0.5, 1, 1) -- 天蓝色
    elseif key == "ALT-CTRL-6" then
        frame.texture:SetColorTexture(1, 0, 0.5, 1) -- 粉红色
    elseif key == "ALT-CTRL-7" then
        frame.texture:SetColorTexture(0.5, 1, 1, 1) -- 浅青色
    elseif key == "ALT-CTRL-8" then
        frame.texture:SetColorTexture(1, 0.5, 1, 1) -- 浅紫色
    elseif key == "ALT-CTRL-9" then
        frame.texture:SetColorTexture(0.5, 0.5, 1, 1) -- 浅蓝色
    elseif key == "ALT-CTRL-0" then
        frame.texture:SetColorTexture(1, 1, 0.5, 1) -- 浅黄色
    elseif key == "SHIFT-CTRL-1" then
        frame.texture:SetColorTexture(0.5, 1, 0.5, 1) -- 浅绿色
    elseif key == "SHIFT-CTRL-2" then
        frame.texture:SetColorTexture(1, 0.5, 0.5, 1) -- 浅红色
    elseif key == "SHIFT-CTRL-3" then
        frame.texture:SetColorTexture(0.5, 0.5, 0, 1) -- 橄榄色
    elseif key == "SHIFT-CTRL-4" then
        frame.texture:SetColorTexture(0, 1, 0.5, 1) -- 浅青绿色
    elseif key == "SHIFT-CTRL-5" then
        frame.texture:SetColorTexture(0.5, 0, 1, 1) -- 浅紫色
    elseif key == "SHIFT-CTRL-6" then
        frame.texture:SetColorTexture(1, 0, 0.5, 1) -- 粉红色
    elseif key == "SHIFT-CTRL-7" then
        frame.texture:SetColorTexture(0.5, 1, 0.5, 1) -- 浅绿色
    elseif key == "SHIFT-CTRL-8" then
        frame.texture:SetColorTexture(1, 0.5, 0, 1) -- 橙色
    elseif key == "SHIFT-CTRL-9" then
        frame.texture:SetColorTexture(0.5, 0.5, 1, 1) -- 浅蓝色
    elseif key == "SHIFT-CTRL-0" then
        frame.texture:SetColorTexture(1, 1, 0.5, 1) -- 浅黄色
    elseif key == "SHIFT-ALT-1" then
        frame.texture:SetColorTexture(1, 0.2, 0.2, 1) -- 浅红色
    elseif key == "SHIFT-ALT-2" then
        frame.texture:SetColorTexture(0.2, 1, 0.2, 1) -- 浅绿色
    elseif key == "SHIFT-ALT-3" then
        frame.texture:SetColorTexture(0.2, 0.2, 1, 1) -- 浅蓝色
    elseif key == "SHIFT-ALT-4" then
        frame.texture:SetColorTexture(1, 1, 0.2, 1) -- 浅黄色
    elseif key == "SHIFT-ALT-5" then
        frame.texture:SetColorTexture(1, 0.2, 1, 1) -- 浅紫色
    elseif key == "SHIFT-ALT-6" then
        frame.texture:SetColorTexture(0.2, 1, 1, 1) -- 浅青色
    elseif key == "SHIFT-ALT-7" then
        frame.texture:SetColorTexture(0.5, 0.2, 0.2, 1) -- 深红色
    elseif key == "SHIFT-ALT-8" then
        frame.texture:SetColorTexture(0.2, 0.5, 0.2, 1) -- 深绿色
    elseif key == "SHIFT-ALT-9" then
        frame.texture:SetColorTexture(0.2, 0.2, 0.5, 1) -- 深蓝色
    elseif key == "SHIFT-ALT-0" then
        frame.texture:SetColorTexture(0.5, 0.5, 0.2, 1) -- 橄榄色
    end    
end






function GetSpellIDByName(spellName)
    for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems
        for j = offset + 1, offset + numSlots do
            local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(j, Enum.SpellBookSpellBank.Player)
            if spellBookItemInfo and spellBookItemInfo.itemType == Enum.SpellBookItemType.Spell then
                local name = C_Spell.GetSpellName(spellBookItemInfo.actionID)
                if name == spellName then
                    return spellBookItemInfo.actionID
                end
            end
        end
    end
    return nil -- 如果没有找到对应的技能名字，返回nil
end


function DK(name)
    -- 冰霜专精技能绑定
    if name == "冰霜" then
        SetBindingSpell("ALT-CTRL-SHIFT-1", "湮灭")
        SetBindingSpell("ALT-CTRL-SHIFT-2", "烬魄之灰")
        SetBindingSpell("ALT-CTRL-SHIFT-3", "凛风冲击")
        SetBindingSpell("ALT-CTRL-SHIFT-4", "冰霜之柱")
        SetBindingSpell("ALT-CTRL-SHIFT-5", "冰链术")
        SetBindingSpell("ALT-CTRL-SHIFT-6", "心灵冰冻")
        SetBindingSpell("ALT-CTRL-SHIFT-7", "反魔法护罩")
        SetBindingSpell("ALT-CTRL-SHIFT-8", "死亡之握")
        SetBindingSpell("ALT-CTRL-SHIFT-9", "符文武器增效")
        SetBindingSpell("ALT-CTRL-SHIFT-0", "巫妖之躯")
    end

    -- 邪恶专精技能绑定
    if name == "邪恶" then
        SetBindingSpell("ALT-CTRL-SHIFT-1", "天灾打击")
        SetBindingSpell("ALT-CTRL-SHIFT-2", "脓疮打击")
        SetBindingSpell("ALT-CTRL-SHIFT-3", "凋零缠绕")
        SetBindingSpell("ALT-CTRL-SHIFT-4", "亡者大军")
        SetBindingSpell("ALT-CTRL-SHIFT-5", "死亡缠绕")
        SetBindingSpell("ALT-CTRL-SHIFT-6", "心灵冰冻")
        SetBindingSpell("ALT-CTRL-SHIFT-7", "反魔法护罩")
        SetBindingSpell("ALT-CTRL-SHIFT-8", "死亡之握")
        SetBindingSpell("ALT-CTRL-SHIFT-9", "符文武器增效")
        SetBindingSpell("ALT-CTRL-SHIFT-0", "黑暗突变")
    end

    -- 血专精技能绑定
    if name == "鲜血" then
        SetBindingSpell("ALT-CTRL-SHIFT-1", "心脏打击")
        SetBindingSpell("ALT-CTRL-SHIFT-2", "死亡打击")
        SetBindingSpell("ALT-CTRL-SHIFT-3", "血液沸腾")
        SetBindingSpell("ALT-CTRL-SHIFT-4", "符文刃舞")
        SetBindingSpell("ALT-CTRL-SHIFT-5", "吸血鬼之血")
        SetBindingSpell("ALT-CTRL-SHIFT-6", "心灵冰冻")
        SetBindingSpell("ALT-CTRL-SHIFT-7", "反魔法护罩")
        SetBindingSpell("ALT-CTRL-SHIFT-8", "死亡之握")
        SetBindingSpell("ALT-CTRL-SHIFT-9", "符文武器增效")
        SetBindingSpell("ALT-CTRL-SHIFT-0", "墓石")
    end

    -- 保存绑定
    SaveBindings(2)  -- 2 表示角色绑定，1 表示账号绑定
end

-- 创建一个函数，遍历当前装备的饰品并获取主动技能名字
function GetTrinketSpellNames()
    local trinketSlots = {13, 14} -- 饰品栏位
    local trinketSpellNames = {}

    for _, slot in ipairs(trinketSlots) do
        local itemID = GetInventoryItemID("player", slot)
        if itemID then
            local spellName = C_Item.GetItemSpell(itemID)
            if spellName then
                table.insert(trinketSpellNames, spellName)
            end
        end
    end

    return trinketSpellNames
end

