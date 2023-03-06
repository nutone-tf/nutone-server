global function killstat_Init

struct Parameter {
    string name
    string value
}

array<string> HEADERS = [ //unused
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
    string Tone_URI
    string Tone_protocol
    int Tone_ID
    string Tone_token
    bool connected
    array<Parameter> customParameters

    int matchId
    string gameMode
    string map
} file

void function killstat_Init() {
    file.killstatVersion = GetConVarString("killstat_version")
    file.Tone_URI = GetConVarString("Tone_URI")
    file.Tone_protocol = GetConVarString("Tone_protocol")
    file.Tone_ID = GetConVarInt("Tone_ID")
    file.Tone_token = GetConVarString("Tone_token")
    file.connected = false

    //register to Tone API if default or invalid token
    Tone_Test_Auth()

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
    AddCallback_OnClientConnected(JoinMessage)
}

Parameter function NewParameter(string name, string value) {
    Parameter p
    p.name = name
    p.value = value
    return p
}

string prefix = "\x1b[38;5;81m[TONE API]\x1b[0m "

void function JoinMessage(entity player) {
    Chat_ServerPrivateMessage(player, prefix + "This server collects data using the Tone API. Check your data here: \x1b[34mtoneapi.com/" + player.GetPlayerName()+ "\x1b[0m", false, false)
}

void function killstat_Begin() {
    //DumpWeaponModBitFields()
    //TODO : request MatchID from API ------------------------------------------------------------------------------------------------
    //TODO : request anonymization data from API
    file.matchId = RandomInt(2000000000)
    file.gameMode = GameRules_GetGameMode()
    file.map = StringReplace(GetMapName(), "mp_", "")

    Log("-----BEGIN KILLSTAT-----")
    Log("Sending kill data to " + file.Tone_URI + "/servers/"+file.Tone_ID+"/kill")
}

