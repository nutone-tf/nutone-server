global function killstat_Init


struct {
    string killstatVersion
    string host
    string protocol
    string servername
    string token
    bool connected

    int matchId
    string gameMode
    string map
} file

void function killstat_Init() {
    file.host = GetConVarString("nutone_host")
    file.token = GetConVarString("nutone_token")
    file.connected = false
    file.servername = GetConVarString("ns_server_name")
    //register to NUTONEAPI if default or invalid token
    nutone_verify()

    // callbacks
    AddCallback_GameStateEnter(eGameState.Playing, killstat_Begin)
    AddCallback_OnPlayerKilled(killstat_Record)
    AddCallback_GameStateEnter(eGameState.Postmatch, killstat_End)
    AddCallback_OnClientConnected(JoinMessage)
}

string prefix = "\x1b[38;5;81m[NUTONEAPI]\x1b[0m "

void function JoinMessage(entity player) {
    Chat_ServerPrivateMessage(player, prefix + "This server collects data using the Nutone API. Check your data here: \x1b[34mhttps://nutone.okudai.dev/frontend" + player.GetPlayerName()+ "\x1b[0m", false, false)
}

void function killstat_Begin() {
    file.matchId = RandomInt(2000000000)
    file.gameMode = GameRules_GetGameMode()
    file.map = StringReplace(GetMapName(), "mp_", "")

    Log("Sending kill data to " + file.host + "/data")
}

void function killstat_Record(entity victim, entity attacker, var damageInfo) {
    if ( !victim.IsPlayer() || !attacker.IsPlayer() || GetGameState() != eGameState.Playing ) 
            return

    table values = {}

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

    vector attackerPos = attacker.GetOrigin()
    vector victimPos = victim.GetOrigin()

    values["match_id"] <- format("%08x", file.matchId)
    values["server_name"] <- file.servername
    values["game_mode"] <- file.gameMode
    values["game_time"] <- Time()
    values["map"] <- file.map
    values["attacker_name"] <- attacker.GetPlayerName()
    values["attacker_id"] <- attacker.GetUID()
    values["attacker_current_weapon"] <- GetWeaponName(attacker.GetLatestPrimaryWeapon())
    values["attacker_weapon_1"] <- GetWeaponName(aw1)
    values["attacker_weapon_2"] <- GetWeaponName(aw2)
    values["attacker_weapon_3"] <- GetWeaponName(aw3)
    values["attacker_offhand_weapon_1"] <- GetWeaponName(aow1)
    values["attacker_offhand_weapon_2"] <- GetWeaponName(aow2)
    values["attacker_titan"] <- GetTitan(attacker)
    values["attacker_x"] <- attackerPos.x
    values["attacker_y"] <- attackerPos.y
    values["attacker_z"] <- attackerPos.z

    values["victim_name"] <- victim.GetPlayerName()
    values["victim_id"] <- victim.GetUID()
    values["victim_current_weapon"] <- GetWeaponName(victim.GetLatestPrimaryWeapon())
    values["victim_weapon_1"] <-  GetWeaponName(vw1)
    values["victim_weapon_2"] <- GetWeaponName(vw2)
    values["victim_weapon_3"] <- GetWeaponName(vw3)
    values["victim_offhand_weapon_1"] <- GetWeaponName(vow1)
    values["victim_offhand_weapon_2"] <- GetWeaponName(vow2)
    values["victim_titan"] <- GetTitan(victim)
    values["victim_x"] <- victimPos.x
    values["victim_y"] <- victimPos.y
    values["victim_z"] <- victimPos.z

    int damageSourceId = DamageInfo_GetDamageSourceIdentifier(damageInfo)
    string damageName = DamageSourceIDToString(damageSourceId)
    values["cause_of_death"] <- damageName

    float dist = Distance(attacker.GetOrigin(), victim.GetOrigin())
    values["distance"] <- dist

    HttpRequest request
    request.method = HttpRequestMethod.POST
    request.url = file.host + "/data"
    request.headers = {Token = [file.token]}
    request.body = EncodeJSON(values)

    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if(response.statusCode == 200 || response.statusCode == 201){
            print("[NUTONEAPI] Kill data sent!")
        }else{
            print("[NUTONEAPI][WARN] Couldn't send kill data, status " + response.statusCode)
            print("[NUTONEAPI][WARN] " + response.body )
        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print("[NUTONEAPI][WARN]  Couldn't send kill data")
        print("[NUTONEAPI][WARN] " + failure.errorMessage )
    }
    NSHttpRequest(request, onSuccess, onFailure)
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
        s = weapon.GetWeaponClassName()
    }
    return s
}

string function GetTitan(entity player) {
    if(!player.IsTitan()) return "null"
    return GetTitanCharacterName(player)
}

string function Anonymize(entity player) {
    return "null" // unused
}

void function Log(string s) {
    print("[NUTONEAPI] " + s)
}

void function nutone_verify(){
    HttpRequest request
    request.method = HttpRequestMethod.POST
    request.url = file.host + "/auth"
    request.headers = {Token = [file.token]}
    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if(response.statusCode == 200){
            print("[NUTONEAPI] NUTONEAPI Online !")
            file.connected = true
        }else{
            print("[NUTONEAPI] NUTONEAPI login failed")
            print("[NUTONEAPI] " + response.body )

        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        print("[NUTONEAPI] NUTONEAPI login failed")
        print("[NUTONEAPI] " + failure.errorMessage )
    }

    NSHttpRequest(request, onSuccess, onFailure)
}
