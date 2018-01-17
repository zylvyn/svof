-- Svof (c) 2011-2018 by Vadim Peretokin

-- Svof is licensed under a
-- Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.

-- You should have received a copy of the license along with this
-- work. If not, see <http://creativecommons.org/licenses/by-nc-sa/4.0/>.

svo.es_version = "1.1"

-- stores vial ID and months left
svo.es_vials = {}
-- stores type by key, and inside each, a potion table
--svo.es_potions = {} -- intialized in setup
-- what are we currently capturing - so we know when to show the output
svo.es_capturing = ""
svo.es_disposecmd = ""

svo.es_knownstuff = svo.es_knownstuff or {}

local luanotify = {}
luanotify.signal = require("notify.signal")
svo.signals.elistcaptured = luanotify.signal.new()

local conf = svo.conf

function svo.es_capture()
  -- reset only what we're actually capturing
  if line:find('Venom', 1, true) then
    svo.es_capturing = 'venoms'

    for vial, _ in pairs(svo.es_potions.venom) do
      svo.es_potions.venom[vial] = {sips = 0, vials = 0, decays = 0}
    end

    -- wipe venoms only from svo.es_potions
    local wipevenom = {}
    for vialid, vialdata in pairs(svo.es_vials) do
      if svo.es_potions.venom[vialdata.potion] then
        wipevenom[#wipevenom+1] = vialid
      end
    end
    for i = 1, #wipevenom do
      svo.es_vials[wipevenom[i]] = nil
    end
  else
    svo.es_capturing = 'potions'

    for catn,cat in pairs(svo.es_potions) do
      if catn ~= 'venom' then
        for vial, _ in pairs(cat) do
          cat[vial] = {sips = 0, vials = 0, decays = 0}
        end
      end
    end

    -- wipe non-venoms only from svo.es_potions
    local wipevial = {}
    for vialid, vialdata in pairs(svo.es_vials) do
      if not svo.es_potions.venom[vialdata.potion] then
        wipevial[#wipevial+1] = vialid
      end
    end
    for i = 1, #wipevial do
      svo.es_vials[wipevial[i]] = nil
    end
  end
end

svo.config.setoption('elist',
{
  type = 'custom',
  vconfig2string = true,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("es:", "", "svo Elist Sorter", true)
    -- change desired amounts; considering vials about to decay at 5 or less months
    fg('a_cyan') echoLink(" set vial amounts", "svo.config.set'elist'", "Click to change the minimum amounts of vials you'd like to have", true)
    fg(defaultcolour) echo("; considering vials about to decay at")
    fg('a_cyan') echoLink(" "..(conf.decaytime or '?'), "printCmdLine'vconfig decaytime '", "Click to change the amount of months at which a vial will be considered for throwing away", true)
    fg(defaultcolour)
    echo(" month"..(conf.decaytime == 1 and '' or 's')..".\n")

  end,
  onmenu = function ()
    -- sort into categories
    local t = {}
    for k,_ in pairs(svo.es_categories) do t[svo.es_categories[k] or 'unknown'] = t[svo.es_categories[k] or 'unknown'] or {}; t[svo.es_categories[k] or 'unknown'][#t[svo.es_categories[k] or 'unknown']+1] = k end

    svo.echof("Set the desired amount for each potion by clicking on the number:")
    for catn, catt in pairs(t) do
      svo.echof("%s%s:", catn:title():sub(1, -2), (catn:sub(-1) == 'y' and 'ies' or catn:sub(-1)..'s'))

      for _, potion in pairs(catt) do
        local amount = (svo.es_knownstuff[potion] or 0)
        echo(string.format("  %30s ", potion))
        fg('blue')
        echoLink(" "..amount.." ", 'printCmdLine"vconfig setpotion '..(svo.es_shortnamesr[potion] and svo.es_shortnamesr[potion] or 'unknown').. ' '..amount..'"', "Change how many vials of "..potion.." you'd like to have", true)
        resetFormat()
        echo"\n"
      end
    end
  end
})

conf.decaytime = conf.decaytime or 3
svo.config.setoption('decaytime',
{
  type = 'number',
  vconfig2string = true,
  onset = function () svo.echof("Will consider vials available for disposal when they decay time is at or less than %d months.", conf.decaytime) end,
  onshow = function (defaultcolour)
    fg('gold')
    echoLink("es:", "", "svo Elist Sorter", true)

    -- obfuscated vials: store vials at less than %d sips into %container
    fg(defaultcolour) echo(" obfuscated vials: store at less than")
    fg('a_cyan') echoLink(" "..(conf.obfsips or '?'), "printCmdLine'vconfig obfsips '", "Click to change the # of sips below which obfuscated vials will be stored in a container", true)
    fg(defaultcolour)
    echo(" sip"..(conf.obfuscated == 1 and '' or 's').." into ")
    fg('a_cyan') echoLink((conf.obfcontainer or '?'), "printCmdLine'vconfig obfcontainer '", "Click to change container into which obfuscated vials will be stored", true)
    echo(".\n")
  end
})

conf.obfsips = conf.obfsips or 20
svo.config.setoption('obfsips',
{
  type = 'number',
  onset = function () svo.echof("Will put obfuscated vials away into %s when they're at %d or below sips.", tostring(conf.obfcontainer), conf.obfsips) end
})


conf.obfcontainer = conf.obfcontainer or 'pack'
svo.config.setoption('obfcontainer',
{
  type = 'string',
  onset = function () svo.echof("Will put obfuscated vials away into %s.", tostring(conf.obfcontainer)) end
})

svo.config.setoption('setpotion',
{
  type = 'string',
  onset = function()
    if not conf.setpotion:find("^.+ %d+$") then svo.echof("What amount do you want to set?") return end

    local potion, amount = conf.setpotion:match("^(.+) (%d+)$")
    amount = tonumber(amount)
    if svo.es_shortnames[potion] then
      svo.es_knownstuff[svo.es_shortnames[potion]] = amount
      svo.echof("Made a note that we'd like to have a minimum %s of %s.", amount, potion)
      return
    elseif not svo.es_knownstuff[potion] then
      svo.echof("I haven't seen any potions called '%s' yet...", potion)
    else
      svo.es_knownstuff[potion] = amount
      svo.echof("Made a note that we'd like to have a minimum %s of %s.", amount, potion)
      return
    end
  end
})

function svo.es_appendrequest(whatfor)
  local t = {}
  for _, catt in pairs(svo.es_potions) do
    for potn, pott in pairs(catt) do
      if ((whatfor ~= 'venoms' and not potn:find("the venom", 1, true)) or (whatfor == 'venoms' and potn:find("the venom", 1, true))) and svo.es_knownstuff[potn] and pott.vials < svo.es_knownstuff[potn] then
        t[#t+1] = (svo.es_knownstuff[potn] - pott.vials) .. " ".. (svo.es_shortnamesr[potn] and svo.es_shortnamesr[potn] or potn)
      end
    end
  end

  if #t == 0 then svo.echof("I don't think you're short on anything!") return
  else appendCmdLine(" I'd like "..svo.concatand(t)) end
end

function svo.es_refillfromkeg()
  local t = {}
  for _, catt in pairs(svo.es_potions) do
    for potn, pott in pairs(catt) do
      if svo.es_knownstuff[potn] and pott.vials < svo.es_knownstuff[potn] and (svo.es_shortnamesr[potn] and svo.es_shortnamesr[potn] or potn) ~= 'empty' then
        for _ = 1, svo.es_knownstuff[potn] - pott.vials do
          t[#t+1] = string.format("refill empty from %s", (svo.es_shortnamesr[potn] and svo.es_shortnamesr[potn] or potn))
        end
      end
    end
  end

  if #t == 0 then svo.echof("I don't think you're short on anything!") return
  else
    svo.sendc(unpack(t))
  end
end

function svo.es_captured(vlist)
  tempTimer(0, function()
    local missing = 0
    local decaying

    local function checkdecays(pott)
      if pott.decays == 0 then return ""
      else decaying = true return (pott.decays.." decaying soon") end
    end

    for catn, catt in pairs(svo.es_potions) do
      svo.echof("%s%s:", catn:title():sub(1, -2), (catn:sub(-1) == 'y' and 'ies' or catn:sub(-1)..'s'))

      for potn, pott in pairs(catt) do
        -- don't show vials that we have 0 of and want 0 of
        if not (pott.vials == 0 and (not svo.es_knownstuff[potn] or (svo.es_knownstuff[potn] and svo.es_knownstuff[potn] == 0))) then
          if svo.es_knownstuff[potn] and pott.vials < svo.es_knownstuff[potn] then
            missing = missing + svo.es_knownstuff[potn] - pott.vials
            svo.echon("%3d %-35s%7s  %10s", pott.vials, potn..' ('..pott.sips..'s)', (svo.es_knownstuff[potn] - pott.vials .. " short"), checkdecays(pott))
          else
            svo.echon("%3d %-35s%7s  %10s", pott.vials, potn..' ('..pott.sips..'s)', "", checkdecays(pott))
          end
        end
      end
    end
    echo"  "; dechoLink("<0,0,250>("..svo.getDefaultColor().."change desired amounts<0,0,250>)", "svo.config.set('elist')", "Show a menu to change how much of what would you like to have", true) echo"\n"
    if decaying then echo"  "; dechoLink("<0,0,250>("..svo.getDefaultColor().."dispose of decays<0,0,250>)", "printCmdLine'dispose of decays by: give vial to humgii'", "Dispose of vials (pouring them into other vials if possible) with a custom command.\nMake sure to include the word 'vial' in the command", true) echo"\n" end
    if missing > 0 then
      echo"  "
      dechoLink("<0,0,250>("..svo.getDefaultColor().."append refill request, need "..missing.." refills<0,0,250>)", "svo.es_appendrequest('"..svo.es_capturing.."')", "Insert how many refills of "..svo.es_capturing.." would you like into the command line.\nYou should pre-type whenever you want to say or tell this to anyone, and then click", true)
      echo"\n  "
      dechoLink("<0,0,250>("..svo.getDefaultColor().."refill from tuns, need "..missing.." refills<0,0,250>)", "svo.es_refillfromkeg()", "Click here to refill all necessary things from shop tuns", true)
      echo"\n"
    end
    svo.showprompt()
    svo.debugf("raising elistcaptured with: %s", tostring(vlist))
    svo.signals.elistcaptured:emit(vlist)
  end)
end

function svo.es_dodisposing(vlist)
  -- check vlist and then elist - ignore if its vlist, only act on elist
  svo.debugf("es_dodisposing: %s", tostring(vlist))
  if vlist then return end

  local function emptyvial(id)
    if svo.es_vials[id].sips == 0 then svo.echof("%d is already empty.", id) return end
    svo.echof("Emptying vial%d with %s.", id, svo.es_vials[id].potion)

    -- one pass is enough! If we don't completely dispose of it, then that's alright
    for otherid, t in pairs(svo.es_vials) do
      if otherid ~= id and (t.potion == svo.es_vials[id].potion or t.potion == 'empty') and t.sips < (type(t.months) == 'number' and 200 or 240) and
        (type(t.months) ~= 'number' or t.months > conf.decaytime) then

        local deltacapacity = (type(t.months) == 'number' and 200 or 240) - t.sips -- this is how much we can fill it up by
        svo.echof("Can fill vial%d with %d more sips.", otherid, deltacapacity)

        local fillingwith = (svo.es_vials[id].sips < deltacapacity and svo.es_vials[id].sips or deltacapacity)
        svo.echof("Filling vial%d with %d sips.", otherid, fillingwith)

        svo.sendc(string.format("pour %d into %d", id, otherid))

        t.sips = t.sips + fillingwith
        svo.echof("Poured %s into vial%s, which is now at %d sips.", svo.es_vials[id].potion, tostring(otherid), tostring(t.sips))

        svo.es_vials[id].sips = svo.es_vials[id].sips - fillingwith
        svo.echof("Decayable vial%s is now at %d sips.", id, svo.es_vials[id].sips)

        if t.potion == 'empty' then t.potion = svo.es_vials[id].potion; svo.echof("Poured into empty now has %s potion", tostring(t.potion)) end
        if svo.es_vials[id].sips <= 0 then svo.echof("Vial %s fully emptied.\n--", tostring(id)) return end
      end
    end
    svo.echof("Vial %d with '%s' wasn't fully emptied, no space to pour it into now.\n--", id, svo.es_vials[id].potion)
  end

  echo'\n'
  local haddecays
  for id, t in pairs(svo.es_vials) do
    if type(t.months) == 'number' and t.months <= conf.decaytime then
      emptyvial(id)
      svo.sendc(svo.es_disposecmd:gsub('vial', id), false)
      haddecays = true
    end
  end

  if haddecays then
    svo.echof("Disposing of vials which have %d or less months on them...", conf.decaytime)
  else
    svo.echof("Don't have any vials which have under %d months :)", conf.decaytime)
  end
  svo.showprompt()

  svo.signals.elistcaptured:disconnect(svo.es_dodisposing)
end

function svo.es_dispose(cmd)
  if not cmd:find('vial', 1, true) then svo.echof("Please include the word 'vial' in the command. Thanks!") return end
  if not next(svo.es_vials) then svo.echof("Don't know of any vials you have - check 'elist' please.") return end

  svo.signals.elistcaptured:connect(svo.es_dodisposing)
  svo.es_disposecmd = cmd
  -- refresh our vials data, in case new vials were bought
  send("config pagelength 250", false)
  send('vlist', false)
  send('elist', false)
end

svo.signals.saveconfig:connect(function () svo.tablesave(getMudletHomeDir() .. "/svo/config/svo.es_knownstuff", svo.es_knownstuff) end)
svo.signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/svo.es_knownstuff"

  if lfs.attributes(conf_path) then
    table.load(conf_path, svo.es_knownstuff)
  end

  if lfs.attributes(conf_path) then
    local ok, msg = pcall(table.load, conf_path, svo.es_knownstuff)
    if not ok then
      os.remove(conf_path)
      tempTimer(10, function()
        svo.echof("Your elist sorter save file file got corrupted for some reason - I've deleted it so the system can load other stuff OK. You'll need to re-set all of the elist options again, though. (%q)", msg)
      end)
    end
  end
end)

-- remember our vial statuses if we have
svo.signals.systemstart:connect(function ()
  local conf_path = getMudletHomeDir() .. "/svo/config/svo.es_potions"

  if lfs.attributes(conf_path) then
    local t = {}
    table.load(conf_path, t)
    svo.update(svo.es_potions, t)
  end

  -- erase tonics and balms as those are gone
  svo.es_potions.tonic = nil
  svo.es_potions.balm = nil
end)

svo.signals.saveconfig:connect(function () svo.tablesave(getMudletHomeDir() .. "/svo/config/svo.es_potions", svo.es_potions) end)

svo.echof("Loaded svo Elist Sorter, version %s.", tostring(svo.es_version))

