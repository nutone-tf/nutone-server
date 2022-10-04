global function killstat_Init

struct Parameter {
    string name
    string value
}

array<string> HEADERS = [
    "killstat_version",
    "match_id",
    "game_mode",
    "map",
    "unix_time",
    "game_time",
    "player_count",
    "attacker_name",
    "attacker_id",
    "attacker_current_weapon",
    "attacker_current_weapon_mods",
    "attacker_weapon_1",
    "attacker_weapon_1_mods",
    "attacker_weapon_2",
    "attacker_weapon_2_mods",
    "attacker_weapon_3",
    "attacker_weapon_3_mods",
    "attacker_offhand_weapon_1",
    "attacker_offhand_weapon_2",
    //"attacker_offhand_weapon_3", always melee
    "victim_name",
    "victim_id",
    "victim_current_weapon",
    "victim_current_weapon_mods",
    "victim_weapon_1",
    "victim_weapon_1_mods",
    "victim_weapon_2",
    "victim_weapon_2_mods",
    "victim_weapon_3",
    "victim_weapon_3_mods",
    "victim_offhand_weapon_1",
    "victim_offhand_weapon_2",
    // "victim_offhand_weapon_3", always melee
    "cause_of_death",
    "distance"
]

struct {
    string killstatVersion

    array<string> headers
    array<Parameter> customParameters

    int matchId
    string gameMode
    string map
} file

void function killstat_Init() {
    file.killstatVersion = GetConVarString("killstat_version")
    file.headers = HEADERS

    // custom parameters
    string customParameterString = GetConVarString("killstat_custom_parameters")
    array<string> customParameterEntries = split(customParameterString, ",")
    file.customParameters = []
    foreach (string customParameterEntry in customParameterEntries) {
        array<string> customParameterPair = split(customParameterEntry, "=")
        if (customParameterPair.len() != 2) {
            Log("[WARN] ignoring invalid custom parameter: " + customParameterEntry)
            continue
        }

        Parameter customParameter
        customParameter.name = strip(customParameterPair[0])
        customParameter.value = strip(customParameterPair[1])
        file.customParameters.append(customParameter)
    }

    // callbacks
    AddCallback_GameStateEnter(eGameState.Playing, killstat_Begin)
    AddCallback_OnPlayerKilled(killstat_Record)
    AddCallback_GameStateEnter(eGameState.Postmatch, killstat_End)
}

Parameter function NewParameter(string name, string value) {
    Parameter p
    p.name = name
    p.value = value
    return p
}

void function killstat_Begin() {
    //DumpWeaponModBitFields()

    file.matchId = RandomInt(2000000000)
    file.gameMode = GameRules_GetGameMode()
    file.map = StringReplace(GetMapName(), "mp_", "")

    array<string> headers = []
    foreach (Parameter p in file.customParameters) {
        headers.append(p.name)
    }
    foreach (string s in file.headers) {
        headers.append(s)
    }

    string headerRow = ToCsvRow(headers)

    Log("-----BEGIN KILLSTAT-----")
    Log("[HEADERS] " + headerRow)
}

