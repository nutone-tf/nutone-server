global function killstat_Init


struct {
    string killstatVersion
    string host
    string protocol
    string serverId
    string serverName
    string token
    bool connected

    int matchId
    string gameMode
    string map
} file

string function sanitizePlayerName(string name) {
    
    var ex = regexp(@"\(\d*\)")
    var result = ex.search(name)
    if (result != null) {
        return name.slice(result.end, name.len())
    }
    return name;
   
}

void function killstat_Init() {
    file.host = GetConVarString("nutone_host")
    file.token = GetConVarString("nutone_token")
    file.connected = false
    file.serverName = GetConVarString("ns_server_name")
    file.serverId = GetConVarString("nutone_server_id")
    if ( file.serverId == "" ) {
        Log("You must set 'nutone_server_id' to send data!'")
        return
    }
    if ( file.serverId.len() > 30) {
        Log("nutone_server_id cannot be longer than 30 characters!")
        return
    }
    if (!regexp(@"^[a-z0-9\-_]+$").match(file.serverId)) {
        Log("nutone_server_id does not match requirements!")
        return
    }
    AddCallback_GameStateEnter(eGameState.Playing, killstat_Begin)
    AddCallback_OnPlayerKilled(killstat_Record)
    AddCallback_GameStateEnter(eGameState.Postmatch, killstat_End)
    AddCallback_OnClientConnected(JoinMessage)
}

string prefix = "\x1b[38;5;81m[NUTONEAPI]\x1b[0m "

void function JoinMessage(entity player) {
    //Chat_ServerPrivateMessage(player, prefix + "This server collects data using the Nutone API. Check your data here: \x1b[34mhttps://nutone.okudai.dev/frontend" + player.GetPlayerName()+ "\x1b[0m", false, false)
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

    vector attackerPos = attacker.GetOrigin()
    vector victimPos = victim.GetOrigin()

    values["match_id"] <- format("%08x", file.matchId)
    values["server_id"] <- file.serverId
    values["server_name"] <- file.serverName
    values["game_mode"] <- file.gameMode
    values["game_time"] <- Time()
    values["map"] <- file.map
    values["attacker_name"] <- sanitizePlayerName(attacker.GetPlayerName())
    values["attacker_uid"] <- attacker.GetUID()
    values["attacker_weapon"] <- GetWeaponName(attacker.GetLatestPrimaryWeapon())
    values["attacker_titan"] <- GetTitan(attacker)
    values["attacker_x"] <- attackerPos.x
    values["attacker_y"] <- attackerPos.y
    values["attacker_z"] <- attackerPos.z

    values["victim_name"] <- sanitizePlayerName(victim.GetPlayerName())
    values["victim_uid"] <- victim.GetUID()
    values["victim_weapon"] <- GetWeaponName(victim.GetLatestPrimaryWeapon())
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
    request.headers = {token = [file.token]}
    request.body = EncodeJSON(values)

    void functionref( HttpRequestResponse ) onSuccess = void function ( HttpRequestResponse response )
    {
        if(response.statusCode == 200 || response.statusCode == 201){
            Log("Kill data sent!")
        }else{
            Log("[WARN] Couldn't send kill data, status " + response.statusCode)
            Log("[WARN] " + response.body )
        }
    }

    void functionref( HttpRequestFailure ) onFailure = void function ( HttpRequestFailure failure )
    {
        Log("[WARN]  Couldn't send kill data")
        Log("[WARN] " + failure.errorMessage )
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