void function killstat_Record(entity victim, entity attacker, var damageInfo) {
    if ( !victim.IsPlayer() || !attacker.IsPlayer() || GetGameState() != eGameState.Playing )
            return

    table values = {}

    foreach (Parameter p in file.customParameters) {
        values[p] <- p.value
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


    values["killstat_version"] <- file.killstatVersion
    values["match_id"] <- format("%08x", file.matchId)
    values["game_mode"] <- file.gameMode
    values["map"] <- file.map
    values["game_time"] <- format("%.3f", Time())
    values["player_count"] <- format("%d", GetPlayerArray().len())
    values["attacker_name"] <- attacker.GetPlayerName()
    values["attacker_id"] <- attacker.GetUID()
    values["attacker_current_weapon"] <- GetWeaponName(attacker.GetLatestPrimaryWeapon())
    values["attacker_current_weapon_mods"] <- GetWeaponMods(attacker.GetLatestPrimaryWeapon())
    values["attacker_weapon_1"] <- GetWeaponName(aw1)
    values["attacker_weapon_1_mods"] <- GetWeaponMods(aw1)
    values["attacker_weapon_2"] <- GetWeaponName(aw2)
    values["attacker_weapon_2_mods"] <- GetWeaponMods(aw2)
    values["attacker_weapon_3"] <- GetWeaponName(aw3)
    values["attacker_weapon_3_mods"] <- GetWeaponMods(aw3)
    values["attacker_offhand_weapon_1"] <- GetWeaponMods(aow1)
    values["attacker_offhand_weapon_2"] <- GetWeaponMods(aow2)
    values["attacker_offhand_weapon_3"] <- GetWeaponMods(aow3)

    values["victim_name"] <- victim.GetPlayerName()
    values["victim_id"] <- victim.GetUID()
    values["victim_current_weapon"] <- GetWeaponName(victim.GetLatestPrimaryWeapon())
    values["victim_current_weapon_mods"] <- GetWeaponMods(victim.GetLatestPrimaryWeapon())
    values["victim_weapon_1"] <-  GetWeaponName(vw1)
    values["victim_weapon_1_mods"] <- GetWeaponMods(vw1)
    values["victim_weapon_2"] <- GetWeaponName(vw2)
    values["victim_weapon_2_mods"] <- GetWeaponMods(vw2)
    values["victim_weapon_3"] <- GetWeaponName(vw3)
    values["victim_weapon_3_mods"] <- GetWeaponMods(vw3)
    values["victim_offhand_weapon_1"] <- GetWeaponMods(vow1)
    values["victim_offhand_weapon_2"] <- GetWeaponMods(vow2)
    values["victim_offhand_weapon_3"] <- GetWeaponMods(vow3)

    int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
    string damageName = DamageSourceIDToString(damageSourceId)
    values["cause_of_death"] <- TrimWeaponName(damageName)

    float dist = Distance(attacker.GetOrigin(), victim.GetOrigin())
    values["distance"] <- format("%.3f", dist)

    string json = EncodeJSON(values)
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if(response.statusCode == 200 || response.statusCode == 201){
            print("[Tone API] Kill data sent!")
        }else{
            print("[Tone API][WARN] Couldn't send kill data")
            print("[Tone API][WARN] " + response.body )
        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print("[Tone API][WARN]  Couldn't send kill data")
        print("[Tone API][WARN] " + failure.errorMessage )
    }
    NSHttpPostBody(GetToneURIWithAuth()+ "/servers/"+file.Tone_ID+"/kill", json, onSuccess, onFailure)
}

void function killstat_End() {
    Log("-----END KILLSTAT-----")
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

string function GetWeaponName(entity weapon) {
    string s = "null"
    if (weapon != null) {
        s = TrimWeaponName(weapon.GetWeaponClassName())
    }
    return s
}

string function GetWeaponMods(entity weapon) {
    if (weapon == null) {
        return "null"
    }
    int modBits = weapon.GetModBitField()
    return format("%d", modBits)
}

string function TrimWeaponName(string s) {
    s = StringReplace(s, "mp_weapon_", "")
    s = StringReplace(s, "mp_ability_", "")
    s = StringReplace(s, "melee_", "")
    return s
}

string function Anonymize(entity player) {
    return "null" // unused
}


string function ToPythonList(array<string> list) {
    array<string> quoted = []
    foreach (string s in list) {
        quoted.append("'" + s + "'")
    }

    return "\"[" + join(quoted, ", ") + "]\""
}

void function Log(string s) {
    print("[fvnkhead.killstat] " + s)
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


void function Tone_Test_Auth(){
    HttpRequest request
    request.method = HttpRequestMethod.POST
    request.url = GetToneURIWithAuth() + "/servers/"+file.Tone_ID
    print(GetToneURIWithAuth())
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if(response.statusCode == 200){
            print("[Tone API] Tone API Online !")
            file.connected = true
        }else{
            print("[Tone API] Tone API registration failed")
            print("[Tone API] " + response.body )
            thread Tone_Register_Threaded()
        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print("[Tone API] Tone API registration failed")
        print("[Tone API] " + failure.errorMessage )
        thread Tone_Register_Threaded()
    }

    NSHttpRequest(request, onSuccess, onFailure)
}


void function Tone_Register_Threaded(){
    table body = {}
    body["name"] <- GetConVarString("ns_server_name")
    body["description"] <- GetConVarString("ns_server_desc")
    body["auth_port"] <- GetConVarString("ns_player_auth_port")
    HttpRequest request
    request.method = HttpRequestMethod.POST
    request.url = file.Tone_protocol + "://" + file.Tone_URI+ "/servers/register"

    string json = EncodeJSON( body )
    request.body = json
    int i = 0
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        //print(response.statusCode)
        if(response.statusCode == 201){
            table answer = DecodeJSON(response.body)
            file.Tone_ID = expect int(answer["id"])
            file.Tone_token = expect string(answer["token"])
            SetConVarInt("Tone_ID", (expect int(answer["id"])))
            SetConVarString("Tone_token", (expect string(answer["token"])))
            print("[Tone API] Tone API Online !")
            file.connected = true
        }else{
            print("[Tone API] Tone API registration failed")
            print("[Tone API] " + response.body )
        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print("[Tone API] Tone API registration failed")
        print("[Tone API] "+ failure.errorMessage )
    }

    while(i < 5 && file.connected == false){
        print("[Tone API] requesting Tone API for registration... Time " + i + " out of 5" )
        NSHttpRequest( request, onSuccess, onFailure )
        i = i + 1
        wait 300
    }
    print("[Tone API] Tone API registration failed. Stopping registration requests for now. Try mentionning @Legonzaur#2100 about this issue.")

    return
}


string function GetToneURIWithAuth(){
    return file.Tone_protocol + "://" +file.Tone_ID+":"+file.Tone_token+"@"+ file.Tone_URI
}