void function killstat_Record(entity victim, entity attacker, var damageInfo) {
    if ( !victim.IsPlayer() || !attacker.IsPlayer() || GetGameState() != eGameState.Playing )
            return

    array<string> values = []

    foreach (Parameter p in file.customParameters) {
        values.append(p.value)
    }

    array<entity> attackerWeapons = attacker.GetMainWeapons()
    array<entity> victimWeapons = victim.GetMainWeapons()
    array<entity> attackerOffhandWeapons = attacker.GetOffhandWeapons()
    array<entity> victimOffhandWeapons = victim.GetOffhandWeapons()

    attackerWeapons.sort(MainWeaponSort)
    victimWeapons.sort(MainWeaponSort)

    entity aw1 = GetNthWeapon(attackerWeapons, 0)
    entity aw2 = GetNthWeapon(attackerWeapons, 1)
    entity aw3 = GetNthWeapon(attackerWeapons, 2)
    entity vw1 = GetNthWeapon(victimWeapons, 0)
    entity vw2 = GetNthWeapon(victimWeapons, 1)
    entity vw3 = GetNthWeapon(victimWeapons, 2)
    entity aow1 = GetNthWeapon(attackerOffhandWeapons, 0)
    entity aow2 = GetNthWeapon(attackerOffhandWeapons, 1)
    entity aow3 = GetNthWeapon(attackerOffhandWeapons, 2)
    entity vow1 = GetNthWeapon(victimOffhandWeapons, 0)
    entity vow2 = GetNthWeapon(victimOffhandWeapons, 1)
    entity vow3 = GetNthWeapon(victimOffhandWeapons, 2)


    foreach (string header in file.headers) {
        switch (header) {
            case "killstat_version":
                values.append(file.killstatVersion)
                break

            case "match_id":
                values.append(format("%08x", file.matchId))
                break

            case "game_mode":
                values.append(file.gameMode)
                break

            case "map":
                values.append(file.map)
                break

            case "unix_time":
                values.append(format("%d", GetUnixTimestamp()))
                break

            case "game_time":
                values.append(format("%.3f", Time()))
                break

            case "player_count":
                values.append(format("%d", GetPlayerArray().len()))
                break

            case "attacker_name":
                values.append(attacker.GetPlayerName())
                break

            case "attacker_id":
                values.append(Anonymize(attacker))
                break

            case "attacker_current_weapon":
                AddWeapon(values, attacker.GetLatestPrimaryWeapon())
                break

            case "attacker_current_weapon_mods":
                AddWeaponMods(values, attacker.GetLatestPrimaryWeapon())
                break

            case "attacker_weapon_1":
                AddWeapon(values, aw1)
                break

            case "attacker_weapon_1_mods":
                AddWeaponMods(values, aw1)
                break
            
            case "attacker_weapon_2":
                AddWeapon(values, aw2)
                break

            case "attacker_weapon_2_mods":
                AddWeaponMods(values, aw2)
                break

            case "attacker_weapon_3":
                AddWeapon(values, aw3)
                break

            case "attacker_weapon_3_mods":
                AddWeaponMods(values, aw3)
                break

            case "attacker_offhand_weapon_1":
                AddWeapon(values, aow1)
                break

            case "attacker_offhand_weapon_2":
                AddWeapon(values, aow2)
                break

            case "attacker_offhand_weapon_3":
                AddWeapon(values, aow3)
                break
                
            case "victim_name":
                values.append(victim.GetPlayerName())
                break

            case "victim_id":
                values.append(Anonymize(victim))
                break

            case "victim_current_weapon":
                AddWeapon(values, victim.GetLatestPrimaryWeapon())
                break

            case "victim_current_weapon_mods":
                AddWeaponMods(values, victim.GetLatestPrimaryWeapon())
                break

            case "victim_weapon_1":
                AddWeapon(values, vw1)
                break

            case "victim_weapon_1_mods":
                AddWeaponMods(values, vw1)
                break

            case "victim_weapon_2":
                AddWeapon(values, vw2)
                break

            case "victim_weapon_2_mods":
                AddWeaponMods(values, vw2)
                break

                case "victim_weapon_3":
                AddWeapon(values, vw3)
                break

            case "victim_weapon_3_mods":
                AddWeaponMods(values, vw3)
                break

            case "victim_offhand_weapon_1":
                AddWeapon(values, vow1)
                break

            case "victim_offhand_weapon_2":
                AddWeapon(values, vow2)
                break

            case "victim_offhand_weapon_3":
                AddWeapon(values, vow3)
                break

            case "cause_of_death":
                int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
                string damageName = DamageSourceIDToString(damageSourceId)
                values.append(TrimWeaponName(damageName))
                break

            case "distance":
                float dist = Distance(attacker.GetOrigin(), victim.GetOrigin())
                values.append(format("%.3f", dist))
                break

            default:
                break
        }
    }

    string row = ToCsvRow(values)
    Log("[ROW] " + row)
}

void function killstat_End() {
    Log("-----END KILLSTAT-----")
}

void function Log(string s) {
     print("[fvnkhead.killstat] " + s)
}

array<int> MAIN_DAMAGE_SOURCES = [
    // primaries
	eDamageSourceId.mp_weapon_car,
	eDamageSourceId.mp_weapon_r97,
	eDamageSourceId.mp_weapon_alternator_smg,
	eDamageSourceId.mp_weapon_hemlok_smg,
	eDamageSourceId.mp_weapon_hemlok,
	eDamageSourceId.mp_weapon_vinson,
	eDamageSourceId.mp_weapon_g2,
	eDamageSourceId.mp_weapon_rspn101,
	eDamageSourceId.mp_weapon_rspn101_og,
	eDamageSourceId.mp_weapon_esaw,
	eDamageSourceId.mp_weapon_lstar,
	eDamageSourceId.mp_weapon_lmg,
	eDamageSourceId.mp_weapon_shotgun,
	eDamageSourceId.mp_weapon_mastiff,
	eDamageSourceId.mp_weapon_dmr,
	eDamageSourceId.mp_weapon_sniper,
	eDamageSourceId.mp_weapon_doubletake,
	eDamageSourceId.mp_weapon_pulse_lmg,
	eDamageSourceId.mp_weapon_smr,
	eDamageSourceId.mp_weapon_softball,
	eDamageSourceId.mp_weapon_epg,
	eDamageSourceId.mp_weapon_shotgun_pistol,
	eDamageSourceId.mp_weapon_wingman_n,

    // secondaries
	eDamageSourceId.mp_weapon_smart_pistol,
	eDamageSourceId.mp_weapon_wingman,
	eDamageSourceId.mp_weapon_semipistol,
	eDamageSourceId.mp_weapon_autopistol,

    // anti-titan
	eDamageSourceId.mp_weapon_mgl,
	eDamageSourceId.mp_weapon_rocket_launcher,
	eDamageSourceId.mp_weapon_arc_launcher,
	eDamageSourceId.mp_weapon_defender
]

void function DumpWeaponModBitFields() {
    Log("[DumpWeaponModBitFields]")
    foreach (int damageSourceId in MAIN_DAMAGE_SOURCES) {
        string weaponName = DamageSourceIDToString(damageSourceId)
        array<string> mods = GetWeaponMods_Global(weaponName)
        array<string> list = [weaponName]
        foreach (string mod in mods) {
            list.append(mod)
        }

        Log("[DumpWeaponModBitFields] " + ToPythonList(list))
    }
}

// Should sort main weapons in following order:
// 1. primary
// 2. secondary
// 3. anti-titan
int function MainWeaponSort(entity a, entity b) {
    int aID = a.GetDamageSourceID()
    int bID = b.GetDamageSourceID()

    int aIdx = MAIN_DAMAGE_SOURCES.find(aID)
    int bIdx = MAIN_DAMAGE_SOURCES.find(bID)

    if (aIdx == bIdx) {
        return 0
    } else if (aIdx != -1 && bIdx == -1) {
        return -1
    } else if (aIdx == -1 && bIdx != -1) {
        return 1
    }

    return aIdx < bIdx ? -1 : 1
}

int function WeaponNameSort(entity a, entity b) {
    return SortStringAlphabetize(a.GetWeaponClassName(), b.GetWeaponClassName())
}

entity function GetNthWeapon(array<entity> weapons, int index) {
    return index < weapons.len() ? weapons[index] : null
}

void function AddWeapon(array<string> list, entity weapon) {
    string s = "null"
    if (weapon != null) {
        s = TrimWeaponName(weapon.GetWeaponClassName())
    }

    list.append(s)
}

string function TrimWeaponName(string s) {
    s = StringReplace(s, "mp_weapon_", "")
    s = StringReplace(s, "mp_ability_", "")
    s = StringReplace(s, "melee_", "")
    return s
}

void function AddWeaponMods(array<string> list, entity weapon) {
    if (weapon == null) {
        list.append("null")
        return
    }

    int modBits = weapon.GetModBitField()
    list.append(format("%d", modBits))
}

string function ToPythonList(array<string> list) {
    array<string> quoted = []
    foreach (string s in list) {
        quoted.append("'" + s + "'")
    }

    return "\"[" + join(quoted, ", ") + "]\""
}

string function Anonymize(entity player) {
    return "null" // unused
}

string function ToCsvRow(array<string> list) {
    return join(list, ",")
}

string function join(array<string> list, string separator) {
    string s = ""
        for (int i = 0; i < list.len(); i++) {
            s += list[i]
                if (i < list.len() - 1) {
                    s += separator
                }
        }

    return s
}
